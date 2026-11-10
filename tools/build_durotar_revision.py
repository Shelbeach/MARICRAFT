"""Authored S04 revision. Produces only the three editable Godot level scenes.
No randomness, runtime generation, asset changes, or profile migration.
"""
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[1]
REFS={
 'floor':'objects/test_platform', 'block':'objects/reward_block',
 'kobold':'enemies/kobold','murloc':'enemies/murloc','coin':'objects/coin',
 'player':'actors/forest_player','ferry':'objects/ferry','pipe':'objects/pipe',
 'spikes':'objects/spikes','rune':'objects/rune','boss':'enemies/candle_foreman'}
def v(x,y): return f'Vector2({x}, {y})'
def q(s): return json.dumps(s,ensure_ascii=False)

class Map:
 def __init__(self,id,finish,checkpoint,cave=0,width=0,mine=False):
  self.id=id;self.nodes=[];self.ncoin=0;self.props=[];self.sections={}
  self.root={'checkpoint_x':checkpoint,'finish_x':finish,'cave_left':cave,'cave_width':width,'mine_main':str(mine).lower()}
  self.floor('WestCliff',-40,100,40,480)
  self.floor('EastCliff',finish+128,100,40,480)
 def node(self,type,name,x,y,**props):
  self.nodes.append((type,name,{'position':v(x,y),**props}))
 def floor(self,name,x,y,w,h=None,wood=False):
  self.node('floor',name,x,y,size=v(w,h if h is not None else 580-y),construction=q('timber' if wood else 'redrock'))
 def deck(self,name,x,y,w):self.floor(name,x,y,w,20,True)
 def block(self,name,x,y,kind='fragile',amount=0,bonus=0):
  self.node('block',name,x,y,reward_id=q(self.id+'/'+name),kind=q(kind),amount=amount,vein_bonus=bonus)
 def row(self,name,x,y,count,chest=-1,kind='coins',amount=16):
  for i in range(count):self.block(name if i==chest else name+str(i),x+i*32,y,kind if i==chest else 'fragile',amount if i==chest else 0)
 def enemy(self,name,x,y,patrol=42,type='kobold'):
  self.node(type,name,x,y-2,reward_id=q(self.id+'/'+name),patrol_width=patrol)
 def coins(self,points):
  old={'2-1':31,'2-2':45,'2-3':17}[self.id]
  # Preserve the original coin IDs, including prefix names, when moving the trail.
  old_names={'2-1':'Road','2-2':'Route','2-3':'Path'}
  for x,y in points:
   self.ncoin+=1
   name=self.old_coin_ids[self.ncoin-1] if self.ncoin<=len(self.old_coin_ids) else self.id+'/revision_coin_%02d'%self.ncoin
   self.node('coin','Coin%02d'%self.ncoin,x,y,reward_id=q(name))
 def trail(self,xs,y):self.coins([(x,y) for x in xs])
 def arc(self,x,y,gap=110):self.coins([(x-25,y-44),(x+gap/2,y-98),(x+gap+25,y-44)])
 def ferry(self,name,x,y,dx,dy=0,period=4.6):self.node('ferry',name,x,y,travel=v(dx,dy),period=period)
 def decor(self,id,*xs):self.props.extend({'id':id,'x':x} for x in xs)
 def save(self):
  parts=['[gd_scene format=3]','[ext_resource type="Script" path="res://scripts/gameplay/durotar_level.gd" id="level"]']
  used={t for t,n,p in self.nodes}|{'player'}
  parts += [f'[ext_resource type="PackedScene" path="res://scenes/{REFS[t]}.tscn" id="{t}"]' for t in REFS if t in used]
  if 'boss' in used:parts+=['[sub_resource type="RectangleShape2D" id="GateShape"]\nsize = Vector2(18, 480)']
  props={**self.root,'scenery':json.dumps(self.props,ensure_ascii=False),'sections':'{'+', '.join(f'{x}: {q(t)}' for x,t in self.sections.items())+'}'}
  parts+=['[node name="Durotar" type="Node2D"]\nscript = ExtResource("level")\n'+'\n'.join(f'{k} = {val}' for k,val in props.items())]
  if 'boss' in used:parts += [f'[node name="Gate" type="StaticBody2D" parent="."]\nposition = {v(self.root["finish_x"]-80,240)}','[node name="Hitbox" type="CollisionShape2D" parent="Gate" groups=["test_hitboxes"]]\nshape = SubResource("GateShape")']
  for t,n,props in self.nodes:parts += [f'[node name="{n}" parent="." instance=ExtResource("{t}")]\n'+'\n'.join(f'{k} = {val}' for k,val in props.items())]
  parts += ['[node name="Player" parent="." instance=ExtResource("player")]\nposition = Vector2(96, 475)']
  (ROOT/f'scenes/levels/durotar_{self.id.replace("-","_")}.tscn').write_text('\n\n'.join(parts)+'\n',encoding='utf-8')

