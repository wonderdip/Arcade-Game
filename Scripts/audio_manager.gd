extends AudioStreamPlayer2D

@export var audio_library: AudioLibrary
@export var custom_max_polyphony: int = 32

var master_vol: float = 100.0
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
	var type_vol := music_vol if sound_effect.type == SoundEffect.Type.Music else sfx_vol
	
	# Convert sliders to linear
	var master_linear := slider_to_linear(master_vol)
	var type_linear := slider_to_linear(type_vol)
	var final_linear := master_linear * type_linear
	
	if final_linear <= 0.00001:
		return
		
	# Convert to dB (avoid silence math issues)
	var vol_db := linear_to_db(max(final_linear, 0.00001))
	vol_db = min(vol_db, -9.0)
	
	var voice_id : int = polyphonic_playback.play_stream(sound_effect.stream, 0.0, vol_db, 1.0)
	if voice_id < 0:
		printerr("Failed to start stream for", _tag)
		return
		
func slider_to_linear(value: float) -> float:
	var normalized = clamp(value / 100.0, 0.0, 1.0)
	return pow(normalized, 1.8) # perceptual curve

func change_sfx_vol(volume: float) -> void:
	sfx_vol = clamp(volume, 0.0, 100.0)
	play_sound_from_library("click")
	print("SFX volume =", sfx_vol)

func change_music_vol(volume: float) -> void:
	music_vol = clamp(volume, 0.0, 100.0)
	print("Music volume =", music_vol)

func change_master_vol(volume: float) -> void:
	master_vol = clamp(volume, 0.0, 100.0)
