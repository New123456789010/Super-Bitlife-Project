# road_gen.gd
extends Node
class_name RoadGen

@export var max_major_length := 3000.0
@export var max_minor_length := 2000.0
@export var road_step := 15.0
@export var branch_chance := 0.02
@export var minor_branch_chance := 0.04
@export var tensor_scale := 0.002
@export var edge_margin_override: int = -1  # if >0 will override owner's edge margin

# Internal
var _owner: Node = null
var _rng := RandomNumberGenerator.new()
var _tensor_field = null

# --- Road agent ---
class RoadAgent:
	var pos: Vector2
	var dir: Vector2
	var path := PackedVector2Array()
	var alive := true
	var type := "major"

	func _init(p: Vector2, d: Vector2, t := "major"):
		pos = p
		dir = d.normalized()
		type = t
		path.append(p)

# --- Simple TensorField implementation (replaceable) ---
class TensorField:
	var noise := FastNoiseLite.new()
	func _init(seed = 0):
		noise.seed = seed
		noise.frequency = 0.0015
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	func sample_direction(p: Vector2, scale: float) -> Vector2:
		var n = noise.get_noise_2d(p.x * scale, p.y * scale) * TAU
		return Vector2(cos(n), sin(n)).normalized()

# --- Setup (optional) ---
func setup(owner: Node) -> void:
	_owner = owner
	_rng.randomize()
	_tensor_field = TensorField.new(_rng.randi())

# --- Convenience generate: builds seeds then runs growth ---
func generate(owner: Node) -> void:
	_owner = owner
	if _tensor_field == null:
		_tensor_field = TensorField.new(_rng.randi())

	# ensure owner's arrays exist and are arrays
	if not owner.has_method("_city_core"):
		push_error("RoadGen: owner missing _city_core()")
		return

	# Clear owner's arrays (mutate in-place)
	if owner.has_method("major_roads") == false:
		# if owner uses properties, assume they exist; otherwise ensure fields exist
		pass
	_owner.major_roads.clear()
	_owner.minor_roads.clear()

	# Build seeds
	var major_seeds = _make_major_seeds( max(16, int(_rng.randi_range(20, 40))) )
	# We'll start minors after majors are grown, but build some random precursors
	var minor_seeds = _make_random_minor_seeds( max(80, int(_rng.randi_range(120, 200))) )

	# Grow majors first
	_grow_roads(major_seeds, "major")

	# Now make minor seeds biased near the newly generated majors
	var near_major_seeds = _make_minor_seeds_near_majors(_rng.randi_range(120, 220))
	# Combine with random ones
	minor_seeds.append_array(near_major_seeds)

	# Grow minors
	_grow_roads(minor_seeds, "minor")

	_postprocess_roads()

# -----------------------
# Seed generators
# -----------------------
func _make_major_seeds(count: int) -> Array:
	var seeds := []
	var map_size = _owner.map_size
	for i in range(count):
		if _rng.randf() < 0.55:
			# spawn on random edge
			var side = _rng.randi_range(0, 3)
			var pos = Vector2()
			match side:
				0:
					pos.x = 0; pos.y = _rng.randf_range(0, map_size.y)
				1:
					pos.x = map_size.x; pos.y = _rng.randf_range(0, map_size.y)
				2:
					pos.y = 0; pos.x = _rng.randf_range(0, map_size.x)
				3:
					pos.y = map_size.y; pos.x = _rng.randf_range(0, map_size.x)
			# small jitter inward
			pos += (Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf_range(6, 36))
			seeds.append(pos)
		else:
			# spawn near core
			var core = _owner._city_core()
			var r = min(map_size.x, map_size.y) * _rng.randf_range(0.08, 0.35)
			var ang = _rng.randf() * TAU
			var pos = core + Vector2.RIGHT.rotated(ang) * r
			pos += Vector2(_rng.randf_range(-12, 12), _rng.randf_range(-12, 12))
			seeds.append(pos)
	return seeds

func _make_random_minor_seeds(count: int) -> Array:
	var seeds := []
	for i in range(count):
		seeds.append(Vector2(_rng.randf_range(0, _owner.map_size.x), _rng.randf_range(0, _owner.map_size.y)))
	return seeds

func _make_minor_seeds_near_majors(count: int) -> Array:
	var seeds := []
	var maj = _owner.major_roads
	var maj_count = maj.size()
	if maj_count == 0:
		return _make_random_minor_seeds(count)
	for i in range(count):
		var mr = maj[_rng.randi_range(0, maj_count - 1)]
		if mr.size() < 2:
			continue
		var si = _rng.randi_range(0, mr.size() - 2)
		var a = mr[si]; var b = mr[si + 1]
		var t = _rng.randf()
		var p = a.lerp(b, t)
		# offset a bit
		p += Vector2(_rng.randf_range(-24, 24), _rng.randf_range(-24, 24))
		seeds.append(p)
	return seeds

