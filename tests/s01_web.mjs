// From the project root: node tests/s01_web.mjs (serve exports on localhost:18760).
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { once } from 'node:events';

const sleep = ms => new Promise(r => setTimeout(r,ms));
const browser = process.env.EDGE_EXE || 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
const base = 'http://127.0.0.1:18760';
const stage = process.argv[2] || 's01';
if(!['s01','s02','s02-fix','s02-polish','s02-layout','s04'].includes(stage))throw Error('Unknown build');
const release = stage+'-release';
const port = stage==='s04' ? 18777 : 18769;
let recordName='campaign';
const profile = path.resolve('reports/temp/'+stage+'/edge-'+Date.now());
const errors = [];
let socket, seq=0;
const pending = new Map();
function pass(value, name) {
  console.log(value?'PASS':'FAIL',name);
  if(!value) throw Error(name);
}
async function send(method,params={}) {
  const id=++seq;
  const reply=new Promise((resolve,reject)=>pending.set(id,{resolve,reject}));
  socket.send(JSON.stringify({id,method,params}));
  return reply;
}
async function evaluate(expression) {
  const r=await send('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true});
  if(r.exceptionDetails) throw Error(JSON.stringify(r.exceptionDetails));
  return r.result.value;
}
async function open(build,query='') {
  spawn(browser,['--headless=new','--disable-background-networking','--no-first-run','--disable-extensions',
    '--remote-debugging-port='+port,'--user-data-dir='+profile,'about:blank'],{windowsHide:true,stdio:'ignore'});
  let page;
  for(let i=0;i<100&&!page;i++) {
    try{page=(await (await fetch('http://127.0.0.1:'+port+'/json/list')).json()).find(t=>t.type==='page');}catch{}
    if(!page) await sleep(200);
  }
  socket=new WebSocket(page.webSocketDebuggerUrl);
  await once(socket,'open');
  socket.onmessage=({data})=>{
    const m=JSON.parse(data);
    if(m.id && pending.has(m.id)){
      const p=pending.get(m.id); pending.delete(m.id);
      if(m.error)p.reject(Error(m.error.message)); else p.resolve(m.result);
    }
    if(m.method==='Runtime.exceptionThrown'||(m.method==='Runtime.consoleAPICalled'&&m.params.type==='error'))errors.push(m.params);
  };
  await send('Runtime.enable');
  await send('Emulation.setDeviceMetricsOverride',{width:960,height:540,deviceScaleFactor:1,mobile:false});
  await send('Page.navigate',{url:base+'/'+build+'/'+query});
  await ready();
}
async function ready(){
  for(let i=0;i<150;i++){
    await sleep(250);
    if(await evaluate("!!document.querySelector('canvas') && !document.querySelector('#status')")){
      await sleep(550);return;
    }
  }
  throw Error('WASM did not start');
}
async function close() {
  if(!socket || socket.readyState!==WebSocket.OPEN)return;
  // Edge may relaunch itself on Windows. Wait for the real browser endpoint.
  const {webSocketDebuggerUrl}=await (await fetch('http://127.0.0.1:'+port+'/json/version')).json();
  const control=new WebSocket(webSocketDebuggerUrl);
  await once(control,'open');
  control.send(JSON.stringify({id:1,method:'Browser.close'}));
  for(let i=0;i<100;i++){
    await sleep(100);
    try{await fetch('http://127.0.0.1:'+port+'/json/version');}
    catch{socket.close();return;}
  }
  throw Error('Browser still running after Browser.close');
}
async function click(x,y){
  for(const type of ['mousePressed','mouseReleased'])await send('Input.dispatchMouseEvent',{type,x,y,button:'left',clickCount:1});
  await sleep(230);
}
async function key(code,key,vk,on) {
  await send('Input.dispatchKeyEvent',{type:on?'rawKeyDown':'keyUp',code,key,windowsVirtualKeyCode:vk});
}
async function tap(c,k,v){await key(c,k,v,true);await sleep(90);await key(c,k,v,false);await sleep(100);}
async function shot(name){
  const {data}=await send('Page.captureScreenshot',{format:'png'});
  fs.writeFileSync(path.join(profile,'../'+name+'.png'),Buffer.from(data,'base64'));
  return data;
}
// Observe the real IndexedDB file; this harness never writes game records.
async function record(){
  const rows=await evaluate(`(async()=>{
    const request = r=>new Promise((ok,fail)=>{r.onsuccess=()=>ok(r.result);r.onerror=()=>fail(r.error)});
    const rows=[];
    for(const {name} of await indexedDB.databases()){
      const db=await request(indexedDB.open(name));
      if(db.objectStoreNames.contains('FILE_DATA')){
        const store=db.transaction('FILE_DATA').objectStore('FILE_DATA');
        const [keys,values]=await Promise.all([request(store.getAllKeys()),request(store.getAll())]);
        for(let i=0;i<keys.length;i++)if([0,1].some(slot=>keys[i].endsWith('/'+${JSON.stringify(recordName)}+'.'+slot)))rows.push(Array.from(values[i].contents));
      }
      db.close();
    }
    return rows;
  })()`);
  function field(buf,name) {
    const tag=Buffer.from(name), pos=buf.indexOf(tag);
    if(pos<0)return null;
    const off=pos+Math.ceil(tag.length/4)*4, type=buf.readUInt32LE(off);
    if(type===2)return buf.readInt32LE(off+4);
    if(type===4)return buf.subarray(off+8,off+8+buf.readUInt32LE(off+4)).toString();
    return null;
  }
  const buffers=rows.map(buf=>Buffer.from(buf)).sort((a,b)=>field(b,'serial')-field(a,'serial'));
  if(!buffers.length)return {};
  return Object.fromEntries(['wallet','hearts','status','hero','lost','score','level'].map(k=>[k,field(buffers[0],k)]));
}
async function until(test,seconds=12){
  for(let i=0;i<seconds*4;i++){const r=await record();if(test(r))return r;await sleep(250);}
  throw Error('Timed out. Persisted state '+JSON.stringify(await record()));
}
async function settingsText(){
  return evaluate(`(async()=>{
    const read=r=>new Promise((ok,fail)=>{r.onsuccess=()=>ok(r.result);r.onerror=()=>fail(r.error)});
    const db=await read(indexedDB.open('/userfs'));
    const store=db.transaction('FILE_DATA').objectStore('FILE_DATA');
    const [keys,values]=await Promise.all([read(store.getAllKeys()),read(store.getAll())]);db.close();
    const idx=keys.findIndex(k=>k.endsWith('/settings.cfg'));
    return idx<0?'':new TextDecoder().decode(values[idx].contents);
  })()`);
}
async function checkRelease(){
  await open(release);
  let settings='';
  if(stage!=='s01'){
    await click(180,423);await click(291,220);await click(723,220);await click(154,432);
    for(let i=0;i<25&&!settings;i++){await sleep(100);settings=await settingsText();}
    pass(settings.includes('"Музыка"=20') && settings.includes('"Музыка"=true'),'music volume and mute applied and saved in IndexedDB');
    await click(180,423);await click(490,220);await click(390,432);
    pass(await settingsText()===settings,'Back discards pending changes');
  }
  await click(173,316); await click(265,316); await click(169,425); await click(172,430);
  await key('KeyD','d',68,true); await sleep(1650); await key('KeyD','d',68,false);
  const earned=await until(r=>r.wallet===3);
  pass(earned.hearts===3 && earned.hero==='human','release collected three real coins');
  if(stage!=='s01'){
    await send('Page.reload',{ignoreCache:true});
    await sleep(400); await ready(); await click(183,370);
    await key('KeyD','d',68,true);await sleep(1650);await key('KeyD','d',68,false);
    pass((await record()).wallet===3,'reload preserves collected coins');
  }
  if(stage!=='s01'){
    await tap('Escape','Escape',27);await click(155,412);
    const confirm=await shot('confirm-exit');await click(417,361);
    pass((await shot('cancelled-exit'))!==confirm,'exit confirmation can be cancelled');
    await click(176,244);
  }
  const before=await shot('release-before-F1');
  await tap('F1','F1',112);
  const after=await shot('release-after-F1');
  // Movement after F1 proves a debug modal has not paused the release game.
  await key('KeyD','d',68,true);await sleep(750);await key('KeyD','d',68,false);
  const moved=await shot('release-after-move');
  async function playfield(png){
    return evaluate(`(async()=>{const im=new Image();im.src='data:image/png;base64,${png}';await im.decode();const c=document.createElement('canvas');c.width=960;c.height=370;c.getContext('2d').drawImage(im,0,-155);return c.toDataURL()})()`);
  }
  pass((await playfield(moved))!==(await playfield(after)) && (await playfield(before))===(await playfield(after)),'release continues moving after F1');
  await close();
  await open(release);
  if(stage!=='s01')pass(await settingsText()===settings,'audio settings persist after browser relaunch');
  await click(183,370);
  await key('KeyD','d',68,true); await sleep(1700);await key('KeyD','d',68,false);
  let r=await record();pass(r.wallet===3 && r.score===30,'closed browser reopened: same wallet and no second reward');
  for(let hearts=2;hearts>=0;hearts--){
    await key('KeyD','d',68,true);
    await sleep(hearts===2?3500:5500);
    await key('Space',' ',32,true);await sleep(650);await key('Space',' ',32,false);
    r=await until(s=>s.hearts===hearts,16);
    await key('KeyD','d',68,false);
    console.log('pit',r);
    if(hearts>0)await sleep(1250);
  }
  pass(r.status==='offer' && r.lost===3,'three real pit falls reached purchase screen');
  const atZero=await shot('release-zero');
  await close();
  await open(release);
  const restored=await shot('release-zero-restored');
  r=await until(s=>s.hearts===0 && s.status==='offer');
  pass(restored===atZero && r.hearts===0 && r.status==='offer','browser restart at zero still requires purchase');
  await click(490,370); await click(140,360);
  await until(s=>s.status==='defeat');
  pass(atZero.length>1000 && restored.length>1000,'restored offer accepts refusal and ends campaign');
  const other=await send('Target.createTarget',{url:base+'/'+release+'/'});
  const target=(await (await fetch('http://127.0.0.1:'+port+'/json/list')).json()).find(t=>t.id===other.targetId);
  const second=new WebSocket(target.webSocketDebuggerUrl);
  await once(second,'open');
  let locked=false;
  for(let i=0;i<100 && !locked;i++){
    const reply=once(second,'message');
    second.send(JSON.stringify({id:i+1,method:'Runtime.evaluate',params:{expression:'window.maricraftWriter === -1 && !document.querySelector("#status")',returnByValue:true}}));
    const [message]=await reply;
    locked=JSON.parse(message.data).result.result.value;
    if(!locked)await sleep(180);
  }
  pass(locked,'another tab cannot overwrite the open campaign');
  await send('Target.closeTarget',{targetId:other.targetId});
  second.close();
  pass(errors.length===0,'no runtime console errors');
}

async function checkForestDebug(){
  await open(stage);
  await click(173,316); await click(265,316); await click(169,425); await click(172,430);
  await until(r=>r.level==='1-1');
  await tap('F1','F1',112); await click(435,295); // Enter the in-memory test profile.
  await click(473,197); await sleep(600);
  const ferryMap=await shot('debug-1-2');
  await tap('F1','F1',112); await click(677,197); await sleep(500);
  await tap('F1','F1',112); await shot('debug-boss-menu');
  await click(474,372); await sleep(450); // Boss HP button moves to the arena.
  const arena=await shot('debug-arena');
  async function healthPixels(png){
    return evaluate(`(async()=>{const im=new Image(); im.src="data:image/png;base64,${png}";await im.decode();const c=document.createElement('canvas');c.width=960;c.height=540;const ctx=c.getContext('2d');ctx.drawImage(im,0,0);const row=ctx.getImageData(763,91,164,1).data;let n=0;for(let i=0;i<row.length;i+=4)if(row[i]>240&&row[i+1]>185&&row[i+2]<155)n++;return n;})()`);
  }
  pass(await healthPixels(ferryMap)===0 && await healthPixels(arena)>155,'debug level jumps open 1-2 then the live 9 HP arena');
  await tap('F1','F1',112);
  await click(679,255); // +100 test coins
  await click(270,412); // Defeat boss in the sandbox
  await tap('F1','F1',112);await sleep(250);
  pass(await healthPixels(await shot('debug-defeated'))===0,'debug defeat removes the boss health bar');
  const normal=await record();
  pass(normal.level==='1-1'&&normal.wallet===0&&normal.score===0,'test rewards and level jumps leave normal browser profile untouched');
  pass(errors.length===0,'debug Web runtime console clean');
}
// The release arena scenario uses only the fresh, private Edge profile created by open().
async function checkReleaseArena(){
  const fixture='reports/temp/polish/browser-fixture/';
  const trace=JSON.parse(fs.readFileSync(fixture+'keys.json'));
  await open(release);
  await click(173,316);await click(265,316);await click(169,425);await click(172,430);
  await until(r=>r.level==='1-1');
  await send('Page.navigate',{url:base+'/'+release+'/index.icon.png'});
  await sleep(350);
  const slots=[0,1].map(slot=>Array.from(fs.readFileSync(fixture+'campaign.'+slot)));
  await evaluate(`(async()=>{
    const read=r=>new Promise((ok,no)=>{r.onsuccess=()=>ok(r.result);r.onerror=()=>no(r.error)});
    const db=await read(indexedDB.open('/userfs'));
    const tx=db.transaction('FILE_DATA','readwrite'),store=tx.objectStore('FILE_DATA');
    const keys=await read(store.getAllKeys()), key=keys.find(k=>k.endsWith('/campaign.1')||k.endsWith('/campaign.0'));
    if(!key)throw Error('No campaign file in the isolated browser');
    const model=await read(store.get(key));
    for(const [i,bytes] of ${JSON.stringify(slots)}.entries())store.put({...model,timestamp:new Date(),contents:new Uint8Array(bytes)},key.slice(0,-1)+i);
    await new Promise((ok,no)=>{tx.oncomplete=ok;tx.onerror=no});db.close();return true
  })()`);
  await send('Page.navigate',{url:base+'/'+release+'/'});await ready();
  pass((await record()).level==='1-3','release loaded isolated campaign at 1-3');
  await click(183,370);
  const start=performance.now();
  let captured=false;
  for(const [tick,vk,on] of trace.events){
    const letter=String.fromCharCode(vk);
    await sleep(Math.max(0,start+tick*1000/60-performance.now()));
    await key(vk===32?'Space':'Key'+letter,vk===32?' ':letter.toLowerCase(),vk,on);
    if(!captured && tick>trace.combat+180){await shot('release-arena-live');captured=true;}
  }
  await sleep(1200);
  await shot('release-arena-end');
  const end=await record();
  console.log('release arena progress',end);
  pass(end.level==='2-1' && end.status==='result','release fight, gate and result from real keyboard input');
  pass(!errors.length,'release arena console clean');
}
async function checkDurotar() {
  const debug=process.argv.includes('--debug');
  const build=debug?stage:release;
  await open(build,'?expedition=durotar');
  recordName='durotar-expedition';
  const main=await shot('s04-menu');
  await tap('F1','F1',112);
  const f1=await shot(debug?'s04-debug-f1':'s04-release-f1');
  pass(debug?main!==f1:main===f1,debug?'F1 opens developer controls':'F1 absent in release');
  if(debug){
    await tap('F1','F1',112);
    await click(170,316);await click(685,315);await click(170,425);await click(174,430);
    await key('KeyD','d',68,true);await sleep(1200);await key('KeyD','d',68,false);
    const p=await until(r=>r.wallet>0);
    pass(p.level==='2-1'&&p.hero==='ogre','debug loads Durotar with ogre');
    pass(!errors.length,'debug console clean');
    return;
  }
  await click(170,316);await click(266,315);await click(170,425);await click(174,430);
  await key('KeyD','d',68,true);await sleep(1650);await key('KeyD','d',68,false);
  const first=await until(r=>r.wallet===3);
  await send('Page.reload',{ignoreCache:true});await sleep(400);await ready();await click(180,370);
  await key('KeyD','d',68,true);await sleep(1650);await key('KeyD','d',68,false);await sleep(500);
  pass((await record()).wallet===first.wallet,'page reload preserves Durotar rewards');
  await send('Page.reload',{ignoreCache:true});await sleep(400);await ready();await click(180,370);
  for(const [index,level] of ['2-1','2-2','2-3'].entries()){
    const trace=JSON.parse(fs.readFileSync('reports/temp/s04/'+level+'-0-ogre.json'));
    const start=performance.now();
    for(const [tick,vk,on] of trace.events){
      await sleep(Math.max(0,start+tick*1000/60-performance.now()));
      const letter=String.fromCharCode(vk);
      await key(vk===32?'Space':'Key'+letter,vk===32?' ':letter.toLowerCase(),vk,on);
    }
    const end=await until(r=>r.status==='result',4);
    pass(end.level===['2-2','2-3','3-1'][index],'browser real keyboard completes '+level);
    await shot('s04-result-'+level);
    await click(170,450);await click(172,436);
  }
  await shot('s04-next-world');
  pass(!errors.length,'release console clean');
}
try{
  if(stage==='s04')await checkDurotar();
  else if(process.argv.includes('--arena'))await checkReleaseArena();
  else if(process.argv.includes('--debug'))await checkForestDebug();
  else await checkRelease();
}finally{await close();}
