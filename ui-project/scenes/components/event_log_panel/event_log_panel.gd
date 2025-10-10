extends Control

@onready var EventPanel: Panel = $Panel

func _ready():
	var intro = GameData.load_timeline("res://dialogic_timeline/heinrich1.json")
	SignalBus.start_timeline.emit(intro)
	SignalBus.timeline_ended.connect(_on_timeline_ended)

func _on_timeline_ended():
	hide() # or queue_free(), or transition scene

func _input(event):
	if event.is_action_pressed("ui_accept") or event is InputEventMouseButton and event.pressed:
		SignalBus.advance.emit()
