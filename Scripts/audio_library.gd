extends Resource
class_name AudioLibrary

@export var sound_effects: Array[SoundEffect]


func get_audio_stream(_tag: String) -> SoundEffect:
	if _tag == "":
		printerr("No tag provided, cannot get sound effect")
		return null
		
	for sound in sound_effects:
		if sound.tag == _tag:
			return sound

	printerr("No sound effect found for tag:", _tag)
	return null
