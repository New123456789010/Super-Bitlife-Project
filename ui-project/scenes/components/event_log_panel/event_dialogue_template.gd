extends Panel

@export var dialogue_label: EventText        # drag the EventText node
@export var choice_label: ChoiceLabel        # drag the ChoiceLabel node
@export var input_box: InlineInput           # drag the InlineInput node

@export var auto_advance := false   # Toggle for autoplay (can be controlled by UI)
@export var auto_advance_delay: float = 1.0   # seconds to wait when auto_advance is true
# Typing speed control state (used while a line is animating)
var _typing_base_delay: float = 0.02
var _typing_speed_multiplier: float = 1.0
const _MAX_MULTIPLIER := 8.0   # once multiplier reaches this we force-complete the line

@export var end_choice_text: String = "Close"

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

				# --- Typing speed setup ---
				_typing_base_delay = dialogue_label.char_delay
				_typing_speed_multiplier = 1.0

				# connect advance handler (only while typing)
				var advance_handler = Callable(self, "_on_advance_during_typing")
				if not SignalBus.advance.is_connected(advance_handler):
					SignalBus.advance.connect(advance_handler)

				# await the typing animation (EventText uses dialogue_label.char_delay each loop)
				await dialogue_label.append_line_typed(formatted)

				# disconnect the handler (safe even if it was triggered)
				if SignalBus.advance.is_connected(advance_handler):
					SignalBus.advance.disconnect(advance_handler)

				# restore base delay and multiplier
				dialogue_label.char_delay = _typing_base_delay
				_typing_speed_multiplier = 1.0

				# Wait for user advance (or auto advance)
				if not auto_advance:
					await SignalBus.advance
				else:
					await get_tree().create_timer(auto_advance_delay).timeout

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
				# Optional custom text for [End] message
				var end_text = evt.get("text", "[End]")
				await dialogue_label.append_line_typed(end_text)

				# Custom exit choice text (fallback to exported var)
				var exit_choice = evt.get("exit_text", end_choice_text)

				# Show a final choice that acts as the exit confirmation
				choice_label.show_options([{ "text": exit_choice, "next": null }])
				choice_label.visible = true
				await choice_label.choice_chosen
				choice_label.clear_options()
				choice_label.visible = false

				# Emit dialogue_finished for logic chaining (optional next timeline)
				if SignalBus.has_signal("dialogue_finished"):
					SignalBus.dialogue_finished.emit()

				# Wait a moment, then animate and end the timeline
				await _animate_timeline_end()
				if SignalBus.has_signal("timeline_ended"):
					SignalBus.timeline_ended.emit()
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

func _animate_timeline_end() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	queue_free()  # safely remove panel after fade


# format text with variables (live)
func _format_text(text: String) -> String:
	for k in GameData.variables.keys():
		text = text.replace("{%s}" % k, str(GameData.variables[k]))
	return text


func _on_autoplay_toggled(pressed: bool):
	auto_advance = pressed
	
# handler called when advance is pressed DURING typing
func _on_advance_during_typing() -> void:
	# double speed each time and update dialogue_label.char_delay
	_typing_speed_multiplier *= 2.0
	# clamp multiplier to a reasonable max; when reached, force-complete
	if _typing_speed_multiplier >= _MAX_MULTIPLIER:
		dialogue_label.skip_current_typing()
		return

	# set new per-character delay (smaller delay => faster typing)
	dialogue_label.char_delay = _typing_base_delay / _typing_speed_multiplier
