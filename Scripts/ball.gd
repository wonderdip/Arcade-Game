extends RigidBody2D

signal update_score(current_player_side)

@export var normal_gravity_scale: float = 0.8
@export var hover_gravity_scale: float = 0.05
@export var hover_linear_damp: float = 1.2
@export var max_velocity: float = 500.0
@onready var landing_ray: RayCast2D = $LandingRay
@onready var landing_sprite: Sprite2D = $"Landing Sprite"
@onready var fire_particle: GPUParticles2D = $FireParticle
@onready var blue_fire_particle: GPUParticles2D = $BlueFireParticle
@onready var freeze_timer: Timer = $FreezeTimer
@onready var blink_timer: Timer = $BlinkTimer
@onready var ball_sprite: Sprite2D = $BallSprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer

const MAX_POSITION = 10000.0  # Maximum allowed position value
const MIN_POSITION = -1000.0  # Minimum allowed position value

# These need to be synced
var current_player_side: int = 0:
	set(value):
		current_player_side = value
var scored: bool = false:
	set(value):
		scored = value

var normal_linear_damp: float = 0.5
var is_hovering: bool = false
var is_local_mode: bool = false
var is_solo_mode: bool = false
var launcher_is_parent: bool = false

func _ready() -> void:
	normal_linear_damp = linear_damp
	fire_particle.emitting = false
	blue_fire_particle.emitting = false
	
	if !launcher_is_parent:
		setup_ball()
		
	is_local_mode = Networkhandler.is_local
	is_solo_mode = Networkhandler.is_solo
	# CRITICAL FIX: Set the server as the authority for the ball (only in network mode)
	if !is_local_mode and !is_solo_mode:
		if multiplayer.is_server():
			# Server is ALWAYS authority 1
			set_multiplayer_authority(1)
			print("Ball: Server set as authority")
			
	if is_local_mode or is_solo_mode:
		# Local mode - always simulate physics
		sleeping = false
	elif multiplayer.is_server():
		# Network mode - server simulates fully
		sleeping = false
		print("Ball: Server ready, physics enabled")
	else:
		# Clients still need collision detection but don't modify physics
		sleeping = false
		contact_monitor = true
		max_contacts_reported = 1
		print("Ball: Client ready, authority is ", get_multiplayer_authority())
		
func setup_ball():
	freeze_timer.start()
	gravity_scale = 0
	blink(1)
	
func blink(length: float):
	var blink_speed = 0.1  # Time between blinks (fixed speed)
	var blink_count = min(10, int(length / blink_speed) * 2)  # Ensure even count
	
	blink_timer.wait_time = blink_speed
	
	for i in range(blink_count):
		blink_timer.start()
		await blink_timer.timeout
		animation_player.play("blink")
		
func _on_freeze_timer_timeout() -> void:
	sleeping = false
	gravity_scale = normal_gravity_scale
	
func _physics_process(_delta: float) -> void:
	# Keep the raycast pointing straight down in world space
	landing_ray.global_rotation = 0

	if landing_ray.is_colliding():
		var hit_point: Vector2 = landing_ray.get_collision_point()
		landing_sprite.global_position = hit_point
		landing_sprite.global_rotation = 0

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# In local mode, always process. In network mode, only on server
	if (not is_local_mode and not is_solo_mode) and not multiplayer.is_server():
		return
	
	# Safety check for position
	var pos = state.transform.origin
	if abs(pos.x) > MAX_POSITION or abs(pos.y) > MAX_POSITION or pos.y < MIN_POSITION:
		push_warning("Ball position out of bounds! Resetting. Pos: " + str(pos))
		# Reset to center top
		state.transform.origin = Vector2(128, -40)
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0
		return
	
	# Cap velocity to prevent ball from going crazy
	var vel: Vector2 = state.linear_velocity
	if vel.length() > max_velocity:
		state.linear_velocity = vel.normalized() * max_velocity
	
	# Cap angular velocity too
	if abs(state.angular_velocity) > 10.0:
		state.angular_velocity = sign(state.angular_velocity) * 10.0
	
	
func enter_hover_zone() -> void:
	if not is_hovering:
		is_hovering = true
		gravity_scale = hover_gravity_scale
		linear_damp = hover_linear_damp

func exit_hover_zone() -> void:
	if is_hovering:
		is_hovering = false
		gravity_scale = normal_gravity_scale
		linear_damp = normal_linear_damp

func _on_body_entered(body: Node) -> void:
	# In local mode, always process. In network mode, only on server
	AudioManager.play_sfx("ballbounce")
	
	if (not is_local_mode and not is_solo_mode) and not multiplayer.is_server():
		return
		
	if scored:
		return
		
	# Only trigger when hitting something relevant (floor/pole/walls)
	if body is TileMapLayer or (body is StaticBody2D and (body.collision_layer & 4)):
		emit_signal("update_score", current_player_side)
		scored = true
		
		# Keep bouncing but ignore everything except layers 3, 4, 6
		var allowed_layers: int = (1 << 2) | (1 << 3) | (1 << 5)
		collision_mask = allowed_layers

func delete_self():
	queue_free()
