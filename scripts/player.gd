extends CharacterBody2D

const SPEED = 80.0

var last_direction := Vector2.DOWN

func _physics_process(_delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * SPEED

	if input_dir != Vector2.ZERO:
		last_direction = input_dir.normalized()
		# Simple bobbing animation while moving
		$Sprite2D.position.y = sin(Time.get_ticks_msec() * 0.01) * 1.5
	else:
		$Sprite2D.position.y = 0.0

	move_and_slide()
