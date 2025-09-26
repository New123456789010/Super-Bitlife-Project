extends PanelContainer

class_name ActionBlock

@export var action: ActionResource

@onready var icon: TextureRect = $VBoxContainer/TextureRect
@onready var label: Label = $VBoxContainer/Label
@export var action_name: String = ""

func _ready():
	label.text = action_name
	# Ensure this control receives mouse events
	mouse_filter = Control.MOUSE_FILTER_STOP

# Called by Godot when the user starts dragging this Control
func _get_drag_data(_pos: Vector2) -> Dictionary:
	var preview := _make_drag_preview()
	preview.text = action_name
	set_drag_preview(preview)
	# Return a reference to self so ScheduleTrack can reorder
	return {"type": "action_block", "block": self}

func execute_action():
	# placeholder: replace with stat changes / trigger events / animations late.
	if action:
		print("   ⏳ Executing action:", action_name)
		action.apply(GameData.player_stats)
		print("Player Stats after action: ",
				"💪", GameData.player_stats.strength,
				" 🧠", GameData.player_stats.intelligence,
				" 😎", GameData.player_stats.charisma,
				" ⚡", GameData.player_stats.energy
)

func _make_drag_preview() -> Control:
	var p := Label.new()
	p.text = action_name
	p.custom_minimum_size = Vector2(120, 40)
	return p
