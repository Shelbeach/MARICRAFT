"""Review of the actual campaign: videos, original captures and camera panoramas."""
import html,json,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'reports/temp/forest-art/python'))
from PIL import Image
e=root/'reports/evidence/p07v03-music'
prefix='evidence/p07v03-music/'
rows=json.loads((e/'after/coverage.json').read_text(encoding='utf8'))
music=json.loads((e/'audio/runtime_analysis.json').read_text(encoding='utf8'))
names=['Меню и карта','Элвиннский лес','Дуротар','Огненные Недра','Первые два босса','Рагнарос']
def img(file,label):
    src=prefix+file
    return f'<a href="{src}" target="_blank"><img loading="lazy" src="{src}" alt="{html.escape(label)}"></a>'
def video(file,title,desc,poster=''):
    poster=f' poster="{prefix}{poster}"' if poster else ''
    return f'<article><h3>{title}</h3><video controls playsinline preload="metadata"{poster} src="{prefix}{file}"></video><p class="muted">{desc}</p></article>'
panos=e/'panoramas';panos.mkdir(exist_ok=True)
galleries=[]
for level in dict.fromkeys(r['level'] for r in rows):
    group=sorted([r for r in rows if r['level']==level],key=lambda r:r['x'])
    start=group[0]['x'];end=group[-1]['x']+960
    panorama=Image.new('RGB',(end-start,540))
    for i,r in enumerate(group):
        width=group[i+1]['x']-r['x'] if i<len(group)-1 else 960
        panorama.paste(Image.open(e/'after'/(r['id']+'.png')).convert('RGB').crop((0,0,width,540)),(r['x']-start,0))
    panorama.save(panos/(level+'.jpg'),quality=93)
    galleries.append(f'<article><h3>{level}</h3><div class="panorama">{img("panoramas/"+level+".jpg",level+" — составная панорама")}</div><details><summary>{len(group)} полных положений камеры</summary><div class="two">'+''.join('<figure>'+img('after/'+r['id']+'.png',r['id'])+f'<figcaption>X={r["x"]}</figcaption></figure>' for r in group)+'</div></details></article>')
