@tool
extends RefCounted
## P07 is presentation only. Coordinates below are always world units.
const ROOT := "res://assets/molten_art/"
var registry:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"registry.json"))
var cache:Dictionary={}

func resource(path:String):
	path=path.trim_prefix("runtime/")
	if not cache.has(path): cache[path]=load(ROOT+path)
	return cache[path]

func item(painter:Node2D,id:String,at:Vector2,tint:=Color.WHITE,factor:=1.0) -> void:
	var d:Dictionary=registry[id]
	var extent:=Vector2(d.world_units[0],d.world_units[1])*factor
	var anchor:=Vector2(d.anchor_world[0],d.anchor_world[1])*factor
	painter.draw_texture_rect(resource(d.file),Rect2(at-anchor,extent),false,tint)

func cropped(painter:Node2D,id:String,target:Rect2,tint:=Color.WHITE) -> void:
	var d:Dictionary=registry[id]
	var b:Array=d.visible_region_px
	painter.draw_texture_rect_region(resource(d.file),target,Rect2(b[0],b[1],b[2],b[3]),tint)

func deck(painter:Node2D,width:float,stone:=false) -> void:
	# Endcaps retain their aspect; repeat the narrow central strip. No stretched slab.
	var id:="ferry_stone" if stone else "ferry_iron"
	var d:Dictionary=registry[id]
	var b:Array=d.visible_region_px
	var texture:Texture2D=resource(d.file)
	var cap:=12.0
	var h:=26.0
	painter.draw_texture_rect_region(texture,Rect2(0,-1,cap,h),Rect2(b[0],b[1],24,b[3]))
	var x:=cap
	while x<width-cap:
		var part:=minf(40,width-cap-x)
		painter.draw_texture_rect_region(texture,Rect2(x,-1,part,h),Rect2(b[0]+32,b[1],part*2,b[3]))
		x+=part
	painter.draw_texture_rect_region(texture,Rect2(width-cap,-1,cap,h),Rect2(b[0]+b[2]-24,b[1],24,b[3]))

func chain(painter:Node2D,at:Vector2,length:float,tint:=Color.WHITE) -> void:
	# One complete link is tiled, removing the source canvas' transparent lower tail.
	var texture:Texture2D=resource("decor/massive_chain.png")
	var y:=0.0
	while y<length:
		var h:=minf(10.0,length-y)
		painter.draw_texture_rect_region(texture,Rect2(at.x-4,at.y+y,8,h),Rect2(2,26,52,h*6.4),tint)
		y+=h
