extends Node

var camera2d: Camera2D
var cameraShakeNoise: FastNoiseLite

func _ready():
	
	cameraShakeNoise = FastNoiseLite.new()
	
func cam_shake(Max: float, Min: float, Length: float):
	var camera_tween = get_tree().create_tween()
	camera_tween.tween_method(StartCameraShake, Max, Min, Length)
	
func StartCameraShake(intensity: float):
	var cameraOffset = cameraShakeNoise.get_noise_1d(Time.get_ticks_msec()) * intensity
	camera2d.offset.x = cameraOffset
	camera2d.offset.y = cameraOffset
