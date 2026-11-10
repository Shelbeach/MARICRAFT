@tool
extends Node2D
const Art:=preload("res://scripts/visual/art_library.gd")
var level
var props:Array=[]
var trees:Array[Vector2]=[]
var forest_color:=Color.WHITE
var last_origin:=Vector2.INF

func _ready() -> void:
	Art.initialize()
	level=get_parent().get_parent()
	z_index=-20
	for kind in ["castle","landscape","trees","props"]:
		var part=preload("res://scripts/visual/backdrop_layer.gd").new()
		part.kind=kind
		# Authored trees occupy -19. Keep structural posts in front of them,
		# matching the original order: landscape, trees, supports.
		if kind=="props": part.z_index=2
		if kind in ["castle","trees"]:
			var shading:=ShaderMaterial.new()
			shading.shader=load("res://scripts/visual/"+("distant_castle.gdshader" if kind=="castle" else "tree_depth.gdshader"))
			part.material=shading
		add_child(part)
	var n:String=preload("res://scripts/visual/level_identity.gd").id(level)
	forest_color=Color("#d0e5ed") if n=="1-3" else (Color("#deecdc") if n=="1-2" else Color.WHITE)
	for body in level.get_children():
		if body.get("construction")==null: continue
		if body.position.y>=475 and body.size.x>250 and body.position.x<level.finish_x:
			var tree_x:float=body.position.x+250
			while tree_x<body.position.x+body.size.x-100:
				trees.append(Vector2(tree_x,body.position.y+18))
				tree_x+=730
		if body.position.y>=475 and body.size.x>150 and body.position.x<level.finish_x:
			var x:float=body.position.x+70
			while x<body.position.x+body.size.x-35:
				# Deliberate small clusters leave landing edges and interactive objects readable.
				props.append([["grass","fern_fan","flowers"][posmod(int(x/71),3)],Vector2(x,body.position.y+3)])
				x+=230 if n=="1-1" else 175
		if body.construction in ["timber","quay","masonry"]:
			var inset:=18.0 if body.construction=="masonry" else 12.0
			var offsets:Array=[inset,body.size.x-inset] if body.size.x>=96 else [body.size.x*0.5]
			for dx in offsets:
				var foot:=support_foot(body.position.x+dx,body.position.y+body.size.y)
				if foot<=body.position.y+body.size.y+2: continue
				var kind:="stone_post" if body.construction=="masonry" else "post"
				# Both ends overlap their occluding surfaces, including alpha padding.
				props.append([kind,Vector2(body.position.x+dx,body.position.y+body.size.y-7),foot+6,minf(28,body.size.x-8)])
	if n=="1-2":
		for x in [1396,1938,4158,4635]: props.append(["mooring",Vector2(x,support_foot(x,350)+5)])
		for x in [220,1150,2070,2820,4740]: props.append(["arena_reeds",Vector2(x,484)])
	if n=="1-3":
		for x in [1540,2530]: props.append(["arena_drum",Vector2(x,484)])
		for x in [1690,2490]: props.append(["arena_reeds",Vector2(x,484)])
	if level.cave_left>0:
		for x in range(int(level.cave_left)+130,int(level.cave_left+level.cave_width)-50,260):
			props.append(["mushrooms" if x%3 else "crystal",Vector2(x,support_foot(x,250)+3)])
			

func support_foot(x:float,below:float) -> float:
	var foot:=540.0
	for body in level.get_children():
		if body.get("construction")==null: continue
		if x>=body.position.x and x<body.position.x+body.size.x and body.position.y>=below:
			foot=minf(foot,body.position.y)
	return foot

func _process(_delta: float) -> void:
	var origin:=get_viewport().canvas_transform.origin
	if origin!=last_origin:
		last_origin=origin
		queue_redraw()
		for child in get_children(): child.queue_redraw()

func item(id: String,at: Vector2,color:=Color.WHITE,painter:Node2D=self) -> void:
	var d:Dictionary=Art.environment[id]
	var size:=Vector2(d.world[0],d.world[1])
	painter.draw_texture_rect(Art.resource("environment/"+d.file),Rect2(at-Vector2(size.x/2,size.y),size),false,color)

