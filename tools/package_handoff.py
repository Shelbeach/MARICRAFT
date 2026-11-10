"""Package freshly exported builds. No engine/game changes or network access."""
import argparse
import datetime
import gzip
import hashlib
import json
from pathlib import Path
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT / 'handoff/teacher-2026-11-10')
    args = parser.parse_args()
    output = args.output.resolve()
    if not output.is_relative_to(ROOT / 'handoff'):
        raise SystemExit('Output must be inside the project handoff/ directory.')
    web, windows = output / 'web', output / 'windows'
    for path in [web / ('index' + ext) for ext in ['.html', '.js', '.wasm', '.pck']] + [windows / 'MARICRAFT.exe', windows / 'MARICRAFT.pck']:
        if not path.is_file() or path.stat().st_size == 0:
            raise SystemExit(f'Missing fresh export: {path}')

    public = ROOT / 'deploy/web'
    public.mkdir(parents=True, exist_ok=True)
    # An explicit inventory prevents stale/debug exports from silently entering the image.
    allowed = {'.html', '.js', '.wasm', '.pck', '.png', '.svg', '.ico'}
    files = sorted(p for p in web.iterdir() if p.is_file() and p.suffix in allowed)
    expected = {p.name + ('.gz' if p.suffix in {'.js', '.wasm', '.pck'} else '') for p in files}
    stale = {p.name for p in public.iterdir() if p.is_file()} - expected - {'SHA256SUMS', 'build-manifest.json'}
    if stale:
        raise SystemExit(f'Unexpected existing deployment files; review them first: {sorted(stale)}')
    for source in files:
        if source.suffix in {'.js', '.wasm', '.pck'}:
            with source.open('rb') as src, (public / (source.name + '.gz')).open('wb') as dest:
                with gzip.GzipFile(filename='', mode='wb', fileobj=dest, compresslevel=9, mtime=0) as compressed:
                    shutil.copyfileobj(src, compressed)
        else:
            shutil.copy2(source, public / source.name)

    inputs = [ROOT / name for name in ['project.godot', 'export_presets.cfg']]
    for folder in ['scripts', 'scenes', 'assets', 'addons']:
        inputs.extend(p for p in (ROOT / folder).rglob('*') if p.is_file())
    source_hashes = {p.relative_to(ROOT).as_posix(): digest(p) for p in sorted(inputs)}
    manifest = {
        'created_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'godot': '4.7.2 Standard', 'preset': 'Web', 'mode': 'release', 'threads': False,
        'source_sha256': hashlib.sha256(json.dumps(source_hashes, sort_keys=True).encode()).hexdigest(),
        'files': {p.name: {'bytes': p.stat().st_size, 'sha256': digest(p)} for p in files},
    }
    (public / 'build-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8', newline='\n')
    (output / 'source-manifest.json').write_text(json.dumps(source_hashes, indent=2) + '\n', encoding='utf-8')
    public_files = sorted(p for p in public.iterdir() if p.is_file() and p.name != 'SHA256SUMS')
    for path in public_files:
        if path.stat().st_size >= 100 * 1024**2:
            raise SystemExit(f'File exceeds the GitHub 100 MiB limit: {path}')
    (public / 'SHA256SUMS').write_text(''.join(f'{digest(p)}  {p.name}\n' for p in public_files), encoding='ascii', newline='\n')

    shutil.copy2(ROOT / 'docs/TEACHER_WINDOWS_README.txt', windows / 'README.txt')
    archive = output / 'MARICRAFT_Windows_x64_GodMode.zip'
    # Only the standalone runtime, its packed game, and the teacher's instructions.
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as zipped:
        for name in ['MARICRAFT.exe', 'MARICRAFT.pck', 'README.txt']:
            zipped.write(windows / name, 'MARICRAFT/' + name)
    with zipfile.ZipFile(archive) as zipped:
        if zipped.testzip() is not None:
            raise SystemExit('ZIP CRC verification failed.')
    (output / 'SHA256SUMS.txt').write_text(f'{digest(archive)}  {archive.name}\n', encoding='ascii')
    print(f'Public deployment: {sum(p.stat().st_size for p in public.iterdir() if p.is_file()):,} bytes')
    print(f'Windows ZIP: {archive.stat().st_size:,} bytes; CRC verified')
    print('Handoff:', output)


if __name__ == '__main__':
    main()
