extends "res://tests/s02_forest.gd"
const DEST:="res://reports/evidence/forest-art/audit/"
var frames_saved:=0
func redraw() -> void:
	game.world.get_node("ForestArt").get_child(1)._process(0)
func run() -> void:
	state=root.get_node("Campaign")
	state.start_sandbox()
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST))
	var audit:Array=[]
	for level in ["1-1","1-2","1-3"]:
		await test_level(level)
		var world=game.world
		world.player.get_node("Camera").enabled=false
		paused=true
		game.get_node("Interface").hide()
		var segments:Array=[[level,0,int(world.finish_x+128)-960]]
		if world.cave_left>0: segments.append(["grotto",int(world.cave_left),int(world.cave_left+world.cave_width)-960])
		for part in segments:
			var name:String=part[0]
			var start:int=part[1]
			var finish:int=part[2]
			var points:Array[int]=[]
			for x in range(start,finish,450): points.append(x)
			if not points.has(finish): points.append(finish)
			for x in points:
				root.canvas_transform=Transform2D(0,Vector2(-x,0))
				redraw()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(DEST+name+"-"+str(x)+".png")
				audit.append({"level":name,"x":x,"width":960,"height":540})
			frames_saved=0
			var clip_dir:="res://reports/temp/forest-art/camera-"+name+"/"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(clip_dir))
			# The actual game scene, with controlled camera motion for layout review.
			for direction in [1,-1]:
				var distance:=finish-start
				for frame in ceili(distance/10.0)+1:
					var x:=minf(finish,start+frame*10.0) if direction==1 else maxf(start,finish-frame*10.0)
					root.canvas_transform=Transform2D(0,Vector2(-x,0))
					redraw()
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_jpg(clip_dir+"%05d.jpg"%frames_saved,0.94)
					frames_saved+=1
			print("CAMERA ",name," frames=",frames_saved," coverage=",start,"..",finish," overlap=510")
		# Resizes retain the project's existing canvas-items stretch configuration.
		for dimensions in [Vector2i(640,360),Vector2i(1280,720),Vector2i(1280,800)]:
			root.size=dimensions
			for frame in 3: await process_frame
			var x:int=6400 if level=="1-2" else (1838 if level=="1-3" else 0)
			root.canvas_transform=Transform2D(0,Vector2(-x,0))
			redraw()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(DEST+level+"-window-"+str(dimensions.x)+"x"+str(dimensions.y)+".png")
			print("WINDOW ",dimensions," viewport=",root.get_visible_rect()," scale_size=",root.content_scale_size," aspect=",root.content_scale_aspect)
		root.size=Vector2i(960,540)
		paused=false
	var file:=FileAccess.open(DEST+"coverage.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(audit,"  "))
	quit()
