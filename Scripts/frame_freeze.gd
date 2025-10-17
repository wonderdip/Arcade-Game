extends Node

func framefreeze(duration: float, time_scale: float):
	if time_scale > 0:
		Engine.time_scale = time_scale
		await get_tree().create_timer(duration * time_scale, true, false, true).timeout
		Engine.time_scale = 1.0
	else:
		Engine.time_scale = 0
		await get_tree().create_timer(duration, true, false, true).timeout
		Engine.time_scale = 1.0
