"""Local static preview with byte ranges, so the recorded MP4s can be scrubbed."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
class Handler(SimpleHTTPRequestHandler):
    def __init__(self,*args,**kwargs):
        self.byte_range=None
        super().__init__(*args,directory=str(ROOT),**kwargs)
    def send_head(self):
        self.byte_range=None
        requested=Path(self.translate_path(self.path))
        match=re.fullmatch(r'bytes=(\d*)-(\d*)',self.headers.get('Range',''))
        if not match or not requested.is_file():return super().send_head()
        total=requested.stat().st_size
        first,last=match.groups()
        start=int(first) if first else max(0,total-int(last or total))
        end=min(int(last),total-1) if first and last else total-1
        if start>=total or end<start:
            self.send_response(416);self.send_header('Content-Range',f'bytes */{total}');self.end_headers();return None
        source=requested.open('rb');source.seek(start)
        self.byte_range=(start,end)
        self.send_response(206)
        self.send_header('Content-Type',self.guess_type(str(requested)))
        self.send_header('Content-Length',str(end-start+1))
        self.send_header('Content-Range',f'bytes {start}-{end}/{total}')
        self.send_header('Accept-Ranges','bytes')
        self.end_headers()
        return source
    def copyfile(self,source,outputfile):
        if self.byte_range is None:return super().copyfile(source,outputfile)
        remaining=self.byte_range[1]-self.byte_range[0]+1
        try:
            while remaining:
                data=source.read(min(65536,remaining))
                if not data:break
                outputfile.write(data);remaining-=len(data)
        except (ConnectionResetError,BrokenPipeError):pass
    def end_headers(self):
        if self.byte_range is None:self.send_header('Accept-Ranges','bytes')
        super().end_headers()
if __name__=='__main__':
    print(f'MARICRAFT static preview http://127.0.0.1:18780/ -> {ROOT}',flush=True)
    ThreadingHTTPServer(('127.0.0.1',18780),Handler).serve_forever()
