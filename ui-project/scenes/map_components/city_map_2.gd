extends Node2D
# @tool  # optional

# -------- Size & seed --------
@export var map_size: Vector2i = Vector2i(2048, 1536)
@export var randomize_on_play: bool = true
@export var fixed_seed: int = 0
var seed: int = 0

# -------- Theme colors --------
@export var color_land: Color = Color("#d9d9d9")
@export var color_water: Color = Color("#6ec8ff")
@export var color_park:  Color = Color("#94d38b")
@export var color_road_major: Color = Color(1, 1, 1)
@export var color_road_minor: Color = Color(1, 1, 1)

@export var width_river: float = 28.0
@export var width_road_major: float = 10.0
@export var width_road_minor: float = 4.0

# -------- Water mode --------
# 0=River, 1=Coastline, 2=None, 3=Random
@export_enum("River","Coastline","None","Random") var water_mode: int = 3

# -------- Pin settings --------
const PIN_CAFE: int = 0
const PIN_OFFICE: int = 1
const PIN_MARKET: int = 2
const PIN_PARK: int = 3
const PIN_AMUSE: int = 4
const PIN_HOME: int = 5

@export var count_cafe: int = 20
@export var count_office: int = 22
@export var count_market: int = 18
@export var count_park_pin: int = 8
@export var count_amusement: int = 10
@export var count_home: int = 40
@export var pin_radius: float = 8.0
@export var pin_outline: float = 3.0

# --- distribution controls (avoid massing on one road) ---
@export var min_dist_office: float = 140.0
@export var min_dist_market: float = 130.0
@export var min_dist_amuse: float = 150.0
@export var per_path_cap_office: int = 6
@export var per_path_cap_market: int = 5
@export var per_path_cap_amuse: int = 4

# Keep pins away from edges
@export var edge_margin: int = 80

# -------- Zoning (debug) --------
var debug_show_zones: bool = false

const Z_RESIDENTIAL: int = 0
const Z_MIXED: int = 1
const Z_COMMERCIAL: int = 2

var zone_centers: Array[Vector2] = []
var zone_sigmas: Array[float] = []

# -------- Data --------
@export var major_roads: Array[PackedVector2Array] = []
@export var minor_roads: Array[PackedVector2Array] = []
var diagonals: Array[PackedVector2Array] = []
var river: PackedVector2Array = PackedVector2Array()
var water_polys: Array[PackedVector2Array] = []
var parks: Array[PackedVector2Array] = []
var park_centroids: Array[Vector2] = []

var pin_pos: Array[Vector2] = []
var pin_kind: Array[int] = []

var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()

var RoadGen := preload("res://scenes/map_components/road_gen.gd").new()

# -------- Lifecycle --------
func _ready() -> void:
	if randomize_on_play:
		_reroll_seed()
	else:
		var s: int = 123456
		if fixed_seed > 0:
			s = fixed_seed
		_set_seed(s)
	generate()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_reroll_seed(); generate(); queue_redraw()
		elif event.keycode == KEY_S:
			save_as_png()
		elif event.keycode == KEY_Z:
			debug_show_zones = not debug_show_zones
			queue_redraw()

# -------- Public: regenerate --------
func generate() -> void:
	major_roads.clear(); minor_roads.clear(); diagonals.clear()
	parks.clear(); park_centroids.clear()
	water_polys.clear(); river.resize(0)
	pin_pos.clear(); pin_kind.clear()
	zone_centers.clear(); zone_sigmas.clear()

	# Random style knobs per run
	var minor_spacing: int = _rng.randi_range(50, 85)
	var major_spacing: int = _rng.randi_range(220, 320)
	var jitter: float = _rng.randf_range(6.0, 14.0)
	var diagonal_chance: float = _rng.randf_range(0.35, 0.9)
	var park_count: int = _rng.randi_range(18, 36)

	_make_water_variant()
	_make_parks(park_count)
	_compute_park_centroids()
	
	RoadGen.generate(self)
	
	_make_zones()           # NEW
	_make_pins()            # NEW

