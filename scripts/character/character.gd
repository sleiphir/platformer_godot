extends CharacterBody2D

signal using_hook(Vector2)

enum Direction { NONE, LEFT, RIGHT }

const SPEED = 240.0
const JUMP_VELOCITY = -500.0
const FRICTION_COEFFICIENT = 9.0/10 # falls 3/4 of based fall speed
const JUMP_TOLERANCE_THRESHOLD = 5.0/60 # 5 frames of tolerance at 60 fps when jumping
const CAMERA_OFFSET = 120 # How much the camera puts the player off-center (positive or negative based on direction)
const HOOK_MOVEMENT_STRENGTH = Vector2(200, -200)
const HOOK_NOT_ANCHORED_MAX_DELAY = 2000 # Waits 2 seconds before stopping hook mode when not anchored
const PUSH_FORCE = 80.0 # Player inertia

@export var acceleration = 1.0
@export var hook_scene: PackedScene

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var current_direction = Direction.NONE

# Jump flags
var CAN_JUMP = true # should always be set to wether the player can jump given all the parameters
var JUMP_TOLERANCE_OVER = false # prevents jumping once _jump_timer is above JUMP_TOLERANCE_THRESHOLD
var CAN_WALL_JUMP = true # allows the player to jump once on a wall
var HAS_JUMPED = false # wether the player has jumped and cannot jump anymore

# Movement flags
var CAN_MOVE_FREELY = true # wether the player can alter it's velocity

# General flags
var IS_DEAD = false # wether the player is currently dead
var HOOK_MODE = false # wether the player is currently using the hook

# Jump tolerance timer (resets everytime the player is on the ground)
var _jump_timer = 0 # We are not using a Timer node as the value is very precise and close to 0

# Store the last jump x position to prevent wall jumping on the same wall multiple times
var last_jump_x: float = 2 << 63 - 1

# Counts the number of times the player died on a level
var death_count = 0
# Starting position to reset the player to when dying
var starting_position = Vector2.ZERO
# The player direction in the previous frame
var last_direction: Direction
# Camera offset tweener
var camera_tween: Tween
# The hook instance
var hook_instance: Node2D
# The hook anchoring timer
var hook_timer: float

func _ready():
	starting_position = position


func _physics_process(delta):
	# Do not process anything while the player is dead
	if IS_DEAD:
		return
		
	# after calling move_and_slide()
	for i in get_slide_collision_count():
		var c = get_slide_collision(i)
		if c.get_collider() is RigidBody2D:
			c.get_collider().apply_central_impulse(-c.get_normal() * PUSH_FORCE)
		
	 
	if HOOK_MODE and not is_on_floor():
		handle_hook_input(delta)
		return
		
	var has_wall_jumped = false
	
	# Add gravity
	if not is_on_floor():
		velocity.y += gravity * delta
		# Apply friction coefficient only when sliding down a wall
		if velocity.y > 0 and is_on_wall():
			velocity.y *= FRICTION_COEFFICIENT

	# Updates jump flags and set CAN_JUMP accordingly
	handle_jump(delta)
	
	# Handle jump action
	if Input.is_action_just_pressed("jump") and CAN_JUMP:
		HAS_JUMPED = true
		velocity.y = JUMP_VELOCITY
		last_jump_x = 2 << 63 - 1
		# Check if that was a wall jump
		if not is_on_floor() and CAN_WALL_JUMP:
			has_wall_jumped = true
			# Only set actual x coordinate when wall jumping
			last_jump_x = position.x
	
	# Set current direction to left or right as soon as the action is pressed
	if Input.is_action_just_pressed("move_left"):
		current_direction = Direction.LEFT
	elif Input.is_action_just_pressed("move_right"):
		current_direction = Direction.RIGHT
		
	if Input.is_action_just_pressed("use_grappling_hook"):
		if HOOK_MODE:
			stop_using_hook()
		else:
			use_hook(get_local_mouse_position())
		
	# Get input strength
	var left_force = Input.get_action_strength("move_left")
	var right_force = Input.get_action_strength("move_right")
	
	# Change direction based on input strength
	if left_force > right_force:
		current_direction = Direction.LEFT
	if right_force > left_force:
		current_direction = Direction.RIGHT
	if left_force + right_force == 0:
		current_direction = Direction.NONE
	
	var direction = 0
	match current_direction:
		Direction.RIGHT: direction = right_force
		Direction.LEFT: direction = -left_force
	
	velocity.x = direction * SPEED
	
	# Add camera tween if the player starts moving in the opposite direction
	if current_direction != last_direction:
		if camera_tween:
			camera_tween.kill()
		var offset = Vector2(0, -50)
		match current_direction:
			Direction.RIGHT: offset.x = CAMERA_OFFSET
			Direction.LEFT: offset.x = -CAMERA_OFFSET
			Direction.NONE: offset.x = $Camera.offset.x
		camera_tween = get_tree().create_tween()
		camera_tween.tween_property($Camera, "offset", offset, 1.5).set_ease(Tween.EASE_IN)
	
	# Update sprite based on direction
	if velocity.x < 0:
		$Smoothing2D/AnimatedSprite2D.flip_h = false
	else:
		$Smoothing2D/AnimatedSprite2D.flip_h = true
		
	if has_wall_jumped:
		$JumpParticles.emitting = true

	if not CAN_MOVE_FREELY:
		velocity = Vector2.ZERO
	
	move_and_slide()
	
	# Variables set at the end to be used in the next frame
	last_direction = current_direction


