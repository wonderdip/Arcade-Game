extends Node2D

@export var audio_library: AudioLibrary
@export var custom_max_polyphony: int = 32

var master_vol: float = 100.0
var sfx_vol: float = 50.0
var music_vol: float = 50.0

@onready var music_player: AudioStreamPlayer2D = $MusicPlayer
@onready var sfx_player: AudioStreamPlayer2D = $SFXPlayer

func _ready() -> void:
	randomize()
	music_player.audio_library = audio_library
	sfx_player.audio_library = audio_library
	play_music("jazzy")
	
func set_bus_volume(bus_name: String, slider_value: float) -> void:
	
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return
	
	var linear := slider_to_linear(slider_value)
	var db := linear_to_db(max(linear, 0.00001))
	AudioServer.set_bus_volume_db(bus_index, db)
	play_sfx("click")
	
func slider_to_linear(value: float) -> float:
	var normalized = clamp(value / 100.0, 0.0, 1.0)
	return pow(normalized, 1.8) # perceptual curve

func play_music(tag: String):
	music_player.play_music(tag)

func play_sfx(tag: String):
	sfx_player.play_sfx(tag)
