extends Control
@onready var start_menu: Control = $"../StartMenu"
@onready var character_creation_menu: Control = $"."


func _on_back_button_pressed() -> void:
	start_menu.visible = true
	character_creation_menu.visible = false


func _on_button_pressed() -> void:
	self.visible = !self.visible
	get_tree().change_scene_to_file("res://scenes/gameplay/gameplay.tscn")
