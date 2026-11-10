extends CharacterBody2D

const SPEED := 160.0
const GRAVITY := 960.0
const JUMP_SPEED := 360.0

func _physics_process(delta: float) -> void:
	velocity.x = Input.get_axis("move_left", "move_right") * SPEED
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 480.0)
	elif Input.is_action_just_pressed("jump"):
		velocity.y = -JUMP_SPEED
	move_and_slide()
