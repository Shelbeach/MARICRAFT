import fs from 'node:fs';
import path from 'node:path';
import {spawn} from 'node:child_process';
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const out=path.resolve('reports/evidence/p07v03-music/review');fs.mkdirSync(out,{recursive:true});
const port=18808,errors=[],media=[];let socket,seq=0;const pending=new Map();
const child=spawn('C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',[
 '--headless=new','--no-first-run','--no-default-browser-check','--autoplay-policy=no-user-gesture-required',
 '--remote-debugging-port='+port,'--user-data-dir='+path.resolve('reports/temp/p07v03-music/review-edge'),'about:blank'
],{stdio:'ignore',windowsHide:true});
async function send(method,params={}){const id=++seq;const p=new Promise((resolve,reject)=>pending.set(id,{resolve,reject}));socket.send(JSON.stringify({id,method,params}));return p;}
async function js(expression){const r=await send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value;}
async function shot(name){const r=await send('Page.captureScreenshot',{format:'png'});fs.writeFileSync(path.join(out,name+'.png'),Buffer.from(r.data,'base64'));}
try{
 let pages;
 for(let i=0;i<50;i++){try{pages=await (await fetch('http://127.0.0.1:'+port+'/json/list')).json();if(pages.length)break;}catch{}await sleep(200);}
 if(!pages?.length)throw Error('Review browser did not start');
 socket=new WebSocket(pages.find(p=>p.type==='page').webSocketDebuggerUrl);
 await new Promise(r=>socket.addEventListener('open',r,{once:true}));
 socket.addEventListener('message',({data})=>{const m=JSON.parse(data);if(m.id){const p=pending.get(m.id);pending.delete(m.id);m.error?p?.reject(m.error):p?.resolve(m.result);}else if(m.method==='Runtime.exceptionThrown')errors.push(m.params);else if(m.method==='Network.responseReceived'&&m.params.response.status>=400&&!m.params.response.url.endsWith('/favicon.ico'))errors.push(m.params.response);});
 await send('Page.enable');await send('Runtime.enable');await send('Network.enable');
 await send('Emulation.setDeviceMetricsOverride',{width:1280,height:960,deviceScaleFactor:1,mobile:false});
 await send('Page.navigate',{url:'http://127.0.0.1:18780/reports/P07_V03_MUSIC_REVIEW.html'});
 await sleep(1500);
 await js(`Promise.all([...document.images].map(img=>{img.loading='eager';return img.decode().catch(()=>null)}))`);
 const images=await js(`({total:document.images.length,broken:[...document.images].filter(i=>!i.naturalWidth).map(i=>i.src)})`);
 if(images.broken.length)throw Error('Broken images '+JSON.stringify(images.broken));
 await shot('desktop');
 const count=await js(`document.querySelectorAll('video,audio').length`);
 for(let i=0;i<count;i++){
  const result=await js(`(async()=>{const e=document.querySelectorAll('video,audio')[${i}];e.scrollIntoView({block:'center'});e.currentTime=0;await e.play();await new Promise(r=>setTimeout(r,450));const d={src:e.getAttribute('src'),duration:e.duration,time:e.currentTime,error:e.error?.message??null,width:e.videoWidth??null,height:e.videoHeight??null};e.pause();return d})()`);
  media.push(result);
  if(result.time<.1||!Number.isFinite(result.duration)||result.error)throw Error('Media playback '+JSON.stringify(result));
 }
 await js(`(async()=>{const e=document.querySelector('video');e.currentTime=20;e.scrollIntoView({block:'center'});await e.play();await new Promise(r=>setTimeout(r,500));e.pause()})()`);
 await shot('video-playing');
 await send('Emulation.setDeviceMetricsOverride',{width:640,height:900,deviceScaleFactor:1,mobile:false});
 await js('window.scrollTo(0,0)');await sleep(200);await shot('compact');
 const width=await js('({viewport:innerWidth,document:document.documentElement.scrollWidth})');
 if(width.document>width.viewport)throw Error('Horizontal page overflow');
 if(errors.length)throw Error('Browser errors '+JSON.stringify(errors));
 fs.writeFileSync(path.join(out,'result.json'),JSON.stringify({passed:true,images,media,width,errors},null,2));
 console.log('REVIEW PASS',images.total,'images;',media.length,'media streams; responsive 1280 / 640');
}catch(e){console.error(e);fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:String(e),errors,media},null,2));process.exitCode=1;}
finally{if(socket?.readyState===1){try{await send('Browser.close')}catch{}}else child.kill();}