# -------- Seed helpers --------
func _reroll_seed() -> void:
	_rng.randomize()
	var s: int = _rng.randi()
	_set_seed(s)

func _set_seed(s: int) -> void:
	seed = s
	_rng.seed = seed
	_noise.seed = seed
	_noise.frequency = 0.0015
	_noise.fractal_octaves = 3

# -------- Generators --------
func _make_water_variant() -> void:
	# Always draw BOTH
	_make_coastline()
	_make_river()


func _make_river() -> void:
	var w: float = float(map_size.x)
	var h: float = float(map_size.y)
	var start: Vector2 = Vector2(-100.0, _rng.randf_range(h * 0.3, h * 0.7))
	var endp:  Vector2 = Vector2(w + 100.0, _rng.randf_range(h * 0.3, h * 0.7))
	var c1: Vector2 = Vector2(w * 0.25, _rng.randf_range(h * 0.15, h * 0.85))
	var c2: Vector2 = Vector2(w * 0.75, _rng.randf_range(h * 0.15, h * 0.85))

	var pts := PackedVector2Array()
	var steps: int = int(max(80.0, w / 8.0))
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var p: Vector2 = _cubic_bezier(start, c1, c2, endp, t)
		var n: float = _noise.get_noise_2d(p.x * 0.6, p.y * 0.6)
		p.y += n * 30.0
		pts.push_back(p)
	river = pts

func _make_coastline() -> void:
	var w: float = float(map_size.x)
	var h: float = float(map_size.y)
	var side: int = _rng.randi_range(0, 1) # 0 = top, 1 = left
	var steps: int = 64

	if side == 0:
		var coast := PackedVector2Array()
		coast.push_back(Vector2(0, 0))
		for i in range(steps + 1):
			var x: float = lerp(0.0, w, float(i) / float(steps))
			var y: float = 40.0 * sin(x * 0.01) + _noise.get_noise_2d(x, 0.0) * 60.0 + _rng.randf_range(20.0, 80.0)
			coast.push_back(Vector2(x, y))
		coast.push_back(Vector2(w, 0))

		var water := PackedVector2Array()
		water.push_back(Vector2(0, -2000))
		water.push_back(Vector2(w, -2000))
		for i in range(steps, -1, -1):
			water.push_back(coast[i + 1])
		water_polys.push_back(water)
	else:
		var coast2 := PackedVector2Array()
		coast2.push_back(Vector2(0, 0))
		for i in range(steps + 1):
			var y2: float = lerp(0.0, h, float(i) / float(steps))
			var x2: float = 40.0 * sin(y2 * 0.01) + _noise.get_noise_2d(0.0, y2) * 60.0 + _rng.randf_range(20.0, 80.0)
			coast2.push_back(Vector2(x2, y2))
		coast2.push_back(Vector2(0, h))

		var water2 := PackedVector2Array()
		water2.push_back(Vector2(-2000, 0))
		water2.push_back(Vector2(-2000, h))
		for i in range(steps, -1, -1):
			water2.push_back(coast2[i + 1])
		water_polys.push_back(water2)

func _make_parks(park_count: int) -> void:
	var w: float = float(map_size.x)
	var h: float = float(map_size.y)
	for i in range(park_count):
		var c: Vector2 = Vector2(_rng.randf_range(60.0, w - 60.0), _rng.randf_range(60.0, h - 60.0))
		var r: float = _rng.randf_range(25.0, 120.0)
		var sides: int = _rng.randi_range(6, 12)
		var poly := PackedVector2Array()
		for k in range(sides):
			var ang: float = TAU * float(k) / float(sides)
			var rr: float = r * (0.7 + 0.6 * _rng.randf())
			var p: Vector2 = c + Vector2.RIGHT.rotated(ang) * rr
			var n: float = _noise.get_noise_2d(p.x, p.y)
			p += Vector2(n * 12.0, n * 12.0).rotated(ang)
			poly.push_back(p)
		parks.push_back(poly)

