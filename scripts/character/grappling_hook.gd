extends Node2D

# Flags
var HAS_CONNECTED = false

var static_body: StaticBody2D
var static_body_collision: CollisionShape2D
var static_body_collision_shape: RectangleShape2D
var static_joint: PinJoint2D
var hit_location: Vector2

func _ready():
	pass


func _process(delta):
	if HAS_CONNECTED:
		$ColorRect.position = hit_location


func connect_to_player(base: RigidBody2D):
	$CharacterJoint.node_b = base.get_path()
	print("linked to character")


func _on_rope_base_body_entered(body):
	if not HAS_CONNECTED:
		hit_location = $RopeBase.position + Vector2(0, -10)
		# Static body the rope will be attached to (the anchor point)
		static_body = StaticBody2D.new()
		static_body.set_name("anchor")
		static_body.position = hit_location
		# Static body collision shape object
		static_body_collision_shape = RectangleShape2D.new()
		static_body_collision_shape.set_size(Vector2(10, 10))
		# Static body collision object
		static_body_collision = CollisionShape2D.new()
		static_body_collision.position = hit_location
		static_body_collision.shape = static_body_collision_shape
		# Add collision shape to static body
		static_body.set_deferred("add_child", static_body_collision)
		# Add static body to scene
		add_child(static_body)
		# Static joint connecting the existing rope to the static body
		static_joint = PinJoint2D.new()
		static_joint.set_name("anchor_joint")
		static_joint.position = hit_location + Vector2(0, +5)
		#static_joint.node_a = static_body.get_path()
		static_joint.set_deferred("node_a", static_body.get_path())
		static_joint.node_b = $RopeBase.get_path()
		static_joint.scale = Vector2(.25, .25)
		# Append to the scene
		add_child(static_joint)
		print("Rope will be attached to:", hit_location)
		HAS_CONNECTED = true

func is_anchored() -> bool:
	return HAS_CONNECTED
