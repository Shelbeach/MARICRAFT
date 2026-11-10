extends Node2D
# Presentation only. No physics nodes, game-state writes, timers or damage.
const Body=preload("body_view.gd")
const Pose=preload("body_pose.gd")
const UPPER=preload("../parts/upper_arm.png")
const LOWER=preload("../parts/forearm.png")
const HAND=preload("../parts/hand.png")
const CAP=preload("../parts/shoulder_cap.png")
const HANDLE=preload("../parts/handle.png")
const HEAD=preload("../parts/head_hammer.png")
var body:Node2D
var body_left:Node2D
var clip:="idle"
var progress:=0.0
var side:=1.0
var head_bottom:=Vector2(156,-95)
var handle_angle:=-0.30
var head_state:="raised"
var debug_anchors:=false
var attachment_points:Dictionary={}
var pose:Dictionary=Pose.sample("idle",0)
var head_frames:SpriteFrames=preload("../resources/hammer.tres")
func _ready()->void:
	body=Body.new();body.scale=Vector2.ONE*0.5;body.z_index=0;add_child(body)
	body_left=Body.new();body_left.scale=Vector2(-0.5,0.5);body_left.z_index=0;add_child(body_left)
	queue_redraw()
func set_visual(action:String,t:float,bottom:Vector2,facing:float=1.0,weapon_state:String="raised",blend_from:Dictionary={},blend_weight:float=1.0)->void:
	clip=action;progress=clampf(t,0,1);head_bottom=bottom;side=clampf(facing,-1,1);head_state=weapon_state
	pose=Pose.sample(action,progress)
	if not blend_from.is_empty():pose=Pose.blend(blend_from,pose,blend_weight)
	if body:
		body.sample(action,progress)
		body_left.sample(action,progress)
		body.apply_pose(pose);body_left.apply_pose(pose)
		# A single opaque silhouette changes facing at the overhead apex.
		# Alpha-crossfading separate draw layers creates a translucent double face.
		body.visible=side>=0.0;body_left.visible=not body.visible
		body.modulate.a=1.0;body_left.modulate.a=1.0
		body.scale.x=0.5*(0.88+0.12*absf(side));body_left.scale.x=-body.scale.x
	var grounded:=clampf((bottom.y+95.0)/95.0,0,1)
	handle_angle=lerpf(-0.30,0.49,grounded)
	if action=="death":handle_angle=lerpf(0.49,0.0,smoothstep(0.25,1,progress))
	update_attachments();queue_redraw()
func solve_elbow(a:Vector2,b:Vector2,l1:float,l2:float,bend:float)->Vector2:
	var d:=b-a
	var length:=clampf(d.length(),0.001,l1+l2-0.001)
	var along:=(l1*l1-l2*l2+length*length)/(2*length)
	var height:=sqrt(maxf(0,l1*l1-along*along))
	var dir:=d.normalized()
	return a+dir*along+Vector2(-dir.y,dir.x)*height*bend
func update_attachments()->void:
	# The weapon orientation changes continuously with side, independent of the body atlas.
	var direction:=Vector2(side*cos(handle_angle),sin(handle_angle)).normalized()
	var socket:=head_bottom+Vector2(-side*16,-32)
	var pommel:=socket-direction*124
	var front_grip:=pommel+direction*44
	var back_grip:=pommel+direction*80
	var shoulder_f:Vector2=Pose.shoulder(pose,true)*0.5
	var shoulder_b:Vector2=Pose.shoulder(pose,false)*0.5
	# Shoulder positions are continuous, with paired arm roles exchanged while turning.
	shoulder_f.x*=side;shoulder_b.x*=side
	var elbow_f:=solve_elbow(shoulder_f,front_grip,65,61,side)
	var elbow_b:=solve_elbow(shoulder_b,back_grip,lerpf(65,50,absf(side)),lerpf(61,52,absf(side)),-side)
	attachment_points={"body_pivot":Vector2.ZERO,"head_pivot":head_bottom,"head_socket":socket,"handle_start":pommel,"front_shoulder":shoulder_f,"front_elbow":elbow_f,"front_wrist":front_grip-direction*14,"front_arm_endpoint":front_grip,"front_grip":front_grip,"rear_shoulder":shoulder_b,"rear_elbow":elbow_b,"rear_wrist":back_grip-direction*14,"rear_arm_endpoint":back_grip,"rear_grip":back_grip}
func part(tex:Texture2D,at:Vector2,pivot:Vector2,angle:float,s:Vector2=Vector2.ONE*0.5,tint:Color=Color.WHITE)->void:
	draw_set_transform(at,angle,s);draw_texture(tex,-pivot,tint)
func segment(tex:Texture2D,a:Vector2,b:Vector2,pivot:Vector2,bone_px:float,tint:Color=Color.WHITE)->void:
	var d:=b-a
	part(tex,a,pivot,d.angle(),Vector2(d.length()/bone_px,0.5),tint)
func _draw()->void:
	if attachment_points.is_empty():return
	var a:=attachment_points
	var dim:Color=Color(.83,.75,.78) if clip!="death" else pose.tint
	segment(UPPER,a.rear_shoulder,a.rear_elbow,Vector2(14,48),130,dim)
	segment(LOWER,a.rear_elbow,a.rear_grip,Vector2(12,41),114,dim)
	# Front arms and weapon use a sibling layer above the body; drawn below through front proxy.
	draw_set_transform(Vector2.ZERO)
func draw_front(target:Node2D)->void:
	if attachment_points.is_empty():return
	var a:=attachment_points
	var tint:Color=pose.tint if clip=="death" else Color.WHITE
	var d:Vector2=a.head_socket-a.handle_start
	target.draw_set_transform(a.handle_start,d.angle(),Vector2(d.length()/248,0.5))
	target.draw_texture(HANDLE,Vector2(-13,-36.5),tint)
	_draw_segment(target,UPPER,a.front_shoulder,a.front_elbow,Vector2(14,48),130,tint)
	_draw_segment(target,LOWER,a.front_elbow,a.front_grip,Vector2(12,41),114,tint)
	for key in ["front_grip","rear_grip"]:
		target.draw_set_transform(a[key],d.angle(),Vector2.ONE*0.5)
		target.draw_texture(HAND,Vector2(-32,-24),tint)
	for key in ["front_shoulder","rear_shoulder"]:
		target.draw_set_transform(a[key]+Vector2(0,-10),0,Vector2.ONE*0.5)
		target.draw_texture(CAP,Vector2(-43,-35),tint)
	target.draw_set_transform(head_bottom,0,Vector2.ONE*0.5)
	var head_tex:Texture2D=HEAD
	if head_frames and head_frames.has_animation(head_state):head_tex=head_frames.get_frame_texture(head_state,mini(3,int(progress*4)))
	target.draw_texture(head_tex,Vector2(-64,-128))
	target.draw_set_transform(Vector2.ZERO)
	if debug_anchors:
		for key in a:target.draw_circle(a[key],2,Color.CYAN)
		target.draw_rect(Rect2(head_bottom+Vector2(-32,-64),Vector2(64,64)),Color.GREEN,false,1)
func _draw_segment(target:Node2D,tex:Texture2D,a:Vector2,b:Vector2,pivot:Vector2,bone_px:float,tint:Color)->void:
	var d:=b-a
	target.draw_set_transform(a,d.angle(),Vector2(d.length()/bone_px,0.5));target.draw_texture(tex,-pivot,tint)
