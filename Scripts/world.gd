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
	print("=== World._ready() called ===")
	print("Networkhandler.is_local = ", Networkhandler.is_local)
	
	# Check if we're in network mode
	is_network_mode = multiplayer.multiplayer_peer != null
	print("is_network_mode = ", is_network_mode)
	
	if is_network_mode:
		print("Network mode detected")
		# Network mode - only server spawns ball after client connects
		if multiplayer.is_server():
			multiplayer.peer_connected.connect(_on_peer_connected)
			var peer_count = multiplayer.get_peers().size()
			if peer_count >= 1:
				await get_tree().create_timer(1.0).timeout
				spawn_ball()
	elif Networkhandler.is_local:
		print("Local mode detected - calling setup_local_multiplayer()")
		# Local mode - setup player manager
		setup_local_multiplayer()
	else:
		print("WARNING: Neither network nor local mode!")

func setup_local_multiplayer() -> void:
	print("=== Setting up local multiplayer ===")
	
	# Create the player manager
	var PlayerManager = load("res://Scripts/local_player_manager.gd")
	local_player_manager = PlayerManager.new()
	local_player_manager.name = "LocalPlayerManager"
	local_player_manager.max_players = 2
	
	# Connect to player join signal BEFORE adding to tree
	var connection_result = local_player_manager.player_joined.connect(_on_local_player_joined)
	print("Signal connection result: ", connection_result)
	print("Is signal connected? ", local_player_manager.player_joined.is_connected(_on_local_player_joined))
	
	add_child(local_player_manager)
	
	# Test if the function can be called directly
	print("Testing direct function call...")
	# Don't actually call it, just verify it exists
	if has_method("_on_local_player_joined"):
		print("_on_local_player_joined method exists")
	else:
		print("ERROR: _on_local_player_joined method NOT found!")
	
	print("Press any button/key to join! (Up to 2 players)")
	print("Keyboard device ID: 0")
	print("Controller devices will have IDs > 0")

func _on_local_player_joined(device_id: int, player_number: int, input_type: String):
	print("=== _on_local_player_joined called ===")
	print("Device ID: ", device_id, " Player Number: ", player_number, " Input Type: ", input_type)
	
	# Spawn the player
	var player = player_scene.instantiate()
	print("Player scene instantiated: ", player)
	
	player.name = "Player_" + str(player_number)
	player.position = local_player_manager.get_spawn_position(player_number)
	print("Player position set to: ", player.position)
	
	add_child(player)
	print("Player added to scene tree")
	
	# Setup the player with their device and input type
	player.setup_local_player(device_id, player_number, input_type)
	print("Player setup complete")
	
	spawned_players.append(player)
	print("Players spawned so far: ", spawned_players.size())
	
	# If both players joined, spawn the ball
	if spawned_players.size() == 2:
		print("Both players joined - spawning ball...")
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
