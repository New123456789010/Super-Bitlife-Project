extends PanelContainer

@export var parent_path: NodePath = "../Control"
@export var inventory_path: NodePath = "../Inventory"
@export var item_card_scene: PackedScene = preload("res://scenes/components/item_card.tscn")

@onready var money_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/MoneyLabel
@onready var status_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/StatusLabel
@onready var store_grid: GridContainer = $MarginContainer/VBoxContainer/StoreGrid

var parent_ctrl: Node
var inventory: Node

var store_items: Array[Dictionary] = [
	{
		"id":"suit_case", "name":"Suit Case", "desc":"formal and simple", "price":50,
		"icon": preload("res://assets/ui_assets/Action Icon/Work Icon.png")        # <—
	},
	{
		"id":"book", "name":"Book", "desc":"ordinary book", "price":20,
		"icon": preload("res://assets/ui_assets/Action Icon/Reading Icon.png")
	},
	{
		"id":"milk", "name":"Milk", "desc":"made from water buffalo", "price":10,
		"icon": preload("res://assets/ui_assets/Joblist/Delivery/Milkman.png")
	},
	{
		"id":"medicine", "name":"Medicine", "desc":"cure from infection", "price":20,
		"icon": preload("res://assets/ui_assets/Joblist/Medical/Pharmacist.png")
	},
	{
		"id":"mail", "name":"Mail", "desc":"a simple mail", "price":5,
		"icon": preload("res://assets/ui_assets/Joblist/Delivery/Mailman.png")
	},
]


func _ready() -> void:
	parent_ctrl = get_node_or_null(parent_path)
	inventory   = get_node_or_null(inventory_path)
	if parent_ctrl == null:
		push_error("Shop: parent_path not set (expect ../Control).")
		return
	if inventory == null:
		push_error("Shop: inventory_path not set (expect ../Inventory).")
		return

	store_grid.columns = 3
	_refresh_shop_money()

	for data in store_items:
		var card := item_card_scene.instantiate()
		store_grid.add_child(card)
		card.setup(data)
		card.buy_pressed.connect(_on_buy_pressed)

func _on_buy_pressed(data: Dictionary) -> void:
	var price := int(data.get("price", 0))

	# Use the global wallet
	if GameData.total_assets < price:
		_say("Not enough money!")
		return

	# Add to inventory first (so we can avoid charging if full)
	if not (inventory and inventory.has_method("add_item") and inventory.add_item(data)):
		_say("Inventory is full!")
		return

	# Charge the player
	GameData.total_assets -= price
	SignalBus.money_changed.emit(GameData.total_assets)

	# Refresh both UIs
	_refresh_shop_money()
	if parent_ctrl and parent_ctrl.has_method("update_money_ui"):
		parent_ctrl.update_money_ui()

	_say("Bought: " + str(data.get("name", "")))

func _refresh_shop_money() -> void:
	money_label.text = "Money: " + str(GameData.total_assets)

func _say(msg: String) -> void:
	status_label.text = msg
