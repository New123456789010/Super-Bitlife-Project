extends Node

class_name MapGenerator

# Palette / colors used for district types
const DISTRICT_TYPES = {
	"DOWNTOWN": Color8(220,80,80),
	"COAST": Color8(80,150,220),
	"SUBURB": Color8(120,200,140),
	"NATURE": Color8(100,170,90),
	"INDUSTRIAL": Color8(150,150,150),
	"SHOPPING": Color8(220,180,90),
}

static var _district_counter: int = 0
static var _poi_counter: int = 0

# Top-level generator. seed=0 => randomize
static func generate_map(seed:int = 0) -> Dictionary:
	_district_counter = 0
	_poi_counter = 0
	
	var rng = RandomNumberGenerator.new()
	if seed == 0:
		rng.randomize()
		seed = rng.randi()
	else:
		rng.seed = seed

	var map = {
		"seed": seed,
		"districts": [],
		"roads": []
	}

	# Downtown in the center
	var downtown_center = Vector2(0.5, 0.5)
	map["districts"].append(_make_district("Downtown", "DOWNTOWN", downtown_center, 0.28, 0.20, rng))

	# Coast on the left side (random Y)
	var coast_center = Vector2(rng.randf_range(0.06, 0.14), rng.randf())
	map["districts"].append(_make_district("Coast", "COAST", coast_center, 0.22, 0.28, rng))

	# Suburbs placed around downtown
	var suburbs = rng.randi_range(2, 4)
	for i in range(suburbs):
		var angle = _randf_range_deg(i, suburbs, rng)
		var radius = rng.randf_range(0.18, 0.33)
		var pos = downtown_center + Vector2(cos(angle), sin(angle)) * radius
		pos.x = clamp(pos.x, 0.08, 0.92)
		pos.y = clamp(pos.y, 0.08, 0.92)
		map["districts"].append(_make_district("Suburb_%d" % i, "SUBURB", pos, rng.randf_range(0.15, 0.26), rng.randf_range(0.10, 0.18), rng))

	# Nature: pick an outer-ish area
	var side = rng.randi_range(0, 3)
	var pos_nature = Vector2()
	if side == 0:
		pos_nature = Vector2(rng.randf_range(0.65, 0.95), rng.randf())
	elif side == 1:
		pos_nature = Vector2(rng.randf(), rng.randf_range(0.65, 0.95))
	elif side == 2:
		pos_nature = Vector2(rng.randf_range(0.65, 0.95), rng.randf())
	else:
		pos_nature = Vector2(rng.randf(), rng.randf_range(0.65, 0.95))
	map["districts"].append(_make_district("Nature", "NATURE", pos_nature, 0.28, 0.22, rng))

	# Shopping + Industrial
	map["districts"].append(_make_district("Shopping", "SHOPPING", Vector2(0.65,0.45), 0.18, 0.12, rng))
	map["districts"].append(_make_district("Industrial", "INDUSTRIAL", Vector2(0.78,0.6), 0.18, 0.14, rng))

	# Generate POIs for each district
	for district in map["districts"]:
		district["pois"] = _generate_pois_for_district(district, rng)

	# Internal roads (POI -> district center)
	# Internal roads (POI -> district hub using Manhattan segments)
	for district in map["districts"]:
		var hub = district.get("hub", district["center"])
		for poi in district["pois"]:
		# Road in two segments: horizontal then vertical
			map["roads"].append({
				"from": poi["id"],
				"to": district["id"],
				"from_pos": poi["pos"],
				"to_pos": Vector2(poi["pos"].x, hub.y)   # horizontal first
			})
			map["roads"].append({
				"from": district["id"],
				"to": "hub_temp",
				"from_pos": Vector2(poi["pos"].x, hub.y),
				"to_pos": hub
			})
			
		# 2. Highways: connect hubs along a grid
	var hubs = []
	for district in map["districts"]:
		hubs.append({"id": district["id"], "pos": district.get("hub", district["center"])})

	# horizontal highways (sort by y, connect left→right)
	hubs.sort_custom(func(a, b): return int(a["pos"].y - b["pos"].y))
	for i in range(hubs.size()-1):
		var a = hubs[i]
		var b = hubs[i+1]
		# only connect if roughly on same row
		if abs(a["pos"].y - b["pos"].y) < 0.1:
			map["roads"].append({
				"type": "highway",
				"from": a["id"], "to": b["id"],
				"from_pos": a["pos"], "to_pos": b["pos"]
			})

	# vertical highways (sort by x, connect top→bottom)
	hubs.sort_custom(func(a, b): return int(a["pos"].x - b["pos"].x))
	for i in range(hubs.size()-1):
		var a = hubs[i]
		var b = hubs[i+1]
		if abs(a["pos"].x - b["pos"].x) < 0.1:
			map["roads"].append({
				"type": "highway",
				"from": a["id"], "to": b["id"],
				"from_pos": a["pos"], "to_pos": b["pos"]
			})

	# 3. Metro lines: connect nearest neighbors, abstract style
	for i in range(map["districts"].size()):
		var a = map["districts"][i]
		var hub_a = a.get("hub", a["center"])
		# find nearest 2 districts
		var sorted = []
		for j in range(map["districts"].size()):
			if i == j: continue
			var b = map["districts"][j]
			var hub_b = b.get("hub", b["center"])
			sorted.append({"id": b["id"], "pos": hub_b, "dist": hub_a.distance_to(hub_b)})
		sorted.sort_custom(func(x,y): return int(x["dist"] - y["dist"]))
		var n_neighbors = min(2, sorted.size())
		for k in range(n_neighbors):
			var b = sorted[k]
			map["roads"].append({
				"type": "metro",
				"from": a["id"], "to": b["id"],
				"from_pos": hub_a, "to_pos": b["pos"]
			})

	# 4. District labels
	for district in map["districts"]:
		map["labels"] = map.get("labels", [])
		map["labels"].append({
			"text": district["name"],
			"pos": district.get("hub", district["center"])
		})

	## Connect district centers with nearest neighbors (ensures connectivity basics)
	#for i in range(map["districts"].size()):
		#var a = map["districts"][i]
		#var sorted = []
		#for j in range(map["districts"].size()):
			#if i == j:
				#continue
			#var b = map["districts"][j]
			#sorted.append({"idx": j, "dist": a["center"].distance_to(b["center"])})
		#sorted.sort_custom(func(x, y): return int(x["dist"] - y["dist"]))
		#var n_neighbors = min(2, sorted.size())
		#for k in range(n_neighbors):
			#var b = map["districts"][sorted[k]["idx"]]
			#map["roads"].append({
				#"from": a["id"],
				#"to": b["id"],
				#"from_pos": a["center"],
				#"to_pos": b["center"]
			#})

	return map
	
