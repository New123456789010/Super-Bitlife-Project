extends RichTextLabel
class_name EventText

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	bbcode_enabled = true
	for _i in range(20):
		append_text("\n")

func add_t(t: String) -> void:
	append_text(t + "\n")
	_scroll_to_bottom()

func _scroll_to_bottom(duration: float = 0.5):
	call_deferred("_scroll_later", duration)

func _scroll_later(duration: float):
	var scroll = get_v_scroll_bar()
	var tween = create_tween()
	tween.tween_property(scroll, "value", scroll.get_max(), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


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
