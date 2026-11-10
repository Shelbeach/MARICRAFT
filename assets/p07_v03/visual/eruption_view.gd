extends Node2D
const TEX=preload("../effects/boss_eruption/active.png")
var clip:="active"
var progress:=0.0
func sample(action:String,t:float)->void:clip=action;progress=clampf(t,0,1);queue_redraw()
func _draw()->void:
	var key:=mini(3,int(progress*4))
	var region:=Rect2(key*320,0,320,320)
	if clip=="warning":
		draw_texture_rect_region(TEX,Rect2(-160,-294,320,320),region,Color(1,0.8,0.55,0.07+progress*0.22))
		draw_texture_rect_region(TEX,Rect2(-66,-24,132,24),Rect2(key*320+94,270,132,24),Color(1,0.8+0.2*progress,0.6,0.6+progress*0.4))
	elif clip=="end":
		var h:=320*(1-0.78*progress)
		draw_texture_rect_region(TEX,Rect2(-160,-294*(h/320),320,h),region,Color(1,1-progress*0.25,1-progress*0.6,1-progress))
	else:draw_texture_rect_region(TEX,Rect2(-160,-294,320,320),region)
