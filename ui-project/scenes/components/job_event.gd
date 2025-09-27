extends PanelContainer

@onready var event_text: RichTextLabel = $MarginContainer/VBoxContainer/EventLabel
@onready var run_button: Button = $MarginContainer/VBoxContainer/RunEvents

# Adjustable first-event chances
var first_event_chance_uneventful := 0.5
var first_event_chance_good := 0.25
var first_event_chance_bad := 0.25

# ==========================
# Event definitions (Good / Bad / Reduced Uneventful) with conditional results
# ==========================
var events := {
	"good": [
		{"description": "Customer greeted you friendly", "result": ["You greet them back and feel happy."]},
		{"description": "Customer tipped you for your hard work", "result": ["You thank them and feel more motivated."]},
		{"description": "While on the break someone from food store give you free drink on hot day", "result": [
			"You thank them and feel happy meeting nice people.",
			"You feel less tired (if a bad event made you tired before)."
		]},
		{"description": "A child wave at you while you make delivery", "result": ["You greet back and think what a nice kid."]},
		{"description": "You were thanked personally for fast service", "result": ["You feel appreciated and more motivated."]},
		{"description": "You enjoyed a nice weather during your shift", "result": ["You feel calm and more motivated."]},
		{"description": "You finish all deliveries safely and on time", "result": ["Increase chance of compliment or tip event."]},
		{"description": "A loyal customer recognized you and said 'You always do a great job'", "result": ["You feel appreciated and more motivated."]},
		{"description": "Your supervisor give you a bonus for your great job", "result": ["You feel great and very rewarded. (Only happen if you get compliment event 20 times or get event 8 for 7 times)"]},
		{"description": "Your supervisor buy you a lunch for no reason", "result": ["Free food, nice."]}
	],
	"bad": [
		{"description": "A dog barked at you while approaching a house", "result": ["You feel terrified."]},
		{"description": "A dog chased after you down the street", "result": ["Your day feels ruined and now you’re tired."]},
		{"description": "Your bike broke down during delivery", "result": ["You walk back to the delivery station."]},
		{"description": "You caught in heavy rain while delivery", "result": [
			"You’re completely soaked and cold.",
			"Lucky (if driving a truck)."
		]},
		{"description": "You stuck in traffic for a long time", "result": ["You are late; customer is very angry."]},
		{"description": "You were given a wrong address", "result": [
			"You go back to your delivery station tired.",
			"You feel very upset at your supervisor (if traffic happened before)."
		]},
		{"description": "You drop the package while delivering", "result": [
			"Customer very mad (if traffic or wrong address happened before).",
			"Worst-case: Customer furious and calls company, supervisor also mad (if traffic and wrong address happened before).",
			"You broke customer package, now they are very angry."
		]},
		{"description": "You got yell by angry customer", "result": [
			"Feel mad but can't do anything.",
			"Feel very guilty and sad (if event 5 and 7 happen before).",
			"Feel very tired and sad now want to quit (if worst case)."
		]},
		{"description": "Your back is injured while try to lift heavy package", "result": ["You feel terrible all day."]},
		{"description": "You almost got hit by a car", "result": [
			"Lucky, survived (God Cat does not claim me yet).",
			"You die (only when your HP is very low or 0.01% chance)."
		]}
	],
	"uneventful": [
		{"description": "A calm day passes with no major incidents", "result": ["You complete your shift quietly."]},
		{"description": "A routine day on the road", "result": ["Everything goes smoothly."]}
	]
}

# ==========================
# Ready function
# ==========================
func _ready() -> void:
	randomize()
	run_button.pressed.connect(_run_event_sequence)
	event_text.text = "[i]Press Run to generate 6 events[/i]"

# ==========================
# Main: generate 6 events
# ==========================
func _run_event_sequence() -> void:
	var output := ""
	var first_category = _pick_first_event()
	var first_event = _get_random_event(first_category)
	output += "[b]1. Event:[/b] " + first_event["description"] + "\n[b]Result:[/b] " + _format_result(first_event["result"]) + "\n\n"

	# If the first event is uneventful, stop here
	if first_category == "uneventful":
		event_text.text = output
		return

	# Remaining 5 events: only good or bad
	for i in range(2, 7):
		var category = _pick_good_or_bad()
		var e = _get_random_event(category)
		output += "[b]" + str(i) + ". Event:[/b] " + e["description"] + "\n[b]Result:[/b] " + _format_result(e["result"]) + "\n\n"

	event_text.text = output

# ==========================
# Format result (handle multiple results)
# ==========================
func _format_result(result) -> String:
	if typeof(result) == TYPE_ARRAY:
		return "\n".join(result)
	return str(result)

# ==========================
# First event selection (weighted)
# ==========================
func _pick_first_event() -> String:
	var roll = randf()
	if roll < first_event_chance_uneventful:
		return "uneventful"
	elif roll < first_event_chance_uneventful + first_event_chance_good:
		return "good"
	else:
		return "bad"

# ==========================
# Pick good or bad (for remaining events)
# ==========================
func _pick_good_or_bad() -> String:
	return (randf() < 0.5) ? "good" : "bad"

# ==========================
# Grab random event from category
# ==========================
func _get_random_event(category: String) -> Dictionary:
	var idx = randi() % events[category].size()
	return events[category][idx]
