extends Panel
class_name DialogueController

@export var event_text: EventText
@export var choice_label: ChoiceLabel
@export var input_line: LineEdit

var variables := {}

func _ready() -> void:
	if not choice_label.is_connected("choice_chosen", Callable(self, "_on_choice_chosen")):
		choice_label.choice_chosen.connect(Callable(self, "_on_choice_chosen"))

	input_line.text_submitted.connect(Callable(self, "_on_input_submitted"))
	input_line.visible = false

	call_deferred("_start_demo")

# -------------------------
# Demo flow with input
# -------------------------
func _start_demo() -> void:
	await event_text.append_line_typed("weird_cat: Let's test text input now…")
	await event_text.append_line_typed("weird_cat: What's your secret password?")

	# request input for variable "secret_code"
	request_input("secret_code", "1234")

# -------------------------
# Input handling
# -------------------------
func request_input(var_name: String, default_val: String = "") -> void:
	variables[var_name] = default_val
	input_line.text = default_val
	input_line.visible = true
	input_line.grab_focus()

func _on_input_submitted(new_text: String) -> void:
	# hide input
	input_line.visible = false

	var var_name := "secret_code"  # later, this will come from the timeline
	variables[var_name] = new_text

	# mirror back the player's response with typing animation
	await event_text.append_line_typed("you: " + new_text)

	# continue demo with smooth typing
	if new_text != "3.14159":
		await event_text.append_line_typed("weird_cat: Hmm… that’s not the magic number I was expecting.")
	else:
		await event_text.append_line_typed("weird_cat: Whoa! You cracked the code! 🐱")

	await event_text.append_line_typed("⚡ End of demo with input.")

#extends Panel
#class_name DialogueController
#
#@export var event_text: EventText
#@export var choice_label: ChoiceLabel
#
#func _ready() -> void:
	## Ensure the signal is connected once
	#if not choice_label.is_connected("choice_chosen", Callable(self, "_on_choice_chosen")):
		#choice_label.choice_chosen.connect(Callable(self, "_on_choice_chosen"))
	## start demo after ready
	#call_deferred("_start_demo")
#
## -------------------------
## Simple demo flow
## -------------------------
#func _start_demo() -> void:
	#await event_text.append_line_typed("weird_cat: Yo! Welcome to your new house. It's a bit bare, but I'm sure you'll cozy it up in no time.")
	#await event_text.append_line_typed("weird_cat: Make sure you’ve got enough for rent, utilities, food, phone, etc.")
	#await event_text.append_line_typed("weird_cat: So… what do you want to do first?")
#
	#var opts := [
		#{
			#"text": "Unpack your stuff",
			#"results": [
				#"you: I'll start unpacking.",
				#"weird_cat: Nice! Let's make the place feel like home."
			#]
		#},
		#{
			#"text": "Take a nap",
			#"results": [
				#"you: I need a quick nap.",
				#"weird_cat: Already tired? Fair enough, moving is exhausting."
			#]
		#},
		#{
			#"text": "Go outside",
			#"results": [
				#"you: I'll go get some fresh air.",
				#"weird_cat: Fresh air is always a good idea!"
			#]
		#}
	#]
#
	#choice_label.show_options(opts)
	## wait for user click — flow continues in _on_choice_chosen
	#return
#
## -------------------------
## Choice handling
## -------------------------
#func _on_choice_chosen(index: int) -> void:
	#var opt = choice_label.options[index]
	## clear UI choices
	#choice_label.clear_options()
#
	## play branch results
	#if opt.has("results"):
		#for line in opt["results"]:
			#await event_text.append_line_typed(line)
#
	## continue the conversation
	#await event_text.append_line_typed("weird_cat: Alright — that's settled. Let's move on.")
	#await event_text.append_line_typed("⚡ End of demo.")
