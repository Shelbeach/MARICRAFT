extends "res://tests/s02_form_reachability.gd"

# Generate an ordinary v2 profile unlocked to 1-3 in the isolated QA directory.
# Record keyboard transitions from a real traversal for replay in Edge.
var events: Array=[]
var down: Dictionary={}
var origin_tick:=0
var mark:=-1

func press(code: Key,on: bool) -> void:
	if down.get(code,false)!=on:
		events.append([Engine.get_physics_frames()-origin_tick,code,on])
		down[code]=on
	super.press(code,on)

func route_continue(_level: String,actor,_axis: int,_frame: int) -> bool:
	if mark<0 and actor.position.x>=1800:
		mark=Engine.get_physics_frames()-origin_tick
	return state.p.hearts==3

func run() -> void:
	var dir:="res://reports/temp/polish/browser-fixture/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	state=root.get_node("Campaign")
	state.store.prefix=ProjectSettings.globalize_path(dir+"campaign")
	state.new_game("human")
	state.finish(138)
	state.leave_result()
	state.finish(82)
	state.leave_result()
	state.start_sandbox() # freeze the on-disk fixture at the beginning of 1-3
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	game.start_level()
	await ticks(6)
	target_form=2
	origin_tick=Engine.get_physics_frames()
	await route("1-3",false)
	var f:=FileAccess.open(dir+"keys.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"events":events,"combat":mark}))
	check(game.page=="result" and game.world.player.form==2,"real rune and victory trace")
	quit(1 if failed else 0)
