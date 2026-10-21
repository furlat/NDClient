extends "res://assets/vfx/sources/a0acae9a3d7412c36b8c/wind_bank.gd"
## Immutable donor geometry with prepared live-path/contact programs.
@export var donor_bank: Resource
var interface_ready := false


func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	grid = donor_bank.grid
	debris_mesh = donor_bank.debris_mesh
	hit_mesh = donor_bank.hit_mesh
	feed_material = donor_bank.feed_material
	source_parameters = donor_bank.source_parameters
	source_phase = donor_bank.source_phase
	source_hashes = donor_bank.source_hashes
	for material: ShaderMaterial in flow_materials + hit_materials:
		material.get_property_list()
		material.shader.get_shader_uniform_list()
	for mesh: Mesh in [grid, debris_mesh, hit_mesh]:
		mesh.get_rid()
	interface_ready = true
