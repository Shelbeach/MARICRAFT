extends Node
## Opt-in, read-only acceptance telemetry. No commands or setters enter the game.
var host
var browser
var audio_events:Dictionary={}
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	browser=JavaScriptBridge.get_interface("window")
	SFX.played.connect(func(id,_details): audio_events[id]=int(audio_events.get(id,0))+1)
func _process(_delta:float) -> void:
	var d:={"page":host.page,"level":Campaign.p.get("level",""),"frame":Engine.get_physics_frames(),"fps":Engine.get_frames_per_second()}
	d.music=MusicManager.snapshot()
	d.buttons=[]
	for button in host.get_tree().root.find_children("*","Button",true,false):
		if button.is_visible_in_tree():
			var rect:Rect2=button.get_global_rect()
			d.buttons.append({"name":str(button.name),"text":button.text,"x":rect.get_center().x,"y":rect.get_center().y,"disabled":button.disabled})
	d.texture_bytes=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
	d.debug=OS.is_debug_build()
	d.sandbox=Campaign.sandbox
	d.profile={"status":Campaign.p.get("status",""),"wallet":Campaign.p.get("wallet",0),"score":Campaign.p.get("score",0),"completed":Campaign.p.get("completed",false),"attempt":Campaign.p.get("attempt",0)}
	d.audio={"unlocked":SFX.unlocked,"events":audio_events,"voices":SFX.voices.filter(func(v): return not v.id.is_empty()).size()}
	if is_instance_valid(host.world):
		var w=host.world
		var a=w.player
		d.player={"x":a.position.x,"y":a.position.y,"vx":a.velocity.x,"vy":a.velocity.y,"floor":a.is_on_floor(),"wall":a.is_on_wall(),"form":a.form}
		d.player.shot_cooldown=a.shot_cooldown
		var camera:Camera2D=a.get_node("Camera")
		var centre:=camera.get_screen_center_position()
		d.camera={"x":centre.x,"y":centre.y,"zoom":camera.zoom.x,"width":camera.get_viewport_rect().size.x/camera.zoom.x,"height":camera.get_viewport_rect().size.y/camera.zoom.y}
		d.arena={"active":w.arena.active,"released":w.arena.released,"left":w.arena.left,"right":w.arena.right} if w.arena else {}
		d.player.step_wall=false
		for i in a.get_slide_collision_count():
			var hit=a.get_slide_collision(i)
			var box=hit.get_collider().get_node_or_null("Hitbox")
			if absf(hit.get_normal().x)>0.5 and box and box.global_position.y+box.shape.get_rect().end.y>=a.position.y-3: d.player.step_wall=true
		var head:Vector2=a.global_position-Vector2(0,a.height+1)
		var above:Dictionary=a.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(head,head-Vector2(0,150),1))
		d.player.low_ceiling=not above.is_empty() and head.y-above.position.y<80
		var tip:Vector2=a.global_position+Vector2(26,-3)
		d.player.edge=a.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(tip,tip+Vector2(0,12),1)).is_empty()
		d.hearts=Campaign.p.hearts
		d.enemies=[]
		for child in w.get_children():
			if child.has_method("defeat") and not child.is_queued_for_deletion(): d.enemies.append({"x":child.position.x,"y":child.position.y,"direction":child.direction})
		d.ferries=[]
		for ferry in w.get_children():
			if ferry.get("elapsed")!=null and ferry.get("travel")!=null:
				var riding:=false
				for i in a.get_slide_collision_count():
					var hit=a.get_slide_collision(i)
					if hit.get_collider()==ferry and hit.get_normal().y< -0.8: riding=true
				d.ferries.append({"x":ferry.position.x,"y":ferry.position.y,"riding":riding,"elapsed":ferry.elapsed,"period":ferry.period,"name":str(ferry.name)})
		d.shots=[]
		d.hazards=[]
		for hazard in w.get_children():
			if hazard.has_method("bounds"): d.hazards.append({"name":str(hazard.name),"x":hazard.position.x,"y":hazard.position.y,"width":hazard.width,"height":hazard.height,"kind":hazard.kind,"age":hazard.age,"warning":hazard.warning,"duration":hazard.duration,"rest":hazard.rest})
		for shot in get_tree().get_nodes_in_group("boss_shots"):
			d.shots.append({"x":shot.position.x,"y":shot.position.y,"dx":shot.direction.x})
		d.enemy_shots=[]
		for shot in get_tree().get_nodes_in_group("enemy_projectiles"):
			d.enemy_shots.append({"x":shot.position.x,"y":shot.position.y,"dx":shot.direction.x,"dy":shot.direction.y,"speed":shot.speed_override})
		if w.boss and str(d.level).begins_with("1-"):
			var b=w.boss
			d.boss={"x":b.position.x,"y":b.position.y,"hp":b.hp,"mode":b.mode,"kind":b.move.kind if b.move else -1,"landing_x":b.landing.x}
		elif w.boss:
			var b=w.boss
			d.boss={"x":b.position.x,"y":b.position.y,"hp":b.hp,"mode":b.mode,"phase":b.attack_phase,"clock":b.clock,"hits":b.hits,"step":b.step,"home_x":b.home.x,"marks":b.marks,"arena_start":b.arena_start}
			d.boss.attack=b.get("attack")
		d.strikes=[]
		for mark in get_tree().get_nodes_in_group("mine_strikes"):
			d.strikes.append({"x":mark.position.x,"kind":mark.kind,"age":mark.age,"warning":mark.warning,"duration":mark.duration,"width":mark.half_width})
	browser.maricraftObservation=JSON.stringify(d)