# Helper: make a jittered rectangle-like polygon (normalized coords)
static func _make_district(name:String, dtype:String, center:Vector2, w:float, h:float, rng:RandomNumberGenerator) -> Dictionary:
	_district_counter += 1
	var polygon = []
	var halfw = w * 0.5
	var halfh = h * 0.5
	var corners = [
		center + Vector2(-halfw, -halfh),
		center + Vector2(halfw, -halfh),
		center + Vector2(halfw, halfh),
		center + Vector2(-halfw, halfh)
	]
	for i in range(corners.size()):
		var jitter = Vector2(rng.randf_range(-w*0.12, w*0.12), rng.randf_range(-h*0.12, h*0.12))
		var c = corners[i] + jitter
		c.x = clamp(c.x, 0.0, 1.0)
		c.y = clamp(c.y, 0.0, 1.0)
		polygon.append(c)
	return {
		"id": "district_%d" % _district_counter,
		"name": name,
		"type": dtype,
		"center": center,
		"w": w,
		"h": h,
		"polygon": polygon,
		"color": DISTRICT_TYPES.get(dtype, Color8(180,180,180))
	}

# Simple POI generation (samples within bounding box of the district polygon)
static func _generate_pois_for_district(district:Dictionary, rng:RandomNumberGenerator) -> Array:
	var type = district["type"]
	var count = 2
	match type:
		"DOWNTOWN": count = rng.randi_range(6, 10)
		"SUBURB": count = rng.randi_range(2, 4)
		"COAST": count = rng.randi_range(3, 6)
		"NATURE": count = rng.randi_range(1, 3)
		"SHOPPING": count = rng.randi_range(3, 5)
		"INDUSTRIAL": count = rng.randi_range(2, 4)
		_: count = rng.randi_range(2, 4)

	var pois = []
	# --- main hub point (slightly jittered district center) ---
	var hub = district["center"] + Vector2(
		rng.randf_range(-district["w"] * 0.15, district["w"] * 0.15),
		rng.randf_range(-district["h"] * 0.15, district["h"] * 0.15)
	)

	# Decide grid size (square grid roughly around hub)
	var grid_side = int(ceil(sqrt(count)))
	var spacing = min(district["w"], district["h"]) / (grid_side + 1)

	# Generate POIs in a local grid around hub
	var idx = 0
	for gx in range(grid_side):
		for gy in range(grid_side):
			if idx >= count:
				break
			_poi_counter += 1
			var offset = Vector2(
				(gx - grid_side/2.0) * spacing + rng.randf_range(-spacing*0.2, spacing*0.2),
				(gy - grid_side/2.0) * spacing + rng.randf_range(-spacing*0.2, spacing*0.2)
			)
			var pos = hub + offset
			# clamp to map bounds (0–1 space)
			pos.x = clamp(pos.x, 0.02, 0.98)
			pos.y = clamp(pos.y, 0.02, 0.98)

			pois.append({
				"id": "poi_%d" % _poi_counter,
				"name": "%s_POI_%d" % [district["name"], idx],
				"type": _pick_poi_type_for_district(type, rng),
				"pos": pos
			})
			idx += 1

	# Save hub too (as a "district center POI") so roads can connect cleanly
	district["hub"] = hub

	return pois
