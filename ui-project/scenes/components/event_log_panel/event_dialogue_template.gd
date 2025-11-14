extends Panel
class_name DialogueTimeline

@export var dialogue_label: EventText        # RichTextLabel with typing
@export var choice_label: ChoiceLabel        # Clickable choices
@export var input_box: InlineInput           # LineEdit for inline input

@export var auto_advance := false
@export var auto_advance_delay: float = 1.0
@export var end_choice_text: String = "Close"

var _typing_base_delay: float = 0.02
var _typing_speed_multiplier: float = 1.0
const _MAX_MULTIPLIER := 8.0

var timeline: Array = []
var index: int = 0
var id_map: Dictionary = {}
var _running: bool = false
var _vars: Dictionary = {}

# ------------------------
# === Ready / Connections
# ------------------------
func _ready() -> void:
	if not SignalBus.start_timeline.is_connected(Callable(self, "_on_start")):
		SignalBus.start_timeline.connect(Callable(self, "_on_start"))

	choice_label.clear_options()
	choice_label.visible = false
	input_box.visible = false
	dialogue_label.clear_history()


# ------------------------
# === Entry Point
# ------------------------
func _on_start(new_timeline: Array) -> void:
	if _running:
		_running = false
		await get_tree().process_frame

	timeline = new_timeline.duplicate(true)
	index = 0
	id_map.clear()
	_vars.clear()

	for i in range(timeline.size()):
		var e = timeline[i]
		if typeof(e) == TYPE_DICTIONARY and e.has("id"):
			id_map[e["id"]] = i

	dialogue_label.clear_history()
	call_deferred("_run_timeline")


# ------------------------
# === Main Timeline Loop
# ------------------------
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
				await _run_dialogue(evt)
			"choice":
				await _run_choice(evt)
			"input":
				await _run_input(evt)
			"set":
				_run_set(evt)
				index += 1
			"resource":
				await _run_resource(evt)
				index += 1
			"extension":
				await _run_extension(evt)
				index += 1
			"signal":
				SignalBus.external_signal.emit(evt.get("name", ""))
				index += 1
			"wait":
				await get_tree().create_timer(evt.get("duration", 1.0)).timeout
				index += 1
			"end":
				await _run_end(evt)
				break
			_:
				push_warning("Unknown event type: %s" % t)
				index += 1

	_running = false
	SignalBus.timeline_ended.emit()


# ------------------------
# === Dialogue Event
# ------------------------
func _run_dialogue(evt: Dictionary) -> void:
	var raw = evt.get("text", "")
	var formatted = _format_text(raw)
	_typing_base_delay = dialogue_label.char_delay
	_typing_speed_multiplier = 1.0

	var advance_handler = Callable(self, "_on_advance_during_typing")
	if not SignalBus.advance.is_connected(advance_handler):
		SignalBus.advance.connect(advance_handler)

	await dialogue_label.append_line_typed(formatted)

	if SignalBus.advance.is_connected(advance_handler):
		SignalBus.advance.disconnect(advance_handler)

	dialogue_label.char_delay = _typing_base_delay
	_typing_speed_multiplier = 1.0

	if not auto_advance:
		await SignalBus.advance
	else:
		await get_tree().create_timer(auto_advance_delay).timeout

	index += 1


# ------------------------
# === Choice Event
# ------------------------
func _run_choice(evt: Dictionary) -> void:
	var options = evt.get("options", [])
	choice_label.show_options(options)
	choice_label.visible = true
	var sig = await choice_label.choice_chosen
	var choice_index: int = sig[0]
	var choice_data = sig[1] if sig.size() > 1 else {}
	choice_label.clear_options()
	choice_label.visible = false

	if choice_data.has("next"):
		var nxt = choice_data["next"]
		if typeof(nxt) == TYPE_STRING:
			index = _find_next_valid_event(nxt)
		elif typeof(nxt) in [TYPE_INT, TYPE_FLOAT]:
			index = int(nxt)
		else:
			index += 1
	elif choice_data.has("events") and typeof(choice_data["events"]) == TYPE_ARRAY:
		var to_insert = choice_data["events"]
		timeline = timeline.slice(0, index + 1) + to_insert + timeline.slice(index + 1, timeline.size())
		index += 1
	else:
		index += 1


