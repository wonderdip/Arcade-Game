extends Node2D

@onready var whistle_sprite: Sprite2D = $WhistleSprite
@onready var ref_sprite: Sprite2D = $RefSprite

func _ready() -> void:
	ref_sprite.hide()
	whistle_sprite.hide()
	
func call_point(side: int) -> void:
	whistle_sprite.show()
	
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(whistle_sprite, "rotation_degrees", 360, 1).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(whistle_sprite, "rotation_degrees", 0, 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	
	var size_tween : Tween = create_tween()
	whistle_sprite.scale = Vector2(0,0)
	size_tween.tween_property(whistle_sprite, "scale", Vector2(1, 1), 1).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	size_tween.tween_property(whistle_sprite, "scale", Vector2(0, 0), 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	AudioManager.play_sfx("long_whistle")
	await size_tween.finished
	
	
	match side:
		1:
			ref_sprite.flip_h = false
		2:
			ref_sprite.flip_h = true
			
	ref_sprite.show()
	ref_sprite.modulate.a = 0
	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(ref_sprite, "modulate:a", 1, 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	fade_tween.tween_property(ref_sprite, "modulate:a", 0, 1).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	await fade_tween.finished
	ref_sprite.hide()
