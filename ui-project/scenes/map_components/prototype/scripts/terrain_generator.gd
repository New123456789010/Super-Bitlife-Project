extends Node
class_name TerrainGenerator

@export var map_width: int = 540
@export var map_height: int = 990
@export_range(0.0, 1.0, 0.01) var sea_level: float = 0.35
@export_enum("Top", "Bottom") var ocean_position: String = "Bottom"

@export var base_seed: int = 1337
@export var base_frequency: float = 0.002
@export var base_octaves: int = 5

var H: Image
var W: Image
var river_path: Array = []
var lake_position: Vector2i = Vector2i.ZERO
var river_mouth: Vector2i = Vector2i.ZERO

signal terrain_regenerated(H: Image, W: Image)

# -------------------------------------------------------------
# Entry point
# -------------------------------------------------------------
func _ready():
	generate_all(base_seed)

func regenerate(optional_seed: int = -1):
	if optional_seed < 0:
		base_seed = randi()
	else:
		base_seed = optional_seed
	print("Regenerating with seed:", base_seed)
	generate_all(base_seed)

func generate_all(seed: int):
	base_seed = seed
	_generate_heightmap()
	_generate_water_mask()
	_place_lake_and_river()
	print("Generation complete with seed:", base_seed)
	
	emit_signal("terrain_regenerated", H, W)

# -------------------------------------------------------------
# Heightmap with better coverage and vertical bias
# -------------------------------------------------------------
func _generate_heightmap():
	H = Image.create(map_width, map_height, false, Image.FORMAT_RF)
	var noise := FastNoiseLite.new()
	noise.seed = base_seed
	noise.frequency = base_frequency
	noise.fractal_octaves = base_octaves

	var cx = map_width / 2.0
	var cy = map_height / 2.0
	var max_dist = sqrt(cx * cx + cy * cy)
	var bias_dir = -1.0 if ocean_position == "Top" else 1.0
	var vertical_bias = 0.3 * bias_dir

	for y in range(map_height):
		for x in range(map_width):
			var n = noise.get_noise_2d(x, y) * 0.5 + 0.5
			var dist = sqrt(pow(x - cx, 2) + pow(y - cy, 2)) / max_dist
			var falloff = pow(1.0 - dist, 1.2)
			var bias = (float(y) / map_height - 0.5) * vertical_bias
			var h = clamp(n * falloff + bias, 0.0, 1.0)
			H.set_pixel(x, y, Color(h, 0, 0))

# -------------------------------------------------------------
# Water mask from sea level
# -------------------------------------------------------------
func _generate_water_mask():
	W = Image.create(map_width, map_height, false, Image.FORMAT_RF)
	for y in range(map_height):
		for x in range(map_width):
			var h = H.get_pixel(x, y).r
			W.set_pixel(x, y, Color(1.0 if h < sea_level else 0.0, 0, 0))

# -------------------------------------------------------------
# Lake and river generation
# -------------------------------------------------------------
func _place_lake_and_river():
	var high_pt := Vector2i.ZERO
	var high_h := 0.0
	var y_start = map_height / 4
	var y_end = map_height / 2 if ocean_position == "Bottom" else 3 * map_height / 4

	for y in range(y_start, y_end):
		for x in range(map_width / 4, 3 * map_width / 4):
			var h = H.get_pixel(x, y).r
			if h > high_h:
				high_h = h
				high_pt = Vector2i(x, y)

	lake_position = high_pt
	if high_pt == Vector2i.ZERO:
		push_warning("No lake position found.")
		return

	# Improved lake shape — noisy, irregular, oval
	var lake_noise := FastNoiseLite.new()
	lake_noise.seed = base_seed + 123
	lake_noise.frequency = 0.12
	var lake_radius = 30 + randi() % 20
	for oy in range(-lake_radius, lake_radius + 1):
		for ox in range(-lake_radius, lake_radius + 1):
			var nx = high_pt.x + ox
			var ny = high_pt.y + oy
			if nx < 0 or ny < 0 or nx >= map_width or ny >= map_height:
				continue
			var d = sqrt(float(ox * ox + oy * oy))
			var noise_val = (lake_noise.get_noise_2d(nx, ny) * 0.5 + 0.5)
			var max_r = lake_radius * (0.7 + 0.4 * noise_val)
			if d < max_r:
				W.set_pixel(nx, ny, Color(1, 0, 0))

	# Find river mouth at ocean edge
	var mouth_candidates: Array = []
	var edge_y = 5 if ocean_position == "Top" else map_height - 5
	for x in range(20, map_width - 20):
		var h = H.get_pixel(x, edge_y).r
		if h < sea_level + 0.1:
			mouth_candidates.append(Vector2i(x, edge_y))

	if mouth_candidates.is_empty():
		push_warning("No valid river mouth found.")
		return

	river_mouth = mouth_candidates[randi() % mouth_candidates.size()]

	# Trace river downhill (auto-continue if plateau)
	river_path = _trace_river_to_sea(lake_position)
	_mark_river()

# -------------------------------------------------------------
# Trace river until sea level
# -------------------------------------------------------------
func _trace_river_to_sea(start: Vector2i, max_steps := 9000) -> Array:
	var path: Array = [start]
	var current = start
	for i in range(max_steps):
		var h_here = H.get_pixel(current.x, current.y).r
		if h_here <= sea_level:
			break

		var best_neighbor = current
		var best_h = h_here
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				if ox == 0 and oy == 0:
					continue
				var nx = clamp(current.x + ox, 0, map_width - 1)
				var ny = clamp(current.y + oy, 0, map_height - 1)
				var nh = H.get_pixel(nx, ny).r
				if nh < best_h or (nh <= sea_level + 0.02):
					best_h = nh
					best_neighbor = Vector2i(nx, ny)

		if best_neighbor == current:
			# Nudge river downhill if stuck
			var dir = Vector2(river_mouth - current).normalized()
			current += Vector2i(round(dir.x), round(dir.y))
			current.x = clamp(current.x, 0, map_width - 1)
			current.y = clamp(current.y, 0, map_height - 1)
			path.append(current)
			continue

		path.append(best_neighbor)
		current = best_neighbor

	return path

# -------------------------------------------------------------
# Paint river wider
# -------------------------------------------------------------
func _mark_river():
	for p in river_path:
		for oy in range(-4, 5):
			for ox in range(-4, 5):
				var nx = p.x + ox
				var ny = p.y + oy
				if nx >= 0 and ny >= 0 and nx < map_width and ny < map_height:
					W.set_pixel(nx, ny, Color(1, 0, 0))


func _on_button_pressed() -> void:
	regenerate()
