extends VBoxContainer

signal buy_pressed(item_data: Dictionary)

@onready var icon: TextureRect = $Icon
@onready var name_label: Label = $NameLabel
@onready var price_label: Label = $PriceLabel
@onready var buy_button: Button = $BuyButton

var item_data: Dictionary = {}

func setup(data: Dictionary) -> void:
	item_data = data
	name_label.text = data.get("name", "Item")
	price_label.text = "Price: " + str(int(data.get("price", 0)))
	var tx: Texture2D = data.get("icon", null) as Texture2D
	if tx:
		icon.texture = tx

func _ready() -> void:
	buy_button.text = "Buy"
	buy_button.pressed.connect(_on_buy)

func _on_buy() -> void:
	buy_pressed.emit(item_data)
