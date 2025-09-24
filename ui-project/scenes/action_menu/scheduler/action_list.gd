extends VBoxContainer

@export var action_block_scene: PackedScene
@onready var tracker: Control = $"../../../ScheduleTracker"
var schedule_ref

# Example data (later you’ll replace with ActionResource list from GameData)
var available_actions := [
	{"name": "Read", "icon": preload("res://assets/ui_assets/Cha Icon.png")},
	{"name": "Sleep", "icon": preload("res://assets/ui_assets/Map Icon.png")},
	{"name": "Eat", "icon": preload("res://assets/ui_assets/Money Icon.png")},
]

func _ready():
	await get_tree().process_frame
	schedule_ref = tracker.action_block_list
	print(schedule_ref)
	_load_action_buttons()

func _load_action_buttons():
	# Clear any existing children
	for child in get_children():
		remove_child(child)
		child.queue_free()

	# Dynamically create buttons for each action
	for action in available_actions:
		var button := Button.new()
		button.text = action["name"]
		if action.has("icon") and action["icon"]:
			button.icon = action["icon"]

		button.pressed.connect(_on_action_button_pressed.bind(action["name"]))
		add_child(button)

func _on_action_button_pressed(action_name: String) -> void:
	var block = action_block_scene.instantiate()
	block.action_name = action_name
	schedule_ref.add_child(block)
