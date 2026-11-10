"""Build the local, portable evidence page from captured gameplay only."""
from pathlib import Path
import html
import json
import re
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
base = root / 'reports/evidence/camera-repair'
media = base / 'media'
ffmpeg = root / 'reports/temp/s04/encoder/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v9.0.2.exe'
sys.path.insert(0, str(root / 'reports/temp/forest-art/python'))
from PIL import Image, ImageDraw

# MediaRecorder WebM has no duration/cues. Add an index with stream copy so
# the local report can seek normally; no frame or audio re-encoding occurs.
recordings = list((base / 'web/release').glob('route-*.webm')) + [
    base / f'web/perf{fps}/ragnaros-with-audio.webm' for fps in (30, 60)
]
for source in recordings:
    destination = root / 'reports/temp/camera-repair' / ('indexed-' + source.parent.name + '-' + source.name)
    assert source.resolve().is_relative_to(base.resolve())
    assert destination.resolve().is_relative_to(root.resolve())
    subprocess.run([str(ffmpeg), '-v', 'error', '-y', '-i', str(source), '-map', '0',
                    '-c', 'copy', str(destination)], check=True)
    destination.replace(source)

# Omit the fixture reposition between the horizontal shot and the jump shot.
# The complete original recording and telemetry remain in web/*/.
for variant in ('before', 'after'):
    for name, start, duration in [('movement', 0, 9.7), ('jumps', 11.4, 4.25)]:
        subprocess.run([str(ffmpeg), '-v', 'error', '-y', '-ss', str(start),
                        '-i', str(media / f'camera-{variant}.mp4'), '-t', str(duration),
                        '-an', '-c:v', 'libx264', '-threads', '2', '-preset', 'fast',
                        '-crf', '21', '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
                        str(media / f'{name}-{variant}.mp4')], check=True)

# Inspectable frames from the final wide Ragnaros framing and the full 2-3 route.
for label, source, timestamp in [
    ('ragnaros-30', 'web/perf30/ragnaros-with-audio.webm', 5),
    ('ragnaros-60', 'web/perf60/ragnaros-with-audio.webm', 5),
    ('candle-route', 'web/release/route-2-3.webm', 25),
]:
    subprocess.run([str(ffmpeg), '-v', 'error', '-y', '-ss', str(timestamp),
                    '-i', str(base / source), '-frames:v', '1', str(media / f'{label}.png')], check=True)
    assert (media / f'{label}.png').exists()

def order(path):
    return (path.stem[:3], 'mine' in path.stem, int(path.stem.split('-')[-1]))

files = sorted((base / 'web/atlas').glob('*.png'), key=order)
assert len(files) == 100
for f in files:
    for version in ('before', 'after'):
        assert (root / 'reports/evidence/final-polish' / version / f.name).exists(), f.name
