extends PanelContainer

class_name ActionBlock

@export var action: ActionResource

@onready var icon: TextureRect = $VBoxContainer/TextureRect
@onready var label: Label = $VBoxContainer/Label
@export var action_name: String = ""

func _ready():
	label.text = action_name

func _get_drag_data(_pos):
	var preview = Label.new()
	preview.text = action_name
	set_drag_preview(preview)
	return {"type": "action_block", "block": self}

func execute_action():
	# For now, just print. Later this will modify stats / trigger events.
	print("   ⏳ Executing action:", action_name)

#func _ready():
	#if action:
		#update_visuals()
#
#func update_visuals():
	## icon (optional, only if you add icon to ActionResource later)
	#if action.has_meta("icon"):
		#icon.texture = action.get_meta("icon")
	#else:
		#icon.visible = false
	#
	## label
	#label.text = "%s (%dh)" % [action.name, action.duration_slots]
#
#
#const PIXELS_PER_SLOT = 10
#
#func set_height_from_duration():
	#var total_slots = action.duration_slots
	#custom_minimum_size.y = total_slots * PIXELS_PER_SLOT
#
#func _get_drag_data(_pos):
	#var preview = Label.new()
	#preview.text = action_name
	#set_drag_preview(preview)
	#return {"type": "action_block", "block": self}
