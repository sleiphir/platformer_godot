extends Node2D

const INITIAL_FORCE_APPLIED = 500 # the amount of force applied initally to the platform to make it move


# Called when the node enters the scene tree for the first time.
func _ready():
	platform_impulse(Vector2(INITIAL_FORCE_APPLIED * randf_range(-1,1), 0))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func platform_impulse(vec: Vector2) -> void:
	$platform.apply_central_impulse(vec)
