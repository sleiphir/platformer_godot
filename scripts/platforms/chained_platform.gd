extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func platform_impulse(vec: Vector2) -> void:
	$platform.apply_central_impulse(vec)