func _compute_park_centroids() -> void:
	for poly in parks:
		var cx: float = 0.0
		var cy: float = 0.0
		if poly.size() > 0:
			for p in poly:
				cx += p.x; cy += p.y
			cx /= float(poly.size()); cy /= float(poly.size())
		park_centroids.append(Vector2(cx, cy))

func _make_roads_tensor_field() -> void:
	var field_res := 64  # lower = smoother, higher = more detail
	var field_scale := map_size / float(field_res)
	var directions: Array = []
	
	# --- Build tensor field ---
	for y in range(field_res + 1):
		directions.append([])
		for x in range(field_res + 1):
			var nx = float(x) / field_res
			var ny = float(y) / field_res
			
			# base orientation curved toward city center
			var dir = (Vector2(map_size.x * 0.5, map_size.y * 0.5) - Vector2(nx * map_size.x, ny * map_size.y)).normalized()
			
			# add noise perturbation for natural variation
			var angle_noise = _noise.get_noise_2d(nx * 2.0, ny * 2.0) * PI * 0.25
			dir = dir.rotated(angle_noise)
			
			directions[y].append(dir)
	
	# --- Road growth agents ---
	var major_count := 40
	var minor_count := 80
	var max_len_major := 800.0
	var max_len_minor := 300.0
	
	var road_points_major: Array[PackedVector2Array] = []
	var road_points_minor: Array[PackedVector2Array] = []
	
	# --- Major road agents ---
	for i in range(major_count):
		var pos = Vector2(
			_rng.randf_range(0, map_size.x),
			_rng.randf_range(0, map_size.y)
		)
		# start from edge only
		if _rng.randf() < 0.5:
			pos.x = 0 if _rng.randf() < 0.5 else map_size.x
		else:
			pos.y = 0 if _rng.randf() < 0.5 else map_size.y
		
		var path = _grow_road_agent(pos, directions, field_scale, max_len_major, 16.0)
		if path.size() > 2:
			road_points_major.append(path)
	
	# --- Minor road agents ---
	for i in range(minor_count):
		var pos = Vector2(
			_rng.randf_range(0, map_size.x),
			_rng.randf_range(0, map_size.y)
		)
		var path = _grow_road_agent(pos, directions, field_scale, max_len_minor, 8.0)
		if path.size() > 2:
			road_points_minor.append(path)
	
	# assign results
	major_roads = road_points_major
	minor_roads = road_points_minor

func _grow_road_agent(start_pos: Vector2, field: Array, field_scale: Vector2, max_length: float, step_len: float) -> PackedVector2Array:
	var path := PackedVector2Array()
	var pos := start_pos
	var traveled := 0.0
	var turn_bias := _rng.randf_range(-0.3, 0.3)
	
	while traveled < max_length:
		if not _inside_margin(pos):
			break
		
		var dir = _sample_field_direction(field, field_scale, pos)
		dir = dir.rotated(turn_bias * 0.05)
		
		# Stop near existing roads
		if _too_close_to_existing(pos):
			break
		
		path.append(pos)
		pos += dir * step_len
		traveled += step_len
		
		# small branching chance
		if _rng.randf() < 0.02 and path.size() > 20:
			var branch_dir = dir.rotated(_rng.randf_range(-PI/3, PI/3))
			var branch_path = _grow_road_agent(pos, field, field_scale, max_length * 0.5, step_len)
			if branch_path.size() > 2:
				minor_roads.append(branch_path)
	
	return path
	
