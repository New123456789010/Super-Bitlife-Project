extends Panel

@export var dialogue_label: EventText        # drag the EventText node
@export var choice_label: ChoiceLabel        # drag the ChoiceLabel node
@export var input_box: InlineInput           # drag the InlineInput node

var timeline: Array = []
var index: int = 0
var id_map: Dictionary = {}
var _running: bool = false

func _ready() -> void:
	# connect bus signals once (guard against double connects)
	if not SignalBus.start_timeline.is_connected(Callable(self, "_on_start")):
		SignalBus.start_timeline.connect(Callable(self, "_on_start"))
	choice_label.choice_chosen.connect(Callable(self, "_on_choice_made"))
	input_box.submitted.connect(Callable(self, "_on_input_submitted"))

	choice_label.clear_options()
	choice_label.visible = false
	input_box.visible = false
	dialogue_label.clear_history()

# Start the runner
func _on_start(new_timeline: Array) -> void:
	if _running:
		# optionally stop existing or ignore; here we reset
		_running = false
		# small wait to ensure previous coroutine halts
		await get_tree().process_frame

	timeline = new_timeline.duplicate(true)
	index = 0
	id_map.clear()

	# Build id_map for label jumps
	for i in range(timeline.size()):
		var e = timeline[i]
		if typeof(e) == TYPE_DICTIONARY and e.has("id"):
			id_map[e["id"]] = i

	dialogue_label.clear_history()
	call_deferred("_run_timeline")  # start async
	return

# Main runner loop (single, sequential)
func _run_timeline() -> void:
	_running = true
	while index < timeline.size():
		var evt = timeline[index]
		if typeof(evt) != TYPE_DICTIONARY:
			index += 1
			continue
			
		if evt.has("condition") and not _evaluate_condition(evt["condition"]):
			index += 1
			continue

		var t = evt.get("type", "dialogue")
		match t:
			"dialogue":
				var raw = evt.get("text", "")
				var formatted := _format_text(raw)
				# await the typing animation
				await dialogue_label.append_line_typed(formatted)
				index += 1
				continue

			"choice":
				var options = evt.get("options", [])
				choice_label.show_options(options)
				choice_label.visible = true
				# wait for a choice to be made
				var sig = await choice_label.choice_chosen
				# sig is a VariantArray of args -> [index, data_dict]
				var choice_index := int(sig[0])
				var choice_data = sig[1] if sig.size() > 1 else {}
				choice_label.clear_options()
				choice_label.visible = false

				# Resolve next: if choice_data.next is label or index
				if choice_data.has("next"):
					var nxt = choice_data["next"]
					if typeof(nxt) == TYPE_STRING:
						index = _find_next_valid_event(nxt)
					elif typeof(nxt) in [TYPE_INT, TYPE_FLOAT]:
						index = int(nxt)
					else:
						index += 1

				else:
					# fallback: insert events (if provided) next inline
					if choice_data.has("events") and typeof(choice_data["events"]) == TYPE_ARRAY:
						# splice events after current index
						var to_insert = choice_data["events"]
						timeline = timeline.slice(0, index+1) + to_insert + timeline.slice(index+1, timeline.size())
						index += 1
					else:
						index += 1
				continue

			"input":
				# generic input: will store into GameData.variables[key]
				var prompt = evt.get("prompt", "")
				var key = evt.get("var", "user_input")
				var default = evt.get("default", "")
				# show prompt as dialogue line (optional)
				if prompt != "":
					await dialogue_label.append_line_typed(_format_text(prompt))
				# request inline input
				input_box.request_input(default)
				input_box.visible = true
				# wait for input_box.submitted
				var value = await input_box.submitted
				GameData.variables[key] = value
				# optionally emit via SignalBus
				SignalBus.input_submitted.emit(key, value)
				input_box.visible = false
				index += 1
				continue

			"signal":
				SignalBus.external_signal.emit(evt.get("name", ""))
				index += 1
				continue

			"action":
				# placeholder for actions (play animation, etc.)
				index += 1
				continue

			"end":
				await dialogue_label.append_line_typed("[End]")
				break

			_:
				push_warning("Unknown event type: %s" % t)
				index += 1
				continue

	# runner finished
	_running = false
	return

func _evaluate_condition(expr: String) -> bool:
	if expr == "" or expr == null:
		return true
	var expression := Expression.new()
	var result := expression.parse(expr, ["GameData"])
	if result != OK:
		push_error("❌ Condition parse error: %s" % expr)
		return false
	var value = expression.execute([GameData])
	if expression.has_execute_failed():
		push_error("❌ Condition execution failed for: %s" % expr)
		return false
	return bool(value)

func _find_next_valid_event(target_id: String) -> int:
	for i in range(timeline.size()):
		var e = timeline[i]
		if typeof(e) == TYPE_DICTIONARY and e.get("id", "") == target_id:
			if not e.has("condition") or _evaluate_condition(e["condition"]):
				return i
	return index + 1

# format text with variables (live)
func _format_text(text: String) -> String:
	for k in GameData.variables.keys():
		text = text.replace("{%s}" % k, str(GameData.variables[k]))
	return text





#func _ready() -> void:
	#if not choice_label.is_connected("choice_chosen", Callable(self, "_on_choice_chosen")):
		#choice_label.choice_chosen.connect(Callable(self, "_on_choice_chosen"))
#
	#input_line.text_submitted.connect(Callable(self, "_on_input_submitted"))
	#input_line.visible = false
#
	#call_deferred("_start_demo")
#
## -------------------------
## Load Scene Text
## -------------------------
#
#
## -------------------------
## Demo flow with input
## -------------------------
#func _start_demo() -> void:
	#await event_text.append_line_typed("weird_cat: Let's test text input now…")
	#await event_text.append_line_typed("weird_cat: What's your secret password?")
#
	## request input for variable "secret_code"
	#request_input("secret_code", "1234")
#
## -------------------------
## Input handling
## -------------------------
#func request_input(var_name: String, default_val: String = "") -> void:
	#variables[var_name] = default_val
	#input_line.text = default_val
	#input_line.visible = true
	#input_line.grab_focus()
#
#func _on_input_submitted(new_text: String) -> void:
	## hide input
	#input_line.visible = false
#
	#var var_name := "secret_code"  # later, this will come from the timeline
	#variables[var_name] = new_text
#
	## mirror back the player's response with typing animation
	#await event_text.append_line_typed("you: " + new_text)
#
	## continue demo with smooth typing
	#if new_text != "3.14159":
		#await event_text.append_line_typed("weird_cat: Hmm… that’s not the magic number I was expecting.")
	#else:
		#await event_text.append_line_typed("weird_cat: Whoa! You cracked the code! 🐱")
#
	#await event_text.append_line_typed("⚡ End of demo with input.")
