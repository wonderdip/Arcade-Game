
extends CharacterBody2D

@export var speed := 200.0
@export var jump_force := 250.0
@export var acceleration := 1200.0
@export var friction := 1000.0
@export var gravity := 980.0
@export var fall_multiplier := 1.5

@export var is_bot := true
@export var left_bound := 128.0
@export var right_bound := 256.0
@export var reaction_time := 0.15
@export var aim_error := 20.0

@export_enum("Easy", "Normal", "Hard", "Expert") var difficulty := "Normal"

@onready var sprite: AnimatedSprite2D = $BotAnim
@onready var player_arms: Node2D = $"Player Arms"
@onready var ball_range: Area2D = $RangePivot/BallRange
@onready var bump_range: Area2D = $RangePivot/BumpRange
@onready var range_pivot: Node2D = $RangePivot
@onready var set_range: Area2D = $RangePivot/SetRange
@onready var hit_range: Area2D = $RangePivot/HitRange
@onready var label: Label = $Label

var ball: RigidBody2D
var decision_timer := 0.0
var move_dir := 0.0
var min_ball_distance:= 0.0
var distance_to_net :float = 0

var is_hitting := false
var is_bumping := false
var is_setting := false
var is_blocking := false
var in_range: bool
var in_bump_range: bool
var in_set_range: bool
var in_hit_range: bool
var in_blockzone: bool = false

var predicted_landing_pos: Vector2
var should_jump := false
var action_cooldown := 0.0
var action_hold_timer := 0.0
var current_action := ""
var last_action := ""
var gravity_mult: float = 1.0
var speed_mult: float
var offense_plan := ""
var ball_height_diff: float
var predicted_ball_pos: Vector2
var cooldown_mult: float = 1.0

func _ready() -> void:
	sprite.play("Idle")
	_apply_difficulty_settings()

func set_difficulty_from_index(index: int) -> void:
	match index:
		0: difficulty = "Easy"
		1: difficulty = "Normal"
		2: difficulty = "Hard"
		3: difficulty = "Expert"
		_: difficulty = "Normal"
	
	_apply_difficulty_settings()
	print("Bot difficulty set to:", difficulty)
	
func _apply_difficulty_settings() -> void:
	match difficulty:
		"Easy":
			reaction_time = 0.25
			aim_error = 8.0
			min_ball_distance = 15
			speed = 200 * 0.7
			jump_force = 250 * 0.85
			player_arms.ball_control = 0.2
			player_arms.downward_force = 20
			player_arms.hit_force = 45
			cooldown_mult = 1.4   # slower bot
		"Normal":
			reaction_time = 0.15
			aim_error = 4.0
			min_ball_distance = 10
			speed = 200 * 0.9
			jump_force = 240
			player_arms.ball_control = 0.5
			player_arms.downward_force = 30
			player_arms.hit_force = 60
			cooldown_mult = 1.0
		"Hard":
			reaction_time = 0.08
			aim_error = 2.0
			min_ball_distance = 6
			speed = 200 * 1.1
			jump_force = 250
			player_arms.ball_control = 0.75
			player_arms.downward_force = 40
			player_arms.hit_force = 70
			cooldown_mult = 0.8
		"Expert":
			reaction_time = 0.03
			aim_error = 0.5
			min_ball_distance = 3
			speed = 200 * 1.3
			jump_force = 250 * 1.15
			player_arms.ball_control = 0.95
			player_arms.downward_force = 50
			player_arms.hit_force = 85
			cooldown_mult = 0.6   # very fast bot


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
	
	label.text = (current_action + str(player_arms.touch_counter) + " " + str(ball_height_diff))
	$Label2.text = offense_plan
	
	if action_cooldown > 0:
		action_cooldown -= delta
	if action_hold_timer > 0:
		action_hold_timer -= delta

func _find_ball() -> void:
	if ball == null:
		ball = get_tree().get_first_node_in_group("ball")

func reset():
	if player_arms:
		player_arms.touch_counter = 0
	offense_plan = ""

# IMPROVED: Predict where ball will be based on velocity
func _predict_ball_position(time_ahead: float) -> Vector2:
	if not ball:
		return Vector2.ZERO
	
	var predicted_pos = ball.global_position + ball.linear_velocity * time_ahead
	# Account for gravity
	predicted_pos.y += 0.5 * gravity * ball.gravity_scale * time_ahead * time_ahead
	return predicted_pos

