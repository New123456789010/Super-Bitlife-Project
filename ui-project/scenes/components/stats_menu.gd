extends Control

@onready var stats_window: VBoxContainer = $PanelContainer2/VBoxContainer/StatsWindow
@onready var paper_panel: PanelContainer = $PanelContainer2/VBoxContainer/PanelContainer
@onready var rich_text_label: RichTextLabel = $PanelContainer2/VBoxContainer/StatsWindow/PanelContainer/MarginContainer/Description
@export var job_description : String

func _ready() -> void:
	paper_panel.visible = false
	job_description = GameData.current_job.description
	rich_text_label.text = job_description
	print(GameData.current_job.name)
	
func refresh_node():
	job_description = GameData.current_job.description
	rich_text_label.text = job_description
	print(GameData.current_job.name)
	
func _on_back_button_pressed() -> void:
	if stats_window.visible == false && paper_panel.visible == true:
		stats_window.visible = true
		paper_panel.visible = false
	else:
		stats_window.visible = false
		paper_panel.visible = true


func _on_forward_button_pressed() -> void:
	if stats_window.visible == true && paper_panel.visible == false:
		stats_window.visible = false
		paper_panel.visible = true
	else:
		stats_window.visible = true
		paper_panel.visible = false
