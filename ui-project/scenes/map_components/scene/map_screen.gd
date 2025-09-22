extends Control


var map_data : Dictionary = {}
var map_seed: int = 12345

@onready var generator = preload("res://scenes/map_components/script/map_generator.gd").new()
@onready var regenerate_button: Button = $RegenerateButton

func _ready() -> void:
	# Generate the map when scene starts
	map_data = generator.generate_map(map_seed)
	queue_redraw()  # trigger _draw
	_on_regenerate_button_pressed()
	
	## Ensure GameState autoload exists (scripts/MapState.gd)
	#if MapState.map_data == null:
		#var s = seed if seed != 0 else randi()
		#MapState.map_data = MapGenerator.generate_map(s)
		#print("Generated map with seed ", MapState.map_data["seed"])
	#map_data = MapState.map_data
	#queue_redraw() # schedule draw

func _draw() -> void:
	if map_data == null:
		return
	var size = get_viewport_rect().size

	# Draw district polygons (filled)
	for district in map_data["districts"]:
		var pts = PackedVector2Array()
		for p in district["polygon"]:
			pts.append(Vector2(p.x * size.x, p.y * size.y))
		var colors = PackedColorArray()
		for i in pts:
			colors.append(district["color"])
		draw_polygon(pts, colors)

	for road in map_data["roads"]:
		var a = road["from_pos"] * size
		var b = road["to_pos"] * size
		var col = Color8(80, 80, 80)  # default gray
		if road["from"].begins_with("poi_"):
			col = Color8(150, 100, 220)  # purple for poi → district
		draw_line(a, b, col, 4)

	# Draw POIs
	for district in map_data["districts"]:
		for poi in district["pois"]:
			var p = poi["pos"] * size
			draw_circle(p, 8, Color8(250, 250, 250))
			draw_circle(p, 4, Color8(40, 120, 200))

func _input(event) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos = event.position
		if map_data == null:
			return
		var size = get_viewport_rect().size
		for district in map_data["districts"]:
			for poi in district["pois"]:
				var p = poi["pos"] * size
				if p.distance_to(pos) < 10:
					_on_poi_clicked(poi, p)
					return

func _on_poi_clicked(poi:Dictionary, pixel_pos:Vector2) -> void:
	print("POI clicked:", poi["name"], " type=", poi["type"])
	var label = Label.new()
	label.text = "%s\n(%s)" % [poi["name"], poi["type"]]
	add_child(label)
	label.position = pixel_pos + Vector2(12, -28)
	# remove after 2s
	_remove_later(label, 2.0)

func _remove_later(node:Node, delay:float) -> void:
	await get_tree().create_timer(delay).timeout
	if node.is_inside_tree():
		node.queue_free()


func _on_regenerate_button_pressed() -> void:
	map_seed = randi() % 100000
	map_data = generator.generate_map(map_seed)
	queue_redraw()


func _on_back_button_pressed() -> void:
	self.visible = !self.visible
