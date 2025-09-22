extends Control

@onready var action_menu: VBoxContainer = $VBoxContainer/ActionPanel/ActionList
@onready var schedule_track: VBoxContainer = $ScheduleTrack
@onready var run_day_button: Button = $RunDayButton

func _ready():
	run_day_button.pressed.connect(_on_run_day_pressed)

func _on_run_day_pressed():
	print("▶ Starting daily schedule")
	for child in schedule_track.get_children():
		if child is PanelContainer and child.has_method("execute_action"):
			child.execute_action()
	print("✅ Day finished")
