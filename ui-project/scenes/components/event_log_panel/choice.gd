extends RichTextLabel
class_name ChoiceLabel

signal choice_chosen(index: int)

var options: Array = []

func _ready() -> void:
	bbcode_enabled = true
	# meta_clicked fires when a [url=meta] tag is clicked
	meta_clicked.connect(Callable(self, "_on_meta_clicked"))

# opts = [ { "text": "Option A", "results": ["line1","line2"] }, ... ]
func show_options(opts: Array) -> void:
	options = opts
	clear()
	self.bbcode_enabled = true
	for i in range(options.size()):
		var opt = options[i]
		# append_bbcode so [url=...] is parsed as BBCode
		append_text("[url=%d]%d. %s[/url]\n" % [i, i+1, opt.get("text", "")])

func clear_options() -> void:
	options = []
	clear()

func _on_meta_clicked(meta) -> void:
	# meta comes as string; convert to index
	var idx := int(meta)
	if idx >= 0 and idx < options.size():
		emit_signal("choice_chosen", idx)



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
