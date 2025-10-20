# Hydrology.gd (sketch)
extends Node

func generate_river(H:Image, W:Image, mouth_point:Vector2, seed:int) -> Array:
	# find mountain source candidates
	var sources = find_points_with_height(H, 0.7)
	var source = choose_source_closest_directional(sources, mouth_point)
	# perform A* on grid (coarse resolution ok)
	var path = astar_grid_path(H, source, mouth_point)
	# place lake at deepest basin along path midpoint
	var lake_center = find_basin_center(H, path)
	fill_lake(H, W, lake_center, radius)
	# mark river polyline and lower H slightly along path
	return path
