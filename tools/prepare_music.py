"""Create reversible runtime derivatives; originals and accepted SFX stay untouched."""
import sys,json,subprocess,hashlib,wave
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'reports/temp/music-python'))
import numpy as np
FF=ROOT/'reports/temp/s04/encoder/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v9.0.2.exe'
OUT=ROOT/'reports/evidence/p07v03-music/audio'
DST=ROOT/'assets/audio/music';DST.mkdir(parents=True,exist_ok=True)
analysis=json.loads((OUT/'source_analysis.json').read_text())
manifest={};report=[]
ids=['menu','forest','durotar','molten','bosses','ragnaros']
sr=44100
def run(args,data=None):return subprocess.run([str(FF),'-hide_banner','-nostdin','-y',*args],input=data,capture_output=True,check=True)
for i,(id,a) in enumerate(zip(ids,analysis),1):
    data=run(['-i',a['source'],'-ar',str(sr),'-ac','2','-f','f32le','pipe:1']).stdout
    y=np.frombuffer(data,np.float32).reshape(-1,2)
    choice=a['candidates'][0]
    start=round(choice['start']*sr);end=round(choice['end']*sr)
    # Move both boundaries by the same <=15ms amount to a quiet stereo crossing.
    # Phrase duration and beat count are unchanged.
    radius=round(.015*sr)
    near=y[start-radius:start+radius+1]
    shift=int(np.argmin(np.max(abs(near),axis=1)))-radius
    start+=shift;end+=shift
    gain=-22-float(a['loudness']['input_i'])
    game=y[:end].copy()*10**(gain/20)
    n=round(.06*sr)
    # Keep loop duration and beat alignment. Last 60ms approach the actual audio
    # immediately BEFORE the loop start; no overlapping/doubled next downbeat.
    fade=np.linspace(0,1,n,dtype=np.float32)[:,None]
    game[-n:]=game[-n:]*(1-fade)+y[start-n:start]*10**(gain/20)*fade
    # Vorbis block padding can change the final few samples. A 4ms guard at
    # both sides of the quiet crossing bounds that codec discontinuity.
    guard=round(.004*sr)
    game[-guard:]*=np.linspace(1,0,guard,dtype=np.float32)[:,None]
    game[start:start+guard]*=np.linspace(0,1,guard,dtype=np.float32)[:,None]
    # 8ms de-click only; retains the musical intro.
    game[:353]*=np.linspace(0,1,353,dtype=np.float32)[:,None]
    file=f'{id}_theme.ogg'
    run(['-f','f32le','-ar',str(sr),'-ac','2','-i','pipe:0','-c:a','libvorbis','-q:a','5','-metadata','comment=MARICRAFT runtime derivative; source preserved',str(DST/file)],game.astype(np.float32).tobytes())
    pcm=run(['-i',str(DST/file),'-f','f32le','-ac','2','-ar',str(sr),'pipe:1']).stdout
    decoded=np.frombuffer(pcm,np.float32).reshape(-1,2)
    jump=float(np.max(abs(decoded[-1]-decoded[start])))
    context=np.r_[decoded[-sr*4:],decoded[start:start+sr*5]]
    run(['-f','f32le','-ar',str(sr),'-ac','2','-i','pipe:0','-c:a','libvorbis','-q:a','5',str(OUT/f'{i}-{id}-loop-seam.ogg')],context.astype(np.float32).tobytes())
    # Full 15min render from the encoded derivative, independently decoded by FFmpeg.
    # Stream blocks through stdin; no 317MB intermediate files on disk.
    p=subprocess.Popen([str(FF),'-hide_banner','-nostdin','-f','f32le','-ar',str(sr),'-ac','2','-i','pipe:0','-af','ebur128=peak=true,silencedetect=noise=-50dB:d=0.20','-f','null','NUL'],stdin=subprocess.PIPE,stdout=subprocess.DEVNULL,stderr=(OUT/f'{i}-15min.log').open('w'))
    left=900*sr;loops=0
    for block in [decoded]:
        block=block[:left];p.stdin.write(block.tobytes());left-=len(block)
    while left>0:
        block=decoded[start:][:left];p.stdin.write(block.tobytes());left-=len(block);loops+=1
    p.stdin.close();code=p.wait()
    assert code==0
    manifest[id]={'file':file,'source_number':i,'loop_start':start/sr,'loop_end':len(decoded)/sr,'gain_db':gain}
    report.append({'id':id,'source_number':i,'source_sha256':a['sha256'],'source_duration':a['duration'],'file':file,'bytes':(DST/file).stat().st_size,'loop_start':start/sr,'loop_end':len(decoded)/sr,'loop_duration':(len(decoded)-start)/sr,'phrase_beats':choice['beats'],'bpm_estimate':a['bpm_estimate'],'chroma_similarity':choice['chroma'],'rhythm_correlation':choice['rhythm'],'seam_blend_seconds':.06,'seam_sample_jump_dbfs':20*np.log10(max(jump,1e-12)),'gain_db':gain,'rendered_seconds':900,'loop_returns':loops,'decode_exit':code,'subjective_listening':False})
    (DST/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
    (OUT/'runtime_analysis.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    print(id,round(len(decoded)/sr,3),'loop',round(start/sr,3),'size',round((DST/file).stat().st_size/1e6,2),'MB seam',round(report[-1]['seam_sample_jump_dbfs'],2),'dBFS',flush=True)
