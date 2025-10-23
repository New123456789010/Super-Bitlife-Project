extends Panel
class_name DialogueTimeline

@export var dialogue_label: EventText
@export var choice_label: ChoiceLabel
@export var input_box: InlineInput

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


func _ready() -> void:
	if not SignalBus.start_timeline.is_connected(Callable(self, "_on_start")):
		SignalBus.start_timeline.connect(Callable(self, "_on_start"))
	choice_label.choice_chosen.connect(Callable(self, "_on_choice_made"))
	input_box.submitted.connect(Callable(self, "_on_input_submitted"))

	choice_label.clear_options()
	choice_label.visible = false
	input_box.visible = false
	dialogue_label.clear_history()


# === ENTRY POINT ===
func _on_start(new_timeline: Array) -> void:
	if _running:
		_running = false
		await get_tree().process_frame

	timeline = new_timeline.duplicate(true)
	index = 0
	id_map.clear()

	for i in range(timeline.size()):
		var e = timeline[i]
		if typeof(e) == TYPE_DICTIONARY and e.has("id"):
			id_map[e["id"]] = i

	dialogue_label.clear_history()
	call_deferred("_run_timeline")


# === MAIN RUN LOOP ===
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

		match evt.get("type", "dialogue"):
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
				push_warning("Unknown event type: %s" % evt.get("type"))
				index += 1

	_running = false


# === EVENT HANDLERS ===
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


func _run_set(evt: Dictionary) -> void:
	# Example: { "type": "set", "path": "GameData.player_stats.energy", "value": 10 }
	var path: String = evt.get("path", "")
	var value = evt.get("value", null)
	if path.begins_with("GameData."):
		var parts = path.split(".").slice(1)
		var target = GameData
		for i in range(parts.size() - 1):
			target = target.get(parts[i])
		target.set(parts[-1], value)


func _run_resource(evt: Dictionary) -> void:
	var path: String = evt.get("path", "")
	var method: String = evt.get("method", "")
	var args: Array = evt.get("args", [])
	var assign_to: String = evt.get("assign_to", "")
	var res: Resource = load(path)
	if res and method in res:
		var result = res.callv(method, args)
		if assign_to != "":
			GameData.variables[assign_to] = result


func _run_extension(evt: Dictionary) -> void:
	var ext_name = evt.get("name", "")
	var method = evt.get("method", "")
	var args = evt.get("args", [])
	var node = get_tree().get_first_node_in_group(ext_name)
	if node and method in node:
		node.callv(method, args)


func _run_end(evt: Dictionary) -> void:
	var end_text = evt.get("text", "[End]")
	await dialogue_label.append_line_typed(end_text)
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


# === HELPERS ===
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


func _format_text(text: String) -> String:
	for k in GameData.variables.keys():
		text = text.replace("{%s}" % k, str(GameData.variables[k]))
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


#extends Panel
#
#@export var dialogue_label: EventText        # drag the EventText node
#@export var choice_label: ChoiceLabel        # drag the ChoiceLabel node
#@export var input_box: InlineInput           # drag the InlineInput node
#
#@export var auto_advance := false   # Toggle for autoplay (can be controlled by UI)
#@export var auto_advance_delay: float = 1.0   # seconds to wait when auto_advance is true
## Typing speed control state (used while a line is animating)
#var _typing_base_delay: float = 0.02
#var _typing_speed_multiplier: float = 1.0
#const _MAX_MULTIPLIER := 8.0   # once multiplier reaches this we force-complete the line
#
#@export var end_choice_text: String = "Close"
#
#var timeline: Array = []
#var index: int = 0
#var id_map: Dictionary = {}
#var _running: bool = false
#
#func _ready() -> void:
	## connect bus signals once (guard against double connects)
	#if not SignalBus.start_timeline.is_connected(Callable(self, "_on_start")):
		#SignalBus.start_timeline.connect(Callable(self, "_on_start"))
	#choice_label.choice_chosen.connect(Callable(self, "_on_choice_made"))
	#input_box.submitted.connect(Callable(self, "_on_input_submitted"))
