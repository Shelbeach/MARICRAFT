extends Control
## Ratio only. Real HP remains in the existing boss/state layer.
var ratio=1.0
var fill:TextureRect
var clip:Control
func _ready():
	var base=get_script().resource_path.get_base_dir().get_base_dir()
	custom_minimum_size=Vector2(376,86)
	var portrait=TextureRect.new();portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.texture=load(base+"/ui/boss_portrait.png");portrait.position=Vector2(0,10);portrait.size=Vector2(64,64);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;add_child(portrait)
	var frame=TextureRect.new();frame.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;frame.texture=load(base+"/ui/boss_health_frame.png");frame.position=Vector2(64,0);frame.size=Vector2(300,86);frame.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;add_child(frame)
	clip=Control.new();clip.position=Vector2(109,34);clip.size=Vector2(210*ratio,18);clip.clip_contents=true;add_child(clip)
	fill=TextureRect.new();fill.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;fill.texture=load(base+"/ui/boss_health_fill.png");fill.size=Vector2(210,18);fill.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;clip.add_child(fill)
	var text=Label.new();text.text="Рагнарос";text.position=Vector2(89,4);text.size=Vector2(250,26);text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;text.add_theme_font_override("font",load("res://assets/ui_art/fonts/Alegreya-ExtraBold.ttf"));text.add_theme_font_size_override("font_size",20);add_child(text)
func set_ratio(value:float):
	ratio=clampf(value,0,1)
	if clip:clip.size.x=210*ratio
