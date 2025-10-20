extends Node2D
class_name MapVisualizer

@export var terrain_generator_path: NodePath
@export var viewport_size: Vector2 = Vector2(540, 990)

var terrain_gen: TerrainGenerator
var tex_preview: Texture2D

func _ready():
	terrain_gen = get_node_or_null(terrain_generator_path)
	if not terrain_gen:
		push_error("No terrain generator found.")
		return
	
	# Connect to regeneration signal (add this to TerrainGenerator)
	if not terrain_gen.is_connected("terrain_regenerated", Callable(self, "_on_terrain_regenerated")):
		terrain_gen.connect("terrain_regenerated", Callable(self, "_on_terrain_regenerated"))
	
	await get_tree().process_frame
	
	# Generate if not already generated
	if not terrain_gen.H:
		terrain_gen.generate_all(terrain_gen.base_seed)
	
	_update_texture()
	queue_redraw()


# ----------------------------------------------------------------
# Regeneration callback
# ----------------------------------------------------------------
func _on_terrain_regenerated(_H: Image, _W: Image) -> void:
	print("MapVisualizer: Detected regenerated terrain → updating preview.")
	_update_texture()
	queue_redraw()


# ----------------------------------------------------------------
# Generate texture preview
# ----------------------------------------------------------------
func _update_texture():
	if not terrain_gen or not terrain_gen.H or not terrain_gen.W:
		push_warning("MapVisualizer: Missing terrain data.")
		return
	
	var img_H = terrain_gen.H
	var img_W = terrain_gen.W
	var preview := Image.create(img_H.get_width(), img_H.get_height(), false, Image.FORMAT_RGBA8)

	for y in range(img_H.get_height()):
		for x in range(img_H.get_width()):
			var h = img_H.get_pixel(x, y).r
			var is_water = img_W.get_pixel(x, y).r > 0.5
			var color = Color(0.1, 0.3, 0.8) if is_water else Color(0.7, 0.7, 0.7)
			preview.set_pixel(x, y, color)

	# River highlight (blue streak)
	for p in terrain_gen.river_path:
		for oy in range(-2, 3):
			for ox in range(-2, 3):
				var nx = p.x + ox
				var ny = p.y + oy
				if nx >= 0 and ny >= 0 and nx < img_H.get_width() and ny < img_H.get_height():
					preview.set_pixel(nx, ny, Color(0.0, 0.2, 0.9))

	# Lake highlight (optional – makes debugging clearer)
	if terrain_gen.lake_position != Vector2i.ZERO:
		var lp = terrain_gen.lake_position
		for oy in range(-5, 6):
			for ox in range(-5, 6):
				var nx = lp.x + ox
				var ny = lp.y + oy
				if nx >= 0 and ny >= 0 and nx < img_H.get_width() and ny < img_H.get_height():
					preview.set_pixel(nx, ny, Color(0.3, 0.6, 1.0))

	tex_preview = ImageTexture.create_from_image(preview)


# ----------------------------------------------------------------
# Draw scaled preview
# ----------------------------------------------------------------
func _draw():
	if tex_preview:
		var scale = Vector2(viewport_size.x / tex_preview.get_width(), viewport_size.y / tex_preview.get_height())
		draw_set_transform(Vector2.ZERO, 0.0, scale)
		draw_texture(tex_preview, Vector2.ZERO)
