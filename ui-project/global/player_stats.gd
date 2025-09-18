# PlayerStats.gd
extends Resource
class_name PlayerStats

# Mental state could use an enum or standardized strings later
@export var health: float = 100.0
@export var mental_state: String = "Stable"

# Core stats
@export var intelligence: float = 50.0
@export var charisma: float = 50.0
@export var strength: float = 50.0

# Energy used in scheduling/actions
@export var energy: float = 100.0

func reset():
	health = 100.0
	mental_state = "Stable"
	intelligence = randf_range(30, 80)
	charisma = randf_range(30, 80)
	strength = randf_range(30, 80)
	energy = 100.0
