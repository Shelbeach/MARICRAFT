import {spawn} from 'node:child_process';
import {once} from 'node:events';
import fs from 'node:fs';
import path from 'node:path';
const out=path.resolve('reports/evidence/campaign-polish'), temp=path.resolve('reports/temp/campaign-polish');
const port=18797, errors=[], result={};
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
let ws,seq=0;const pending=new Map();
async function send(method,params={}){const id=++seq;const reply=new Promise((resolve,reject)=>pending.set(id,{resolve,reject}));ws.send(JSON.stringify({id,method,params}));return reply;}
async function evaluate(expression){const r=await send('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value;}
async function screenshot(name){const r=await send('Page.captureScreenshot',{format:'png'});fs.writeFileSync(path.join(out,name+'.png'),Buffer.from(r.data,'base64'));}
try{
 spawn('C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',['--headless=new','--disable-extensions','--disable-sync','--disable-background-networking','--no-first-run','--remote-debugging-port='+port,'--user-data-dir='+path.join(temp,'review-'+Date.now()),'about:blank'],{windowsHide:true,stdio:'ignore',env:{...process.env,TEMP:temp,TMP:temp}});
 let page;for(let i=0;i<100&&!page;i++){try{page=(await(await fetch(`http://127.0.0.1:${port}/json/list`)).json()).find(p=>p.type==='page'&&p.url==='about:blank');}catch{}if(!page)await sleep(100);}
 ws=new WebSocket(page.webSocketDebuggerUrl);await once(ws,'open');
 ws.onmessage=({data})=>{const m=JSON.parse(data);if(m.id&&pending.has(m.id)){const p=pending.get(m.id);pending.delete(m.id);m.error?p.reject(Error(m.error.message)):p.resolve(m.result);}if(m.method==='Runtime.exceptionThrown')errors.push(m.params);};
 await send('Runtime.enable');await send('Page.enable');
 result.browser=await send('Browser.getVersion');
 await send('Emulation.setDeviceMetricsOverride',{width:1160,height:860,deviceScaleFactor:1,mobile:false});
 await send('Page.navigate',{url:'http://127.0.0.1:18780/reports/CAMPAIGN_POLISH_REVIEW.html'});
 for(let i=0;i<100;i++){if(await evaluate(`document.readyState==='complete'&&[...document.querySelectorAll('video')].every(v=>v.readyState>=1)`))break;await sleep(200);}
 await evaluate(`[...document.images].forEach(i=>i.loading='eager')`);
 for(let i=0;i<100;i++){if(await evaluate(`[...document.images].every(i=>i.complete&&i.naturalWidth>0)`))break;await sleep(200);}
 result.images=await evaluate(`[...document.images].map(i=>({src:i.getAttribute('src'),loaded:i.complete&&i.naturalWidth>0}))`);
 result.videos=await evaluate(`[...document.querySelectorAll('video')].map(v=>({src:v.getAttribute('src'),duration:v.duration,width:v.videoWidth,height:v.videoHeight,error:v.error?.message??null}))`);
 if(result.images.some(i=>!i.loaded)||result.videos.some(v=>v.error||!(v.duration>=3)))throw Error('Missing media');
 await screenshot('review-desktop');
 await evaluate(`(async()=>{const v=document.querySelector('video');v.muted=true;await v.play();v.scrollIntoView({block:'center'})})()`);await sleep(1800);
 result.playback=await evaluate(`(()=>{const v=document.querySelector('video');return {time:v.currentTime,paused:v.paused,frames:v.getVideoPlaybackQuality().totalVideoFrames}})()`);
 if(result.playback.paused||result.playback.time<1)throw Error('Video did not advance');
 await screenshot('review-playing');
 await evaluate(`new Promise(resolve=>{const v=document.querySelector('video');v.pause();v.addEventListener('seeked',()=>resolve(true),{once:true});v.currentTime=Math.max(0,v.duration-1)})`);
 await sleep(250);
 result.seek=await evaluate(`(()=>{const v=document.querySelector('video');return {time:v.currentTime,target:Math.max(0,v.duration-1)}})()`);
 if(Math.abs(result.seek.time-result.seek.target)>0.2)throw Error('Video seeking failed');
 await screenshot('review-video-victory');
 result.allPlayback=[];
 for(let i=0;i<result.videos.length;i++){
  await evaluate(`(async()=>{document.querySelectorAll('video').forEach(v=>v.pause());const v=document.querySelectorAll('video')[${i}];v.currentTime=0;v.muted=true;v.scrollIntoView({block:'center'});await v.play()})()`);
  await sleep(1100);
  const row=await evaluate(`(()=>{const v=document.querySelectorAll('video')[${i}];return {src:v.getAttribute('src'),time:v.currentTime,paused:v.paused,frames:v.getVideoPlaybackQuality().totalVideoFrames,error:v.error?.message??null}})()`);
  if(row.paused||row.time<0.5||row.error)throw Error('Clip playback failed '+row.src);
  await evaluate(`new Promise(resolve=>{const v=document.querySelectorAll('video')[${i}];v.pause();v.addEventListener('seeked',()=>resolve(true),{once:true});v.currentTime=v.duration*0.6})`);
  row.seek=await evaluate(`document.querySelectorAll('video')[${i}].currentTime`);
  result.allPlayback.push(row);
 }
 await send('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:1,mobile:false});
 await evaluate('window.scrollTo(0,0)');await sleep(250);
 result.mobile=await evaluate(`({width:innerWidth,body:document.documentElement.scrollWidth})`);
 if(result.mobile.body>result.mobile.width)throw Error('Page overflows mobile viewport');
 await screenshot('review-mobile');
 if(errors.length)throw Error('Runtime error');
 result.errors=errors;result.success=true;
 console.log('CAMPAIGN POLISH REVIEW PASS',result.videos,result.playback,result.mobile);
}catch(e){result.success=false;result.error=String(e);console.error(e);process.exitCode=1;}
finally{fs.writeFileSync(path.join(out,'review-browser.json'),JSON.stringify(result,null,2));if(ws?.readyState===WebSocket.OPEN){try{await send('Browser.close');}catch{}ws.close();}}