func _sample_field_direction(field: Array, field_scale: Vector2, pos: Vector2) -> Vector2:
	var xi = clamp(int(pos.x / field_scale.x), 0, field.size() - 2)
	var yi = clamp(int(pos.y / field_scale.y), 0, field.size() - 2)
	var fracx = fposmod(pos.x / field_scale.x, 1.0)
	var fracy = fposmod(pos.y / field_scale.y, 1.0)
	var d00 = field[yi][xi]
	var d10 = field[yi][xi + 1]
	var d01 = field[yi + 1][xi]
	var d11 = field[yi + 1][xi + 1]
	var dx0 = d00.lerp(d10, fracx)
	var dx1 = d01.lerp(d11, fracx)
	return dx0.lerp(dx1, fracy).normalized()
	
func _too_close_to_existing(pos: Vector2) -> bool:
	for arr in major_roads:
		for p in arr:
			if p.distance_to(pos) < 20.0:
				return true
	for arr in minor_roads:
		for p in arr:
			if p.distance_to(pos) < 10.0:
				return true
	return false

# -------- Zoning --------
func _make_zones() -> void:
	zone_centers.clear()
	zone_sigmas.clear()
	var w: float = float(map_size.x)
	var h: float = float(map_size.y)

	# Main city core stays fairly central
	var cx: float = w * 0.5 + _rng.randf_range(-w * 0.12, w * 0.12)
	var cy: float = h * 0.5 + _rng.randf_range(-h * 0.12, h * 0.12)
	zone_centers.append(Vector2(cx, cy))
	zone_sigmas.append(min(w, h) * _rng.randf_range(0.28, 0.36))  # broader, nicer core

	# Optional secondary node ~50% of the time, smaller spread
	if _rng.randf() < 0.55:
		var ang: float = _rng.randf() * TAU
		var r: float = min(w, h) * _rng.randf_range(0.15, 0.28)
		var c2: Vector2 = Vector2(cx, cy) + Vector2.RIGHT.rotated(ang) * r
		zone_centers.append(c2)
		zone_sigmas.append(min(w, h) * _rng.randf_range(0.18, 0.26))


func _city_score(p: Vector2) -> float:
	var s: float = 0.0
	for i in range(zone_centers.size()):
		var c: Vector2 = zone_centers[i]
		var sig: float = zone_sigmas[i]
		var d: float = p.distance_to(c)
		var g: float = exp(-(d * d) / (2.0 * sig * sig))  # 0..1
		s += g
	# add gentle noise so borders aren't perfect
	var n: float = abs(_noise.get_noise_2d(p.x * 0.004, p.y * 0.004)) * 0.25
	s = s * (0.85 + n)
	if s > 1.0:
		return 1.0
	if s < 0.0:
		return 0.0
	return s

func _zone_at(p: Vector2) -> int:
	var s: float = _city_score(p)
	if s >= 0.60:
		return Z_COMMERCIAL
	elif s >= 0.40:
		return Z_MIXED
	else:
		return Z_RESIDENTIAL

func _inside_margin(p: Vector2) -> bool:
	if p.x < edge_margin: return false
	if p.y < edge_margin: return false
	if p.x > float(map_size.x - edge_margin): return false
	if p.y > float(map_size.y - edge_margin): return false
	return true

# -------- Pins --------
func _make_pins() -> void:
	_add_pins_on_paths(minor_roads, count_home, PIN_HOME)
	_add_pins_on_paths(minor_roads, count_cafe, PIN_CAFE)
	_add_pins_on_paths(major_roads, count_office, PIN_OFFICE)
	_add_pins_on_paths(major_roads, count_market, PIN_MARKET)
	_add_pins_on_paths(major_roads, count_amusement, PIN_AMUSE)
	_add_pins_in_parks(count_park_pin, PIN_PARK)
	_force_presence_guarantee()
	
