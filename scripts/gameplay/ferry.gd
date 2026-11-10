extends AnimatableBody2D

@export var travel := Vector2(180,0)
@export var period := 5.0
var origin: Vector2
var elapsed := 0.0

func _ready() -> void:
	origin = position

func _physics_process(delta: float) -> void:
	elapsed = fmod(elapsed+delta,period)
	position = origin + travel * (0.5-0.5*cos(TAU*elapsed/period))

func _draw() -> void:
	if has_meta("forest_skin"): return
	draw_rect(Rect2(-64,0,128,16),Color("#8b7558"))
	draw_rect(Rect2(-64,0,128,4),Color("#f7cf83"))
	for x in [-42,-16,12,40]:
		draw_line(Vector2(x,5),Vector2(x-5,15),Color("#dcae73"),2)
