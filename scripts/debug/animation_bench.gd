extends Control
const Art:=preload("res://scripts/visual/art_library.gd")
const Sprite:=preload("res://scripts/visual/art_sprite.gd")
const UI:=preload("res://scripts/core/ui_kit.gd")
var models:Array=[]
var model_index:=0
var clip_index:=0
var clips:PackedStringArray
var playing:=true
var speed:=0.5
var zoom:=2.0
var direction:=1
var guides=preload("res://scripts/debug/animation_guides.gd").new()
var corrected:=Sprite.new()
var original:=Sprite.new()
var model_list:=OptionButton.new()
var clip_list:=OptionButton.new()
var status:Label
var note:Label
var body_size:=Vector2(24,32)
var previous_pause:=false
var closed:Callable

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	Art.initialize()
	models=Art.actors.keys()
	UI.box(self,0,0,960,540,Color("#15242a"))
	UI.label(self,"АНИМАЦИИ · исходник и игровая калибровка",24,15,820,36,24)
	UI.place(model_list,self,24,66,225,38)
	for id in models: model_list.add_item(id)
	model_list.item_selected.connect(select_model)
	UI.place(clip_list,self,267,66,224,38)
	clip_list.item_selected.connect(select_clip)
	UI.button(self,"Закрыть",finish,813,17,125,35)
	UI.button(self,"Стоп / пуск",toggle,510,66,140,38)
	UI.button(self,"− кадр",step.bind(-1),665,66,125,38)
	UI.button(self,"+ кадр",step.bind(1),804,66,125,38)
	UI.button(self,"Скорость",cycle_speed,24,116,170,36)
	UI.button(self,"Масштаб 1× / 2×",cycle_zoom,210,116,220,36)
	UI.button(self,"Развернуть",flip,448,116,175,36)
	UI.label(self,"ИСХОДНЫЕ КАДРЫ",92,177,320,30,18)
	UI.label(self,"ПОПРАВКИ В ИГРЕ",565,177,340,30,18)
	add_child(original)
	add_child(corrected)
	guides.bench=self
	add_child(guides)
	original.corrected=false
	status=UI.label(self,"",24,471,920,32,17)
	note=UI.label(self,"Жёлтый крест: опора · бирюзовый контур: коллизия · линия: пол",24,508,925,24,15,UI.MUTED)
	select_model(0)

func select_model(index:int) -> void:
	model_index=index
	model_list.select(index)
	var id:String=models[index]
	original.set_actor(id)
	corrected.set_actor(id)
	clips=corrected.sprite.sprite_frames.get_animation_names()
	clip_list.clear()
	for clip in clips: clip_list.add_item(clip)
	# Read the actual actor scenes; the hero dimensions are also verified in runtime tests.
	var scene:PackedScene=load("res://scenes/actors/forest_player.tscn" if "_" in id else ("res://scenes/enemies/murloc.tscn" if id=="murloc" else "res://scenes/enemies/boss.tscn"))
	var actor=scene.instantiate()
	body_size=actor.get_node("Hitbox").shape.size
	if "_" in id and not id.ends_with("small"): body_size.y=64
	actor.free()
	var preferred:=clips.find("idle")
	select_clip(maxi(0,preferred))

func select_clip(index:int) -> void:
	clip_index=index
	clip_list.select(index)
	original.sprite.stop()
	corrected.sprite.stop()
	original.play(clips[index])
	corrected.play(clips[index])
	original.sprite.frame=0
	corrected.sprite.frame=0
	playing=true

func toggle() -> void:
	playing=not playing
	if playing and not corrected.sprite.is_playing():
		original.play(clips[clip_index],0.0,true)
		corrected.play(clips[clip_index],0.0,true)

func step(amount:int) -> void:
	playing=false
	var count:=corrected.sprite.sprite_frames.get_frame_count(clips[clip_index])
	var frame:=posmod(corrected.sprite.frame+amount,count)
	original.sprite.frame=frame
	corrected.sprite.frame=frame

func cycle_speed() -> void: speed=1.0 if speed==0.5 else (0.25 if speed==1.0 else 0.5)
func cycle_zoom() -> void: zoom=1.0 if zoom==2.0 else 2.0
func flip() -> void: direction=-direction

func _process(_delta:float) -> void:
	for actor in [original,corrected]:
		actor.scale=Vector2(direction*actor.source_faces*zoom,zoom)
		actor.sprite.speed_scale=speed if playing else 0.0
	actor_positions()
	status.text="%s / %s · кадр %d / %d · %.2f× скорость · %.0f× размер · тело %s"%[models[model_index],clips[clip_index],corrected.sprite.frame+1,corrected.sprite.sprite_frames.get_frame_count(clips[clip_index]),speed,zoom,body_size]
	guides.queue_redraw()

func actor_positions() -> void:
	original.position=Vector2(245,441)
	corrected.position=Vector2(715,441)

func _draw() -> void:
	for x in [245,715]:
		draw_line(Vector2(x-205,441),Vector2(x+205,441),Color("#90ada7"),1)
		draw_rect(Rect2(Vector2(x,441)-Vector2(body_size.x/2,body_size.y)*zoom,body_size*zoom),Color("#68e5d4"),false,1)
		draw_line(Vector2(x-7,441),Vector2(x+7,441),Color("#ffd381"),2)
		draw_line(Vector2(x,434),Vector2(x,448),Color("#ffd381"),2)

func finish() -> void:
	if closed.is_valid(): closed.call()
	queue_free()
