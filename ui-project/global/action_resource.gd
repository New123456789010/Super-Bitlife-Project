extends Resource
class_name ActionResource

@export var name: String = "Unnamed Action"
@export var description: String = ""
@export var icon: Texture

# Time & cost
@export_range(1, 96) var default_length: int = 4 # In 15-min slots (e.g., 1h = 4 slots)
@export var energy_cost_per_unit: float = 1.0
@export var energy_cost: float = 1.0 # Optional upfront cost
@export var is_restful: bool = false

# Stat effect
@export_enum("intelligence", "charisma", "strength") var stat_affected: String = ""
@export var stat_gain_per_unit: float = 0.0

func apply(player_stats: PlayerStats, duration: int = 1) -> bool:
	var total_cost := energy_cost_per_unit * duration

	# Energy check
	if !is_restful and player_stats.energy < total_cost:
		print("❌ Not enough energy for", name)
		return false

	# Energy adjustment
	if is_restful:
		player_stats.energy += abs(total_cost)
	else:
		player_stats.energy -= total_cost

	# Stat adjustment
	var gain := stat_gain_per_unit * duration
	match stat_affected:
		"intelligence": player_stats.intelligence += gain
		"charisma": player_stats.charisma += gain
		"strength": player_stats.strength += gain
		_: pass # Unknown or none

	return true
