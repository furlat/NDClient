extends Resource
## New closed-hold artwork, sampled from the actual source-authored hold window.
@export var particle_data: Texture2D
@export var draw_material: ShaderMaterial
@export var draw_mesh: Mesh
@export var emitter_transform := Transform3D.IDENTITY
@export var particle_count := 3
@export var source_hz := 144
@export var hold_start_seconds := 1.5
@export var hold_end_seconds := 3.5
@export var source_properties: Dictionary = {}
@export var provenance: Dictionary = {}
var interface_ready := false


func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	assert(particle_data != null and draw_mesh != null and draw_material != null)
	assert(particle_count == 3 and hold_end_seconds > hold_start_seconds)
	assert(particle_data.get_width() == roundi((hold_end_seconds - hold_start_seconds) * source_hz) + 1)
	assert(particle_data.get_height() == particle_count * 6)
	particle_data.get_rid()
	draw_mesh.get_rid()
	draw_material.get_property_list()
	draw_material.shader.get_rid()
	VfxPackageIO_451a60ce42.resource("res://assets/vfx/extensions/production-review-20261020/sources/e2ac0833a7405937cab5/flame_hold_process.gdshader").get_rid()
	interface_ready = true

const VfxPackageIO_451a60ce42 = preload("res://assets/vfx/extensions/production-review-20261020/scoped_resource_io.gd")
