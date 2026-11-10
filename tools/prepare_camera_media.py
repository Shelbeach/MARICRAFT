from pathlib import Path
import subprocess,sys
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'reports/temp/forest-art/python'))
from PIL import Image,ImageDraw
base=root/'reports/evidence/camera-repair'
out=base/'media';out.mkdir(exist_ok=True)
ff=root/'reports/temp/s04/encoder/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v9.0.2.exe'
for label,prefix in [('camera',''),('long','long-'),('elevation','elevation-'),('boss','boss-')]:
    for variant in ['before','after']:
        source=base/'web'/f'{prefix}{variant}-human-1-60-960'/'camera.webm'
        if not source.exists():raise RuntimeError(f'Missing {source}')
        dest=out/f'{label}-{variant}.mp4'
        subprocess.run([str(ff),'-v','error','-y','-i',str(source),'-an','-c:v','libx264','-threads','2','-preset','fast','-crf','21','-pix_fmt','yuv420p','-movflags','+faststart',str(dest)],check=True)
        frames=out/f'{label}-{variant}-frames';frames.mkdir(exist_ok=True)
        subprocess.run([str(ff),'-v','error','-y','-i',str(source),'-vf','fps=1,scale=480:270','-frames:v','24',str(frames/'%03d.png')],check=True)
        files=sorted(frames.glob('*.png'))
        for page in range((len(files)+11)//12):
            chunk=files[page*12:(page+1)*12]
            image=Image.new('RGB',(1440,294*((len(chunk)+2)//3)),'#101922');draw=ImageDraw.Draw(image)
            for i,p in enumerate(chunk):
                x=i%3*480;y=i//3*294
                image.paste(Image.open(p),(x,y+24));draw.text((x+8,y+5),f'{label} {variant} / second {int(p.stem)-1}',fill='white')
            image.save(out/f'{label}-{variant}-review-{page}.jpg',quality=91)
        print('PREPARED',label,variant,len(files),'frames',flush=True)
