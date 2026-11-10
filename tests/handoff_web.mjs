// Fresh, isolated headless browser. Drives real UI; telemetry is read-only.
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import fs from 'node:fs';
import path from 'node:path';
const url = process.argv[2] || 'http://127.0.0.1:18880/';
const out = path.resolve('reports/evidence/handoff/web');
const profile = path.resolve('reports/temp/handoff/edge-' + Date.now());
const port = 18915;
fs.mkdirSync(out,{recursive:true});
const sleep = ms => new Promise(r=>setTimeout(r,ms));
const checks=[], errors=[], requests=[];
let socket, sequence=0;
const pending=new Map();
function check(ok,label){checks.push({pass:!!ok,check:label});console.log(ok?'PASS':'FAIL',label);if(!ok)throw Error(label);}
async function send(method,params={}){
  const id=++sequence;
  const p=new Promise((resolve,reject)=>pending.set(id,{resolve,reject}));
  socket.send(JSON.stringify({id,method,params}));return p;
}
async function evaluate(expression){
  const r=await send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});
  if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value;
}
async function observe(){return evaluate("JSON.parse(window.maricraftObservation || '{}')");}
async function waitFor(fn){for(let i=0;i<200;i++){const d=await observe();if(fn(d))return d;await sleep(200);}throw Error('Game state timeout');}
async function key(code,key,vk,pressed){await send('Input.dispatchKeyEvent',{type:pressed?'rawKeyDown':'keyUp',code,key,windowsVirtualKeyCode:vk});}
async function tap(code,k,vk){await key(code,k,vk,true);await sleep(80);await key(code,k,vk,false);await sleep(200);}
async function button(text){
  const d=await observe(),b=d.buttons.find(b=>b.text===text||b.name===text);
  check(b&&!b.disabled,'UI button: '+text);
  for(const type of ['mousePressed','mouseReleased'])await send('Input.dispatchMouseEvent',{type,x:b.x,y:b.y,button:'left',clickCount:1});
  await sleep(300);
}
async function shot(name){const {data}=await send('Page.captureScreenshot',{format:'png'});fs.writeFileSync(path.join(out,name+'.png'),Buffer.from(data,'base64'));}
async function close(){
  try{
    const {webSocketDebuggerUrl}=await (await fetch('http://127.0.0.1:'+port+'/json/version')).json();
    const control=new WebSocket(webSocketDebuggerUrl);await once(control,'open');
    control.send(JSON.stringify({id:1,method:'Browser.close'}));
  }catch{}
  socket?.close();
}
try {
  spawn(process.env.EDGE_EXE||'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',[
    '--headless=new','--disable-background-networking','--disable-sync','--no-first-run','--disable-extensions',
    '--remote-debugging-port='+port,'--user-data-dir='+profile,'about:blank'
  ],{windowsHide:true,stdio:'ignore',env:{...process.env,TEMP:path.resolve('reports/temp/handoff'),TMP:path.resolve('reports/temp/handoff')}});
  let page;
  for(let i=0;i<100&&!page;i++){try{page=(await(await fetch('http://127.0.0.1:'+port+'/json/list')).json()).find(t=>t.type==='page');}catch{}if(!page)await sleep(200);}
  if(!page)throw Error('Headless Edge did not start');
  socket=new WebSocket(page.webSocketDebuggerUrl);await once(socket,'open');
  socket.onmessage=({data})=>{
    const m=JSON.parse(data);
    if(m.id&&pending.has(m.id)){const p=pending.get(m.id);pending.delete(m.id);m.error?p.reject(Error(m.error.message)):p.resolve(m.result);}
    if(m.method==='Runtime.exceptionThrown'||(m.method==='Runtime.consoleAPICalled'&&m.params.type==='error'))errors.push(m.params);
    if(m.method==='Network.responseReceived')requests.push({url:m.params.response.url,status:m.params.response.status,type:m.params.response.mimeType,headers:m.params.response.headers});
  };
  await send('Page.enable');await send('Runtime.enable');await send('Network.enable');
  await send('Page.addScriptToEvaluateOnNewDocument',{source:'window.MARICRAFT_QA=true;'});
  await send('Emulation.setDeviceMetricsOverride',{width:960,height:540,deviceScaleFactor:1,mobile:false});
  await send('Page.navigate',{url});
  let d=await waitFor(d=>d.page==='main');
  check(d.debug===false&&!d.sandbox,'Public release: debug=false, sandbox=false');
  check(d.buttons.find(b=>b.text==='Выбор уровней')?.disabled,'Level select remains locked on a fresh profile');
  await tap('F1','F1',112);d=await observe();
  check(!d.buttons.some(b=>b.text.includes('тестовую сессию'))&&!d.sandbox&&d.page==='main','F1 exposes no developer panel in menu');
  await shot('01-main');
  await button('Новая игра');await waitFor(d=>d.page==='heroes');
  await button('HeroHit_human');await button('Подтвердить выбор');
  await waitFor(d=>d.page==='map');await shot('02-map');
  await button('Продолжить');d=await waitFor(d=>d.page==='play'&&d.player?.floor);
  check(d.level==='1-1','Real UI starts level 1-1');
  const x=d.player.x;
  await key('KeyD','d',68,true);await sleep(500);await key('KeyD','d',68,false);
  d=await observe();check(d.player.x>x+40,'Browser keyboard moves the hero');
  const y=d.player.y;
  await key('Space',' ',32,true);await sleep(180);d=await observe();await key('Space',' ',32,false);
  check(d.player.y<y-20,'Browser keyboard triggers a jump');
  await sleep(600);await tap('F1','F1',112);d=await observe();
  check(d.page==='play'&&!d.debug&&!d.sandbox&&!d.buttons.some(b=>b.text.includes('тестовую сессию')),'F1 remains unavailable inside a level');
  check(d.audio.unlocked&&Object.keys(d.audio.events).length>0,'User interaction unlocks Web audio and triggers sound events');
  await shot('03-level');
  await tap('Escape','Escape',27);await waitFor(d=>d.page==='pause');
  check(true,'Pause input works');
  await button('Продолжить');await waitFor(d=>d.page==='play');
  await send('Page.reload',{ignoreCache:true});d=await waitFor(d=>d.page==='main');
  check(d.profile.status==='playing'&&!d.buttons.find(b=>b.text==='Продолжить')?.disabled,'Progress survives a browser reload');
  await button('Продолжить');await waitFor(d=>d.page==='play');
  for(const ext of ['.html','.js','.wasm','.pck']){
    const r=requests.find(r=>r.status===200&&(ext==='.html'?r.url===url:r.url.endsWith(ext)));
    check(!!r,'Loaded export resource '+ext);
  }
  const wasm=requests.find(r=>r.url.endsWith('.wasm'));
  check(wasm?.type==='application/wasm','WASM is served with application/wasm');
  check(requests.every(r=>r.status<400),'No HTTP errors in game requests');
  check(errors.length===0,'No browser JavaScript/runtime console errors');
} catch(error) {
  errors.push({test_error:String(error)});console.error(error);process.exitCode=1;
} finally {
  fs.writeFileSync(path.join(out,'result.json'),JSON.stringify({url,checks,errors,requests},null,2));
  await close();
}
