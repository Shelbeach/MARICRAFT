extends "res://tests/durotar_revision_movie.gd"
var snapshots:={}
func next_frame() -> void:
	await super.next_frame()
	if level_id!="2-3" or not is_instance_valid(game.world.boss): return
	var b=game.world.boss
	var name:=""
	if b.mode==b.Mode.WARN and b.clock<0.4: name="foreman-phase-%d-warning"%b.attack_phase
	elif b.mode==b.Mode.STRIKE:
		name="foreman-phase-%d-active"%b.attack_phase
		if b.attack_phase==3 and b.clock<0.3: name="foreman-second-fall"
	elif b.mode==b.Mode.DEAD: name="foreman-death-%d"%b.get_node("Skin").art.sprite.frame
	if name.is_empty() or snapshots.has(name): return
	snapshots[name]=true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/evidence/durotar-revision/"+name+".png")
