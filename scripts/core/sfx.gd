extends Node
## Immediate, bounded SFX. No delayed starts, scene-owned players or second settings store.
signal played(id:String,details:Dictionary)
signal suppressed(id:String,reason:String)
const BUS:="Эффекты"
const ROOT:="res://assets/audio/sfx/"
const VOICES:=10
const ORDINARY_LIMIT:=8
const CARRY:=["ui_click","player_death","level_complete","game_over"]
var config:Dictionary={}
var streams:Dictionary={}
var variants:Dictionary={}
var last_variant:Dictionary={}
var voices:Array[Dictionary]=[]
var last:Dictionary={}
var seen:Dictionary={}
var generation:=0
var clock:=0.0
var unlocked:=not OS.has_feature("web")
var random:=RandomNumberGenerator.new()

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	while not Campaign.access_ready: await get_tree().process_frame
	config=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
	random.randomize()
	for id in config:
		streams[id]=load(ROOT+str(config[id].file))
		if config[id].has("variants"):
			variants[id]=[]
			for file in config[id].variants: variants[id].append(load(ROOT+str(file)))
	for i in VOICES:
		var player:=AudioStreamPlayer.new()
		player.bus=BUS
		# Stream playback keeps the same bus DSP/limiter in desktop and Web.
		player.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
		add_child(player)
		voices.append({"player":player,"id":"","priority":0,"until":0.0,"started":0.0,"source":0})
	# Only protection against summed peaks; user volume/mute remains on Campaign's bus.
	var bus:=AudioServer.get_bus_index(BUS)
	var limiter:=AudioEffectHardLimiter.new()
	limiter.ceiling_db=-1.0
	limiter.pre_gain_db=0.0
	limiter.release=0.1
	AudioServer.add_bus_effect(bus,limiter)

func _input(event:InputEvent) -> void:
	if unlocked: return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		unlocked=true
		# There is deliberately no queue to flush after the browser's user gesture.

func _process(delta:float) -> void:
	clock+=delta
	if voices.is_empty(): return
	var muted:=AudioServer.is_bus_mute(AudioServer.get_bus_index(BUS))
	for voice in voices:
		if not voice.id.is_empty() and (clock>=voice.until or muted): stop_voice(voice)

func stop_voice(voice:Dictionary) -> void:
	voice.player.stop()
	voice.id=""
	voice.priority=0

func stop_id(id:String,source:Object=null) -> void:
	for voice in voices:
		if voice.id==id and (source==null or voice.source==source.get_instance_id()): stop_voice(voice)

func new_world(keep_ui:=true) -> void:
	for voice in voices:
		if not keep_ui or voice.id!="ui_click": stop_voice(voice)
	generation+=1
	seen.clear()
	var click_time:float=last.get("ui_click",-1000.0)
	last.clear()
	last.ui_click=click_time

func warp() -> void:
	for voice in voices:
		if voice.id not in ["pipe_transition","ui_click"]: stop_voice(voice)
	generation+=1
	seen.clear()

func page_changed(page:String) -> void:
	if page=="play": return
	var keep:Array=["ui_click"]
	if page=="offer": keep.append("player_death")
	if page in ["result","victory"]: keep.append("level_complete")
	if page=="defeat": keep.append("game_over")
	for voice in voices:
		if voice.id not in keep: stop_voice(voice)

func rejected(id:String,reason:String) -> bool:
	suppressed.emit(id,reason)
	return false

func play(id:String,source:Object,action:Variant=null,extra_db:=0.0) -> bool:
	if not config.has(id): return rejected(id,"unknown")
	if not unlocked: return rejected(id,"locked")
	if get_tree().paused and id not in CARRY: return rejected(id,"paused")
	var bus:=AudioServer.get_bus_index(BUS)
	if AudioServer.is_bus_mute(bus) or AudioServer.get_bus_volume_db(bus)<=-60: return rejected(id,"muted")
	var serial:Variant=Engine.get_process_frames() if id=="ui_click" else Engine.get_physics_frames()
	if action!=null: serial=action
	var source_id:=source.get_instance_id() if is_instance_valid(source) else 0
	var token:="%d/%s/%d/%s"%[generation,id,source_id,str(serial)]
	if seen.has(token): return rejected(id,"duplicate")
	seen[token]=true
	if seen.size()>512: seen.erase(seen.keys()[0])
	var data:Dictionary=config[id]
	if clock-float(last.get(id,-1000.0))<float(data.interval): return rejected(id,"interval")
	var same:=0
	var ordinary:=0
	var available:Dictionary={}
	var victim:Dictionary={}
	var same_oldest:Dictionary={}
	for voice in voices:
		if not voice.id.is_empty() and clock>=voice.until: stop_voice(voice)
		if voice.id.is_empty():
			if available.is_empty(): available=voice
			continue
		if voice.id==id:
			same+=1
			if same_oldest.is_empty() or voice.started<same_oldest.started: same_oldest=voice
		if voice.priority<70: ordinary+=1
		if voice.priority<=int(data.priority) and (victim.is_empty() or voice.priority<victim.priority or (voice.priority==victim.priority and voice.started<victim.started)): victim=voice
	if same>=int(data.voices):
		if int(data.priority)<70: return rejected(id,"per_id_limit")
		# A newly confirmed important pickup replaces its own fading tail, not its cue.
		stop_voice(same_oldest)
		available=same_oldest
	if int(data.priority)<70 and ordinary>=ORDINARY_LIMIT: return rejected(id,"reserved")
	if available.is_empty():
		if victim.is_empty(): return rejected(id,"priority")
		stop_voice(victim)
		available=victim
	var player:AudioStreamPlayer=available.player
	player.stream=streams[id]
	var variant:=-1
	if variants.has(id):
		var choices:Array=[]
		for index in variants[id].size():
			if index!=last_variant.get(id,-1): choices.append(index)
		variant=choices[random.randi_range(0,choices.size()-1)]
		last_variant[id]=variant
		player.stream=variants[id][variant]
	player.volume_db=float(data.volume_db)+extra_db
	player.pitch_scale=random.randf_range(float(data.pitch[0]),float(data.pitch[1]))
	available.id=id
	available.priority=int(data.priority)
	available.started=clock
	available.until=clock+player.stream.get_length()/player.pitch_scale
	available.source=source_id
	last[id]=clock
	player.play()
	played.emit(id,{"generation":generation,"source":source_id,"action":str(serial),"clock":clock,"volume_db":player.volume_db,"pitch":player.pitch_scale,"variant":variant})
	return true
