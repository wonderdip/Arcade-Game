extends Area2D

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_hitting: bool = false
var is_bumping: bool = false
var is_blocking: bool = false
var is_setting: bool = false
var facing_right: bool = true
var hit_bodies: = {} # body -> true (or just use a Set)
var body_hit_cooldowns: Dictionary = {}  # body -> time_remaining
var last_hit_time: Dictionary = {}  # body -> timestamp of last hit
var touch_counter: int = 0

@export var hit_force: float = 50.0
@export var downward_force: float = 20.0
@export var bump_force: float = 10.0
@export var bump_upward_force: float = 25.0
@export var set_force: float = 40
@export var set_upward_force: float = 40
@export var hit_cooldown: float = 0.2
@export var max_ball_speed: float = 400.0
@export_range(0.0, 1.0, 0.1) var ball_control: float = 0.0  # 0 = no control, 1 = perfect control

@export var control_speed_threshold: float = 200.0  # Speed above which control kicks in
@export var shank_percentage: float = 0.4

var is_network_mode: bool = false
@onready var collision_particle: GPUParticles2D = $CollisionShape2D/CollisionParticle

var original_shape_size : Vector2 = Vector2(4.5, 20.0)

func _ready():
	if !Networkhandler.is_solo:
		if !Networkhandler.is_local:
			is_network_mode = multiplayer.multiplayer_peer != null
	
	monitoring = true
	monitorable = true
	
	# Ensure collision shape exists and is properly initialized
	if collision_shape:
		collision_shape.disabled = false
		if collision_shape.shape is CapsuleShape2D:
			original_shape_size = Vector2(collision_shape.shape.radius, collision_shape.shape.height)
	else:
		push_error("CollisionShape2D not found in player_arms!")
		
func set_collision_shape(disabled: bool):
	if disabled:
		collision_shape.shape.radius = 0
		collision_shape.shape.height = 0
	else:
		collision_shape.shape.radius = original_shape_size.x
		collision_shape.shape.height = original_shape_size.y
		
		
func _process(delta: float) -> void:
	# Update cooldowns
	var bodies_to_remove = []
	for body in body_hit_cooldowns:
		body_hit_cooldowns[body] -= delta
		if body_hit_cooldowns[body] <= 0:
			bodies_to_remove.append(body)
	
	for body in bodies_to_remove:
		body_hit_cooldowns.erase(body)

# Called when a body enters the arm's area
func _on_body_entered(body: Node):
	if not (is_hitting or is_bumping or is_blocking or is_setting):
		return
	if not (body.is_in_group("ball") and body is RigidBody2D):
		return
	if not "scored" in body or body.scored:
		return
	
	# For instant actions (hit, block), check cooldown
	if (is_hitting or is_blocking):
		if body_hit_cooldowns.has(body) and body_hit_cooldowns[body] > 0:
			return
		if hit_bodies.has(body):
			return
	
	# For hold actions (bump, set), allow continuous contact but with minimum interval
	if (is_bumping or is_setting):
		var current_time = Time.get_ticks_msec() / 1000.0
		if last_hit_time.has(body):
			var time_since_last = current_time - last_hit_time[body]
			# Minimum 0.2 seconds between hits from same hold action
			if time_since_last < 0.2:
				return
		last_hit_time[body] = current_time
	
	# In network mode, send hit to server
	if is_network_mode and not multiplayer.is_server():
		print("Client sending hit RPC to server")
		_request_ball_hit.rpc_id(1, body.get_path(), collision_shape.global_position, facing_right, is_hitting, is_bumping, is_blocking, is_setting)
	else:
		# Server or local mode - apply directly
		_apply_hit_to_ball(body)
	
	hit_bodies[body] = true
	
	# Set cooldown only for instant actions
	if is_hitting or is_blocking:
		body_hit_cooldowns[body] = hit_cooldown

