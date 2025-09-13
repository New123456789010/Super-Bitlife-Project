extends Control

@onready var v_box_container: VBoxContainer = $Control/TextureRect/PanelContainer2/VBoxContainer/PanelContainer/MarginContainer/VBoxContainer

@onready var panel_container_3: PanelContainer = $Control/TextureRect/PanelContainer3

func _on_button_pressed() -> void:
	panel_container_3.visible = true
