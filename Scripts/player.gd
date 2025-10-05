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
var is_bumping: bool = false
var in_blockzone: bool = false

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var player_arms: Node2D = $"Player Arms"

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	player_arms.visible = false
	
func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority(): return
	# Apply gravity with floaty jump feel
	if velocity.y < 0:  # going up
		if not Input.is_action_pressed("jump_1"):
			velocity.y += gravity * low_jump_multiplier * delta
		elif abs(velocity.y) < peak_threshold:
			velocity.y += gravity * peak_gravity_scale * delta
		else:
			velocity.y += gravity * delta * 0.5
	else:  # falling
		velocity.y += gravity * fall_multiplier * delta

	# Handle jump
	if Input.is_action_just_pressed("jump_1") and is_on_floor():
		velocity.y = JumpForce
	
	# Handle movement
	var direction := Input.get_axis("left_1", "right_1")
	
	if is_bumping:
		velocity.x = 0  # lock in place during bump
	elif direction != 0 and not is_hitting:
		velocity.x = move_toward(velocity.x, direction * Speed, Acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, Friction * delta)
	
	# --- Handle attack ---
	if Input.is_action_just_pressed("hit_1") and not is_on_floor() and not is_hitting and not is_bumping:
		is_hitting = true
		player_arms.swing()
		sprite.play("Hit")
	
	# Handle bump - only on ground and not during other actions
	if Input.is_action_pressed("Bump_1") and is_on_floor() and not is_hitting:
		if not is_bumping:
			is_bumping = true
			player_arms.bump()
			sprite.play("Bump")
	else:
		# Release bump when button is let go
		if is_bumping:
			is_bumping = false
			player_arms.stop_bump()  # Use the new stop_bump function
			sprite.play("Idle")

	
	# Cancel hit if you land
	if is_on_floor() and is_hitting:
		is_hitting = false
		player_arms.stop_hit()
		sprite.play("Idle")
		
	# --- Pick animations (if not hitting or bumping) ---
	if not is_bumping and not is_hitting:
		if not is_on_floor():
			if in_blockzone == false:
				sprite.play("Jump")
			elif in_blockzone == true:
				print(in_blockzone)
				sprite.play("Block")
		elif direction != 0:
			sprite.play("Run")
		else:
			sprite.play("Idle")

	# Flip sprite based on direction
	if direction != 0:
		if direction > 0:
			sprite.flip_h = false
		elif direction < 0:
			sprite.flip_h = true
		
		# Always update arm direction when there's input
		player_arms.sprite_direction(direction)

	# Apply movement
	move_and_slide()
