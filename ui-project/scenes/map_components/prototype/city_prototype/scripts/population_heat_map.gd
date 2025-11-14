extends Node
class_name CityEnvironment

signal maps_generated(water: Image, forest: Image, height: Image, population: Image, city_potential: Image)

@export var map_size := Vector2i(256, 256)
@export var seed: int = 1337

@onready var city_zones: CityZones = $CityZones

func _ready() -> void:
	call_deferred("generate_maps")

func generate_maps() -> void:
	print("CityEnvironment: generating maps...")
	randomize()
	
	var water := _generate_water_map()
	var forest := _generate_forest_map()
	var height := _generate_height_map()
	var population := _generate_population_map()
	var city_potential := city_zones.generate_zones(height, water, population)

	print("CityEnvironment: maps generated.")
	maps_generated.emit(water, forest, height, population, city_potential)

# Simple noise prototypes – replace later with Perlin or OpenSimplex2D
func _generate_water_map() -> Image:
	var img := Image.create(map_size.x, map_size.y, false, Image.FORMAT_RF)
	img.fill(Color.BLACK)
	var river_x := randi_range(map_size.x / 3, map_size.x * 2 / 3)
	for y in range(map_size.y):
		img.set_pixel(river_x, y, Color.WHITE)
	for x in range(map_size.x):
		img.set_pixel(x, map_size.y - 1, Color.WHITE)
	return img

func _generate_forest_map() -> Image:
	var img := Image.create(map_size.x, map_size.y, false, Image.FORMAT_RF)
	var noise := FastNoiseLite.new()
	noise.seed = seed + 100
	noise.frequency = 0.05
	for y in range(map_size.y):
		for x in range(map_size.x):
			var v = (noise.get_noise_2d(x, y) + 1.0) * 0.5
			img.set_pixel(x, y, Color(v, v, v))
	return img

func _generate_height_map() -> Image:
	var img := Image.create(map_size.x, map_size.y, false, Image.FORMAT_RF)
	var noise := FastNoiseLite.new()
	noise.seed = seed + 200
	noise.frequency = 0.03
	for y in range(map_size.y):
		for x in range(map_size.x):
			var v = (noise.get_noise_2d(x, y) + 1.0) * 0.5
			img.set_pixel(x, y, Color(v, v, v))
	return img

func _generate_population_map() -> Image:
	var img := Image.create(map_size.x, map_size.y, false, Image.FORMAT_RF)
	for y in range(map_size.y):
		for x in range(map_size.x):
			var value = clamp((float(y) / map_size.y) * 1.2 - 0.1, 0.0, 1.0)
			img.set_pixel(x, y, Color(value, value, value))
	return img


#extends Node
#class_name CityEnvironment
#
#signal maps_generated(water: Image, forest: Image, height: Image, population: Image, city_potential: Image)
#
#@export var map_size: int = 1024
#@export var world_size: float = 2048.0
#@export var base_noise_scale: float = 0.005
#@export var river_points: int = 10
#@export var river_width: int = 8
#@export var coast_height_ratio: float = 0.10  # fraction of map used as coast band
#@export var max_water_proximity: int = 120    # pixels for proximity influence
#
#var water_image: Image
#var forest_image: Image
#var height_image: Image
#var population_image: Image
#var city_potential_image: Image
#
#func _ready() -> void:
	#call_deferred("generate_maps")
#
#
#func generate_maps() -> void:
	#height_image = _generate_height_map()
	#water_image = _generate_water_map(height_image)
	#forest_image = _generate_forest_map(height_image)
	#population_image = _generate_population_map()
	#city_potential_image = _generate_city_potential_map()
	#print("CityEnvironment: maps generated")
	#emit_signal("maps_generated", water_image, forest_image, height_image, population_image, city_potential_image)
#
#
#func _generate_height_map() -> Image:
	#var noise := FastNoiseLite.new()
	#noise.seed = randi()
	#noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	#noise.frequency = base_noise_scale * 1.5
	#noise.fractal_octaves = 4
#
	#var img := Image.create(map_size, map_size, false, Image.FORMAT_RF)
	#for y in range(map_size):
		#for x in range(map_size):
			#var nx = float(x) / map_size
			#var ny = float(y) / map_size
			#var v = noise.get_noise_2d(nx, ny)
			#v = clamp((v + 1.0) * 0.5, 0.0, 1.0)
			#var coast_factor = smoothstep(0.0, coast_height_ratio, ny)
			#v = lerp(v, coast_factor * 0.25, 0.25)
			#img.set_pixel(x, y, Color(v, v, v))
	#return img
#
#
#func _generate_water_map(height_img: Image) -> Image:
	#var img := Image.create(map_size, map_size, false, Image.FORMAT_RF)
	#img.fill(Color(0,0,0))
	#var coast_limit = int(map_size * coast_height_ratio)
#
	## ocean strip
	#for y in range(map_size - coast_limit, map_size):
		#for x in range(map_size):
			#img.set_pixel(x, y, Color(1.0,1.0,1.0))
#
	## river control points
	#var noise := FastNoiseLite.new()
	#noise.seed = randi()
	#noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	#noise.frequency = 0.02
#
	#var start_x := randf_range(map_size * 0.25, map_size * 0.75)
	#var y_step := float(map_size - coast_limit) / float(max(1, river_points))
	#var pts := []
	#for i in range(river_points + 1):
		#var y = clamp(i * y_step, 0.0, float(map_size - coast_limit - 1))
		#var offset = noise.get_noise_2d(0.0, y * 0.003) * float(map_size) * 0.08
		#var x = clamp(start_x + offset, 0.0, float(map_size - 1))
		#pts.append(Vector2(x, y))