baseline=json.loads((ROOT/'reports/evidence/durotar-revision/layout-before.json').read_text(encoding='utf-8'))
def start(*args,**kw):
 m=Map(*args,**kw);m.old_coin_ids=[n['reward_id'].strip('"') for n in baseline['durotar_'+m.id.replace('-','_')]['nodes'] if n['type']=='coin'];return m

m=start('2-1',5300,2360)
for name,x,y,w in [('Trail',0,480,800),('Shelf',900,448,340),('Mesa',1240,416,290),('FarMesa',1650,416,210),('Descent',1860,448,250),('Camp',2110,480,410),('HaulStep',2520,440,290),('HatLane',2920,480,450),('RedRise',3370,416,230),('EastSpur',3710,416,280),('FreightYard',3990,480,490),('WatchRidge',4600,448,330),('GateRoad',4930,480,498)]:m.floor(name,x,y,w)
m.floor('TrailStep',470,432,76);m.deck('TrailLookout',590,352,160)
m.floor('RidgeStep',1000,400,60);m.deck('RidgeDeck',1100,320,170);m.deck('RidgeUpper',1360,278,140)
m.floor('CacheStep',1720,370,64);m.deck('CacheDeck',1830,290,180)
m.floor('RubbleStep',2472,408,48);m.floor('LoadingStep',2980,432,76);m.deck('LoadingDeck',3100,352,206)
m.deck('Lookout',3780,312,160)
m.ferry('CargoLift',4230,388,0,-112,4.8);m.deck('HighCargo',4330,276,128)
m.row('Supplies',312,368,5,2,'potion',0);m.row('TrailPay',610,240,3,1,'coins',18)
m.row('RidgePay',1382,166,3,1,'coins',20);m.row('CacheSeal',1846,178,5,2,'coins',22)
m.row('HaulCrust',2620,328,4);m.coins([(2652,276),(2716,276)]);m.row('HatWorkshop',3120,240,5,2,'coins',16)
m.row('WatchPay',3810,200,3,1,'coins',24);m.row('CargoPay',4350,144,3,1,'coins',26)
m.row('GateCrust',4760,336,4)
for args in [('Scout',225,480,30),('RidgeMiner',1170,320,35),('Hauler',2420,480,40),('RearGuard',3220,480,40,'murloc'),('LookoutGuard',3475,416,78),('CargoMiner',4390,276,28),('LastScout',5100,480,50)]:m.enemy(*args)
m.trail([155,210,265],448);m.trail([505,640,704],316);m.arc(800,480,100);m.trail([1150,1210],300);m.arc(1530,416,120);m.trail([1880,1950],254);m.trail([2190,2270,2320],448);m.arc(2810,440,110);m.trail([3140,3220,3280],316);m.arc(3600,416,110);m.trail([3820,3880],276);m.trail([4240,4370,4420],240);m.arc(4480,480,120);m.trail([4680,4860,5010,5200],412)
m.decor('camp_canopy',150);m.decor('barrel',260);m.decor('dry_grass',790,1180,2080,3690,4935);m.decor('thorn',950,1750,2980,4780);m.decor('boulder',1460,2240,4050);m.decor('scree',1920,3340,4660);m.decor('fence',2340,5200);m.decor('crate',3070,4380);m.decor('rail',4170);m.decor('cart',4170);m.decor('sign',4950)
m.sections={60:'ДУРОТАР · КРАСНЫЙ ТРАКТ',470:'Сторожевой уступ · награда наверху',1010:'Верхняя тропа через скалы',2130:'Привал · шляпа опасна после пинка',2990:'Рудный двор · разбейте кладку',4010:'Грузовой подъёмник',4650:'Последняя гряда'};m.save()

