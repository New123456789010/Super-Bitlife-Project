extends Node
class_name CityManager

@onready var env := $CityEnvironment
@onready var zones := $CityZones
@onready var vis := $CityVisualizer

func _ready() -> void:
	print("CityManager: Starting generation sequence...")
	
	# Step 1 → Generate environment maps
	env.connect("maps_generated", Callable(self, "_on_maps_generated"))
	call_deferred("_start_generation")


func _start_generation() -> void:
	env.generate_maps()


func _on_maps_generated(water: Image, forest: Image, height: Image, population: Image, city_potential: Image) -> void:
	print("CityManager: Environment maps ready. Passing to zones...")
	
	# Step 2 → Run zoning
	zones.connect("zones_generated", Callable(self, "_on_zones_generated"))
	zones.generate_zones(city_potential)


func _on_zones_generated(zone_image: Image) -> void:
	print("CityManager: Zones ready. Drawing visualization...")
	
	# Step 3 → Let visualizer draw everything
	vis.display_composite(zone_image)
