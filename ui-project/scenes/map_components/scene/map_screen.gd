extends Control

var map_data: Dictionary = {}
var map_seed: int = 12345

@onready var generator = preload("res://scenes/map_components/script/map_generator.gd").new()
@onready var regenerate_button: Button = %RegenerateButton

# preload POI icons
const POI_ICONS := {
	"Trailhead": preload("res://assets/ui_assets/POIs Icon/Trailhead Icon.png"),
	"School": preload("res://assets/ui_assets/POIs Icon/School Icon.png"),
	"Dock": preload("res://assets/ui_assets/POIs Icon/Dock Icon.png"),
	"Mall": preload("res://assets/ui_assets/POIs Icon/Mall Icon.png"),
	"Beach": preload("res://assets/ui_assets/POIs Icon/Beach Icon.png"),
	"Office": preload("res://assets/ui_assets/POIs Icon/Shop Icon.png"),
	"Cafe": preload("res://assets/ui_assets/POIs Icon/Cafe Icon.png"),
	"Shop": preload("res://assets/ui_assets/POIs Icon/Shop Icon.png"),
	"Station": preload("res://assets/ui_assets/POIs Icon/Station Icon.png"),
	"House": preload("res://assets/ui_assets/POIs Icon/Shop Icon.png"),
	"Park": preload("res://assets/ui_assets/POIs Icon/Park Icon.png"),
	"Factory": preload("res://assets/ui_assets/POIs Icon/Warehouse Icon.png"),
	"Warehouse": preload("res://assets/ui_assets/POIs Icon/Warehouse Icon.png"),
	"Default": preload("res://assets/ui_assets/POIs Icon/Shop Icon.png")
}

func _ready() -> void:
	map_data = generator.generate_map(map_seed)
	queue_redraw()
	_on_regenerate_button_pressed()


func _draw() -> void:
	if map_data.is_empty():
		return
	var view_size = get_viewport_rect().size

	# === Draw district polygons ===
	for district in map_data["districts"]:
		var pts := PackedVector2Array()
		for p in district["polygon"]:
			pts.append(Vector2(p.x * view_size.x, p.y * view_size.y))
		var colors := PackedColorArray()
		for i in pts:
			colors.append(district["color"])
		draw_polygon(pts, colors)

		# Draw label at approximate center
		var center := Vector2.ZERO
		for p in pts: center += p
		center /= pts.size()
		draw_string(get_theme_default_font(), center, district["name"], HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.WHITE)


	# === Draw roads & metro lines ===
	for road in map_data["roads"]:
		var a = road["from_pos"] * view_size
		var b = road["to_pos"] * view_size

		match road.get("type", "road"):
			"highway":
				draw_line(a, b, Color8(240, 180, 60), 6)
			"metro":
				_draw_curved_connection(a, b, Color.SKY_BLUE, 3)
			_:
				draw_line(a, b, Color8(80, 80, 80), 3)

	# === Draw POIs ===
	for district in map_data["districts"]:
		for poi in district["pois"]:
			var p = poi["pos"] * view_size
			_draw_poi_icon(poi, p)


# --- Draw helpers ---
func _draw_poi_icon(poi: Dictionary, pos: Vector2) -> void:
	var tex: Texture2D = POI_ICONS.get(poi["type"], POI_ICONS["Default"])
	if tex == null:
		return
	var scale := 0.5
	var draw_size := tex.get_size() * scale
	var draw_rect := Rect2(pos - draw_size / 2.0, draw_size)
	draw_texture_rect(tex, draw_rect, false)


func _draw_curved_connection(a: Vector2, b: Vector2, color: Color, width: float = 2.0, steps: int = 24):
	var mid := (a + b) * 0.5
	var dir := (b - a).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var bend_strength := 60.0
	mid += perp * bend_strength * (randf() - 0.5)

	var points := PackedVector2Array()
	for i in range(steps + 1):
		var t := float(i) / steps
		var q := (1 - t) * (1 - t) * a + 2 * (1 - t) * t * mid + t * t * b
		points.append(q)
	draw_polyline(points, color, width)


