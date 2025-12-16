extends CharacterBody2D

@export var speed := 200.0
@export var jump_force := 250.0
@export var acceleration := 1200.0
@export var friction := 1000.0
@export var gravity := 980.0
@export var fall_multiplier := 1.5

@export var is_bot := true
@export var left_bound := 128.0  # Stay on right side of net
@export var right_bound := 256.0
@export var reaction_time := 0.15
@export var aim_error := 20.0

# Difficulty settings
@export_enum("Easy", "Normal", "Hard", "Expert") var difficulty := "Normal"

@onready var sprite: AnimatedSprite2D = $BotAnim
@onready var player_arms: Node2D = $"Player Arms"
@onready var ball_range: Area2D = $BallRange
@onready var bump_range: Area2D = $BumpRange

var ball: RigidBody2D
var decision_timer := 0.0
var move_dir := 0.0

var is_hitting := false
var is_bumping := false
var is_setting := false
var is_blocking := false
var in_range: bool
var in_bump_range: bool
var in_set_range: bool
var in_hit_range: bool
var in_blockzone: bool = false

# Enhanced AI state
var predicted_landing_pos: Vector2
var should_jump := false
var action_cooldown := 0.0
var action_hold_timer := 0.0
var current_action := ""
var last_action := ""
var gravity_mult: float = 1.0
var speed_mult: float

var fallbackframe := preload("res://Assets/Characters/Player Sprite Frames/P1.tres")

func _ready() -> void:
	sprite.play("Idle")
	_apply_difficulty_settings()
	load_character()
	
func load_character():
	var char_stat: CharacterStat = null
	
	# If we have a character stat, apply it
	if char_stat != null:
		sprite.sprite_frames = char_stat.sprite_frame
		
		# Apply character stats
		speed = char_stat.Speed * 2.0
		jump_force = char_stat.Jumping * 4.0
		var recv_norm = char_stat.Recieving / 100.0
		var set_norm  = char_stat.Setting / 100.0
		player_arms.ball_control = (recv_norm + set_norm) / 2.0
		
		if char_stat.Hitting < 50:
			player_arms.downward_force = -char_stat.Hitting / 4
			player_arms.hit_force = char_stat.Hitting * 0.6
		else:
			player_arms.downward_force = char_stat.Hitting / 2
			player_arms.hit_force = char_stat.Hitting
	else:
		# Fallback to default P3 frames
		sprite.sprite_frames = fallbackframe
		
func _apply_difficulty_settings() -> void:
	match difficulty:
		"Easy":
			reaction_time = 0.3
			aim_error = 20.0
			speed = 120.0
		"Normal":
			reaction_time = 0.2
			aim_error = 10.0
			speed = 140.0
		"Hard":
			reaction_time = 0.1
			aim_error = 5.0
			speed = 160.0
		"Expert":
			reaction_time = 0.05
			aim_error = 1.0
			speed = 180.0

func _physics_process(delta: float) -> void:
	_find_ball()
	
	if Networkhandler.settings_opened:
		return
			
			
	_update_ai(delta)
	_apply_gravity(delta)
	_apply_movement(delta)
	_handle_action_holding(delta)
	_update_actions()
	_update_animation()
	move_and_slide()
	
	if action_cooldown > 0:
		action_cooldown -= delta
	if action_hold_timer > 0:
		action_hold_timer -= delta

func _find_ball() -> void:
	if ball == null:
		ball = get_tree().get_first_node_in_group("ball")

func _update_ai(delta: float) -> void:
	if not is_bot or ball == null or ball.scored:
		return
		
	if not in_range:
		# Return to center-back position when ball is far
		var defensive_position = (left_bound + right_bound) / 2 + 20
		var distance_to_position = abs(defensive_position - global_position.x)
		if distance_to_position > 5:
			move_dir = sign(defensive_position - global_position.x)
		else:
			move_dir = 0
		should_jump = false
		return
		
	# Don't make new decisions while executing an action
	if action_hold_timer > 0:
		var horiz_distance = abs(ball.global_position.x - global_position.x)
		
		if horiz_distance > 15:
			move_dir = sign(ball.global_position.x - global_position.x)
		else:
			move_dir = 0
		return
		
	decision_timer -= delta
	if decision_timer > 0:
		return

	decision_timer = reaction_time

	# Track ball position
	var horizontal_distance = abs(ball.global_position.x - global_position.x)
	var target_x = ball.global_position.x
	var distance_to_net = abs(ball.global_position.x - 128)
	
	# If ball is close to net and on our side, position closer to net
	if ball.global_position.x > 128 and distance_to_net < 40:
		target_x = 128 + 30
	
	# Add some error based on difficulty
	target_x += randf_range(-aim_error, aim_error)
	target_x = clamp(target_x, left_bound, right_bound)
	
	# Stop moving if we're close enough
	if horizontal_distance < 5:
		move_dir = 0
	else:
		move_dir = sign(target_x - global_position.x)
	
	# Only decide new actions if we're not in cooldown
	if action_cooldown <= 0 and in_range:
		_decide_action()

func _handle_action_holding(_delta: float) -> void:
	if action_hold_timer <= 0:
		if current_action not in ["preparing_hit", "preparing_block"]:
			is_bumping = false
			is_hitting = false
			is_setting = false
			is_blocking = false
			current_action = ""

