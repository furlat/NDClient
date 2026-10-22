extends Resource
## Original unsampled scene plus an offline frame-operand shader substitution.
## No actor point packet, occurrence, mutable material or source clock stored.
const Materials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Bindings = preload("res://assets/vfx/sources/dabf568b4506db4883ad/occurrence_bindings.gd")
@export var native_bank: Resource
@export var frame_shaders: Array[Shader] = []
@export var kernel: Resource
@export var provenance: Dictionary = {}
var interface_ready := false
var native_ready := false
var native_defaults: Dictionary:
	get:
		return native_bank.native_defaults


func prepare_immutable_interface_step() -> Dictionary:
	if native_bank == null or native_bank.scene == null or kernel == null:
		interface_ready = false
		return {"complete": false, "error": "Actual native patches scene and frame kernel required"}
	if frame_shaders.size() != native_bank.material_piece_indices.size():
		interface_ready = false
		return {"complete": false, "error": "Every actual material needs its prepared frame program"}
	if not native_ready:
		native_bank.prepare_immutable_interface()
		for shader: Shader in frame_shaders:
			if shader == null:
				return {"complete": false, "error": "Missing prepared patches frame program"}
			shader.get_rid()
			shader.get_shader_uniform_list()
			Materials.declared_uniforms(shader)
		Bindings.methods(VfxPackageIO_c4f4d4ddde.resource("res://assets/vfx/extensions/cloud-body-speed-20261021/sources/c19fb6c081fb50b97c27/component.gd"))
		native_ready = native_bank.interface_ready
	var result: Dictionary = kernel.prepare_immutable_interface_step()
	var error: String = result.get("error", "")
	if error.is_empty() and not native_ready:
		error = "Original patches interface did not prepare"
	interface_ready = error.is_empty() and result.complete and kernel.available()
	return {"complete": interface_ready, "error": error, "compute": result}

const VfxPackageIO_c4f4d4ddde = preload("res://assets/vfx/extensions/cloud-body-speed-20261021/scoped_resource_io.gd")
