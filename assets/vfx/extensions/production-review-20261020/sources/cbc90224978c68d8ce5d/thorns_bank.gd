extends "res://assets/vfx/sources/e5af8c7a70cade75d4a1/bank.gd"
## Same native meshes/material/animation, with explicit authored geometry uniforms.
var interface_ready := false
@export var donor_bank: Resource


func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	meshes = donor_bank.meshes
	mesh_transform = donor_bank.mesh_transform
	decal_properties = donor_bank.decal_properties
	animation = donor_bank.animation
	tracks = donor_bank.tracks
	source_settings = donor_bank.source_settings
	provenance = donor_bank.provenance
	super.prepare_immutable_interface()
	for mesh: Mesh in meshes:
		mesh.get_rid()
	interface_ready = true
