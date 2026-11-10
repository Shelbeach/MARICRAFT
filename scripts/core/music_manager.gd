extends Node
## One campaign soundtrack. Presentation only; no profile, reward or boss writes.
signal theme_changed(id:String)
const ROOT:="res://assets/audio/music/"
const BUS:="Music"
const CROSSFADE:=1.1
var tracks:Dictionary={}
var streams:Dictionary={}
var voices:Array[Dictionary]=[]
var host:Node
var current_theme:=""
var pending_theme:=""
var unlocked:=not OS.has_feature("web")
var duck:=1.0
var finale_hold:=0.0
var was_final_battle:=false
var starts:Dictionary={}
var clock:=0.0

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	# Observe the user gesture before a modal/debug shortcut can consume _input.
	get_window().window_input.connect(_input)
	while not Campaign.access_ready: await get_tree().process_frame
	tracks=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
	for id in tracks:
		var stream:=load(ROOT+str(tracks[id].file)) as AudioStreamOggVorbis
		stream.loop=true
		stream.loop_offset=float(tracks[id].loop_start)
		streams[id]=stream
	for i in 2:
		var player:=AudioStreamPlayer.new()
		player.name="MusicVoice%d"%i
		player.bus=BUS
		player.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
		add_child(player)
		voices.append({"player":player,"id":"","gain":0.0,"target":0.0})

func bind_flow(value:Node) -> void:
	host=value

func _input(event:InputEvent) -> void:
	if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		unlocked=true

func region_theme(level:String) -> String:
	return "forest" if level.begins_with("1-") else ("durotar" if level.begins_with("2-") else "molten")

func desired_theme(delta:float) -> String:
	if not is_instance_valid(host): return ""
	var world=host.world
	var level:String=Campaign.p.get("level","1-1")
	var battle:=false
	var final_battle:=false
	if is_instance_valid(world) and world.boss and world.arena:
		battle=world.arena.active and world.boss.hp>0
		final_battle=battle and level=="3-3"
		if was_final_battle and world.boss.hp<=0: finale_hold=3.0
	was_final_battle=final_battle
	finale_hold=maxf(0,finale_hold-delta)
	if finale_hold>0 and host.page not in ["main","map","heroes","settings"]: return "ragnaros"
	if is_instance_valid(world) and host.page in ["play","pause","offer","confirm"]:
		if battle: return "ragnaros" if final_battle else "bosses"
		return region_theme(level)
	return "menu"

func request_theme(id:String) -> void:
	if id.is_empty() or not streams.has(id): return
	if id==current_theme and pending_theme.is_empty(): return
	pending_theme=id
	# Reversing a transition reuses its existing voice/position. Never duplicate.
	for voice in voices:
		if voice.id==id:
			for other in voices: other.target=1.0 if other==voice else 0.0
			current_theme=id
			pending_theme=""
			theme_changed.emit(id)
			return
	for voice in voices:
		if voice.id.is_empty():
			for other in voices: other.target=0.0
			voice.id=id
			voice.target=1.0
			voice.gain=0.0
			voice.player.stream=streams[id]
			voice.player.volume_db=-80
			voice.player.play()
			current_theme=id
			pending_theme=""
			starts[id]=int(starts.get(id,0))+1
			theme_changed.emit(id)
			return
	# Three different requests during a fade: release a voice first, no hard stop.
	for voice in voices: voice.target=0.0

func _process(delta:float) -> void:
	clock+=delta
	if voices.is_empty() or not unlocked: return
	var desired:=desired_theme(delta)
	if desired!=current_theme or not pending_theme.is_empty(): request_theme(desired)
	var quiet:=get_tree().paused or finale_hold>0
	duck=move_toward(duck,0.50 if quiet else 1.0,delta*1.5)
	for voice in voices:
		if voice.id.is_empty(): continue
		voice.gain=move_toward(voice.gain,voice.target,delta/CROSSFADE)
		# Equal-power fade with the soundtrack pre-normalized below game cues.
		voice.player.volume_db=linear_to_db(maxf(0.0001,sqrt(voice.gain)*duck))-3.0
		if voice.gain<=0.0 and voice.target==0.0:
			voice.player.stop()
			voice.id=""

func snapshot() -> Dictionary:
	var active:Array=[]
	for voice in voices:
		if not voice.id.is_empty(): active.append({"id":voice.id,"gain":voice.gain,"target":voice.target,"position":voice.player.get_playback_position(),"playing":voice.player.playing})
	return {"theme":current_theme,"pending":pending_theme,"unlocked":unlocked,"duck":duck,"voices":active,"starts":starts.duplicate(),"clock":clock}

func stop_all() -> void:
	# Explicit teardown for the accelerated acceptance runner and engine shutdown.
	# Normal menus/death/retries use request_theme(), never this method.
	set_process(false)
	for voice in voices:
		voice.player.stop()
		voice.player.stream=null
		voice.id=""
	streams.clear()

func _exit_tree() -> void:
	stop_all()
