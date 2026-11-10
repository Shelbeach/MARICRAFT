extends Node2D
# Read-only adapter for scripts/gameplay/ragnaros.gd in MARICRAFT 0.7.0 + P07 integration.
# Instantiate as a SIBLING of the physical boss. Call bind_controller(boss) after its _ready.
# The integrator disables the prototype _draw; this adapter does not modify the controller.
const RigScene=preload("ragnaros_rig.tscn")
var controller:Node2D
var rig:Node2D
var previous_mode:=-1
var previous_phase:=1
var visual_age:=0.0
var transition_age:=1.0
var reaction_age:=99.0
var reaction:=""
var phase_transition:=false
var entry_bottom:=Vector2(156,-95)
var entry_side:=1.0
var old_pose:Dictionary={}
var body_from:Dictionary={}
var body_blend_age:=1.0
var previous_action:=""
func _ready()->void:
	rig=RigScene.instantiate();add_child(rig)
func bind_controller(value:Node2D)->void:
	controller=value
	if not controller.visual_event.is_connected(_on_visual_event):controller.visual_event.connect(_on_visual_event)
	previous_mode=-1
func _on_visual_event(kind:String)->void:
	if kind in ["hit","deflect"]:reaction=kind;reaction_age=0
func _process(delta:float)->void:
	if not is_instance_valid(controller) or not rig:return
	visual_age+=delta;reaction_age+=delta;transition_age+=delta;body_blend_age+=delta
	global_position=controller.get_parent().to_global(controller.home)
	var mode:int=controller.mode
	var phase:int=controller.phase()
	if mode!=previous_mode:
		entry_bottom=rig.head_bottom;entry_side=rig.side;old_pose=rig.pose.duplicate();transition_age=0
		phase_transition=phase!=previous_phase
		previous_mode=mode;previous_phase=phase
	var selected_side:float=-1.0 if controller.position.x<controller.home.x else 1.0
	if mode==0:selected_side=entry_side
	var p:=0.0
	var action:="idle"
	var state:="raised"
	var bottom:=entry_bottom
	var facing:=selected_side
	match mode:
		0:
			p=clampf(transition_age/controller.watch_duration,0,1)
			action="phase" if phase_transition else ("recover" if p<1 else "idle")
			if action=="idle":p=fposmod(visual_age*1.5,1)
			if controller.engaged and controller.step==0 and not phase_transition:
				action="alert";p=clampf(1-controller.clock/0.9,0,1)
			bottom=entry_bottom.lerp(Vector2(entry_bottom.x,-95),smoothstep(0,0.35,transition_age))
		1:
			p=clampf(1-controller.clock/(1.05 if controller.attack==2 else 0.95),0,1)
			action=["prepare_fire","prepare_hammer","ground_power"][controller.attack];state="prepare"
			var u:=smoothstep(0,0.8,p)
			facing=lerpf(entry_side,selected_side,u)
			bottom=entry_bottom.lerp(Vector2(selected_side*156,-120),u)
			if entry_side*selected_side<0:bottom.y-=sin(u*PI)*118
		2:
			p=clampf(1-controller.clock/controller.strike_duration(),0,1)
			action=["fire_shot","hammer_slam","ground_power"][controller.attack];state="strike"
			bottom=entry_bottom.lerp(Vector2(selected_side*156,0),smoothstep(0,0.3,p))
		3:
			p=clampf(1-controller.clock/controller.open_duration(),0,1)
			action="open" if controller.hits==0 else "guarded";state="open" if controller.hits==0 else "grounded"
			bottom=Vector2(selected_side*156,0)
		4:
			p=clampf(controller.death_age/2.0,0,1)
			action="death";state="end"
			bottom=entry_bottom.lerp(Vector2(entry_bottom.x,0),smoothstep(0,0.2,p))
	if mode!=4 and reaction_age<0.36:
		action=reaction;p=clampf(reaction_age/0.36,0,1);state="hit" if reaction=="hit" else "guarded"
	if action!=previous_action:
		body_from=rig.pose.duplicate();body_blend_age=0;previous_action=action
	rig.set_visual(action,p,bottom,facing,state,body_from,smoothstep(0,0.12,body_blend_age))
