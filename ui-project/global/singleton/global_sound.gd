# GlobalSound.gd
extends Node

# Preload your sounds
@export var click_sound: AudioStream = preload("res://global/singleton/SFX.mp3")
@export var other_sound: AudioStream

# Or you can load dynamically
var _audio_players: Dictionary = {}

func _ready() -> void:
	# Create AudioStreamPlayer for click
	var click_player = AudioStreamPlayer.new()
	add_child(click_player)
	_audio_players["click"] = click_player

	var other_player = AudioStreamPlayer.new()
	add_child(other_player)
	_audio_players["other"] = other_player

func play_click() -> void:
	var player = _audio_players.get("click")
	if player:
		player.stream = click_sound
		player.play()

func play_other() -> void:
	var player = _audio_players.get("other")
	if player:
		player.stream = other_sound
		player.play()

#func play_sound(name: String, stream: AudioStream) -> void:
	## General method: you can play any given stream
	#var player = _audio_players.get(name)
	#if not player:
		#player = AudioStreamPlayer.new()
		#add_child(player)
		#_audio_players[name] = player
	#player.stream = stream
	#player.play()
