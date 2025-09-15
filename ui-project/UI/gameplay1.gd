extends Control

@onready var control_2: Label = $Control2/HBoxContainer/MarginContainer/PanelContainer/MarginContainer/VBoxContainer/%Label2
@onready var event_modal_panel: PanelContainer = $Control/EventModalPanel
@onready var get_money_button: Control = $GetMoneyButton

var timeline : DialogicTimeline = DialogicTimeline.new()
var money: int

func _ready():
	Dialogic.signal_event.connect(_on_dialogic_signal)

func _on_money_button_pressed() -> void:
	money += 100
	control_2.text = "%.2f" %money


func _on_action_pressed() -> void:
	if Dialogic.current_timeline != null:
		return
	else: 
		Dialogic.start("finding_first_job")

func _on_dialogic_signal(argument: String):
	if argument == "show_newspaper_ads":
		event_modal_panel.visible = true
		get_money_button.visible = false
		