func _add_pins_on_paths(paths: Array[PackedVector2Array], count: int, kind: int) -> void:
	if paths.is_empty():
		return

	# Per-path cap only for the "city" kinds
	var per_cap: int = 1000000
	if kind == PIN_OFFICE:
		per_cap = per_path_cap_office
	elif kind == PIN_MARKET:
		per_cap = per_path_cap_market
	elif kind == PIN_AMUSE:
		per_cap = per_path_cap_amuse

	var placed_per_path := {}  # path_index -> count

	var attempts: int = max(200, count * 80)
	var placed: int = 0
	var tries: int = 0
	var min_d: float = _min_distance_for_kind(kind)

	while placed < count and tries < attempts:
		tries += 1

		var path_index: int = _rng.randi_range(0, paths.size() - 1)
		var used: int = 0
		if placed_per_path.has(path_index):
			used = int(placed_per_path[path_index])
		if used >= per_cap:
			continue

		var path: PackedVector2Array = paths[path_index]
		if path.size() < 2:
			continue

		var seg_index: int = _rng.randi_range(0, path.size() - 2)
		var a: Vector2 = path[seg_index]
		var b: Vector2 = path[seg_index + 1]
		var t: float = _rng.randf()
		var p: Vector2 = a.lerp(b, t)
		p += Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-6.0, 6.0))

		if not _inside_margin(p):
			continue

		var zone: int = _zone_at(p)
		if not _pin_zone_ok(kind, zone, p):
			continue

		if not _far_from_same_kind(p, kind, min_d):
			continue

		pin_pos.append(p)
		pin_kind.append(kind)
		placed += 1
		if placed_per_path.has(path_index):
			placed_per_path[path_index] = int(placed_per_path[path_index]) + 1
		else:
			placed_per_path[path_index] = 1

func _min_distance_for_kind(kind: int) -> float:
	if kind == PIN_OFFICE:
		return min_dist_office
	elif kind == PIN_MARKET:
		return min_dist_market
	elif kind == PIN_AMUSE:
		return min_dist_amuse
	return 0.0

func _far_from_same_kind(p: Vector2, kind: int, min_d: float) -> bool:
	if min_d <= 0.0:
		return true
	for i in range(pin_pos.size()):
		if pin_kind[i] == kind:
			if pin_pos[i].distance_to(p) < min_d:
				return false
	return true


func _pin_zone_ok(kind: int, zone: int, p: Vector2) -> bool:
	if kind == PIN_HOME:
		if zone == Z_RESIDENTIAL:
			return true
		return false
	elif kind == PIN_CAFE:
		if zone == Z_MIXED or zone == Z_COMMERCIAL:
			return true
		return false
	elif kind == PIN_OFFICE:
		if zone == Z_COMMERCIAL:
			return true
		return false
	elif kind == PIN_MARKET:
		# prefer mid-to-high density
		var s: float = _city_score(p)
		if s >= 0.50:
			return true
		return false
	elif kind == PIN_AMUSE:
		# near parks helps
		if _nearest_park_distance(p) <= 220.0 and (zone == Z_MIXED or zone == Z_COMMERCIAL):
			return true
		# fallback: mixed zone
		if zone == Z_MIXED:
			return true
		return false
	else:
		return true

func _add_pins_in_parks(count: int, kind: int) -> void:
	if parks.is_empty(): return
	var attempts: int = max(32, count * 6)
	var placed: int = 0
	var tries: int = 0
	while placed < count and tries < attempts:
		tries += 1
		var pi: int = _rng.randi_range(0, parks.size() - 1)
		var poly: PackedVector2Array = parks[pi]
		if poly.size() < 3: continue
		var bb: Rect2 = _poly_bounds(poly)
		var pt: Vector2 = Vector2(
			_rng.randf_range(bb.position.x + 6.0, bb.position.x + bb.size.x - 6.0),
			_rng.randf_range(bb.position.y + 6.0, bb.position.y + bb.size.y - 6.0)
		)
		if not _inside_margin(pt): continue
		if Geometry2D.is_point_in_polygon(pt, poly):
			pin_pos.append(pt); pin_kind.append(kind); placed += 1

