extends PanelContainer

const TOTAL_SLOTS := 20
const START_AVAILABLE := 5       # first N slots usable

@onready var grid: GridContainer = $PanelContainer/MarginContainer/VBoxContainer/GridContainer
@onready var item_label: Label = $PanelContainer/MarginContainer/VBoxContainer/VBoxContainer2/ItemLabel
@onready var item_desc: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/VBoxContainer2/ItemDesc

# Simple "database" of items
var items = [
	{"name": "Potion", "desc": "Heals 50 HP"},
	{"name": "Elixir", "desc": "Restores HP & MP"},
	{"name": "Sword", "desc": "A sharp blade"},
]

var slot_buttons: Array[Button] = []
var slot_data: Array = []   # per-slot item dict or null

func _ready() -> void:
	assert(grid != null, "GridContainer node not found. Name it 'Grid' or update the path.")
	grid.columns = 5

	# 1) Create all slots once
	for i in range(TOTAL_SLOTS):
		var b := Button.new()
		b.custom_minimum_size = Vector2(72, 72)
		b.focus_mode = Control.FOCUS_ALL
		b.disabled = i >= START_AVAILABLE      # lock all except first 5
		b.text = ""                            # empty until an item is set
		b.connect("pressed", Callable(self, "_on_slot_pressed").bind(i))
		grid.add_child(b)
		slot_buttons.append(b)
		slot_data.append(null)

	# 2) Put items in the first 5 slots (example)
	for i in range(min(START_AVAILABLE, items.size())):
		set_slot(i, items[i])

	# Clear info panel
	item_label.text = "ItemName:"
	item_desc.text = "<item description>"

func set_slot(index: int, data: Dictionary) -> void:
	slot_data[index] = data
	var b: Button = slot_buttons[index]
	b.disabled = false
	b.text = data.name  # or set an icon instead of text

func _on_slot_pressed(index: int) -> void:
	var data = slot_data[index]
	if data == null:
		item_label.text = "ItemName: (Empty)"
		item_desc.text = ""
		return
	item_label.text = "ItemName: " + str(data.name)
	item_desc.text = str(data.desc)

# Optional: if you still have an Add button and want it to fill the next empty unlocked slot
func _on_add_item_pressed() -> void:
	# find first unlocked empty slot
	for i in range(TOTAL_SLOTS):
		if !slot_buttons[i].disabled and slot_data[i] == null:
			set_slot(i, items[randi() % items.size()])
			return
