extends Node2D
class_name CityVisualizer

@export var city_env_path: NodePath
@export_enum("Population", "Water", "Forest", "Height", "CityPotential", "Composite") var debug_layer := "Composite"

@onready var city_env: CityEnvironment = get_node_or_null(city_env_path)
@onready var debug_font := ThemeDB.fallback_font

var tex_preview: Texture2D
var last_update_time := 0.0


func _ready() -> void:
	if not city_env:
		push_error("CityVisualizer: city_env_path not set or node missing")
		return

	city_env.connect("maps_generated", Callable(self, "_on_maps_generated"))
	print("CityVisualizer ready, waiting for maps...")


func _on_maps_generated(water: Image, forest: Image, height: Image, population: Image, city_potential: Image) -> void:
	var img: Image
	match debug_layer:
		"Population":
			img = population
		"Water":
			img = water
		"Forest":
			img = forest
		"Height":
			img = height
		"CityPotential":
			img = city_potential
		"Composite":
			img = _generate_composite_map(water, forest, height, population, city_potential)

	if not img:
		push_error("CityVisualizer: No image created.")
		return

	tex_preview = ImageTexture.create_from_image(img)
	last_update_time = Time.get_ticks_msec() / 1000.0
	queue_redraw()


func _generate_composite_map(water: Image, forest: Image, height: Image, population: Image, city_potential: Image) -> Image:
	var w = water.get_width()
	var h = water.get_height()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var r = population.get_pixel(x, y).r
			var g = forest.get_pixel(x, y).r
			var b = water.get_pixel(x, y).r
			var a = city_potential.get_pixel(x, y).r
			img.set_pixel(x, y, Color(r, g, b, a))
	return img

func _draw() -> void:
	if tex_preview:
		draw_texture(tex_preview, Vector2.ZERO)

	# --- Runtime debugger overlay ---
	self.modulate = Color.WHITE
	draw_string(debug_font, Vector2(10, 20), "Debug Layer: " + debug_layer, HORIZONTAL_ALIGNMENT_LEFT, -1)

	self.modulate = Color(1, 1, 0)
	draw_string(debug_font, Vector2(10, 40), "Last Update: %.2fs" % last_update_time, HORIZONTAL_ALIGNMENT_LEFT, -1)

#extends Node2D
#class_name CityVisualizer
#
#@export var city_env_path: NodePath
#@export var zones_node_path: NodePath
#
#@export_enum("Population", "Water", "Forest", "Height", "CityPotential", "Composite", "Zones") var debug_layer := "Composite"
#@export var world_size: float = 2048.0
#
#var city_env: Node = null
#var zones_node: Node = null
#
#var tex_population: Texture2D
#var tex_water: Texture2D
#var tex_forest: Texture2D
#var tex_height: Texture2D
#var tex_potential: Texture2D
#var tex_composite: Texture2D
#var tex_zones: Texture2D
#
#var centers: Array = []
#var show_centers: bool = true
#var show_zones_overlay: bool = true
#
#func _ready() -> void:
	#city_env = get_node_or_null(city_env_path)
	#zones_node = get_node_or_null(zones_node_path)
#
	#if city_env:
		#if not city_env.is_connected("maps_generated", Callable(self, "_on_maps_generated")):
			#city_env.connect("maps_generated", Callable(self, "_on_maps_generated"))
	#if zones_node:
		#if not zones_node.is_connected("zones_generated", Callable(self, "_on_zones_generated")):
			#zones_node.connect("zones_generated", Callable(self, "_on_zones_generated"))
#
	#print("CityVisualizer ready. Waiting for maps...")
#
#func _on_maps_generated(water: Image, forest: Image, height: Image, population: Image, city_potential: Image) -> void:
	#tex_population = ImageTexture.create_from_image(population)
	#tex_water = ImageTexture.create_from_image(water)
	#tex_forest = ImageTexture.create_from_image(forest)
	#tex_height = ImageTexture.create_from_image(height)
	#tex_potential = ImageTexture.create_from_image(city_potential)
	#tex_composite = ImageTexture.create_from_image(_generate_composite_map(water, forest, height, population))
	#queue_redraw()
	#print("CityVisualizer: maps received and textures created.")
#
#func _on_zones_generated(zone_image: Image, centers_in: Array) -> void:
	#tex_zones = ImageTexture.create_from_image(zone_image)
	#centers = centers_in.duplicate()
	#queue_redraw()
	#print("CityVisualizer: zones received (", centers.size(), " centers )")
#
#
#func _generate_composite_map(water: Image, forest: Image, height: Image, population: Image) -> Image:
	#var w = water.get_width()
	#var h = water.get_height()
	#var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	#for y in range(h):
		#for x in range(w):
			#var c = Color(population.get_pixel(x, y).r, forest.get_pixel(x, y).r, water.get_pixel(x, y).r, 1.0)
			#out.set_pixel(x, y, c)
	#return out
#
#
#func _unhandled_input(event):
	#if event is InputEventKey and event.pressed and not event.echo:
		#match event.scancode:
			#KEY_1:
				#debug_layer = "Population"; queue_redraw()
			#KEY_2:
				#debug_layer = "Water"; queue_redraw()
			#KEY_3:
				#debug_layer = "Forest"; queue_redraw()
			#KEY_4:
				#debug_layer = "Height"; queue_redraw()
			#KEY_5:
				#debug_layer = "CityPotential"; queue_redraw()
			#KEY_6:
				#debug_layer = "Composite"; queue_redraw()
			#KEY_7:
				#debug_layer = "Zones"; queue_redraw()
			#KEY_Z:
				#show_zones_overlay = not show_zones_overlay; queue_redraw()
			#KEY_C:
				#show_centers = not show_centers; queue_redraw()
#
#func _draw() -> void:
	#var draw_rect_size = Vector2(world_size, world_size)
#
	#if debug_layer == "Population" and tex_population:
		#draw_texture(tex_population, Vector2.ZERO)
	#elif debug_layer == "Water" and tex_water:
		#draw_texture(tex_water, Vector2.ZERO)
	#elif debug_layer == "Forest" and tex_forest:
		#draw_texture(tex_forest, Vector2.ZERO)
	#elif debug_layer == "Height" and tex_height:
		#draw_texture(tex_height, Vector2.ZERO)
	#elif debug_layer == "CityPotential" and tex_potential:
		#draw_texture(tex_potential, Vector2.ZERO)
	#elif debug_layer == "Composite" and tex_composite:
		#draw_texture(tex_composite, Vector2.ZERO)
	#elif debug_layer == "Zones" and tex_zones:
		#draw_texture(tex_zones, Vector2.ZERO)
	#else:
		#draw_rect(Rect2(Vector2.ZERO, draw_rect_size), Color(0.05, 0.05, 0.05))
#
	## zones overlay semi-transparent
	#if show_zones_overlay and tex_zones:
		#draw_texture(tex_zones, Vector2.ZERO, Color(1,1,1,0.6))
#
	## draw centers
	#if show_centers and centers.size() > 0 and tex_composite:
		#for c in centers:
			#var px = float(c.x) / tex_composite.get_width() * world_size
			#var py = float(c.y) / tex_composite.get_height() * world_size
			#draw_circle(Vector2(px, py), 6.0, Color(1,1,1))