levels = sorted({f.stem[:3] for f in files})
(base / 'sheets').mkdir(exist_ok=True)
for level in levels:
    shots = [f for f in files if f.stem.startswith(level)]
    sheet = Image.new('RGB', (1920, 254 * ((len(shots) + 2) // 3)), '#101922')
    draw = ImageDraw.Draw(sheet)
    for i, f in enumerate(shots):
        x, y = (i % 3) * 640, (i // 3) * 254
        shot = Image.open(f).crop((0, 195, 960, 540)).resize((640, 230))
        sheet.paste(shot, (x, y + 24))
        draw.text((x + 8, y + 5), f.stem, fill='white')
    sheet.save(base / 'sheets' / f'{level}.jpg', quality=91)

prefix = 'evidence/camera-repair/'
pairs = [
    ('movement', 'Шаги, остановка и разворот', 'После остановки смотрите на ближайшие опоры: новый обзор не возвращает героя к центру.'),
    ('jumps', 'Прыжки на месте', 'Три прыжка на одной поверхности. Новая камера сохраняет высоту фона.'),
    ('long', '13 секунд бега и прыжок через яму', 'Непрерывная запись: разбег, перепрыгивание разрыва, остановка, возвращение влево.'),
    ('elevation', 'Высокая платформа и спуск', 'Большая форма прыгает на верхнем настиле, затем спускается. Запас сверху сохраняет голову героя в кадре.'),
    ('boss', 'Бой с первым боссом', 'Одинаковый алгоритм управления. Босс побеждён в обоих вариантах; три сердца сохранены.'),
]
pair_html = []
for name, title, caption in pairs:
    columns = ''.join(f'<figure><figcaption>{label}</figcaption><video controls muted playsinline preload="metadata" src="{prefix}media/{name}-{variant}.mp4"></video></figure>'
                      for variant, label in [('before', 'Прежняя камера'), ('after', 'Исправленная камера')])
    pair_html.append(f'<article class="comparison"><h3>{title}</h3><p>{caption}</p><div class="pair">{columns}</div><button class="sync">Воспроизвести одновременно</button><button class="pause">Остановить оба</button></article>')

level_data = json.dumps([f.name for f in files], ensure_ascii=False)
level_options = ''.join(f'<option>{level}</option>' for level in levels)
comparisons = []
for name, title, detail in [
    ('1-1-2700.png', '1-1 · опоры нижнего настила', 'Справа дерево перекрывало левую стойку. После исправления стойка снова видна перед стволом.'),
    ('1-1-3600.png', '1-1 · порядок слоёв конструкций', 'Возвращён порядок принятой версии: деревья позади опор. Платформы и коллизии не перемещались.'),
    ('2-2-450.png', '2-2 · фон шахты', 'Убрано ошибочное зеркалирование чередующихся пролётов. Сравните правую стену с принятой версией.'),
]:
    figures = ''.join(f'<figure><figcaption>{label}</figcaption><a href="{path}/{name}" target="_blank"><img loading="lazy" src="{path}/{name}" alt="{html.escape(title)} — {label}"></a></figure>'
                      for path, label in [('evidence/final-polish/before', 'Принятая версия'), ('evidence/final-polish/after', 'До исправления'), (prefix + 'web/atlas', 'После исправления')])
    comparisons.append(f'<article><h3>{title}</h3><p>{detail}</p><div class="triple">{figures}</div></article>')

page = '''<!doctype html>
<html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>MARICRAFT — камера и восстановление уровней</title>
<link rel="icon" href="../exports/camera-repair-release/index.icon.png">
<style>
:root{color-scheme:dark;--ink:#e9ede9;--muted:#aab7ba;--panel:#142229;--line:#30434a;--accent:#d6b577}
*{box-sizing:border-box}body{margin:0;background:#0b151b;color:var(--ink);font:16px/1.65 system-ui,sans-serif}main{max-width:1320px;margin:auto;padding:40px 28px 80px}header{padding:24px 0 32px;border-bottom:1px solid var(--line)}.eyebrow{color:var(--accent);letter-spacing:.13em;font-size:13px}h1{font-size:clamp(29px,4vw,48px);line-height:1.15;max-width:950px}h2{margin-top:58px;font-size:28px}h3{font-size:21px;margin-bottom:8px}p{max-width:980px;color:var(--muted)}a{color:#c9e8e6}nav{display:flex;gap:18px;flex-wrap:wrap;margin-top:24px}.stats{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin:28px 0}.stat{background:var(--panel);padding:18px;border:1px solid var(--line);border-radius:8px}.stat strong{font-size:30px;display:block;color:var(--accent)}.stat span{color:var(--muted);font-size:14px}article{margin:28px 0 42px}.pair,.triple{display:grid;gap:16px;grid-template-columns:repeat(2,1fr)}.triple{grid-template-columns:repeat(3,1fr)}figure{margin:0;min-width:0}figcaption{padding:8px 0;color:var(--muted);font-size:14px}video,img{display:block;width:100%;background:#080e12;border:1px solid var(--line);border-radius:6px}video{aspect-ratio:16/9}button,select{font:inherit;color:var(--ink);border:1px solid #587077;background:#20343c;border-radius:6px;padding:8px 14px;cursor:pointer}button:hover,select:hover{border-color:var(--accent)}button:focus-visible,a:focus-visible,select:focus-visible{outline:3px solid var(--accent);outline-offset:3px}.comparison button{margin:12px 10px 0 0}.toolbar{display:flex;gap:12px;flex-wrap:wrap;align-items:center;margin:18px 0}.gallery{display:grid;grid-template-columns:repeat(2,1fr);gap:22px}.note{border-left:3px solid var(--accent);padding:8px 20px;background:var(--panel)}.table-wrap{overflow:auto}table{width:100%;border-collapse:collapse}th,td{text-align:left;padding:11px 14px;border-bottom:1px solid var(--line)}th{color:var(--accent)}.route{max-width:960px}.muted,small{color:var(--muted)}code{background:var(--panel);padding:2px 5px;overflow-wrap:anywhere}footer{margin-top:50px;border-top:1px solid var(--line);padding-top:20px;color:var(--muted)}
@media(max-width:760px){main{padding:20px 16px 50px}.pair,.triple,.gallery{grid-template-columns:1fr}.stats{grid-template-columns:repeat(2,1fr)}h2{font-size:24px}}
</style><main>
<header><div class="eyebrow">MARICRAFT / ПРОВЕРКА 06.11.2026</div><h1>Спокойная камера.<br>Восстановленные конструкции.</h1>
<p>Камера больше не откатывается назад при остановке и не поднимает фон вслед за обычным прыжком. Опоры первой локации снова видны перед деревьями; ошибочное зеркалирование шахты 2-2 исправлено.</p>
<nav><a href="#camera">Сравнить камеру</a><a href="#repairs">Увидеть восстановление</a><a href="#levels">Все уровни</a><a href="#routes">Прохождение</a><a href="../docs/CAMERA_REPAIR_REPORT.md">Подробный отчёт</a><a href="../docs/NATIVE_LAUNCH.md">Запуск в Godot</a></nav></header>
<div class="stats"><div class="stat"><strong>24%</strong><span>ширина свободной области камеры</span></div><div class="stat"><strong>108 / 108</strong><span>основных сценариев Godot</span></div><div class="stat"><strong>9 / 9</strong><span>уровней полного Web-маршрута</span></div><div class="stat"><strong>100</strong><span>окон визуальной проверки</span></div></div>
<p class="note">Проверки выполнены в Godot и отдельном headless-браузере. Рабочий стол владельца не использовался. Кадры и видео получены из работающих игровых сцен; ниже указано, где применялось тестовое размещение героя.</p>
<section id="camera"><h2>Камера до и после</h2><p>Оба варианта используют одинаковые сцены и команды движения. Подготовлены герой в большой форме и начальная позиция; далее работают штатные физика, столкновения и атаки. Шаги и прыжки вынесены в отдельные ролики, чтобы не включать перемещение тестовой позиции. Скорость видео — обычная.</p>
__PAIRS__
<div class="table-wrap"><table><thead><tr><th>Измерение</th><th>Прежняя камера</th><th>Исправленная</th></tr></thead><tbody><tr><td>Возврат назад после остановки</td><td>75,8 мировых единицы</td><td>0</td></tr><tr><td>Вертикальный ход при прыжках на месте</td><td>43,8</td><td>0</td></tr><tr><td>Обычный масштаб</td><td>×1,25</td><td>×1,25 — сохранён</td></tr><tr><td>Масштаб в бою</td><td>Меняется с расстоянием</td><td>Постоянный для каждой арены</td></tr></tbody></table></div>
<p>После отпускания движения остаётся около 16,1 единицы плавного продвижения вперёд вместе с торможением героя. Обратного центрирования нет. В 12 сценариях при 640×360 — оба героя, все формы, 30/60 FPS — результаты совпали.</p></section>
<section id="repairs"><h2>Почему исчезли опоры</h2><p>Объекты не были удалены. После переноса деревьев в редактируемый <code>Scenery</code> они оказались перед слоем опор и закрыли их. Восстановлен прежний порядок рисования: деревья → опоры → поверхности. Новые случайные колонны и коллизии не добавлялись.</p>__COMPARISONS__
<p>Проверены все прежние игровые узлы: сохранены 201 поверхность, 198 блоков и 360 отдельных монет. В 3-1 также возвращена случайно сдвинутая на два пикселя монета. Две ранее исправленные монеты 3-2 оставлены на доступных позициях. Периодический рисунок старых фоновых полос и условно подвешенные игровые блоки присутствовали в принятой версии; художественная структура не переделывалась.</p></section>
<section id="levels"><h2>Все девять уровней и дополнительные комнаты</h2><p>Одинаковые мировые координаты и масштаб, без HUD. Нажмите изображение для оригинала 960×540. Переключатель версии позволяет проверить каждый участок, включая места без изменений.</p><div class="toolbar"><label>Уровень <select id="level">__LEVELS__</select></label><label>Версия <select id="version"><option value="fixed">После исправления</option><option value="regression">До исправления</option><option value="accepted">Принятая версия P07 v03</option></select></label><span id="count" class="muted"></span></div><div id="gallery" class="gallery"></div></section>
<section id="routes"><h2>Записи полного прохождения</h2><p>Публичная Web-сборка, окно 640×360. Маршрут начинается через обычное меню и выбор героя, затем последовательно проходит девять уровней. Управление подаёт тестовый игрок через браузерные события клавиш; это отдельная проверка от подготовленных сравнительных сцен выше. Видеозаписи маршрутов — без звука.</p><div class="toolbar"><label>Маршрут <select id="route">__LEVELS__</select></label><a id="route-link" href="evidence/camera-repair/web/release/route-1-1.webm">Открыть запись</a></div><video id="route-video" class="route" controls playsinline preload="metadata" src="evidence/camera-repair/web/release/route-1-1.webm"></video>
<h3>Финальный обзор арены Рагнароса: 30 и 60 FPS</h3><p>Отдельные записи после последней настройки ×0,90. Оба боя завершены, показаны три типа атак и сохранены 12 HP босса. В этих двух роликах записан игровой звук.</p><div class="pair"><figure><figcaption>30 FPS · фактически около 29,95</figcaption><video controls playsinline preload="metadata" poster="evidence/camera-repair/media/ragnaros-30.png" src="evidence/camera-repair/web/perf30/ragnaros-with-audio.webm"></video></figure><figure><figcaption>60 FPS · фактически около 59,87</figcaption><video controls playsinline preload="metadata" poster="evidence/camera-repair/media/ragnaros-60.png" src="evidence/camera-repair/web/perf60/ragnaros-with-audio.webm"></video></figure></div></section>
<section id="checks"><h2>Проверки и границы результата</h2><div class="table-wrap"><table><tbody><tr><th>Godot</th><td>Импорт без ошибок; 108 основных сценариев и ещё 12 для финального обзора Рагнароса. Отдельно проверены механики, сохранения, награды, 24 случая на краях переправы.</td></tr><tr><th>Web</th><td>9 уровней, победа, загрузка финального сохранения, открытая карта, повторный вход в 3-2, отсутствие ошибок исполнения. F1 выключен в публичной сборке.</td></tr><tr><th>Чертята</th><td>Оба стрелка: по 20 из 20 выстрелов при 30 и 60 FPS, отмен подготовки нет.</td></tr><tr><th>Ресурсы</th><td>592 изображения, звука и шрифта сохранили хеши. P07 v03, музыка, физика и слой сохранений сохранены.</td></tr><tr><th>Редактор</th><td>Все девять сцен загружены и проверены через headless-стенд. Выбор объектов мышью и F5/F8 в GUI в этой задаче не проверялись. Специальный стенд редактора сообщил об оставшихся RID при выходе; обычный импорт чистый.</td></tr><tr><th>Не проверено</th><td>Публикация на HTTPS, слабые устройства и субъективная оценка звука на слух. Ощущение камеры можно оценить по роликам и в игре.</td></tr></tbody></table></div>
<p><a href="evidence/camera-repair/verification-summary.json">Измерения JSON</a> · <a href="evidence/camera-repair/web/release/release.json">Полный Web-результат</a> · <a href="../docs/CAMERA_REPAIR_REPORT.md">Причины, файлы и результаты по каждому уровню</a></p></section>
<section><h2>Открыть актуальную игру</h2><p>Godot 4.7.2 Standard → «Импортировать» → <code>D:/Projects/MARICRAFT/project.godot</code> → открыть проект → <strong>F5</strong>. Остановка — <strong>F8</strong>. Для просмотра уровня откройте его сцену в <code>scenes/levels/</code>; подробные шаги — в <a href="../docs/NATIVE_LAUNCH.md">инструкции для редактора</a>.</p><p><a href="../exports/camera-repair-release/">Запустить публичную Web-сборку</a> (работает при открытии этой страницы через локальный сервер). Сохранения браузера и настольной версии раздельные; существующие сохранения не удалялись.</p></section>
<footer>Все материалы находятся в D:/Projects/MARICRAFT. Полные исходные записи и журналы сохранены в reports/evidence/camera-repair/. Более ранние неудачные запуски стенда оставлены для истории; итоговые результаты приведены по ссылкам выше.</footer>
</main><script>
const files=__FILES__;
const paths={fixed:'evidence/camera-repair/web/atlas/',regression:'evidence/final-polish/after/',accepted:'evidence/final-polish/before/'};
const level=document.getElementById('level'),version=document.getElementById('version'),gallery=document.getElementById('gallery');
function render(){const shots=files.filter(f=>f.startsWith(level.value+'-'));gallery.replaceChildren();document.getElementById('count').textContent=shots.length+' окон';for(const file of shots){const fig=document.createElement('figure'),link=document.createElement('a'),img=document.createElement('img'),caption=document.createElement('figcaption');link.href=paths[version.value]+file;link.target='_blank';img.src=link.href;img.loading='lazy';img.alt=file.replace('.png','');caption.textContent=file.replace('.png','').replace('-mine-',' · дополнительная комната · x=').replace(new RegExp('^'+level.value+'-'),level.value+' · x=');link.append(img);fig.append(link,caption);gallery.append(fig)}}
level.addEventListener('change',render);version.addEventListener('change',render);render();
document.querySelectorAll('.comparison').forEach(card=>{const videos=[...card.querySelectorAll('video')];card.querySelector('.sync').addEventListener('click',async()=>{for(const v of videos){v.pause();v.currentTime=0}await Promise.allSettled(videos.map(v=>v.play()))});card.querySelector('.pause').addEventListener('click',()=>videos.forEach(v=>v.pause()))});
document.getElementById('route').addEventListener('change',event=>{const url='evidence/camera-repair/web/release/route-'+event.target.value+'.webm';document.getElementById('route-video').src=url;document.getElementById('route-link').href=url});
</script></html>'''
page = page.replace('__PAIRS__', '\n'.join(pair_html)).replace('__COMPARISONS__', '\n'.join(comparisons)).replace('__LEVELS__', level_options).replace('__FILES__', level_data)
target = root / 'reports/CAMERA_REPAIR_REVIEW.html'
target.write_text(page, encoding='utf-8')
for relative in re.findall(r'(?:src|href|poster)="([^"]+)"', page):
    if relative.startswith('#'):
        continue
    assert (target.parent / relative).exists(), relative
print(f'Created {target}; 100 atlas images, 5 video pairs, 9 route recordings.')
