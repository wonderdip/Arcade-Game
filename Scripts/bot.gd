extends CharacterBody2D

@export var speed := 200.0
@export var jump_force := 220.0
@export var acceleration := 1200.0
@export var friction := 1000.0
@export var gravity := 980.0
@export var fall_multiplier := 1.5

@export var is_bot := true
@export var left_bound := 0.0
@export var right_bound := 640.0
@export var reaction_time := 0.15
@export var aim_error := 20.0
@onready var sprite: AnimatedSprite2D = $BotAnim
@onready var player_arms: Node2D = $"Player Arms"
@onready var ball_range: Area2D = $BallRange
@onready var action_range: Area2D = $ActionRange

var ball: RigidBody2D
var decision_timer := 0.0
var move_dir := 0.0

var is_hitting := false
var is_bumping := false
var is_setting := false
var is_blocking := false

func _ready() -> void:
	sprite.play("Idle")

func _physics_process(delta: float) -> void:
	if Networkhandler.settings_opened:
		return

	_find_ball()
	_update_ai(delta)
	_apply_gravity(delta)
	_apply_movement(delta)
	_update_actions()
	_update_animation()
	move_and_slide()

func _find_ball() -> void:
	if ball == null:
		ball = get_tree().get_first_node_in_group("ball")

func _update_ai(delta: float) -> void:
	if not is_bot or ball == null:
		return
	if ball:
		return
		
	decision_timer -= delta
	if decision_timer > 0:
		return

	decision_timer = reaction_time

	# Movement target
	var target_x := _predict_ball_x()
	target_x += randf_range(-aim_error, aim_error)
	move_dir = sign(target_x - global_position.x)

	# Action decisions
	var dist := global_position.distance_to(ball.global_position)
	var ball_falling := ball.linear_velocity.y > 0

	is_bumping = false
	is_hitting = false
	is_setting = false

	if dist < 60 and ball_falling and is_on_floor():
		is_bumping = true
	elif dist < 70 and not is_on_floor():
		is_hitting = true

func _predict_ball_x() -> float:
	var time = max(ball.global_position.y - global_position.y, 0.0) / 400.0
	var predicted = ball.global_position.x + ball.linear_velocity.x * time
	return clamp(predicted, left_bound, right_bound)

func _apply_gravity(delta: float) -> void:
	if velocity.y < 0:
		velocity.y += gravity * delta
	else:
		velocity.y += gravity * fall_multiplier * delta

func _apply_movement(delta: float) -> void:
	if move_dir != 0:
		velocity.x = move_toward(
			velocity.x,
			move_dir * speed,
			acceleration * delta
		)
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)

func _update_actions() -> void:
	if is_bumping:
		player_arms.action("bump")
	elif is_hitting:
		player_arms.action("hit")
	else:
		player_arms.action("bump", false)
		player_arms.action("hit", false)

func _update_animation() -> void:
	if not is_on_floor():
		sprite.play("Jump")
	elif move_dir != 0:
		sprite.play("Run")
	else:
		sprite.play("Idle")

	if move_dir != 0:
		sprite.flip_h = move_dir < 0
		player_arms.sprite_direction(move_dir)
