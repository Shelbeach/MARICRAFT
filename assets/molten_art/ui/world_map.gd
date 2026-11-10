extends Control
## Presentation only; inject real Campaign data with set_progress().
signal level_selected(level_id:String)
signal start_requested(level_id:String)
const POINTS=[Vector2(96,309),Vector2(215,239),Vector2(299,325),Vector2(393,277),Vector2(490,206),Vector2(590,314),Vector2(686,255),Vector2(787,325),Vector2(869,203)]
const TITLES=["Элвиннский лес","Дуротар","Огненные Недра"]
var progress_data:Array=[]
var selected_id=""
var free_replay=false
var buttons:Array[Button]=[]
var stars:Array=[]
var rings:Array[Panel]=[]
var info:Label
var mode_label:Label
var start_button:Button
var base:String
func _ready():
	base=get_script().resource_path.get_base_dir().get_base_dir()
	theme=load("res://assets/faction_art/maricraft_p06.theme.tres")
	custom_minimum_size=Vector2(960,540);size=Vector2(960,540)
	var bg=TextureRect.new();bg.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;bg.texture=load(base+"/ui/world_map_base.png");bg.position=Vector2.ZERO;bg.size=size;bg.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(bg)
	var heading=add_label("Кампания",Vector2(180,12),Vector2(600,44),34,true)
	heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	mode_label=add_label("",Vector2(280,56),Vector2(400,28),18)
	mode_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	for i in range(9):
		var b=Button.new();b.name="Level_%d-%d"%[i/3+1,i%3+1];b.position=POINTS[i]-Vector2(28,28);b.size=Vector2(56,56);b.focus_mode=Control.FOCUS_ALL;add_child(b);buttons.append(b)
		b.pressed.connect(select_level.bind(i));b.focus_entered.connect(focus_level.bind(i))
		var ring=Panel.new();ring.position=Vector2(-4,-4);ring.size=Vector2(64,64);ring.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var style=StyleBoxFlat.new();style.bg_color=Color(1,.75,.15,.08);style.border_color=Color("#fff0aa");style.set_border_width_all(3);style.set_corner_radius_all(30);ring.add_theme_stylebox_override("panel",style);b.add_child(ring);rings.append(ring)
		var num=Label.new();num.text="%d-%d"%[i/3+1,i%3+1];num.position=Vector2(0,11);num.size=Vector2(56,32);num.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;num.add_theme_font_size_override("font_size",22);num.add_theme_color_override("font_color",Color.WHITE);num.add_theme_constant_override("outline_size",5);num.add_theme_color_override("font_outline_color",Color("#171a27"));num.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(num)
		var ss=[]
		for j in range(3):
			var s=TextureRect.new();s.position=Vector2(1+j*18,51);s.size=Vector2(18,18);s.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;s.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(s);ss.append(s)
		stars.append(ss)
	for i in range(3):
		var region_label=add_label(TITLES[i],Vector2(24+i*310,404),Vector2(292,30),24,true)
		region_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var panel=Panel.new();panel.position=Vector2(20,450);panel.size=Vector2(920,72);add_child(panel)
	info=add_label("Выберите доступную точку",Vector2(42,464),Vector2(590,42),22)
	start_button=Button.new();start_button.name="MapStart";start_button.text="Выбрать уровень";start_button.position=Vector2(680,465);start_button.size=Vector2(240,42);start_button.pressed.connect(func():start_requested.emit(selected_id));add_child(start_button)
	refresh()
func add_label(value:String,pos:Vector2,box:Vector2,fs:int,heading=false)->Label:
	var l=Label.new();l.text=value;l.position=pos;l.size=box;l.add_theme_font_size_override("font_size",fs);l.add_theme_color_override("font_color",Color("#f7e5b7"));l.add_theme_constant_override("outline_size",4);l.add_theme_color_override("font_outline_color",Color("#28202c"));l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if heading:l.add_theme_font_override("font",load("res://assets/ui_art/fonts/Alegreya-ExtraBold.ttf"))
	add_child(l);return l
func set_progress(data:Array,selection:String="",replay:bool=false):
	progress_data=data;selected_id=selection;free_replay=replay
	if is_node_ready():refresh()
func state_at(i:int)->Dictionary:
	return progress_data[i] if i<progress_data.size() else {"id":"%d-%d"%[i/3+1,i%3+1],"state":"locked","stars":0}
func round_style(fill:Color,border:Color,width=3)->StyleBoxFlat:
	var s=StyleBoxFlat.new();s.bg_color=fill;s.border_color=border;s.set_border_width_all(width);s.set_corner_radius_all(28);s.set_content_margin_all(0);return s
func refresh():
	var selected_index=-1
	for i in range(9):
		var data=state_at(i);var state=str(data.get("state","locked"));var id=str(data.get("id",""))
		var fill=Color({"locked":"#48434e","available":"#285261","current":"#725020","completed":"#315f43"}.get(state,"#48434e"))
		var border=Color("#ffdc8c") if state=="current" else Color("#c4a263")
		buttons[i].add_theme_stylebox_override("normal",round_style(fill,border))
		buttons[i].add_theme_stylebox_override("hover",round_style(fill.lightened(.16),Color("#fff1b6")))
		buttons[i].add_theme_stylebox_override("pressed",round_style(fill.darkened(.2),border))
		buttons[i].add_theme_stylebox_override("disabled",round_style(fill.darkened(.08),Color("#8b7c67")))
		buttons[i].add_theme_stylebox_override("focus",round_style(Color(0,0,0,0),Color("#fff1b6"),2))
		buttons[i].disabled=not free_replay and state!="current"
		if id==selected_id and not buttons[i].disabled:selected_index=i
		buttons[i].modulate=Color(.65,.68,.75) if state=="locked" else Color.WHITE
		rings[i].visible=id==selected_id
		for j in range(3):stars[i][j].texture=load("res://assets/ui_art/icons/star_"+("on" if j<int(data.get("stars",0)) else "off")+".png")
	mode_label.text="Свободное прохождение" if free_replay else "Девять испытаний · один путь"
	start_button.disabled=selected_index<0
	info.text="Уровень "+selected_id+"  ·  "+TITLES[selected_index/3] if selected_index>=0 else "Выберите доступную точку"
func select_level(i:int):
	if buttons[i].disabled:return
	selected_id=str(state_at(i).get("id",""));refresh();level_selected.emit(selected_id)
func focus_level(i:int):
	for j in range(rings.size()):rings[j].visible=j==i or str(state_at(j).get("id",""))==selected_id
