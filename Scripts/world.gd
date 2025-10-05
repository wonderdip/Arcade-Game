extends Node2D

@onready var ball_scene: PackedScene = preload("res://Scenes/ball.tscn")
@onready var player_scene: PackedScene = preload("res://Scenes/player.tscn")
@onready var score_board: Node2D = $ScoreBoard
@onready var multiplayer_spawner: MultiplayerSpawner = $MultiplayerSpawner

var active_ball: Node2D = null
var ball_spawned: bool = false
var is_network_mode: bool = false
var local_player_manager: Node = null
var spawned_players: Array = []

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
	elif Networkhandler.is_local:
		# Local mode - setup player manager
		print("Local multiplayer mode detected")
		setup_local_multiplayer()

func setup_local_multiplayer() -> void:
	# Create the player manager
	var PlayerManager = load("res://Scripts/local_player_manager.gd")
	local_player_manager = PlayerManager.new()
	local_player_manager.name = "LocalPlayerManager"
	local_player_manager.max_players = 2
	add_child(local_player_manager)
	
	# Connect to player join signal
	local_player_manager.player_joined.connect(_on_local_player_joined)
	
	print("Press any button to join! (Up to 2 players)")

func _on_local_player_joined(device_id: int, player_number: int):
	print("Spawning player %d with device %d" % [player_number, device_id])
	
	# Spawn the player
	var player = player_scene.instantiate()
	player.name = "Player_" + str(player_number)
	player.position = local_player_manager.get_spawn_position(player_number)
	
	add_child(player)
	
	# Setup the player with their device
	player.setup_local_player(device_id, player_number)
	spawned_players.append(player)
	
	# If both players joined, spawn the ball
	if spawned_players.size() == 2:
		await get_tree().create_timer(0.5).timeout
		spawn_ball_local()

func _on_peer_connected(id: int):
	if multiplayer.is_server() and not ball_spawned:
		print("Client ", id, " connected. Spawning ball...")
		await get_tree().create_timer(1.0).timeout
		spawn_ball()

func _physics_process(_delta: float) -> void:
	# Ball spawning for testing/reset
	if Input.is_action_just_pressed("spawnball_1") or Input.is_action_just_pressed("spawnball_2"):
		if is_network_mode:
			if multiplayer.is_server():
				spawn_ball()
			else:
				rpc_id(1, "request_ball_spawn")
		elif Networkhandler.is_local and spawned_players.size() >= 2:
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
