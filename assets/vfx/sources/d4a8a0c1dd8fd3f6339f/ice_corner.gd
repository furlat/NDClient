extends "res://assets/vfx/sources/41bda60be893f43ae18e/solid_wall.gd"
## The existing older corner's24 native chip bodies, prepared before the hit.
const Restore = preload("res://assets/vfx/sources/ceff5437bd2fda002c72/restore.gd")
var bank: Resource
var runtime_materials: Array[ShaderMaterial] = []
var runtime_geometry: Array = []
var source_transform_known := false
var previous_source_transform := Transform3D.IDENTITY

static func preparation_resources(input: Dictionary) -> Array:
	return Restore.preparation_resources(input)

static func make_component(input: Dictionary) -> Node3D:
	return Restore.make("res://assets/vfx/sources/d4a8a0c1dd8fd3f6339f/ice_corner.gd", input)

func sample(seconds: float) -> void:
	Restore.sample_wall(self, seconds)

func shatter() -> void:
	assert(not broken and fragments.size() == bank.break_motions.size())
	for index in fragments.size():
		var body: RigidBody3D = fragments[index]
		var motion: Dictionary = bank.break_motions[index]
		body.collision_layer = int(motion.collision_layer)
		body.collision_mask = int(motion.collision_mask)
		body.show()
		body.freeze = false
		body.linear_velocity = motion.linear_velocity_source_units_per_second
		body.angular_velocity = motion.angular_velocity_source_radians_per_second
		if settings.get("single_section", false):
			body.linear_velocity = subject.global_basis * body.linear_velocity
			body.angular_velocity = subject.global_basis * body.angular_velocity
	broken = true

func update_flakes(age: float, ground: Vector2, removal: float) -> void:
	Restore.flakes_wall(self, age, ground, removal)

func source_bindings() -> Dictionary:
	return Restore.source_bindings(self)

func set_root_path(_value: Transform3D) -> void:
	Restore.update_source_transform(self)
