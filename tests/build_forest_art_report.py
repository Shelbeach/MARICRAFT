from pathlib import Path
import json,html
r=Path(__file__).resolve().parents[1]
e=r/'reports/evidence/forest-art'
read=lambda name:json.loads((e/name).read_text(encoding='utf-8-sig'))
coverage=read('audit/coverage.json')
integrity=read('integrity.json')
chapters=read('animation-chapters.json')['chapters']
def img(file,label):
 return f'<figure><a href="evidence/forest-art/{file}"><img loading="lazy" src="evidence/forest-art/{file}" alt="{html.escape(label)}"></a><figcaption>{html.escape(label)}</figcaption></figure>'
def pair(before,after,label):
 return f'<h3>{label}</h3><div class="pair">{img(before,"До")}{img(after,"После · реальная сцена")}</div>'
def video(id,file,poster=''):
 return f'<video id="{id}" controls preload="metadata"'+(f' poster="evidence/forest-art/{poster}"' if poster else '')+f' src="evidence/forest-art/{file}.mp4"></video><p class="controls"><button onclick="play(\'{id}\')">Пуск</button><button onclick="pause(\'{id}\')">Стоп</button><button onclick="rate(\'{id}\',0.5)">0,5×</button><button onclick="rate(\'{id}\',1)">1×</button><button onclick="rate(\'{id}\',2)">2×</button></p>'
head='''<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>MARICRAFT · первая локация 0.4.1</title><style>
:root{color-scheme:dark;font:16px/1.55 system-ui;background:#101c22;color:#edf1eb}body{max-width:1160px;margin:40px auto;padding:0 24px}h1,h2,h3{line-height:1.2}h1{font-size:clamp(30px,5vw,44px)}h2{margin-top:52px}h3{margin-top:30px}a{color:#a6e2ce}p{max-width:980px}.muted,figcaption{color:#b2c3bf}.badge{color:#f5cf8b}.links{display:flex;flex-wrap:wrap;gap:12px}.links a{padding:11px 18px;background:#264843;border-radius:8px;text-decoration:none}button{font:inherit;padding:8px 13px;background:#2a3f46;color:inherit;border:1px solid #5b777c;border-radius:6px;cursor:pointer;margin:4px 4px 4px 0}button:hover{background:#35555b}video{display:block;width:min(960px,100%);background:#000;max-height:72vh}img{display:block;max-width:100%}figure{margin:10px 0}figcaption{margin-top:5px;font-size:14px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:20px}.gallery{display:grid;grid-template-columns:repeat(2,1fr);gap:18px}.strip{overflow:auto;border:1px solid #385158}.strip img{max-width:none;height:270px}.card{background:#192b31;border:1px solid #385158;border-radius:12px;padding:20px;margin:20px 0}table{border-collapse:collapse;width:100%}td,th{border-bottom:1px solid #3a5155;padding:10px;text-align:left}summary{cursor:pointer;padding:12px 0;font-weight:600}.small{font-size:14px}code{overflow-wrap:anywhere}.notice{border-left:3px solid #e2b76e;padding-left:16px}@media(max-width:700px){body{padding:0 16px}.pair,.gallery{grid-template-columns:1fr}td,th{padding:6px;font-size:13px}}
</style><h1>MARICRAFT · первая локация</h1><p class="badge">Рабочая сборка 0.4.1 · 04.11.2026 · художественная приёмка</p>
<p>Замок встроен за силуэт хребта; корни дубов перекрываются грунтом; настилы имеют целые торцы и одну сплошную переднюю балку. Ниже — кадры настоящих сцен и новые записи после этих исправлений.</p>
<div class="links"><a href="../exports/forest-art-release/">Играть · обычная кампания</a><a href="../exports/forest-art/">Диагностика · F1</a><a href="../docs/FOREST_VISUAL_AUDIT.md">Причины и исправления</a></div>
<p class="small muted">A / D — движение, пробел — прыжок, E — магия, S — труба, Esc — пауза. F1 доступна только в диагностической сборке; стенд показывает исходные и откалиброванные кадры. Открывайте одну игровую вкладку за раз.</p>
<nav><a href="#compare">До / после</a> · <a href="#camera">Движение камеры</a> · <a href="#panoramas">Панорамы</a> · <a href="#actors">Анимации</a> · <a href="#gameplay">Игра и бой</a> · <a href="#checks">Проверки</a></nav>
<h2 id="compare">Те же места после исправления</h2>
<p>Скриншоты не ретушировались. Старые дефекты оставлены только в колонке «До». Крупные фрагменты — обрезка и увеличение настоящего кадра, без дорисовки.</p>'''
parts=[head]
parts.append(pair('revision-before-1-1.png','1-1-0.png','Старт 1-1 · тот же обзор камеры'))
parts.append('<div class="gallery">'+img('inspect-castle.png','Замок: основание за реальным силуэтом горы')+img('inspect-roots.png','Корни: просветы закрыты передним грунтом')+img('inspect-deck.png','Настил: целые торцы, одна передняя доска')+'</div>')
parts.append(pair('issue-cave-before.png','1-2-6400.png','Грот · покрытие фоном и непрерывный камень'))
parts.append(pair('issue-forest-before.png','1-1-0.png','Лесная подложка и опоры'))
parts.append(pair('issue-wood-before.png','inspect-deck.png','Обрубленный настил'))
parts.append('''<h2 id="camera">Камера через всю локацию</h2><p>Настоящие сцены Godot, контролируемый проход камеры вправо и обратно. 1-1 — 83 с, 1-2 — 56 с, грот — 4 с, 1-3 — 25 с. Это ревизия окружения, отдельно от прохождения персонажем.</p><div>''')
for key,label in [('1-1','1-1'),('1-2','1-2'),('grotto','Грот'),('1-3','1-3')]:
 parts.append(f'<button onclick="choose(\'cameraMovie\',\'camera-{key}\')">{label}</button>')
