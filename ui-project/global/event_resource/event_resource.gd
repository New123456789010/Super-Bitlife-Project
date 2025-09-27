extends Resource

@export var event_name: String
@export var trigger_tags: Array[String] # e.g. "work", "morning"
@export var trigger_chance: float # probability
@export var conditions: Dictionary # {"money": < 0, "energy": < 20}
@export var choices: Array[EventChoiceResource]
