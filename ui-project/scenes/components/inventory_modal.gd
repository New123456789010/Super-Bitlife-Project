extends PanelContainer

const TOTAL_SLOTS := 20
const START_AVAILABLE := 5       # first N slots usable

@onready var grid: GridContainer = $PanelContainer/MarginContainer/VBoxContainer/GridContainer
@onready var item_label: Label = $PanelContainer/MarginContainer/VBoxContainer/VBoxContainer2/ItemLabel
@onready var item_desc: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/VBoxContainer2/ItemDesc

var slot_buttons: Array[Button] = []
var slot_data: Array = []   # each is Dictionary or null

func _ready() -> void:
	grid.columns = 5
	for i in range(TOTAL_SLOTS):
		var b := Button.new()
		b.custom_minimum_size = Vector2(72, 72)
		b.disabled = i >= START_AVAILABLE
		b.text = ""
		b.connect("pressed", Callable(self, "_on_slot_pressed").bind(i))
		grid.add_child(b)
		slot_buttons.append(b)
		slot_data.append(null)

	item_label.text = "ItemName:"
	item_desc.text = "<item description>"

func _on_slot_pressed(index: int) -> void:
	var data = slot_data[index]
	if data == null:
		item_label.text = "ItemName: (Empty)"
		item_desc.text = ""
		return
	item_label.text = "ItemName: " + str(data.name)
	item_desc.text = str(data.desc)

func add_item(data: Dictionary) -> bool:
	# Find first unlocked, empty slot
	for i in range(slot_buttons.size()):
		if !slot_buttons[i].disabled and slot_data[i] == null:
			slot_data[i] = data
			var b := slot_buttons[i]
			b.text = data.get("name", "")
			# If you have icons: b.icon = data.get("icon", null)
			return true
	return false  # inventory full or all unlocked slots used
