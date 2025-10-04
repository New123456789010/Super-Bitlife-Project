extends LineEdit
class_name InlineInput

signal submitted(value: String)

func _ready() -> void:
	visible = false
	focus_mode = Control.FOCUS_ALL
	text = ""
	# connect text_submitted to our handler if you want to use that instead
	text_submitted.connect(Callable(self, "_on_submitted"))

func request_input(default_text: String = "") -> void:
	text = default_text
	visible = true
	grab_focus()
	caret_column = text.length()

func _on_submitted(value: String) -> void:
	visible = false
	release_focus()
	emit_signal("submitted", value)

# Also allow pressing enter via _gui_input (optional)
func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		visible = false
		release_focus()
		emit_signal("submitted", text)
