extends PanelContainer
class_name ActionBlock

@export var action: ActionResource
@export var action_name: String = ""

@onready var icon: TextureRect = $VBoxContainer/TextureRect
@onready var label: Label = $VBoxContainer/Label

var _press_time: float = 0.0
const LONG_PRESS_THRESHOLD := 0.5

var _shake_tween: Tween = null

func _ready() -> void:
	label.text = action_name if action_name != "" else (action.name if action else "")
	if action and action.icon:
		icon.texture = action.icon

	mouse_filter = Control.MOUSE_FILTER_STOP

	# Connect to global signal
	GameData.removal_mode_changed.connect(_on_removal_mode_changed)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_time = Time.get_ticks_msec() / 1000.0
		else:
			_handle_release()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_press_time = Time.get_ticks_msec() / 1000.0
		else:
			_handle_release()

func _handle_release() -> void:
	var duration := (Time.get_ticks_msec() / 1000.0) - _press_time
	if duration >= LONG_PRESS_THRESHOLD:
		_toggle_global_removal_mode()
	elif GameData.removal_mode:
		_remove_self()

func _get_drag_data(_pos: Vector2) -> Dictionary:
	var preview := _make_drag_preview()
	set_drag_preview(preview)
	return {"type": "action_block", "block": self}

func _toggle_global_removal_mode() -> void:
	GameData.toggle_removal_mode()

func _on_removal_mode_changed(enabled: bool) -> void:
	if enabled:
		_start_shake()
	else:
		_stop_shake()

func _remove_self() -> void:
	var p = get_parent()
	if p:
		p.remove_child(self)
	queue_free()

# ---------- Shake ----------
func _start_shake() -> void:
	_stop_shake()
	_shake_tween = create_tween()
	var amplitude := 6.0
	var speed := 0.06
	_shake_tween.tween_property(self, "rotation_degrees", amplitude, speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_shake_tween.tween_property(self, "rotation_degrees", -amplitude, speed * 2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_shake_tween.tween_property(self, "rotation_degrees", 0.0, speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_shake_tween.tween_interval(0.04)
	_shake_tween.connect("finished", Callable(self, "_on_shake_finished"))

func _on_shake_finished() -> void:
	if GameData.removal_mode:
		_start_shake()
	else:
		_stop_shake()

func _stop_shake() -> void:
	if _shake_tween:
		_shake_tween.kill()
		_shake_tween = null
	rotation_degrees = 0.0

# ---------- Execution ----------
func execute_action() -> void:
	if action:
		print("   ⏳ Executing action:", action.name)
		action.apply(GameData.player_stats)
		print("Player Stats after action: ",
			"💪", GameData.player_stats.strength,
			" 🧠", GameData.player_stats.intelligence,
			" 😎", GameData.player_stats.charisma,
			" ⚡", GameData.player_stats.energy
		)
	else:
		print("   ⏳ Executing action:", action_name)

func _make_drag_preview() -> Control:
	var p := Label.new()
	p.text = action_name if action_name != "" else (action.name if action else "?")
	p.custom_minimum_size = Vector2(120, 40)
	return p


#extends PanelContainer
#
#class_name ActionBlock
#
#@export var action: ActionResource
#
#@onready var icon: TextureRect = $VBoxContainer/TextureRect
#@onready var label: Label = $VBoxContainer/Label
#@export var action_name: String = ""
#
## Global removal mode shared across all ActionBlocks
#static var removal_mode: bool = false
#signal removal_mode_changed(enabled: bool)
#
#var _press_time: float = 0.0
#const LONG_PRESS_THRESHOLD := 0.5
#
#func _ready():
	#label.text = action_name
	## Ensure this control receives mouse events
	#mouse_filter = Control.MOUSE_FILTER_STOP
	#
	#ActionBlock.removal_mode_changed.connect(_on_removal_mode_changed)
	#
#
#func _gui_input(event: InputEvent) -> void:
	#if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		#if event.pressed:
			#_press_time = Time.get_ticks_msec() / 1000.0
		#else:
			#var duration := (Time.get_ticks_msec() / 1000.0) - _press_time
			#if duration >= LONG_PRESS_THRESHOLD:
				#_toggle_global_removal_mode()
			#elif ActionBlock.removal_mode:
				#_remove_self()
#
#
## Called by Godot when the user starts dragging this Control
#func _get_drag_data(_pos: Vector2) -> Dictionary:
	#var preview := _make_drag_preview()
	#preview.text = action_name
	#set_drag_preview(preview)
	## Return a reference to self so ScheduleTrack can reorder
	#return {"type": "action_block", "block": self}
	#
#
#func _toggle_global_removal_mode() -> void:
	#ActionBlock.removal_mode = !ActionBlock.removal_mode
	## Notify all blocks
	#ActionBlock.removal_mode_changed.emit(ActionBlock.removal_mode)
	#
#
#func _on_removal_mode_changed(enabled: bool) -> void:
	#if enabled:
		#_start_shake()
	#else:
		#_stop_shake()
#
#func _remove_self() -> void:
	#var parent := get_parent()
	#if parent:
		#parent.remove_child(self)
	#queue_free()
#
#func _start_shake() -> void:
	#tween.stop_all()
	#rotation_degrees = 0
#
	#var amplitude := 4.0
	#var speed := 0.1
	#tween.tween_property(self, "rotation_degrees", amplitude, speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	#tween.tween_property(self, "rotation_degrees", -amplitude, speed * 2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	#tween.tween_property(self, "rotation_degrees", 0.0, speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	#tween.set_loops()
#
#func _stop_shake() -> void:
	#tween.stop_all()
	#rotation_degrees = 0
#
#func execute_action():
	## placeholder: replace with stat changes / trigger events / animations late.
	#if action:
		#print("   ⏳ Executing action:", action_name)
		#action.apply(GameData.player_stats)
		#print("Player Stats after action: ",
				#"💪", GameData.player_stats.strength,
				#" 🧠", GameData.player_stats.intelligence,
				#" 😎", GameData.player_stats.charisma,
				#" ⚡", GameData.player_stats.energy
#)
#
#func _make_drag_preview() -> Control:
	#var p := Label.new()
	#p.text = action_name
	#p.custom_minimum_size = Vector2(120, 40)
	#return p
