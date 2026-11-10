extends "res://tests/s04_routes.gd"
var recorded:=0
func _initialize() -> void:
	root.unfocusable=true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/temp/durotar-revision/baseline"))
	super._initialize()
func next_frame() -> void:
	await super.next_frame()
	if frame_no%6!=0: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/temp/durotar-revision/baseline/%05d.png"%recorded)
	recorded+=1