func _update_ai(delta: float) -> void:
	if not is_bot or ball == null:
		return
		
	# BLOCK RESET: Cancel block when landing OR leaving blockzone
	if is_blocking and (is_on_floor() or not in_blockzone):
		is_blocking = false
		should_jump = false
		current_action = ""
		action_hold_timer = 0
		action_cooldown = 0

	# IMPROVED: Better out-of-range behavior
	if not in_range or ball.scored:
		player_arms.touch_counter = 0
		var defensive_position = (left_bound + right_bound) / 2 - 20
		var distance_to_position = abs(defensive_position - global_position.x)
		if distance_to_position > 5:
			move_dir = sign(defensive_position - global_position.x)
		else:
			move_dir = 0
		should_jump = false
		is_blocking = false
		is_bumping = false
		is_hitting = false
		is_setting = false
		return
		
	# IMPROVED: Don't lock movement during action hold unless it's a commit action
	if action_hold_timer > 0 and (is_hitting or (is_bumping and action_hold_timer > 0.3)):
		var horiz_distance = abs(ball.global_position.x - global_position.x)
		if horiz_distance > min_ball_distance:
			move_dir = sign(ball.global_position.x - global_position.x)
		else:
			move_dir = 0
		return
		
	decision_timer -= delta
	if decision_timer > 0:
		return

	decision_timer = reaction_time

	# IMPROVED: Use prediction for faster balls
	var ball_speed = ball.linear_velocity.length()
	var use_prediction = ball_speed > 150.0 and ball.global_position.x > 128
	var target_ball_pos = ball.global_position
	
	if use_prediction:
		var time_to_predict = 0.3 if difficulty == "Expert" else 0.5
		predicted_ball_pos = _predict_ball_position(time_to_predict)
		# Only use prediction if ball is moving toward bot's side
		if ball.linear_velocity.x > 0:
			target_ball_pos = predicted_ball_pos
	
	var horizontal_distance = abs(target_ball_pos.x - global_position.x)
	var target_x = target_ball_pos.x
	distance_to_net = global_position.x - 128
	
	# IMPROVED: Better net positioning
	if ball.global_position.x > 128 and distance_to_net < 50:
		target_x = 128 + 35
	
	target_x += randf_range(-aim_error, aim_error)
	target_x = clamp(target_x, left_bound, right_bound)
	
	# IMPROVED: Start moving earlier
	if horizontal_distance < min_ball_distance:
		move_dir = 0
	else:
		move_dir = sign(target_x - global_position.x)
	
	if ball.global_position.x <= 128 or ball.scored:
		reset()
		
	if action_cooldown <= 0 and in_range:
		_decide_action()
		
	# IMPROVED: Set offense plan earlier
	if offense_plan == "" and ball.global_position.x > 128:
		offense_plan = "quick" if randf() < 0.5 else "high"

func _handle_action_holding(_delta: float) -> void:
	if action_hold_timer <= 0:
		if current_action != "block":
			is_bumping = false
			is_hitting = false
			is_setting = false
			current_action = ""

func _decide_action() -> void:
	ball_height_diff = global_position.y - ball.global_position.y
	var ball_falling = ball.linear_velocity.y > 0
	var ball_speed = ball.linear_velocity.length()
	var hit_type := offense_plan
	
	if current_action != "" and current_action != "block":
		last_action = current_action
		
	if current_action != "block":
		is_bumping = false
		is_hitting = false
		is_setting = false
		should_jump = false
		current_action = ""
	
	# DECISION PRIORITY (IMPROVED)
	
	# 1. Regular BUMP - Low ball on ground
	if is_on_floor() and in_bump_range:
		current_action = "bump"
		is_bumping = true
		should_jump = false
		action_hold_timer = 0.55
		action_cooldown = 0.4 * cooldown_mult
		return
	
	# 2. BLOCK - Ball coming over net
	if (in_blockzone and ball.global_position.x < 128 and 
		ball_height_diff > 70 and ball_height_diff < 120 and is_on_floor()):
		should_jump = true
		is_blocking = true
		current_action = "block"
		action_hold_timer = 999.0
		action_cooldown = 0.1 * cooldown_mult
		return
	
	# 3. HIT - High ball after touches
	if (in_hit_range and not is_on_floor() and 
		not last_action == "hit" and 
		player_arms.touch_counter >= 2):
		current_action = "hit"
		is_hitting = true
		action_hold_timer = 0.35
		action_cooldown = 0.6 * cooldown_mult
		reset()
		return
	
	# 4. SET - Medium ball on ground
	if is_on_floor() and in_set_range and player_arms.touch_counter >= 1 and distance_to_net < 110:
		if hit_type == "quick" and player_arms.touch_counter <= 2 and distance_to_net > 60:
			current_action = "set"
			is_setting = true
			action_hold_timer = 0.5
			action_cooldown = 0.5 * cooldown_mult
		elif hit_type == "high":
			current_action = "set"
			is_setting = true
			action_hold_timer = 0.5
			action_cooldown = 0.5 * cooldown_mult
		return
		
	# 5. Position for jump after set (high ball)
	if (distance_to_net > 30 and distance_to_net < 95 and
		ball_height_diff > 140 and ball_height_diff < 180 and
		ball.global_position.x > 128 and
		player_arms.touch_counter >= 2 and
		is_on_floor() and hit_type == "high"):
		should_jump = true
		return
		
	# 6. Position for jump after bump (quick)
	if (distance_to_net > 10 and distance_to_net < 60 and
		ball_height_diff > 50 and ball_height_diff < 80 and
		ball.global_position.x > 128 and
		player_arms.touch_counter >= 2 and
		is_on_floor() and hit_type == "quick"):
		should_jump = true
		return
		
func _apply_gravity(delta: float) -> void:
	if is_blocking and not is_on_floor():
		gravity_mult = jump_force / 210
	else:
		gravity_mult = 1.0

	if velocity.y < 0:
		velocity.y += gravity * 0.6 * gravity_mult * delta
	else:
		velocity.y += gravity * fall_multiplier * gravity_mult * delta
		
func _apply_movement(delta: float) -> void:
	if should_jump and is_on_floor():
		velocity.y = -jump_force
		should_jump = false
		
	if is_bumping:
		speed_mult = 0.3
	elif is_setting:
		speed_mult = 0.5
	elif is_hitting:
		speed_mult = 0.2
	elif is_blocking:
		speed_mult = 0.7
	else:
		speed_mult = 1.0
	
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
		player_arms.action("bump", false)
		player_arms.action("hit", false)
		player_arms.action("set", false)
		player_arms.action("block", false)

func _update_animation() -> void:
	if move_dir != 0:
		range_pivot.scale.x = sign(move_dir)

	if in_blockzone or not is_on_floor() or (is_setting or is_bumping) and distance_to_net < 40:
		sprite.flip_h = true
		player_arms.sprite_direction(-1)
	elif move_dir != 0:
		sprite.flip_h = move_dir < 0
		player_arms.sprite_direction(move_dir)
	
	if not is_bumping and not is_hitting and not is_setting:
		if not is_on_floor():
			if is_blocking:
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
