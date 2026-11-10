extends "res://tests/s02_forest.gd"

func run() -> void:
	state=root.get_node("Campaign")
	state.start_sandbox()
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	var version:="before" if "--before" in OS.get_cmdline_user_args() else "after"
	var layout := "--layout" in OS.get_cmdline_user_args()
	var folder:="res://reports/evidence/layout/" if layout else "res://reports/evidence/polish/"+version+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var durotar := "--s04" in OS.get_cmdline_user_args()
	if durotar: folder="res://reports/evidence/s04/"
	if "--art" in OS.get_cmdline_user_args(): folder="res://reports/evidence/forest-art/"
	for level in (["2-1","2-2","2-3"] if durotar else ["1-1","1-2","1-3"]):
		await test_level(level)
		var world=game.world
		game.get_node("Interface").hide()
		world.player.get_node("Camera").enabled=false
		paused=true
		var origins:Array[int]=[]
		for x in range(0,int(world.finish_x+128),900):
			origins.append(mini(x,int(world.finish_x+128)-960))
		if world.cave_left>0:
			origins.append(int(world.cave_left))
			origins.append(int(world.cave_left+world.cave_width)-960)
		var sheet:=Image.create(960,ceili(origins.size()/2.0)*270,false,Image.FORMAT_RGB8)
		for i in origins.size():
			root.canvas_transform=Transform2D(0,Vector2(-origins[i],0))
			if world.has_node("ForestArt"): world.get_node("ForestArt").get_child(1)._process(0)
			await RenderingServer.frame_post_draw
			var frame:=root.get_texture().get_image()
			check(frame.save_png(folder+level+"-"+str(origins[i])+".png")==OK,"camera "+str(origins[i]))
			frame.convert(Image.FORMAT_RGB8)
			frame.resize(480,270,Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(frame,Rect2i(0,0,480,270),Vector2i((i%2)*480,(i/2)*270))
		check(sheet.save_png(folder+level+".png")==OK,"contact sheet "+level)
		panorama(folder,level,origins,int(world.finish_x+128),int(world.cave_left),int(world.cave_width))
		if version=="after" and not layout and not durotar and "--art" not in OS.get_cmdline_user_args():
			panorama(folder.replace("/after/","/before/"),level,origins,int(world.finish_x+128),int(world.cave_left),int(world.cave_width))
		paused=false
		game.get_node("Interface").show()
	quit(1 if failed else 0)

func panorama(folder: String,level: String,origins: Array[int],width: int,cave_x: int,cave_width: int) -> void:
	var surface:=Image.create(width,540,false,Image.FORMAT_RGB8)
	var cave:=Image.create(maxi(1,cave_width),540,false,Image.FORMAT_RGB8)
	for x in origins:
		var part:=Image.load_from_file(folder+level+"-"+str(x)+".png")
		part.convert(Image.FORMAT_RGB8)
		if cave_x and x>=cave_x:
			cave.blit_rect(part,Rect2i(0,0,960,540),Vector2i(x-cave_x,0))
		else:
			surface.blit_rect(part,Rect2i(0,0,960,540),Vector2i(x,0))
	if folder.ends_with("/s04/") or folder.ends_with("/forest-art/"):
		check(surface.save_png(folder+"strip-"+level+".png")==OK,"full-width panorama "+level)
		if cave_width: check(cave.save_png(folder+"strip-mine.png")==OK,"full-width panorama of mine")
	surface.resize(width/2,270,Image.INTERPOLATE_BILINEAR)
	var rows:=ceili(surface.get_width()/960.0)
	var out:=Image.create(960,(rows+int(cave_width>0))*276,false,Image.FORMAT_RGB8)
	out.fill(Color("#10252c"))
	for i in rows:
		out.blit_rect(surface,Rect2i(i*960,0,mini(960,surface.get_width()-i*960),270),Vector2i(0,i*276))
	if cave_width:
		cave.resize(cave_width/2,270,Image.INTERPOLATE_BILINEAR)
		out.blit_rect(cave,Rect2i(Vector2i.ZERO,cave.get_size()),Vector2i(0,rows*276))
	check(out.save_png(folder+"pan-"+level+".png")==OK,"continuous panorama "+level)
