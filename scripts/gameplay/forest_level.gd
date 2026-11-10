extends Node2D

signal cleared
signal checkpoint_reached
@export var forest_art := false
@export var checkpoint_x := 4040.0
@export var finish_x := 7070.0
@export var sections: Dictionary = {}
@export var water_spans := PackedVector2Array()
@export var cave_left := 0.0
@export var cave_width := 0.0
@export var arena_entry_x := 0.0
var arena
var checkpoint := false
var total_coins := 0
var autosave := 0.0
var underground := false
var pipe_prompt := ""
@onready var player := $Player
@onready var boss := get_node_or_null("Boss")

func _ready() -> void:
	if boss and arena_entry_x>0:
		arena=preload("res://scripts/gameplay/arena_lock.gd").new()
		arena.name="ArenaLock"
		arena.level=self
		add_child(arena)
	for object in find_children("*","",true,false):
		if object.get("kind") == "coin":
			total_coins += 1
		elif object.get("kind") == "coins":
			total_coins += int(object.amount)
		elif object.get("kind") == "fragile":
			total_coins += int(object.vein_bonus)
	frame_room()
	if forest_art:
		var art=load("res://scripts/visual/forest_art.gd").new()
		art.name="ForestArt"
		add_child(art)
	if forest_art or has_meta("location2_art"):
		add_child(preload("res://scripts/visual/faction_decor.gd").new())
	restore_defeated_boss.call_deferred()

func restore_defeated_boss() -> void:
	# The existing unique reward ID also proves this encounter was won in this
	# attempt. Reopening a saved level must not resurrect it or lock its gates.
	if not boss or not Campaign.claimed(boss.reward_id): return
	boss.hp=0
	boss.mode=boss.Mode.DEAD
	boss.position=boss.home
	boss.get_node("Hitbox").disabled=true
	if boss.get("death_age")!=null: boss.death_age=2.0
	set_gate(false)

func frame_room() -> void:
	underground = cave_left > 0 and player.position.x >= cave_left
	var camera: Camera2D = player.get_node("Camera")
	camera.limit_left = int(cave_left) if underground else 0
	camera.limit_right = int(cave_left+cave_width) if underground else int(finish_x+128)
	if camera.has_method("snap_to_player"): camera.snap_to_player()
	camera.reset_smoothing()

func warp(target: Vector2) -> void:
	SFX.warp()
	for bolt in get_tree().get_nodes_in_group("bolts"):
		bolt.queue_free()
	player.position = target
	player.velocity = Vector2.ZERO
	player.previous_feet = target.y
	pipe_prompt = ""
	frame_room()

func _physics_process(delta: float) -> void:
	if not Campaign.active():
		return
	if cave_left > 0 and (player.position.x >= cave_left) != underground:
		frame_room()
	Campaign.p.seconds += delta
	autosave += delta
	if autosave >= 3:
		autosave = 0
		Campaign.save()
	if underground or player.recovering > 0 or player.position.y > 490:
		return
	if not checkpoint and absf(player.position.x-checkpoint_x) < 34:
		checkpoint = true
		player.spawn_point = Vector2(checkpoint_x,475)
		checkpoint_reached.emit()
		SFX.play("checkpoint",self,"checkpoint")
		queue_redraw()
	if player.position.x >= finish_x and (not boss or boss.hp == 0) and Campaign.finish(total_coins):
		SFX.play("level_complete",self,"finish")
		cleared.emit()

func set_gate(locked: bool) -> void:
	$Gate/Hitbox.set_deferred("disabled",not locked)
	if arena:
		if not locked: arena.release()
		elif arena.released: arena.reset()
	queue_redraw()

func _draw() -> void:
	if forest_art or has_meta("location2_art"): return
	var width := finish_x + 128
	draw_forest_backdrop(width)
	if cave_left:
		draw_cave()
	# Below the landing surfaces: the coloured channel marks the extent of each crossing.
	for span in water_spans:
		draw_rect(Rect2(span.x,508,span.y-span.x,32),Color("#254d59"))
		draw_line(Vector2(span.x,508),Vector2(span.y,508),Color("#598592"),2)
	for x in sections:
		draw_string(ThemeDB.fallback_font,Vector2(float(x),201),sections[x],HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("#d1e4d2"))
	if boss and boss.hp>0:
		var gate_x: float = $Gate.position.x
		draw_rect(Rect2(gate_x-9,308,18,172),Color("#b27b68"))
		for y in range(324,470,28):
			draw_line(Vector2(gate_x-8,y),Vector2(gate_x+8,y-10),Color("#ffe0a1"),3)
	for x in [checkpoint_x,finish_x]:
		var c := Color("#f6cc72") if x == finish_x else (Color("#91f3b7") if checkpoint else Color("#a6bfcd"))
		draw_line(Vector2(x,480),Vector2(x,330),c,5)
		draw_colored_polygon(PackedVector2Array([Vector2(x,330),Vector2(x+65,330),Vector2(x+47,350),Vector2(x+65,369),Vector2(x,369)]),c)
		var title := "ФИНИШ" if x == finish_x else "ПРИВАЛ"
		draw_string(ThemeDB.fallback_font,Vector2(x-20,311),title,HORIZONTAL_ALIGNMENT_LEFT,-1,18,c)

func draw_cave() -> void:
	draw_rect(Rect2(cave_left,0,cave_width,540),Color("#292c41"))
	for i in ceili(cave_width/112):
		var x := cave_left + i*112
		draw_colored_polygon(PackedVector2Array([Vector2(x,85),Vector2(x+65,180+i%3*23),Vector2(x+112,85)]),Color("#424658"))

func draw_forest_backdrop(width: float) -> void:
	draw_rect(Rect2(0,0,width,540),Color("#294952"))
	# Two quiet silhouettes leave the platforms and coin trails in the foreground.
	var ridge:=PackedVector2Array([Vector2(0,540)])
	for i in ceili(width/240)+1:
		var x:=i*240.0
		ridge.append(Vector2(x,236+28*sin(x/490)+16*cos(x/230)))
	ridge.append(Vector2(ridge[-1].x,540))
	draw_colored_polygon(ridge,Color("#35565c"))
	for stand in ceili(width/680)+1:
		var centre:=stand*680.0
		for offset: int in [-108,0,88]:
			var x:=centre+offset
			var crown:=266.0+absf(offset)*0.42+20*sin(centre/410)
			var base:=Vector2(x,540.0)
			var contour:=PackedVector2Array([
				Vector2(x,crown),Vector2(x+43,crown+74),Vector2(x+24,crown+70),
				Vector2(x+74,crown+148),Vector2(x+44,crown+141),base+Vector2(85,0),
				base-Vector2(85,0),Vector2(x-44,crown+141),Vector2(x-74,crown+148),
				Vector2(x-24,crown+70),Vector2(x-43,crown+74)])
			draw_colored_polygon(contour,Color("#2f5055"))
