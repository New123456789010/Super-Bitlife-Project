extends Control
@onready var character_creation_menu: Control = $character_creation_menu
@onready var start_menu: Control = $StartMenu
@onready var option_menu: PanelContainer = $OptionMenu

func _ready():
	_connect_buttons(self)

func _connect_buttons(node: Node) -> void:
	for child in node.get_children():
		if child is Button:
			child.pressed.connect(_on_any_button_pressed)
		elif child.get_child_count() > 0:
			_connect_buttons(child)

func _on_any_button_pressed() -> void:
	GlobalSound.play_click()

func _on_new_game_pressed() -> void:
	start_menu.visible = false
	character_creation_menu.visible = true


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_options_pressed() -> void:
	option_menu.visible = true
