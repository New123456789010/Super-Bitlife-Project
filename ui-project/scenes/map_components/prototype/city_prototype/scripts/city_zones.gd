extends Node
class_name CityZones

@export var zone_size: int = 32
@export var zone_spacing: int = 8
@export var blur_radius: int = 2

func generate_zones(height: Image, water: Image, population: Image) -> Image:
	if zone_size <= 0:
		zone_size = 32
	if zone_spacing < 0:
		zone_spacing = 0

	var width := height.get_width()
	var height_px := height.get_height()
	var img := Image.create(width, height_px, false, Image.FORMAT_RGBA8)

	# Detect city centers (simple sampling for now)
	var centers := _detect_city_centers(width, height_px, zone_size)
	for c in centers:
		var color := _zone_color(centers.find(c))
		for y in range(zone_size):
			for x in range(zone_size):
				var px := c.x + x
				var py := c.y + y
				if px < width and py < height_px:
					img.set_pixel(px, py, color)

	img = _blur_image(img, blur_radius)
	return img


func _detect_city_centers(width: int, height_px: int, step: int) -> Array[Vector2i]:
	var centers: Array[Vector2i] = []
	var x_step = max(step + zone_spacing, 1)
	var y_step = max(step + zone_spacing, 1)

	for y in range(0, height_px, y_step):
		for x in range(0, width, x_step):
			centers.append(Vector2i(x, y))
	return centers


func _zone_color(index: int) -> Color:
	var colors = [
		Color.RED,
		Color.GREEN,
		Color.BLUE,
		Color.YELLOW,
		Color.MAGENTA,
		Color.CYAN
	]
	return colors[index % colors.size()]


func _blur_image(img: Image, radius: int) -> Image:
	if radius <= 0:
		return img

	var w := img.get_width()
	var h := img.get_height()
	var result := img.duplicate()
	
	for y in range(h):
		for x in range(w):
			var accum := Color(0, 0, 0, 0)
			var count := 0
			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					var sx = clamp(x + dx, 0, w - 1)
					var sy = clamp(y + dy, 0, h - 1)
					accum += img.get_pixel(sx, sy)
					count += 1
			result.set_pixel(x, y, accum / float(count))
	return result

#extends Node
#class_name CityZones
#
#signal zones_generated(zone_image: Image, centers: Array)
#
#@export var threshold: float = 0.40
#@export var region_grow_limit: int = 8000
#@export var max_centers: int = 6
#@export var blur_passes: int = 2
#
#@export var debug_colors: Array = [
	#Color(1, 0, 0),
	#Color(0, 1, 0),
	#Color(0, 0, 1),
	#Color(1, 1, 0),
	#Color(1, 0, 1),
	#Color(0, 1, 1)
#]
#
#
#func generate_zones(city_potential: Image) -> void:
	#var map_size = city_potential.get_width()
	#var smooth = _blur_image(city_potential, blur_passes)
	#var centers := _detect_city_centers(smooth, map_size)
	#print("CityZones: centers found:", centers.size(), centers)
#
	#var zone_image := Image.create(map_size, map_size, false, Image.FORMAT_RGBA8)
	#zone_image.fill(Color(0,0,0,0))
#
	#for i in range(min(max_centers, centers.size())):
		#var c = centers[i]
		#var color = debug_colors[i % debug_colors.size()]
		#_flood_fill_zone(c, color, smooth, zone_image)
#
	#print("CityZones: zones generated (centers:", centers.size(), ")")
	#emit_signal("zones_generated", zone_image, centers)
#
#
#func _detect_city_centers(city_potential: Image, map_size: int) -> Array:
	#var centers := []
	#for y in range(1, map_size - 1):
		#for x in range(1, map_size - 1):
			#var v = city_potential.get_pixel(x, y).r
			#if v < threshold:
				#continue
			#var is_peak = true
			#for oy in [-1, 0, 1]:
				#for ox in [-1, 0, 1]:
					#if city_potential.get_pixel(x + ox, y + oy).r > v:
						#is_peak = false
						#break
				#if not is_peak:
					#break
			#if is_peak:
				#centers.append(Vector2i(x, y))
				#if centers.size() >= max_centers:
					#return centers
	#return centers
#
#
#func _flood_fill_zone(start: Vector2i, color: Color, potential: Image, zone_image: Image) -> void:
	#var map_size = potential.get_width()
	#var stack := [start]
	#var visited := {}
	#var grown := 0
	#while stack.size() > 0 and grown < region_grow_limit:
		#var pos = stack.pop_back()
		#var key = (pos.x << 16) | (pos.y & 0xffff)
		#if visited.has(key):
			#continue
		#visited[key] = true
		#if pos.x < 0 or pos.y < 0 or pos.x >= map_size or pos.y >= map_size:
			#continue
		#var v = potential.get_pixel(pos.x, pos.y).r
		#if v < threshold * 0.5:
			#continue
		#zone_image.set_pixel(pos.x, pos.y, Color(color.r, color.g, color.b, 1.0))
		#grown += 1
		#for off in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			#stack.append(pos + off)
#
#
#func _blur_image(src: Image, passes: int = 1) -> Image:
	#var w = src.get_width()
	#var h = src.get_height()
	#var dst = src.duplicate()
	#for p in range(passes):
		#for y in range(h):
			#for x in range(w):
				#var sum = 0.0
				#var cnt = 0
				#for oy in [-1, 0, 1]:
					#for ox in [-1, 0, 1]:
						#var nx = clamp(x + ox, 0, w - 1)
						#var ny = clamp(y + oy, 0, h - 1)
						#sum += src.get_pixel(nx, ny).r
						#cnt += 1
				#dst.set_pixel(x, y, Color(sum / float(cnt), 0.0, 0.0))
		#src = dst.duplicate()
	#return dst
