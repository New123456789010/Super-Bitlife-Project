extends PanelContainer
@onready var bgmvolume: HSlider = $PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/BGMvolume

signal bgm_volume_changed(value: float)

func _ready() -> void:
	bgmvolume.value_changed.connect(_on_slider_changed)
	
func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")


func _on_slider_changed(value: float) -> void:
	emit_signal("bgm_volume_changed", value)
