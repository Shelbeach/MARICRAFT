extends "res://tests/s04_routes.gd"
var record_frame:=0
var visual_states:Dictionary={}

func _initialize() -> void:
	root.unfocusable=true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/temp/p04-p05/boss-motion"))
	super._initialize()

func next_frame() -> void:
	await super.next_frame()
	if frame_no%2!=0: return
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	image.save_png("res://reports/temp/p04-p05/boss-motion/%05d.png"%record_frame)
	record_frame+=1
	var w=game.world
	if w.boss:
		var skin=w.boss.get_node("Skin")
		var tag:String="boss-"+skin.art.last_clip
		if not visual_states.has(tag):
			visual_states[tag]=true
			image.save_png("res://reports/evidence/p04-p05/after/"+tag+".png")
	for mark in get_nodes_in_group("mine_strikes"):
		if not mark.has_node("Skin"): continue
		var tag:String="danger-"+mark.get_node("Skin").art.last_clip
		if not visual_states.has(tag):
			visual_states[tag]=true
			image.save_png("res://reports/evidence/p04-p05/after/"+tag+".png")
