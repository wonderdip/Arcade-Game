extends Node

var camera2d: Camera2D
var cameraShakeNoise: FastNoiseLite

func _ready():
	cameraShakeNoise = FastNoiseLite.new()
	
	# Connect to multiplayer if needed
	if multiplayer.multiplayer_peer != null:
		multiplayer.peer_connected.connect(_on_peer_connected)

func _on_peer_connected(_id: int):
	pass  # Peer connected, ready to receive RPCs

# Original function now calls RPC version
func cam_shake(Max: float, Min: float, Length: float):
	# If in network mode, sync to all clients
	if multiplayer.multiplayer_peer != null and multiplayer.is_server():
		_cam_shake_rpc.rpc(Max, Min, Length)
	else:
		_do_cam_shake(Max, Min, Length)

# Server calls this RPC to sync shake to all clients
@rpc("authority", "call_local", "reliable")
func _cam_shake_rpc(Max: float, Min: float, Length: float):
	_do_cam_shake(Max, Min, Length)

# Actual shake logic
func _do_cam_shake(Max: float, Min: float, Length: float):
	if not camera2d:
		return
	var camera_tween = get_tree().create_tween()
	camera_tween.tween_method(StartCameraShake, Max, Min, Length)
	
func StartCameraShake(intensity: float):
	if not camera2d:
		return
	var cameraOffset = cameraShakeNoise.get_noise_1d(Time.get_ticks_msec()) * intensity
	camera2d.offset.x = cameraOffset
	camera2d.offset.y = cameraOffset

# Original function now calls RPC version
func framefreeze(duration: float, time_scale: float):
	# If in network mode, sync to all clients
	if multiplayer.multiplayer_peer != null and multiplayer.is_server():
		_framefreeze_rpc.rpc(duration, time_scale)
	else:
		_do_framefreeze(duration, time_scale)

# Server calls this RPC to sync freeze to all clients
@rpc("authority", "call_local", "reliable")
func _framefreeze_rpc(duration: float, time_scale: float):
	_do_framefreeze(duration, time_scale)

# Actual freeze logic
func _do_framefreeze(duration: float, time_scale: float):
	if time_scale > 0:
		Engine.time_scale = time_scale
		await get_tree().create_timer(duration * time_scale, true, false, true).timeout
		Engine.time_scale = 1.0
	else:
		Engine.time_scale = 0
		await get_tree().create_timer(duration, true, false, true).timeout
		AudioManager.play_sfx("afterhit")
		Engine.time_scale = 1.0
