extends Resource
class_name AudioLibrary

@export var sound_effects: Array[SoundEffect]

var last_played: Dictionary

func get_audio_stream(_tag: String) -> SoundEffect:
	var matches: Array[SoundEffect] = []

	for sound in sound_effects:
		if sound.tag == _tag:
			matches.append(sound)

	if matches.is_empty():
		return null

	if matches.size() == 1:
		last_played[_tag] = matches[0]
		return matches[0]

	var choice = matches.pick_random()
	if last_played.get(_tag) == choice:
		matches.erase(choice)
		choice = matches.pick_random()

	last_played[_tag] = choice
	return choice
