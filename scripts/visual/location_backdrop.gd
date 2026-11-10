@tool
extends Node2D
var library
var level
var left:=0.0
var mine:=false
var props:Array=[]

func setup(owner_level) -> void:
	level=owner_level
	z_index=-30
	for id in ["canyon_sky","canyon_far","distant","canyon_mid","canyon_near"]:
		var part=preload("res://scripts/visual/location_layer.gd").new()
		part.library=library;part.level=level;part.id=id
		part.show_behind_parent=true
		add_child(part)
	if level.has_node("Scenery"): return
	# Every cluster belongs to an authored station, camp, seam or loading bay.
	for entry in level.scenery:
		if entry.id=="support": continue # Detached arches read as false platforms.
		ground(entry.id,float(entry.x))

func floor_at(x:float,width:float) -> float:
	var result:=10000.0
	for node in level.get_children():
		if node.get("construction")==null: continue
		if node.construction in ["timber","quay"]: continue
		if x-width/2>=node.position.x and x+width/2<=node.position.x+node.size.x: result=minf(result,node.position.y)
	for node in level.get_children():
		if node.get("construction")==null or node.construction in ["timber","quay"]: continue
		if node.position.y<result and node.position.x<x+width/2 and node.position.x+node.size.x>x-width/2: return 10000.0
	return result

func ground(id:String,x:float) -> void:
	var data:Dictionary=library.environment[id]
	var footprint:float={"rail":90.0,"cart":76.0}.get(id,float(data.world_units[0])*0.65)
	var y:=floor_at(x,footprint)
	if y>=1000:
		for offset in [-24,24,-48,48,-72,72]:
			var candidate:=floor_at(x+offset,footprint)
			if candidate<1000:
				x+=offset
				y=candidate
				break
	if y<1000:
		# The surface top is the support, not a five-unit hover offset. Registry
		# anchors already include transparent margins around the painted foot.
		var inset:float=2.0
		props.append([id,Vector2(x,y+inset)])

func _process(_delta:float) -> void:
	left=-get_viewport().canvas_transform.origin.x/get_viewport().canvas_transform.x.x
	mine=level.mine_main or (level.cave_left>0 and left>=level.cave_left-1)
	queue_redraw()

func layer(id:String,tint:=Color.WHITE) -> void:
	var data:Dictionary=library.environment[id]
	var texture:Texture2D=library.resource(data.file)
	var source:=Rect2(Vector2.ZERO,texture.get_size())
	# These two source strips contain a cut-off mesa inside their right edge.
	# Use the intact landscape, then mirror alternate spans: both joins now share
	# exactly the same silhouette and pixels, instead of unrelated cut edges.
	if id=="canyon_far": source=Rect2(200,0,1500,840)
	elif id=="canyon_near": source=Rect2(200,0,1420,500)
	var width:float=source.size.x*float(data.world_units[0])/texture.get_width()
	var offset:=left*(1-float(data.parallax[0]))
	var start:=floori((left-offset)/width)
	for i in range(start-1,start+3):
		# The outdoor seam experiment accidentally mirrored the mine as well.
		# Its accepted strip already repeats in one direction; preserve that join.
		var mirrored:=id!="mine_back" and posmod(i,2)==1
		draw_set_transform(Vector2(i*width+offset+(width if mirrored else 0),float(data.top_world)),0,Vector2(-1 if mirrored else 1,1))
		draw_texture_rect_region(texture,Rect2(0,0,width,float(data.world_units[1])),source,tint)
		if float(data.top_world)==0:
			draw_set_transform(Vector2(i*width+offset+(width if mirrored else 0),0),0,Vector2(-1 if mirrored else 1,-1))
			draw_texture_rect_region(texture,Rect2(0,0,width,64),Rect2(source.position,Vector2(source.size.x,64*texture.get_height()/float(data.world_units[1]))),tint)
		draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if mine:
		# The former mid layer contains bright horizontal walkways. It is deliberately
		# absent: only the real, supported timber decks may read as standing surfaces.
		layer("mine_back",Color(0.72,0.76,0.81))
		var start:float=level.cave_left if left>=level.cave_left and level.cave_left>0 else 0.0
		var end:float=start+level.cave_width if start>0 else level.finish_x+128
		for x in range(int(start),int(end),512):
			library.rectangle(self,"arena_roof",Rect2(x,0,512,112))
	else:
		if level.get_node_or_null("Boss"):
			var start:float=level.get_node_or_null("Boss").arena_start
			var end:float=level.finish_x+128
			library.rectangle(self,"mine_back",Rect2(start,0,end-start,600),Color(0.74,0.77,0.82))
			library.rectangle(self,"arena_roof",Rect2(start,0,end-start,145))
			for x in [start,end-30]:
				library.rectangle(self,"support_middle",Rect2(x-14,0,28,487))
				library.item(self,"beam_joint",Vector2(x,146))
				library.item(self,"lantern",Vector2(x,159))
	for prop in props:
		if prop[1].x>=left-250 and prop[1].x<=left+1210:
			var tint:=Color(0.77,0.80,0.83) if mine else Color(0.90,0.88,0.84)
			if prop[0]=="arena_kiln": tint=Color(0.60,0.61,0.65)
			library.item(self,prop[0],prop[1],tint)
