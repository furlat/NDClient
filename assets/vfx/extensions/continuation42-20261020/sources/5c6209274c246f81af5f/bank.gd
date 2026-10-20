extends Resource
## Two actual source materials, plus the unchanged windup station template.
## No quarry, source item, pose, target layout, source time or particle history.
const Clock = preload("res://assets/vfx/sources/c0017ad639184b208deb/occurrence_clock.gd")
const Bindings = preload("res://assets/vfx/sources/dabf568b4506db4883ad/occurrence_bindings.gd")
@export var material_parameters: Dictionary = {}
@export var materials: Array[ShaderMaterial] = []
@export var material_settings: Array[Dictionary] = []
@export var windup := false
@export var ribbon: ArrayMesh
@export var provenance: Dictionary = {}
var interface_ready := false

func private_material(index: int) -> ShaderMaterial:
	var specification: Dictionary = material_settings[index]
	var material := ShaderMaterial.new()
	material.shader = materials[index].shader
	material.render_priority = specification.render_priority
	for name in specification.parameters:
		material.set_shader_parameter(name,specification.parameters[name])
	for name in specification.metadata:
		material.set_meta(name,specification.metadata[name])
	return material

func prepare_immutable_interface() -> void:
	if interface_ready: return
	Clock.ensure_pool()
	Bindings.methods(VfxPackageIO_5c6209274c.resource("res://assets/vfx/extensions/continuation42-20261020/sources/b383d717f6c20a7ed205/field.gd"))
	for material in materials:
		material.get_rid()
		material.get_property_list()
		material.shader.get_shader_uniform_list()
	if ribbon != null:
		ribbon.get_rid()
		# Populate the unchanged source's immutable template cache before publish.
		# No hand coordinates, occurrence Node or sampled path is supplied here.
		preload("res://assets/vfx/extensions/continuation42-20261020/sources/34e0f9ed9a909885cd97/path_ribbon.gd").templates[[15,Color.WHITE,Vector2(0,1),false]] = ribbon
	interface_ready = true

const VfxPackageIO_5c6209274c = preload("res://assets/vfx/extensions/continuation42-20261020/scoped_resource_io.gd")