#
	#if pts.size() > 0:
		#pts[pts.size()-1].y = float(map_size - coast_limit / 4)
#
	#for i in range(pts.size() - 1):
		#_draw_line_filled(img, pts[i], pts[i+1], river_width)
#
	#return img
#
#
#func _draw_line_filled(img: Image, a: Vector2, b: Vector2, width_px: int) -> void:
	#var dir = (b - a)
	#var length = int(ceil(dir.length()))
	#if length <= 0:
		#return
	#dir = dir / max(1, length)
	#for i in range(length + 1):
		#var p = a + dir * float(i)
		#var cx = int(round(p.x))
		#var cy = int(round(p.y))
		#for dy in range(-width_px, width_px + 1):
			#for dx in range(-width_px, width_px + 1):
				#var sx = cx + dx
				#var sy = cy + dy
				#if sx >= 0 and sy >= 0 and sx < map_size and sy < map_size:
					#img.set_pixel(sx, sy, Color(1.0,1.0,1.0))
#
#
#func _generate_forest_map(height_img: Image) -> Image:
	#var noise := FastNoiseLite.new()
	#noise.seed = randi()
	#noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	#noise.frequency = base_noise_scale * 2.5
	#noise.fractal_octaves = 3
#
	#var img := Image.create(map_size, map_size, false, Image.FORMAT_RF)
	#for y in range(map_size):
		#for x in range(map_size):
			#var nx = float(x) / map_size
			#var ny = float(y) / map_size
			#var h = height_img.get_pixel(x, y).r
			#var v = noise.get_noise_2d(nx, ny)
			#v = clamp((v + 1.0) * 0.5, 0.0, 1.0)
			#var forest = clamp(v * smoothstep(0.2, 0.8, h), 0.0, 1.0)
			#img.set_pixel(x, y, Color(forest, forest, forest))
	#return img
#
#
#func _generate_population_map() -> Image:
	#var noise := FastNoiseLite.new()
	#noise.seed = randi()
	#noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	#noise.frequency = base_noise_scale * 0.4
	#noise.fractal_octaves = 2
#
	#var img := Image.create(map_size, map_size, false, Image.FORMAT_RF)
	#for y in range(map_size):
		#for x in range(map_size):
			#var nx = float(x) / map_size
			#var ny = float(y) / map_size
			#var v = noise.get_noise_2d(nx, ny)
			#v = clamp((v + 1.0) * 0.5, 0.0, 1.0)
			#img.set_pixel(x, y, Color(v, v, v))
	#return img
#
#
#func _generate_city_potential_map() -> Image:
	#var dist_map = _water_distance_map(water_image)
	#var maxd = float(max(1, max_water_proximity))
#
	#var pop_noise := FastNoiseLite.new()
	#pop_noise.seed = randi()
	#pop_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	#pop_noise.frequency = base_noise_scale * 0.35
#
	#var img := Image.create(map_size, map_size, false, Image.FORMAT_RF)
	#for y in range(map_size):
		#for x in range(map_size):
			#var h = height_image.get_pixel(x, y).r
			#var f = forest_image.get_pixel(x, y).r
			#var p = population_image.get_pixel(x, y).r
			#var w = water_image.get_pixel(x, y).r
#
			#var height_pref = 1.0 - abs(h - 0.45) * 2.0
			#height_pref = clamp(height_pref, 0.0, 1.0)
#
			#var d = float(dist_map[y * map_size + x])
			#var prox = clamp(1.0 - (d / maxd), 0.0, 1.0)
			#if w > 0.5:
				#prox = 0.0
#
			#var nx = float(x) / map_size
			#var ny = float(y) / map_size
			#var pop_variation = clamp((pop_noise.get_noise_2d(nx, ny) + 1.0) * 0.5, 0.0, 1.0)
#
			#var pot = (0.6 * prox + 0.4 * height_pref) * (1.0 - f * 0.5) * (0.5 + p * 0.5 * pop_variation)
			#pot = clamp(pow(pot, 1.4), 0.0, 1.0)
#
			#img.set_pixel(x, y, Color(pot, pot, pot))
	#return img
#
#
#func _water_distance_map(water_img: Image) -> PackedInt32Array:
	#var w = map_size
	#var h = map_size
	#var size = w * h
	#var dist := PackedInt32Array()
	#dist.resize(size)
	#for i in range(size):
		#dist[i] = 0x7fffffff
#
	#var q := []
	#for yy in range(h):
		#for xx in range(w):
			#if water_img.get_pixel(xx, yy).r > 0.5:
				#var idx = yy * w + xx
				#dist[idx] = 0
				#q.append(Vector2i(xx, yy))
#
	#var qi := 0
	#while qi < q.size():
		#var p = q[qi]
		#qi += 1
		#var px = p.x
		#var py = p.y
		#var base_idx = py * w + px
		#var d0 = dist[base_idx]
		#for off in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			#var nx = px + off.x
			#var ny = py + off.y
			#if nx >= 0 and ny >= 0 and nx < w and ny < h:
				#var nidx = ny * w + nx
				#if dist[nidx] > d0 + 1:
					#dist[nidx] = d0 + 1
					#q.append(Vector2i(nx, ny))
	#return dist