#
	#choice_label.clear_options()
	#choice_label.visible = false
	#input_box.visible = false
	#dialogue_label.clear_history()
#
## Start the runner
#func _on_start(new_timeline: Array) -> void:
	#if _running:
		## optionally stop existing or ignore; here we reset
		#_running = false
		## small wait to ensure previous coroutine halts
		#await get_tree().process_frame
#
	#timeline = new_timeline.duplicate(true)
	#index = 0
	#id_map.clear()
#
	## Build id_map for label jumps
	#for i in range(timeline.size()):
		#var e = timeline[i]
		#if typeof(e) == TYPE_DICTIONARY and e.has("id"):
			#id_map[e["id"]] = i
#
	#dialogue_label.clear_history()
	#call_deferred("_run_timeline")  # start async
	#return
#
## Main runner loop (single, sequential)
#func _run_timeline() -> void:
	#_running = true
	#while index < timeline.size():
		#var evt = timeline[index]
		#if typeof(evt) != TYPE_DICTIONARY:
			#index += 1
			#continue
			#
		#if evt.has("condition") and not _evaluate_condition(evt["condition"]):
			#index += 1
			#continue
#
		#var t = evt.get("type", "dialogue")
		#match t:
			#"dialogue":
				#var raw = evt.get("text", "")
				#var formatted := _format_text(raw)
#
				## --- Typing speed setup ---
				#_typing_base_delay = dialogue_label.char_delay
				#_typing_speed_multiplier = 1.0
#
				## connect advance handler (only while typing)
				#var advance_handler = Callable(self, "_on_advance_during_typing")
				#if not SignalBus.advance.is_connected(advance_handler):
					#SignalBus.advance.connect(advance_handler)
#
				## await the typing animation (EventText uses dialogue_label.char_delay each loop)
				#await dialogue_label.append_line_typed(formatted)
#
				## disconnect the handler (safe even if it was triggered)
				#if SignalBus.advance.is_connected(advance_handler):
					#SignalBus.advance.disconnect(advance_handler)
#
				## restore base delay and multiplier
				#dialogue_label.char_delay = _typing_base_delay
				#_typing_speed_multiplier = 1.0
#
				## Wait for user advance (or auto advance)
				#if not auto_advance:
					#await SignalBus.advance
				#else:
					#await get_tree().create_timer(auto_advance_delay).timeout
#
				#index += 1
				#continue
#
#
			#"choice":
				#var options = evt.get("options", [])
				#choice_label.show_options(options)
				#choice_label.visible = true
				## wait for a choice to be made
				#var sig = await choice_label.choice_chosen
				## sig is a VariantArray of args -> [index, data_dict]
				#var choice_index := int(sig[0])
				#var choice_data = sig[1] if sig.size() > 1 else {}
				#choice_label.clear_options()
				#choice_label.visible = false
#
				## Resolve next: if choice_data.next is label or index
				#if choice_data.has("next"):
					#var nxt = choice_data["next"]
					#if typeof(nxt) == TYPE_STRING:
						#index = _find_next_valid_event(nxt)
					#elif typeof(nxt) in [TYPE_INT, TYPE_FLOAT]:
						#index = int(nxt)
					#else:
						#index += 1
#
				#else:
					## fallback: insert events (if provided) next inline
					#if choice_data.has("events") and typeof(choice_data["events"]) == TYPE_ARRAY:
						## splice events after current index
						#var to_insert = choice_data["events"]
						#timeline = timeline.slice(0, index+1) + to_insert + timeline.slice(index+1, timeline.size())
						#index += 1
					#else:
						#index += 1
				#continue
