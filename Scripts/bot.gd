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
@onready var ball_range: Area2D = $BallRange
@onready var bump_range: Area2D = $BumpRange
@onready var label: Label = $Label
@onready var label_2: Label = $Label2

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

var predicted_landing_pos: Vector2
var should_jump := false
var action_cooldown := 0.0
var action_hold_timer := 0.0
var current_action := ""
var last_action := ""
var gravity_mult: float = 1.0
var speed_mult: float

var fallbackframe := preload("res://Assets/Characters/Player Sprite Frames/P1.tres")

# Character resources for dynamic loading
@export var character_resources: Array[CharacterStat] = [
	preload("res://Scripts/Resources/P1.tres"),
	preload("res://Scripts/Resources/P2.tres"),
	preload("res://Scripts/Resources/P3.tres")
]

func _ready() -> void:
	sprite.play("Idle")
	_apply_difficulty_settings()
	load_character_by_index(0)

# Method to set difficulty from index (0=Easy, 1=Normal, 2=Hard, 3=Expert)
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
			reaction_time = 0.3
			aim_error = 20.0
			speed = speed * 0.8
		"Normal":
			reaction_time = 0.2
			aim_error = 10.0
		"Hard":
			reaction_time = 0.005
			aim_error = 0.5
			speed = speed * 1.2
		"Expert":
			reaction_time = 0.0005
			aim_error = 0.05
			speed = speed * 1.5
			player_arms.ball_control = 1
			
# Method to load character by index (0=P1, 1=P2, 2=P3)
func load_character_by_index(index: int) -> void:
	if index < 0 or index >= character_resources.size():
		index = 0
	
	var char_stat: CharacterStat = character_resources[index]
	
	if char_stat != null:
		sprite.sprite_frames = char_stat.sprite_frame
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
		
		# Reapply difficulty settings after character change
		_apply_difficulty_settings()
		
		print("Bot character loaded: P", index + 1)
	else:
		sprite.sprite_frames = fallbackframe
		print("Failed to load character, using fallback")
	


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
		var defensive_position = (left_bound + right_bound) / 2 - 20
		var distance_to_position = abs(defensive_position - global_position.x)
		if distance_to_position > 5:
			move_dir = sign(defensive_position - global_position.x)
		else:
			move_dir = 0
		should_jump = false
		return
		
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

	var horizontal_distance = abs(ball.global_position.x - global_position.x)
	var target_x = ball.global_position.x
	var distance_to_net = abs(ball.global_position.x - 128)
	
	if ball.global_position.x > 128 and distance_to_net < 40:
		target_x = 128 + 30
	
	target_x += randf_range(-aim_error, aim_error)
	target_x = clamp(target_x, left_bound, right_bound)
	
	if horizontal_distance < 5:
		move_dir = 0
	else:
		move_dir = sign(target_x - global_position.x)
	
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
	label.text = str(ball_height_diff)
	label_2.text = str(difficulty)
	
	if ball.global_position.x <= 128:
		player_arms.touch_counter = 0
	
	# Store the PREVIOUS action before resetting (but not preparatory states)
	if current_action != "" and current_action not in ["preparing_hit", "preparing_block"]:
		last_action = current_action
		
	# Reset all actions first
	is_bumping = false
	is_hitting = false
	is_setting = false
	is_blocking = false
	should_jump = false
	current_action = ""
	
	# DECISION PRIORITY
	
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
		if distance_to_net > 50:
			action_hold_timer = 0.5
			action_cooldown = 0.5
		return
	
	# 4. Ball coming over net - BLOCK
	if in_blockzone and ball.global_position.x < 128 and ball_height_diff > 80 and ball_height_diff < 110:
		if ball.linear_velocity.x > 0:
			if is_on_floor():
				should_jump = true
				current_action = "preparing_block"
			else:
				current_action = "block"
				is_blocking = true
				action_hold_timer = 0.3
				action_cooldown = 0.6
			return
	
	# 5. Position for jump after set
	if (
		distance_to_net > 20 and
		distance_to_net < 70 and
		ball_height_diff > 120 and
		ball_height_diff < 140 and
		ball.global_position.x > 128 and
		player_arms.touch_counter >= 2 and
		is_on_floor() and
		not in_blockzone and 
		last_action == "set"
	):
		should_jump = true
		return
	
	# Position for jump after bump
	if (
		distance_to_net > 5 and
		distance_to_net < 40 and
		ball_height_diff > 80 and
		ball_height_diff < 90 and
		ball.global_position.x > 128 and
		player_arms.touch_counter >= 3 and
		is_on_floor() and
		last_action == "bump"
	):
		should_jump = true
		return
		
func _apply_gravity(delta: float) -> void:
	if is_blocking:
		gravity_mult = 1.3
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
		
	if is_bumping or is_setting:
		speed_mult = 0.4
	elif is_hitting:
		speed_mult = 0.4
	else:
		speed_mult = 1
	
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
	if in_blockzone or not is_on_floor() or is_setting or is_bumping:
		sprite.flip_h = true
		player_arms.sprite_direction(-1)
	elif move_dir != 0:
		sprite.flip_h = move_dir < 0
		player_arms.sprite_direction(move_dir)
	
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
