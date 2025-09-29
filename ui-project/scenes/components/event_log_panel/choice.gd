extends RichTextLabel
class_name Choice
signal choice_selected(index: int)

func _ready() -> void:
	bbcode_enabled = true
	meta_clicked.connect(_on_choice_clicked)

func show_choices(choices: Array) -> void:
	clear()
	for i in range(choices.size()):
		append_text("[url=%d]%d. %s[/url]\n" % [i, i+1, choices[i].get("text", "")])

func _on_choice_clicked(meta):
	if typeof(meta) == TYPE_INT:
		emit_signal("choice_selected", meta)
	clear()



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
