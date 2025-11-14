extends Camera2D

@export var min_zoom := 0.5
@export var max_zoom := 3.0
@export var zoom_speed := 0.1
@export var drag_enabled := true

var dragging := false
var last_mouse_pos := Vector2.ZERO
var touch_positions := {}
var last_pinch_distance = null

func _ready() -> void:
	make_current()

func _unhandled_input(event: InputEvent) -> void:
	# --- Mouse Scroll Zoom ---
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_toward(get_viewport().get_mouse_position(), 1.0 - zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_toward(get_viewport().get_mouse_position(), 1.0 + zoom_speed)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			last_mouse_pos = get_viewport().get_mouse_position()

	# --- Mouse Drag Pan ---
	elif event is InputEventMouseMotion and dragging and drag_enabled:
		var delta = event.relative
		position -= delta * zoom

	# --- Touch Input ---
	elif event is InputEventScreenTouch:
		if event.pressed:
			touch_positions[event.index] = event.position
		else:
			touch_positions.erase(event.index)

	elif event is InputEventScreenDrag:
		touch_positions[event.index] = event.position

	if touch_positions.size() == 2:
		handle_pinch_zoom()

func zoom_toward(screen_pos: Vector2, factor: float) -> void:
	var world_before := to_global(screen_pos)
	var new_zoom := zoom * factor
	new_zoom.x = clamp(new_zoom.x, min_zoom, max_zoom)
	new_zoom.y = clamp(new_zoom.y, min_zoom, max_zoom)
	zoom = new_zoom
	var world_after := to_global(screen_pos)
	position += world_before - world_after

func handle_pinch_zoom() -> void:
	var keys := touch_positions.keys()
	var pos1 = touch_positions[keys[0]]
	var pos2 = touch_positions[keys[1]]
	var current_distance = pos1.distance_to(pos2)

	if last_pinch_distance != null:
		var delta = current_distance - last_pinch_distance
		var factor = 1.0 - delta * zoom_speed * 0.01
		var midpoint = (pos1 + pos2) * 0.5
		zoom_toward(midpoint, factor)

	last_pinch_distance = current_distance
