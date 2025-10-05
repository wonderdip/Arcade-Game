extends RigidBody2D

signal update_score(current_player_side)

@export var normal_gravity_scale: float = 0.8
@export var hover_gravity_scale: float = 0.05
@export var hover_linear_damp: float = 1.2
@export var max_velocity: float = 500.0
@onready var landing_ray: RayCast2D = $LandingRay
@onready var landing_sprite: Sprite2D = $"Landing Sprite"

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

func _enter_tree() -> void:
	is_local_mode = Networkhandler.is_local
	
	# Set the server as the authority for the ball (only in network mode)
	if not is_local_mode:
		set_multiplayer_authority(1)

func _ready():
	normal_linear_damp = linear_damp
	body_entered.connect(_on_body_entered)
	
	if is_local_mode:
		# Local mode - always simulate physics
		freeze = false
		sleeping = false
		print("Ball spawned in local mode at position: ", global_position)
	elif multiplayer.is_server():
		# Network mode - only server simulates
		freeze = false
		sleeping = false
		print("Ball spawned on server at position: ", global_position)
	else:
		# Network client - just show the ball
		print("Ball spawned on client at position: ", global_position)

func _physics_process(_delta: float) -> void:
	# Keep the raycast pointing straight down in world space
	landing_ray.global_rotation = 0

	if landing_ray.is_colliding():
		var hit_point = landing_ray.get_collision_point()
		landing_sprite.global_position = hit_point

func _integrate_forces(state):
	# In local mode, always process. In network mode, only on server
	if not is_local_mode and not multiplayer.is_server():
		return
		
	# Cap velocity to prevent ball from going crazy
	var vel = state.linear_velocity
	if vel.length() > max_velocity:
		state.linear_velocity = vel.normalized() * max_velocity

func enter_hover_zone():
	if not is_hovering:
		is_hovering = true
		gravity_scale = hover_gravity_scale
		linear_damp = hover_linear_damp

func exit_hover_zone():
	if is_hovering:
		is_hovering = false
		gravity_scale = normal_gravity_scale
		linear_damp = normal_linear_damp

func _on_body_entered(body: Node):
	# In local mode, always process. In network mode, only on server
	if not is_local_mode and not multiplayer.is_server():
		return
		
	if scored:
		return
		
	# Only trigger when hitting something relevant (floor/pole/walls)
	if body is TileMapLayer or (body is StaticBody2D and (body.collision_layer & 4)):
		emit_signal("update_score", current_player_side)
		scored = true
		
		# Keep bouncing but ignore everything except layers 3, 4, 6
		var allowed_layers = (1 << 2) | (1 << 3) | (1 << 5)
		collision_mask = allowed_layers
