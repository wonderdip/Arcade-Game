extends Node2D

const BALL_SCENE := preload("res://Scenes/ball.tscn")
const PLAYER_SCENE := preload("res://Scenes/player.tscn")

@onready var score_board: Node2D = $ScoreBoard
@onready var ball_timer: Timer = $BallTimer
@onready var camera_2d: Camera2D = $Camera2D
@onready var referee: Node2D = $Referee
@onready var player_joined: Label = $PlayerJoined

var active_ball: Node2D = null
@export var ball_spawned: bool = false

# Mode tracking
enum GameMode { SOLO, LOCAL, NETWORK }
var current_mode: GameMode

# Network specific
var is_network_server: bool = false
var total_players: int = 0

# Local specific
var spawned_players: Array = []

func _ready() -> void:
	ScreenFX.camera2d = camera_2d
	_determine_game_mode()
	_initialize_mode()

func _determine_game_mode() -> void:
	"""Figure out which game mode we're in"""
	if Networkhandler.is_solo:
		current_mode = GameMode.SOLO
	elif Networkhandler.is_local:
		current_mode = GameMode.LOCAL
	elif multiplayer.multiplayer_peer != null:
		current_mode = GameMode.NETWORK
		is_network_server = multiplayer.is_server()
	else:
		push_error("Unknown game mode - returning to main menu")
		get_tree().change_scene_to_file("res://Scenes/Menus/title_screen.tscn")

func _initialize_mode() -> void:
	"""Initialize based on game mode"""
	match current_mode:
		GameMode.SOLO:
			_setup_solo_mode()
		GameMode.LOCAL:
			_setup_local_mode()
		GameMode.NETWORK:
			_setup_network_mode()

# ========================================
# SOLO MODE
# ========================================

func _setup_solo_mode() -> void:
	print("Initializing solo mode")
	player_joined.hide()
	var player = PLAYER_SCENE.instantiate()
	player.position = Vector2(30, 112)
	add_child(player)
	PlayerManager.player_one = player
	
	# Find bot if it exists
	for child in get_children():
		if child.name == "Bot":
			PlayerManager.player_two = child
			break
			
# ========================================
# LOCAL MODE
# ========================================

func _setup_local_mode() -> void:
	print("Initializing local multiplayer mode")
	PlayerManager.player_joined.connect(_on_local_player_joined)
	player_joined.show()
	
func _on_local_player_joined(device_id: int, player_number: int, input_type: String) -> void:
	var player = PLAYER_SCENE.instantiate()
	player.name = "Player_" + str(player_number)
	player.position = PlayerManager.get_spawn_position(player_number)
	add_child(player)
	player._setup_local_player(device_id, player_number, input_type)
	
	if player_number == 1:
		PlayerManager.player_one = player
		player_joined.text = "Player 2 Press Any Button"
	elif player_number == 2:
		PlayerManager.player_two = player
		player_joined.hide()
	
	spawned_players.append(player)
	
	# Spawn ball when both players ready
	if spawned_players.size() == 2 and current_mode == GameMode.LOCAL:
		await get_tree().create_timer(0.5).timeout
		_spawn_ball_local()

# ========================================
# NETWORK MODE
# ========================================

func _setup_network_mode() -> void:
	print("Initializing network mode (server: %s)" % is_network_server)
	player_joined.hide()
	
	if is_network_server:
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		total_players = multiplayer.get_peers().size() + 1
		
		
		# Spawn ball if we already have max players
		if total_players == Networkhandler.MAX_CLIENTS and current_mode == GameMode.NETWORK:
			await get_tree().create_timer(1.0).timeout
			_spawn_ball_network()

func _on_peer_connected(id: int) -> void:
	if not is_network_server:
		return
	
	total_players = multiplayer.get_peers().size() + 1
	print("Peer connected: %d (Total: %d/%d)" % [id, total_players, Networkhandler.MAX_CLIENTS])
	
	if total_players == Networkhandler.MAX_CLIENTS and current_mode == GameMode.NETWORK:
		await get_tree().create_timer(1.0).timeout
		_spawn_ball_network()

func _on_peer_disconnected(_id: int) -> void:
	if not is_network_server:
		return
	
	total_players = multiplayer.get_peers().size() + 1
	print("Peer disconnected (Total: %d)" % total_players)

# ========================================
# BALL SPAWNING
# ========================================

func _spawn_ball_local() -> void:
	"""Spawn ball in solo or local mode"""
	_cleanup_existing_ball()
	
	var ball = BALL_SCENE.instantiate()
	if current_mode == GameMode.SOLO:
		ball.global_position = Vector2(30, 20)
	else:
		ball.global_position = _get_ball_spawn_position()
	ball.current_player_side = score_board.last_point
	
	add_child(ball, true)
	active_ball = ball
	ball_spawned = true
	
	_connect_ball_signals(ball)

func _spawn_ball_network() -> void:
	"""Spawn ball in network mode (server only)"""
	if not is_network_server:
		return
	
	_cleanup_existing_ball()
	
	var ball = BALL_SCENE.instantiate()
	ball.name = "Ball"  # Consistent name for replication
	var spawn_pos = _get_ball_spawn_position()
	ball.global_position = spawn_pos
	ball.current_player_side = score_board.last_point
	
	add_child(ball, true)
	active_ball = ball
	ball_spawned = true
	
	# IMPORTANT: Set velocity to zero explicitly to ensure clean spawn
	await get_tree().physics_frame
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0
	
	_connect_ball_signals(ball)
	
	print("[Server] Ball spawned at: ", spawn_pos)