func _poly_bounds(poly: PackedVector2Array) -> Rect2:
	var min_x: float = 1e9; var min_y: float = 1e9
	var max_x: float = -1e9; var max_y: float = -1e9
	for p in poly:
		if p.x < min_x: min_x = p.x
		if p.y < min_y: min_y = p.y
		if p.x > max_x: max_x = p.x
		if p.y > max_y: max_y = p.y
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _nearest_park_distance(p: Vector2) -> float:
	var best: float = 1e9
	for c in park_centroids:
		var d: float = p.distance_to(c)
		if d < best: best = d
	return best

# -------- Drawing --------
func _draw() -> void:
	# Land
	draw_rect(Rect2(Vector2.ZERO, map_size), color_land, true)

	# Optional zone overlay for debugging
	if debug_show_zones:
		var step: int = 64
		var y: int = 0
		while y < map_size.y:
			var x: int = 0
			while x < map_size.x:
				var p: Vector2 = Vector2(x + step * 0.5, y + step * 0.5)
				var z: int = _zone_at(p)
				var col: Color = Color(0, 0, 0, 0)
				if z == Z_RESIDENTIAL:
					col = Color(0, 0.6, 0.6, 0.08)
				elif z == Z_MIXED:
					col = Color(0.9, 0.6, 0.0, 0.08)
				else:
					col = Color(0.2, 0.2, 1.0, 0.08)
				draw_rect(Rect2(Vector2(x, y), Vector2(step, step)), col, true)
				x += step
			y += step

	# Water
	for wp in water_polys:
		draw_colored_polygon(wp, color_water)
	if river.size() > 1:
		draw_polyline(river, color_water, width_river, true)

	# Parks
	for poly in parks:
		draw_colored_polygon(poly, color_park)

	# Roads
	for path in minor_roads:
		draw_polyline(path, color_road_minor, width_road_minor, true)
	for path in major_roads:
		draw_polyline(path, color_road_major, width_road_major, true)
	for path in diagonals:
		draw_polyline(path, color_road_major, width_road_major, true)

	# Pins (on top)
	_draw_pins()

func _draw_pins() -> void:
	var r_outer: float = pin_radius + pin_outline
	for i in range(pin_pos.size()):
		var p: Vector2 = pin_pos[i]
		var c: Color = _pin_color(pin_kind[i])
		draw_circle(p, r_outer, Color(1,1,1))     # outline
		draw_circle(p, pin_radius, c)             # fill
		draw_circle(p - Vector2(pin_radius * 0.35, pin_radius * 0.35),
					pin_radius * 0.25, Color(1,1,1))  # shine

# --- Presence guarantee -------------------------------------------------------

func _force_presence_guarantee() -> void:
	var core: Vector2 = _city_core()
	if not _has_kind(PIN_OFFICE):
		_force_place_in_zone(PIN_OFFICE, core)
	if not _has_kind(PIN_MARKET):
		_force_place_in_zone(PIN_MARKET, core)
	if not _has_kind(PIN_AMUSE):
		var anchor: Vector2 = core
		if park_centroids.size() > 0:
			anchor = _nearest_park_to(core)
		_force_place_in_zone(PIN_AMUSE, anchor)

func _has_kind(kind: int) -> bool:
	for k in pin_kind:
		if k == kind:
			return true
	return false

func _city_core() -> Vector2:
	if zone_centers.size() > 0:
		return zone_centers[0]
	return Vector2(float(map_size.x) * 0.5, float(map_size.y) * 0.5)

func _nearest_park_to(p: Vector2) -> Vector2:
	var best: float = 1e12
	var best_c: Vector2 = p
	for c in park_centroids:
		var d: float = p.distance_to(c)
		if d < best:
			best = d
			best_c = c
	return best_c

