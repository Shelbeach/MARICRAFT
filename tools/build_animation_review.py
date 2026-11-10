from pathlib import Path
import json, html
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'reports/evidence/animation-fix'
data=json.loads((OUT/'motion-after.json').read_text(encoding='utf8'))
names=['Человек · малая','Человек · большая','Человек · магия','Огр · малая','Огр · большая','Огр · магия','Мурлок']
buttons=''.join(f'<button onclick="seek({p["seconds"]})">{name}</button>' for p,name in zip(data['chapters'],names))
actors=json.loads((ROOT/'assets/forest_art/characters/animations.json').read_text(encoding='utf8'))
galleries=''
for model,actor in actors.items():
    pics=''.join(f'<a href="evidence/animation-fix/{p.name}" target="_blank"><img loading="lazy" src="evidence/animation-fix/{p.name}" alt="{model}: часть {i+1}"></a>' for i,p in enumerate(sorted(OUT.glob(f'corrected-{model}-*.png'))))
    galleries+=f'<details><summary>{html.escape(actor["name"])} · {sum(c["count"] for c in actor["clips"].values())} кадров</summary><p>Нативный рендер Godot. Малая форма показана 4×, остальные 2× для покадрового просмотра. Линия — опора ног. Клик открывает полный размер.</p>{pics}</details>'
page='''<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>MARICRAFT · анимации 0.4.2</title>
<style>body{margin:0;background:#102126;color:#e6eeea;font:17px/1.6 system-ui}main{max-width:1400px;margin:auto;padding:40px 24px}h1{font-size:42px;line-height:1.15}h2{margin-top:44px}p{max-width:1050px}a{color:#91e6c5}button,summary{cursor:pointer;background:#25444c;color:#f4e0a3;border:1px solid #607a70;border-radius:6px;padding:9px 14px;font:inherit;margin:4px}video,img{width:100%;display:block;background:#182d32;border-radius:8px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:20px}.tag{color:#96b8b6}.controls{margin:20px 0}details{margin:14px 0}details img{margin:12px 0}figure{margin:0}figcaption{margin:6px 0 12px}code{color:#f2d18b}@media(max-width:900px){.pair{grid-template-columns:1fr}h1{font-size:32px}}</style>
<main><p class="tag">MARICRAFT / 0.4.2 / 04.11.2026</p><h1>Бег без задержки приземления.<br>Стабильный размер поз.</h1>
<p>Исправлены скачки масштаба у человека и огра во всех трёх формах: одинаковые нарисованные позы теперь имеют одинаковый размер в разных клипах. Частота шагов зависит от скорости и длины шага. Приземление прерывается сразу при движении или новом прыжке.</p>
<p>Лесные мурлоки увеличены на <strong>40%</strong>, включая выход из трубы, разворот и поражение. Физические тела, скорость движения и награды сохранены. Исходные PNG, исправленные фон и грунт не перезаписаны.</p>
<h2>Одинаковый игровой сценарий до и после</h2><p>Записи настоящего настольного Godot, одна камера и одни нажатия. Здесь 15 кадров/с для синхронного сравнения; ниже — новая запись 60 кадров/с. Это автоматизированные игровые прогоны, не ручное прохождение человеком.</p>
<div class="controls">BUTTONS<br><button onclick="playBoth()">Смотреть обе записи</button><button onclick="pauseBoth()">Пауза</button><button onclick="rate(.5)">0,5×</button><button onclick="rate(1)">1×</button></div>
<div class="pair"><figure><figcaption>До · 60 тактов со скользящей позой приземления</figcaption><video id="before" controls preload="metadata" src="evidence/animation-fix/motion-before.mp4"></video></figure><figure><figcaption>После · 0 таких тактов на том же маршруте</figcaption><video id="after" controls preload="metadata" src="evidence/animation-fix/motion-after.mp4"></video></figure></div>
<h2>Движение после исправления · 60 кадров/с</h2><video controls preload="metadata" src="evidence/animation-fix/motion-after-60.mp4"></video>
<h2>Размер обычных врагов на уровне</h2><div class="pair"><figure><figcaption>До</figcaption><img src="evidence/animation-fix/enemy-before.png"></figure><figure><figcaption>После · 1,4×</figcaption><img src="evidence/animation-fix/enemy-after.png"></figure></div>
<h2>Покадровая проверка всего комплекта</h2><p>Проверены все 8 моделей: 6 вариантов героев, мурлок и вожак. Изменены калибровки героев и обычного мурлока; босс сохранён. Естественное сгибание коленей, поднятая рука, дыхание и лежащая поза не выравнивались по общей высоте.</p>GALLERIES
<h2>Проверки</h2><p><a href="evidence/animation-fix/animation_regression.log">Переходы, масштаб, повторный прыжок, реальное наступание на врага</a> · <a href="evidence/animation-fix/forest_art_visual_contract.log">Коллизии, формы, смерть и восстановление</a> · <a href="evidence/animation-fix/routes-human.log">9 маршрутов человека</a> · <a href="evidence/animation-fix/routes-ogre.log">9 маршрутов огра</a> · <a href="evidence/animation-fix/web-release.log">Web-кампания и сохранение</a></p>
<p><a href="../exports/forest-art-release/">Открыть Web-игру</a> · <a href="../exports/forest-art/">Debug с F1 → Стенд анимаций</a>. В Godot открыть <code>D:/Projects/MARICRAFT/project.godot</code> и нажать F5.</p></main>
<script>const videos=[document.querySelector('#before'),document.querySelector('#after')];function seek(t){videos.forEach(v=>{v.currentTime=t;v.pause()})}function playBoth(){videos[0].currentTime=videos[1].currentTime;videos.forEach(v=>v.play())}function pauseBoth(){videos.forEach(v=>v.pause())}function rate(n){videos.forEach(v=>v.playbackRate=n)}</script></html>'''
(ROOT/'reports/ANIMATION_REVIEW.html').write_text(page.replace('BUTTONS',buttons).replace('GALLERIES',galleries),encoding='utf8')
print('reports/ANIMATION_REVIEW.html')
