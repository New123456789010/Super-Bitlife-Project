extends Control

@onready var money_indicator: Label = $MarginContainer/MoneyIndicator/MarginContainer/VBoxContainer/%Label2
@onready var event_modal_panel: PanelContainer = $Control/EventModalPanel
@onready var get_money_button: Control = $GetMoneyButton
@onready var option_menu: PanelContainer = $OptionMenu
@onready var stats_menu: Control = $StatsMenu

var timeline : DialogicTimeline = DialogicTimeline.new()
var money: int
var menus := []

func _ready():
	menus = [option_menu, stats_menu]
	Dialogic.signal_event.connect(_on_dialogic_signal)
	money_indicator.text = str(GameData.total_assets)

func _on_money_button_pressed() -> void:
	GameData.total_assets += 100
	money_indicator.text = str(GameData.total_assets)


func _on_action_pressed() -> void:
	if Dialogic.current_timeline != null:
		return
	else: 
		Dialogic.start("finding_first_job")

func _on_dialogic_signal(argument: String):
	if argument == "show_newspaper_ads":
		event_modal_panel.visible = true
		get_money_button.visible = false
		

func close_all() -> void:
	for m in menus:
		m.visible = false
	
func _on_setting_button_pressed() -> void:
	if option_menu.visible:
		close_all()
	else:
		close_all()
		option_menu.visible = true
	
func _on_schedule_button_pressed() -> void:
	if stats_menu.visible:
		close_all()
	else:
		close_all()
		stats_menu.visible = true
	
	stats_menu.refresh_node()
	
