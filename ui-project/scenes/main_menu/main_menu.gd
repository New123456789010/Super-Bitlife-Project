extends Control
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer


func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/character_creation/character_creation.tscn")


func _on_exit_pressed() -> void:
	get_tree().quit()
