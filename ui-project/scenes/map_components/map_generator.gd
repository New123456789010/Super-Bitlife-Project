extends Node2D
class_name CityMap
# @tool  # optional if you want editor-time preview

# -------- Size & seed --------
@export var map_size: Vector2i = Vector2i(2048, 1536)
@export var randomize_on_play: bool = true
@export var fixed_seed: int = 0        # >0 to lock; 0 means auto
var seed: int = 0

# -------- Theme colors (OSM-ish) --------
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

# -------- Data --------
var major_roads: Array[PackedVector2Array] = []
var minor_roads: Array[PackedVector2Array] = []
var diagonals: Array[PackedVector2Array] = []
var river: PackedVector2Array = PackedVector2Array()
var water_polys: Array[PackedVector2Array] = []   # for coastline
var parks: Array[PackedVector2Array] = []

var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()

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
			_reroll_seed()
			generate()
			queue_redraw()

# -------- Public: regenerate --------
func generate() -> void:
	major_roads.clear()
	minor_roads.clear()
	diagonals.clear()
	parks.clear()
	water_polys.clear()
	river.resize(0)

	# Random style knobs each run
	var minor_spacing: int = _rng.randi_range(50, 85)
	var major_spacing: int = _rng.randi_range(220, 320)
	var jitter: float = _rng.randf_range(6.0, 14.0)
	var diagonal_chance: float = _rng.randf_range(0.35, 0.9)
	var park_count: int = _rng.randi_range(18, 36)

	_make_water_variant()
	_make_parks(park_count)
	_make_grids(minor_spacing, major_spacing, jitter)
	_make_diagonals(diagonal_chance)

# -------- Seed helpers --------
func _reroll_seed() -> void:
	# Seed using OS entropy; no XOR, no ternary
	_rng.randomize()                 # uses system ticks under the hood
	var s: int = _rng.randi()        # grab a fresh random 32-bit int
	_set_seed(s)


func _set_seed(s: int) -> void:
	seed = s
	_rng.seed = seed
	_noise.seed = seed
	_noise.frequency = 0.0015
	_noise.fractal_octaves = 3

# -------- Generators --------
func _make_water_variant() -> void:
	var mode: int = water_mode
	if mode == 3:
		mode = _rng.randi_range(0, 2)

	if mode == 0:
		_make_river()
	elif mode == 1:
		_make_coastline()
	else:
		# None
		pass

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
			var y: float = 0.0 + 40.0 * sin(x * 0.01) + _noise.get_noise_2d(x, 0.0) * 60.0 + _rng.randf_range(20.0, 80.0)
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
			var x2: float = 0.0 + 40.0 * sin(y2 * 0.01) + _noise.get_noise_2d(0.0, y2) * 60.0 + _rng.randf_range(20.0, 80.0)
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

func _make_grids(minor_spacing: int, major_spacing: int, jitter: float) -> void:
	var w: float = float(map_size.x)
	var h: float = float(map_size.y)

	var x: float = 0.0
	while x <= w:
		var pts := PackedVector2Array()
		var segments: int = 64
		for i in range(segments + 1):
			var t: float = float(i) / float(segments)
			var yv: float = t * h
			var j: float = _noise.get_noise_2d(x, yv) * jitter
			pts.push_back(Vector2(x + j, yv))
		if roundi(x) % major_spacing == 0:
			major_roads.push_back(pts)
		else:
			minor_roads.push_back(pts)
		x += float(minor_spacing)

	var y: float = 0.0
	while y <= h:
		var pts2 := PackedVector2Array()
		var segments2: int = 64
		for i in range(segments2 + 1):
			var t2: float = float(i) / float(segments2)
			var xx: float = t2 * w
			var j2: float = _noise.get_noise_2d(xx, y) * jitter
			pts2.push_back(Vector2(xx, y + j2))
		if roundi(y) % major_spacing == 0:
			major_roads.push_back(pts2)
		else:
			minor_roads.push_back(pts2)
		y += float(minor_spacing)

func _make_diagonals(diagonal_chance: float) -> void:
	var w: float = float(map_size.x)
	var h: float = float(map_size.y)
	var count: int = _rng.randi_range(3, 7)
	for i in range(count):
		if _rng.randf() > diagonal_chance:
			continue
		var a: Vector2 = Vector2(_rng.randf_range(-40.0, w + 40.0), -40.0)
		var b: Vector2 = Vector2(_rng.randf_range(-40.0, w + 40.0), h + 40.0)
		var pts := PackedVector2Array()
		var steps: int = 80
		for k in range(steps + 1):
			var t: float = float(k) / float(steps)
			var p: Vector2 = a.lerp(b, t)
			var n: float = _noise.get_noise_2d(p.x * 1.5, p.y * 1.5)
			p += Vector2(-n * 14.0, n * 14.0)
			pts.push_back(p)
		diagonals.push_back(pts)

# -------- Draw --------
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, map_size), color_land, true)

	for wp in water_polys:
		draw_colored_polygon(wp, color_water)
	if river.size() > 1:
		draw_polyline(river, color_water, width_river, true)

	for poly in parks:
		draw_colored_polygon(poly, color_park)

	for path in minor_roads:
		draw_polyline(path, color_road_minor, width_road_minor, true)
	for path in major_roads:
		draw_polyline(path, color_road_major, width_road_major, true)
	for path in diagonals:
		draw_polyline(path, color_road_major, width_road_major, true)

# -------- Utils --------
func _cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3

# Export PNG (optional)
func save_as_png(path: String = "user://city_map.png") -> void:
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(path)
	print("Saved:", path)
