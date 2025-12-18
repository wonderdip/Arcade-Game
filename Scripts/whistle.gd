extends Node2D

@onready var whistle_sprite: Sprite2D = $WhistleSprite

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var tween := get_tree().create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(whistle_sprite, "rotation_degrees", 15, 1.0)
	tween.tween_property(whistle_sprite, "rotation_degrees", -15, 1.0)
