extends Control

@onready var money_indicator: Label = $MarginContainer/HBoxContainer/VBoxContainer/MoneyIndicator/MarginContainer/VBoxContainer/%Label2
@onready var event_modal_panel: PanelContainer = $Control/EventModalPanel
@onready var get_money_button: Control = $GetMoneyButton
@onready var option_menu: PanelContainer = $OptionMenu
@onready var stats_menu: Control = $StatsMenu
@onready var schedule_tracker: Control = $Control/ScheduleTracker
@onready var bgm: AudioStreamPlayer = $BGM


var timeline : DialogicTimeline = DialogicTimeline.new()
var money: int
var menus := []

var show_newspaper_ads_event_fired := false

@export var map_scene: PackedScene 
var map_scene_node
var map_scene_instantiated := false

func _ready():
	menus = [option_menu, stats_menu,schedule_tracker,event_modal_panel]
	Dialogic.signal_event.connect(_on_dialogic_signal)
	money_indicator.text = str(GameData.total_assets)
	option_menu.bgm_volume_changed.connect(_on_child_volume_changed)
	_on_child_volume_changed(100)
	_connect_buttons(self)

func _on_child_volume_changed(value: float) -> void:
	var linear = value / 100.0
	bgm.volume_db = -80.0 if linear <= 0.0 else linear_to_db(linear)
	

func _connect_buttons(node: Node) -> void:
	for child in node.get_children():
		if child is Button:
			child.pressed.connect(_on_any_button_pressed)
		elif child.get_child_count() > 0:
			_connect_buttons(child)

func _on_any_button_pressed() -> void:
	GlobalSound.play_click()

func _on_money_button_pressed() -> void:
	GameData.total_assets += 100
	money_indicator.text = str(GameData.total_assets)


func _on_action_pressed() -> void:
	if Dialogic.current_timeline != null:
		return
	elif show_newspaper_ads_event_fired == false:
		close_all()
		Dialogic.start("finding_first_job")
	else:
		if event_modal_panel.visible:
			close_all()
		else:
			close_all()
			event_modal_panel.visible = true
		get_money_button.visible = false

func _on_dialogic_signal(argument: String):
	print(argument)
	if argument == "show_newspaper_ads":
		event_modal_panel.visible = true
		get_money_button.visible = false
		show_newspaper_ads_event_fired = true


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
	if schedule_tracker.visible:
		close_all()
	else:
		close_all()
		schedule_tracker.visible = true
		
	schedule_tracker.refresh_node()


func _on_stats_button_pressed() -> void:
	if stats_menu.visible:
		close_all()
	else:
		close_all()
		stats_menu.visible = true
	
	stats_menu.refresh_node()


func _on_map_button_pressed() -> void:
	if map_scene != null && map_scene_instantiated == false:
		map_scene_node = map_scene.instantiate()
		add_child(map_scene_node)
		map_scene_instantiated = true
		print(map_scene_instantiated)
	else:
		map_scene_node.visible = !map_scene_node.visible