#static func _generate_pois_for_district(district:Dictionary, rng:RandomNumberGenerator) -> Array:
	#var type = district["type"]
	#var count = 2
	#match type:
		#"DOWNTOWN":
			#count = rng.randi_range(6, 10)
		#"SUBURB":
			#count = rng.randi_range(2, 4)
		#"COAST":
			#count = rng.randi_range(3, 6)
		#"NATURE":
			#count = rng.randi_range(1, 3)
		#"SHOPPING":
			#count = rng.randi_range(3, 5)
		#"INDUSTRIAL":
			#count = rng.randi_range(2, 4)
		#_:
			#count = rng.randi_range(2, 4)
	#var pois = []
	#var bbox_min = Vector2(1,1)
	#var bbox_max = Vector2(0,0)
	#for p in district["polygon"]:
		#bbox_min.x = min(bbox_min.x, p.x)
		#bbox_min.y = min(bbox_min.y, p.y)
		#bbox_max.x = max(bbox_max.x, p.x)
		#bbox_max.y = max(bbox_max.y, p.y)
	#for i in range(count):
		#_poi_counter += 1
		#var pos = Vector2(rng.randf_range(bbox_min.x, bbox_max.x), rng.randf_range(bbox_min.y, bbox_max.y))
		#pois.append({
			#"id": "poi_%d" % _poi_counter,
			#"name": "%s_POI_%d" % [district["name"], i],
			#"type": _pick_poi_type_for_district(type, rng),
			#"pos": pos
		#})
	#return pois

static func _pick_poi_type_for_district(dtype:String, rng:RandomNumberGenerator) -> String:
	var choices = []
	match dtype:
		"DOWNTOWN":
			choices = ["Office", "Cafe", "Shop", "Station", "Mall"]
		"SUBURB":
			choices = ["House", "School", "Cafe", "Grocery"]
		"COAST":
			choices = ["Beach", "Pier", "Cafe", "BoatDock"]
		"NATURE":
			choices = ["Park", "Trailhead", "Cemetery"]
		"SHOPPING":
			choices = ["Mall", "Cinema", "FoodCourt", "Market"]
		"INDUSTRIAL":
			choices = ["Factory", "Warehouse", "Depot"]
		_:
			choices = ["Shop", "Cafe"]
	return choices[rng.randi_range(0, choices.size() - 1)]

static func _randf_range_deg(i, total, rng:RandomNumberGenerator) -> float:
	var base = float(i) / float(total) * TAU
	return base + deg_to_rad(rng.randf_range(-30, 30))
