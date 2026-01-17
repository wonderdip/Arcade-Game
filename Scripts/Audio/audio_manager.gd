extends Node2D

@export var audio_library: AudioLibrary
@export var custom_max_polyphony: int = 32

var master_vol: float = 100.0
var sfx_vol: float = 50.0
var music_vol: float = 50.0

@onready var music_player: AudioStreamPlayer2D = $MusicPlayer
@onready var sfx_player: AudioStreamPlayer2D = $SFXPlayer

var fade_duration := 2.0 # seconds
var fade_timer := 0.0
var target_bus := "Music"
var fading_in := false

var music_vol_db: float

func _ready() -> void:
	randomize()
	
	# Only assign music tracks to music_player
	music_player.audio_library = get_library_by_type(SoundEffect.Type.Music)
	# Only assign SFX tracks to sfx_player
	sfx_player.audio_library = get_library_by_type(SoundEffect.Type.SFX)
	play_music("Menu")
	
func get_library_by_type(type: int) -> AudioLibrary:
	var new_lib := AudioLibrary.new()
	for sound in audio_library.sound_effects:
		if sound.type == type:
			new_lib.add_sound(sound)
	return new_lib
	
func set_bus_volume(bus_name: String, slider_value: float) -> void:
	
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return
	
	var linear := slider_to_linear(slider_value)
	var db := linear_to_db(max(linear, 0.00001))
	AudioServer.set_bus_volume_db(bus_index, db)
	
	if bus_name == "Music":
		music_player.music_db = AudioServer.get_bus_volume_db(bus_index)
		
	play_sfx("click")
	
func slider_to_linear(value: float) -> float:
	var normalized = clamp(value / 100.0, 0.0, 1.0)
	return pow(normalized, 1.8) # perceptual curve
		
func play_music(tag: String):
	music_player.play_music(tag)

func play_sfx(tag: String):
	sfx_player.play_sfx(tag)