func action(action_name: String, start: bool = true):
	match action_name:
		"hit":
			is_hitting = start
		"bump":
			is_bumping = start
		"block":
			is_blocking = start
		"set":
			is_setting = start
	
	# Handle the player arms
	if start:
		set_collision_shape(false)
		
		match action_name:
			"hit":
				anim.play("Hit")
			"bump":
				anim.play("Bump")
			"block":
				anim.play("Block")
			"set":
				anim.play("Set")
	else:
		# When stopping an action, clear hit tracking for that action only
		if action_name in ["hit", "block"]:
			# For instant actions, clear immediately
			hit_bodies.clear()
			body_hit_cooldowns.clear()
		elif action_name in ["bump", "set"]:
			# For hold actions, just clear the last hit times
			last_hit_time.clear()
			# Clear hit_bodies if no other action is active
			if not (is_hitting or is_bumping or is_blocking or is_setting):
				hit_bodies.clear()
		
		set_collision_shape(true)
		
		anim.stop()
		anim.play("RESET")

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

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("ball"):
		hit_bodies.erase(body)
		last_hit_time.erase(body)

func _apply_hit_to_ball(body: RigidBody2D):
	var contact_point = collision_shape.global_position
	var impulse = calculate_ball_hit(
		body,
		contact_point,
		facing_right,
		is_hitting,
		is_bumping,
		is_blocking,
		is_setting,
		ball_control
	)
	
	# Safety check for impulse magnitude
	if impulse.length() > 1000.0:
		push_warning("Impulse too large! Capping. Original: " + str(impulse))
		impulse = impulse.normalized() * 1000.0
	
	# Apply impulse with safety check
	var contact_offset = contact_point - body.global_position
	if contact_offset.length() > 50.0:  # If contact point is too far from ball center
		push_warning("Contact point too far from ball center! Using ball position.")
		contact_offset = Vector2.ZERO
	
	body.apply_impulse(impulse, contact_offset)
	body.animation_player.play("blink")
	
	if is_hitting or is_blocking:
		set_collision_shape(true)
		
	touch_counter += 1
	
	# Cap speed
	await get_tree().process_frame
	if body.linear_velocity.length() > max_ball_speed:
		body.linear_velocity = body.linear_velocity.normalized() * max_ball_speed

func _apply_hit_to_ball_server(body: RigidBody2D, contact_point: Vector2, face_right: bool, hitting: bool, bumping: bool, blocking: bool, is_set: bool):
	var impulse = calculate_ball_hit(
		body,
		contact_point,
		face_right,
		hitting,
		bumping,
		blocking,
		is_set,
		ball_control
	)
	# Safety check for impulse magnitude
	if impulse.length() > 1000.0:
		push_warning("Impulse too large! Capping. Original: " + str(impulse))
		impulse = impulse.normalized() * 1000.0
	
	# Apply impulse with safety check
	var contact_offset = contact_point - body.global_position
	if contact_offset.length() > 50.0:  # If contact point is too far from ball center
		push_warning("Contact point too far from ball center! Using ball position.")
		contact_offset = Vector2.ZERO
	
	body.apply_impulse(impulse, contact_offset)
	body.animation_player.play("blink")
	
	if is_hitting or is_blocking:
		set_collision_shape(true)
		
	touch_counter += 1
	
	# Cap speed
	await get_tree().process_frame
	if body.linear_velocity.length() > max_ball_speed:
		body.linear_velocity = body.linear_velocity.normalized() * max_ball_speed
		