parts.append('</div>'+video('cameraMovie','camera-1-1','1-1-0.png')+'<button onclick="half(\'cameraMovie\')">Обратный путь</button>')
parts.append('<details><summary>Все 34 перекрывающихся окна, без пропусков</summary><p>960×540, шаг 450; крайние окна подогнаны к границе карты. В игре камера по вертикали фиксирована: прыжки проверены в игровых эпизодах.</p><div class="gallery">')
for shot in coverage:
 parts.append(img(f'audit/{shot["level"]}-{int(shot["x"])}.png',f'{shot["level"]} · x={int(shot["x"])}'))
parts.append('</div></details><h2 id="panoramas">Панорамы без склейки</h2><p>Каждая панорама снята одним широким SubViewport настоящего мира. Прокручивайте горизонтально; щелчок открывает полный размер. Для оценки игрового масштаба используйте окна выше.</p>')
for key,label in [('1-1','1-1 · лесная тропа'),('1-2','1-2 · переправа'),('mine','Грот'),('1-3','1-3 · арена')]:
 parts.append(f'<h3>{label}</h3><div class="strip">{img("strip-"+key+".png",label)}</div>')
parts.append('<h2 id="actors">Исходник и калибровка анимаций</h2><p>Слева исходник, справа поправки. Полные циклы исправленных клипов в обе стороны; 2×, скорость 0,5×, линии пола и опоры, настоящая коллизия. Равномерный масштаб отдельных поз не меняет контроллер.</p><div>')
names={'human_small':'Малый человек','human_large':'Большой человек','human_magic':'Человек с магией','ogre_small':'Малый огр','ogre_large':'Большой огр','ogre_magic':'Огр с магией','murloc':'Мурлок','chief':'Вожак'}
for c in chapters:
 parts.append(f'<button onclick="jump(\'cycles\',{c["seconds"]})">{names[c["actor"]]} · {c["clip"]}</button>')
parts.append('</div>'+video('cycles','animation-cycles'))
parts.append('<details><summary>Дополнительно: смена остальных состояний, 62 с</summary>'+video('bench','animations-before-after')+'</details>')
parts.append('<h2 id="gameplay">Оба героя в настоящей игре</h2><p>Записи автоматического ввода: движение, прыжки, разворот, настоящее зелье, паром и грот. Локальные эпизоды начинают с подготовленных позиций; это не непрерывное ручное прохождение человеком.</p><button onclick="choose(\'heroMovie\',\'review-hero-human\')">Человек</button><button onclick="choose(\'heroMovie\',\'review-hero-ogre\')">Огр</button>'+video('heroMovie','review-hero-human'))
parts.append('<h3>Руна, три фазы боя, победа и выход</h3><p>Руна получена прыжком. Предупреждения, щит и окно уязвимости связаны с действующим боссом. Снаряды героев различаются внешне; скорость и урон сохранены.</p><button onclick="choose(\'bossMovie\',\'review-boss-human\')">Бой человеком</button><button onclick="choose(\'bossMovie\',\'review-boss-ogre\')">Бой огром</button>'+video('bossMovie','review-boss-human'))
parts.append('''<h2 id="checks">Что проверено</h2><div class="card"><ul>
<li>36 сочетаний: 2 героя × 3 формы × 3 уровня × 30/60 FPS. Отдельно — настоящее получение усилений, тесный потолок, потеря формы в прыжке, грот, переправы и восстановление.</li>
<li>Регрессия босса малой формой и магией, невозможность безопасно застрелять с одной постоянной позиции; награды и прогресс остаются в Campaign.</li>
<li>Визуально просмотрены игровые окна, крупные проблемные фрагменты, панорамы, анимации и кадры движения. Окна 640×360, 1280×720, 1280×800 сохраняют логический обзор 960×540.</li>
<li>250 файлов пакета и их рабочие копии совпадают с исходными хэшами. Текст трёх сцен отличается только флагом оформления; геометрия сохранена. Вторая глава сохраняет оформление S04.</li>
</ul><p><a href="../docs/REPORT_IMPLEMENTATION_TESTS.md">Полный протокол и команды</a> · <a href="../docs/FOREST_ART_INTEGRATION.md">Перечень ресурсов и калибровка</a> · <a href="evidence/forest-art/integrity.json">Хэши и размеры</a></p></div>''')
web=read('web-release.json') if (e/'web-release.json').exists() else {}
log=(e/'web-release.log').read_text(encoding='utf-8-sig',errors='replace')
if 'PASS next chapter starts normally' in log and 'PASS browser console has no runtime errors' in log:
 parts.append('<p>Release Web: обычная кампания пройдена из меню через 1-1, 1-2 и 1-3 до открытия и запуска 2-1, без потери сердец. Обновление страницы сохранило результат, кошелёк и счёт. F1 отключена; ошибок консоли не зарегистрировано. Автоматический клавиатурный драйвер читает координаты через отдельный наблюдатель, не изменяет игру или сохранение.</p>')
