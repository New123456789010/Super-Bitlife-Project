extends Node

class_name RoadGen

# ---------- Tunables ----------
@export var major_seed_count: int = 36
@export var minor_seed_count: int = 220
@export var major_step: float = 12.0
@export var minor_step: float = 8.0
@export var max_major_length: int = 300
@export var max_minor_length: int = 120
@export var major_branch_chance: float = 0.06
@export var minor_branch_chance: float = 0.03
@export var snap_distance: float = 12.0
@export var avoid_park_water: bool = true
@export var tensor_noise_scale: float = 0.0012
@export var tensor_rotation_strength: float = 0.6
@export var minor_grid_spacing_min: float = 40.0
@export var minor_grid_spacing_max: float = 110.0
@export var edge_margin: float = 64.0
@export var map_size: Vector2 = Vector2(540, 990)

# ---------- Internal ----------
var _owner: Node = null
var _rng := RandomNumberGenerator.new()
var _tensor_seed: int = 0

# --- Entry point (call from CityMap) ---
func generate(owner: Node) -> void:
	_owner = owner
	# randomize RNG from owner's seed if available
	if _owner.has_method("_set_seed") or _owner.has_method("_set_seed"): # noop check
		pass
	_rng.randomize()
	_tensor_seed = _rng.randi()
	# ensure arrays exist & clear them (mutate in-place)
	if "major_roads" in _owner:
		if typeof(_owner.major_roads) == TYPE_ARRAY:
			_owner.major_roads.clear()
		else:
			_owner.major_roads = []
	else:
		_owner.major_roads = []

	if "minor_roads" in _owner:
		if typeof(_owner.minor_roads) == TYPE_ARRAY:
			_owner.minor_roads.clear()
		else:
			_owner.minor_roads = []
	else:
		_owner.minor_roads = []

	# Build field (no persistent object to keep simple)
	# Generate majors
	var major_seeds = _make_major_seeds(major_seed_count)
	_generate_major_roads(major_seeds)
	# Generate minors (bias near majors)
	var minor_seeds = _make_minor_seeds_near_majors(minor_seed_count)
	_generate_minor_roads(minor_seeds)
	_postprocess_roads()

# ---------- Tensor / direction helpers ----------
func _tensor_field_direction(p: Vector2) -> Vector2:
	# Combine noise + attraction toward city core (owner has _city_core and _city_score)
	var core = _owner._city_core()
	var to_core = (core - p)
	if to_core.length() > 0.0:
		to_core = to_core.normalized()
	else:
		to_core = Vector2.RIGHT
	# noise-driven rotation
	var noisev = _owner._noise.get_noise_2d(p.x * tensor_noise_scale, p.y * tensor_noise_scale)
	var rot = noisev * PI * 0.5
	# blend base direction (toward core) with a rotated orthogonal/noise vector to make grids + radial
	var base_dir = Vector2(1, 0).rotated(rot)
	var grid_strength = clamp(_owner._city_score(p), 0.0, 1.0)
	var major_dir = base_dir.slerp(to_core, grid_strength * tensor_rotation_strength).normalized()
	# final small noise jitter
	var jitter = _owner._noise.get_noise_2d(p.x * tensor_noise_scale * 2.1, p.y * tensor_noise_scale * 2.1) * 0.18
	return major_dir.rotated(jitter).normalized()

# ---------- Major seeds ----------
func _make_major_seeds(count: int) -> Array:
	var seeds := []
	var ms = _owner.map_size
	for i in range(count):
		if _rng.randf() < 0.6:
			# spawn on an edge (random side) and jitter inward
			var side = _rng.randi_range(0, 3)
			var pos = Vector2()
			match side:
				0:
					pos.x = 0; pos.y = _rng.randf_range(0, ms.y)
				1:
					pos.x = ms.x; pos.y = _rng.randf_range(0, ms.y)
				2:
					pos.y = 0; pos.x = _rng.randf_range(0, ms.x)
				3:
					pos.y = ms.y; pos.x = _rng.randf_range(0, ms.x)
			# push slightly inward
			pos += Vector2(_rng.randf_range(-24, 24), _rng.randf_range(-24, 24))
			seeds.append(_clamp_pt(pos))
		else:
			# near city core
			var core = _owner._city_core()
			var r = min(ms.x, ms.y) * _rng.randf_range(0.06, 0.35)
			var ang = _rng.randf() * TAU
			var pos = core + Vector2.RIGHT.rotated(ang) * r
			pos += Vector2(_rng.randf_range(-16, 16), _rng.randf_range(-16, 16))
			seeds.append(_clamp_pt(pos))
	return seeds

