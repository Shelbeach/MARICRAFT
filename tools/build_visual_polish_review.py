"""Assemble an offline review from actual Godot viewport captures; no asset edits."""
from pathlib import Path
import json
from html import escape

root = Path(__file__).resolve().parents[1]
evidence = root / 'reports/evidence/visual-polish'
coverage = json.loads((evidence / 'after/coverage.json').read_text(encoding='utf8'))
choices = [
    ('1-2-1800', 'Труба и деревянные опоры'),
    ('1-3-1838', 'Арена: каменные площадки и замок'),
    ('grotto-6400', 'Грот: вход и лестница'),
    ('grotto-6720', 'Грот: обратная труба'),
    ('1-3-0', 'Подступы: колонны и ступени'),
    ('1-1-450', 'Лесопилка: стыки опор'),
]
options = ''.join(f'<option value="{key}">{escape(label)}</option>' for key, label in choices)
gallery = ''.join(f'<a href="evidence/visual-polish/after/{row["id"]}.png" target="_blank"><img loading="lazy" src="evidence/visual-polish/after/{row["id"]}.png" alt="{row["id"]}"><span>{row["id"]}</span></a>' for row in coverage)
def video(name, title):
    return f'<figure><video controls loop muted preload="metadata" src="evidence/visual-polish/{name}.mp4"></video><figcaption>{title}</figcaption></figure>'
