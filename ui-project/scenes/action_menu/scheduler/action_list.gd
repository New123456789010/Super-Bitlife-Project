extends VBoxContainer

@export var action_block_scene: PackedScene
@export var schedule_track: NodePath
var schedule_ref: VBoxContainer

func _ready():
	schedule_ref = get_node(schedule_track)

func _on_action_button_pressed(action_name: String):
	var block = action_block_scene.instantiate()
	block.action_name = action_name
	schedule_ref.add_child(block)