# ---------- Major growth (agent-based) ----------
func _generate_major_roads(seeds: Array) -> void:
	var agents := []

	# Initialize major agents
	for s in seeds:
		var dir = Vector2.RIGHT.rotated(randf_range(-PI / 8, PI / 8))
		agents.append({
			"pos": s,
			"dir": dir,
			"path": PackedVector2Array([s]),
			"alive": true
		})

	while agents.size() > 0:
		for a in agents:
			if not a["alive"]:
				continue

			var pos: Vector2 = a["pos"]
			var dir: Vector2 = a["dir"]

			# Check boundaries
			if not _inside_margin(pos):
				a["alive"] = false
				continue

			# Compute tensor-guided direction
			var tensor_dir = _tensor_field_direction(pos)
			dir = (dir + tensor_dir * 0.3).normalized()

			# Step forward
			pos += dir * major_step

			# Stop if hitting restricted area
			if _is_blocked(pos):
				a["alive"] = false
				continue

			a["path"].append(pos)
			a["pos"] = pos
			a["dir"] = dir

			# Stop if max length reached
			if a["path"].size() >= max_major_length:
				a["alive"] = false

		agents = agents.filter(func(x): return x["alive"])

	for a in agents:
		if a["path"].size() >= 3:
			_owner.major_roads.append(a["path"])

# ---------- Minor seeds generation biased near major roads ----------
func _make_minor_seeds_near_majors(count: int) -> Array:
	var seeds := []
	var maj = _owner.major_roads
	if maj.size() == 0:
		# fallback random seeds
		for i in range(count):
			seeds.append(Vector2(_rng.randf_range(0, _owner.map_size.x), _rng.randf_range(0, _owner.map_size.y)))
		return seeds

	for i in range(count):
		# pick a random major road and sample a random segment point then jitter
		var mr = maj[_rng.randi_range(0, maj.size() - 1)]
		if mr.size() < 2:
			i -= 1
			continue
		var si = _rng.randi_range(0, mr.size() - 2)
		var a = mr[si]; var b = mr[si + 1]
		var t = _rng.randf()
		var p = a.lerp(b, t)
		# offset a bit perpendicular or toward interior
		var seg_dir = (b - a)
		if seg_dir.length() == 0.0:
			seg_dir = Vector2.RIGHT
		seg_dir = seg_dir.normalized()
		var perp = Vector2(-seg_dir.y, seg_dir.x)
		p += perp * _rng.randf_range(-60.0, 60.0)
		p += Vector2(_rng.randf_range(-10, 10), _rng.randf_range(-10, 10))
		if _owner._inside_margin(p) and (not avoid_park_water or (not _is_in_park(p) and not _is_in_water(p))):
			seeds.append(p)
	return seeds

# ---------- Minor roads generation: grid-like fills oriented to nearest major ----------
func _generate_minor_roads(seeds: Array) -> void:
	var agents := []

	for s in seeds:
		var dir = Vector2.RIGHT.rotated(randf_range(-PI, PI))
		agents.append({
			"pos": s,
			"dir": dir,
			"path": PackedVector2Array([s]),
			"alive": true
		})

	while agents.size() > 0:
		for a in agents:
			if not a["alive"]:
				continue

			var pos: Vector2 = a["pos"]
			var dir: Vector2 = a["dir"]

			if not _inside_margin(pos):
				a["alive"] = false
				continue

			# Tensor-guided movement, slightly noisier for minor roads
			var tensor_dir = _tensor_field_direction(pos)
			dir = (dir * 0.7 + tensor_dir * 0.3 + Vector2(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1))).normalized()

			pos += dir * minor_step

			if _is_blocked(pos):
				a["alive"] = false
				continue

			a["path"].append(pos)
			a["pos"] = pos
			a["dir"] = dir

			if a["path"].size() >= max_minor_length:
				a["alive"] = false

		agents = agents.filter(func(x): return x["alive"])

	for a in agents:
		if a["path"].size() >= 3:
			_owner.minor_roads.append(a["path"])

