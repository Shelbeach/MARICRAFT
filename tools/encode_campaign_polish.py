from pathlib import Path
import subprocess,sys
root=Path(__file__).resolve().parents[1]
ff=root/'reports/temp/s04/encoder/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v9.0.2.exe'
dest=root/'reports/evidence/campaign-polish/video';dest.mkdir(exist_ok=True)
for source,fps in [('frames',20),('continuous',15)]:
    for folder in (root/'reports/temp/campaign-polish'/source).glob('*'):
        if not folder.is_dir() or not list(folder.glob('*.png')):continue
        if sys.argv[1:] and folder.name not in sys.argv[1:]:continue
        out=dest/(folder.name+'.mp4')
        # A shorter repeat can leave older scratch frames at the end; encode only
        # the current contiguous take without deleting historical scratch files.
        first=(folder/'00000.png').stat().st_mtime
        count=0
        while (p:=folder/f'{count:05d}.png').exists() and p.stat().st_mtime>=first-1:
            count+=1
        subprocess.run([str(ff),'-y','-loglevel','error','-framerate',str(fps),'-i',str(folder/'%05d.png'),'-frames:v',str(count),'-c:v','libx264','-preset','fast','-crf','20','-pix_fmt','yuv420p','-movflags','+faststart',str(out)],check=True)
        print(out.relative_to(root),out.stat().st_size,flush=True)
