# DialogueController.gd
extends Panel

@onready var event_text: EventText = %EventText
@onready var choice_container: VBoxContainer = $ChoiceContainer
@export var timeline_file: String

var timeline = []
var variables = {}
var current_index = 0

func _ready():
	load_timeline(timeline_file)
	play_next()

func load_timeline(file_path):
	var f = FileAccess.open(file_path, FileAccess.READ)
	var json_text = f.get_as_text()
	f.close()
	var data = JSON.parse_string(json_text)
	if data.error != OK:
		push_error("Failed to parse timeline JSON")
		return
	timeline = data.result["timeline"]

func play_next():
	if current_index >= timeline.size():
		print("Timeline ended")
		return
	var evt = timeline[current_index]
	match evt["type"]:
		"dialogue":
			event_text.add_t("%s: %s" % [evt["character"], evt["text"]])
			current_index += 1
		"choice":
			show_choices(evt)
		"text_input":
			request_text_input(evt)
		"conditional":
			handle_conditional(evt)
		"signal":
			emit_signal(evt["arg"])
			current_index += 1
		"action":
			# handle join, leave, etc
			current_index += 1
		"end_timeline":
			print("Timeline finished")
			return

func show_choices(evt):
	choice_container.clear()
	for opt in evt["options"]:
		var choice_label = Choice.new()
		choice_label.set_bbcode("[url]%s[/url]" % opt["text"])
		choice_label.connect("meta_clicked", Callable(self, "_on_choice_selected"))
		choice_container.add_child(choice_label)

func _on_choice_selected(option):
	choice_container.clear()
	# Insert option.result events into timeline at current_index
	timeline = timeline.slice(0, current_index + 1) + option["result"] + timeline.slice(current_index + 1, timeline.size())
	current_index += 1
	play_next()

func request_text_input(evt):
	# Simple dialog for input
	var popup = AcceptDialog.new()
	popup.dialog_text = evt["text"]
	var input = LineEdit.new()
	input.text = evt.get("default", "")
	popup.add_child(input)
	popup.connect("confirmed", func():
		_on_text_input_confirmed(evt, input)
	)
	add_child(popup)
	popup.popup_centered()

func _on_text_input_confirmed(evt, input):
	variables[evt["var"]] = input.text
	current_index += 1
	play_next()

func handle_conditional(evt):
	# Replace variables in condition
	var cond = evt["condition"]
	for key in variables.keys():
		cond = cond.replace("{%s}" % key, "\"" + variables[key] + "\"")
	if Expression.new().parse(cond) == OK and Expression.new().execute() == true:
		timeline = timeline.slice(0, current_index + 1) + evt["true"] + timeline.slice(current_index + 1, timeline.size())
	else:
		timeline = timeline.slice(0, current_index + 1) + evt["false"] + timeline.slice(current_index + 1, timeline.size())
	current_index += 1
	play_next()
