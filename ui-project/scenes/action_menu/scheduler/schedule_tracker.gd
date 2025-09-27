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

func _on_run_action_pressed() -> void:
	var blocks := action_block_list.get_children()
	# execute bottom-first (visual bottom is last rendered child when alignment=END)
	if blocks.size() > 0:
		var bottom_block := blocks[blocks.size() - 1]
		if bottom_block is ActionBlock:
			bottom_block.execute_action()
			bottom_block.queue_free()

# Run all action at once
#func _on_run_action_pressed() -> void:
	#var blocks := action_block_list.get_children()
	#for i in range(blocks.size() - 1, -1, -1): # from bottom to top
		#var block := blocks[i]
		#if block is ActionBlock:
			#block.execute_action()
			#block.queue_free()
