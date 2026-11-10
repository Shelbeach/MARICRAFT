import fs from 'node:fs';
const p=(await(await fetch('http://127.0.0.1:18796/json/list')).json())[0];
const s=new WebSocket(p.webSocketDebuggerUrl);
s.onopen=()=>s.send(JSON.stringify({id:1,method:'Runtime.evaluate',params:{expression:'JSON.stringify({status:document.querySelector("#status")?.innerText,game:window.maricraftObservation})',returnByValue:true}}));
s.onmessage=e=>{let m=JSON.parse(e.data);if(m.id===1){let raw=JSON.parse(m.result.result.value);let g=JSON.parse(raw.game||'{}');console.log(JSON.stringify({page:g.page,level:g.level,player:g.player,hearts:g.hearts,boss:g.boss,fps:g.fps,arena:g.arena,status:raw.status}));s.close()}};
