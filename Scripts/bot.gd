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
var action_hold_timer := 0.0  # New: hold actions longer
var current_action := ""  # Track what action we're doing
var last_action := ""


func _ready() -> void:
	sprite.play("Idle")
	_apply_difficulty_settings()

func _apply_difficulty_settings() -> void:
	match difficulty:
		"Easy":
			reaction_time = 0.3
			aim_error = 40.0
			speed = 120.0
		"Normal":
			reaction_time = 0.2
			aim_error = 25.0
			speed = 140.0
		"Hard":
			reaction_time = 0.1
			aim_error = 15.0
			speed = 160.0
		"Expert":
			reaction_time = 0.005
			aim_error = 5.0
			speed = 180.0

func _physics_process(delta: float) -> void:
	if Networkhandler.settings_opened:
		return

	_find_ball()
	_update_ai(delta)
	_apply_gravity(delta)
	_apply_movement(delta)
	_handle_action_holding(delta)  # New: manage action timing
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
	if not is_bot or ball == null:
		return
	if not in_range:
		# Return to center-back position when ball is far
		var defensive_position = (left_bound + right_bound) / 2 + 20  # Slightly back from center
		var distance_to_position = abs(defensive_position - global_position.x)
		if distance_to_position > 5:
			move_dir = sign(defensive_position - global_position.x)
		else:
			move_dir = 0
		should_jump = false
		return
		
	# Don't make new decisions while executing an action
	if action_hold_timer > 0:
		# But still track the ball position while acting
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
		target_x = 128 + 30  # Position close to net
	
	# Add some error based on difficulty
	target_x += randf_range(-aim_error, aim_error)
	target_x = clamp(target_x, left_bound, right_bound)
	
	# Stop moving if we're close enough (prevents overshooting)
	if horizontal_distance < 5:
		move_dir = 0
	else:
		move_dir = sign(target_x - global_position.x)
	
	# Only decide new actions if we're not in cooldown
	if action_cooldown <= 0 and in_range:
		_decide_action()

func _predict_ball_landing() -> Vector2:
	if ball == null:
		return global_position
	
	var ball_pos = ball.global_position
	var ball_vel = ball.linear_velocity
	
	# If ball is moving away from us, don't chase it too aggressively
	if ball_vel.x < -50 and ball_pos.x < left_bound:
		# Ball going to opponent's side, return to center
		return Vector2((left_bound + right_bound) / 2, global_position.y)
	
	# Simple prediction for better tracking
	var time_to_reach = 2  # Look ahead half a second
	var predicted_x = ball_pos.x + (ball_vel.x * time_to_reach)
	
	# Clamp to our side
	predicted_x = clamp(predicted_x, left_bound + 20, right_bound - 20)
	
	return Vector2(predicted_x, global_position.y)

func _handle_action_holding(_delta: float) -> void:
	# This ensures actions are held long enough to register
	if action_hold_timer <= 0:
		# Time's up, release all actions
		if not current_action in ["preparing_hit", "preparing_block"]:
			is_bumping = false
			is_hitting = false
			is_setting = false
			is_blocking = false
			current_action = ""

