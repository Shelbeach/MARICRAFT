from pathlib import Path
import json
import subprocess
import sys

root=Path(__file__).resolve().parents[1]
base=root/'reports/evidence/arena-polish'
media=base/'media';media.mkdir(exist_ok=True)
ff=root/'reports/temp/s04/encoder/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v9.0.2.exe'
sys.path.insert(0,str(root/'reports/temp/forest-art/python'))
from PIL import Image,ImageDraw

for name,source,filename,fps in [
    ('rune','arena_rune-after-human-0-60-640','camera.webm',3),
    ('waves','arena_waves-after-human-0-60-640','camera.webm',3),
    ('route-3-3','release-single-capture','route-3-3.webm',0.25),
]:
    video=base/'web'/source/filename
    audio=['-c:a','aac','-b:a','128k'] if name=='route-3-3' else ['-an']
    subprocess.run([str(ff),'-v','error','-y','-i',str(video),*audio,'-c:v','libx264','-threads','2','-preset','fast','-crf','20','-pix_fmt','yuv420p','-movflags','+faststart',str(media/(name+'.mp4'))],check=True)
    frames=media/(name+'-frames');frames.mkdir(exist_ok=True)
    subprocess.run([str(ff),'-v','error','-y','-i',str(video),'-vf',f'fps={fps},scale=480:270','-frames:v','12',str(frames/'%03d.png')],check=True)
    files=sorted(frames.glob('*.png'))
    sheet=Image.new('RGB',(1440,294*((len(files)+2)//3)),'#101922');draw=ImageDraw.Draw(sheet)
    for i,f in enumerate(files):
        x=i%3*480;y=i//3*294
        sheet.paste(Image.open(f),(x,y+24));draw.text((x+8,y+4),f'{name} / ~{(i+.5)/fps:.2f}s',fill='white')
    sheet.save(media/(name+'-review.jpg'),quality=92)

prefix='evidence/arena-polish/'
shots=prefix+'web/arena_view-after-human-0-60-960/'
rows=json.loads((base/'imps-60.json').read_text(encoding='utf-8'))
imp_rows=''.join(f'<tr><td>{r["id"]}</td><td>{r["fired"]} / {r["started"]}</td><td>{r["cancelled"]}</td></tr>' for r in rows)
page='''<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>MARICRAFT — арена, чертята и выбор уровней</title><link rel="icon" href="../exports/arena-polish-release/index.icon.png">
<style>:root{color-scheme:dark}*{box-sizing:border-box}body{margin:0;background:#0b151b;color:#eef1e9;font:16px/1.65 system-ui,sans-serif}main{max-width:1180px;margin:auto;padding:32px 24px 64px}h1{font-size:clamp(28px,4vw,44px);line-height:1.15}h2{margin-top:42px}p{max-width:980px;color:#b9c7c9}a{color:#d6c18e}nav{display:flex;gap:20px;flex-wrap:wrap}.pair{display:grid;grid-template-columns:1fr 1fr;gap:20px}.comparison{display:grid;grid-template-columns:200px 1fr;gap:20px;align-items:start}figure{margin:0;min-width:0}img,video{display:block;width:100%;border-radius:7px;border:1px solid #405159}video{aspect-ratio:16/9;background:#050b0e}figcaption{font-size:14px;color:#a9babc;margin:8px 0 16px}.note{background:#18272e;border-left:3px solid #d6b577;padding:12px 18px}table{border-collapse:collapse;width:100%;max-width:700px}td,th{text-align:left;border-bottom:1px solid #314650;padding:8px 12px}th{color:#d6c18e}code{overflow-wrap:anywhere}footer{border-top:1px solid #314650;padding-top:18px;margin-top:40px;color:#a9babc}@media(max-width:760px){.pair{grid-template-columns:1fr}.comparison{grid-template-columns:1fr}.comparison figure:first-child img{max-width:200px}main{padding:20px 14px}}</style>
<main><p>MARICRAFT · исправления по замечаниям владельца · 06.11.2026</p><h1>Арена без стыка.<br>Руна, волны и стреляющие чертята.</h1><nav><a href="../exports/arena-polish-release/">Играть в Web</a><a href="../docs/ARENA_POLISH_REPORT.md">Подробный отчёт</a><a href="../docs/NATIVE_LAUNCH.md">Запуск в Godot</a></nav>
<h2>Правый край арены</h2><p>Фиксированная панорама шириной 1080 единиц не перекрывала кадр с масштабом ×0,90 и смещением фона. Теперь размер рассчитывается по видимой области с запасом для движения. Пропорции изображения сохранены.</p><div class="comparison"><figure><img src="__P__reported-seam.png" alt="Стык на присланном снимке"><figcaption>Присланный снимок: вертикальный обрыв.</figcaption></figure><figure><a href="__S__arena-right.png"><img src="__S__arena-right.png" alt="Исправленный правый край арены"></a><figcaption>Новый кадр из игры: панорама покрывает правый край целиком. Проверены оба края при 960×540 и 640×360.</figcaption></figure></div>
<h2>Руна и наземные волны</h2><div class="pair"><figure><video controls playsinline preload="metadata" src="__P__media/rune.mp4"></video><figcaption>Руна опущена с y=270 до y=380. Короткий прыжок с пола внутри закрытой арены; показаны обычный подбор и рост в магическую форму.</figcaption></figure><figure><video controls playsinline preload="metadata" src="__P__media/waves.mp4"></video><figcaption>Пламя и след наземной волны увеличены втрое. Скорость, урон и область попадания 12×12 остались прежними. Запись при 640×360.</figcaption></figure></div><p class="note">Это отдельные визуальные сценарии с подготовленной позицией героя. Босс остановлен для проверки руны; для волн вызван его настоящий удар. Полное прохождение с действующим боссом проверяется отдельно.</p>
<h2>Все шесть чертят стреляют</h2><p>Пять размещённых на уровнях чертят и противник из опасной трубы используют одну сцену <code>fire_imp.tscn</code>. Проверено по 20 подготовок/выстрелов у каждого при 30 и 60 FPS, в том числе при прыжке цели после начала подготовки. Стрельба сквозь стены и до завершения выхода из трубы не включалась.</p><table><thead><tr><th>Противник</th><th>Выстрелы / подготовки</th><th>Обрывы</th></tr></thead><tbody>__IMPS__</tbody></table>
<h2>Кнопка «Выбор уровней»</h2><div class="pair"><figure><img src="__S__menu-locked.png" alt="Неактивная кнопка до финала"><figcaption>До завершения кампании видна, но недоступна. Подсказка объясняет условие открытия.</figcaption></figure><figure><img src="__S__menu-unlocked.png" alt="Активная кнопка после финала"><figcaption>После финала открывает существующую карту девяти уровней. Завершённое сохранение также открывает кнопку.</figcaption></figure></div><p>После начала новой кампании выбор снова блокируется. Банк, рекорды, защита наград и правила повторных попыток остались в общем состоянии кампании.</p>
<h2>Проверки</h2><p>Godot: 36 основных маршрутов третьей локации — два героя, три формы, 30/60 FPS. Отдельно проверены руна, все стрелки, урон волн, блокировка и сохранение доступа к выбору уровней. Визуальные кадры и последовательности записей просмотрены.</p><p><a href="__P__web/release/route-3-3.webm">Полный маршрут 3-3 в публичной Web-сборке</a> · <a href="__P__web/release/release.json">Результат Web-проверки и сохранений</a> · <a href="__P__checks60.log">Проверки 60 FPS</a> · <a href="__P__checks30.log">Проверки 30 FPS</a></p>
<p class="note">Рабочий стол не использовался. Godot проверен через headless-запуски, графика — в отдельном headless Edge. Нажатия F5/F8 в интерфейсе редактора и HTTPS-хостинг в этой задаче не проверялись.</p><footer>Рабочий проект: <code>D:/Projects/MARICRAFT/project.godot</code>, Godot 4.7.2 Standard. Запуск — F5, остановка — F8. Сохранения владельца не удалялись. Прежние исправления камеры, леса, музыки и баланса боссов сохранены.</footer></main></html>'''
page=page.replace('__P__',prefix).replace('__S__',shots).replace('__IMPS__',imp_rows)
page=page.replace('web/release/route-3-3.webm','media/route-3-3.mp4')
page=page.replace('<h2>Проверки</h2>',f'''<h2>Проверки</h2><video controls playsinline preload="metadata" src="{prefix}media/route-3-3.mp4"></video>
<p>Публичная Web-сборка: повтор 3-3 через новую кнопку и бой с действующим Рагнаросом, три сердца сохранены. Запись содержит игровой звук. Все девять уровней ранее пройдены с продолжением сохранения: на первой попытке 3-3 тестовое управление рано прыгнуло перед ямой и потеряло сердце. После исправления ввода финальный уровень пройден с оставшимися двумя сердцами без новой потери. Победа, загрузка сохранения, новая кнопка и повтор 3-2 проверены; ошибок выполнения нет.</p>
<p>При первоначальном двойном видеозахвате в headless Edge появились цветные артефакты HUD. Повтор без захвата и показанный здесь повтор с одним записывающим потоком дали чистые кадры. Исходная диагностическая запись сохранена; игровые ресурсы и рендерер из-за этого не менялись.</p>''')
page=page.replace('</style>','.comparison figure:first-child img{max-height:560px;width:auto;max-width:100%}</style>')
(root/'reports/ARENA_POLISH_REVIEW.html').write_text(page,encoding='utf-8')
print('Prepared arena-polish review and three portable videos.')
