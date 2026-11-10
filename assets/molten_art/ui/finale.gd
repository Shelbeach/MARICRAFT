extends Control
signal map_requested
signal replay_requested
var presentation="campaign"
var stats:Dictionary={}
var base:String
func _ready():
	base=get_script().resource_path.get_base_dir().get_base_dir();theme=load("res://assets/faction_art/maricraft_p06.theme.tres");size=Vector2(960,540);build()
func present(kind:String,results:Dictionary):
	presentation=kind;stats=results
	if is_node_ready():build()
func picture(path:String,rect:Rect2):
	var t=TextureRect.new();t.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;t.texture=load(base+"/"+path);t.position=rect.position;t.size=rect.size;t.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;t.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;t.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(t)
func label(value:String,rect:Rect2,size_px:int,heading=false):
	var l=Label.new();l.text=value;l.position=rect.position;l.size=rect.size;l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;l.add_theme_font_size_override("font_size",size_px)
	if heading:l.add_theme_font_override("font",load("res://assets/ui_art/fonts/Alegreya-ExtraBold.ttf"))
	add_child(l)
func build():
	for child in get_children():remove_child(child);child.queue_free()
	picture("ui/campaign_finale.png",Rect2(0,0,960,540))
	var p=Panel.new();p.position=Vector2(190,66);p.size=Vector2(580,426);add_child(p)
	picture("ui/"+("campaign_crest" if presentation=="results" else "victory_trophy")+".png",Rect2(405,52,150,150))
	var title={"victory":"Рагнарос повержен!","campaign":"Кампания завершена!","results":"Ваше приключение"}.get(presentation,"Кампания завершена!")
	label(title,Rect2(210,202,540,48),34,true)
	label("Три земли пройдены. Впереди — новые рекорды.",Rect2(210,253,540,32),21)
	var values="Звёзды   %s     Монеты   %s"%[str(stats.get("stars","—")),str(stats.get("coins","—"))]
	label(values,Rect2(230,306,500,34),25)
	label("Время: %s   ·   Очки: %s"%[str(stats.get("time","—")),str(stats.get("score","—"))],Rect2(230,349,500,30),22)
	label("Общий рекорд: %s"%str(stats.get("record","—")),Rect2(230,380,500,27),20)
	for i in range(2):
		var b=Button.new();b.position=Vector2(230+i*260,418);b.size=Vector2(240,48);b.text="На карту мира" if i==0 else "Повторить 3-3";add_child(b)
		if i==0:b.pressed.connect(func():map_requested.emit())
		else:b.pressed.connect(func():replay_requested.emit())
