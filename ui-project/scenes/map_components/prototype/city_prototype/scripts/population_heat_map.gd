extends Node2D
class_name EnvironmentMaps

@export var map_size: int = 512
@export var world_size: float = 1024.0
@export var noise_scale: float = 0.02

# which layer to draw for debug
@export_enum("Population", "Water", "Forest", "Height", "CityPotential") var debug_layer: String = "Population"

var water_image: Image
var forest_image: Image
var height_image: Image
var population_image: Image

var pixels_per_unit: float

func _ready() -> void:
	pixels_per_unit = float(map_size) / world_size
	_generate_maps()
	queue_redraw()

# ------------------------------
# 1. MAP GENERATION
# ------------------------------
func _generate_maps() -> void:
	water_image = _generate_noise_map(1.5)
	forest_image = _generate_noise_map(3.5)
	height_image = _generate_noise_map(1.0)
	population_image = _generate_noise_map(4.0)


func _generate_noise_map(offset: float) -> Image:
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 1.0 * offset    # must be > 0
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.5
	noise.fractal_lacunarity = 2.0

	var image := Image.create(map_size, map_size, false, Image.FORMAT_RF)
	for y in range(map_size):
		for x in range(map_size):
			var nx = float(x) / map_size     # normalize 0..1
			var ny = float(y) / map_size
			#var v = noise.get_noise_2d(nx, ny)
			var v = noise.get_noise_2d(nx * 50.0, ny * 50.0) # Sampling over larger domain
			v = (v + 1.0) * 0.5
			v = pow(v, 0.5)  
			v = clamp((v + 1.0) * 0.5 * 5.0 - 2.0, 0.0, 1.0)
			image.set_pixel(x, y, Color(v, v, v))
			
			if x == 0 and y == 0:
				print("Noise sample at 0,0 =", v)
				
			if x % 100 == 0 and y % 100 == 0:
				print("noise(", x, ",", y, ") =", v)
				
			#print("min:", image.get_used_rect().position, " sample(10,10) =", noise.get_noise_2d(0.1,0.1))

	return image
	
# ------------------------------
# 2. COORDINATE MAPPING
# ------------------------------
func world_to_image_coords(world_pos: Vector2) -> Vector2i:
	var x = int(clamp(world_pos.x * pixels_per_unit, 0, map_size - 1))
	var y = int(clamp(world_pos.y * pixels_per_unit, 0, map_size - 1))
	return Vector2i(x, y)

func image_to_world_coords(img_pos: Vector2i) -> Vector2:
	var x = float(img_pos.x) / pixels_per_unit
	var y = float(img_pos.y) / pixels_per_unit
	return Vector2(x, y)


# ------------------------------
# 3. SAMPLING FUNCTIONS
# ------------------------------
func sample_map(image: Image, world_pos: Vector2) -> float:
	var coords = world_to_image_coords(world_pos)
	return image.get_pixel(coords.x, coords.y).r

func sample_map_smooth(image: Image, world_pos: Vector2) -> float:
	var fx = clamp(world_pos.x * pixels_per_unit, 0.0, map_size - 1.0)
	var fy = clamp(world_pos.y * pixels_per_unit, 0.0, map_size - 1.0)

	var x0 = int(floor(fx))
	var y0 = int(floor(fy))
	var x1 = min(x0 + 1, map_size - 1)
	var y1 = min(y0 + 1, map_size - 1)

	var tx = fx - x0
	var ty = fy - y0

	var c00 = image.get_pixel(x0, y0).r
	var c10 = image.get_pixel(x1, y0).r
	var c01 = image.get_pixel(x0, y1).r
	var c11 = image.get_pixel(x1, y1).r

	var lerp_x0 = lerp(c00, c10, tx)
	var lerp_x1 = lerp(c01, c11, tx)
	return lerp(lerp_x0, lerp_x1, ty)


# ------------------------------
# 4. ENVIRONMENT QUERY
# ------------------------------
func sample_environment(world_pos: Vector2) -> Dictionary:
	return {
		"water": sample_map_smooth(water_image, world_pos),
		"forest": sample_map_smooth(forest_image, world_pos),
		"height": sample_map_smooth(height_image, world_pos),
		"population": sample_map_smooth(population_image, world_pos)
	}

func sample_city_potential(world_pos: Vector2) -> float:
	var env = sample_environment(world_pos)
	return (1.0 - env["water"]) * (1.0 - env["forest"]) * env["population"]


# ------------------------------
# 5. DRAWING (DEBUG)
# ------------------------------
func _draw() -> void:
	var tex: ImageTexture

	match debug_layer:
		"Population":
			tex = ImageTexture.create_from_image(population_image)
		"Water":
			tex = ImageTexture.create_from_image(water_image)
		"Forest":
			tex = ImageTexture.create_from_image(forest_image)
		"Height":
			tex = ImageTexture.create_from_image(height_image)
		"CityPotential":
			var potential_img := Image.create(map_size, map_size, false, Image.FORMAT_RF)
			for y in map_size:
				for x in map_size:
					var world_pos = image_to_world_coords(Vector2i(x, y))
					var v = sample_city_potential(world_pos)
					potential_img.set_pixel(x, y, Color(v, v, v))
			tex = ImageTexture.create_from_image(potential_img)

	draw_texture_rect(tex, Rect2(Vector2.ZERO, Vector2(world_size, world_size)), false)

	# Debug marker
	var test_pos := Vector2(300, 500)
	var env = sample_environment(test_pos)
	draw_circle(test_pos, 5, Color(env["population"], 0, 0))
