extends VBoxContainer
class_name ScheduleTrack

func _ready() -> void:
	# Blocks stacked bottom-up visually, align to END
	alignment = BoxContainer.ALIGNMENT_END

# Accept only action_block payloads
func _can_drop_data(_pos: Vector2, data) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.get("type", "") == "action_block"

# Called when a drop happens; pos is local to this container
func _drop_data(pos: Vector2, data) -> void:
	var block := data.get("block") as Control
	if not block:
		return

	# If dragged inside the same container: just move
	if block.get_parent() == self:
		var new_index := _get_drop_index(pos, block)
		move_child(block, new_index)
		return

	# If coming from another parent: reparent + insert at index
	var old_parent := block.get_parent()
	if old_parent:
		old_parent.remove_child(block)

	add_child(block) # temporarily add so sizes/positions update
	var insert_index := _get_drop_index(pos, block)
	move_child(block, insert_index)

# Compute insertion index based on y position
# local_pos : Vector2 (local to this container)
# dragging_block : optional control being dragged (we skip it when counting)
func _get_drop_index(local_pos: Vector2, dragging_block: Control = null) -> int:
	var idx := 0
	for i in range(get_child_count()):
		var child := get_child(i) as Control
		if child == dragging_block:
			# skip the dragging node when computing indices
			continue
		# child's rect position and size are valid after container layout
		var mid_y := child.position.y + child.size.y * 0.5
		if local_pos.y < mid_y:
			return idx
		idx += 1
	return idx