#
			#"input":
				## generic input: will store into GameData.variables[key]
				#var prompt = evt.get("prompt", "")
				#var key = evt.get("var", "user_input")
				#var default = evt.get("default", "")
				## show prompt as dialogue line (optional)
				#if prompt != "":
					#await dialogue_label.append_line_typed(_format_text(prompt))
				## request inline input
				#input_box.request_input(default)
				#input_box.visible = true
				## wait for input_box.submitted
				#var value = await input_box.submitted
				#GameData.variables[key] = value
				## optionally emit via SignalBus
				#SignalBus.input_submitted.emit(key, value)
				#input_box.visible = false
				#index += 1
				#continue
#
			#"signal":
				#SignalBus.external_signal.emit(evt.get("name", ""))
				#index += 1
				#continue
#
			#"action":
				## placeholder for actions (play animation, etc.)
				#index += 1
				#continue
				#
			#"set":
				#var writes = []
#
				## Single write shorthand
				#if evt.has("path"):
					#writes.append({
						#"path": evt.get("path"),
						#"value": evt.get("value", null),
						#"if": evt.get("if", null),
						#"op": evt.get("op", "")
					#})
				## Multi-write block
				#elif evt.has("writes"):
					#writes = evt["writes"]
				#else:
					#push_warning("Set event missing 'path' or 'writes' field.")
					#index += 1
					#continue
#
				#for w in writes:
					#var condition = w.get("if", null)
					#if condition != null and condition != "":
						#if not _evaluate_condition(condition):
							#continue  # Skip this write if condition fails
#
					#var path = w.get("path", "")
					#if path == "":
						#push_warning("Skipped set: missing path.")
						#continue
#
					#var value_expr = w.get("value", null)
					#var op = w.get("op", "")
#
					#var final_value = value_expr
					#if typeof(value_expr) == TYPE_STRING:
						#var expression := Expression.new()
						#if expression.parse(value_expr, ["GameData"]) == OK:
							#final_value = expression.execute([GameData])
							#if expression.has_execute_failed():
								#push_error("❌ Failed to evaluate value expression: %s" % value_expr)
								#continue
						#else:
							#push_warning("⚠️ Could not parse value expression: %s" % value_expr)
#
					#_set_game_data_value(path, final_value, op)
#
				#index += 1
				#continue
				#
			#"resource":
				#var res_path = evt.get("path", "")
				#if res_path == "":
					#push_warning("⚠️ Resource event missing path.")
					#index += 1
					#continue
#
				## Optional condition
				#var condition = evt.get("if", "")
				#if condition != "" and not _evaluate_condition(condition):
					#index += 1
					#continue
#
				## Load the resource
				#var res = load(res_path)
				#if res == null:
					#push_error("❌ Failed to load resource: %s" % res_path)
					#index += 1
					#continue
#
				#var result = null
				#var method = evt.get("method", "")
				#var args = []
				#var raw_args = evt.get("args", [])
#
				## Resolve arguments (allow expressions or GameData references)
				#for a in raw_args:
					#if typeof(a) == TYPE_STRING and a.begins_with("GameData."):
						#var expr := Expression.new()
						#if expr.parse(a, ["GameData"]) == OK:
							#args.append(expr.execute([GameData]))
						#else:
							#args.append(a)
					#else:
						#args.append(a)
#
				## === AUTO-DETECTION ===
				#if res is ActionResource:
					## Default: apply the action to GameData.player_stats
					#if method == "":
						#method = "apply"
						#args = [GameData.player_stats, evt.get("duration", 1)]
				#elif res is JobResource:
					## If it's a job, you can check qualifications or compute earnings
					#if method == "":
						#method = "is_qualified"
						#args = [GameData.player_stats]
#
				## === EXECUTION ===
				#if method != "" and res.has_method(method):
					#result = res.callv(method, args)
				#else:
					#push_warning("⚠️ Resource %s has no callable method '%s'" % [res_path, method])
#
				## === STORE RESULT ===
				#if evt.has("assign_to"):
					#var assign_path = evt["assign_to"]
					#_set_game_data_value(assign_path, result)