func _decide_action() -> void:
	var ball_height_diff = global_position.y - ball.global_position.y
	var ball_falling = ball.linear_velocity.y > 0
	var distance_to_net = abs(global_position.x - 128)
	
	# Reset touch counter when ball crosses to opponent's side
	if ball.global_position.x <= 128:
		player_arms.touch_counter = 0
		
	# Reset all actions first
	is_bumping = false
	is_hitting = false
	is_setting = false
	is_blocking = false
	should_jump = false
	current_action = ""
	
	# DECISION PRIORITY (most specific first):
	
	# 1. Very low ball - BUMP
	if is_on_floor() and ball_falling and in_bump_range:
		current_action = "bump"
		is_bumping = true
		should_jump = false
		action_hold_timer = 0.55
		action_cooldown = 0.4
		return
	
	# 2. High ball after 3 touches - HIT
	if in_hit_range and not is_on_floor():
		current_action = "hit"
		is_hitting = true
		action_hold_timer = 0.3
		action_cooldown = 0.6
		return
	
	# 3. Medium ball on ground - SET
	if is_on_floor() and in_set_range:
		current_action = "set"
		is_setting = true
		action_hold_timer = 0.55
		action_cooldown = 0.4
		return
	
	# 4. Ball coming over net - BLOCK
	if in_blockzone and ball.global_position.x < 128:
		if ball.linear_velocity.x > 0:  # Ball coming toward our side
			if is_on_floor():
				should_jump = true
				current_action = "preparing_block"
			else:
				current_action = "block"
				is_blocking = true
				action_hold_timer = 0.3
				action_cooldown = 0.6
			return
	
	# 5. Position for spike near net
	if distance_to_net < 50 and ball_height_diff > -10 and ball.global_position.x > 128 and player_arms.touch_counter >= 3:
		should_jump = true
		return
		
func _apply_gravity(delta: float) -> void:
	
	if is_blocking:
		gravity_mult = 1.3
	else:
		gravity_mult = 1.0

	# Apply gravity with multiplier
	if velocity.y < 0:
		velocity.y += gravity * 0.6 * gravity_mult * delta
	else:
		velocity.y += gravity * fall_multiplier * gravity_mult * delta
		
func _apply_movement(delta: float) -> void:
	# Jump if needed
	if should_jump and is_on_floor():
		velocity.y = -jump_force
		should_jump = false
		
	if is_bumping or is_setting:
		speed_mult = 0.2
	elif is_hitting:
		speed_mult = 0.4
	else:
		speed_mult = 1
	
	# Move horizontally
	if move_dir != 0:
		velocity.x = move_toward(
			velocity.x,
			move_dir * speed * speed_mult,
			acceleration * delta
		)
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)

func _update_actions() -> void:
	if is_bumping:
		player_arms.action("bump")
		sprite.play("Bump")
	elif is_hitting:
		player_arms.action("hit")
		sprite.play("Hit")
	elif is_setting:
		player_arms.action("set")
		sprite.play("Set")
	elif is_blocking:
		player_arms.action("block")
		sprite.play("Block")
	else:
		# Release all actions
		player_arms.action("bump", false)
		player_arms.action("hit", false)
		player_arms.action("set", false)
		player_arms.action("block", false)

func _update_animation() -> void:
	
	if in_blockzone or not is_on_floor():
		sprite.flip_h = true
		player_arms.sprite_direction(-1)
	elif move_dir != 0:
		# Only change direction when on ground and moving
		sprite.flip_h = move_dir < 0
		player_arms.sprite_direction(move_dir)
	
	# Handle animations
	if not is_bumping and not is_hitting and not is_setting:
		if not is_on_floor():
			if in_blockzone:
				sprite.play("Block")
			else:
				sprite.play("Jump")
		elif move_dir != 0:
			sprite.play("Run")
		else:
			sprite.play("Idle")

# Area detection functions
func _on_ball_range_body_entered(body: Node2D) -> void:
	if body is RigidBody2D and body == get_tree().get_first_node_in_group("ball"):
		in_range = true

func _on_ball_range_body_exited(body: Node2D) -> void:
	if body is RigidBody2D and body == get_tree().get_first_node_in_group("ball"):
		in_range = false

func _on_bump_range_body_entered(body: Node2D) -> void:
	if body is RigidBody2D and body == get_tree().get_first_node_in_group("ball"):
		in_bump_range = true

func _on_bump_range_body_exited(body: Node2D) -> void:
	if body is RigidBody2D and body == get_tree().get_first_node_in_group("ball"):
		in_bump_range = false

func _on_set_range_body_entered(body: Node2D) -> void:
	if body is RigidBody2D and body == get_tree().get_first_node_in_group("ball"):
		in_set_range = true

func _on_set_range_body_exited(body: Node2D) -> void:
	if body is RigidBody2D and body == get_tree().get_first_node_in_group("ball"):
		in_set_range = false

func _on_hit_range_body_entered(body: Node2D) -> void:
	if body is RigidBody2D and body == get_tree().get_first_node_in_group("ball"):
		in_hit_range = true

func _on_hit_range_body_exited(body: Node2D) -> void:
	if body is RigidBody2D and body == get_tree().get_first_node_in_group("ball"):
		in_hit_range = false
