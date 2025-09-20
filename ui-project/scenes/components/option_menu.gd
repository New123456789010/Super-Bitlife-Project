extends PanelContainer
@onready var bgmvolume: HSlider = $PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/BGMvolume
@onready var option_menu: PanelContainer = $"."

signal bgm_volume_changed(value: float)

func _ready() -> void:
	bgmvolume.value_changed.connect(_on_slider_changed)
	
func _on_button_pressed() -> void:
	option_menu.visible = false


func _on_slider_changed(value: float) -> void:
	emit_signal("bgm_volume_changed", value)
