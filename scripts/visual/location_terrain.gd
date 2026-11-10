@tool
extends Node2D
const Selector:=preload("res://assets/location2_art/terrain/tile_selector.gd")
var library
var level
var surfaces:Array[Rect2]=[]
var woods:Array[Rect2]=[]
var groups:Dictionary={}
var contacts:Array=[]

class Surface extends Node2D:
	var atlas:Texture2D
	var tiles:Array=[]
	func _draw() -> void:
		for tile in tiles: draw_texture_rect_region(atlas,tile[0],tile[1])

func setup(owner_level) -> void:
	level=owner_level
	for node in level.get_children():
		if node.get("construction")==null: continue
		var rect:=Rect2(node.position,node.size)
		if node.construction in ["timber","quay"]: woods.append(rect)
		else: surfaces.append(rect)
	for body in surfaces: tessellate(body)
	queue_redraw()

func solid(at:Vector2) -> bool:
	for rect in surfaces:
		if rect.has_point(at): return true
	return false

func mask_at(r:Rect2) -> int:
	var m:=r.get_center()
	# P04 uses N/E/S/W/NE/SE/SW/NW, unlike the P01 cave atlas.
	var probes:=[Vector2(m.x,r.position.y-0.1),Vector2(r.end.x+0.1,m.y),Vector2(m.x,r.end.y+0.1),Vector2(r.position.x-0.1,m.y),Vector2(r.end.x+0.1,r.position.y-0.1),r.end+Vector2.ONE*0.1,Vector2(r.position.x-0.1,r.end.y+0.1),r.position-Vector2.ONE*0.1]
	var mask:=0
	for i in 8:
		if solid(probes[i]): mask|=1<<i
	return mask

func cuts(from:float,to:float,axis:int) -> Array[float]:
	var points:Array[float]=[from,to]
	var at:=floorf(from/32.0)*32+32
	while at<to:
		points.append(at)
		at+=32
	for other in surfaces:
		for edge in [other.position[axis],other.end[axis]]:
			if edge>from and edge<to and not points.has(edge): points.append(edge)
	points.sort()
	return points

func group(kind:String):
	if groups.has(kind): return groups[kind]
	var node:=Surface.new()
	var set:TileSet=library.resource("terrain/"+kind+".tres")
	node.atlas=(set.get_source(0) as TileSetAtlasSource).texture
	var shader:=ShaderMaterial.new()
	shader.shader=load("res://scripts/visual/location_material.gdshader")
	shader.set_shader_parameter("field",library.resource("terrain/"+kind+"_field.png"))
	if level.get_node_or_null("Boss") and kind=="redrock":
		shader.set_shader_parameter("use_transition",true)
		shader.set_shader_parameter("transition_field",library.resource("terrain/redrock_to_masonry.png"))
		shader.set_shader_parameter("transition_start",ceilf((level.get_node_or_null("Boss").arena_start+96)/32)*32)
	node.material=shader
	add_child(node)
	groups[kind]=node
	return node

func tessellate(body:Rect2) -> void:
	var xs:=cuts(body.position.x,body.end.x,0)
	var ys:=cuts(body.position.y,body.end.y,1)
	for yi in ys.size()-1:
		for xi in xs.size()-1:
			var rect:=Rect2(Vector2(xs[xi],ys[yi]),Vector2(xs[xi+1]-xs[xi],ys[yi+1]-ys[yi]))
			var cell:=Vector2i(floori(rect.position.x/32),floori(rect.position.y/32))
			var coord:=Selector.atlas_coords(cell,mask_at(rect))
			var kind:="redrock"
			if level.mine_main or (level.cave_left>0 and rect.position.x>=level.cave_left): kind="ore"
			elif level.get_node_or_null("Boss") and rect.position.x>=ceilf((level.get_node_or_null("Boss").arena_start+96)/32)*32+256: kind="masonry"
			# Full contour for partial cells; shader preserves the continuous global fill.
			group(kind).tiles.append([rect,Rect2(Vector2(2+coord.x*68,2+coord.y*68),Vector2(64,64))])

func footing(x:float,from:float,ignore:Rect2) -> float:
	var best:=600.0
	for rect in surfaces+woods:
		if rect==ignore: continue
		if x>=rect.position.x and x<rect.end.x and rect.position.y>=from-0.1: best=minf(best,rect.position.y)
	return best

func _draw() -> void:
	contacts.clear()
	for node in level.get_children():
		if node.get("travel")==null: continue
		# Gantry posts stand on the banks. The moving deck is suspended from this beam.
		var a:float=(node.position.x if Engine.is_editor_hint() else node.origin.x)-90
		var b:float=(node.position.x if Engine.is_editor_hint() else node.origin.x)+node.travel.x+90
		var roof:=116.0
		for x in [a,b]:
			var bottom:=footing(x,roof,Rect2())
			library.rectangle(self,"support_middle",Rect2(x-7,roof-8,14,bottom+15-roof))
			library.item(self,"beam_joint",Vector2(x,roof-4))
		# A narrow timber carrier, visibly distinct from the orange walkable decks.
		draw_set_transform(Vector2(a-12,roof),-PI/2)
		library.rectangle(self,"support_middle",Rect2(0,0,10,b-a+24),Color(0.58,0.61,0.64))
		draw_set_transform(Vector2.ZERO)
	for deck in woods:
		var columns:Array=[deck.get_center().x] if deck.size.x<80 else [deck.position.x+16,deck.end.x-16]
		for x in columns:
			var top:=deck.position.y+14
			var bottom:=footing(x,deck.end.y,deck)
			if bottom<=top: continue
			library.rectangle(self,"support_middle",Rect2(x-7,top,14,bottom+7-top))
			library.item(self,"beam_joint",Vector2(x,top+4))
			contacts.append({"x":x,"top":top,"floor":bottom,"foot":bottom+7})
		library.rectangle(self,"deck_left",Rect2(deck.position,Vector2(12,20)))
		library.rectangle(self,"deck_middle",Rect2(deck.position+Vector2(12,0),Vector2(maxf(1,deck.size.x-24),20)))
		library.rectangle(self,"deck_right",Rect2(Vector2(deck.end.x-12,deck.position.y),Vector2(12,20)))
		if level.mine_main or deck.position.x>=level.cave_left and level.cave_left>0:
			library.item(self,"lantern",Vector2(deck.position.x+18,deck.position.y-14),Color(0.90,0.86,0.76))
