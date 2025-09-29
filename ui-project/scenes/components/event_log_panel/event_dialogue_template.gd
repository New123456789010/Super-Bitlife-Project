extends Panel

@onready var event_text: RichTextLabel = %EventText
@onready var choice_label: RichTextLabel = %Choice

var end_of_event := false
var timeline_index := 0
var timeline_data := []

func _ready() -> void:
	randomize()
	mouse_filter = Control.MOUSE_FILTER_STOP
	end_of_event = false
	event_text.text = "[i]Click anywhere to start the demo timeline[/i]"

	# Setup a demo timeline
	timeline_data = [
		{"type":"text","character":"weird_cat","line":"Yo! Welcome to your new house. It's a bit bare, but you'll cozy it up."},
		{"type":"text","character":"weird_cat","line":"Make sure you have enough for rent, food, utilities, etc."},
		{"type":"choice","options":["Unpack your stuff","Take a nap","Go outside"]},
		{"type":"text_input","prompt":"What's your secret password?","variable":"secret_code","default":"1234"},
		{"type":"signal","arg":"timeline_demo_signal"},
		{"type":"text","character":"weird_cat","line":"That's the end of the demo timeline."},
	]

	# Connect Choice click
	choice_label.connect("meta_clicked", Callable(self, "_on_choice_selected"))


# ==========================
# Input to advance timeline
# ==========================
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		print("Press detected")
		if end_of_event:
			self.queue_free()
			return
		_run_next_timeline_event()
	elif event is InputEventScreenTouch and event.pressed:
		print("Press detected")
		if end_of_event:
			self.queue_free()
			return
		_run_next_timeline_event()
		


# ==========================
# Timeline runner
# ==========================
func _run_next_timeline_event() -> void:
	if timeline_index >= timeline_data.size():
		end_of_event = true
		event_text.add_t("[i]Timeline finished[/i]")
		_scroll_event_text()
		return

	var item = timeline_data[timeline_index]
	timeline_index += 1

	match item.type:
		"text":
			var character = item.get("character","")
			var line = item.get("line","")
			if character != "":
				event_text.add_t("[b]%s:[/b] %s" % [character, line])
			else:
				event_text.add_t(line)
			_scroll_event_text()

		"choice":
			_show_choice(item.options)

		"text_input":
			_show_text_input(item)

		"signal":
			event_text.add_t("[i]Signal fired: %s[/i]" % item.arg)
			_scroll_event_text()


# ==========================
# Choice handler
# ==========================
func _show_choice(options:Array) -> void:
	choice_label.clear()
	for i in range(options.size()):
		# clickable with meta = option index
		choice_label.append_text("[url=%d]%d. %s[/url]\n" % [i, i+1, options[i]])
	choice_label.on_option()


func _on_choice_selected(meta: Variant) -> void:
	event_text.add_t("[i]Choice selected: %s[/i]" % meta)
	choice_label.clear()
	_scroll_event_text()
	_run_next_timeline_event()


# ==========================
# Text input handler
# ==========================
func _show_text_input(item:Dictionary) -> void:
	var prompt = item.prompt
	var default_value = item.default
	event_text.add_t("%s (default: %s)" % [prompt, default_value])
	_scroll_event_text()
	# auto-fill default
	_run_next_timeline_event()


# ==========================
# Tween scrolling for EventText
# ==========================
func _scroll_event_text() -> void:
	var scroll: ScrollBar = event_text.get_v_scroll_bar()
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(scroll.set_value, scroll.get_value(), scroll.get_max(), 0.5)


#extends Panel
#
#@onready var event_text: RichTextLabel = %EventText
#@onready var choice_label: RichTextLabel = %Choice
#
#var end_of_event := false
#
#func _ready() -> void:
	#randomize()
	#mouse_filter = Control.MOUSE_FILTER_STOP
	#end_of_event = false
	#event_text.text = "[i]Press Run to start a timeline[/i]"
