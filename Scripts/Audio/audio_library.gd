extends Resource
class_name AudioLibrary

@export var sound_effects: Array[SoundEffect] = []
var last_played: Dictionary = {}  # tag -> SoundEffect (track per tag, not globally)

func get_audio_stream(tag: String) -> SoundEffect:
	var matches: Array[SoundEffect] = []
	
	for sound in sound_effects:
		if sound.tag == tag:
			matches.append(sound)
	
	if matches.is_empty():
		return null
	
	# If only one variant exists, return it
	if matches.size() == 1:
		last_played[tag] = matches[0]
		return matches[0]
	
	# If more than one variant exists, pick randomly but avoid immediate repeats
	var choice: SoundEffect
	var last_for_this_tag = last_played.get(tag, null)
	
	# Remove the last played variant from options (if it exists)
	if last_for_this_tag != null and last_for_this_tag in matches:
		var filtered_matches = matches.filter(func(s): return s != last_for_this_tag)
		# Only use filtered list if we still have options
		if not filtered_matches.is_empty():
			choice = filtered_matches.pick_random()
		else:
			# Fallback if somehow all matches are the same
			choice = matches.pick_random()
	else:
		choice = matches.pick_random()
	
	# Remember what we just picked for this tag
	last_played[tag] = choice
	return choice

func add_sound(sound: SoundEffect):
	sound_effects.append(sound)
