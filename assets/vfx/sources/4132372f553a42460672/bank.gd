extends Resource
## Immutable exact native section draws and donor finish. No owner/event state.
@export var material: ShaderMaterial
@export var material_specification: Dictionary = {}
@export var geometry: Dictionary = {}
@export var provenance: Dictionary = {}
var published_geometry: Dictionary = {}
var interface_ready := false

static func section_key(form: String, section: Dictionary, radius: float, spacing: float) -> String:
	# Names identify actual backend sections, not immutable geometry. They must
	# never be frozen into this preparation key or substituted at runtime.
	return JSON.stringify([form, section.origin, section.horizontal, section.vertical,
		radius if form == "cage" else 0.0, spacing if form == "cage" else 0.0]).sha256_text()

func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	material.get_property_list()
	for key in geometry:
		var source: Variant = geometry[key]
		if source is Mesh:
			published_geometry[key] = source
		else:
			# A dummy renderer cannot serialize RenderingServer-owned MultiMesh
			# buffers. Preserve the original transforms explicitly as CPU data;
			# publish the immutable renderer buffer before any occurrence exists.
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = source.mesh
			multimesh.instance_count = source.transforms.size()
			for index in source.transforms.size():
				multimesh.set_instance_transform(index, source.transforms[index])
			published_geometry[key] = multimesh
	interface_ready = true

