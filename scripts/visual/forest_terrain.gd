@tool
extends Node2D
const Art:=preload("res://scripts/visual/art_library.gd")
var surfaces:Array[Rect2]=[]
var tiles:Array=[]
var woods:Array[Rect2]=[]
var ledges:Array[Rect2]=[]
var cave_left:=0.0
var masks:Array=[]
var forest:Texture2D
var cavern:Texture2D

func setup(level) -> void:
	Art.initialize()
	forest=Art.resource("terrain/forest/forest_atlas_2x.png")
	cavern=Art.resource("environment/atlases/grotto_tiles_2x.png")
	for value in JSON.parse_string(FileAccess.get_file_as_string(Art.ROOT+"environment/grotto_layout.json")).masks:
		masks.append(int(value))
	cave_left=level.cave_left
	for node in level.get_children():
		if node.get("construction")==null: continue
		var rect:=Rect2(node.position,node.size)
		if node.construction in ["timber","quay"]:
			woods.append(rect)
		elif node.construction=="masonry" and node.size.y<=32 and rect.end.y<node.foundation_y-2:
			ledges.append(rect)
		else: surfaces.append(rect)
	for rect in surfaces: tessellate(rect)
	var cave=preload("res://scripts/visual/grotto_terrain.gd").new()
	cave.atlas=cavern
	cave.tiles=tiles.filter(func(tile): return tile[2])
	var stone_material:=ShaderMaterial.new()
	stone_material.shader=load("res://scripts/visual/grotto_material.gdshader")
	stone_material.set_shader_parameter("stone",Art.resource("environment/grotto/stone_field.png"))
	cave.material=stone_material
	add_child(cave)
	var earth=preload("res://scripts/visual/grotto_terrain.gd").new()
	earth.atlas=forest
	earth.tiles=tiles.filter(func(tile): return not tile[2])
	var earth_material:=ShaderMaterial.new()
	earth_material.shader=load("res://scripts/visual/forest_material.gdshader")
	earth_material.set_shader_parameter("soil_atlas",forest)
	earth.material=earth_material
	add_child(earth)
	queue_redraw()

func solid(at: Vector2) -> bool:
	for rect in surfaces:
		if rect.has_point(at): return true
	return false

func mask_at(r: Rect2) -> int:
	var mid:=r.get_center()
	var probes:=[Vector2(mid.x,r.position.y-1),Vector2(r.end.x+1,mid.y),Vector2(mid.x,r.end.y+1),Vector2(r.position.x-1,mid.y),
		r.position-Vector2.ONE,Vector2(r.end.x+1,r.position.y-1),r.end+Vector2.ONE,Vector2(r.position.x-1,r.end.y+1)]
	var mask:=0
	for i in 4:
		if solid(probes[i]): mask|=1<<i
	for i in 4:
		var sides:Array=[[0,3],[0,1],[1,2],[2,3]][i]
		if mask&(1<<sides[0]) and mask&(1<<sides[1]) and solid(probes[i+4]): mask|=1<<(i+4)
	return mask

func cuts(from: float,to: float,axis: int) -> Array[float]:
	var points:Array[float]=[from,to]
	var at:=from+32
	while at<to:
		points.append(at)
		at+=32
	if axis==1:
		points.sort()
		return points
	for neighbor in surfaces:
		for edge in [neighbor.position[axis],neighbor.end[axis]]:
			if edge>from and edge<to and not points.has(edge): points.append(edge)
	points.sort()
	return points

func column_top(body: Rect2,x: float) -> float:
	var top:=body.position.y
	for step in surfaces.size():
		var before:=top
		for other in surfaces:
			if x>=other.position.x and x<other.end.x and absf(other.end.y-top)<0.1:
				top=other.position.y
		if top==before: break
	return top

