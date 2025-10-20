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

	# create lake blob (keep lake elevation ABOVE sea_level so river can flow)
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
			var d = sqrt(float(ox*ox + oy*oy)) / float(radius)
			var noisev = ln.get_noise_2d(px, py) * 0.5 + 0.5
			var threshold = 0.85 * (1.0 - d) + 0.25 * noisev
			if threshold > 0.5:
				W.set_pixel(px, py, Color(1,0,0))
				# IMPORTANT: keep lake at or above sea_level + small margin
				var old_h = H.get_pixel(px, py).r
				var lake_h = max(old_h, sea_level + 0.05)
				H.set_pixel(px, py, Color(lake_h,0,0))

	# river mouth selection (lenient)
	var edge_y = 3 if ocean_at_top else map_height - 4
	var mouths := []
	for x in range(10, map_width - 10):
		if H.get_pixel(x, edge_y).r < sea_level + 0.08:
			mouths.append(Vector2i(x, edge_y))
	if mouths.is_empty():
		for x in range(map_width):
			if W.get_pixel(x, edge_y).r > 0.5:
				mouths.append(Vector2i(x, edge_y))
	if mouths.is_empty():
		push_warning("No river mouth found")
		return
	river_mouth = mouths[randi() % mouths.size()]

	# Trace the river
	river_path = _trace_river_to_sea(lake_position)

	# carve river into heightmap and mark water — clamp so we don't dig below sea level by much
	for p in river_path:
		for oy in range(-2, 3):
			for ox in range(-2, 3):
				var nx = p.x + ox
				var ny = p.y + oy
				if nx >= 0 and ny >= 0 and nx < map_width and ny < map_height:
					var old = H.get_pixel(nx, ny).r
					var lowered = min(old, max(sea_level * 0.9, old - 0.02)) # lower gently but not below sea_level*0.9
					H.set_pixel(nx, ny, Color(lowered, 0, 0))
					W.set_pixel(nx, ny, Color(1,0,0))

	# debug info
	var start_h = H.get_pixel(lake_position.x, lake_position.y).r if lake_position != Vector2i.ZERO else -1.0
	var mouth_h = H.get_pixel(river_mouth.x, river_mouth.y).r if river_mouth != Vector2i.ZERO else -1.0
	print("River start h:", start_h, " mouth:", river_mouth, " mouth_h:", mouth_h, " path_len:", river_path.size())


# -------------------------
# Improved downhill tracing
# -------------------------
func _trace_river_to_sea(start: Vector2i, max_steps: int = 20000) -> Array:
	var path: Array = [start]
	var current := start
	var visited := {}
	visited[current] = true

	for step in range(max_steps):
		var h_here = H.get_pixel(current.x, current.y).r
		# stop if already reached water/sea
		if h_here <= sea_level:
			break

		# evaluate neighbors by a combined score:
		# score = neighbor_height + small_bias * distance_to_mouth_normalized
		var best_score := 1e9
		var best_pos := current
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				if ox == 0 and oy == 0:
					continue
				var nx = clamp(current.x + ox, 0, map_width - 1)
				var ny = clamp(current.y + oy, 0, map_height - 1)
				var nh = H.get_pixel(nx, ny).r
				# distance bias (prefer steps toward mouth)
				var dist_to_mouth = float(Vector2(nx, ny).distance_to(Vector2(river_mouth.x, river_mouth.y)))
				var dist_norm = dist_to_mouth / float(max(map_width, map_height))
				var score = nh + 0.15 * dist_norm  # 0.15 weight is small but directional
				if score < best_score:
					best_score = score
					best_pos = Vector2i(nx, ny)

		# if we didn't move (shouldn't happen), nudge toward mouth
		if best_pos == current:
			var dir = Vector2(river_mouth - current)
			if dir.length() == 0:
				break
			dir = dir.normalized()
			var nx = clamp(current.x + int(round(dir.x)), 0, map_width - 1)
			var ny = clamp(current.y + int(round(dir.y)), 0, map_height - 1)
			best_pos = Vector2i(nx, ny)

		# Erode neighbor slightly to ensure downhill progression (but clamp to not go below sea_level*0.85)
		var nh_now = H.get_pixel(best_pos.x, best_pos.y).r
		var target_h = min(nh_now, h_here - 0.002)  # make it slightly lower than current
		target_h = max(target_h, sea_level * 0.85)  # don't erode super deep below sea
		H.set_pixel(best_pos.x, best_pos.y, Color(target_h, 0, 0))

		# stop if already visited (prevent loops)
		if best_pos in visited:
			break
		visited[best_pos] = true

		path.append(best_pos)
		current = best_pos

		# if near the edge (ocean pole), terminate
		if (ocean_at_top and current.y <= 2) or (!ocean_at_top and current.y >= map_height - 3):
			break

	return path
