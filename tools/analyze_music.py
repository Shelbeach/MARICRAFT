"""Decode all originals and rank repeated, beat-aligned phrase boundaries.
This is objective analysis, not a substitute for listening approval.
"""
import sys,json,subprocess,re,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'reports/temp/music-python'))
import numpy as np
from scipy import signal
FF=ROOT/'reports/temp/s04/encoder/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v9.0.2.exe'
OUT=ROOT/'reports/evidence/p07v03-music/audio'
OUT.mkdir(parents=True,exist_ok=True)
TMP=ROOT/'reports/temp/p07v03-music';TMP.mkdir(parents=True,exist_ok=True)
def run(args):return subprocess.run([str(FF),'-hide_banner','-nostdin',*args],capture_output=True,check=True)
results=[]
for i in range(1,7):
    src=Path.home()/'Downloads'/f'{i}.mp3'
    p=run(['-i',str(src),'-af','loudnorm=print_format=json,silencedetect=noise=-50dB:d=0.15','-f','null','NUL'])
    log=p.stderr.decode(errors='replace');(OUT/f'source-{i}.log').write_text(log)
    loud=json.loads(re.findall(r'\{\s*"input_i".*?\}',log,re.S)[-1])
    sr=11025;hop=256
    pcm=run(['-i',str(src),'-ac','1','-ar',str(sr),'-f','f32le','pipe:1']).stdout
    y=np.frombuffer(pcm,np.float32)
    np.save(TMP/f'{i}-mono.npy',y)
    _,t,z=signal.stft(y,sr,nperseg=2048,noverlap=2048-hop)
    mag=np.abs(z).astype(np.float32)
    flux=np.maximum(0,np.diff(np.log1p(mag*60),axis=1)).sum(axis=0)
    flux=np.r_[0,flux];flux/=max(np.std(flux),1e-9)
    ac=signal.fftconvolve(flux-flux.mean(),(flux-flux.mean())[::-1],mode='full')[len(flux)-1:]
    lagmin=int(sr/hop*60/170);lagmax=int(sr/hop*60/68)
    lag=lagmin+np.argmax(ac[lagmin:lagmax]);period=lag*hop/sr
    # Refine the constant grid against onsets, then use actual nearby peaks.
    periods=np.linspace(period*.96,period*1.04,161)
    best=(-1,None,None)
    dur=len(y)/sr
    for per in periods:
        for off in np.linspace(0,per,32,endpoint=False):
            grid=np.arange(off,dur-3,per);ix=np.minimum((grid*sr/hop).astype(int),len(flux)-1)
            score=np.mean(flux[ix])
            if score>best[0]:best=(score,per,off)
    _,period,offset=best
    grid=np.arange(offset,dur-3,period)
    beats=[]
    for pos in grid:
        k=int(pos*sr/hop);r=max(1,int(period*.16*sr/hop));a=max(0,k-r);b=min(len(flux),k+r+1)
        beats.append(float((a+np.argmax(flux[a:b]))*hop/sr))
    # Harmonic and envelope context on both sides, not mere zero-crossings.
    freqs=np.fft.rfftfreq(2048,1/sr)
    chroma=np.zeros((12,mag.shape[1]),np.float32)
    for k,f in enumerate(freqs):
        if 70<f<4000:chroma[int(round(69+12*np.log2(f/440)))%12]+=mag[k]
    chroma/=np.maximum(np.linalg.norm(chroma,axis=0),1e-8)
    env=np.log(np.maximum(np.sqrt(np.mean(mag*mag,axis=0)),1e-8))
    candidates=[]
    step=sr/hop
    for a in range(8,len(beats)-70):
        if beats[a]>dur*.55:break
        for n in range(64,len(beats)-a,16):
            b=a+n
            if beats[b]>dur-7 or beats[b]-beats[a]<45:continue
            ka=int(beats[a]*step);kb=int(beats[b]*step)
            offsets=np.arange(-int(period*4*step),int(period*4*step),3)
            ia=np.clip(ka+offsets,0,len(flux)-1);ib=np.clip(kb+offsets,0,len(flux)-1)
            tonal=float(np.mean(np.sum(chroma[:,ia]*chroma[:,ib],axis=0)))
            rhythm=float(np.corrcoef(flux[ia],flux[ib])[0,1])
            volume=float(np.mean(abs(env[ia]-env[ib])))
            score=tonal+.23*rhythm-.18*volume
            candidates.append(dict(start=beats[a],end=beats[b],beats=n,seconds=beats[b]-beats[a],score=score,chroma=tonal,rhythm=rhythm,log_rms_difference=volume))
    candidates.sort(key=lambda c:c['score'],reverse=True)
    result=dict(source=str(src),sha256=hashlib.sha256(src.read_bytes()).hexdigest(),duration=dur,loudness=loud,bpm_estimate=60/period,beat_seconds=period,leading_silence=re.findall(r'silence_(?:start|end): [^\r\n]+',log),candidates=candidates[:12],subjective_listening=False)
    results.append(result)
    (OUT/'source_analysis.json').write_text(json.dumps(results,indent=2),encoding='utf8')
    print(i,'duration',round(dur,2),'LUFS',loud['input_i'],'bpm',round(60/period,2),'candidate',candidates[0],flush=True)
