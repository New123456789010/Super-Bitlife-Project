extends PanelContainer

const TOTAL_SLOTS := 20
const START_AVAILABLE := 5

@onready var grid: GridContainer = $PanelContainer/MarginContainer/VBoxContainer/GridContainer
@onready var item_label: Label = $PanelContainer/MarginContainer/VBoxContainer/VBoxContainer2/ItemLabel
@onready var item_desc: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/VBoxContainer2/ItemDesc

var slot_buttons: Array[Button] = []
var slot_data: Array = []   # each slot stores a Dictionary or null

func _ready() -> void:
	grid.columns = 5
	for i in range(TOTAL_SLOTS):
		var b := Button.new()
		b.custom_minimum_size = Vector2(72, 72)
		b.disabled = i >= START_AVAILABLE
		b.text = ""
		b.focus_mode = Control.FOCUS_ALL
		b.connect("pressed", Callable(self, "_on_slot_pressed").bind(i))

		# ✅ fixed icon config
		b.expand_icon = true
		#b.icon_position = Button.ICON_POSITION_TOP
		#b.text_alignment = HorizontalAlignment.CENTER

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

			# ✅ use icon first, fallback to name text
			var tex: Texture2D = data.get("icon", null) as Texture2D
			if tex:
				b.icon = tex
				b.text = ""  # optional, clear text if using icon only
			else:
				b.text = data.get("name", "")

			# optional: show tooltip with item info
			b.tooltip_text = "%s\n%s" % [data.get("name", ""), data.get("desc", "")]
			return true
	return false  # inventory full