else: parts.append('<p class="notice">Итоговый Web-прогон ещё не подтверждён. Эта строка обновится после успешной проверки.</p>')
parts.append('<p>Диагностическая Web-сборка отдельно открыта через интерфейс: F1, выбор модели и клипа, стоп, шаг по кадрам и разворот. Это UI-проверка стенда, не ручное прохождение всей игры.</p><p><a href="evidence/forest-art/web-release.log">Журнал Web</a> · <a href="evidence/forest-art/web-release.json">Измерения Web</a></p>')
parts.append('<table><thead><tr><th>Сборка</th><th>Файлы экспорта, без HTTP-сжатия</th></tr></thead><tbody>')
for build in ['s04-release','forest-art-release','forest-art']:
 n=integrity['exports'][build]['bytes'];parts.append(f'<tr><td>{build}</td><td>{n:,} байт · {n/1048576:.2f} MiB</td></tr>')
parts.append('</tbody></table>')
parts.append('<table><thead><tr><th>Локальный старт 1-1</th><th>До меню</th><th>rAF медиана / p95</th></tr></thead><tbody>')
for file in ['web-baseline.json','web-performance.json']:
 if (e/file).exists():
  m=read(file)['metrics']; key='baseline-start' if file=='web-baseline.json' else 'forest-start'; s=m[key]
  parts.append(f'<tr><td><a href="evidence/forest-art/{file}">'+('До арта' if key=='baseline-start' else 'С артом')+f'</a></td><td>{m["loading"]/1000:.2f} с</td><td>{s["median_ms"]:.1f} / {s["p95_ms"]:.1f} мс</td></tr>')
parts.append('</tbody></table><details><summary>Настоящие экраны Web-проверки</summary><div class="gallery">')
for file,label in [('web-main.png','Главное меню'),('web-heroes.png','Выбор героя'),('web-start-1-1.png','Старт 1-1'),('web-result-1-3.png','Результат 1-3'),('web-durotar.png','Переход в существующий Дуротар')]:parts.append(img(file,label))
parts.append('</div></details>')
parts.append('''<p class="notice">Внешний HTTPS-хостинг и слабые устройства не проверялись. Замер requestAnimationFrame на этом компьютере характеризует выдачу кадров браузером, а не гарантированный FPS на всех устройствах. Художественное принятие остаётся за владельцем; следующие локации в этой задаче не оформлялись.</p>
<script>
// A complete local Blob makes seeking reliable even on a static server without Range.
const media=new Map();
async function prepare(id,source){
 const v=document.getElementById(id);source=source||v.dataset.movie||v.getAttribute('src');
 if(v.dataset.prepared===source)return v;
 v.dataset.movie=source;v.pause();
 if(!media.has(source))media.set(source,fetch(source).then(r=>{if(!r.ok)throw Error('Video '+r.status);return r.blob()}).then(URL.createObjectURL));
 const url=await media.get(source);if(v.dataset.movie!==source)return null;
 v.src=url;v.removeAttribute('poster');v.dataset.prepared=source;
 await new Promise((ok,fail)=>{v.addEventListener('loadedmetadata',ok,{once:true});v.addEventListener('error',fail,{once:true})});return v;
}
async function play(id){const v=await prepare(id);if(v)v.play()}
function pause(id){document.getElementById(id).pause()}
function rate(id,n){document.getElementById(id).playbackRate=n}
async function jump(id,t){const v=await prepare(id);if(v){v.currentTime=t;v.play()}}
async function half(id){const v=await prepare(id);if(v){v.currentTime=v.duration/2;v.play()}}
async function choose(id,file){const v=await prepare(id,'evidence/forest-art/'+file+'.mp4');if(v)v.play()}
for(const v of document.querySelectorAll('video'))v.addEventListener('play',()=>{if(!v.dataset.prepared){v.pause();play(v.id)}});
</script></html>''')
(r/'reports/FOREST_ART_REVIEW.html').write_text('\n'.join(parts),encoding='utf8')
print('Written reports/FOREST_ART_REVIEW.html; windows',len(coverage))
