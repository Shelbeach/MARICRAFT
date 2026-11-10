extends RefCounted
# All translations in source pixels (2 px per game unit). Root never moves.
const CLIPS=["idle","alert","prepare_fire","fire_shot","prepare_hammer","hammer_slam","ground_power","recover","open","guarded","deflect","hit","phase","death"]
static func sample(clip:String,t:float)->Dictionary:
	t=clampf(t,0,1)
	var p={"torso":Vector2(0,-62),"angle":0.0,"head_angle":0.0,"mouth":0.0,"base_scale":Vector2.ONE,"base_alpha":1.0,"tint":Color.WHITE,"head_free":false,"head_position":Vector2.ZERO}
	var wave:=sin(t*TAU)
	var bell:=sin(t*PI)
	match clip:
		"idle":
			p.torso.y+=wave*2.0;p.head_angle=wave*0.018;p.base_scale.x=1+wave*0.015
		"alert":
			p.torso+=Vector2(t*3,-t*3);p.angle=-t*0.035;p.head_angle=-t*0.07
		"prepare_fire":
			p.torso+=Vector2(-5*t,-3*t);p.angle=-0.06*t;p.head_angle=-0.09*t;p.mouth=t
		"fire_shot":
			p.torso+=Vector2(7*bell,2*bell);p.angle=0.06*bell;p.head_angle=0.12*bell;p.mouth=1-t;p.base_scale.x=1+bell*0.04
		"prepare_hammer":
			p.torso+=Vector2(-5*t,-4*t);p.angle=-0.075*t;p.head_angle=-0.025*t
		"hammer_slam":
			var impact:=sin(minf(t*2.3,1)*PI)
			p.torso+=Vector2(5*impact,7*impact);p.angle=0.10*impact;p.head_angle=-0.03*impact;p.base_scale=Vector2(1+impact*0.05,1-impact*0.04)
		"ground_power":
			p.torso.y+=5*bell;p.angle=0.035*bell;p.head_angle=-0.10*bell;p.mouth=bell;p.base_scale.x=1+bell*0.065
		"recover":
			p.torso+=Vector2(2,5)*(1-t);p.angle=0.05*(1-t);p.head_angle=-0.03*(1-t)
		"open":
			p.torso.y+=5+wave*1.5;p.angle=0.035;p.head_angle=-0.04+wave*0.01;p.base_scale.y=0.96
		"guarded":
			p.torso.x-=bell*3;p.angle=-0.045*bell;p.head_angle=0.04*bell
		"deflect":
			p.torso.x+=3*bell;p.angle=0.04*bell;p.head_angle=-0.03*bell;p.tint=Color(1,1-0.06*bell,1-0.15*bell)
		"hit":
			p.torso+=Vector2(-8,-2)*bell;p.angle=-0.09*bell;p.head_angle=-0.06*bell;p.tint=Color(1,1-0.1*bell,1-0.18*bell)
		"phase":
			p.torso.y-=5*bell;p.head_angle=-0.10*bell;p.mouth=bell;p.base_scale=Vector2(1+0.08*bell,1+0.03*bell)
		"death":
			# Articulated collapse: pedestal drains, torso settles sideways, crown falls independently.
			var q:=smoothstep(0,1,t)
			p.angle=PI*0.5*q;p.torso=Vector2(-30*q,lerpf(-62,-115,q))
			p.base_scale=Vector2(1+q*0.04,1-q*0.85);p.base_alpha=1-q*0.94
			p.head_free=true;p.head_position=Vector2(11,-243).lerp(Vector2(60,-70),q)
			p.head_angle=-0.15*q;p.tint=Color(1-q*0.67,1-q*0.73,1-q*0.69)
	return p
static func shoulder(p:Dictionary,front:bool)->Vector2:
	return p.torso+Vector2(-72 if front else 70,-162 if front else -155).rotated(p.angle)
static func blend(a:Dictionary,b:Dictionary,w:float)->Dictionary:
	var result:=b.duplicate()
	for key in ["torso","angle","head_angle","mouth","base_scale","base_alpha","tint","head_position"]:
		result[key]=lerp(a[key],b[key],w)
	return result