bosses = ''.join(video(f'boss-{i}', title) for i,title in enumerate(['Выстрел: сбор воды и фиксация прицела', 'Рывок: направленные гребни воды', 'Прыжок: водоворот и расходящиеся волны']))
walks = ''.join(video('walk-'+level, label) for level,label in [('1-1','Полный осмотр 1-1'),('1-2','Полный осмотр 1-2'),('grotto','Грот'),('1-3','Полный осмотр 1-3')])
page = '''<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>MARICRAFT · визуальная ревизия 0.4.3</title><style>
*{box-sizing:border-box}body{margin:0;background:#101c20;color:#e9ede5;font:16px/1.6 system-ui,sans-serif}main{max-width:1120px;margin:auto;padding:42px 24px 70px}h1{font-size:clamp(27px,4vw,44px);line-height:1.12;max-width:900px;margin:12px 0 22px}h2{margin-top:44px;font-size:25px}p{max-width:850px;color:#b9cacc}a{color:#a9e4cc}small,.eyebrow{color:#9ec5b9}.eyebrow{letter-spacing:.13em;font-size:12px}select{background:#21363c;color:#f1f4ef;border:1px solid #62827d;border-radius:7px;padding:12px;font:inherit;max-width:100%;margin:10px 0 18px}.compare{position:relative;aspect-ratio:16/9;border:1px solid #4b6465;background:#17262c;overflow:hidden}.compare img{position:absolute;width:100%;height:100%;inset:0}.compare #old{clip-path:inset(0 50% 0 0)}.label{position:absolute;bottom:14px;background:#101c20dd;padding:3px 12px;font-size:13px}.left{left:12px}.right{right:12px}.divider{position:absolute;left:50%;top:0;bottom:0;border-left:2px solid white;pointer-events:none}input{width:100%;accent-color:#8ad1b6}figure{margin:0}video{width:100%;border-radius:6px;background:#172a30}figcaption{font-size:14px;color:#aebfc2;padding:8px 0 18px}.video-grid{display:grid;grid-template-columns:repeat(2,1fr);gap:22px}.boss-grid figure:first-child{grid-column:1/-1;max-width:960px}.gallery{display:grid;grid-template-columns:repeat(2,1fr);gap:18px;margin-top:20px}.gallery img{width:100%;display:block}.gallery span{font-size:13px}.gallery a{text-decoration:none}details{border-top:1px solid #32494c;padding:20px 0}summary{cursor:pointer;font-size:20px}.facts{border-left:3px solid #76b99e;padding:3px 0 3px 20px}li{margin:8px 0}footer{border-top:1px solid #32494c;padding-top:20px;margin-top:35px;color:#90a6a9;font-size:14px}@media(max-width:720px){main{padding:24px 14px}.video-grid,.gallery{grid-template-columns:1fr}}
</style><main><div class="eyebrow">MARICRAFT / 0.4.3 / 04.11.2026</div>
<h1>Опоры, цельный грот<br>и водяные предупреждения</h1>
<p>Сравнение настоящих кадров Godot в одинаковых точках камеры. Передвиньте ползунок: слева прежняя сборка 0.4.2, справа исправленная 0.4.3.</p>
<label for="scene">Место проверки</label><br><select id="scene">OPTIONS</select>
<div class="compare"><img id="new" alt="После исправления"><img id="old" alt="До исправления"><div class="divider" id="divider"></div><span class="label left">До · 0.4.2</span><span class="label right">После · 0.4.3</span></div>
<label for="split"><small>Граница сравнения</small></label><input id="split" type="range" min="0" max="100" value="50">
<ul><li>Опоры входят в поверхность; узкие площадки стоят на одной колонне. Каменные уступы сохраняют весь нарисованный нижний край.</li><li>Корпус трубы удлинён до основания, низ заглублён на 4 единицы; обод остаётся на высоте настоящей коллизии.</li><li>Замок смягчён и приглушён цветом дальнего плана. Его основание по-прежнему закрывают горы.</li><li>Грот использует одну цельную камеру на всю высоту экрана. Перевёрнутая копия и обрезанная наложенная аркада убраны.</li></ul>
<h2>Три предупреждения в движении</h2><p>Нативная запись 60 кадров/с. Вода собирается перед выстрелом, направленные гребни обозначают рывок, водоворот показывает точку приземления. Эффект прекращается при начале настоящей атаки. Тайминги, урон и движение босса сохранены.</p><div class="video-grid boss-grid">BOSSES</div>
<div class="facts"><strong>Проверка</strong><p>34 перекрывающихся окна, непрерывный проезд камеры, 3 размера окна. Автоматически: 18 маршрутов обоими героями во всех формах, грот и рост, предупреждения в обе стороны, бой прыжками и магией, прежние анимации. Подробный протокол — в документации проекта.</p></div>
<h2>Полный осмотр уровней</h2><p>Камера движется по настоящей сцене; мир приостановлен, проезд замедлен для осмотра декораций. Эти записи показывают окружение, а не прохождение игроком. <a href="evidence/visual-polish/support-contacts.jpg" target="_blank">Все 66 контактов опор крупным планом</a>.</p><div class="video-grid">WALKS</div>
<details><summary>Все 34 окна после исправлений</summary><div class="gallery">GALLERY</div></details>
<footer>Исходные PNG и SpriteFrames не перезаписаны. Геометрия и коллизии сохранены. Художественная приёмка владельцем остаётся открытой.<br><a href="../exports/forest-art-release/">Открыть Web-версию</a> · <a href="../exports/forest-art/">Диагностическая версия F1</a></footer>
</main><script>
const scene=document.getElementById('scene'),split=document.getElementById('split');
function changeScene(){document.getElementById('new').src='evidence/visual-polish/after/'+scene.value+'.png';document.getElementById('old').src='evidence/visual-polish/before/'+scene.value+'.png';}
scene.onchange=changeScene;split.oninput=()=>{document.getElementById('old').style.clipPath=`inset(0 ${100-split.value}% 0 0)`;document.getElementById('divider').style.left=split.value+'%';};changeScene();
</script></html>'''
for key, value in [('OPTIONS',options),('BOSSES',bosses),('WALKS',walks),('GALLERY',gallery)]:
    page = page.replace(key, value)
(root/'reports/VISUAL_POLISH_REVIEW.html').write_text(page, encoding='utf8')
print('reports/VISUAL_POLISH_REVIEW.html')
