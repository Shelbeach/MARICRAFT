import sys,json,subprocess,re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'reports/temp/forest-art/python'))
from PIL import Image,ImageDraw
ff=root/'reports/temp/s04/encoder/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v9.0.2.exe'
base=root/'reports/evidence/p07v03-music'
records=[]
for p in (base/'video').glob('*.mp4'):
    result=subprocess.run([str(ff),'-hide_banner','-i',str(p),'-af','volumedetect','-f','null','NUL'],capture_output=True)
    log=result.stderr.decode(errors='replace')
    (base/'video'/(p.stem+'-decode.log')).write_text(log)
    duration=re.search(r'Duration: (\d+):(\d+):([\d.]+)',log)
    seconds=int(duration[1])*3600+int(duration[2])*60+float(duration[3])
    captures=base/'video'/p.stem;captures.mkdir(exist_ok=True)
    subprocess.run([str(ff),'-loglevel','error','-y','-i',str(p),'-vf','fps=2,scale=480:-1',str(captures/'%04d.jpg')],check=True)
    files=sorted(captures.glob('*.jpg'))
    for page in range((len(files)+15)//16):
        part=files[page*16:page*16+16]
        sheet=Image.new('RGB',(1920,294*((len(part)+3)//4)),(20,24,31));d=ImageDraw.Draw(sheet)
        for i,f in enumerate(part):
            x=i%4*480;y=i//4*294
            sheet.paste(Image.open(f),(x,y+24));d.text((x+10,y+6),f'{p.stem} / {(page*16+i)/2:.1f}s',fill='white')
        sheet.save(base/'contact'/f'{p.stem}-{page}.jpg',quality=88)
    records.append({'file':p.name,'seconds':seconds,'size_bytes':p.stat().st_size,'decode_exit':result.returncode,'audio_present':'Audio: aac' in log,'peak_db':re.findall(r'max_volume: ([-\d.]+)',log),'mean_db':re.findall(r'mean_volume: ([-\d.]+)',log),'review_frames_2fps':len(files)})
for p in (base/'audio').glob('godot-*-seam.f32'):
    subprocess.run([str(ff),'-v','error','-y','-f','f32le','-ar','44100','-ac','2','-i',str(p),'-c:a','libvorbis','-q:a','5',str(p.with_suffix('.ogg'))],check=True)
(base/'video/media-audit.json').write_text(json.dumps(records,indent=2))
print(records)
