extends RichTextLabel
class_name EventText

@export var char_delay: float = 0.02  # seconds per character

var _lines: Array = []
var _is_typing: bool = false
var _skip_typing: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	bbcode_enabled = false
	clear()
	_lines.clear()

func _build_display_text(buffer: String) -> String:
	if _lines.size() == 0:
		return buffer
	if buffer == "":
		return String("\n").join(_lines)
	return String("\n").join(_lines) + "\n" + buffer

func clear_history() -> void:
	_lines.clear()
	text = ""
	_scroll_to_bottom()

func append_line_instant(line: String) -> void:
	_lines.append(line)
	text = _build_display_text("")
	_scroll_to_bottom()

func append_line_typed(line: String) -> void:
	# Ensure only one typing loop at a time
	if _is_typing:
		_skip_typing = true
		await get_tree().process_frame
	_is_typing = true
	_skip_typing = false

	var buffer := ""
	for c in line:
		if _skip_typing:
			buffer = line
			text = _build_display_text(buffer)
			_scroll_to_bottom()
			break
		buffer += String(c)
		text = _build_display_text(buffer)
		_scroll_to_bottom()
		await get_tree().create_timer(char_delay).timeout

	_lines.append(line)
	text = _build_display_text("")
	_scroll_to_bottom()

	_is_typing = false
	_skip_typing = false

func skip_current_typing() -> void:
	if _is_typing:
		_skip_typing = true

func _scroll_to_bottom() -> void:
	var sb := get_v_scroll_bar()
	if sb:
		sb.value = sb.max_value
