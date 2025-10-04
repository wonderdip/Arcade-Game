extends RigidBody2D

@export var normal_gravity_scale: float = 0.8
@export var hover_gravity_scale: float = 0.01
@export var hover_linear_damp: float = 2.0

var normal_linear_damp: float = 0.5
var is_hovering: bool = false


func _ready():
	normal_linear_damp = linear_damp


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