# --- Interaction ---
func _input(event) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos = event.position
		if map_data.is_empty():
			return
		var view_size := get_viewport_rect().size
		for district in map_data["districts"]:
			for poi in district["pois"]:
				var p = poi["pos"] * view_size
				if p.distance_to(pos) < 10:
					_on_poi_clicked(poi, p)
					return


func _on_poi_clicked(poi: Dictionary, pixel_pos: Vector2) -> void:
	print("POI clicked:", poi["name"], " type=", poi["type"])
	var label := Label.new()
	label.text = "%s\n(%s)" % [poi["name"], poi["type"]]
	add_child(label)
	label.position = pixel_pos + Vector2(12, -28)
	_remove_later(label, 2.0)


func _remove_later(node: Node, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if node.is_inside_tree():
		node.queue_free()


func _on_regenerate_button_pressed() -> void:
	map_seed = randi() % 100000
	map_data = generator.generate_map(map_seed)
	queue_redraw()


func _on_back_button_pressed() -> void:
	self.visible = !self.visible


#extends Control
#
#var map_data : Dictionary = {}
#var map_seed: int = 12345
#
#@onready var generator = preload("res://scenes/map_components/script/map_generator.gd").new()
#@onready var regenerate_button: Button = %RegenerateButton
#
#func _ready() -> void:
	## Generate the map when scene starts
	#map_data = generator.generate_map(map_seed)
	#queue_redraw()  # trigger _draw
	#_on_regenerate_button_pressed()
#
#func _draw() -> void:
	#if map_data == null:
		#return
	#var size = get_viewport_rect().size
#
	## Draw district polygons (filled)
	#for district in map_data["districts"]:
		#var pts = PackedVector2Array()
		#for p in district["polygon"]:
			#pts.append(Vector2(p.x * size.x, p.y * size.y))
		#var colors = PackedColorArray()
		#for i in pts:
			#colors.append(district["color"])
		#draw_polygon(pts, colors)
#
	#for road in map_data["roads"]:
		#var a = road["from_pos"] * size
		#var b = road["to_pos"] * size
		#var col = Color8(80, 80, 80)  # default gray
		#if road["from"].begins_with("poi_"):
			#col = Color8(150, 100, 220)  # purple for poi → district
		#draw_line(a, b, col, 4)
#
	## Draw POIs
	#for district in map_data["districts"]:
		#for poi in district["pois"]:
			#var p = poi["pos"] * size
			#draw_circle(p, 8, Color8(250, 250, 250))
			#draw_circle(p, 4, Color8(40, 120, 200))
#
#func _input(event) -> void:
	#if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		#var pos = event.position
		#if map_data == null:
			#return
		#var size = get_viewport_rect().size
		#for district in map_data["districts"]:
			#for poi in district["pois"]:
				#var p = poi["pos"] * size
				#if p.distance_to(pos) < 10:
					#_on_poi_clicked(poi, p)
					#return
#
#func _on_poi_clicked(poi:Dictionary, pixel_pos:Vector2) -> void:
	#print("POI clicked:", poi["name"], " type=", poi["type"])
	#var label = Label.new()
	#label.text = "%s\n(%s)" % [poi["name"], poi["type"]]
	#add_child(label)
	#label.position = pixel_pos + Vector2(12, -28)
	## remove after 2s
	#_remove_later(label, 2.0)
#
#func _remove_later(node:Node, delay:float) -> void:
	#await get_tree().create_timer(delay).timeout
	#if node.is_inside_tree():
		#node.queue_free()
#
#
#func _on_regenerate_button_pressed() -> void:
	#map_seed = randi() % 100000
	#map_data = generator.generate_map(map_seed)
	#queue_redraw()
#
#
#func _on_back_button_pressed() -> void:
	#self.visible = !self.visible
