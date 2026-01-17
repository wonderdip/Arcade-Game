extends Node2D

var audio_library: AudioLibrary
@export var max_concurrent_sounds := 48

var player_pool: Array[AudioStreamPlayer2D] = []
var last_sfx_played := {}  # tag -> SoundEffect

func _ready():
	randomize()
	# Create a pool of AudioStreamPlayer2D nodes
	for i in range(max_concurrent_sounds):
		var player = AudioStreamPlayer2D.new()
		player.bus = "SFX"
		add_child(player)
		player_pool.append(player)

func play_sfx(tag: String):
	# Get a SoundEffect variant
	var sfx: SoundEffect = audio_library.get_audio_stream(tag)
	if sfx == null or sfx.type != SoundEffect.Type.SFX:
		return

	# Find an available player (one that's not playing)
	var available_player: AudioStreamPlayer2D = null
	for player in player_pool:
		if not player.playing:
			available_player = player
			break
	
	# If all players are busy, use the first one (it will stop and restart)
	if available_player == null:
		available_player = player_pool[0]
	
	# Randomize pitch slightly for variety
	var pitch := randf_range(0.95, 1.05)
	
	# Play the sound
	available_player.stream = sfx.stream
	available_player.pitch_scale = pitch
	available_player.play()
