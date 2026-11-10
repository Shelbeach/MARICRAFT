from pathlib import Path
root=Path(__file__).resolve().parents[1]
base=(root/'tests/p07v03_web.mjs').read_text(encoding='utf8').split('\ntry{\n const debug=')[0]
base=base.replace('const port = 18806;','const port = 18807;').replace("const out='reports/evidence/p07v03-music/web/'+variant;","const out='reports/evidence/p07v03-music/web/music-loops';")
extra=r'''
const loopManifest=JSON.parse(fs.readFileSync('assets/audio/music/manifest.json','utf8'));
async function waitTheme(id){
 for(let i=0;i<60;i++){const d=await observe();if(d.music.theme===id && d.music.voices.length===1)return d;await sleep(100);}
 throw Error('Expected soundtrack '+id+': '+JSON.stringify(await observe()));
}
async function loop(id){
 let d=await waitTheme(id);const start=performance.now();
 await evaluate(`window.__loopChunks=[];window.__loopRecorder=new MediaRecorder(window.__captureAudio,{mimeType:'audio/webm;codecs=opus'});window.__loopRecorder.ondataavailable=e=>{window.__loopChunks.push(e.data);if(window.__loopChunks.length>10)window.__loopChunks.shift()};window.__loopRecorder.start(1000)`);
 let previous=d.music.voices[0].position,wrapped=false;
 console.log('LOOP WAIT',id,previous,'end',loopManifest[id].loop_end);
 while(performance.now()-start<(loopManifest[id].loop_end+12)*1000){
  await sleep(250);d=await observe();
  pass(d.music.theme===id,'loop stable '+id);
  const position=d.music.voices.find(v=>v.id===id).position;
  if(position<previous-5){
   const expected=loopManifest[id].loop_start;
   if(Math.abs(position-expected)>1.5)throw Error('Wrong loop target '+id+' '+position+' '+expected);
   metrics[id]={wrap_from:previous,wrap_to:position,expected,wall_seconds:(performance.now()-start)/1000,voices:d.music.voices.length};
   wrapped=true;break;
  }
  previous=position;
 }
 if(!wrapped)throw Error('No actual Web loop '+id);
 await sleep(2300);await audioSample(id+'-audio');
 await evaluate(`new Promise(resolve=>{window.__loopRecorder.onstop=resolve;window.__loopRecorder.stop()})`);
 // Chunk zero contains the WebM header. Save the complete short loop audit via
 // metrics; audio evidence is provided by the separate native seam captures.
 pass(metrics[id+'-audio'].peak>0.0001,'audible stream after wrap '+id);
 console.log('LOOP PASS',id,metrics[id]);
 fs.writeFileSync(path.join(out,'loops-progress.json'),JSON.stringify({metrics,errors},null,2));
}
async function restart(id){await tap('F1','F1',112);await button('Заново · '+id);await sleep(800);}
async function boss(id){
 await restart(id);await tap('F1','F1',112);
 // The last debug actions are clipped by their scroll container. Scroll using
 // real wheel input, then re-read their on-screen coordinates before clicking.
 await send('Input.dispatchMouseEvent',{type:'mouseWheel',x:480,y:320,deltaX:0,deltaY:650});await sleep(300);
 const d=await observe();const entry=d.buttons.find(b=>b.text.startsWith('Босс ·'));
 await button(entry.text);await sleep(700);await key('KeyD','d',68,true);await sleep(450);await key('KeyD','d',68,false);await sleep(150);
}
try{
 await open(stage);await click(480,130);await sleep(1500);
 const resume=process.argv.includes('--bosses-only');
 if(resume)Object.assign(metrics,JSON.parse(fs.readFileSync(path.join(out,'loops-progress.json'),'utf8')).metrics);
 else await loop('menu');
 await tap('F1','F1',112);await button('Начать тестовую сессию');await button('Заново · 1-1');await sleep(700);
 if(!resume){
  await tap('Escape','Escape',27);await loop('forest');
  await restart('2-1');await tap('Escape','Escape',27);await loop('durotar');
  await restart('3-1');await tap('Escape','Escape',27);await loop('molten');
 }
 await boss('1-3');await tap('Escape','Escape',27);await loop('bosses');
 await boss('3-3');await tap('Escape','Escape',27);await loop('ragnaros');
 pass(errors.length===0,'no Web audio soak runtime errors');
 fs.writeFileSync(path.join(out,'loops.json'),JSON.stringify({metrics,errors},null,2));
 console.log('ALL SIX WEB LOOPS PASS');
}catch(e){console.error(e);fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:String(e),metrics,errors},null,2));process.exitCode=1;}finally{await close();}
'''
# Frequent identical loop observations belong in the machine log, not stdout.
extra=extra.replace("pass(d.music.theme===id,'loop stable '+id);","if(d.music.theme!==id)throw Error('Theme changed during loop '+id);")
(root/'tests/p07v03_loop_web.mjs').write_text(base+extra,encoding='utf8')
