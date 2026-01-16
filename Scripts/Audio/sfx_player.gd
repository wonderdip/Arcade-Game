extends AudioStreamPlayer2D

var audio_library: AudioLibrary
@export var maximum_polyphony := 32

func _ready():
	stream = AudioStreamPolyphonic.new()
	stream.polyphony = max_polyphony
	play()
	randomize()

func play_sfx(tag: String):
	var sfx: SoundEffect = audio_library.get_audio_stream(tag)
	if sfx == null or sfx.type != SoundEffect.Type.SFX:
		return
	
	var playback := get_stream_playback()
	if playback == null:
		return
	
	var pitch := randf_range(0.95, 1.05)
	playback.play_stream(sfx.stream, 0.0, 0.0, pitch)
