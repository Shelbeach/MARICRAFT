extends SceneTree

const TITLE := "res://scenes/boot/start.tscn"
const SHOTS := "res://reports/evidence/screenshots/"
var failed := false

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	failed = failed or not ok

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func capture(filename: String) -> void:
	if "--screenshots" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var path := ProjectSettings.globalize_path(SHOTS)
		DirAccess.make_dir_recursive_absolute(path)
		check(root.get_texture().get_image().save_png(path.path_join(filename)) == OK, filename)

func run() -> void:
	change_scene_to_file(TITLE)
	await scene_changed
	check(current_scene.get_node("Start").has_focus(), "start button focused")
	await capture("s00-menu.png")
	key(KEY_ENTER, true)
	key(KEY_ENTER, false)
	await ticks(6)
	if not current_scene or current_scene.name != "TestField":
		check(false, "menu opens test field")
		quit(1)
		return
	check(true, "menu opens test field")
	var player: CharacterBody2D = current_scene.get_node("Player")
	var camera: Camera2D = player.get_node("Camera")
	await ticks(24)
	check(player.is_on_floor() and absf(player.position.y - 464.0) < 1, "lands on floor")
	await capture("s00-field.png")
	var start_x := player.position.x
	key(KEY_A, true)
	await ticks(12)
	key(KEY_A, false)
	check(player.position.x < start_x - 20, "A moves left")
	key(KEY_D, true)
	await ticks(110)
	check(player.is_on_wall() and absf(player.position.x - 308.0) < 1, "D stops at first obstacle")
	key(KEY_SPACE, true)
	await ticks(4)
	key(KEY_SPACE, false)
	check(player.velocity.y < 0 and player.position.y < 464, "Space jumps")
	await ticks(30)
	key(KEY_D, false)
	await ticks(20)
	check(player.is_on_floor() and absf(player.position.y - 432.0) < 1, "lands on step")
	key(KEY_D, true)
	await ticks(8)
	key(KEY_SPACE, true)
	await ticks(2)
	key(KEY_SPACE, false)
	await ticks(50)
	key(KEY_D, false)
	check(camera.is_current() and camera.get_screen_center_position().x > 500, "camera scrolls")
	var menu := root.get_node("DebugTools/DeveloperMenu")
	key(KEY_F1, true)
	key(KEY_F1, false)
	await process_frame
	check(paused and menu.get_node("Modal").visible, "F1 opens modal")
	menu.get_node("%Collisions").button_pressed = true
	key(KEY_F1, true)
	key(KEY_F1, false)
	await process_frame
	check(not paused and not menu.get_node("Modal").visible, "F1 closes modal")
	check(menu.get_node("Outlines").is_visible_in_tree(), "hitbox overlay remains visible during play")
	quit(1 if failed else 0)