# ---------- Trace a short polyline in given direction until collision/edge/water ----------
func _trace_line(start: Vector2, dir: Vector2, step: float, max_len: float, road_type: String) -> PackedVector2Array:
	var path := PackedVector2Array()
	var p = start
	path.push_back(p)
	var traveled = 0.0
	var direction = dir.normalized()
	while traveled < max_len:
		var nextp = p + direction * step
		if not _owner._inside_margin(nextp):
			break
		if avoid_park_water and (_is_in_park(nextp) or _is_in_water(nextp)):
			break
		# stop if near existing major road at snap distance (so we align)
		if _is_near_existing(nextp, snap_distance * 0.9):
			var q = _owner._snap_to_nearest_path(nextp, _owner.major_roads + _owner.minor_roads + _owner.diagonals)
			path.push_back(q)
			return path
		path.push_back(nextp)
		p = nextp
		traveled += step
		# if self-overlap or too close to minor lines, stop
		if _is_near_existing(p, step * 0.5):
			break
	return path

# ---------- Utility: nearest major segment & direction ----------
func _nearest_major_segment(p: Vector2) -> Dictionary:
	var best_d2 = 1e18
	var best = null
	for mr in _owner.major_roads:
		for i in range(mr.size() - 1):
			var a = mr[i]; var b = mr[i + 1]
			var q = _owner._closest_point_on_segment(a, b, p)
			var d2 = (q - p).length_squared()
			if d2 < best_d2:
				best_d2 = d2
				var dir = (b - a)
				if dir.length() == 0.0: dir = Vector2.RIGHT
				best = {"a": a, "b": b, "q": q, "d2": d2, "dir": dir.normalized()}
	return best

# ---------- Proximity helpers ----------
func _is_near_existing(p: Vector2, threshold: float) -> bool:
	var t2 = threshold * threshold
	for path in _owner.major_roads:
		for i in range(path.size()):
			if (path[i] - p).length_squared() <= t2:
				return true
	for path in _owner.minor_roads:
		for i in range(path.size()):
			if (path[i] - p).length_squared() <= t2:
				return true
	for path in _owner.diagonals:
		for i in range(path.size()):
			if (path[i] - p).length_squared() <= t2:
				return true
	return false

func _is_in_water(p: Vector2) -> bool:
	for poly in _owner.water_polys:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false

func _is_in_park(p: Vector2) -> bool:
	for poly in _owner.parks:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false

func _clamp_pt(p: Vector2) -> Vector2:
	# clamp inside a small inset to avoid exact-edge seeds
	var em = _owner.edge_margin if "edge_margin" in _owner else 40
	var x = clamp(p.x, float(em), float(_owner.map_size.x - em))
	var y = clamp(p.y, float(em), float(_owner.map_size.y - em))
	return Vector2(x, y)

# ---------- Postprocess (prune tiny lines + smoothing stub) ----------
func _postprocess_roads() -> void:
	# prune trivials (mutate in-place)
	var keep_major := []
	for path in _owner.major_roads:
		if typeof(path) == TYPE_PACKED_VECTOR2_ARRAY and path.size() >= 3:
			keep_major.append(path)
	_owner.major_roads.clear()
	_owner.major_roads.append_array(keep_major)

	var keep_minor := []
	for path in _owner.minor_roads:
		if typeof(path) == TYPE_PACKED_VECTOR2_ARRAY and path.size() >= 3:
			keep_minor.append(path)
	_owner.minor_roads.clear()
	_owner.minor_roads.append_array(keep_minor)

	# Optional: a small Chaikin smoothing pass for major roads to reduce stair-step
	for i in range(_owner.major_roads.size()):
		_owner.major_roads[i] = _chaikin(_owner.major_roads[i], 1)

# Chaikin smoothing helper (keeps endpoints)
func _chaikin(src: PackedVector2Array, iterations: int) -> PackedVector2Array:
	var poly = src.duplicate()
	for it in range(iterations):
		if poly.size() < 2:
			break
		var next := PackedVector2Array()
		next.push_back(poly[0])
		for j in range(poly.size() - 1):
			var p0 = poly[j]; var p1 = poly[j + 1]
			var q = p0 * 0.75 + p1 * 0.25
			var r = p0 * 0.25 + p1 * 0.75
			next.push_back(q); next.push_back(r)
		next.push_back(poly[poly.size() - 1])
		poly = next
	return poly

# ---------- End of road_gen.gd ----------
# === HELPER FUNCTIONS ===
func _inside_margin(p: Vector2) -> bool:
	if p.x < edge_margin: return false
	if p.y < edge_margin: return false
	if p.x > map_size.x - edge_margin: return false
	if p.y > map_size.y - edge_margin: return false
	return true


func _is_blocked(p: Vector2) -> bool:
	# Placeholder: you can expand this to check your masks
	# Return true if the point lies within water or terrain obstacles
	return false
