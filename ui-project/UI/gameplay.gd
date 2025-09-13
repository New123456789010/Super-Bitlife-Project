extends Control

@onready var control_2: Label = $Control2/HBoxContainer/MarginContainer/PanelContainer/MarginContainer/VBoxContainer/%Label2

var money: int

func _on_button_pressed() -> void:
	money += 100
	control_2.text = "%.2f" %money
