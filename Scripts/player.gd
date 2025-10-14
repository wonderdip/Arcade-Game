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
var block_gravity_mult: float
var speed_mult: float

var is_hitting: bool = false
var is_bumping: bool = false
var is_setting: bool = false
var is_blocking: bool = false
var in_blockzone: bool = false

# Player identification
var player_number: int = -1  # Set this when spawning
var device_id: int = -1      # Set by InputManager, optional for controller
var input_type: String = ""  # "keyboard" or "controller"
var is_local_mode: bool = false

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var player_arms: Node2D = $"Player Arms"

func _enter_tree() -> void:
	is_local_mode = Networkhandler.is_local
	if !is_local_mode:
		set_multiplayer_authority(name.to_int())

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
	if is_local_mode and player_number < 0:
		return  # Not setup yet

	if not is_local_mode and !is_multiplayer_authority(): 
		return

	# --- Input Handling ---
	var direction: float
	var jump_pressed: bool
	var jump_just_pressed: bool
	var hit_just_pressed: bool
	var bump_pressed: bool
	var set_pressed: bool
	
	if is_local_mode:
		direction = InputManager.get_axis(player_number, "left", "right")
		jump_pressed = InputManager.is_action_pressed(player_number, "jump")
		jump_just_pressed = InputManager.is_action_just_pressed(player_number, "jump")
		hit_just_pressed = InputManager.is_action_just_pressed(player_number, "hit")
		bump_pressed = InputManager.is_action_pressed(player_number, "bump")
		set_pressed = InputManager.is_action_pressed(player_number, "set")
	else:
		direction = Input.get_axis("left", "right")
		jump_pressed = Input.is_action_pressed("jump")
		jump_just_pressed = Input.is_action_just_pressed("jump")
		hit_just_pressed = Input.is_action_just_pressed("hit")
		bump_pressed = Input.is_action_pressed("bump")
		set_pressed = Input.is_action_pressed("set")

	# --- Movement and Actions ---
	# Apply gravity with floaty jump feel
	if is_blocking:
		block_gravity_mult = 1.3  # increase this for lower jumps
	else:
		block_gravity_mult = 1

	if velocity.y < 0:
		if not jump_pressed:
			velocity.y += gravity * low_jump_multiplier * block_gravity_mult * delta
		elif abs(velocity.y) < peak_threshold:
			velocity.y += gravity * peak_gravity_scale * block_gravity_mult * delta
		else:
			velocity.y += gravity * 0.5 * block_gravity_mult * delta
	else:
		velocity.y += gravity * fall_multiplier * block_gravity_mult * delta


	# Handle jump
	if jump_just_pressed and is_on_floor():
		velocity.y = JumpForce
	
	if is_bumping or is_setting:
		speed_mult = 0.2
	elif is_hitting:
		speed_mult = 0.4
	else:
		speed_mult = 1
	
	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * Speed * speed_mult, Acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, Friction * delta)

	# Handle attack
	if hit_just_pressed and not is_on_floor() and not is_hitting and not is_bumping:
		is_hitting = true
		player_arms.swing()
		sprite.play("Hit")

	# Handle bump
	if bump_pressed and is_on_floor() and not is_hitting and not is_setting:
		if not is_bumping:
			is_bumping = true
			player_arms.bump()
			sprite.play("Bump")
	else:
		if is_bumping:
			is_bumping = false
			player_arms.stop_bump()
			sprite.play("Idle")
			
	if set_pressed and is_on_floor() and not is_hitting and not is_bumping:
		is_setting = true
		sprite.play("Set")
		player_arms.setting()
	else:
		if is_setting:
			is_setting = false
			sprite.play("Idle")
			player_arms.stop_setting()
		
	if in_blockzone and not is_on_floor():
		is_blocking = true
		player_arms.block()
	elif (is_on_floor() or not in_blockzone) and is_blocking:
		is_blocking = false
		player_arms.stop_block()
		
	# Cancel hit if you land
	if is_on_floor() and is_hitting:
		is_hitting = false
		player_arms.stop_hit()
		sprite.play("Idle")

	# Pick animations
	if not is_bumping and not is_hitting and not is_setting:
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

func setup_local_player(dev_id: int, p_number: int, inp_type: String):
	player_number = p_number
	device_id = dev_id
	input_type = inp_type
	print("Player %d setup with device %d (%s)" % [player_number, device_id, input_type])
	# Register with InputManager if local mode
	InputManager.register_player(player_number, input_type, device_id)