func tessellate(body: Rect2) -> void:
	var xs:=cuts(body.position.x,body.end.x,0)
	var ys:=cuts(body.position.y,body.end.y,1)
	var cols:=xs.size()-1
	var rows:=ys.size()-1
	var cave:=cave_left>0 and body.position.x>=cave_left
	for y in rows:
		for x in cols:
			var at:=Vector2(xs[x],ys[y])
			var size:=Vector2(xs[x+1]-xs[x],ys[y+1]-ys[y])
			var rect:=Rect2(at,size)
			var column:=posmod(floori(at.x/32),4)+4*posmod(floori(at.y/32),4)
			var row:=0
			var join_row:=-1
			if cave:
				row=masks.find(mask_at(rect))
			else:
				var l:=not solid(Vector2(at.x-1,at.y+size.y/2))
				var r:=not solid(Vector2(rect.end.x+1,at.y+size.y/2))
				var depth:=floori((at.y-column_top(body,rect.get_center().x))/32)
				row=mini(depth,3)*4+int(l)+2*int(r)
				if rect.end.y<540 and not solid(Vector2(rect.get_center().x,rect.end.y+1)): row+=16
				# A lower surface ends against the side of a taller neighbouring block.
				if depth==0 and not l and solid(at+Vector2(-1,-1)): join_row=32
				elif depth==0 and not r and solid(Vector2(rect.end.x+1,at.y-1)): join_row=33
			var edges:=int(not solid(Vector2(at.x-1,rect.get_center().y)))+2*int(not solid(Vector2(rect.end.x+1,rect.get_center().y)))+4*int(not solid(Vector2(rect.get_center().x,rect.end.y+1)))
			var offset:=Vector2(fposmod(at.x-body.position.x,32.0),0)
			# Clip the last fragment against the external right/bottom boundary.
			if x==cols-1 and size.x<32: offset.x=32-size.x
			if y==rows-1 and size.y<32 and body.end.y<540 and not solid(Vector2(rect.get_center().x,rect.end.y+1)): offset.y=32-size.y
			if not cave: rect.position.y-=2.5 # P00 grass has a 5-source-pixel transparent cap.
			tiles.append([rect,Rect2(Vector2(2+68*column,2+68*row)+offset*2,size*2),cave,not solid(Vector2(rect.get_center().x,at.y-1)),edges])
			if join_row>=0:
				tiles.append([rect,Rect2(Vector2(2+68*column,2+68*join_row)+offset*2,size*2),false,true,edges])

func _draw() -> void:
	for rect in woods: draw_deck(rect)
	for rect in ledges:
		# Fit the complete painted edge, including its underside, to a thin lintel.
		var target:=Rect2(rect.position-Vector2(0,1.5),rect.size+Vector2(0,1.5))
		draw_texture_rect(Art.resource("environment/grotto/stone_edge.png"),target,false)

func draw_deck(rect:Rect2) -> void:
	var texture:Texture2D=Art.resource("gameplay/interactive/ferry_oak.png")
	var beam:Texture2D=Art.resource("environment/decor/beam.png")
	# One broad wooden fascia, not stacked narrow beams with transparent gaps.
	# Deep quays use joined 24-unit boards; a normal platform uses one board.
	var y:=rect.position.y+8
	while y<rect.end.y:
		var height:=minf(24,rect.end.y-y)
		var x:=rect.position.x+2
		draw_texture_rect_region(beam,Rect2(x,y,8,height),Rect2(0,7,16,16))
		x+=8
		draw_texture_rect_region(beam,Rect2(x,y,rect.end.x-6-x,height),Rect2(28,7,88,16))
		draw_texture_rect_region(beam,Rect2(rect.end.x-6,y,4,height),Rect2(116,7,8,16))
		y+=height
	# Preserve both finished deck ends and its authored thickness.
	draw_texture_rect_region(texture,Rect2(rect.position,Vector2(8,16)),Rect2(0,0,16,32))
	draw_texture_rect_region(texture,Rect2(rect.end.x-8,rect.position.y,8,16),Rect2(240,0,16,32))
	var x:=rect.position.x+8
	while x<rect.end.x-8:
		var width:=minf(112,rect.end.x-8-x)
		draw_texture_rect_region(texture,Rect2(x,rect.position.y,width,16),Rect2(16,0,width*2,32))
		x+=width