func _decide_action() -> void:
	
	# Calculate relative positions
	var ball_height_diff = global_position.y - ball.global_position.y
	var ball_falling = ball.linear_velocity.y > 0
	var _ball_rising = ball.linear_velocity.y < -100
	var ball_speed = ball.linear_velocity.length()
	var distance_to_net = abs(global_position.x - 128)  # Distance from net
	
	if ball.global_position.x <= 128:
		player_arms.touch_counter = 0
		
	# Reset all actions first
	is_bumping = false
	is_hitting = false
	is_setting = false
	is_blocking = false
	should_jump = false
	current_action = ""
	
	
	# CRITICAL: Check conditions in REVERSE order (most specific first)
	
	if is_on_floor() and ball_falling and in_bump_range:
		current_action = "bump"
		is_bumping = true
		should_jump = false
		action_hold_timer = 0.4
		action_cooldown = 0.7
		print("=== BOT DECISION ===")
		print("Height diff: ", ball_height_diff, " | Falling: ", ball_falling, " | On floor: ", is_on_floor())
		print("Dist to net: ", distance_to_net, " | Ball speed: ", ball_speed)
		print(">>> ACTION: BUMP (very low ball)")
		return
	
	# Check 2: High ball - HIT or prepare to hit
	if in_hit_range and not is_on_floor() and player_arms.touch_counter >= 3:
		current_action = "hit"
		is_hitting = true
		action_hold_timer = 0.3
		action_cooldown = 0.8
		print(">>> ACTION: HIT (in air)")
		return
	
	# Check 3: Medium-low to medium-high ball - SET (this should be most common)
	if is_on_floor() and in_set_range:
		current_action = "set"
		is_setting = true
		print("=== BOT DECISION ===")
		print("Height diff: ", ball_height_diff, " | Falling: ", ball_falling, " | On floor: ", is_on_floor())
		print("Dist to net: ", distance_to_net, " | Ball speed: ", ball_speed)
		print(">>> ACTION: SET")
		action_hold_timer = 0.4
		action_cooldown = 0.7
		return
	
	# Check 4: Block at net
	if in_blockzone and ball_height_diff > -20 and ball.global_position.x < 128:
		if ball.linear_velocity.x > 0:  # Ball coming toward our side
			if is_on_floor():
				should_jump = true
				current_action = "preparing_block"
				action_hold_timer = 0.3
				print(">>> ACTION: Preparing to BLOCK")
			else:
				current_action = "block"
				is_blocking = true
				action_hold_timer = 0.3
				action_cooldown = 0.8
				print("=== BOT DECISION ===")
				print("Height diff: ", ball_height_diff, " | Falling: ", ball_falling, " | On floor: ", is_on_floor())
				print("Dist to net: ", distance_to_net, " | Ball speed: ", ball_speed)
				print(">>> ACTION: BLOCK")
			return
			
	if distance_to_net < 35 and ball_height_diff > -20 and ball.global_position.x > 128:
		should_jump = true
		print(">>> ACTION: JUMP")
		return
		
func _apply_gravity(delta: float) -> void:
	var gravity_mult: float = 1
	
	if is_blocking:
		gravity_mult = 1.3
		print("block")
	else:
		gravity_mult = 1

	# Apply gravity
	if velocity.y < 0:
		velocity.y += gravity * 0.6 * gravity_mult * delta
	else:
		velocity.y += gravity * fall_multiplier * gravity_mult * delta
		
func _apply_movement(delta: float) -> void:
	# Jump if needed
	if should_jump and is_on_floor():
		velocity.y = -jump_force
		should_jump = false
	
	# Move horizontally
	if move_dir != 0:
		velocity.x = move_toward(
			velocity.x,
			move_dir * speed,
			acceleration * delta
		)
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)

func _update_actions() -> void:
	# Only update player arms if we have an active action
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
	
	if not is_bumping and not is_hitting and not is_setting:
		if not is_on_floor():
			if in_blockzone == false:
				sprite.play("Jump")
			elif in_blockzone == true:
				sprite.play("Block")
		elif move_dir != 0:
			sprite.play("Run")
		else:
			sprite.play("Idle")
			
	if move_dir != 0:
		sprite.flip_h = move_dir < 0
		player_arms.sprite_direction(move_dir)

func _on_ball_range_body_entered(body: Node2D) -> void:
	if body is RigidBody2D:
		if body == get_tree().get_first_node_in_group("ball"):
			in_range = true

func _on_ball_range_body_exited(body: Node2D) -> void:
	if body is RigidBody2D:
		if body == get_tree().get_first_node_in_group("ball"):
			in_range = false

func _on_bump_range_body_entered(body: Node2D) -> void:
	if body is RigidBody2D:
		if body == get_tree().get_first_node_in_group("ball"):
			in_bump_range = true

func _on_bump_range_body_exited(body: Node2D) -> void:
	if body is RigidBody2D:
		if body == get_tree().get_first_node_in_group("ball"):
			in_bump_range = false

func _on_set_range_body_entered(body: Node2D) -> void:
	if body is RigidBody2D:
		if body == get_tree().get_first_node_in_group("ball"):
			in_set_range = true

func _on_set_range_body_exited(body: Node2D) -> void:
	if body is RigidBody2D:
		if body == get_tree().get_first_node_in_group("ball"):
			in_set_range = false

func _on_hit_range_body_entered(body: Node2D) -> void:
	if body is RigidBody2D:
		if body == get_tree().get_first_node_in_group("ball"):
			in_hit_range = true
			print(in_hit_range)

func _on_hit_range_body_exited(body: Node2D) -> void:
	if body is RigidBody2D:
		if body == get_tree().get_first_node_in_group("ball"):
			in_hit_range = false
