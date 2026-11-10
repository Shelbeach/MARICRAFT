extends Node
var records:Dictionary={}
func _ready() -> void: process_physics_priority=10
func _physics_process(_delta:float) -> void:
	var game=get_tree().current_scene
	if not game or game.get("page")!="play" or not is_instance_valid(game.world): return
	var a=game.world.player
	if a.recovering>0 or not a.visible: return
	var c:Camera2D=a.get_node("Camera")
	c.force_update_scroll()
	var campaign=get_node("/root/Campaign")
	var id:String=campaign.p.level+"/"+campaign.p.hero+"/"+str(a.form)
	if not records.has(id): records[id]={"frames":0,"outside":0,"hud_overlap":0,"min_head":999.0,"max_feet":0.0,"max_dx":0.0,"where":[]}
	var r:Dictionary=records[id]
	var screen:Vector2=a.get_global_transform_with_canvas().origin
	var head:float=screen.y-a.height*c.zoom.y
	r.frames+=1;r.min_head=minf(r.min_head,head);r.max_feet=maxf(r.max_feet,screen.y)
	r.max_dx=maxf(r.max_dx,absf(screen.x-480))
	if head<0 or screen.x<0 or screen.x>960 or screen.y>540:
		r.outside+=1
		if r.where.size()<8:r.where.append([a.position.x,a.position.y,head,screen.x,screen.y])
	if head<66:r.hud_overlap+=1
func _exit_tree() -> void:
	var args:=OS.get_cmdline_user_args()
	var tag:="human" if not "--ogre" in args else "ogre"
	tag+="-30" if "--30" in args else "-60"
	var file:=FileAccess.open("res://reports/evidence/camera-repair/view-"+str(get_meta("region"))+"-"+tag+".json",FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(records,"  "))
