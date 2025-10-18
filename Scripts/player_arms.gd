extends Area2D

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_hitting: bool = false
var is_bumping: bool = false
var is_blocking: bool = false
var is_setting: bool = false
var facing_right: bool = true
var hit_bodies: Dictionary = {}  # Tracks last hit time for each ball

@export var hit_force: float = 50.0
@export var downward_force: float = -20.0
@export var bump_force: float = 10.0
@export var bump_upward_force: float = -25.0
@export var set_force: float = 40
@export var set_upward_force: float = -40
@export var hit_cooldown: float = 0.2
@export var max_ball_speed: float = 400.0

var is_network_mode: bool = false

func _ready():
	is_network_mode = multiplayer.multiplayer_peer != null
	
	monitoring = true
	monitorable = true
	collision_shape.disabled = true
	
	# Connect signals safely using method references
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func swing():
	if not is_hitting and not is_bumping:
		is_hitting = true
		hit_bodies.clear()
		collision_shape.disabled = false
		anim.play("Hit")

func bump():
	if not is_bumping and not is_hitting and not is_blocking and not is_setting:
		is_bumping = true
		hit_bodies.clear()
		collision_shape.disabled = false
		anim.play("Bump") 

func block():
	if not is_hitting and not is_blocking:
		is_blocking = true
		hit_bodies.clear()
		collision_shape.disabled = false
		anim.play("Block")

func setting():
	if not is_setting and not is_bumping and not is_hitting and not is_blocking:
		is_setting = true
		hit_bodies.clear()
		collision_shape.disabled = false
		anim.play("Set")

func stop_setting():
	is_setting = false
	cleanup_anim()

func stop_hit():
	is_hitting = false
	cleanup_anim()

func stop_bump():
	is_bumping = false
	cleanup_anim()

func stop_block():
	is_blocking = false
	cleanup_anim()

func cleanup_anim():
	hit_bodies.clear()
	collision_shape.disabled = true
	anim.stop()
	anim.play("RESET")
	visible = false

# Called when a body enters the arm's area
func _on_body_entered(body: Node):
	if not (is_hitting or is_bumping or is_blocking or is_setting):
		return
	if not (body.is_in_group("ball") and body is RigidBody2D):
		return
	if not "scored" in body or body.scored:
		return

	var current_time = Time.get_ticks_msec() / 1000.0
	if body in hit_bodies and current_time - hit_bodies[body] < hit_cooldown:
		return

	# Ball must be above the arms
	if body.global_position.y > collision_shape.global_position.y + 3:
		return

	print("Ball collision detected! Network mode: ", is_network_mode)
	
	# In network mode, send hit to server
	if is_network_mode and not multiplayer.is_server():
		# Client: Send RPC to server with hit information
		print("Client sending hit RPC to server")
		_request_ball_hit.rpc_id(1, body.get_path(), collision_shape.global_position, facing_right, is_hitting, is_bumping, is_blocking, is_setting)
	else:
		# Server or local mode - apply directly
		_apply_hit_to_ball(body)
	
	hit_bodies[body] = current_time

# RPC called by clients to request ball hit on server
@rpc("any_peer", "call_remote", "reliable")
func _request_ball_hit(ball_path: NodePath, contact_pos: Vector2, face_right: bool, hitting: bool, bumping: bool, blocking: bool, is_set: bool):
	# Only server processes this
	if not multiplayer.is_server():
		return
	
	print("Server received hit RPC for ball at: ", ball_path)
	
	var ball = get_node_or_null(ball_path)
	if not ball or not is_instance_valid(ball):
		print("Ball not found or invalid")
		return
	if not ball.is_in_group("ball"):
		print("Not a ball")
		return
	if "scored" in ball and ball.scored:
		print("Ball already scored")
		return
	
	print("Applying hit to ball on server")
	# Apply hit using the contact position and facing direction from client
	_apply_hit_to_ball_server(ball, contact_pos, face_right, hitting, bumping, blocking, is_set)

func _on_body_exited(body: Node):
	# Allow ball to be hit again after cooldown
	if body.is_in_group("ball") and body in hit_bodies:
		var current_time = Time.get_ticks_msec() / 1000.0
		hit_bodies[body] = current_time - hit_cooldown + 0.05

func _apply_hit_to_ball(body: RigidBody2D):
	var impulse: Vector2
	var hit_direction: Vector2
	var contact_point = collision_shape.global_position

	# Get current velocity before hit
	var ball_vel = body.linear_velocity

	# Optional: reduce or cancel downward velocity
	if ball_vel.y > 0:
		body.linear_velocity.y = ball_vel.y * 0.1  # or 0 for full reset

	if is_bumping:
		hit_direction = Vector2(0.2 if facing_right else -0.2, -1).normalized()
		impulse = hit_direction * bump_force + Vector2(0, bump_upward_force)
	elif is_hitting or is_blocking:
		hit_direction = Vector2(1 if facing_right else -1, -0.2).normalized()
		impulse = hit_direction * hit_force + Vector2(0, -downward_force)
		CamShake.cam_shake(2, 1, 0.3)
		FrameFreeze.framefreeze(0.2, 0)
	elif is_setting:
		hit_direction = Vector2(0.2 if facing_right else -0.2, -1).normalized()
		impulse = hit_direction * set_force + Vector2(0, set_upward_force)

	body.apply_impulse(impulse, contact_point - body.global_position)

	# Cap the speed
	await get_tree().process_frame
	if body.linear_velocity.length() > max_ball_speed:
		body.linear_velocity = body.linear_velocity.normalized() * max_ball_speed

# Server-side hit application (used when called via RPC)
func _apply_hit_to_ball_server(body: RigidBody2D, contact_point: Vector2, face_right: bool, hitting: bool, bumping: bool, blocking: bool, is_set: bool):
	var impulse: Vector2
	var hit_direction: Vector2

	# Get current velocity before hit
	var ball_vel = body.linear_velocity

	# Optional: reduce or cancel downward velocity
	if ball_vel.y > 0:
		body.linear_velocity.y = ball_vel.y * 0.1

	if bumping:
		hit_direction = Vector2(0.2 if face_right else -0.2, -1).normalized()
		impulse = hit_direction * bump_force + Vector2(0, bump_upward_force)
	elif hitting or blocking:
		hit_direction = Vector2(1 if face_right else -1, -0.2).normalized()
		impulse = hit_direction * hit_force + Vector2(0, -downward_force)
	elif is_set:
		hit_direction = Vector2(0.2 if face_right else -0.2, -1).normalized()
		impulse = hit_direction * set_force + Vector2(0, set_upward_force)

	body.apply_impulse(impulse, contact_point - body.global_position)

	# Cap the speed
	await get_tree().process_frame
	if is_instance_valid(body) and body.linear_velocity.length() > max_ball_speed:
		body.linear_velocity = body.linear_velocity.normalized() * max_ball_speed

func sprite_direction(sprite_dir: float):
	if sprite_dir > 0:
		if not facing_right:
			facing_right = true
			scale.x = 1
	elif sprite_dir < 0:
		if facing_right:
			facing_right = false
			scale.x = -1

func _on_animation_player_animation_finished(anim_name: StringName) -> void: 
	if anim_name == "Hit": 
		is_hitting = false 
		hit_bodies.clear() 
		collision_shape.disabled = true 
		visible = false 
		
	elif anim_name == "Block":
		is_blocking = false 
		hit_bodies.clear() 
		collision_shape.disabled = true 
		visible = false 
		
	elif anim_name == "Bump": # Don't clear when bump animation finishes if still holding button
		pass
		
	elif anim_name == "Set":
		pass
