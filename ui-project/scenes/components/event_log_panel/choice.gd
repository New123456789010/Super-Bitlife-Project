extends RichTextLabel
class_name ChoiceLabel

signal choice_chosen(index: int, data: Dictionary)

var options: Array = []

func _ready() -> void:
	bbcode_enabled = true
	meta_clicked.connect(Callable(self, "_on_meta_clicked"))

func show_options(opts: Array) -> void:
	options = opts.duplicate(true)
	clear()
	bbcode_enabled = true
	# Render options as [url=index] so meta contains the index
	for i in range(options.size()):
		var opt = options[i]
		append_text("[url=%d]%d. %s[/url]\n" % [i, i+1, opt.get("text", "")])
	_scroll_to_bottom()

func clear_options() -> void:
	options.clear()
	clear()

func _on_meta_clicked(meta) -> void:
	var idx := int(meta)
	if idx >= 0 and idx < options.size():
		emit_signal("choice_chosen", idx, options[idx])
		
func _scroll_to_bottom() -> void:
	var scroll: ScrollBar = get_v_scroll_bar()
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(scroll.set_value, scroll.get_value(), scroll.get_max(), 0.35)

#extends RichTextLabel
#
#func _ready() -> void:
	#mouse_filter = Control.MOUSE_FILTER_STOP
	#bbcode_enabled = true
	#connect("meta_clicked", Callable(self, "_on_choice_selected"))
#
#func on_option() -> void:
	#pass
#
#func _on_choice_selected(meta: Variant) -> void:
	## Forward to parent Panel
	#if get_parent().has_method("_on_choice_selected"):
		#get_parent()._on_choice_selected(meta)


#extends RichTextLabel
#
#func _ready() -> void:
	#self.bbcode_enabled = true
	##connect("meta_clicked", %EventText.add_t)
	#connect("meta_clicked", Callable(self, "_on_choice_selected"))
	#
	#text = ""  # start empty
	#on_option()
	#return
#
#func on_option() -> void:
	#pass
	##for i in range(1, 5):
		##text += "[url]%d. %s[/url]\n" % [i, "Option"]
	##return
#
#func _on_choice_selected(meta: Variant) -> void:
	#Dialogic.choice_selected(int(meta))