func handle_run(delta) -> void:
	pass


# Update jump flags and set CAN_JUMP based on the sum of the parameters
func handle_jump(delta) -> void:
	# Check if a wall jump is possible
	if is_on_wall():
		var gap = last_jump_x - position.x
		gap *= 1 if gap > 0 else -1
		CAN_WALL_JUMP = gap > 5
	elif JUMP_TOLERANCE_OVER or HAS_JUMPED:
		CAN_WALL_JUMP = false
	
	# Reset flags when on the floor
	if is_on_floor():
		HAS_JUMPED = false
		JUMP_TOLERANCE_OVER = false
		CAN_WALL_JUMP = false
		_jump_timer = 0
	# Increase jump tolerance timer when not on the floor
	else:
		_jump_timer += delta
	
	# Check jump tolerance threshold
	if _jump_timer > JUMP_TOLERANCE_THRESHOLD:
		JUMP_TOLERANCE_OVER = true
		
	CAN_JUMP = CAN_WALL_JUMP or (not JUMP_TOLERANCE_OVER and not HAS_JUMPED)


func use_hook(direction: Vector2):
	print("started using hook")
	var hook = hook_scene.instantiate()
	hook.connect_to_player($HookBase)
	hook.position = $HookBase.position + Vector2(0, -10)
	get_parent().add_child(hook)
	launch_hook(direction)
	hook_instance = hook
	HOOK_MODE = true


func launch_hook(direction: Vector2):
	print("launch hook")
	#$HookBase.apply_central_impulse(Vector2(5, -500))


func handle_hook_input(delta):
	if Input.is_action_just_pressed("use_grappling_hook"):
		stop_using_hook()
		
	hook_timer += delta
	if not hook_instance.is_anchored() and hook_timer > HOOK_NOT_ANCHORED_MAX_DELAY:
		print("hook did not connect")
		stop_using_hook()
		
	var force = Vector2.ZERO
	if Input.is_action_pressed("move_left"):
		force.x = HOOK_MOVEMENT_STRENGTH.x * -1
	elif Input.is_action_pressed("move_right"):
		force.x = HOOK_MOVEMENT_STRENGTH.x
	elif Input.is_action_just_pressed("jump"):
		force.y = HOOK_MOVEMENT_STRENGTH.y
		
	velocity.y += gravity * delta
		
	#$HookBase.apply_central_force(force)
	move_and_slide()

func stop_using_hook():
	hook_instance.queue_free()
	HOOK_MODE = false
	$HookBase.position = position
	print("stopped using hook")


func die(body):
	IS_DEAD = true
	CAN_MOVE_FREELY = false
	if is_instance_valid(hook_instance):
		hook_instance.queue_free()
	HOOK_MODE = false
	death_count += 1
	velocity = Vector2.ZERO
	scale = Vector2.ZERO
	$JumpParticles.emitting = true
	await get_tree().create_timer(.75).timeout
	position = starting_position
	revive()


func revive():
	await get_tree().create_timer(.3).timeout
	CAN_MOVE_FREELY = true
	IS_DEAD = false
	scale = Vector2.ONE
