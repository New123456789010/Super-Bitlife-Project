extends Button

@export var button_texture : Texture

@onready var texture_rect: TextureRect = $MarginContainer/TextureRect

func _ready() -> void:
	texture_rect.texture = button_texture
