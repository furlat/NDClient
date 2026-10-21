extends "res://assets/vfx/extensions/wall-child-v3-20261021/sources/34c288bbfa76fd9ea2e9/ice_wall_clear_breach.gd"
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
	return Restore.make("res://assets/vfx/extensions/wall-child-v3-20261021/sources/4b9580110fc329eabba3/ice_wall.gd", input)

func sample(seconds: float) -> void:
	Restore.sample_wall(self, seconds)

func shatter() -> void:
	Restore.break_wall(self)

func update_flakes(age: float, ground: Vector2, removal: float) -> void:
	Restore.flakes_wall(self, age, ground, removal)

func _ready() -> void:
	assembly_breakup.attach_world(self)

func source_bindings() -> Dictionary:
	return Restore.source_bindings(self)

func set_root_path(_value: Transform3D) -> void:
	Restore.update_source_transform(self)

func _exit_tree() -> void:
	assembly_breakup.close()
