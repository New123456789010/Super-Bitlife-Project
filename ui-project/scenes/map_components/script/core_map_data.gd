class District:
	var name: String
	var type: String   # "Coastal", "CBD", "Suburb", "Nature"
	var polygon: PackedVector2Array
	var pois: Array    # array of POI objects
	var neighbors: Array # connected districts

class POI:
	var name: String
	var type: String   # "Store", "Townhall", "Station", "Park"
	var position: Vector2
	var district: District
