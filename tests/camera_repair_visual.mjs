// Dedicated headless Edge only. Never attaches to the user's browser/desktop.
import {spawn} from 'node:child_process';
import {once} from 'node:events';
import fs from 'node:fs';
import path from 'node:path';
const arg=(key,fallback)=>process.argv.find(a=>a.startsWith('--'+key+'='))?.split('=')[1]??fallback;
const options={mode:arg('mode','camera'),form:Number(arg('form',0)),hero:arg('hero','human'),before:process.argv.includes('--before')};
const width=Number(arg('width',960)),fps=Number(arg('fps',60)),port=Number(arg('port',18816));
const tag=options.mode==='atlas'?'atlas':`${options.mode==='camera'?'':options.mode+'-'}${options.before?'before':'after'}-${options.hero}-${options.form}-${fps}-${width}`;
const out=path.resolve('reports/evidence',arg('evidence','camera-repair'),'web',tag);fs.mkdirSync(out,{recursive:true});
const temp=path.resolve('reports/temp/camera-repair');fs.mkdirSync(temp,{recursive:true});
const profile=path.join(temp,'edge-'+Date.now());
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
let socket,seq=0;const pending=new Map(),errors=[];
async function send(method,params={}){const id=++seq;const promise=new Promise((resolve,reject)=>pending.set(id,{resolve,reject}));socket.send(JSON.stringify({id,method,params}));return promise;}
async function evaluate(expression){const r=await send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value;}
async function snap(name){const r=await send('Page.captureScreenshot',{format:'png'});fs.writeFileSync(path.join(out,name+'.png'),Buffer.from(r.data,'base64'));}
async function record(){await evaluate(`(()=>{window.chunks=[];window.recorder=new MediaRecorder(document.querySelector('canvas').captureStream(30),{mimeType:'video/webm;codecs=vp8',videoBitsPerSecond:2800000});recorder.ondataavailable=e=>{if(e.data.size)chunks.push(e.data)};recorder.start(1000)})()`);}
async function saveVideo(){const b64=await evaluate(`new Promise(resolve=>{recorder.onstop=async()=>{const bytes=new Uint8Array(await new Blob(chunks).arrayBuffer());let text='';for(let i=0;i<bytes.length;i+=32768)text+=String.fromCharCode(...bytes.subarray(i,i+32768));resolve(btoa(text))};recorder.stop()})`);fs.writeFileSync(path.join(out,'camera.webm'),Buffer.from(b64,'base64'));}
async function close(){try{const info=await(await fetch('http://127.0.0.1:'+port+'/json/version')).json();const ws=new WebSocket(info.webSocketDebuggerUrl);await once(ws,'open');ws.send(JSON.stringify({id:1,method:'Browser.close'}));ws.close();socket?.close();}catch{}}
try{
 spawn('C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',['--headless=new','--disable-background-networking','--disable-sync','--no-first-run','--disable-extensions','--remote-debugging-port='+port,'--user-data-dir='+profile,'about:blank'],{windowsHide:true,stdio:'ignore',env:{...process.env,TEMP:temp,TMP:temp}});
 let page;for(let i=0;i<100&&!page;i++){try{page=(await(await fetch('http://127.0.0.1:'+port+'/json/list')).json()).find(t=>t.type==='page'&&t.url==='about:blank')}catch{}if(!page)await sleep(150)}
 if(!page)throw Error('Headless browser did not start');socket=new WebSocket(page.webSocketDebuggerUrl);await once(socket,'open');
 socket.onmessage=({data})=>{const m=JSON.parse(data);if(m.id&&pending.has(m.id)){const p=pending.get(m.id);pending.delete(m.id);m.error?p.reject(Error(m.error.message)):p.resolve(m.result)}if(m.method==='Runtime.exceptionThrown'||m.method==='Runtime.consoleAPICalled'&&m.params.type==='error')errors.push({type:m.params.type,text:(m.params.args||[]).map(a=>a.value).join(' '),exception:m.params.exceptionDetails?.text})};
 await send('Runtime.enable');await send('Page.enable');await send('Emulation.setDeviceMetricsOverride',{width,height:width*9/16,deviceScaleFactor:1,mobile:false});
 let source=`window.cameraOptions=${JSON.stringify(JSON.stringify(options))};window.cameraAck='';window.MARICRAFT_QA=true;`;
 if(fps===30)source+=`const realRAF=window.requestAnimationFrame.bind(window);let serial=0,last=0;const queue=new Map();window.requestAnimationFrame=cb=>{const id=++serial;queue.set(id,cb);return id};window.cancelAnimationFrame=id=>queue.delete(id);realRAF(function pump(t){if(t-last>=32.8){last=t;const callbacks=[...queue.values()];queue.clear();for(const cb of callbacks)cb(t)}realRAF(pump)});`;
 await send('Page.addScriptToEvaluateOnNewDocument',{source});
 await send('Page.navigate',{url:'http://127.0.0.1:18780/exports/'+arg('build','camera-repair-qa')+'/'});
 let last='',started=Date.now(),recording=false,done=false;
 while(Date.now()-started<300000){
  const s=await evaluate("JSON.parse(window.cameraQa||'{}')");
  if(s.capture&&s.capture!==last){last=s.capture;await snap(last);if(last==='ready'){await record();recording=true}console.log('CAPTURE',tag,last);await evaluate(`window.cameraAck=${JSON.stringify(last)}`)}
  if(s.done){if(recording)await saveVideo();fs.writeFileSync(path.join(out,'result.json'),JSON.stringify({...s,errors},null,2));console.log('DONE',tag,'samples',s.telemetry?.length,'errors',errors.length);done=true;break}
  if(errors.length)throw Error(JSON.stringify(errors).slice(0,3000));await sleep(40);
 }
 if(!done)throw Error('Visual fixture timed out');
}catch(error){fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({message:String(error),errors},null,2));console.error(error);process.exitCode=1;}finally{await close()}
