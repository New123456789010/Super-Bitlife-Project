extends PanelContainer
@onready var newspaper: TextureRect = $MarginContainer/HBoxContainer/PanelContainer/VBoxContainer/MarginContainer/VBoxContainer/Newspaper
@onready var apply_job: Button = $MarginContainer/HBoxContainer/PanelContainer/VBoxContainer/MarginContainer2/PanelContainer/ApplyJob

var dock_worker_description = """[center][b]⚓ Dock Worker[/b][/center]

[b]Summary:[/b]
Tough, tireless laborers who keep the harbor running. They haul cargo, secure ships, and fend off trouble when it comes ashore.

[i]"The tide waits for no one. Move fast or get left behind."[/i]

[b]Pay & Shifts:[/b]
• [b]Wage:[/b] 15 gold/hour  
• [b]Shifts:[/b] 6am–2pm / 2pm–10pm (rotating weekly)  
• [b]Overtime:[/b] Available during storm season or pirate raids

[b]Traits:[/b]
• [i]Salt-Hardened[/i]: Resists cold/water effects  
• [i]Dockside Brawler[/i]: Bonus unarmed damage near water
"""

var store_clerk_description = """[center][b]🛒 Store Clerk[/b][/center]

[b]Summary:[/b]
Friendly and sharp-eyed, Store Clerks manage inventory, assist customers, and keep the shop running smoothly. Ideal for those with a knack for numbers and a silver tongue.

[i]"You break it, you buy it. And yes, I saw you break it."[/i]

[b]Pay & Shifts:[/b]
• [b]Wage:[/b] 10 gold/hour  
• [b]Shifts:[/b] 9am–5pm / 12pm–8pm (flexible scheduling)  
• [b]Bonuses:[/b] Commission on rare item sales

[b]Traits:[/b]
• [i]Quick Counter[/i]: +2 to inventory management rolls  
• [i]Customer Charm[/i]: Improved persuasion with NPCs
"""


@onready var job_text: RichTextLabel = $MarginContainer/HBoxContainer/PanelContainer/VBoxContainer/MarginContainer/VBoxContainer/RichTextLabel
var default_text: String

var jobs := [
	dock_worker_description,
	store_clerk_description,
]
var current_idx := 0

func _ready() -> void:
	default_text = job_text.text

func start() -> void:
	apply_job.visible = true
	newspaper.visible = false

func _on_forward_button_pressed() -> void:
	start()
	current_idx = (current_idx + 1) % jobs.size()
	job_text.text = jobs[current_idx]

func _on_back_button_pressed() -> void:
	start()
	current_idx = (current_idx - 1 + jobs.size()) % jobs.size()
	job_text.text = jobs[current_idx]


func _on_option_3_pressed() -> void:
	job_text.text = default_text
	apply_job.visible = false
	newspaper.visible = true
	self.hide()


func _on_apply_job_pressed() -> void:
	apply_job.disabled = true                # prevent extra clicks
	apply_job.text = "Applied (3)"           # starting text
	# Countdown from 3 to 1
	for i in range(2, -1, -1):                # 2,1,0
		await get_tree().create_timer(1.0).timeout
		if i > 0:
			apply_job.text = "Applied (" + str(i) + ")"
		else:
			apply_job.text = "Applied"
	hide()    # or queue_free() if you want to remove the whole node
