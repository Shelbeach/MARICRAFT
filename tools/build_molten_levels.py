"""Authored final chapter. Writes only molten_3_[123].tscn; no P07 dependencies."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
REFS={'floor':'objects/test_platform','block':'objects/reward_block','kobold':'enemies/kobold',
      'murloc':'enemies/murloc','coin':'objects/coin','player':'actors/forest_player',
      'ferry':'objects/ferry','pipe':'objects/pipe','spikes':'objects/spikes','rune':'objects/rune',
      'boss':'enemies/ragnaros','hazard':'objects/molten_hazard'}
def q(s):return json.dumps(s,ensure_ascii=False)
def v(x,y):return f'Vector2({x}, {y})'
class Map:
 def __init__(self,id,finish,checkpoint,cave=0,width=0):
  self.id=id;self.nodes=[];self.count=0
  self.props={'chapter_level':q(id),'finish_x':finish,'checkpoint_x':checkpoint,'cave_left':cave,'cave_width':width}
  self.floor('WestWall',-40,80,40,500);self.floor('EastWall',finish+128,80,40,500)
 def node(self,type,name,x,y,**props):self.nodes.append((type,name,{'position':v(x,y),**props}))
 def floor(self,name,x,y,w,h=None):self.node('floor',name,x,y,size=v(w,h if h is not None else 580-y),construction=q('masonry'))
 def deck(self,name,x,y,w):self.floor(name,x,y,w,20)
 def row(self,name,x,y,n,chest=-1,kind='coins',amount=16):
  for i in range(n):
   key=name if i==chest else name+str(i)
   self.node('block',key,x+i*32,y,reward_id=q(self.id+'/'+key),kind=q(kind if i==chest else 'fragile'),amount=amount if i==chest else 0,vein_bonus=0)
 def enemy(self,name,x,y,p=70,kind='kobold'):self.node(kind,name,x,y-2,reward_id=q(self.id+'/'+name),patrol_width=p)
 def coins(self,points):
  for x,y in points:
   self.count+=1;name=f'Coin{self.count:03}'
   self.node('coin',name,x,y,reward_id=q(self.id+'/'+name))
 def trail(self,xs,y):self.coins([(x,y) for x in xs])
 def arc(self,x,y,gap):self.coins([(x-22,y-42),(x+gap/2,y-96),(x+gap+24,y-42)])
 def ferry(self,name,x,y,dx,dy=0,period=4.8):self.node('ferry',name,x,y,travel=v(dx,dy),period=period)
 def vent(self,name,x,y,width=60,height=64,offset=0):self.node('hazard',name,x,y,width=width,height=height,offset=offset)
 def lava(self,name,left,right):self.node('hazard',name,(left+right)/2,560,kind=q('lava'),width=right-left,height=46)
 def save(self):
  chunks=['[gd_scene format=3]','[ext_resource type="Script" path="res://scripts/gameplay/molten_level.gd" id="level"]']
  used={x[0] for x in self.nodes}|{'player'}
  chunks += [f'[ext_resource type="PackedScene" path="res://scenes/{REFS[t]}.tscn" id="{t}"]' for t in REFS if t in used]
  if 'boss' in used:chunks+=['[sub_resource type="RectangleShape2D" id="GateShape"]\nsize = Vector2(18, 480)']
  chunks+=['[node name="MoltenCore" type="Node2D"]\nscript = ExtResource("level")\n'+'\n'.join(f'{k} = {val}' for k,val in self.props.items())]
  if 'boss' in used:chunks += [f'[node name="Gate" type="StaticBody2D" parent="."]\nposition = {v(self.props["finish_x"]-80,240)}','[node name="Hitbox" type="CollisionShape2D" parent="Gate" groups=["test_hitboxes"]]\nshape = SubResource("GateShape")']
  for t,n,props in self.nodes:chunks += [f'[node name="{n}" parent="." instance=ExtResource("{t}")]\n'+'\n'.join(f'{k} = {val}' for k,val in props.items())]
  chunks+=['[node name="Player" parent="." instance=ExtResource("player")]\nposition = Vector2(96, 475)']
  path=ROOT/f'scenes/levels/molten_{self.id.replace("-","_")}.tscn'
  path.write_text('\n\n'.join(chunks)+'\n',encoding='utf-8')
  print(self.id,len(self.nodes),'objects;',self.count,'loose coins')

m=Map('3-1',4300,2420)
for n,x,y,w in [('Gatehouse',0,480,780),('BasaltFirst',892,440,340),('BasaltSecond',1344,440,208),('LowerForge',1552,480,708),('Warehouse',2260,480,840),('HighExit',3270,340,240),('CoolingStep',3510,400,120),('LastRise',3742,440,280),('ExitRoad',4022,480,406)]:m.floor(n,x,y,w)
m.floor('SupplyStep',250,432,80);m.deck('SupplyBalcony',380,352,200)
m.row('GateGrowth',410,240,5,2,'potion',0)
m.vent('FirstVent',650,480)
m.enemy('BasaltGuard',1110,440,80,'murloc')
m.floor('UpperApproach',1580,432,76);m.deck('UpperWest',1696,350,164);m.deck('UpperEast',1980,270,220)
m.row('UpperBridge',1886,318,3);m.row('WestCache',1712,238,4,1,amount=18);m.row('UpperCache',2020,158,5,2,amount=22)
m.vent('LowerValveA',1750,480,60,64,0.6);m.vent('LowerValveB',2090,480,60,64,2.0)
m.row('WarehouseCrust',2540,368,4,2,amount=16)
m.floor('WarehouseStep',2680,432,76);m.deck('RuneGallery',2800,352,210)
m.row('RuneSeal',2834,240,5,2,'rune',0)
m.enemy('Keeper',2940,480,95)
m.ferry('ChainLift',3160,460,0,-120,4.8)
m.vent('LastValve',3870,440,58,64,1.1)
m.node('spikes','ExitSpikes',4115,480)
m.row('LastCache',4200,368,3,1,amount=18)
m.trail([160,208],446);m.trail([401,473,545],316);m.arc(780,480,112);m.arc(1232,440,112)
m.trail([1700,1770,1840],314);m.trail([1890,1950],282);m.trail([2010,2090,2160],234)
m.coins([(1620,396),(1860,444),(2190,444)]);m.trail([2340,2420,2490],444);m.trail([2824,2890,2960],316)
m.trail([3140,3170],304);m.trail([3330,3410],304);m.arc(3630,400,112);m.trail([3780,3970,4240],404)
for n,l,r in [('LavaA',780,892),('LavaB',1232,1344),('LiftLava',3100,3270),('LavaC',3630,3742)]:m.lava(n,l,r)
m.save()

m=Map('3-2',5540,2290,6600,1680)
for n,x,y,w in [('Sorting',0,480,700),('Arrival',1060,440,270),('TowerFoot',1330,480,690),('RestFoundry',2020,480,760),('CounterBank',3150,380,300),('SlagBank',3450,440,260),('Casting',3710,480,730),('FinalIsland',4780,440,230),('MasterStep',5122,400,180),('Workshop',5302,480,366)]:m.floor(n,x,y,w)
m.floor('SortStep',280,432,80);m.deck('SortShelf',420,352,210);m.row('SortGrowth',450,240,5,2,'potion',0)
m.enemy('Sorter',570,480,76,'murloc')
m.ferry('LavaCarrier',760,456,240,-16,4.6)
m.floor('TowerStep',1430,432,80);m.deck('TowerDeck',1560,352,240);m.deck('CrownDeck',1890,272,220)
m.row('CrownBridge',1816,320,3);m.row('CrownCache',1922,160,5,2,amount=24);m.row('TowerCache',1590,240,5,2,amount=22)
m.enemy('HighSmith',1230,440,55);m.vent('TowerValve',1920,480,64,64,1.8)
m.row('RestSupply',2360,368,5,2,'rune',0)
m.node('pipe','Entry',2580,480,destination=v(6680,475),prompt=q('Тигельная комната · необязательное испытание'))
m.ferry('Counterweight',2840,452,250,-72,5.0)
m.floor('CounterStep',3240,332,70);m.deck('CounterGallery',3340,252,160);m.row('CounterCache',3370,140,3,1,amount=20)
m.node('spikes','SlagTeeth',3580,440)
m.node('pipe','DangerVent',3890,480,mode=q('ambush'),enemy_id=q('3-2/DangerGuard'))
m.floor('BypassStep',3990,432,80);m.deck('BypassDeck',4110,352,210);m.row('BypassCache',4140,240,4,1,amount=20)
m.node('spikes','CastingTeeth',4180,480);m.vent('CastingValve',4360,480,60,64,0.3)
m.ferry('LastBridge',4500,456,220,-16,4.5)
m.vent('LastBreath',4880,440,56,58,1.5)
m.row('FinalCache',5440,368,3,1,amount=18)
m.floor('ChamberWestWall',6560,80,40,500);m.floor('ChamberFloor',6600,480,1680);m.floor('ChamberEastWall',8280,80,40,500)
m.floor('ChamberStep',6880,432,90);m.deck('ChamberShelf',7030,352,220);m.row('ChamberCache',7060,240,5,2,amount=24)
m.row('SecretCrust',7480,368,3);m.trail([7480,7512,7544],310)
m.node('spikes','ChamberTeeth',7330,480);m.enemy('ChamberKeeper',7650,480,86)
m.ferry('VaultLift',7885,440,0,-112,4.6);m.deck('VaultShelf',7960,328,200);m.row('VaultCache',8010,216,4,1,amount=24)
m.node('pipe','Return',8200,480,mode=q('return'),destination=v(2680,475),prompt=q('Вернуться к привалу кузницы'))
m.trail([175,225,485,555],444);m.trail([450,520,590],316);m.arc(700,480,360)
m.trail([1130,1220],404);m.trail([1460,1530],396);m.trail([1590,1660,1730],316);m.trail([1850,1950,2020,2070],236)
m.trail([1390,1850,2160,2250,2330,2490,2650,2730],444);m.arc(2780,480,370)
m.trail([3370,3440],216);m.trail([3480,3650],404);m.trail([3770,4020],444);m.trail([4140,4210,4280],316)
m.arc(4440,480,340);m.arc(5010,440,112);m.trail([5160,5240],364);m.trail([5340],444)
m.trail([6700,6780],444);m.trail([7050,7120,7200],316);m.trail([7480,7760],444);m.trail([7990,8060,8120],292)
for n,l,r in [('CarrierLava',700,1060),('CounterLava',2780,3150),('FinalLava',4440,4780),('LeapLava',5010,5122)]:m.lava(n,l,r)
m.save()

m=Map('3-3',3020,1180)
for n,x,y,w in [('Entry',0,480,420),('BrokenPier',524,440,330),('LastCauseway',958,480,2190)]:m.floor(n,x,y,w)
m.floor('OfferStep',150,432,60);m.deck('OfferShelf',260,352,100);m.row('ApproachCache',270,240,3,1,amount=18)
m.enemy('LastSentinel',680,440,60,'murloc')
m.node('rune','LastRune',1280,366,reward_id=q('3-3/LastRune'))
m.floor('LeftPedestal',1630,424,128);m.floor('RightPedestal',2520,424,128)
m.node('boss','Boss',2150,480,arena_start=1440)
m.trail([130,210],444);m.trail([310,365],316);m.arc(420,480,104);m.arc(854,440,104)
m.trail([1040,1120,1200,1360],444);m.trail([1660,1720,2550,2610],388);m.trail([2810,2900,2980],444)
m.lava('EntryLava',420,524);m.lava('ApproachLava',854,958)
m.save()
