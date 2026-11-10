extends "res://tests/forest_art_routes.gd"
var recorded:=0
var capture_tick:=-100
func frame_capture() -> void:
	if target_form!=0 or Engine.get_physics_frames()-capture_tick<6: return
	capture_tick=Engine.get_physics_frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/temp/durotar-revision/forest-baseline/%05d.png"%recorded)
	recorded+=1
