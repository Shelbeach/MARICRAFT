// From the project root: node tests/forest_art_web.mjs (serve project on localhost:18780).
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { once } from 'node:events';

const sleep = ms => new Promise(r => setTimeout(r,ms));
const browser = process.env.EDGE_EXE || 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
const base = 'http://127.0.0.1:18780/exports';
const stage = 'molten';
const release = stage+'-release';
const port = 18792;
let recordName='campaign';
const profile = path.resolve('reports/temp/'+stage+'/edge-'+Date.now());
const errors = [];
const requests=[];
const out='reports/evidence/molten/web';fs.mkdirSync(out,{recursive:true});
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
  spawn(browser,['--headless=new','--disable-background-networking','--disable-sync','--no-first-run','--disable-extensions',
    '--remote-debugging-port='+port,'--user-data-dir='+profile,'about:blank'],{windowsHide:true,stdio:'ignore',env:{...process.env,TEMP:path.resolve('reports/temp/molten'),TMP:path.resolve('reports/temp/molten')}});
  let page;
  for(let i=0;i<100&&!page;i++) {
    try{page=(await (await fetch('http://127.0.0.1:'+port+'/json/list')).json()).find(t=>t.type==='page'&&t.url==='about:blank');}catch{}
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
    if(m.method==='Network.requestWillBeSent')requests.push(m.params.request.url);
    if(m.method==='Runtime.exceptionThrown'||(m.method==='Runtime.consoleAPICalled'&&m.params.type==='error'))errors.push(m.params);
  };
  await send('Runtime.enable');
  await send('Page.enable');
  await send('Network.enable');
  await send('Page.addScriptToEvaluateOnNewDocument',{source:`window.MARICRAFT_QA=true;
${process.argv.includes('--30') ? `const nativeRAF=window.requestAnimationFrame.bind(window);let rafId=0,rafTime=0;const rafQueue=new Map();window.requestAnimationFrame=callback=>{const id=++rafId;rafQueue.set(id,callback);return id};window.cancelAnimationFrame=id=>rafQueue.delete(id);nativeRAF(function pump(t){if(t-rafTime>=32.8){rafTime=t;const batch=[...rafQueue.values()];rafQueue.clear();for(const cb of batch)cb(t)}nativeRAF(pump)});` : ''} window.__audioContexts=[];window.__audioProbes=[];
const originalAudioContext=window.AudioContext;
window.AudioContext=new Proxy(originalAudioContext,{construct(target,args){const context=new target(...args);window.__audioContexts.push(context);return context;}});
const originalConnect=AudioNode.prototype.connect;
AudioNode.prototype.connect=function(destination,...args){
 if(destination instanceof AudioDestinationNode){
  const analyser=this.context.createAnalyser();analyser.fftSize=2048;window.__audioProbes.push(analyser);
  originalConnect.call(this,analyser);return originalConnect.call(analyser,destination,...args);
 }
 return originalConnect.call(this,destination,...args);
};`});
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
  fs.writeFileSync(path.join(out,name+'.png'),Buffer.from(data,'base64'));
  return data;
}
async function observe(){return evaluate("JSON.parse(window.maricraftObservation||'{}')");}
async function button(text,index=0){
 let found;
 for(let i=0;i<30&&!found;i++){const d=await observe();found=(d.buttons||[]).filter(b=>(b.text===text||b.name===text))[index];if(!found)await sleep(100);}
 pass(!!found&&!found.disabled,'enabled UI: '+text);await click(found.x,found.y);
}
async function audioSample(label){
 metrics[label]=await evaluate(`new Promise(resolve=>{let peak=0,frames=0;function read(){for(const a of window.__audioProbes){const b=new Float32Array(a.fftSize);a.getFloatTimeDomainData(b);for(const x of b)peak=Math.max(peak,Math.abs(x));}if(++frames<45)requestAnimationFrame(read);else resolve({peak,contexts:window.__audioContexts.map(c=>c.state)})}read()})`);
 console.log('AUDIO',label,metrics[label]);
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
async function startBossSample(){
 await evaluate(`window.__bossPerf={active:true,last:0,d:[]};requestAnimationFrame(function frame(t){const p=window.__bossPerf;if(!p.active)return;if(p.last)p.d.push(t-p.last);p.last=t;requestAnimationFrame(frame)})`);
}
async function endBossSample(){
 metrics.boss_performance=await evaluate(`(()=>{const p=window.__bossPerf;p.active=false;const d=p.d.slice(10).sort((a,b)=>a-b);return {frames:d.length,median_ms:d[Math.floor(d.length/2)],p95_ms:d[Math.floor(d.length*.95)],estimated_fps:1000/(d.reduce((a,b)=>a+b,0)/d.length)}})()`);
 console.log('PERFORMANCE boss',metrics.boss_performance);
}
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
          const deck=s.ferries.find(d=>d.name===['BrookFerry','LastFerry'][i]),left=[1450,4200][i],right=[1770,4480][i];
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
        if(b.mode===1&&b.kind===1)target=b.landing_x-105;
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
async function driveDurotar(level){
 const held=new Set(),started=performance.now();let lastFrame=-1,jumpUntil=0,airborne=false,lastReport=-600;
 async function hold(code,on){if(held.has(code)===on)return;const vk=code==='Space'?32:code.charCodeAt(3);await key(code,code==='Space'?' ':code[3].toLowerCase(),vk,on);if(on)held.add(code);else held.delete(code);}
 async function stop(){for(const k of [...held])await hold(k,false);jumpUntil=0;airborne=false;}
 async function next(){
  for(;;){const s=await observe();if(s.page==='pause'){await tap('Escape','Escape',27);continue;}
   if(s.hearts!==3&&s.player){await shot('web-failure-'+level);throw Error('Unexpected heart loss '+JSON.stringify(s));}
   if(s.player&&s.frame!==lastFrame){lastFrame=s.frame;if(s.frame-lastReport>600){lastReport=s.frame;console.log('ROUTE',level,Math.round(s.player.x),Math.round(s.player.y),'boss',s.boss?.hp??'');}return s;}
   if(performance.now()-started>260000)throw Error('Web route timed out '+level);await sleep(7);
  }
 }
 const steer=(p,x)=>Math.abs(x-p.x)>3?Math.sign(x-p.x):0;
 async function controls(s,axis,leap){
  await hold('KeyD',axis>0);await hold('KeyA',axis<0);
  if(!s.player.floor)airborne=true;
  if(held.has('Space')&&(s.frame>=jumpUntil||(leap&&s.player.floor&&airborne))){await hold('Space',false);jumpUntil=0;airborne=false;return;}
  if(leap&&s.player.floor&&!held.has('Space')){await hold('Space',true);jumpUntil=s.frame+46;airborne=false;}
 }
 async function settle(ticks=65){await stop();let s=await next(),end=s.frame+ticks;while(s.frame<end)s=await next();return s;}
 async function approach(dest,launch=[]){
  let s=await next();const end=s.frame+5400;
  while(s.page==='play'&&Math.abs(s.player.x-dest)>3){
   const p=s.player,axis=steer(p,dest);let leap=p.step_wall;
   for(const x of launch)if(axis>0&&((p.x>=x&&p.x<x+31)||(p.floor&&p.edge&&x>=p.x-12&&x<p.x+120)))leap=true;
   for(const foe of s.enemies){const gap=(foe.x-p.x)*axis,base=p.low_ceiling?45:80,timing=foe.direction!==axis?Math.max(base,65):base;if(gap>0&&gap<timing&&Math.abs(foe.y-p.y)<36)leap=true;}
   await controls(s,axis,leap);s=await next();if(s.frame>end)throw Error('Stuck toward '+dest+' '+JSON.stringify(s));
  }
  await stop();return s;
 }
 async function ferry(name,bank){
  let s=await next(),launched=false,boarded=false,timeout=s.frame+1000;
  while(s.frame<timeout){const deck=s.ferries.find(d=>d.name===name),p=s.player;if(deck.riding){boarded=true;break;}
   if(!launched&&p.floor&&deck.elapsed>deck.period*.65&&deck.x-p.x<132)launched=true;
   await controls(s,launched&&deck.x-p.x>4?1:0,launched);s=await next();
  }
  pass(boarded,'Web boarded '+name);await stop();
  while(s.ferries.find(d=>d.name===name).x<bank-91){const d=s.ferries.find(d=>d.name===name);await controls(s,Math.abs(d.x-s.player.x)>8?Math.sign(d.x-s.player.x):0,false);s=await next();}
  await stop();let first=true;
  while(s.player.x<bank+30){await controls(s,1,first);first=false;s=await next();}
  await stop();pass(s.player.y<500,'Web disembarked '+name);
 }
 async function pipe(outside){await settle();await hold('KeyS',true);let s=await next(),end=s.frame+90;while((s.player.x>6000)!==outside&&s.frame<end)s=await next();await hold('KeyS',false);pass((s.player.x>6000)===outside,'Web pipe transition');}
 try{
  if(level==='2-1')await approach(5303,[770,1500,2780,3570,4450]);
  if(level==='2-2'){
   await approach(680);await ferry('WestLift',1050);await approach(1830);await ferry('EastLift',2200);
   await approach(3060);await pipe(true);await approach(8760,[7745]);await pipe(false);
   await approach(3630,[3435]);await ferry('DeepLift',4020);await approach(4160);await settle(55);await approach(5403,[4180,4560]);
  }
  if(level==='2-3'){
   await approach(3070,[490,1060,2150]);let s=await next(),oldStep=-1,evade=3070;const phases=new Set(),timeout=s.frame+6500;
   while(s.boss.hp>0&&s.frame<timeout){
    const b=s.boss,p=s.player,dx=b.x-p.x,side=dx<0?1:-1;phases.add(b.phase);let target=b.x+side*105,leap=p.step_wall;
    if(b.step!==oldStep&&b.mode===1){oldStep=b.step;const mark=b.marks[0],far=Math.sign(mark-b.x)||-1;evade=mark+far*78;if(evade<b.arena_start+25||evade>3900)evade=mark-far*64;}
    if(b.mode===1||b.mode===2){target=evade;if(b.phase===1){target=b.x+side*104;if(b.mode===1&&b.clock<.35)leap=true;}}
    if(b.mode===3){target=b.x;if(Math.abs(dx)<144)leap=true;}
    await controls(s,steer(p,target),leap);s=await next();
   }
   pass(s.boss.hp===0&&phases.size===3,'Web foreman all three phases');await stop();await approach(4023);
  }
  await settle(4);const s=await observe();pass(s.page==='result','Web finish '+level);metrics[level+'_route_seconds']=(performance.now()-started)/1000;
 }finally{await stop();}
}
async function replay(level,index){
  const opened=performance.now();
  await button('Продолжить');
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
  await button('Следующий уровень');
}
async function driveMolten(level){
 const held=new Set(),started=performance.now();let lastFrame=-1,jumpUntil=0,airborne=false,lastReport=-600;
 async function hold(code,on){if(held.has(code)===on)return;const vk=code==='Space'?32:code.charCodeAt(3);await key(code,code==='Space'?' ':code[3].toLowerCase(),vk,on);if(on)held.add(code);else held.delete(code);}
 async function stop(){for(const k of [...held])await hold(k,false);jumpUntil=0;airborne=false;}
 async function next(){for(;;){const s=await observe();if(s.page==='pause'){await tap('Escape','Escape',27);continue;}if(s.hearts!==3&&s.player){await shot('failure-'+level);throw Error('Heart loss '+JSON.stringify(s));}if(s.player&&s.frame!==lastFrame){lastFrame=s.frame;if(s.frame-lastReport>600){lastReport=s.frame;console.log('MOLTEN',level,Math.round(s.player.x),Math.round(s.player.y),s.boss?.hp??'');}return s;}if(performance.now()-started>340000)throw Error('Timeout '+level);await sleep(5);}}
 const steer=(p,x)=>Math.abs(x-p.x)>3?Math.sign(x-p.x):0;
 async function controls(s,axis,leap){await hold('KeyD',axis>0);await hold('KeyA',axis<0);if(!s.player.floor)airborne=true;if(held.has('Space')&&(s.frame>=jumpUntil||(leap&&s.player.floor&&airborne))){await hold('Space',false);jumpUntil=0;airborne=false;return;}if(leap&&s.player.floor&&!held.has('Space')){await hold('Space',true);jumpUntil=s.frame+46;airborne=false;}}
 async function settle(ticks=65){await stop();let s=await next(),end=s.frame+ticks;while(s.frame<end)s=await next();return s;}
 async function approach(dest,launch=[]){let s=await next();const end=s.frame+4200;while(s.page==='play'&&Math.abs(s.player.x-dest)>3){const p=s.player,axis=steer(p,dest);let leap=p.step_wall;for(const x of launch)if(axis>0&&((p.x>=x&&p.x<x+31)||(p.floor&&p.edge&&x>=p.x-12&&x<p.x+120)))leap=true;for(const foe of s.enemies){const gap=(foe.x-p.x)*axis,base=p.low_ceiling?45:80,timing=foe.direction!==axis?Math.max(base,65):base;if(gap>0&&gap<timing&&Math.abs(foe.y-p.y)<36)leap=true;}await controls(s,axis,leap);s=await next();if(s.frame>end)throw Error('Stuck '+dest+' '+JSON.stringify(s));}await stop();return s;}
 async function valve(name){let s=await next(),v=s.hazards.find(v=>v.name===name);await approach(v.x-v.width/2-42);s=await settle(6);for(;;){v=s.hazards.find(v=>v.name===name);const phase=v.age%(v.warning+v.duration+v.rest);if(phase>=v.warning+v.duration+.03&&phase<v.warning+v.duration+.45)break;s=await next();}await approach(v.x+v.width/2+46);pass(true,'Web timed valve '+name);}
 async function ferry(name,bank){let s=await next(),launched=false,boarded=false,end=s.frame+1000;while(s.frame<end){const d=s.ferries.find(d=>d.name===name),p=s.player;if(d.riding){boarded=true;break;}if(!launched&&p.floor&&d.elapsed>d.period*.65&&d.x-p.x<132)launched=true;await controls(s,launched&&d.x-p.x>4?1:0,launched);s=await next();}pass(boarded,'Web boarded '+name);await stop();while(s.ferries.find(d=>d.name===name).x<bank-91){const d=s.ferries.find(d=>d.name===name);await controls(s,Math.abs(d.x-s.player.x)>8?Math.sign(d.x-s.player.x):0,false);s=await next();}await stop();let first=true;while(s.player.x<bank+30){await controls(s,1,first);first=false;s=await next();}await stop();pass(s.player.y<500,'Web disembarked '+name);}
 async function lift(){let s=await next(),launched=false,boarded=false,end=s.frame+1000;while(s.frame<end){const d=s.ferries.find(d=>d.name==='ChainLift');if(d.riding){boarded=true;break;}if(!launched&&s.player.floor&&d.elapsed>d.period*.8&&Math.abs(s.player.x-d.x)<125)launched=true;await controls(s,launched&&s.player.x<d.x-2?1:0,launched);s=await next();}pass(boarded,'Web boarded vertical chain lift');await stop();while(s.ferries.find(d=>d.name==='ChainLift').y>344){const d=s.ferries.find(d=>d.name==='ChainLift');await controls(s,Math.abs(d.x-s.player.x)>7?Math.sign(d.x-s.player.x):0,false);s=await next();}await stop();let first=true,air=false;while(!air||!s.player.floor){await controls(s,steer(s.player,3294),first);first=false;s=await next();if(!s.player.floor)air=true;}await settle(6);pass(Math.abs((await observe()).player.y-340)<3,'Web landed from lift');}
 async function duel(){let s=await next(),oldStep=-1,evade=1900,stompStarted=false;const phases=new Set(),attacks=new Set(),end=s.frame+14000;while(s.boss.hp>0&&s.frame<end){const b=s.boss,p=s.player;phases.add(b.phase);let target=b.x-112,leap=p.step_wall;if(b.mode!==3||b.hits>=2)stompStarted=false;if(b.mode===1&&b.phase*100+b.step!==oldStep){oldStep=b.phase*100+b.step;attacks.add(b.attack);evade=p.x>b.arena_start+180?p.x-95:p.x+95;}if(b.mode===1||b.mode===2)target=b.attack===2?evade:b.x-112;else if(b.mode===3){if(b.hits>=2)target=b.x-120;else{if(p.floor)stompStarted=true;target=stompStarted?b.x:b.x-112;if(stompStarted&&Math.abs(b.x-p.x)<135)leap=true;}}else target=1910;if(b.attack===0&&s.shots.length){target=p.x;stompStarted=false;}for(const shot of s.shots)if((p.x-shot.x)*shot.dx>0&&Math.abs(p.x-shot.x)<105&&shot.y>=p.y-(p.form===0?32:64)-20&&shot.y<=p.y+10)leap=true;await controls(s,steer(p,target),leap);s=await next();}await stop();pass(s.boss.hp===0&&phases.size===3,'Web Ragnaros defeated by stomps');pass(attacks.size===3,'Web all three attack types before victory');metrics.boss_attacks=[...attacks];await shot('ragnaros-defeat');await settle(125);}
 try{
  if(level==='3-1'){await valve('FirstVent');await approach(1510,[748,1200]);await approach(1612);await settle();await valve('LowerValveA');await valve('LowerValveB');await approach(3068);await lift();await approach(3560);await settle(55);await approach(3808,[3598]);await valve('LastValve');await approach(4303,[4056]);}
  if(level==='3-2'){let s;await approach(677);await ferry('LavaCarrier',1060);await approach(1462);await settle();await valve('TowerValve');await approach(2758);await ferry('Counterweight',3150);await approach(3500);await settle(55);await approach(3800,[3522]);await approach(4008);await approach(4260,[4123]);await valve('CastingValve');await approach(4418);await ferry('LastBridge',4780);await valve('LastBreath');await approach(5543,[4978]);}
  if(level==='3-3'){await approach(201);await settle();await approach(360);await settle(55);await approach(800,[388]);await settle();await approach(1340,[822]);await approach(1442);await startBossSample();await duel();await endBossSample();await approach(3023);}
  await settle(4);const s=await observe();pass(['result','victory'].includes(s.page),'Web finish '+level);metrics[level+'_seconds']=(performance.now()-started)/1000;
 }finally{await stop();}
}
try{
 const debug=process.argv.includes('--debug');
 await open(debug?stage:release);
 metrics.loading_ms=await evaluate('performance.now()');
 await shot(debug?'debug-main':'release-main');
 await tap('F1','F1',112);
 let d=await observe();pass(d.debug===debug,'correct export type');
 if(debug){await button('Начать тестовую сессию');await button(process.argv.includes('--perf-only')?'Заново · 3-3':'Заново · 3-1');}
 else{
  pass(!d.buttons.some(b=>b.text==='Начать тестовую сессию'),'release F1 disabled');
  await button('Новая игра');await button('HeroHit_human');await button('Подтвердить выбор');
  for(const [index,level] of ['1-1','1-2','1-3'].entries())await replay(level,index);
  for(const level of ['2-1','2-2','2-3']){await button('Продолжить');await driveDurotar(level);await shot('result-'+level);await button('Следующий уровень');}
  await button('Продолжить');
 }
 const levels=process.argv.includes('--perf-only')?['3-3']:['3-1','3-2','3-3'];
 for(const [index,level] of levels.entries()){
  await shot('start-'+level);await driveMolten(level);await shot('result-'+level);
  if(index<levels.length-1){await button('Следующий уровень');await button('Продолжить');}
 }
 d=await observe();pass(d.page==='victory'&&d.profile.completed,'final victory unlocks campaign');
 metrics.final=d.profile;
 if(!debug){await sleep(1200);await send('Page.reload',{ignoreCache:true});await sleep(400);await ready();d=await observe();pass(d.page==='victory'&&d.profile.completed&&d.profile.wallet===metrics.final.wallet,'Web reload keeps victory and bank');}
 await button('Карта · все уровни');await shot('free-map');
 d=await observe();pass(d.buttons.filter(b=>b.name.startsWith('Level_')&&!b.disabled).length===9,'all nine real replay buttons enabled');
 await button('Level_3-2');await button('Играть');d=await observe();pass(d.level==='3-2'&&d.hearts===3&&d.profile.wallet===metrics.final.wallet,'replay starts with three hearts and retains bank');
 await performanceSample('replay-performance');await shot('replay-3-2');
 pass(errors.length===0,'no browser runtime errors');
 fs.writeFileSync(path.join(out,debug?('debug'+(process.argv.includes('--perf-only')?(process.argv.includes('--30')?'-perf30':'-perf60'):process.argv.includes('--30')?'-30':'')+'.json'):'release.json'),JSON.stringify({metrics,errors,requests},null,2));
 console.log('MOLTEN WEB PASS',debug?'debug':'release');
}catch(e){console.error(e);fs.writeFileSync(path.join(out,'failure-'+Date.now()+'.json'),JSON.stringify({error:String(e),metrics,errors},null,2));process.exitCode=1;}finally{await close();}