func calculate_ball_hit(
	body: RigidBody2D,
	_contact_point: Vector2,
	face_right: bool,
	hitting: bool,
	bumping: bool,
	blocking: bool,
	is_set: bool,
	ball_control_val: float
) -> Vector2:
	
	var hit_direction: Vector2
	var ball_vel = body.linear_velocity
	var ball_speed = ball_vel.length()
	
	if bumping or is_set:
		if ball_speed > control_speed_threshold:
			var damping_factor = 1.0 - ball_control_val
			body.linear_velocity.x *= damping_factor
			
			if ball_vel.y > 0:
				var vertical_damping = lerp(0.1, 0.0, ball_control_val * 0.8)
				body.linear_velocity.y = ball_vel.y * vertical_damping
				
	else:
		if ball_vel.y > 0:
			body.linear_velocity.y = ball_vel.y * 0.1
			
	if bumping:
		var final_direction = get_random_direction(face_right, ball_control_val, 40)
		
		var horizontal_modifier = lerp(1.0, 0.5, ball_control_val)
		var adjusted_bump_force = bump_force * horizontal_modifier
		
		AudioManager.play_sfx("bump")
		collision_particle.global_position = body.global_position + Vector2(0, 8)
		collision_particle.emitting = true
		return final_direction * adjusted_bump_force + Vector2(0, -bump_upward_force)
		
	elif hitting:
		hit_direction = Vector2(1 if face_right else -1, -0.2).normalized()
		AudioManager.play_sfx("hit")
		ScreenFX.cam_shake(2, 1, 0.3)
		ScreenFX.framefreeze(0.2, 0)
		body.fire_particle.emitting = true
		return hit_direction * hit_force + Vector2(0, downward_force)
		
	elif blocking:
		hit_direction = Vector2(1 if face_right else -1, -0.2).normalized()
		AudioManager.play_sfx("hit")
		ScreenFX.cam_shake(2, 1, 0.3)
		ScreenFX.framefreeze(0.2, 0)
		body.fire_particle.emitting = true
		return hit_direction * (hit_force * 0.8) + Vector2(0, downward_force * 0.6)
		
	elif is_set:
		hit_direction = Vector2(0.2 if face_right else -0.2, -1).normalized()
		
		var horizontal_speed = abs(ball_vel.x)
		var horizontal_modifier = 1.0
		
		if horizontal_speed > control_speed_threshold:
			var speed_factor = clamp(horizontal_speed / (control_speed_threshold * 2.0), 0.0, 1.0)
			var effective_control = pow(ball_control_val * speed_factor, 2.0)
			horizontal_modifier = lerp(1.0, 0.1, effective_control)
			
		var final_direction = get_random_direction(face_right, ball_control_val, 20)
		
		horizontal_modifier = lerp(1.0, 0.5, ball_control_val)
		var adjusted_set_force = set_force * horizontal_modifier
		AudioManager.play_sfx("set")
		collision_particle.global_position = body.global_position + Vector2(0, 8)
		collision_particle.emitting = true
		return final_direction * adjusted_set_force + Vector2(0, -set_upward_force)
		
	return Vector2.ZERO

## Chooses random direction based on ball_control
func get_random_direction(face_right: bool, ball_control_val: float, max_angle: float) -> Vector2:
	
	var base_dir := Vector2(0, -1)
	
	# Randomness based on control
	var angle_randomness = max_angle * (1.0 - ball_control_val)
	# --- BACKWARD CHANCE ---
	
	var shank_chance = lerp(0.5, 0.0, ball_control_val)
	var is_shanking_backward = randf() < shank_chance
	var backward_bias_deg := 0.0
	
	if is_shanking_backward:
		backward_bias_deg = randf_range(-35.0, -10.0)  # random backward shank range
		var backward_bias = deg_to_rad(backward_bias_deg)
		
		# Random offset around the chosen direction
		var random_offset = deg_to_rad(randf_range(-angle_randomness, angle_randomness))
		
		var local_angle = backward_bias + random_offset
		var local_direction = base_dir.rotated(local_angle)
		
		# Flip horizontally depending on facing direction
		var side_multiplier = 1 if face_right else -1
		return Vector2(local_direction.x * side_multiplier, local_direction.y).normalized()
		
	return Vector2(0.3 if face_right else -0.3, -1).normalized()
	
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
		set_collision_shape(true)
		
	elif anim_name == "Block":
		is_blocking = false
		hit_bodies.clear()
		set_collision_shape(true
		)
	elif anim_name == "Bump":
		if is_bumping:
			anim.play("Bump")
		
	elif anim_name == "Set":
		if is_setting:
			anim.play("Set")
