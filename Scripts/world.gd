extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var ball_scene: PackedScene = preload("res://Scenes/ball.tscn")
@onready var score_board: Node2D = $ScoreBoard

var active_ball: Node2D = null  # Track the current ball

func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("spawnball_1"):
		spawn_ball()

func spawn_ball() -> void:
	# Delete old ball if it exists
	if active_ball != null:
		active_ball.call_deferred("queue_free")

	# Instantiate new ball
	var ball_instance = ball_scene.instantiate()
	active_ball = ball_instance
	ball_instance.update_score.connect(score_board.update_score)
	
	# Reset ball spawn depending on who scored last
	if score_board.last_point == 1:
		ball_instance.global_position = Vector2(30, -40)
		ball_instance.current_player_side = 1
	elif score_board.last_point == 2:
		ball_instance.global_position = Vector2(226, -40)
		ball_instance.current_player_side = 2

	add_child(ball_instance)
	

func _on_player_one_side_body_entered(body: Node2D) -> void:
	if body.is_in_group("ball"):
		body.current_player_side = 1

func _on_player_two_side_body_entered(body: Node2D) -> void:
	if body.is_in_group("ball"):
		body.current_player_side = 2

func _on_block_zone_body_entered(body: Node2D):
	if body == player:
		player.in_blockzone = true

func _on_block_zone_body_exited(body: Node2D) -> void:
	if body == player:
		player.in_blockzone = false