m=start('2-2',5400,2350,6800,2080,True)
for name,x,y,w in [('Apron',0,480,700),('Station',1050,448,370),('SwitchRoad',1420,480,430),('HaulRoad',2200,480,1040),('RockBench',3240,448,410),('EastStation',4020,448,360),('OreRise',4380,416,210),('KilnBench',4700,416,190),('KilnRoad',4890,480,638)]:m.floor(name,x,y,w)
m.floor('AssayStep',250,432,96);m.deck('AssayDeck',414,356,210)
m.deck('SwitchDeck',1460,348,210);m.floor('GalleryStep',2620,432,96);m.deck('GalleryWest',2770,352,190);m.deck('GalleryEast',3130,288,190)
m.floor('KilnStep',5010,432,64);m.deck('KilnGantry',5120,352,190)
m.ferry('WestLift',760,450,230,-16,4.5);m.ferry('EastLift',1910,456,230,0,4.8);m.ferry('DeepLift',3710,432,250,0,4.4)
m.row('SurveyPay',470,224,4,2,'coins',18);m.row('GateGrowth',2390,368,5,2,'potion',0)
m.row('SwitchPay',1500,216,4,1,'coins',20);m.row('GalleryBridge',2992,320,3);m.row('GalleryPay',3152,156,5,2,'coins',26);m.row('KilnCrust',4290,336,3);m.row('KilnPay',5160,220,4,1,'coins',18)
for args in [('Surveyor',530,356,38),('Switchman',1580,348,38),('RailMiner',2860,352,35),('GalleryGuard',3210,288,38),('KilnGuard',5230,352,40)]:m.enemy(*args)
m.node('spikes','KilnSpikes',3490,448);m.node('pipe','Entry',3060,480,destination=v(6880,475),prompt=q('Боковая свечная жила'))
m.node('pipe','Vent',4160,448,mode=q('ambush'),enemy_id=q('2-2/VentGuard'))
m.node('pipe','Return',8760,480,mode=q('return'),destination=v(3160,475),prompt=q('Вернуться в главную шахту'))
m.floor('MineWall',6760,100,40,480);m.floor('MineFloor',6800,480,2080);m.floor('EndMine',8880,100,40,480)
m.floor('Tailings',7110,432,100);m.floor('OreBench',7210,384,150);m.deck('Gantry',7460,304,220);m.floor('OrePier',7900,432,120);m.deck('OreHood',8090,336,190);m.deck('Vault',8450,264,180)
m.ferry('VeinLift',8390,388,0,-112,4.6)
m.row('VeinPay',7510,192,4,1,'coins',30);m.row('LowerPay',8170,224,4,1,'coins',24)
m.block('CrustA',7440,320);m.block('CrustB',7710,320,bonus=8);m.row('VaultSeal',8480,152,4,2,'coins',22)
m.node('spikes','SlagSpikes',7800,480);m.enemy('VeinMiner',8115,480,65)
m.trail([155,210],448);m.trail([455,520,590],320);m.arc(700,480,350);m.trail([1120,1220,1330],416);m.trail([1510,1600],312);m.arc(1850,480,350);m.trail([2280,2340,2530],448);m.trail([2810,2900,3005,3070],282);m.trail([3170,3250],252);m.arc(3650,448,370);m.arc(4590,416,110);m.trail([5150,5240],316);m.trail([5340],448)
m.trail([6940,7020],440);m.trail([7160],396);m.trail([7250,7320],348);m.trail([7500,7570,7640],268);m.arc(7750,480,110);m.trail([8170,8250],300);m.trail([8480,8550,8610],228);m.trail([8700],440)
m.decor('tools',190,2490,6970);m.decor('rail',180,1290,2668,4970,6930,8650);m.decor('cart',180,2668,8650);m.decor('ore_pile',590,1560,3290,4490,7330,7990);m.decor('crate',1380,5040);m.decor('candles',290,1790,2330,2900,4140,4830,7060,7740,8350);m.decor('sign',3050)
m.sections={60:'ШАХТА КОБОЛЬДОВ · РУДНЫЙ ПУТЬ',590:'Первая клеть · дождитесь платформы',1450:'Перевалочная галерея',2240:'Привал шахтёров',2650:'Верхний мост или боковая жила',3510:'Глубокий разрез',4890:'Грузовая станция',6850:'БОКОВАЯ ШТОЛЬНЯ · СВЕЧНАЯ ЖИЛА'};m.save()

