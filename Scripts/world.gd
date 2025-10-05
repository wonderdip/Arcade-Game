extends Node2D

@onready var ball_scene: PackedScene = preload("res://Scenes/ball.tscn")
@onready var score_board: Node2D = $ScoreBoard
@onready var multiplayer_spawner: MultiplayerSpawner = $MultiplayerSpawner

var active_ball: Node2D = null
var ball_spawned: bool = false
var is_network_mode: bool = false

func _ready() -> void:
	# Check if we're in network mode
	is_network_mode = multiplayer.multiplayer_peer != null
	
	if is_network_mode:
		# Network mode - only server spawns ball after client connects
		if multiplayer.is_server():
			multiplayer.peer_connected.connect(_on_peer_connected)
			var peer_count = multiplayer.get_peers().size()
			if peer_count >= 1:
				await get_tree().create_timer(1.0).timeout
				spawn_ball()
	else:
		# Local mode - players are already in scene, just wait a moment
		print("Local multiplayer mode detected")
		# Ball can be spawned immediately or wait for player input

func _on_peer_connected(id: int):
	if multiplayer.is_server() and not ball_spawned:
		print("Client ", id, " connected. Spawning ball...")
		await get_tree().create_timer(1.0).timeout
		spawn_ball()

func _physics_process(_delta: float) -> void:
	# Anyone can spawn ball in local mode, only server in network mode
	if Input.is_action_just_pressed("spawnball_1") or Input.is_action_just_pressed("spawnball_2"):
		if is_network_mode:
			if multiplayer.is_server():
				spawn_ball()
			else:
				rpc_id(1, "request_ball_spawn")
		else:
			# Local mode - just spawn directly
			spawn_ball_local()

@rpc("any_peer", "call_remote")
func request_ball_spawn():
	if multiplayer.is_server():
		spawn_ball()

func spawn_ball() -> void:
	# Network mode spawning
	if not multiplayer.is_server():
		return
		
	if active_ball != null and is_instance_valid(active_ball):
		active_ball.queue_free()
		await get_tree().process_frame

	var ball_instance = ball_scene.instantiate()
	
	if score_board.last_point == 1:
		ball_instance.position = Vector2(30, -40)
		ball_instance.current_player_side = 1
	elif score_board.last_point == 2:
		ball_instance.position = Vector2(226, -40)
		ball_instance.current_player_side = 2
	
	ball_instance.name = "Ball_" + str(Time.get_ticks_msec())
	
	print("Server spawning ball at position: ", ball_instance.position)
	
	add_child(ball_instance, true)
	active_ball = ball_instance
	ball_spawned = true
	
	if not ball_instance.update_score.is_connected(score_board.update_score):
		ball_instance.update_score.connect(score_board.update_score)

func spawn_ball_local() -> void:
	# Local mode spawning (no network replication needed)
	if active_ball != null and is_instance_valid(active_ball):
		active_ball.queue_free()

	var ball_instance = ball_scene.instantiate()
	
	if score_board.last_point == 1:
		ball_instance.global_position = Vector2(30, -40)
		ball_instance.current_player_side = 1
	elif score_board.last_point == 2:
		ball_instance.global_position = Vector2(226, -40)
		ball_instance.current_player_side = 2
	
	print("Local mode: Spawning ball at position: ", ball_instance.global_position)
	
	add_child(ball_instance)
	active_ball = ball_instance
	
	if not ball_instance.update_score.is_connected(score_board.update_score):
		ball_instance.update_score.connect(score_board.update_score)

func _on_player_one_side_body_entered(body: Node2D) -> void:
	if body.is_in_group("ball"):
		if is_network_mode and not multiplayer.is_server():
			return
		body.current_player_side = 1

func _on_player_two_side_body_entered(body: Node2D) -> void:
	if body.is_in_group("ball"):
		if is_network_mode and not multiplayer.is_server():
			return
		body.current_player_side = 2

func _on_block_zone_body_entered(body: Node2D):
	if body is CharacterBody2D and "in_blockzone" in body:
		body.in_blockzone = true

func _on_block_zone_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and "in_blockzone" in body:
		body.in_blockzone = false
