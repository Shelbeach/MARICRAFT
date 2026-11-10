// Validate the generated evidence page in an independent, hidden browser.
import {spawn} from 'node:child_process';
import {once} from 'node:events';
import fs from 'node:fs';
import path from 'node:path';
const port=18829, temp=path.resolve('reports/temp/camera-repair');
const out=path.resolve('reports/evidence/camera-repair');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
let ws,seq=0;const pending=new Map(),errors=[];
async function send(method,params={}){const id=++seq;const result=new Promise((resolve,reject)=>pending.set(id,{resolve,reject}));ws.send(JSON.stringify({id,method,params}));return result}
async function evaluate(expression){const r=await send('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value}
function check(value,label){if(!value)throw Error(label);console.log('PASS',label)}
try{
  spawn('C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',[
    '--headless=new','--disable-background-networking','--disable-sync','--no-first-run','--disable-extensions',
    '--remote-debugging-port='+port,'--user-data-dir='+path.join(temp,'report-'+Date.now()),'about:blank'
  ],{windowsHide:true,stdio:'ignore',env:{...process.env,TEMP:temp,TMP:temp}});
  let page;
  for(let i=0;i<100&&!page;i++){try{page=(await(await fetch('http://127.0.0.1:'+port+'/json/list')).json()).find(t=>t.type==='page'&&t.url==='about:blank')}catch{}if(!page)await sleep(150)}
  ws=new WebSocket(page.webSocketDebuggerUrl);await once(ws,'open');
  ws.onmessage=({data})=>{const m=JSON.parse(data);if(m.id&&pending.has(m.id)){const p=pending.get(m.id);pending.delete(m.id);m.error?p.reject(Error(m.error.message)):p.resolve(m.result)}if(m.method==='Runtime.exceptionThrown')errors.push(m.params);if(m.method==='Network.responseReceived'&&m.params.response.status>=400)errors.push(m.params.response)};
  await send('Runtime.enable');await send('Page.enable');await send('Network.enable');
  await send('Emulation.setDeviceMetricsOverride',{width:1280,height:900,deviceScaleFactor:1,mobile:false});
  await send('Page.navigate',{url:'http://127.0.0.1:18780/reports/CAMERA_REPAIR_REVIEW.html'});
  for(let i=0;i<100;i++){if(await evaluate('document.readyState==="complete"'))break;await sleep(100)}
  check(await evaluate('document.querySelectorAll(".comparison").length===5'),'five comparison pairs');
  check(await evaluate('files.length===100'),'100 atlas images');
  const images=await evaluate(`(async()=>{let count=0;for(const filename of files){for(const dir of Object.values(paths)){const image=new Image();image.src=dir+filename;await image.decode();if(image.naturalWidth!==960||image.naturalHeight!==540)throw Error(filename);count++}}return count})()`);
  check(images===300,'all 300 before/accepted/after images load');
  const durations=await evaluate(`Promise.all([...document.querySelectorAll('video')].map(v=>new Promise((resolve,reject)=>{const done=()=>resolve({src:v.getAttribute('src'),duration:v.duration,width:v.videoWidth,height:v.videoHeight});if(v.readyState>=1)done();else{v.addEventListener('loadedmetadata',done,{once:true});v.addEventListener('error',()=>reject(Error(v.src)),{once:true})}})))`);
  check(durations.every(v=>Number.isFinite(v.duration)&&v.duration>3&&v.width>0),'all videos decode metadata');
  await evaluate('document.querySelector(".sync").click()');await sleep(600);
  check(await evaluate('[...document.querySelectorAll(".comparison:first-of-type video")].every(v=>v.currentTime>0&&!v.paused)'),'paired playback works');
  await evaluate('document.querySelector(".pause").click()');
  let shot=await send('Page.captureScreenshot',{format:'png'});fs.writeFileSync(path.join(out,'review-desktop.png'),Buffer.from(shot.data,'base64'));
  await send('Emulation.setDeviceMetricsOverride',{width:640,height:900,deviceScaleFactor:1,mobile:false});
  check(await evaluate('document.documentElement.scrollWidth<=640'),'640px report has no horizontal overflow');
  await evaluate(`document.getElementById('level').value='2-2';document.getElementById('level').dispatchEvent(new Event('change'));document.getElementById('version').value='accepted';document.getElementById('version').dispatchEvent(new Event('change'));document.getElementById('levels').scrollIntoView()`);
  check(await evaluate(`document.querySelectorAll('#gallery img').length===16&&document.querySelector('#gallery img').src.includes('final-polish/before')`),'level and comparison switches work');
  await sleep(300);shot=await send('Page.captureScreenshot',{format:'png'});fs.writeFileSync(path.join(out,'review-mobile.png'),Buffer.from(shot.data,'base64'));
  if(errors.length)console.error(JSON.stringify(errors,null,2));
  check(errors.length===0,'report has no runtime errors or HTTP failures');
  fs.writeFileSync(path.join(out,'report-check.json'),JSON.stringify({images,durations,errors,desktop:[1280,900],mobile:[640,900]},null,2));
}catch(error){console.error(error);process.exitCode=1}
finally{
  try{const version=await(await fetch('http://127.0.0.1:'+port+'/json/version')).json();const browser=new WebSocket(version.webSocketDebuggerUrl);await once(browser,'open');browser.send(JSON.stringify({id:1,method:'Browser.close'}));browser.close();ws?.close()}catch{}
}