m=start('2-3',4020,2540)
for name,x,y,w in [('Approach',0,480,520),('Rampart',630,448,250),('OreSteps',880,416,210),('Breach',1210,416,260),('Descent',1470,448,210),('Staging',1680,480,500),('Forge',2300,480,1848)]:m.floor(name,x,y,w)
m.floor('Scale',200,432,76);m.deck('AssayStand',320,352,120);m.floor('RampartStep',690,400,60);m.deck('RampartDeck',790,320,170);m.deck('BreachDeck',1260,304,170)
m.floor('LoadingStep',1770,432,90);m.deck('LoadingGallery',1900,352,220)
m.floor('ArenaLeftPlinth',2900,408,128);m.floor('ArenaRightPlinth',3550,408,128)
m.row('ShiftPay',332,240,3,1,'coins',14);m.row('ForemanPay',820,188,4,1,'coins',14);m.row('BreachCrust',1300,208,4);m.coins([(1332,156),(1396,156)]);m.row('ForgeCache',1930,220,5,2,'coins',24);m.row('LastCrust',2390,368,3)
m.enemy('GateScout',875,320,55);m.enemy('Sentry',1815,432,24);m.enemy('Hauler',2010,352,76)
m.node('rune','LastRune',2640,364,reward_id=q('2-3/LastRune'))
m.node('boss','Boss',3300,480,arena_start=2780)
m.trail([135,170],448);m.trail([350,410],316);m.coins([(495,436),(575,382),(710,364)]);m.trail([830,900],284);m.arc(1090,416,120);m.trail([1300,1380],268);m.trail([1550,1730],410);m.trail([1940,2010,2080],316);m.arc(2180,480,120);m.trail([2490,2570],448);m.trail([2930,2990,3580,3640],372);m.trail([3830,3920],448)
m.decor('fence',150,1730);m.decor('barrel',225);m.decor('scree',935,1580);m.decor('thorn',664);m.decor('rail',2000);m.decor('cart',2000);m.decor('camp_canopy',2600);m.decor('tools',2740);m.decor('candles',2860,3720,3870);m.decor('arena_kiln',3380)
m.sections={60:'ДУРОТАР · ПУТЬ К ПЛАВИЛЬНЕ',600:'Внешние укрепления',1190:'Пролом в кладке',1740:'Грузовая галерея',2480:'Последний привал',2790:'ЗАЛ СВЕЧНОГО ГЛАВАРЯ'};m.save()
print('Wrote three authored level scenes. Existing reward IDs retained where reused.')
