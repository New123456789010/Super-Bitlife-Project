extends Node
class_name TerrainGenerator

signal data_changed

@export var map_width: int = 540
@export var map_height: int = 990
@export_range(0.0, 1.0, 0.01) var sea_level: float = 0.25
@export var base_seed: int = 1337
@export var base_frequency: float = 0.002
@export var base_octaves: int = 5
@export var ocean_at_top: bool = false
@export_range(0, 8, 1) var water_smooth_iters: int = 3
@export_range(0.2, 1.0, 0.05) var continent_ratio: float = 0.8  # NEW: how large continent is relative to map

var H: Image
var W: Image

var river_path: Array = []
var lake_position: Vector2i = Vector2i.ZERO
var river_mouth: Vector2i = Vector2i.ZERO

func _ready() -> void:
	generate_all(base_seed)

func regenerate(optional_seed: int = -1) -> void:
	if optional_seed >= 0:
		base_seed = optional_seed
	else:
		base_seed = randi()
	print("TerrainGenerator: regenerating seed =", base_seed)
	generate_all(base_seed)
	emit_signal("data_changed", H, W)

func generate_all(seed: int) -> void:
	base_seed = seed
	_generate_heightmap()
	_generate_water_mask()
	_place_lake_and_river()
	_smooth_water_mask(water_smooth_iters)
	emit_signal("data_changed", H, W)
	print("TerrainGenerator: generation complete (seed %d)" % base_seed)

# -------------------------
# Heightmap using FastNoiseLite
# -------------------------
func _generate_heightmap() -> void:
	H = Image.create(map_width, map_height, false, Image.FORMAT_RF)

	var f := FastNoiseLite.new()
	f.seed = int(base_seed)
	f.frequency = base_frequency
	f.fractal_octaves = base_octaves

	for y in range(map_height):
		for x in range(map_width):
			var n = f.get_noise_2d(x, y) * 0.5 + 0.5
			var ny = float(y) / float(map_height)
			var pole_factor = ny if ocean_at_top else (1.0 - ny)
			# continent_ratio compresses the falloff band
			var adjusted = clamp((pole_factor - (1.0 - continent_ratio) * 0.5) / continent_ratio, 0.0, 1.0)
			var fall = pow(adjusted, 0.7)
			var slope_bias = ny if ocean_at_top else (1.0 - ny)
			var h = clamp(n * fall, 0.0, 1.0)
			h = clamp(h * 0.9 + slope_bias * 0.1, 0.0, 1.0)
			H.set_pixel(x, y, Color(h, 0, 0))

# -------------------------
# Water mask from H
# -------------------------
func _generate_water_mask() -> void:
	W = Image.create(map_width, map_height, false, Image.FORMAT_RF)
	for y in range(map_height):
		for x in range(map_width):
			var h = H.get_pixel(x, y).r
			W.set_pixel(x, y, Color(1.0 if h < sea_level else 0.0, 0, 0))

func _smooth_water_mask(passes: int) -> void:
	for p in range(passes):
		var tmp := Image.create(map_width, map_height, false, Image.FORMAT_RF)
		for y in range(map_height):
			for x in range(map_width):
				var sum = 0.0
				var count = 0
				for oy in range(-1, 2):
					for ox in range(-1, 2):
						var nx = x + ox
						var ny = y + oy
						if nx >= 0 and ny >= 0 and nx < map_width and ny < map_height:
							sum += W.get_pixel(nx, ny).r
							count += 1
				var avg = sum / float(count)
				tmp.set_pixel(x, y, Color(1.0 if avg > 0.45 else 0.0, 0, 0))
		W = tmp

