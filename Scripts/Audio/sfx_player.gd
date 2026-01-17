extends AudioStreamPlayer2D

var audio_library: AudioLibrary
@export var maximum_polyphony := 32

var last_sfx_played := {}  # tag -> SoundEffect

func _ready():
	stream = AudioStreamPolyphonic.new()
	stream.polyphony = max_polyphony
	play()
	randomize()

func play_sfx(tag: String):
	# Get a SoundEffect variant that isn't the same as last played
	var sfx: SoundEffect = audio_library.get_audio_stream(tag)
	if sfx == null or sfx.type != SoundEffect.Type.SFX:
		return

	var playback := get_stream_playback()
	if playback == null:
		return

	# Randomize pitch slightly for variety
	var pitch := randf_range(0.95, 1.05)

	# Play the SFX on the polyphonic stream
	playback.play_stream(
		sfx.stream,
		0.0,   # start position
		0.0,   # volume (use bus volume)
		pitch
	)
