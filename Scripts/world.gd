extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var ball_scene: PackedScene = preload("res://Scenes/ball.tscn")
@onready var score_board: Node2D = $ScoreBoard

func _on_block_zone_body_entered(body: Node2D) -> void:
	if body == player:
		player.in_blockzone = true

func _on_block_zone_body_exited(body: Node2D) -> void:
	if body == player:
		player.in_blockzone = false

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("spawnball"):
		var ball_instance = ball_scene.instantiate()
		ball_instance.update_score.connect(score_board.update_score)
		if score_board.last_point == 1:
			ball_instance.global_position = Vector2(30, -40)
		elif score_board.last_point == 2:
			ball_instance.global_position = Vector2(226, -40)
		add_child(ball_instance)

func _on_player_one_side_body_entered(body: Node2D) -> void:
	if body.is_in_group("ball"):
		body.current_player_side = 1

func _on_player_two_side_body_entered(body: Node2D) -> void:
	if body.is_in_group("ball"):
		body.current_player_side = 2
