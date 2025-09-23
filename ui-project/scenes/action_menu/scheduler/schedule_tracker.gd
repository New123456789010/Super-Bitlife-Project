extends Control

@onready var action_block_list: VBoxContainer = %ActionBlockList

func refresh_node():
	pass
	
func _can_drop_data(_pos: Vector2, data) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.get("type") == "action_block"

func _drop_data(pos: Vector2, data) -> void:
	var block: Control = data["block"]
	if block.get_parent() != self:
		block.get_parent().remove_child(block)
		add_child(block)
	move_child(block, get_drop_index(pos))

func get_drop_index(pos: Vector2) -> int:
	for i in range(get_child_count()):
		var child = get_child(i)
		if pos.y < child.position.y + child.size.y / 2.0:
			return i
	return get_child_count()
