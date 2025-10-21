extends Node2D

func _ready() -> void:
	#initialize and trigger citygen, heatmap
	#request queue_redraw() 
	_draw()

func _draw() -> void:
	var start := get_random_vector2(100, 100, 500, 500)
	var end := get_random_vector2(100, 500, 500, 100)
	draw_line(start, end, Color.AQUA)

func get_random_vector2(min_x: float, max_x: float, min_y: float, max_y: float) -> Vector2:
	var x = randf_range(min_x, max_x)
	var y = randf_range(min_y, max_y)
	return Vector2(x, y)
