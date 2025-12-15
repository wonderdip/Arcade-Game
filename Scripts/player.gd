extends CharacterBody2D

@export var Speed: float = 200.0
@export var JumpForce: float = 220.0
@export var Acceleration: float = 1200.0
@export var Friction: float = 1000.0
@export var gravity: float = 980
@export var fall_multiplier: float = 1.5
@export var low_jump_multiplier: float = 1.5

@export_enum("P1", "P2", "P3") var character: String = "P1"

var fallbackframe := preload("res://Assets/Characters/Player Sprite Frames/P1.tres")

var peak_gravity_scale: float = 0.5
var peak_threshold: float = 80.0
var gravity_mult: float
var speed_mult: float

var is_hitting: bool = false
var is_bumping: bool = false
var is_setting: bool = false
var is_blocking: bool = false
var in_blockzone: bool = false

# Player identification
@export var player_number: int = -1  # exported so replication can see it at spawn
var device_id: int = -1
var input_type: String = ""  # "keyboard" or "controller"

var is_local_mode: bool = false
var is_solo_mode: bool = false
var settings_opened: bool = false

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var player_arms: Node2D = $"Player Arms"

func _enter_tree() -> void:
	is_local_mode = Networkhandler.is_local
	is_solo_mode = Networkhandler.is_solo
	# In network mode, each peer claims authority for their own player
	if not is_local_mode and not is_solo_mode:
		await get_tree().process_frame
		
		# The node name is the peer ID (set by spawner)
		var peer_id: int = int(name)
		
		# Set authority to match the peer ID in the name
		if get_multiplayer_authority() != peer_id:
			set_multiplayer_authority(peer_id)

func _ready() -> void:
	# Load character based on mode
	load_character()
	
	# Just verify we have proper authority for input
	if !is_local_mode and !is_solo_mode:
		if get_multiplayer_authority() == multiplayer.get_unique_id():
			print("This player instance is controlled locally")
		
		print("[Player._ready] name=", name,
		  " player_number=", player_number,
		  " authority=", get_multiplayer_authority(),
		  " unique_id=", multiplayer.get_unique_id(),
		  " is_server=", multiplayer.is_server(),
		  " pos=", global_position)

func load_character():
	var char_stat: CharacterStat = null
	
	if is_solo_mode:
		# Solo mode - use the single character selection
		char_stat = PlayerManager.character
	elif is_local_mode:
		# Local mode - use player-specific character
		char_stat = PlayerManager.get_player_character(player_number)
	
	# If we have a character stat, apply it
	if char_stat != null:
		sprite.sprite_frames = char_stat.sprite_frame
		
		# Apply character stats
		Speed = char_stat.Speed * 2.0
		JumpForce = char_stat.Jumping * 4.0
		var recv_norm = char_stat.Recieving / 100.0
		var set_norm  = char_stat.Setting / 100.0
		player_arms.ball_control = (recv_norm + set_norm) / 2.0
		
		if char_stat.Hitting < 50:
			player_arms.downward_force = -char_stat.Hitting / 4
			player_arms.hit_force = char_stat.Hitting * 0.6
		else:
			player_arms.downward_force = char_stat.Hitting / 2
			player_arms.hit_force = char_stat.Hitting
		print("Loaded character %s for player %d" % [char_stat.name, player_number])
	else:
		# Fallback to default P3 frames
		sprite.sprite_frames = fallbackframe
		print("Warning: No character assigned for player %d, using default" % player_number)
		
func _physics_process(delta: float) -> void:
	# Freeze movement if settings menu is open globally
	if Networkhandler.settings_opened:
		return
		
	if is_local_mode:
		if player_number < 0:
			return  # Not setup yet
	elif !is_solo_mode:
		# In network mode, only process if we have authority
		if not is_multiplayer_authority():
			return
	
	# --- Input Handling ---
	var direction: float
	var jump_just_pressed: bool
	var hit_just_pressed: bool
	var bump_pressed: bool
	var set_pressed: bool
	
	if is_local_mode:
		# Local mode uses InputManager
		direction = InputManager.get_axis(player_number, "left", "right")
		jump_just_pressed = InputManager.is_action_just_pressed(player_number, "jump")
		hit_just_pressed = InputManager.is_action_just_pressed(player_number, "hit")
		bump_pressed = InputManager.is_action_pressed(player_number, "bump")
		set_pressed = InputManager.is_action_pressed(player_number, "set")
	else:
		# Network mode uses standard Input (each client controls their own player)
		var x_axis: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
		var y_axis: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
		var angle: float = Vector2(x_axis, y_axis).angle()
		
		direction = Input.get_axis("left", "right")
		hit_just_pressed = Input.is_action_just_pressed("hit")
		bump_pressed = Input.is_action_pressed("bump")
		set_pressed = Input.is_action_pressed("set")
		
		# Jump with controller or keyboard
		jump_just_pressed = false
		if y_axis < -0.4 and abs(angle + PI/2) < deg_to_rad(60):
			jump_just_pressed = true
		elif Input.is_action_just_pressed("jump"):
			jump_just_pressed = true
	
	animations(direction)
	
	if is_blocking:
		gravity_mult = 1.3
	else:
		gravity_mult = 1

	# Apply gravity
	if velocity.y < 0:
		velocity.y += gravity * 0.6 * gravity_mult * delta
	else:
		velocity.y += gravity * fall_multiplier * gravity_mult * delta

	# Handle jump
	if jump_just_pressed and is_on_floor():
		velocity.y = -JumpForce
		AudioManager.play_sound_from_library("jump")
	
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
		player_arms.action("hit")
		sprite.play("Hit")

	# Handle bump
	if bump_pressed and is_on_floor() and not is_hitting and not is_setting:
		if not is_bumping:
			is_bumping = true
			player_arms.action("bump")
			sprite.play("Bump")
			
	else:
		if is_bumping:
			is_bumping = false 
			player_arms.action("bump", false)
			sprite.play("Idle")
			
	if set_pressed and not is_hitting and not is_bumping:
		is_setting = true
		sprite.play("Set")
		player_arms.action("set")
	else:
		if is_setting:
			is_setting = false
			sprite.play("Idle")
			player_arms.action("set", false)
		
	if in_blockzone and not is_on_floor() and not is_blocking:
		is_blocking = true
		player_arms.action("block")
	elif (is_on_floor() or not in_blockzone) and is_blocking:
		is_blocking = false
		player_arms.action("block", false)
		
	# Cancel hit if you land
	if is_on_floor() and is_hitting:
		is_hitting = false
		player_arms.action("hit", false)
		sprite.play("Idle")
		
func animations(direction):
	
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
	# Load character after player number is set
	load_character()