# ------------------------
# === Input Event
# ------------------------
func _run_input(evt: Dictionary) -> void:
	var prompt = evt.get("prompt", "")
	var key = evt.get("var", "user_input")
	var default = evt.get("default", "")
	if prompt != "":
		await dialogue_label.append_line_typed(_format_text(prompt))
	input_box.request_input(default)
	input_box.visible = true
	var value = await input_box.submitted
	GameData.variables[key] = value
	SignalBus.input_submitted.emit(key, value)
	input_box.visible = false
	index += 1


# ------------------------
# === Set Event
# ------------------------
func _run_set(evt: Dictionary) -> void:
	var path: String = evt.get("path", "")
	var value = evt.get("value", null)
	if path.begins_with("GameData."):
		var parts = path.split(".").slice(1)
		var target = GameData
		for i in range(parts.size() - 1):
			target = target.get(parts[i])
		target.set(parts[-1], value)


# ------------------------
# === Resource Event
# ------------------------
func _run_resource(evt: Dictionary) -> void:
	var path: String = evt.get("path", "")
	var method: String = evt.get("method", "")
	var args = []
	for raw_arg in evt.get("args", []):
		args.append(_resolve_value(raw_arg))

	var assign_to: String = evt.get("assign_to", "")
	var res: Resource = load(path)
	if res and res.has_method(method):
		var result = res.callv(method, args)
		if assign_to != "":
			GameData.variables[assign_to] = result


# ------------------------
# === Extension Event
# ------------------------
func _run_extension(evt: Dictionary) -> void:
	var ext_name = evt.get("name", "")
	var method = evt.get("method", "")
	var args = evt.get("args", [])
	var node = get_tree().get_first_node_in_group(ext_name)
	if node and node.has_method(method):
		node.callv(method, args)


# ------------------------
# === End Event
# ------------------------
func _run_end(evt: Dictionary) -> void:
	var end_text = evt.get("text", "[End]")
	await dialogue_label.append_line_typed(_format_text(end_text))

	var exit_choice = evt.get("exit_text", end_choice_text)
	choice_label.show_options([{ "text": exit_choice, "next": null }])
	choice_label.visible = true
	await choice_label.choice_chosen
	choice_label.clear_options()
	choice_label.visible = false

	if SignalBus.has_signal("dialogue_finished"):
		SignalBus.dialogue_finished.emit()

	await _animate_timeline_end()
	if SignalBus.has_signal("timeline_ended"):
		SignalBus.timeline_ended.emit()


# ------------------------
# === Helpers
# ------------------------
func _evaluate_condition(expr: String) -> bool:
	if expr == "" or expr == null:
		return true
	var e := Expression.new()
	var result = e.parse(expr, ["GameData"])
	if result != OK:
		push_error("❌ Condition parse error: %s" % expr)
		return false
	var value = e.execute([GameData])
	if e.has_execute_failed():
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


func _format_text(text: String) -> String:
	# Replace {GameData.*} and {variable} placeholders
	for k in GameData.variables.keys():
		text = text.replace("{%s}" % k, str(GameData.variables[k]))

	var regex = RegEx.new()
	regex.compile("{(GameData\\.[^}]+)}")
	for result in regex.search_all(text):
		var path = result.get_string(1).replace("GameData.", "")
		var parts = path.split(".")
		var value = GameData
		for p in parts:
			if value == null:
				break
			if value.has_method("get") and value.get(p) != null:
				value = value.get(p)
		text = text.replace(result.get_string(0), str(value))

	# Support [img]...[/img]
	text = text.replace("[img]", "[img=64x64]")
	return text


func _animate_timeline_end() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	queue_free()


func _on_advance_during_typing() -> void:
	_typing_speed_multiplier *= 2.0
	if _typing_speed_multiplier >= _MAX_MULTIPLIER:
		dialogue_label.skip_current_typing()
		return
	dialogue_label.char_delay = _typing_base_delay / _typing_speed_multiplier

# Resolves an argument value for resource/extension calls
func _resolve_value(arg):
	if typeof(arg) == TYPE_STRING:
		if arg.begins_with("GameData."):
			var parts = arg.replace("GameData.", "").split(".")
			var value = GameData
			for p in parts:
				if value == null:
					break
				# Use get() if possible, otherwise access property directly
				if value.has_method("get"):
					value = value.get(p)
				elif value.has(p):
					value = value[p]
				else:
					if value.has_variable(p):
						value = value.get(p)
					else:
						value = null
			return value
		# fallback: check if it matches a stored variable
		elif GameData.variables.has(arg):
			return GameData.variables[arg]
		else:
			return arg
	return arg
