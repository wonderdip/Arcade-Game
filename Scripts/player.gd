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

# Player-specific input suffixes
var input_suffix: String = "_1"
var is_local_mode: bool = false

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var player_arms: Node2D = $"Player Arms"

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	player_arms.visible = false
	
	# Check if we're in network mode or local mode
	is_local_mode = multiplayer.multiplayer_peer == null
	
	if is_local_mode:
		# Local multiplayer mode - use device IDs
		# Player name should be "1" or "2" when spawned locally
		var player_num = name.to_int() if name.is_valid_int() else 1
		input_suffix = "_" + str(player_num)
		print("Local mode: Player ", player_num, " using device ", player_num - 1)
	else:
		# Network multiplayer mode
		var peer_id = name.to_int()
		if multiplayer.get_unique_id() == peer_id:
			if multiplayer.is_server():
				input_suffix = "_1"
				global_position = Vector2(40, 112)
			else:
				input_suffix = "_2"
				global_position = Vector2(216, 112)
	
func _physics_process(delta: float) -> void:
	# In local mode, always process. In network mode, check authority
	if not is_local_mode and !is_multiplayer_authority(): 
		return
	
	# Apply gravity with floaty jump feel
	if velocity.y < 0:
		if not Input.is_action_pressed("jump" + input_suffix):
			velocity.y += gravity * low_jump_multiplier * delta
		elif abs(velocity.y) < peak_threshold:
			velocity.y += gravity * peak_gravity_scale * delta
		else:
			velocity.y += gravity * delta * 0.5
	else:
		velocity.y += gravity * fall_multiplier * delta

	# Handle jump
	if Input.is_action_just_pressed("jump" + input_suffix) and is_on_floor():
		velocity.y = JumpForce
	
	# Handle movement
	var direction := Input.get_axis("left" + input_suffix, "right" + input_suffix)
	
	if is_bumping:
		velocity.x = 0
	elif direction != 0 and not is_hitting:
		velocity.x = move_toward(velocity.x, direction * Speed, Acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, Friction * delta)
	
	# Handle attack
	if Input.is_action_just_pressed("hit" + input_suffix) and not is_on_floor() and not is_hitting and not is_bumping:
		is_hitting = true
		player_arms.swing()
		sprite.play("Hit")
	
	# Handle bump
	if Input.is_action_pressed("Bump" + input_suffix) and is_on_floor() and not is_hitting:
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
