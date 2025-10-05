extends RigidBody2D

signal update_score(current_player_side)

@export var normal_gravity_scale: float = 0.8
@export var hover_gravity_scale: float = 0.05
@export var hover_linear_damp: float = 1.2
@export var max_velocity: float = 500.0  # Maximum speed the ball can reach
@onready var landing_ray: RayCast2D = $LandingRay
@onready var landing_sprite: Sprite2D = $"Landing Sprite"
var current_player_side: int = 0


func _physics_process(_delta: float) -> void:
	# Keep the raycast pointing straight down in world space
	landing_ray.global_rotation = 0  # 0 radians = world downwards if your cast direction is (0, 1)

	if landing_ray.is_colliding():
		var hit_point = landing_ray.get_collision_point()
		landing_sprite.global_position = hit_point

var normal_linear_damp: float = 0.5
var is_hovering: bool = false


func _ready():
	normal_linear_damp = linear_damp
	body_entered.connect(_on_body_entered)


func _integrate_forces(state):
	# Cap velocity to prevent ball from going crazy
	var vel = state.linear_velocity
	if vel.length() > max_velocity:
		state.linear_velocity = vel.normalized() * max_velocity


func enter_hover_zone():
	if not is_hovering:
		is_hovering = true
		gravity_scale = hover_gravity_scale
		linear_damp = hover_linear_damp
		print("Ball entering hover zone")


func exit_hover_zone():
	if is_hovering:
		is_hovering = false
		gravity_scale = normal_gravity_scale
		linear_damp = normal_linear_damp
		print("Ball exiting hover zone")


func _on_body_entered(body: Node):
	if body is TileMapLayer:
		print("Ball hit the ground - deleting")
		emit_signal("update_score", current_player_side)
		queue_free()
	elif body is StaticBody2D:
		if body.collision_layer & 4:
			print("Ball hit the ground - deleting")
			emit_signal("update_score", current_player_side)
			queue_free()
