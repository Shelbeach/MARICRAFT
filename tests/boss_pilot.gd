extends RefCounted
## Test-only keyboard driver: approach a recovering target or aim on the left step.
var jump_ticks := 0
var frame := 0
var last_axis := 2

func tick(tree,actor,boss,ranged: bool,spam := false) -> void:
	frame+=1
	var dx:float=boss.position.x-actor.position.x
	var axis:=0
	var jump:=false
	var open:bool=boss.mode==boss.Mode.OPEN
	if "--trace" in OS.get_cmdline_user_args() and frame%6==0:
		print("FIRST BOSS ",frame," player=",actor.position," form=",actor.form," vy=",actor.velocity.y," held=",jump_ticks," boss=",boss.position," mode=",boss.mode," hp=",boss.hp," clock=",boss.time_left," face=",actor.facing," reload=",actor.shot_cooldown," clear=",boss.clear_lane," blocks=",boss.deflections)
	if ranged:
		var safe_x:float=boss.position.x-150
		if boss.mode==boss.Mode.WARN and boss.move.kind==boss.DASH:
			safe_x=boss.landing.x-105
		axis=signi(roundi(safe_x-actor.position.x)) if absf(safe_x-actor.position.x)>5 else 0
		if not spam:
			for shot in tree.get_nodes_in_group("boss_shots"):
				if shot.direction.x<0 and shot.position.x-actor.position.x>0 and shot.position.x-actor.position.x<72:
					jump=true
		# Lead the projectile by its real travel time.
		var travel:=absf(dx)/320.0
		var arriving:bool=(open and boss.time_left>travel-0.10) or (boss.mode==boss.Mode.ACT and boss.time_left<travel) or (boss.mode==boss.Mode.WARN and boss.time_left+boss.move.execution<travel)
		var casting:bool=(spam or (arriving and actor.is_on_floor())) and actor.shot_cooldown<=0
		if casting: axis=signi(roundi(dx))
		# The input event is consumed on the next physics step. First orient, then
		# cast; a retreating pilot must not assume an unprocessed key changed facing.
		tree.press(KEY_E,casting and actor.facing==axis)
	else:
		var target:float=boss.position.x-117
		if open:
			target=boss.position.x-4
			if absf(dx)<143: jump=true
		if boss.mode==boss.Mode.WARN and boss.move.kind==boss.DASH:
			target=boss.landing.x-64
		axis=signi(roundi(target-actor.position.x)) if absf(target-actor.position.x)>3 else 0
		jump=jump or actor.is_on_wall()
		for shot in tree.get_nodes_in_group("boss_shots"):
			var gap:float=(actor.position.x-shot.position.x)*signf(shot.direction.x)
			if gap>0 and gap<67: jump=true
	if axis!=last_axis:
		tree.press(KEY_D,axis>0)
		tree.press(KEY_A,axis<0)
		last_axis=axis
	if jump_ticks>0:
		jump_ticks-=1
		if jump_ticks==0: tree.press(KEY_SPACE,false)
	elif jump and actor.is_on_floor():
		tree.press(KEY_SPACE,true)
		jump_ticks=35

func release(tree) -> void:
	for k in [KEY_E,KEY_A,KEY_D,KEY_SPACE]:
		tree.press(k,false)