#
#
## ==========================
## Start timeline dynamically
## ==========================
#func start_dialogue(timeline_name: String) -> void:
	#end_of_event = false
	#event_text.clear()
	#choice_label.clear()
	#
	#var handler := Dialogic.start(timeline_name)
	#
		## connect signals on this handler
	#handler.timeline_ended.connect(_on_timeline_end)
	#handler.dialogic_signal.connect(_on_signal)         # for [signal arg=...]
	#handler.textbox_signal.connect(_on_text)            # character + line
	#handler.choice_selected_signal.connect(_on_choice)  # choices
	#handler.text_input_signal.connect(_on_text_input)   # text input
#
#
## ==========================
## Signal Handlers
## ==========================
#func _on_timeline_end(timeline_name: String) -> void:
	#end_of_event = true
	#event_text.add_t("[i]End of timeline: %s[/i]" % timeline_name)
#
#
#func _on_text(line: String, character: String) -> void:
	#if character != "":
		#event_text.add_t("[b]%s:[/b] %s" % [character, line])
	#else:
		#event_text.add_t(line)
#
#
#func _on_choice(choices: Array) -> void:
	#choice_label.clear()
	#for i in range(choices.size()):
		#var text = "[url=%d]%d. %s[/url]\n" % [i, i+1, choices[i]]
		#choice_label.append_text(text)
	#choice_label.on_option()
#
#
#func _on_signal(arg: String) -> void:
	## For custom events like [signal arg="show_newspaper_ads"]
	#event_text.add_t("[i]Signal fired:[/i] %s" % arg)
	## TODO: Trigger game logic here (like opening a panel)
#
#
#func _on_text_input(prompt: String, variable: String, default_value: String) -> void:
	## For [text_input ...]
	#event_text.add_t("%s (default: %s)" % [prompt, default_value])
	## For now just auto-answer with default
	#Dialogic.set_variable(variable, default_value)
	#Dialogic.continue()


#extends Panel
#
#@onready var event_text: RichTextLabel = %EventText
#
## Adjustable first-event chances
#
#var end_of_event := false
#
## ==========================
## Ready function
## ==========================
#func _ready() -> void:
	#randomize()
	#mouse_filter = Control.MOUSE_FILTER_STOP
	#end_of_event = false
	#event_text.text = "[i]Press Run to generate 6 events[/i]"
	#
	## Connect to dialogic signals
	#Dialogic.timeline_ended.connect(_on_timeline_end)
	#Dialogic.text_signal.connect(_on_text)        # when text updates
	#Dialogic.choice_signal.connect(_on_choice)    # when choices appear
#
## ==========================
## Gui Input
## ==========================
#func _on_event_text_gui_input(event: InputEvent) -> void:
	#if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		#if event.pressed && end_of_event == false:
			#event_text.text += 'add more text\n'
			#event_text.on_option()
			#return
			#print("Input detected: _run_event_sequence")
		#elif event.pressed && end_of_event == true:
			#self.queue_free()
	#elif event is InputEventScreenTouch && end_of_event == false:
		#if event.pressed:
			#event_text.text += 'add more text\n'
			#event_text.on_option()
			#return
			#print("Input detected: _run_event_sequence")
		#elif event.pressed && end_of_event == true:
			#self.queue_free()
			#
			#
#func _on_timeline_end(timeline_name: String) -> void:
	#end_of_event = true
	#event_text.add_t("[i]End of timeline: %s[/i]" % timeline_name)
#
#
#func _on_text(line: String) -> void:
	#event_text.add_t(line)
#
#
#func _on_choice(choices: Array) -> void:
	#var choice_label: RichTextLabel = %Choice
	#choice_label.clear()
	#for i in range(choices.size()):
		#var text = "[url=%d]%d. %s[/url]\n" % [i, i+1, choices[i]]
		#choice_label.append_text(text)
#
	#choice_label.on_option()
#
