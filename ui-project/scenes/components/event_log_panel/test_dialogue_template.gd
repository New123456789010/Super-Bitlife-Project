extends RichTextLabel
class_name EventText

@export var char_delay: float = 0.02  # seconds per character

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	bbcode_enabled = false
	clear()

# instant append + scroll
func append_line_instant(line: String) -> void:
	append_text(line + "\n")
	_scroll_to_bottom()

# typed append (awaitable because it awaits a Timer internally)
func append_line_typed(line: String) -> void:
	for c in line:
		append_text(String(c))
		_scroll_to_bottom()
		await get_tree().create_timer(char_delay).timeout
	append_text("\n")
	_scroll_to_bottom()

func _scroll_to_bottom() -> void:
	var sb := get_v_scroll_bar()
	if sb:
		sb.value = sb.max_value



#func _scroll_to_bottom() -> void:
	#var scroll: ScrollBar = get_v_scroll_bar()
	#var tween: Tween = create_tween()
	#tween.set_ease(Tween.EASE_IN_OUT)
	#tween.tween_method(scroll.set_value, scroll.get_value(), scroll.get_max(), 0.35)



#extends RichTextLabel
#
#func _ready() -> void:
	#mouse_filter = Control.MOUSE_FILTER_PASS
	#for _i in range(20):
		#text += "\n"
	#return
	#
#func on_option() -> void:
	#var tween: Tween = create_tween()
	#tween.set_ease(Tween.EASE_IN_OUT)
	#var scroll: ScrollBar = get_v_scroll_bar()
	#var v: float = scroll.get_value()
	#var m: float = scroll.get_max()
	#tween.tween_method(scroll.set_value, v, m, 0.55)
	#return
#
#func add_t(t: String) -> void:
	#text += t + '\n' 
	#on_option()
	#return