# -------------------------
# Lake + river generation
# -------------------------
func _place_lake_and_river() -> void:
	# --- Find main lake (highest inland peak)
	var best_pt := Vector2i.ZERO
	var best_h := -1.0
	var y_lo = int(map_height * 0.25)
	var y_hi = int(map_height * 0.65)
	for y in range(y_lo, y_hi):
		for x in range(int(map_width * 0.25), int(map_width * 0.75)):
			var hh = H.get_pixel(x, y).r
			if hh > best_h:
				best_h = hh
				best_pt = Vector2i(x, y)
	lake_position = best_pt
	if lake_position == Vector2i.ZERO:
		push_warning("No lake position found")
		return

	# --- Create a shallow lake
	var ln := FastNoiseLite.new()
	ln.seed = int(base_seed) + 101
	ln.frequency = 0.18
	ln.fractal_octaves = 2
	var radius = int(clamp(18 + (base_seed % 20), 15, 45))
	for oy in range(-radius, radius + 1):
		for ox in range(-radius, radius + 1):
			var px = lake_position.x + ox
			var py = lake_position.y + oy
			if px < 0 or py < 0 or px >= map_width or py >= map_height:
				continue
			var d = sqrt(float(ox * ox + oy * oy)) / float(radius)
			var noisev = ln.get_noise_2d(px, py) * 0.5 + 0.5
			var threshold = 0.85 * (1.0 - d) + 0.25 * noisev
			if threshold > 0.5:
				W.set_pixel(px, py, Color(1, 0, 0))
				var old_h = H.get_pixel(px, py).r
				var lake_h = max(old_h, sea_level + 0.05)
				H.set_pixel(px, py, Color(lake_h, 0, 0))

	# --- Find river mouths near coast
	var mouths: Array[Vector2i] = []
	var edge_margin = 3
	for x in range(map_width):
		if H.get_pixel(x, map_height - edge_margin - 1).r <= sea_level + 0.05:
			mouths.append(Vector2i(x, map_height - edge_margin - 1))
	if mouths.is_empty():
		push_warning("No river mouths found")
		return

	river_path.clear()

	# --- Main river from lake to sea
	var main_mouth = mouths.pick_random()
	var main_path = _trace_river_to_sea(lake_position, main_mouth)
	river_path.append_array(main_path)

	# --- Secondary rivers (tributaries)
	for i in range(3): # 3 smaller rivers joining main one
		var tries = 0
		var source = Vector2i.ZERO
		while tries < 500:
			var x = randi_range(int(map_width * 0.2), int(map_width * 0.8))
			var y = randi_range(int(map_height * 0.2), int(map_height * 0.8))
			var h = H.get_pixel(x, y).r
			if h > 0.55:
				source = Vector2i(x, y)
				break
			tries += 1
		if source == Vector2i.ZERO:
			continue

		# Pick nearest point on main river as join target
		var nearest = main_path[0]
		var best_dist = 999999.0
		for p in main_path:
			var d = source.distance_to(p)
			if d < best_dist:
				best_dist = d
				nearest = p

		var trib_path = _trace_river_to_sea(source, nearest)
		river_path.append_array(trib_path)
	
	# Force river to visually connect to ocean
	var end = river_path[-1]
	for y in range(end.y, map_height):
		for x in range(end.x - 2, end.x + 3):
			if x >= 0 and x < map_width:
				H.set_pixel(x, y, Color(sea_level * 0.9, 0, 0))
				W.set_pixel(x, y, Color(1, 0, 0))

	# --- Carve all rivers into terrain
	for p in river_path:
		for oy in range(-2, 3):
			for ox in range(-2, 3):
				var nx = p.x + ox
				var ny = p.y + oy
				if nx >= 0 and ny >= 0 and nx < map_width and ny < map_height:
					var old = H.get_pixel(nx, ny).r
					var lowered = min(old, max(sea_level * 0.9, old - 0.02))
					H.set_pixel(nx, ny, Color(lowered, 0, 0))
					W.set_pixel(nx, ny, Color(1, 0, 0))

	print("Main river length:", main_path.size(), "Total rivers:", river_path.size())

# -------------------------
# Improved downhill tracing
# -------------------------
func _trace_river_to_sea(start: Vector2i, target: Vector2i, max_steps: int = 5000) -> Array:
	var path: Array = [start]
	var current := start
	var visited := {}
	visited[current] = true

	for step in range(max_steps):
		var h_here = H.get_pixel(current.x, current.y).r

		# Stop if already reached ocean or coast
		if h_here <= sea_level + 0.01 or current.y >= map_height - 2:
			break

		var best_pos := current
		var best_score = h_here

		for oy in range(-1, 2):
			for ox in range(-1, 2):
				if ox == 0 and oy == 0:
					continue
				var nx = clamp(current.x + ox, 0, map_width - 1)
				var ny = clamp(current.y + oy, 0, map_height - 1)
				var nh = H.get_pixel(nx, ny).r

				# Prefer lower height and closer to ocean (bottom)
				var height_factor = nh
				var y_bias = float(ny) / map_height * 0.2  # prefer southward (toward ocean)
				var noise_bias = randf_range(-0.02, 0.02)
				var score = height_factor + y_bias + noise_bias

				if score < best_score:
					best_score = score
					best_pos = Vector2i(nx, ny)

		# Prevent infinite loops
		if best_pos == current or best_pos in visited:
			# fallback: pick any nearby pixel closer to ocean
			var fallback := Vector2i(current.x, min(map_height - 1, current.y + 1))
			best_pos = fallback

		visited[best_pos] = true
		current = best_pos
		path.append(current)

		# Hard stop if reached very bottom row (guarantee connection)
		if current.y >= map_height - 3:
			break

	return path
