extends CharacterBody2D

@export var Speed: float = 200.0
@export var JumpForce: float = -220.0
@export var Acceleration: float = 1200.0
@export var Friction: float = 1000.0

@export var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
@export var fall_multiplier: float = 1.5
@export var low_jump_multiplier: float = 1.5
var peak_gravity_scale: float = 0.5   # how floaty the top feels
var peak_threshold: float = 80.0      # how close to 0 velocity to count as "peak"

var is_hitting: bool = false

@onready var sprite: AnimatedSprite2D = $Sprite


func _physics_process(delta: float) -> void:
	# Apply gravity with floaty jump feel
	if velocity.y < 0:  # going up
		if not Input.is_action_pressed("jump"):
			velocity.y += gravity * low_jump_multiplier * delta
		elif abs(velocity.y) < peak_threshold:
			velocity.y += gravity * peak_gravity_scale * delta
		else:
			velocity.y += gravity * delta * 0.5
	else:  # falling
		velocity.y += gravity * fall_multiplier * delta

	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JumpForce

	# Handle movement
	var direction := Input.get_axis("left", "right")

	if direction != 0 and not is_hitting:
		velocity.x = move_toward(velocity.x, direction * Speed, Acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, Friction * delta)

	# --- Handle attack ---
	if Input.is_action_just_pressed("hit") and not is_on_floor() and not is_hitting:
		# Start hit only in the air
		sprite.play("Hit")
		is_hitting = true

	# Cancel hit if you land
	if is_on_floor() and is_hitting:
		is_hitting = false
		sprite.play("Idle")

	# --- Pick animations (if not hitting) ---
	if not is_hitting:
		if not is_on_floor():
			sprite.play("Jump")
		elif direction != 0:
			sprite.play("Run")
		else:
			sprite.play("Idle")

	# Flip sprite
	if direction > 0:
		sprite.flip_h = false
	elif direction < 0:
		sprite.flip_h = true

	# Apply movement
	move_and_slide()
