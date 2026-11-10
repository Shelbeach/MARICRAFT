extends Node2D
const Sprite:=preload("res://scripts/visual/location_sprite.gd")
var library
var strike
var art:=Sprite.new()

func _ready() -> void:
	strike=get_parent()
	art.library=library
	add_child(art)
	z_index=3
	_process(0)

func _process(_delta:float) -> void:
	var stem:String=["fissure","wax","rock"][strike.kind]
	if strike.kind==strike.Kind.ROCK and strike.half_width<40: stem="rock_second"
	var active:bool=strike.age>=strike.warning
	var progress:float=(strike.age-strike.warning)/strike.duration if active else strike.age/strike.warning
	art.visible=strike.age<strike.warning+strike.duration
	art.sample(stem+("_active" if active else "_warning"),progress)

