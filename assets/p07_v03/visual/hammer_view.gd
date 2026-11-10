extends Node2D
const TEX=preload("../parts/head_hammer.png")
const STATES=["raised","prepare","strike","grounded","open","guarded","hit","end"]
var state:="raised"
var progress:=0.0
func sample(value:String,t:float)->void:state=value;progress=t;queue_redraw()
func _draw()->void:
	var pulse:=sin(progress*TAU)
	var tint:=Color.WHITE
	match state:
		"prepare":tint=Color(1,1+0.08*progress,1-0.15*progress)
		"strike":tint=Color(1+0.15*(1-progress),1+0.05*(1-progress),1)
		"grounded":tint=Color(.92,.88,.85)
		"open":tint=Color(1.15,1.1+0.06*pulse,.92)
		"guarded":tint=Color(.65,.7,.83)
		"hit":tint=Color(1.6-0.6*progress,1.5-0.5*progress,1.2-0.2*progress)
		"end":tint=Color.WHITE.lerp(Color(.42,.36,.4),progress)
	draw_texture(TEX,Vector2.ZERO,tint)
