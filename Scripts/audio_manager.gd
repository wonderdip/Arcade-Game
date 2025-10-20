extends AudioStreamPlayer2D

@export var audio_library: AudioLibrary
@export var custom_max_polyphony: int = 32

var sfx_vol: float = 50.0
var music_vol: float = 50.0

func _ready() -> void:
	# Use a polyphonic stream on this player
	stream = AudioStreamPolyphonic.new()
	stream.polyphony = custom_max_polyphony
	volume_db = 0.0 # ensure parent node doesn't scale voices
	play() # activate the playback instance

func play_sound_from_library(_tag: String) -> void:
	if _tag == "":
		printerr("No tag provided, cannot play sound effect!")
		return

	var sound_effect: SoundEffect = audio_library.get_audio_stream(_tag)
	if sound_effect == null:
		printerr("Audio effect not found for tag:", _tag)
		return

	var polyphonic_playback := get_stream_playback()
	if polyphonic_playback == null:
		printerr("Polyphonic playback not initialized!")
		return
	
	# Choose slider based on effect type
	var slider_value := music_vol if sound_effect.type == SoundEffect.Type.Music else sfx_vol
	
	# Convert 0–100 slider to a nice curve and then to dB
	var normalized = pow(slider_value / 100.0, 2.5) # linear 0..1 curve shaping
	var vol_db = linear_to_db(max(normalized, 0.00001)) # avoid log(0)
	
	var voice_id : int = polyphonic_playback.play_stream(sound_effect.stream, 0.0, vol_db, 1.0)
	if voice_id < 0:
		printerr("Failed to start stream for", _tag)
		return

func change_sfx_vol(volume: float) -> void:
	sfx_vol = clamp(volume, 0.0, 100.0)
	play_sound_from_library("click")
	print("SFX volume =", sfx_vol)

func change_music_vol(volume: float) -> void:
	music_vol = clamp(volume, 0.0, 100.0)
	print("Music volume =", music_vol)
