extends AudioStreamPlayer2D

@export var maximum_polyphony := 8
var audio_library: AudioLibrary
var music_db: float

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
		
	var tween = create_tween()
	volume_db = -80
	tween.tween_property(self, "volume_db", music_db, 2)
	playback.play_stream(sfx.stream)
	