# -----------------------
# Growth core (agent system)
# -----------------------
func _grow_roads(seeds: Array, road_type: String) -> void:
	var max_length = max_major_length if road_type == "major" else max_minor_length
	var step_len = road_step * ( 1.0 if road_type == "major" else 0.6 )
	var branch_prob = branch_chance if road_type == "major" else minor_branch_chance

	var agents: Array = []
	for s in seeds:
		var dir = _tensor_field.sample_direction(s, tensor_scale)
		agents.append(RoadAgent.new(s, dir, road_type))

	# Active growth loop
	while agents.size() > 0:
		# iterate a copy because agents may append during loop (branching)
		for agent in agents.duplicate():
			if not agent.alive:
				continue

			# Steer toward tensor field
			var field_dir = _tensor_field.sample_direction(agent.pos, tensor_scale)
			agent.dir = (agent.dir * 0.72 + field_dir * 0.28).normalized()

			# Step
			var next_pos = agent.pos + agent.dir * step_len

			# margin check (use owner's edge_margin if present)
			var em = 0

			if edge_margin_override > 0:
				em = edge_margin_override
			elif _owner.has_method("edge_margin"):
				em = _owner.edge_margin()
			else:
				em = _owner.edge_margin

			if next_pos.x < em or next_pos.y < em or next_pos.x > float(_owner.map_size.x - em) or next_pos.y > float(_owner.map_size.y - em):
				agent.alive = false
				continue

			# avoid parks/water if you want: uncomment checks if desired
			# if _is_in_park(next_pos) or _is_in_water(next_pos):
			#     agent.alive = false; continue

			# proximity to existing roads -> snap and terminate
			if _is_within_snap(next_pos, road_step * 0.9):
				var q = _owner._snap_to_nearest_path(next_pos, _owner.major_roads + _owner.minor_roads + _owner.diagonals)
				agent.path.push_back(q)
				agent.alive = false
				continue

			# commit step
			agent.path.push_back(next_pos)
			agent.pos = next_pos

			# length limit
			if agent.path.size() * step_len > max_length:
				agent.alive = false
				continue

			# branching
			if _rng.randf() < branch_prob and agent.path.size() > 6:
				var branch_angle = _rng.randf_range(-PI * 0.45, PI * 0.45)
				var branch_dir = agent.dir.rotated(branch_angle)
				var branch_agent = RoadAgent.new(agent.pos + branch_dir * (step_len * 0.5), branch_dir, road_type)
				agents.append(branch_agent)

			# safety guard
			if agent.path.size() > 12000:
				agent.alive = false

		# remove dead agents from the active list (keeps memory bounded)
		for i in range(agents.size() - 1, -1, -1):
			if not agents[i].alive:
				# store the finished path on owner immediately
				var finished = agents[i].path
				if finished.size() >= 3:
					if agents[i].type == "major":
						_owner.major_roads.append(finished)
					else:
						_owner.minor_roads.append(finished)
				agents.remove_at(i)

# -----------------------
# Utilities: snapping / checks
# -----------------------
func _is_within_snap(p: Vector2, d: float) -> bool:
	var dd2 = d * d
	for path in _owner.major_roads:
		for i in range(path.size() - 1):
			var q = _owner._closest_point_on_segment(path[i], path[i + 1], p)
			if (q - p).length_squared() <= dd2:
				return true
	for path in _owner.minor_roads:
		for i in range(path.size() - 1):
			var q = _owner._closest_point_on_segment(path[i], path[i + 1], p)
			if (q - p).length_squared() <= dd2:
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

# -----------------------
# Postprocess: keep arrays, prune tiny
# -----------------------
func _postprocess_roads() -> void:
	# prune trivial
	var cleaned_major := []
	for path in _owner.major_roads:
		if typeof(path) == TYPE_PACKED_VECTOR2_ARRAY and path.size() >= 3:
			cleaned_major.append(path)
	_owner.major_roads.clear()
	_owner.major_roads.append_array(cleaned_major)

	var cleaned_minor := []
	for path in _owner.minor_roads:
		if typeof(path) == TYPE_PACKED_VECTOR2_ARRAY and path.size() >= 3:
			cleaned_minor.append(path)
	_owner.minor_roads.clear()
	_owner.minor_roads.append_array(cleaned_minor)
