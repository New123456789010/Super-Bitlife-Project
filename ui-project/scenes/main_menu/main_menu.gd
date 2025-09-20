extends Control
@onready var character_creation_menu: Control = $character_creation_menu
@onready var start_menu: Control = $StartMenu
@onready var option_menu: PanelContainer = $OptionMenu


func _on_new_game_pressed() -> void:
	start_menu.visible = false
	character_creation_menu.visible = true


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_options_pressed() -> void:
	option_menu.visible = true