#
				### === Optional async wait (future support) ===
				##if evt.has("await") and evt["await"]:
					##if result is GDScriptFunctionState:
						##await result
#
				#index += 1
				#continue
#
#
			#"end":
				## Optional custom text for [End] message
				#var end_text = evt.get("text", "[End]")
				#await dialogue_label.append_line_typed(end_text)
#
				## Custom exit choice text (fallback to exported var)
				#var exit_choice = evt.get("exit_text", end_choice_text)
#
				## Show a final choice that acts as the exit confirmation
				#choice_label.show_options([{ "text": exit_choice, "next": null }])
				#choice_label.visible = true
				#await choice_label.choice_chosen
				#choice_label.clear_options()
				#choice_label.visible = false
#
				## Emit dialogue_finished for logic chaining (optional next timeline)
				#if SignalBus.has_signal("dialogue_finished"):
					#SignalBus.dialogue_finished.emit()
#
				## Wait a moment, then animate and end the timeline
				#await _animate_timeline_end()
				#if SignalBus.has_signal("timeline_ended"):
					#SignalBus.timeline_ended.emit()
				#break
#
			#_:
				#push_warning("Unknown event type: %s" % t)
				#index += 1
				#continue
#
	## runner finished
	#_running = false
	#return
#
#func _evaluate_condition(expr: String) -> bool:
	#if expr == "" or expr == null:
		#return true
	#var expression := Expression.new()
	#var result := expression.parse(expr, ["GameData"])
	#if result != OK:
		#push_error("❌ Condition parse error: %s" % expr)
		#return false
	#var value = expression.execute([GameData])
	#if expression.has_execute_failed():
		#push_error("❌ Condition execution failed for: %s" % expr)
		#return false
	#return bool(value)
#
#func _find_next_valid_event(target_id: String) -> int:
	#for i in range(timeline.size()):
		#var e = timeline[i]
		#if typeof(e) == TYPE_DICTIONARY and e.get("id", "") == target_id:
			#if not e.has("condition") or _evaluate_condition(e["condition"]):
				#return i
	#return index + 1
#
#func _animate_timeline_end() -> void:
	#var tween := create_tween()
	#tween.tween_property(self, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	#await tween.finished
	#queue_free()  # safely remove panel after fade
#
#
## format text with variables (live)
#func _format_text(text: String) -> String:
	#for k in GameData.variables.keys():
		#text = text.replace("{%s}" % k, str(GameData.variables[k]))
	#return text
#
#
#func _on_autoplay_toggled(pressed: bool):
	#auto_advance = pressed
	#
## handler called when advance is pressed DURING typing
#func _on_advance_during_typing() -> void:
	## double speed each time and update dialogue_label.char_delay
	#_typing_speed_multiplier *= 2.0
	## clamp multiplier to a reasonable max; when reached, force-complete
	#if _typing_speed_multiplier >= _MAX_MULTIPLIER:
		#dialogue_label.skip_current_typing()
		#return
#
	## set new per-character delay (smaller delay => faster typing)
	#dialogue_label.char_delay = _typing_base_delay / _typing_speed_multiplier
#
#func _set_game_data_value(path: String, value, op: String = "") -> void:
	#var parts = path.split(".")
	#if parts.is_empty():
		#return
#
	#var obj = GameData
	#for i in range(parts.size() - 1):
		#var key = parts[i]
		#if not obj.has(key):
			#push_error("Invalid GameData path: %s" % path)
			#return
		#obj = obj.get(key)
#
	#var last_key = parts[-1]
	#if not obj.has(last_key):
		#push_error("GameData missing key: %s" % last_key)
		#return
#
	#match op:
		#"add":
			#obj[last_key] += value
		#"sub":
			#obj[last_key] -= value
		#_:
			#obj[last_key] = value
#
	#if SignalBus.has_signal("game_data_changed"):
		#SignalBus.game_data_changed.emit(path, value)