@rpc("any_peer", "call_remote", "reliable")
func _request_ball_spawn() -> void:
	"""Client requests server to spawn ball"""
	if is_network_server:
		_spawn_ball_network()

func _cleanup_existing_ball() -> void:
	"""Remove existing ball if present"""
	if active_ball != null and is_instance_valid(active_ball):
		active_ball.queue_free()
		await get_tree().process_frame

func _get_ball_spawn_position() -> Vector2:
	"""Get spawn position based on who scored last"""
	if score_board.last_point == 1:
		return Vector2(30, 20)
	else:
		return Vector2(226, 20)

func _connect_ball_signals(ball: Node) -> void:
	"""Connect ball scoring signals"""
	if not ball.update_score.is_connected(score_board.update_score):
		ball.update_score.connect(score_board.update_score)
	if not ball.update_score.is_connected(_on_ball_scored):
		ball.update_score.connect(_on_ball_scored)

# ========================================
# GAME EVENTS
# ========================================

func _on_ball_scored(side: int) -> void:
	"""Handle ball scoring"""
	ball_spawned = false
	
	# Play appropriate sound/animation
	if current_mode == GameMode.SOLO:
		AudioManager.play_sfx("quick_whistle")
	else:
		referee.call_point(side)
	
	# Reset player positions based on mode
	match current_mode:
		GameMode.LOCAL:
			_reset_player_positions()
		GameMode.NETWORK:
			if is_network_server:
				_reset_player_positions_network()
			# Clients don't need to do anything - they'll receive the RPC
	
	# Start timer for next ball
	ball_timer.start()

func _reset_player_positions() -> void:
	"""Move players back to spawn positions (Local/Solo mode)"""
	await get_tree().create_timer(0.3).timeout
	
	if PlayerManager.player_one:
		PlayerManager.player_one.global_position = PlayerManager.get_spawn_position(1)
	if PlayerManager.player_two:
		PlayerManager.player_two.global_position = PlayerManager.get_spawn_position(2)

func _reset_player_positions_network() -> void:
	"""Reset player positions in network mode (Server calls this and syncs to clients)"""
	await get_tree().create_timer(0.3).timeout
	
	# Call RPC to reset all clients
	_reset_all_players.rpc()

@rpc("authority", "call_local", "reliable")
func _reset_all_players() -> void:
	"""RPC called on all peers to reset their player positions"""
	# Find all player nodes
	for child in get_children():
		if child is CharacterBody2D and child.is_in_group("Player"):
			var player_num = child.player_number
			if player_num > 0:
				child.global_position = PlayerManager.get_spawn_position(player_num)
				print("[%d] Reset player %d to position %s" % [
					multiplayer.get_unique_id(), 
					player_num, 
					PlayerManager.get_spawn_position(player_num)
				])
		
func _on_ball_timer_timeout() -> void:
	"""Spawn new ball after timer expires"""
	if ball_spawned:
		return
	
	match current_mode:
		GameMode.LOCAL:
			_spawn_ball_local()
		GameMode.NETWORK:
			if is_network_server:
				_spawn_ball_network()
			else:
				_request_ball_spawn.rpc_id(1)

# ========================================
# INPUT HANDLING
# ========================================

func _physics_process(_delta: float) -> void:
	# Manual ball spawn for testing
	if SettingsManager.settings_opened:
		return
	
	if _should_allow_manual_spawn() and _is_spawn_input_pressed():
		_handle_manual_spawn()

func _should_allow_manual_spawn() -> bool:
	"""Check if manual spawning is allowed"""
	return !ball_spawned and !SettingsManager.settings_opened

func _is_spawn_input_pressed() -> bool:
	"""Check if spawn input was pressed"""
	return Input.is_action_just_pressed("spawnball_1") or Input.is_action_just_pressed("spawnball_2")

func _handle_manual_spawn() -> void:
	"""Handle manual ball spawn based on mode"""
	match current_mode:
		GameMode.SOLO, GameMode.LOCAL:
			if current_mode == GameMode.LOCAL and spawned_players.size() < 2:
				return
			_spawn_ball_local()
		GameMode.NETWORK:
			if is_network_server:
				_spawn_ball_network()
			else:
				_request_ball_spawn.rpc_id(1)

# ========================================
# AREA DETECTION
# ========================================

func _on_player_one_side_body_entered(body: Node2D) -> void:
	if not body.is_in_group("ball"):
		return
	if current_mode == GameMode.NETWORK and not is_network_server:
		return
	body.current_player_side = 1

func _on_player_two_side_body_entered(body: Node2D) -> void:
	if not body.is_in_group("ball"):
		return
	if current_mode == GameMode.NETWORK and not is_network_server:
		return
	body.current_player_side = 2

func _on_block_zone_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and "in_blockzone" in body:
		body.in_blockzone = true

func _on_block_zone_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and "in_blockzone" in body:
		body.in_blockzone = false
