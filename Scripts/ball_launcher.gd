extends Node2D

@onready var ball_spawn_point: Marker2D = $BallSpawnPoint
@export var ball_scene: PackedScene
@onready var timer: Timer = $Timer
@export var launch_speed: float = 400.0
@export var max_balls: int = 5

var balls: Array[RigidBody2D] = []

func _ready() -> void:
	change_position(1)
	timer.start()

func change_position(current_pos: int) -> void:
	if current_pos == 1:
		position = Vector2(190, 45)
		rotation = deg_to_rad(-100)
	elif current_pos == 2:
		position = Vector2(158, 37)
		rotation = deg_to_rad(-115)
	elif current_pos == 3:
		position = Vector2(55, 100)
		rotation = deg_to_rad(10)

func launch_ball() -> void:
	# Create and spawn the ball
	var new_ball: RigidBody2D = ball_scene.instantiate()
	new_ball.global_position = ball_spawn_point.global_position
	
	var direction = Vector2.UP.rotated(ball_spawn_point.global_rotation)
	new_ball.linear_velocity = direction * launch_speed
	new_ball.launcher_is_parent = true
	
	get_parent().add_child(new_ball, true)
	AudioManager.play_sfx("balllaunch")
	# Add to list
	balls.append(new_ball)
	
	# If too many balls, remove the oldest one
	if balls.size() > max_balls:
		var oldest_ball = balls.pop_front()
		if is_instance_valid(oldest_ball):
			oldest_ball.queue_free()
			print("Oldest ball deleted.")

func delete_all_balls():
	for ball in balls:
		ball.queue_free()

func _on_timer_timeout() -> void:
	launch_ball()
	timer.start()
