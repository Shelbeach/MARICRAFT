extends SceneTree
var game
var state
var events:Array=[]
func _initialize() -> void:
	root.unfocusable=true
	run.call_deferred()
func hold(seconds:float,label:String) -> void:
	print("MUSIC_DEMO ",label," ",root.get_node("MusicManager").snapshot())
	events.append({"label":label,"time":Engine.get_physics_frames()/60.0,"music":root.get_node("MusicManager").snapshot()})
	for i in roundi(seconds*60): await physics_frame
func stage(id:String) -> void:
	state.debug_level(id)
	game.start_level()
	state.cheats.shield=true
	game.world.player.set_physics_process(false)
func run() -> void:
	state=root.get_node("Campaign");state.start_sandbox()
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	game.show_page("main")
	await hold(5,"1 menu")
	game.show_page("settings");await hold(3,"same menu theme, no restart")
	game.show_page("map");await hold(3,"same menu theme on map")
	stage("1-1");await hold(5,"2 forest")
	game.show_page("pause");await hold(2,"pause ducks")
	game.show_page("play");await hold(2,"resume same playback")
	stage("1-3")
	game.world.player.position=Vector2(game.world.arena.left+100,480)
	await hold(5,"5 first boss")
	stage("2-1");await hold(5,"3 durotar")
	stage("2-3")
	game.world.player.position=Vector2(game.world.arena.left+100,480)
	await hold(4,"5 second boss")
	stage("3-1");await hold(5,"4 molten")
	stage("3-3")
	game.world.player.position=Vector2(game.world.arena.left+110,480)
	await hold(6,"6 ragnaros")
	game.world.boss.take_damage(12)
	await hold(5,"final death hold, then region")
	game.main_menu();await hold(4,"1 return to menu")
	FileAccess.open("res://reports/evidence/p07v03-music/music-demo.json",FileAccess.WRITE).store_string(JSON.stringify(events,"  "))
	root.get_node("MusicManager").stop_all()
	OS.delay_msec(150)
	quit()
