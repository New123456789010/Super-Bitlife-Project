extends Node2D

@export var map_width: int = 512
@export var map_height: int = 512
@export var noise_scale: float = 0.01
@export var seed: int = 1234
@export var octaves: int = 4
@export var lacunarity: float = 2.0
@export var gain: float = 0.5

var noise: FastNoiseLite
var density_image: Image
var density_texture: ImageTexture
