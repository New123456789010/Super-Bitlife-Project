extends RichTextLabel
class_name EventText

@export var char_delay: float = 0.02  # seconds per character

var _lines: Array = []
var _is_typing: bool = false
var _skip_typing: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	bbcode_enabled = true
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

func append_line_typed(line: String) -> void:
	if _is_typing:
		_skip_typing = true
		await get_tree().process_frame
	_is_typing = true
	_skip_typing = false

	# Ensure BBCode is enabled so images display
	bbcode_enabled = true

	# Tokenize: treat [tag ...] and [/tag] and [img]...[/img] as single tokens
	var tokens := []
	var i := 0
	while i < line.length():
		if line[i] == "[":
			# find the matching closing ']' for this tag start
			var j := line.find("]", i)
			if j == -1:
				# malformed, treat rest as plain text
				tokens.append(line.substr(i, line.length() - i))
				break
			var tag_text = line.substr(i, j - i + 1)
			# if it's a standalone [img] tag, capture until [/img]
			if tag_text.begins_with("[img]"):
				var end_img = line.find("[/img]", j + 1)
				if end_img != -1:
					var full_img = line.substr(i, end_img + 6 - i) # include [/img]
					tokens.append(full_img)
					i = end_img + 6
					continue
			# otherwise add the tag token
			tokens.append(tag_text)
			i = j + 1
		else:
			# normal chars — append single char as token for fine-grained typing
			tokens.append(line.substr(i, 1))
			i += 1

	var buffer := ""
	for token in tokens:
		if _skip_typing:
			buffer = line
			text = _build_display_text(buffer)
			_scroll_to_bottom()
			break

		# If token is an [img]...[/img] or any full tag, append it immediately (don't animate internal chars)
		if token.begins_with("[") and token.ends_with("]") or token.begins_with("[img]"):
			buffer += token
			text = _build_display_text(buffer)
			_scroll_to_bottom()
			# slight pause for tag render (optional)
			await get_tree().create_timer(char_delay).timeout
		else:
			# normal single character
			buffer += token
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
