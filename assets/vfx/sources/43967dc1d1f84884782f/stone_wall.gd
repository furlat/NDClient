extends "res://assets/vfx/sources/ef76c0b7e659f7397562/solid_wall_assembly_breakup.gd"
const Restore = preload("res://assets/vfx/sources/ceff5437bd2fda002c72/restore.gd")
var bank: Resource
var runtime_materials: Array[ShaderMaterial] = []
var runtime_geometry: Array = []
var runtime_break_sources: Array[MeshInstance3D] = []
var source_transform_known := false
var previous_source_transform := Transform3D.IDENTITY

static func preparation_resources(input: Dictionary) -> Array:
	return Restore.preparation_resources(input)

static func make_component(input: Dictionary) -> Node3D:
	return Restore.make("res://assets/vfx/sources/43967dc1d1f84884782f/stone_wall.gd", input)

func sample(seconds: float) -> void:
	Restore.sample_wall(self, seconds)

func shatter() -> void:
	Restore.break_wall(self)

func _ready() -> void:
	assembly_breakup.attach_world(self)

func source_bindings() -> Dictionary:
	return Restore.source_bindings(self)

func set_root_path(_value: Transform3D) -> void:
	Restore.update_source_transform(self)

func _exit_tree() -> void:
	assembly_breakup.close()
