// From the project root: node tests/forest_art_web.mjs (serve project on localhost:18780).
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { once } from 'node:events';

const sleep = ms => new Promise(r => setTimeout(r,ms));
const browser = process.env.EDGE_EXE || 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
const base = 'http://127.0.0.1:18780/exports';
const stage = 'forest-art';
if(!['s01','s02','s02-fix','s02-polish','s02-layout','s04','forest-art'].includes(stage))throw Error('Unknown build');
const release = stage+'-release';
const port = 18779;
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
  await send('Page.enable');
  await send('Page.addScriptToEvaluateOnNewDocument',{source:'window.MARICRAFT_QA=true;'});
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
// Focused art acceptance test: actual HTML5 release, no writes to its save.
// Run: node tests/forest_art_web.mjs [--baseline]
async function performanceSample(label){
  const stats=await evaluate(`new Promise(resolve=>{let last=performance.now(),d=[];function frame(t){d.push(t-last);last=t;if(d.length<180)requestAnimationFrame(frame);else{d=d.slice(10).sort((a,b)=>a-b);resolve({frames:d.length,median_ms:d[Math.floor(d.length/2)],p95_ms:d[Math.floor(d.length*.95)],estimated_fps:1000/(d.reduce((a,b)=>a+b,0)/d.length)})}}requestAnimationFrame(frame)})`);
  metrics[label]=stats;console.log('PERFORMANCE',label,stats);
}
const metrics={};
// Same obstacle decisions as the native pilot, but only real browser key events.
// The opt-in observation is read-only; no commands, grants or save writes.
async function drive(level){
  const held=new Set(), ferries=[0,0], started=performance.now();
  const pits={'1-1':[1600,3184,4784,6560],'1-2':[650,3380],'1-3':[700]}[level];
  let jumpUntil=0,lastFrame=-1,lastReport=-500,duel=false;
  async function hold(code,on){
    if(held.has(code)===on)return;
    const vk=code==='Space'?32:code.charCodeAt(3);
    await key(code,code==='Space'?' ':code[3].toLowerCase(),vk,on);
    if(on)held.add(code);else held.delete(code);
  }
  try{
    while(performance.now()-started<180000){
      const s=await evaluate("JSON.parse(window.maricraftObservation || '{}')");
      if(s.page==='result'){metrics[level+'_route_seconds']=(performance.now()-started)/1000;return;}
      if(!s.player){if(performance.now()-started>8000)throw Error('No acceptance observation: '+JSON.stringify(s));await sleep(8);continue;}
      if(s.frame===lastFrame){await sleep(8);continue;}
      lastFrame=s.frame;
      if(s.page==='pause'){await tap('Escape','Escape',27);continue;}
      const p=s.player,x=p.x;
      if(s.hearts<3){await shot('web-failure-'+level);throw Error('Unexpected loss '+JSON.stringify(s));}
      let axis=1,jump=p.wall;
      for(const edge of pits)if(x>=edge-42&&x<edge)jump=true;
      for(const e of s.enemies)if(Math.abs(e.y-p.y)<45&&e.x-x>12&&e.x-x<86)jump=true;
      if(level==='1-2'){
        for(const thorn of [430,3090,3948])if(x>thorn-89&&x<thorn-52)jump=true;
        for(let i=0;i<2;i++){
          const deck=s.ferries[i],left=[1450,4200][i],right=[1770,4480][i];
          if(x<left-110||ferries[i]===3)continue;
          if(ferries[i]===0){axis=0;if(deck.x<left+32&&p.floor){ferries[i]=1;axis=1;jump=true;}}
          else if(ferries[i]===1){axis=x<deck.x-4?1:0;if(deck.riding)ferries[i]=2;}
          else if(ferries[i]===2){axis=0;if(x>right-85){ferries[i]=3;axis=1;jump=true;}}
          if(x>=right+20)ferries[i]=3;
        }
      }
      if(level==='1-3'&&s.boss?.hp>0&&x>=1804){
        if(!duel){await hold('Space',false);jumpUntil=0;duel=true;}
        const b=s.boss,dx=b.x-x;
        let target=b.x-117;jump=p.wall;
        if(b.mode===3){target=b.x-4;if(Math.abs(dx)<143)jump=true;}
        if(b.mode===1&&b.kind===1)target=b.landing_x-64;
        axis=Math.abs(target-x)>3?Math.sign(target-x):0;
        for(const shot of s.shots){const gap=(x-shot.x)*Math.sign(shot.dx);if(gap>0&&gap<67)jump=true;}
      }
      await hold('KeyD',axis>0);await hold('KeyA',axis<0);
      if(held.has('Space')){if(s.frame>=jumpUntil)await hold('Space',false);}
      else if(jump&&p.floor){await hold('Space',true);jumpUntil=s.frame+(duel?35:40);}
      if(s.frame-lastReport>600){lastReport=s.frame;console.log('ROUTE',level,Math.round(x),Math.round(p.y),ferries,s.boss?.hp??'');}
      await sleep(8);
    }
    await shot('web-timeout-'+level);throw Error('Route timeout '+level);
  }finally{for(const code of [...held])await hold(code,false);}
}
async function replay(level,index){
  const opened=performance.now();
  for(const type of ['mousePressed','mouseReleased'])await send('Input.dispatchMouseEvent',{type,x:172,y:430,button:'left',clickCount:1});
  await shot('web-start-'+level);
  metrics[level+'_first_frame_ms']=performance.now()-opened;
  await drive(level);
  const end=await until(r=>r.status==='result',8);
  console.log('PROGRESS',level,end);
  pass(end.level===['1-2','1-3','2-1'][index]&&end.hearts===3,'normal campaign completes '+level+' without lost hearts');
  await shot('web-result-'+level);
  if(index===0){
    await send('Page.reload',{ignoreCache:true});await sleep(400);await ready();
    const restored=await record();pass(restored.wallet===end.wallet&&restored.score===end.score&&restored.level===end.level,'reload preserves result, wallet and score');
    await shot('web-restored-result');
  }
  await click(170,450);
}
try{
  const baseline=process.argv.includes('--baseline');
  const perf=process.argv.includes('--performance');
  await open(baseline?'s04-release':release);
  metrics.loading=await evaluate('performance.now()');
  await shot(baseline?'baseline-main':'web-main');
  const before=await shot('web-before-f1');
  await tap('F1','F1',112);
  pass((await shot('web-after-f1'))===before,'F1 unavailable in release main menu');
  if(baseline||perf){
    await click(173,316);await click(265,316);await click(169,425);await click(172,430);
    await performanceSample(baseline?'baseline-start':'forest-start');
  }else{
    await click(180,423);await shot('web-settings');await tap('Escape','Escape',27);
    await click(173,316);await shot('web-heroes');await click(265,316);await click(169,425);await shot('web-map');
    for(const [index,level] of ['1-1','1-2','1-3'].entries())await replay(level,index);
    await shot('web-unlocked-2-1');await click(172,430);await sleep(400);
    await shot('web-durotar');await performanceSample('durotar-start');
    pass((await record()).level==='2-1','next chapter starts normally');
    await tap('Escape','Escape',27);await shot('web-pause');
    pass(errors.length===0,'browser console has no runtime errors');
  }
}finally{
  fs.writeFileSync('reports/evidence/forest-art/'+(process.argv.includes('--baseline')?'web-baseline':(process.argv.includes('--performance')?'web-performance':'web-release'))+'.json',JSON.stringify({metrics,errors},null,2));
  await close();
}
