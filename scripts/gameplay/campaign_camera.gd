extends Camera2D
## Persistent world framing. HUD and physics keep their original scale.
const TRAVEL_ZOOM := 1.25
const HORIZONTAL_ZONE := 0.24
const LANDING_STEP := 80.0
var anchor := Vector2.ZERO
var ground_height := 480.0
var framing_arena := false
var last_actor_position := Vector2.ZERO

func _ready() -> void:
	top_level = true
	position_smoothing_enabled = false
	# A high optional ledge still needs room for a large hero's jump above HUD.
	# Backdrops extend their top edge into this small, otherwise unseen margin.
	limit_top = -64
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	process_physics_priority = 5
	snap_to_player()

func snap_to_player() -> void:
	var actor = get_parent()
	framing_arena = false
	ground_height = actor.global_position.y
	zoom = Vector2.ONE * TRAVEL_ZOOM
	anchor = Vector2(actor.global_position.x, ground_height - 100)
	anchor = bounded(anchor)
	global_position = anchor
	last_actor_position = actor.global_position
	reset_smoothing()

func bounded(point: Vector2) -> Vector2:
	var half := get_viewport_rect().size / zoom * 0.5
	return Vector2(clampf(point.x, limit_left + half.x, limit_right - half.x),
		clampf(point.y, limit_top + half.y, limit_bottom - half.y))

func _physics_process(delta: float) -> void:
	var actor = get_parent()
	var level = actor.get_parent()
	# Respawns and pipe transitions should not chase across the whole level.
	if actor.global_position.distance_to(last_actor_position) > 500:
		snap_to_player()
	last_actor_position = actor.global_position
	var boss = level.get_node_or_null("Boss")
	if boss and actor.position.x >= level.arena_entry_x - 240:
		framing_arena = true
	elif framing_arena and actor.position.x < level.arena_entry_x - 300:
		framing_arena = false
	var desired_zoom := TRAVEL_ZOOM
	if framing_arena:
		# One scale per arena, retained through victory. Only its outer edges
		# require panning; the boss's jump and attack do not drive the camera.
		desired_zoom = 0.90 if level.get("chapter_level")=="3-3" else (1.10 if level.forest_art else 1.0)
	zoom = Vector2.ONE * move_toward(zoom.x, desired_zoom, 0.30 * delta)
	var half := get_viewport_rect().size / zoom * 0.5
	if framing_arena:
		var centre: float = (level.arena_entry_x + level.get_node("Gate").position.x) * 0.5
		anchor.x = clampf(centre, actor.global_position.x - half.x + 96, actor.global_position.x + half.x - 96)
		anchor.y = 270
	else:
		var margin := half.x * HORIZONTAL_ZONE
		anchor.x = clampf(anchor.x, actor.global_position.x - margin, actor.global_position.x + margin)
		# Ground hysteresis ignores ordinary jumps and small steps.
		if actor.is_on_floor() and absf(actor.global_position.y - ground_height) >= LANDING_STEP:
			ground_height = actor.global_position.y
			anchor.y = ground_height - 100
		# Follow long falls before the feet leave the visible landing area.
		if actor.velocity.y > 0 and actor.global_position.y > anchor.y + half.y - 48:
			anchor.y = actor.global_position.y - half.y + 48
	anchor = bounded(anchor)
	var target := Vector2(lerpf(global_position.x, anchor.x, 1.0 - exp(-12.0 * delta)),
		lerpf(global_position.y, anchor.y, 1.0 - exp(-6.0 * delta)))
	global_position = bounded(target)
