extends CharacterBody2D

signal using_hook(Vector2)

enum Direction { NONE, LEFT, RIGHT }

const SPEED = 240.0
const JUMP_VELOCITY = -500.0
const FRICTION_COEFFICIENT = 9.0/10 # falls 90% of base fall speed
const JUMP_TOLERANCE_THRESHOLD = 3.0/60 # 5 frames of tolerance at 60 fps when jumping
const CAMERA_OFFSET = 80 # How much the camera puts the player off-center (positive or negative based on direction)
const CAMERA_TWEEN_SPEED = 0.5 # Speed in seconds at which the camera tweening executes
const PUSH_FORCE = 120.0 # Player inertia

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# Jump flags
var CAN_JUMP = true # should always be set to wether the player can jump given all the parameters
var JUMP_TOLERANCE_OVER = false # prevents jumping once jump_timer is above JUMP_TOLERANCE_THRESHOLD
var CAN_WALL_JUMP = true # allows the player to jump once on a wall
var HAS_JUMPED = false # wether the player has jumped and cannot jump anymore

# Movement flags
var CAN_MOVE_FREELY = true # wether the player can alter it's velocity

# General flags
var IS_DEAD = false # wether the player is currently dead

# Jump tolerance timer (resets everytime the player is on the ground)
var jump_timer = 0 # We are not using a Timer node as the value is very precise and close to 0

# Store the last jump x position to prevent wall jumping on the same wall multiple times
var last_jump_x: float = INF
# The player direction in the current frame
var current_direction = Direction.NONE
# Counts the number of times the player died on a level
var death_count = 0
# Starting position to reset the player to when dying
var starting_position = Vector2.ZERO
# The player direction in the previous frame
var last_direction: Direction
# Camera offset tweener
var camera_tween: Tween


func _ready():
	starting_position = position


func _physics_process(delta):
	# Do not process anything while the player is dead
	if IS_DEAD:
		return

	# Handle jump action
	handle_jump(delta)
	
	# Handle movement actions and modify the velocity vector
	handle_movement(delta)
	
	# Change the camera's x offset when the player goes the opposite direction
	#handle_camera(delta)
	
	# Update sprite based on direction
	if velocity.x < 0:
		$Smoothing2D/AnimatedSprite2D.flip_h = false
	else:
		$Smoothing2D/AnimatedSprite2D.flip_h = true
		
	move_and_slide()
	
	# Correct RB2D collisions
	for i in get_slide_collision_count():
		var c = get_slide_collision(i)
		if c.get_collider() is RigidBody2D:
			c.get_collider().apply_central_impulse(-c.get_normal() * PUSH_FORCE)
	
	# Set at the end of the process loop to be used in the next frame
	last_direction = current_direction


# Modify the camera settings based on the player's position
func handle_camera(_delta) -> void:
	# Stop tweening the camera's offset when the player stops moving
	if pow(velocity.x, 2) < 1:
		if camera_tween:
			camera_tween.kill()
	# Modify the camera's x position when the player start going in the opposite direction
	if current_direction != last_direction:
		if camera_tween:
			camera_tween.kill()
		var offset = Vector2(0, -60)
		match current_direction:
			Direction.RIGHT: offset.x = CAMERA_OFFSET
			Direction.LEFT: offset.x = -CAMERA_OFFSET
			Direction.NONE: offset.x = $Camera.offset.x
		camera_tween = get_tree().create_tween()
		camera_tween.tween_property($Camera, "offset", offset, CAMERA_TWEEN_SPEED)


# Calculates the velocity vector of the player each frame
func handle_movement(delta) -> void:
	# Add gravity
	if not is_on_floor():
		velocity.y += gravity * delta
		# Apply friction coefficient only when sliding down a wall
		if velocity.y > 0 and is_on_wall():
			velocity.y *= FRICTION_COEFFICIENT
			
	# Set current direction to left or right as soon as the action is pressed
	if Input.is_action_just_pressed("move_left"):
		current_direction = Direction.LEFT
	elif Input.is_action_just_pressed("move_right"):
		current_direction = Direction.RIGHT
		
	# Get input strength
	var left_force = Input.get_action_strength("move_left")
	var right_force = Input.get_action_strength("move_right")
	if not CAN_MOVE_FREELY:
		left_force = 0
		right_force = 0
	
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
	if not CAN_MOVE_FREELY:
		velocity = Vector2.ZERO


# Handle jump action and update jump flags accordingly
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
		jump_timer = 0
	# Increase jump tolerance timer when not on the floor
	else:
		jump_timer += delta
	
	# Check jump tolerance threshold
	if jump_timer > JUMP_TOLERANCE_THRESHOLD:
		JUMP_TOLERANCE_OVER = true
		
	CAN_JUMP = CAN_WALL_JUMP or (not JUMP_TOLERANCE_OVER and not HAS_JUMPED)
	
	# Handle jump action
	if Input.is_action_just_pressed("jump") and CAN_JUMP:
		HAS_JUMPED = true
		velocity.y = JUMP_VELOCITY
		last_jump_x = INF
		# Check if that was a wall jump
		if not is_on_floor() and CAN_WALL_JUMP:
			# Only set actual x coordinate when wall jumping
			last_jump_x = position.x
			# Emit wall jump particles
			$JumpParticles.emitting = true


func die(body):
	hide()
	IS_DEAD = true
	CAN_MOVE_FREELY = false
	death_count += 1
	create_tween().tween_property(self, "position", starting_position, .75)
	await get_tree().create_timer(.75).timeout
	position = starting_position
	revive()


func revive():
	show()
	IS_DEAD = false
	CAN_MOVE_FREELY = true
