extends PanelContainer

const TOTAL_SLOTS := 20
const START_AVAILABLE := 5

@onready var grid: GridContainer = $PanelContainer/MarginContainer/VBoxContainer/GridContainer
@onready var item_label: Label = $PanelContainer/MarginContainer/VBoxContainer/VBoxContainer2/ItemLabel
@onready var item_desc: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/VBoxContainer2/ItemDesc

var use_button: Button                    # optional; assigned in _ready()

var slot_buttons: Array[Button] = []      # typed button array
var slot_data: Array[Dictionary] = []     # each slot is a Dictionary; empty slot => {}

var selected_index: int = -1

func _ready() -> void:
	# (optional) get UseButton if you added it under VBoxContainer2
	use_button = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/VBoxContainer2/UseButton") as Button
	if is_instance_valid(use_button):
		use_button.text = "Use"
		use_button.disabled = true
		use_button.pressed.connect(_on_use_pressed)

	grid.columns = 5

	for i in range(TOTAL_SLOTS):
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(72, 72)
		b.disabled = i >= START_AVAILABLE
		b.text = ""
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_on_slot_pressed.bind(i))

		# icon display on Button
		b.expand_icon = true
		# b.icon_position = Button.ICON_POSITION_TOP  # uncomment if you also keep text
		# b.text_alignment = HorizontalAlignment.CENTER

		grid.add_child(b)
		slot_buttons.append(b)
		slot_data.append({})   # <-- strictly typed: empty slot is {}

	item_label.text = ""
	item_desc.text = ""

func _on_slot_pressed(index: int) -> void:
	selected_index = index
	var data: Dictionary = slot_data[index]
	if data.is_empty():
		item_label.text = "ItemName: (Empty)"
		item_desc.text = ""
		if is_instance_valid(use_button):
			use_button.disabled = true
		return

	item_label.text = "ItemName: " + str(data.get("name", ""))
	item_desc.text = str(data.get("desc", ""))

	if is_instance_valid(use_button):
		var qty: int = int(data.get("quantity", 1))
		var is_consumable: bool = str(data.get("type", "")) == "consumable"
		use_button.disabled = not (is_consumable and qty > 0)

func add_item(data: Dictionary) -> bool:
	# defaults for stackable/consumable items
	if not data.has("quantity"):
		data["quantity"] = 1
	if not data.has("max_stack"):
		data["max_stack"] = 99

	# 1) try to stack with same id & type
	for i in range(slot_buttons.size()):
		var cur: Dictionary = slot_data[i]
		if not cur.is_empty() and cur.get("id", "") == data.get("id", "") and cur.get("type", "") == data.get("type", ""):
			var total: int = int(cur.get("quantity", 1)) + int(data.get("quantity", 1))
			var max_stack: int = int(cur.get("max_stack", 99))
			var carry: int = max(total - max_stack, 0)
			cur["quantity"] = min(total, max_stack)
			_update_slot_visual(i)
			if carry == 0:
				return true
			else:
				data["quantity"] = carry
				# continue to place the remainder

	# 2) place in first unlocked empty slot
	for i in range(slot_buttons.size()):
		if not slot_buttons[i].disabled:
			var cur2: Dictionary = slot_data[i]
			if cur2.is_empty():
				slot_data[i] = data.duplicate(true)
				_update_slot_visual(i)
				return true
	return false

func _update_slot_visual(i: int) -> void:
	var d: Dictionary = slot_data[i]
	var b: Button = slot_buttons[i]
	if d.is_empty():
		b.icon = null
		b.text = ""
		b.tooltip_text = ""
		return

	var tex: Texture2D = d.get("icon", null) as Texture2D
	b.icon = tex

	var qty: int = int(d.get("quantity", 1))
	if qty > 1:
		b.text = "x%d" % qty
	else:
		b.text = ""

	b.tooltip_text = "%s\n%s" % [d.get("name", ""), d.get("desc", "")]

func _on_use_pressed() -> void:
	if selected_index < 0:
		return
	var d: Dictionary = slot_data[selected_index]
	if d.is_empty():
		return
	if str(d.get("type", "")) != "consumable":
		return

	_apply_consumable_effect(d)

	var qty2: int = int(d.get("quantity", 1)) - 1
	if qty2 <= 0:
		slot_data[selected_index] = {}
		item_label.text = "Item used."
		item_desc.text = ""
		if is_instance_valid(use_button):
			use_button.disabled = true
	else:
		d["quantity"] = qty2
		item_label.text = "ItemName: %s (x%d)" % [str(d.get("name", "")), qty2]

	_update_slot_visual(selected_index)

func _apply_consumable_effect(d: Dictionary) -> void:
	match str(d.get("id", "")):
		"potion":
			SignalBus.emit_signal("player_heal", 50)
		"elixir":
			SignalBus.emit_signal("player_restore_hp_mp", 9999)
		_:
			pass
