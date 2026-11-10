extends Node2D
## Live encounter state, not a second save system. Death reopens the entrance;
## claimed rewards and boss HP remain owned by the existing session/Campaign.
var level
var entrance:StaticBody2D
var active:=false
var released:=false
var left:=0.0
var right:=0.0
var entry_view
var exit_view

func _ready() -> void:
	process_physics_priority=-20
	left=level.arena_entry_x
	right=level.get_node("Gate").position.x
	entrance=StaticBody2D.new()
	entrance.name="Entrance"
	entrance.collision_layer=1
	entrance.collision_mask=0
	entrance.position=Vector2(left,480)
	var shape:=CollisionShape2D.new()
	shape.name="Hitbox"
	shape.shape=RectangleShape2D.new()
	shape.shape.size=Vector2(18,1100)
	shape.position.y=-500
	shape.disabled=true
	entrance.add_child(shape)
	add_child(entrance)
	var gate=level.get_node("Gate")
	gate.position.y=480
	gate.get_node("Hitbox").shape=shape.shape.duplicate()
	gate.get_node("Hitbox").position.y=-500
	var chapter:=int(Campaign.p.level.left(1))
	for i in 2:
		var view:=preload("res://scripts/visual/arena_barrier.gd").new()
		view.chapter=chapter
		view.position=Vector2(left if i==0 else right,480)
		view.closed=i==1
		view.progress=1.0 if i==0 else 0.0
		add_child(view)
		if i==0: entry_view=view
		else: exit_view=view

func request_activation() -> bool:
	var actor=level.player
	if released or level.boss.hp<=0 or actor.recovering>0: return false
	# The complete capsule must be inside. No shove, teleport, or trapping a player
	# who collected a rune from the other side of a wall.
	if actor.position.x<left+48 or actor.position.x>right-32: return false
	if not active:
		active=true
		entrance.get_node("Hitbox").set_deferred("disabled",false)
		entry_view.closed=true
		entry_view.progress=0.0
	return true

func release() -> void:
	active=false
	released=true
	entrance.get_node("Hitbox").set_deferred("disabled",true)
	entry_view.closed=false
	exit_view.closed=false
	entry_view.progress=1.0
	exit_view.progress=1.0

func reset() -> void:
	active=false
	released=false
	entrance.get_node("Hitbox").set_deferred("disabled",true)
	entry_view.closed=false
	exit_view.closed=true
	entry_view.progress=1.0
	exit_view.progress=0.0

func _physics_process(_delta:float) -> void:
	if level.boss.hp<=0:
		if not released: release()
		return
	if released: reset()
	if level.player.recovering>0:
		if active: reset()
		return
	if Campaign.active() and not active: request_activation()