body='''<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>MARICRAFT · P07 v03 и музыка</title><style>
:root{color-scheme:dark;font:17px/1.55 system-ui,sans-serif;background:#15151c;color:#eee7dc}*{box-sizing:border-box}body{margin:0}main{max-width:1220px;margin:auto;padding:42px 24px 80px}a{color:#f4bd74}h1{font-size:clamp(34px,6vw,66px);line-height:1.08;max-width:920px;margin:18px 0 24px}h2{font-size:30px;margin:54px 0 18px}h3{font-size:21px;margin:20px 0 12px}.eyebrow{letter-spacing:.15em;color:#d9a567;text-transform:uppercase}.lead{max-width:840px;font-size:21px}.muted,figcaption{color:#b3b1bb;font-size:14px}nav{display:flex;flex-wrap:wrap;gap:10px;margin:24px 0}nav a{border:1px solid #514452;border-radius:7px;padding:9px 13px;text-decoration:none;background:#25222d}.notice{background:#302721;border-left:3px solid #d99851;padding:15px 20px}.stats{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin:26px 0}.stats div{background:#24222d;padding:17px;border-radius:9px}.stats b{display:block;color:#f4bd74;font-size:30px}.two{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:20px}.wide{max-width:960px}.audio{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:16px}.audio article{background:#24222d;padding:16px;border-radius:8px}.audio h3{margin-top:0;font-size:18px}figure{margin:0}img,video{width:100%;height:auto;display:block;border-radius:6px;background:#090b10}audio{width:100%}figcaption{padding:8px 0}.panorama{overflow:auto;border:1px solid #514452;border-radius:6px}.panorama img{width:auto;height:270px;max-width:none}.scroll{overflow:auto}table{border-collapse:collapse;width:100%;font-size:15px}td,th{padding:9px 12px;border-bottom:1px solid #514452;text-align:left}details{padding:16px 0;border-bottom:1px solid #514452}summary{cursor:pointer;font-weight:600;margin-bottom:15px}code{overflow-wrap:anywhere}section{scroll-margin-top:22px}@media(max-width:750px){main{padding:24px 16px 55px}.two,.audio{grid-template-columns:1fr}.stats{grid-template-columns:repeat(2,1fr)}h2{font-size:26px}.lead{font-size:18px}.panorama img{height:220px}}
</style><main><div class="eyebrow">MARICRAFT · P07 v03 · 06 ноября 2026</div><h1>Рагнарос в кампании.<br>Шесть музыкальных тем.</h1><p class="lead">Новый риг, паромы, извержения и варианты окружения работают в основной игре. Геометрия, 12 HP, атаки, формы героев и награды сохранены.</p><nav><a href="#fight">Бой</a><a href="#music">Музыка</a><a href="#world">Окружение</a><a href="#checks">Проверки</a><a href="../exports/p07v03-music-release/">Играть в Web</a><a href="../docs/P07_V03_MUSIC_REPORT.md">Подробный отчёт</a></nav><div class="stats"><div><b>9 / 9</b>уровней пройдены в Web</div><div><b>36</b>native-маршрутов Недр</div><div><b>14 + 8</b>состояний корпуса / молота</div><div><b>6 × 15 мин</b>декодировано Godot</div></div><p class="notice"><b>Граница проверки звука:</b> записи содержат настоящий игровой микс. Проверены воспроизведение, переключения, уровни сигнала и повтор циклов. Прослушивание и художественная оценка музыкальных стыков недоступны используемому инструменту; «бесшовность на слух» не объявляется подтверждённой.</p>
<section id="fight"><h2>Полный бой с новым Рагнаросом</h2><p>Малый человек, без магии, неуязвимости и телепортаций. Непрерывный маршрут 3-3, все три атаки и фазы, 12 HP, победа и три звезды. Видео 960×540, 30 кадров/с, со звуком; игровая физика 60 Гц.</p><div class="wide">'''
body+=video('video/ragnaros-full.mp4','3-3 · от входа до финала','Бой начинается примерно на 16-й секунде; смерть — около 33-й. Запись сделана основным Godot-проектом.','video/ragnaros-full/0045.jpg')
body+='</div><div class="two">'
body+=video('video/rig-both-sides.mp4','Молот с обеих сторон','Контролируемые позиции игрока, реальные часы контроллера. Показаны перенос через верхнюю дугу, отражение, реакция на удар и двухсекундная смерть. Это отдельная проверка анимации.','screens/open--1.png')
body+=video('video/ragnaros-web.mp4','Тот же бой в Web','Настоящие клавиши браузера, release без F1, захват canvas и аудиовыхода браузера. Проверка сохранения финала выполнена после этой записи.','web/release/ragnaros-defeat.png')
body+='</div><h3>Состояния в настоящей арене</h3><p class="muted">Ниже контролируемые образцы поз для проверки рук и слоёв; реальное время переходов показано в видео.</p><div class="two">'
for file,title in [('body-prepare_fire--1','Подготовка выстрела'),('body-prepare_hammer-1','Замах'),('open--1','Уязвимая головка слева'),('open-1','Уязвимая головка справа'),('body-phase-1','Смена фазы'),('death-end','Остаток тела после смерти')]:
    body+='<figure>'+img('screens/'+file+'.png',title)+'<figcaption>'+title+'</figcaption></figure>'
body+='</div><details><summary>Все 14 состояний и восемь клипов молота</summary><div class="two">'
for p in sorted((e/'screens').glob('body-*.png'))+sorted((e/'screens').glob('hammer-*.png')):
    body+='<figure>'+img('screens/'+p.name,p.stem)+'<figcaption>'+p.stem+'</figcaption></figure>'
body+='</div></details></section><section id="music"><h2>Переходы и циклы</h2><div class="wide">'
body+=video('video/music-transitions.mp4','Все шесть тем · 54 секунды','Меню → настройки → карта → лес → пауза → первый босс → Дуротар → второй босс → Недра → Рагнарос → смерть → меню. Позиции и победа задаются тестом; звуковой переход выполняет настоящий MusicManager.','after/ui-main.png')
body+='</div><p>Одна система и два плеера на шине Music. Переход — 1,1 с; одна и та же тема продолжает играть. Пауза приглушает звук. Ползунок «Музыка» сохраняется; эффекты сохраняют прежние настройки.</p><div class="scroll"><table><tr><th>Исходник</th><th>Назначение</th><th>Первое воспроизведение</th><th>Повторяемый участок</th></tr>'
for t,title in zip(music,names):
    body+=f'<tr><td>{t["source_number"]}.mp3</td><td>{title}</td><td>0–{t["loop_end"]:.3f} с</td><td>{t["loop_start"]:.3f}–{t["loop_end"]:.3f} с</td></tr>'
body+='</table></div><h3>Короткие записи границ циклов</h3><p class="muted">Четыре секунды настоящего декодера Godot вокруг первого возврата. Это фрагменты для оценки стыка, не отдельные игровые темы; не ставьте сам четырёхсекундный файл на повтор.</p><div class="audio">'
for t,title in zip(music,names):
    body+=f'<article><h3>{t["source_number"]} · {title}</h3><audio controls preload="none" src="{prefix}audio/godot-{t["id"]}-seam.ogg"></audio><p class="muted">Цикл {t["loop_duration"]:.2f} с</p></article>'
