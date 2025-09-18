# JobResource.gd
extends Resource
class_name JobResource
#@icon("res://icons/job.svg")

@export var name: String = "Unnamed Job"
@export var description := """ """

# Compensation
@export var base_income_per_hour: float = 10.0
@export var energy_cost_per_hour: float = 2.0

# Stat requirements
@export_enum("intelligence", "charisma", "strength") var required_stat: String = ""
@export var required_stat_min: float = 0.0

# Time constraints
@export_range(0, 23) var start_hour: int = 9
@export_range(1, 12) var shift_length_hours: int = 8

func get_total_income(hours: int) -> float:
	return base_income_per_hour * hours

func get_total_energy_cost(hours: int) -> float:
	return energy_cost_per_hour * hours

func is_qualified(player_stats: PlayerStats) -> bool:
	match required_stat:
		"intelligence": return player_stats.intelligence >= required_stat_min
		"charisma": return player_stats.charisma >= required_stat_min
		"strength": return player_stats.strength >= required_stat_min
		_: return true
