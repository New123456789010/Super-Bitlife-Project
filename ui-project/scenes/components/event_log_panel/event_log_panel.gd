extends Control

@onready var EventPanel: Panel = $Panel

func _ready():
	var intro = GameData.load_timeline("res://dialogic_timeline/demo_timeline.json")
	SignalBus.start_timeline.emit(intro)
