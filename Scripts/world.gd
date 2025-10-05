extends Node2D

@onready var ball_scene: PackedScene = preload("res://Scenes/ball.tscn")
@onready var score_board: Node2D = $ScoreBoard
@onready var multiplayer_spawner: MultiplayerSpawner = $MultiplayerSpawner

var active_ball: Node2D = null

func _ready() -> void:
	# Wait for multiplayer to be ready
	if not multiplayer.is_server():
		return
	
	# Give time for players to spawn first
	await get_tree().create_timer(0.5).timeout
	spawn_ball()

func _physics_process(_delta: float) -> void:
	# Only server can spawn balls, but both players can press the button
	if Input.is_action_just_pressed("spawnball_1") or Input.is_action_just_pressed("spawnball_2"):
		if multiplayer.is_server():
			spawn_ball()
		else:
			# Client requests server to spawn ball
			rpc_id(1, "request_ball_spawn")

@rpc("any_peer", "call_remote")
func request_ball_spawn():
	if multiplayer.is_server():
		spawn_ball()

func spawn_ball() -> void:
	if not multiplayer.is_server():
		return
		
	# Delete old ball if it exists
	if active_ball != null and is_instance_valid(active_ball):
		active_ball.queue_free()
		await get_tree().process_frame  # Wait for deletion

	# Instantiate new ball
	var ball_instance = ball_scene.instantiate()
	active_ball = ball_instance
	
	# Set ball properties before adding to scene
	if score_board.last_point == 1:
		ball_instance.global_position = Vector2(30, -40)
		ball_instance.current_player_side = 1
	elif score_board.last_point == 2:
		ball_instance.global_position = Vector2(226, -40)
		ball_instance.current_player_side = 2
	
	# Add to scene first
	add_child(ball_instance, true)
	
	# Connect signal after adding to scene tree
	if not ball_instance.update_score.is_connected(score_board.update_score):
		ball_instance.update_score.connect(score_board.update_score)

func _on_player_one_side_body_entered(body: Node2D) -> void:
	if body.is_in_group("ball"):
		body.current_player_side = 1

func _on_player_two_side_body_entered(body: Node2D) -> void:
	if body.is_in_group("ball"):
		body.current_player_side = 2

func _on_block_zone_body_entered(body: Node2D):
	if body is CharacterBody2D and "in_blockzone" in body:
		body.in_blockzone = true

func _on_block_zone_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and "in_blockzone" in body:
		body.in_blockzone = false
