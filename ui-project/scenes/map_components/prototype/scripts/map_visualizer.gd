extends Node2D
class_name MapVisualizer

@export var terrain_generator_path: NodePath
@export var viewport_size: Vector2 = Vector2(540, 990)

var terrain_gen: TerrainGenerator
var tex_preview: Texture2D

func _ready() -> void:
	terrain_gen = get_node_or_null(terrain_generator_path)
	if not terrain_gen:
		push_error("MapVisualizer: terrain_generator_path not set or node missing")
		return

	# 🟢 Listen to signal (H, W)
	if not terrain_gen.is_connected("data_changed", Callable(self, "_on_data_changed")):
		terrain_gen.connect("data_changed", Callable(self, "_on_data_changed"))

	# trigger initial draw if data already exists
	if terrain_gen.H and terrain_gen.W:
		_update_texture()
		queue_redraw()

func _on_data_changed(H: Image, W: Image) -> void:
	_update_texture()
	queue_redraw()

func _update_texture() -> void:
	if not terrain_gen or terrain_gen.H == null or terrain_gen.W == null:
		push_warning("MapVisualizer: Missing terrain data to build preview")
		return

	var img_H := terrain_gen.H
	var img_W := terrain_gen.W
	var w = img_H.get_width()
	var h = img_H.get_height()

	var preview := Image.create(w, h, false, Image.FORMAT_RGBA8)

	# Base water vs land
	for yy in range(h):
		for xx in range(w):
			var is_water = img_W.get_pixel(xx, yy).r > 0.5
			var col = Color(0.1, 0.35, 0.85) if is_water else Color(0.8, 0.8, 0.8)
			preview.set_pixel(xx, yy, col)

	# Rivers
	print("River path length:", terrain_gen.river_path.size())
	# draw river with width and shading
	for p in terrain_gen.river_path:
		for oy in range(-2, 3):
			for ox in range(-2, 3):
				var px = p.x + ox
				var py = p.y + oy
				if px < 0 or py < 0 or px >= w or py >= h:
					continue
				var dist = sqrt(float(ox*ox + oy*oy))
				var fade = clamp(1.0 - dist / 3.0, 0.0, 1.0)
				var base = preview.get_pixel(px, py)
				var river_color = Color(0.05, 0.15 + 0.25 * fade, 0.85 + 0.1 * fade)
				preview.set_pixel(px, py, base.lerp(river_color, fade))

	# Lake
	if terrain_gen.lake_position != Vector2i.ZERO:
		var lp = terrain_gen.lake_position
		for oy in range(-10, 11):
			for ox in range(-10, 11):
				var px = lp.x + ox
				var py = lp.y + oy
				if px >= 0 and py >= 0 and px < w and py < h:
					var d = sqrt(float(ox*ox + oy*oy)) / 10.0
					if d <= 1.0:
						var alpha = clamp(1.0 - d, 0.0, 1.0)
						var lake_col = Color(0.0, 0.3 * alpha, 0.9 * alpha)
						preview.set_pixel(px, py, lake_col)

	tex_preview = ImageTexture.create_from_image(preview)
	print("MapVisualizer: preview rebuilt")

func _draw() -> void:
	if tex_preview:
		var scale = Vector2(viewport_size.x / tex_preview.get_width(), viewport_size.y / tex_preview.get_height())
		draw_set_transform(Vector2.ZERO, 0.0, scale)
		draw_texture(tex_preview, Vector2.ZERO)


#extends Node2D
#class_name MapVisualizer
#
#@export var terrain_generator_path: NodePath
#@export var viewport_size: Vector2 = Vector2(540, 990)
#
#var terrain_gen: TerrainGenerator
#var tex_preview: Texture2D
#
#func _ready():
	#terrain_gen = get_node_or_null(terrain_generator_path)
	#if not terrain_gen:
		#push_error("No terrain generator found.")
		#return
	#
	#await get_tree().process_frame
	#
	## Generate if not already generated
	#if not terrain_gen.H:
		#terrain_gen.generate_all(terrain_gen.base_seed)
	#
	#_update_texture()
	#queue_redraw()
#
#
## ----------------------------------------------------------------
## Regeneration callback
## ----------------------------------------------------------------
#func _on_terrain_regenerated(_H: Image, _W: Image) -> void:
	#print("MapVisualizer: Detected regenerated terrain → updating preview.")
	#_update_texture()
	#queue_redraw()
#
#
## ----------------------------------------------------------------
## Generate texture preview
## ----------------------------------------------------------------
#func _update_texture():
	#if not terrain_gen or not terrain_gen.H or not terrain_gen.W:
		#push_warning("MapVisualizer: Missing terrain data.")
		#return
	#
	#var img_H = terrain_gen.H
	#var img_W = terrain_gen.W
	#var preview := Image.create(img_H.get_width(), img_H.get_height(), false, Image.FORMAT_RGBA8)
#
	#for y in range(img_H.get_height()):
		#for x in range(img_H.get_width()):
			#var h = img_H.get_pixel(x, y).r
			#var is_water = img_W.get_pixel(x, y).r > 0.5
			#var color = Color(0.1, 0.3, 0.8) if is_water else Color(0.7, 0.7, 0.7)
			#preview.set_pixel(x, y, color)
#
	## River highlight (blue streak)
	#for p in terrain_gen.river_path:
		#for oy in range(-2, 3):
			#for ox in range(-2, 3):
				#var nx = p.x + ox
				#var ny = p.y + oy
				#if nx >= 0 and ny >= 0 and nx < img_H.get_width() and ny < img_H.get_height():
					#preview.set_pixel(nx, ny, Color(0.0, 0.2, 0.9))
#
	## Lake highlight (optional – makes debugging clearer)
	#if terrain_gen.lake_position != Vector2i.ZERO:
		#var lp = terrain_gen.lake_position
		#for oy in range(-5, 6):
			#for ox in range(-5, 6):
				#var nx = lp.x + ox
				#var ny = lp.y + oy
				#if nx >= 0 and ny >= 0 and nx < img_H.get_width() and ny < img_H.get_height():
					#preview.set_pixel(nx, ny, Color(0.3, 0.6, 1.0))
#
	#tex_preview = ImageTexture.create_from_image(preview)
#
#
## ----------------------------------------------------------------
## Draw scaled preview
## ----------------------------------------------------------------
#func _draw():
	#if tex_preview:
		#var scale = Vector2(viewport_size.x / tex_preview.get_width(), viewport_size.y / tex_preview.get_height())
		#draw_set_transform(Vector2.ZERO, 0.0, scale)
		#draw_texture(tex_preview, Vector2.ZERO)