func _force_place_in_zone(kind: int, anchor: Vector2) -> void:
	# Radial sampling around anchor with progressive radius; must satisfy zone rules.
	var max_stage: int = 3
	var min_d: float = _min_distance_for_kind(kind)

	var stage: int = 0
	while stage <= max_stage:
		var tries: int = 0
		var radius: float = min(float(map_size.x), float(map_size.y)) * (0.12 + 0.12 * float(stage))
		while tries < 1200:
			tries += 1
			var r: float = radius * sqrt(_rng.randf())
			var ang: float = _rng.randf() * TAU
			var p: Vector2 = anchor + Vector2.RIGHT.rotated(ang) * r
			if not _inside_margin(p):
				continue

			var zone: int = _zone_at(p)
			var ok: bool = false
			if kind == PIN_OFFICE:
				# Offices: commercial; if stage>1 allow mixed
				if stage <= 1:
					if zone == Z_COMMERCIAL:
						ok = true
				else:
					if zone == Z_COMMERCIAL or zone == Z_MIXED:
						ok = true
			elif kind == PIN_MARKET:
				# Prefer mid/high density; relax by stage
				var s: float = _city_score(p)
				if stage == 0 and s >= 0.55:
					ok = true
				elif stage == 1 and s >= 0.45:
					ok = true
				elif stage >= 2 and zone != Z_RESIDENTIAL:
					ok = true
			elif kind == PIN_AMUSE:
				# Near parks and central/mixed
				var near: bool = _nearest_park_distance(p) <= 220.0
				if stage <= 1:
					if near and (zone == Z_MIXED or zone == Z_COMMERCIAL):
						ok = true
				else:
					if zone == Z_MIXED or zone == Z_COMMERCIAL:
						ok = true

			if not ok:
				continue

			# Snap to the nearest road (major preferred)
			var snapped: Vector2 = p
			if not major_roads.is_empty():
				snapped = _snap_to_nearest_path(p, major_roads)
			elif not minor_roads.is_empty():
				snapped = _snap_to_nearest_path(p, minor_roads)

			if not _far_from_same_kind(snapped, kind, min_d):
				continue

			pin_pos.append(snapped)
			pin_kind.append(kind)
			return
		stage += 1

	# Last resort (should rarely run): snap core itself
	var fallback: Vector2 = anchor
	if not major_roads.is_empty():
		fallback = _snap_to_nearest_path(anchor, major_roads)
	elif not minor_roads.is_empty():
		fallback = _snap_to_nearest_path(anchor, minor_roads)
	pin_pos.append(_clamp_inside_margin(fallback))
	pin_kind.append(kind)


# Snap an anchor to the nearest point on given paths; if empty, returns anchor.
func _snap_to_nearest_path(anchor: Vector2, paths: Array[PackedVector2Array]) -> Vector2:
	var best_d2: float = 1e18
	var best_q: Vector2 = anchor
	for path in paths:
		for i in range(path.size() - 1):
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			var q: Vector2 = _closest_point_on_segment(a, b, anchor)
			var d2: float = (q - anchor).length_squared()
			if d2 < best_d2:
				best_d2 = d2
				best_q = q
	return best_q

func _closest_point_on_segment(a: Vector2, b: Vector2, p: Vector2) -> Vector2:
	var ab: Vector2 = b - a
	var t: float = 0.0
	var denom: float = ab.length_squared()
	if denom > 0.0:
		t = (p - a).dot(ab) / denom
		if t < 0.0: t = 0.0
		if t > 1.0: t = 1.0
	return a.lerp(b, t)

func _clamp_inside_margin(p: Vector2) -> Vector2:
	var x: float = clampf(p.x, float(edge_margin), float(map_size.x - edge_margin))
	var y: float = clampf(p.y, float(edge_margin), float(map_size.y - edge_margin))
	return Vector2(x, y)

# Try to place on major roads; if none/invalid, fall back to minors; if still bad, place at anchor.
func _force_place_on_roads(kind: int, anchor: Vector2, prefer_major: bool) -> void:
	var p: Vector2 = anchor
	if prefer_major and not major_roads.is_empty():
		p = _snap_to_nearest_path(anchor, major_roads)
	elif not minor_roads.is_empty():
		p = _snap_to_nearest_path(anchor, minor_roads)

	p = _clamp_inside_margin(p)
	pin_pos.append(p)
	pin_kind.append(kind)


