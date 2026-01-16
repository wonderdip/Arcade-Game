extends AudioStreamPlayer2D

@export var maximum_polyphony := 8
var audio_library: AudioLibrary

func _ready():
	stream = AudioStreamPolyphonic.new()
	stream.polyphony = max_polyphony
	play()
	
func play_music(tag: String):
	var sfx: SoundEffect = audio_library.get_audio_stream(tag)
	if sfx == null or sfx.type != SoundEffect.Type.Music:
		return
	
	var playback := get_stream_playback()
	if playback == null:
		return
	
	playback.play_stream(sfx.stream)
