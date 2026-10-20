extends Resource
## Exact native Acid Arrow residual operands. Recipient/cell data stays live.
const Bindings = preload("res://assets/vfx/sources/dabf568b4506db4883ad/occurrence_bindings.gd")
const Clock = preload("res://assets/vfx/sources/c0017ad639184b208deb/occurrence_clock.gd")
@export var material_parameters: Dictionary = {}
@export var materials: Array[ShaderMaterial] = []
@export var head: Mesh
@export var shaft: Mesh
@export var bead: Mesh
@export var includes_patch := false
@export var provenance: Dictionary = {}
var interface_ready := false


static func material_signature(input: Dictionary) -> Dictionary:
	var signature := {}
	for key in ["palette","head_material","core_material","trail_material","droplet_material",
		"patch_material","opacity_response","patch_opacity_exponent"]:
		if input.has(key):
			signature[key] = input[key]
	return signature


func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	Clock.ensure_pool()
	Bindings.methods(VfxPackageIO_bf40f205bc.resource("res://assets/vfx/extensions/followup-20261020/sources/37785dde819b7df05531/field.gd"))
	for material in materials:
		material.get_property_list()
		material.shader.get_shader_uniform_list()
	for mesh in [head,shaft,bead]:
		mesh.get_rid()
	interface_ready = true

const VfxPackageIO_bf40f205bc = preload("res://assets/vfx/extensions/followup-20261020/scoped_resource_io.gd")