body+='</div></section><section id="world"><h2>Окружение и переправы</h2><p>Мировые UV, асимметричные поля A/B и новые дальние пролёты без отражения. Прежние кромки, опоры, слои и уникальный фон арены сохранены.</p><div class="two">'
for file,title in [('3-1-1800','3-1 · базальт и дальние скалы'),('3-2-2250','3-2 · переход к нагретому камню'),('3-2-mine-7050','Дополнительная комната 3-2'),('3-3-1800','3-3 · обсидиан и святилище')]:
    body+='<figure>'+img('after/'+file+'.png',title)+'<figcaption>'+title+'</figcaption></figure>'
body+='</div><h3>Оба края нового парома · 640×360</h3><div class="two">'
for form in [0,1]:
    for side in [-1,1]:
        title=('Малая' if form==0 else 'Большая')+' форма · '+('левый' if side<0 else 'правый')+' край'
        body+='<figure>'+img(f'screens/ferry-{form}-{side}.png',title)+'<figcaption>'+title+'</figcaption></figure>'
body+='</div><h3>Маршруты целиком</h3><p class="muted">Составные панорамы собраны из соседних окон камеры для обзора маршрута. На границах кадров меняется параллакс; по этим границам нельзя оценивать шов текстуры. Для проверки фонов раскройте полные кадры ниже. Панорамы можно прокручивать по горизонтали.</p>'+''.join(galleries)+'</section>'
body+='''<section id="checks"><h2>Что проверено</h2><div class="scroll"><table><tr><th>Проверка</th><th>Результат</th></tr><tr><td>Native 960×540 / 640×360</td><td>По 148 интеграционных проверок; без ошибок</td></tr><tr><td>3-1, 3-2, 3-3</td><td>Оба героя × три формы × 30/60: 36 непрерывных проходов без потери сердца</td></tr><tr><td>Паром</td><td>12 случаев у обоих краёв; скольжение 0,0, отклонение от палубы менее 0,003 ед.</td></tr><tr><td>Риг в движении</td><td>Обе стороны; в OPEN ошибка совмещения головки 0,0 ед.</td></tr><tr><td>Web release</td><td>Девять уровней, финал, reload, повтор; ошибок выполнения нет</td></tr><tr><td>Web бой при 30/60</td><td>29,99 / 59,11 FPS на этой машине; p95 33,4 / 16,8 мс</td></tr><tr><td>Музыкальные циклы</td><td>По 900 с в декодере Godot, 8–15 повторов; отдельный реальный Web-возврат каждой темы</td></tr><tr><td>Godot GUI</td><td>F5 → меню → настройки → 1-1 → F8. Ошибок runtime не наблюдалось; 16 статических предупреждений проекта</td></tr><tr><td>Сохранность</td><td>1003 прежних файла совпали по SHA256, 13 существующих изменены по задаче; сцены и прежние ассеты не изменены</td></tr></table></div><p>Движение и прыжки подтверждены автоматическим игровым вводом native/Web. Короткий физический ввод через инструмент GUI не дал наблюдаемого движения и не называется ручным прохождением. 15-минутные прогоны декодера выполнены ускоренно, не являются 90 минутами прослушивания. Внешний HTTPS и слабые устройства не проверены.</p><p><a href="evidence/p07v03-music/protection-audit.json">Контроль файлов</a> · <a href="evidence/p07v03-music/audio/godot-soak.json">Декодер</a> · <a href="evidence/p07v03-music/web/music-loops/loops.json">Циклы Web</a> · <a href="../docs/P07_V03_MUSIC_REPORT.md">Команды и полный отчёт</a></p></section><h2>Запустить игру</h2><p>В Godot 4.7.2 Standard выберите «Импортировать», укажите <code>D:/Projects/MARICRAFT/project.godot</code> и откройте проект. <b>F5</b> запускает меню, <b>F8</b> останавливает игру. Для F5 браузер и сервер не нужны.</p><p>Быстрая проверка Недр: <b>F1 → «Начать тестовую сессию» → «Заново · 3-3»</b>. Изменения тестовой сессии не попадают в обычное сохранение. В публичной Web-сборке F1 отключён.</p><p class="muted">Сохранения браузера и настольной версии раздельные. Исходные MP3, P07 v02/v03 и предыдущие художественные исправления сохранены.</p></main></html>'''
# Prevent two review clips from obscuring one another during comparison.
body=body.replace('</main>',"<script>document.querySelectorAll('video,audio').forEach(el=>el.addEventListener('play',()=>document.querySelectorAll('video,audio').forEach(other=>{if(other!==el)other.pause()})))</script></main>")
(root/'reports/P07_V03_MUSIC_REVIEW.html').write_text(body,encoding='utf8')
print('Review created:',len(rows),'camera windows,',len(music),'audio samples')