func _random_point_on_paths(paths: Array[PackedVector2Array]) -> Vector2:
	# Returns a random point near a random segment; caller must validate
	var path_index: int = _rng.randi_range(0, paths.size() - 1)
	var path: PackedVector2Array = paths[path_index]
	if path.size() < 2:
		return Vector2(-1e9, -1e9)  # sentinel for "invalid"
	var seg_index: int = _rng.randi_range(0, path.size() - 2)
	var a: Vector2 = path[seg_index]
	var b: Vector2 = path[seg_index + 1]
	var t: float = _rng.randf()
	var p: Vector2 = a.lerp(b, t)
	p += Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-6.0, 6.0))
	return p

func _ensure_kind_present_on_paths(kind: int, paths: Array[PackedVector2Array]) -> void:
	if _has_kind(kind):
		return
	if paths.is_empty():
		return

	var placed: bool = false
	var tries: int = 0
	var stage: int = 0
	var max_tries: int = 4000

	while not placed and tries < max_tries:
		tries += 1

		var p: Vector2 = _random_point_on_paths(paths)
		if p.x < -1e8:  # invalid sentinel
			continue
		if not _inside_margin(p):
			continue

		var ok: bool = false
		if kind == PIN_OFFICE:
			# Stage 0: commercial only; Stage 1: allow mixed; Stage 2+: anywhere
			var zone_office: int = _zone_at(p)
			if stage == 0:
				if zone_office == Z_COMMERCIAL:
					ok = true
			elif stage == 1:
				if zone_office == Z_COMMERCIAL or zone_office == Z_MIXED:
					ok = true
			else:
				ok = true

		elif kind == PIN_MARKET:
			# Prefer medium/high density; relax progressively
			var s: float = _city_score(p)
			if stage == 0:
				if s >= 0.50:
					ok = true
			elif stage == 1:
				if s >= 0.40:
					ok = true
			else:
				ok = true

		elif kind == PIN_AMUSE:
			# Prefer near parks and central/mixed; relax progressively
			var near: bool = _nearest_park_distance(p) <= 220.0
			var z: int = _zone_at(p)
			if stage == 0:
				if near and (z == Z_MIXED or z == Z_COMMERCIAL):
					ok = true
			elif stage == 1:
				if z == Z_MIXED or z == Z_COMMERCIAL:
					ok = true
			else:
				ok = true

		# Place if OK
		if ok:
			pin_pos.append(p)
			pin_kind.append(kind)
			placed = true

		# Every 1000 failed tries, relax constraints one level
		if not placed and tries % 1000 == 0:
			stage += 1


# -------- Colors --------
func _pin_color(kind: int) -> Color:
	if kind == PIN_CAFE:
		return Color("#e86e34")   # orange
	elif kind == PIN_OFFICE:
		return Color("#5666ff")   # blue
	elif kind == PIN_MARKET:
		return Color("#b84dff")   # violet
	elif kind == PIN_PARK:
		return Color("#3aa655")   # green
	elif kind == PIN_AMUSE:
		return Color("#ff4d84")   # pink-red
	else:
		return Color("#2bb3b3")   # home = teal

# -------- Utils --------
func _cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3

# Export PNG
func save_as_png(path: String = "") -> void:
	var final_path: String = path
	if final_path == "":
		var stamp: String = Time.get_datetime_string_from_system()
		stamp = stamp.replace(":", "-")
		final_path = "user://city_map_" + stamp + ".png"
	var img: Image = get_viewport().get_texture().get_image()
	var result: int = img.save_png(final_path)
	if result == OK:
		print("Saved: ", final_path)
	else:
		push_error("Failed to save PNG at: " + final_path)
