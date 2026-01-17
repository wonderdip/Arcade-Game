extends Resource
class_name AudioLibrary

@export var sound_effects: Array[SoundEffect] = []

var last_played: SoundEffect

func get_audio_stream(tag: String) -> SoundEffect:
	var matches: Array[SoundEffect] = []

	for sound in sound_effects:
		if sound.tag == tag:
			matches.append(sound)

	if matches.is_empty():
		return null

	# If only one variant exists, return it
	if matches.size() == 1:
		last_played = matches[0]
		return matches[0]

	# If more than one variant exists
	var choice: SoundEffect = matches.pick_random()

	# Avoid repeating immediately if there is more than one variant
	if matches.size() > 1 and last_played != null:
		matches.push_back(last_played)
		choice = matches.get(0)
		
	# Remember what we just picked
	last_played = choice
	return choice

func add_sound(sound: SoundEffect):
	sound_effects.append(sound)
