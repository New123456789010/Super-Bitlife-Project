extends VBoxContainer

@export var action_block_scene: PackedScene
@onready var tracker: Control = $"../../ScheduleTracker"
var schedule_ref

@export var actions_folder: String = "res://actions"  # Folder path to load actions from

var available_actions: Array[ActionResource] = []

func _ready():
	await get_tree().process_frame
	schedule_ref = tracker.action_block_list
	print(schedule_ref)
	_load_actions_from_folder()
	_load_action_buttons()

func _load_actions_from_folder():
	available_actions.clear()
	var dir := DirAccess.open(actions_folder)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var res_path = actions_folder + "/" + file_name
				var res = load(res_path)
				if res is ActionResource:
					available_actions.append(res)
			file_name = dir.get_next()
		dir.list_dir_end()

func _load_action_buttons():
	# Clear existing buttons
	for child in get_children():
		child.queue_free()

	# Create buttons for each ActionResource
	for action in available_actions:
		var button := Button.new()
		button.text = action.name
		if action.icon:
			button.icon = action.icon
		button.pressed.connect(_on_action_button_pressed.bind(action))
		add_child(button)

func _on_action_button_pressed(action: ActionResource) -> void:
	var block = action_block_scene.instantiate()
	block.action = action
	schedule_ref.add_child(block)