func strip(id: String,left: float,y: float,tint:=Color.WHITE,painter:Node2D=self,flip_y:=false,world_scale:=1.0) -> void:
	var d:Dictionary=Art.environment[id]
	var size:=Vector2(d.world[0],d.world[1])*world_scale
	var shift:=left*(1.0-float(d.parallax))
	var first:=floori((left-shift)/size.x)
	var width:float=get_viewport_rect().size.x/get_viewport().canvas_transform.x.x
	for i in ceili(width/size.x)+2:
		var index:=first+i
		var flip_x:=false # Prepared strips already have matched horizontal borders.
		var x:=index*size.x+shift
		painter.draw_set_transform(Vector2(x+(size.x if flip_x else 0),y+(size.y if flip_y else 0)),0,Vector2(-1 if flip_x else 1,-1 if flip_y else 1))
		var texture:Texture2D=Art.resource("environment/"+d.file)
		painter.draw_texture_rect(texture,Rect2(Vector2.ZERO,size),false,tint)
		if y==0:
			# Reflect only the top margin; no accepted texture is resized/replaced.
			painter.draw_set_transform(Vector2(x,0),0,Vector2(1,-1))
			painter.draw_texture_rect_region(texture,Rect2(0,0,size.x,64),Rect2(0,0,texture.get_width(),64*texture.get_height()/size.y),tint)
		painter.draw_set_transform(Vector2.ZERO)

func view_width() -> float:
	return get_viewport_rect().size.x/get_viewport().canvas_transform.x.x

func in_cave(left:float) -> bool:
	return level.cave_left>0 and left>=level.cave_left-2

func _draw() -> void:
	if not level: return
	var left:float=-get_viewport().canvas_transform.origin.x/get_viewport().canvas_transform.x.x
	var cave:=in_cave(left)
	if cave:
		draw_rect(Rect2(left,0,view_width()+40,560),Color("#14282b"))
		# One coherent chamber fills the viewport at the source aspect ratio.
		# No inverted copy or cropped arcade intersects the playable silhouette.
		strip("cave_back",left,0,Color("#bacbd0"),self,false,560.0/410.0)
	else:
		draw_rect(Rect2(left,0,view_width()+40,560),Color("#719993"))
		strip("sky",left,0,forest_color)

func draw_landscape(painter:Node2D,left:float) -> void:
	# This layer still occludes the castle foundation at the same .12 parallax.
	strip("ridge",left,157,forest_color,painter)
	strip("forest_far",left,461,forest_color,painter,true)
	strip("forest_far",left,270,forest_color,painter)
	strip("forest_mid",left,346,forest_color,painter)

func draw_trees(painter:Node2D,left:float) -> void:
	if level.has_node("Scenery"): return
	for foot in trees:
		if foot.x<left-200 or foot.x>left+view_width()+200: continue
		item("oak_trunk",foot,Color("#a2b8a0"),painter)
		item("oak_crown",foot+Vector2(2,-204),Color("#a7bc9c"),painter)
		item("oak_bough",foot+Vector2(35,-174),Color("#a7bc9c"),painter)

func draw_props(painter:Node2D,left:float) -> void:
	for prop in props:
		if level.has_node("Scenery") and prop[0] not in ["post","stone_post"]: continue
		if prop[1].x<left-180 or prop[1].x>left+view_width()+170: continue
		if prop[0]=="post":
			var t:Texture2D=Art.resource("environment/decor/beam.png")
			var total:float=prop[2]-prop[1].y
			painter.draw_set_transform(prop[1],PI/2)
			for y in range(0,ceili(total),36):
				var length:=minf(36,total-y)
				painter.draw_texture_rect_region(t,Rect2(y,-6,length+0.35,12),Rect2(40,3,length*2,24),Color("#8f9f91"))
			painter.draw_set_transform(Vector2.ZERO)
		elif prop[0]=="stone_post": draw_stone_post(painter,prop[1],prop[2],prop[3])
		else: item(prop[0],prop[1],Color.WHITE,painter)
	var spans=level.get("water_spans")
	if spans==null: spans=PackedVector2Array() # Non-tool scene placeholders in the editor.
	for span in spans:
		var t:Texture2D=Art.resource("environment/layers/brook.png")
		var d:Dictionary=Art.environment.brook
		var height:=32.0
		# Paint beneath both banks; colliders and actual water spans stay unchanged.
		for x in range(int(span.x)-64,int(span.y)+64,int(d.world[0])):
			var width:=minf(d.world[0],span.y+64-x)
			painter.draw_texture_rect_region(t,Rect2(x,508,width,height),Rect2(0,0,width/d.world[0]*d.px[0],height/d.world[1]*d.px[1]))

func draw_stone_post(painter:Node2D,top:Vector2,foot:float,width:float) -> void:
	var texture:Texture2D=Art.resource("environment/decor/ruin_column.png")
	var tint:=Color("#879c93")
	# Recessed piers remain background scenery; only the ledge has a collider.
	for y in range(int(top.y),ceili(foot),14):
		var height:=minf(14,foot-y)
		painter.draw_texture_rect_region(texture,Rect2(top.x-width*.32,y,width*.64,height+0.4),Rect2(12,18,36,height*2),tint)
	painter.draw_texture_rect_region(texture,Rect2(top.x-width/2,top.y,width,8),Rect2(0,0,56,16),tint)
	painter.draw_texture_rect_region(texture,Rect2(top.x-width/2,foot-12,width,12),Rect2(0,32,56,24),tint)
