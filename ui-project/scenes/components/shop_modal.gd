extends PanelContainer

# Set this in the Inspector to point to the Inventory node in your scene (e.g. "../Inventory")
@export var inventory_path: NodePath = "../Inventory"

# Either keep export and use preload (works fine), or leave blank and set in Inspector
@export var item_card_scene: PackedScene = preload("res://scenes/components/item_card.tscn")

@export var starting_gold: int = 250

@onready var gold_label: Label    = $MarginContainer/VBoxContainer/HBoxContainer/GoldLabel
@onready var status_label: Label  = $MarginContainer/VBoxContainer/HBoxContainer/StatusLabel
@onready var store_grid: GridContainer = $MarginContainer/VBoxContainer/StoreGrid

var gold: int
var store_items: Array[Dictionary] = [
	{"id":"potion","name":"Potion","desc":"Heals 50 HP","price":25},
	{"id":"elixir","name":"Elixir","desc":"Restores HP&MP","price":90},
	{"id":"sword","name":"Short Sword","desc":"A sharp blade","price":120},
	{"id":"shield","name":"Small Shield","desc":"Blocks attacks","price":110},
	{"id":"herb","name":"Herb","desc":"A simple remedy","price":10},
]

var inventory: Node

func _ready() -> void:
	inventory = get_node_or_null(inventory_path)
	if inventory == null:
		push_error("Store.gd: inventory_path is not set or node not found.")
		return

	gold = starting_gold
	_refresh_gold()

	store_grid.columns = 3

	for data in store_items:
		var card := item_card_scene.instantiate()
		store_grid.add_child(card)
		card.setup(data)
		card.buy_pressed.connect(_on_buy_pressed)

func _on_buy_pressed(data: Dictionary) -> void:
	var price: int = int(data.get("price", 0))
	if price > gold:
		_say("Not enough gold!")
		return

	var ok := false
	if inventory and inventory.has_method("add_item"):
		ok = inventory.add_item(data)
	if !ok:
		_say("Inventory is full!")
		return

	gold -= price
	_refresh_gold()
	_say("Bought: " + str(data.get("name", "")))

func _refresh_gold() -> void:
	gold_label.text = "Gold: " + str(gold)

func _say(msg: String) -> void:
	status_label.text = msg
