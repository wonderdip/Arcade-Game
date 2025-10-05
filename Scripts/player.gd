extends CharacterBody2D

@export var Speed: float = 200.0
@export var JumpForce: float = -220.0
@export var Acceleration: float = 1200.0
@export var Friction: float = 1000.0

@export var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
@export var fall_multiplier: float = 1.5
@export var low_jump_multiplier: float = 1.5
var peak_gravity_scale: float = 0.5
var peak_threshold: float = 80.0

var is_hitting: bool = false
var is_bumping: bool = false
var in_blockzone: bool = false

# Device-based input for local multiplayer
var device_id: int = -1
var player_number: int = -1
var is_local_mode: bool = false

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var player_arms: Node2D = $"Player Arms"

func _enter_tree() -> void:
	is_local_mode = Networkhandler.is_local
	if !is_local_mode:
		set_multiplayer_authority(name.to_int())

func setup_local_player(dev_id: int, p_number: int):
	device_id = dev_id
	player_number = p_number
	print("Player %d setup with device %d" % [player_number, device_id])

func _ready() -> void:
	player_arms.visible = false
	
	if !is_local_mode:
		# Network multiplayer mode
		var peer_id = name.to_int()
		if multiplayer.get_unique_id() == peer_id:
			if multiplayer.is_server():
				global_position = Vector2(40, 112)
			else:
				global_position = Vector2(216, 112)
	
func _physics_process(delta: float) -> void:
	# In local mode, check device_id. In network mode, check authority
	if is_local_mode and device_id < 0:
		return  # Not setup yet
	
	if not is_local_mode and !is_multiplayer_authority(): 
		return
	
	# Apply gravity with floaty jump feel
	if velocity.y < 0:
		if not _is_action_pressed("jump"):
			velocity.y += gravity * low_jump_multiplier * delta
		elif abs(velocity.y) < peak_threshold:
			velocity.y += gravity * peak_gravity_scale * delta
		else:
			velocity.y += gravity * delta * 0.5
	else:
		velocity.y += gravity * fall_multiplier * delta

	# Handle jump
	if _is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JumpForce
	
	# Handle movement
	var direction := _get_axis("left", "right")
	
	if is_bumping:
		velocity.x = 0
	elif direction != 0 and not is_hitting:
		velocity.x = move_toward(velocity.x, direction * Speed, Acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, Friction * delta)
	
	# Handle attack
	if _is_action_just_pressed("hit") and not is_on_floor() and not is_hitting and not is_bumping:
		is_hitting = true
		player_arms.swing()
		sprite.play("Hit")
	
	# Handle bump
	if _is_action_pressed("Bump") and is_on_floor() and not is_hitting:
		if not is_bumping:
			is_bumping = true
			player_arms.bump()
			sprite.play("Bump")
	else:
		if is_bumping:
			is_bumping = false
			player_arms.stop_bump()
			sprite.play("Idle")
	
	# Cancel hit if you land
	if is_on_floor() and is_hitting:
		is_hitting = false
		player_arms.stop_hit()
		sprite.play("Idle")
		
	# Pick animations
	if not is_bumping and not is_hitting:
		if not is_on_floor():
			if in_blockzone == false:
				sprite.play("Jump")
			elif in_blockzone == true:
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
		player_arms.sprite_direction(direction)

	move_and_slide()

# Helper functions for device-specific input
func _is_action_pressed(action: String) -> bool:
	if is_local_mode:
		return Input.is_action_pressed(action, device_id)
	else:
		# Network mode - use suffix-based inputs
		var suffix = "_1" if multiplayer.is_server() else "_2"
		return Input.is_action_pressed(action + suffix)

func _is_action_just_pressed(action: String) -> bool:
	if is_local_mode:
		return Input.is_action_just_pressed(action, device_id)
	else:
		var suffix = "_1" if multiplayer.is_server() else "_2"
		return Input.is_action_just_pressed(action + suffix)

func _get_axis(negative: String, positive: String) -> float:
	if is_local_mode:
		return Input.get_action_strength(positive, device_id) - Input.get_action_strength(negative, device_id)
	else:
		var suffix = "_1" if multiplayer.is_server() else "_2"
		return Input.get_axis(negative + suffix, positive + suffix)
