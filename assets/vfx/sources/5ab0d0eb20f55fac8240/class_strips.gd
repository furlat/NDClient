extends "res://assets/vfx/sources/5944248dd6bb52ef8394/class_action.gd"
const Motion = preload("res://assets/vfx/sources/584a1116b96d865072e3/strip_motion.gd")
const ASSEMBLIES := {
	"quickened": "res://assets/vfx/sources/828c2cb08fb5a3ff8675/quickened.tscn",
	"twinned": "res://assets/vfx/sources/34bc32e89d5aa2bec55a/twinned.tscn",
	"distant": "res://assets/vfx/sources/f290264eb5973819ad72/distant.tscn",
}
static var prepared_scenes: Dictionary = {}
var prepared_strip_mesh: ArrayMesh


static func make_component(input: Dictionary) -> Node3D:
	var node: Node3D = VfxPackageIO_5ab0d0eb20.resource("res://assets/vfx/sources/5ab0d0eb20f55fac8240/class_strips.gd").new()
	node.settings = input.duplicate(true)
	node.kind = input.kind
	if ASSEMBLIES.has(node.kind) and not input.get("native_palette", []).is_empty():
		node._build_prepared()
	else:
		node._build()
	return node


static func preparation_resources(input: Dictionary) -> Array:
	return [ASSEMBLIES[input.kind]] if ASSEMBLIES.has(input.kind) and not input.get("native_palette", []).is_empty() else []


func _build_prepared() -> void:
	var path: String = ASSEMBLIES[kind]
	if not prepared_scenes.has(path):
		prepared_scenes[path] = VfxPackageIO_5ab0d0eb20.resource(path)
	fit = prepared_scenes[path].instantiate()
	add_child(fit)
	for node in fit.get_children():
		if str(node.name).begins_with("Strip"):
			pieces.append(node)
		elif str(node.name).begins_with("Core"):
			cores.append(node)
		elif str(node.name).begins_with("Mote"):
			motes.append(node)
	for group in [pieces, cores]:
		for node in group:
			NativePalette.bind_parameters(node.material_override, settings.native_palette)
	prepared_strip_mesh = pieces[0].mesh
	flow_noise = pieces[0].material_override.get_shader_parameter("source_noise")
	sample(0.0)


func _piece(family: String, index: int) -> MeshInstance3D:
	var piece := super._piece(family, index)
	if kind not in ["roar", "presence"]:
		Motion.prepare(piece.material_override, kind, index)
	return piece


func _strip(_index: int, _seconds: float) -> ArrayMesh:
	return prepared_strip_mesh if prepared_strip_mesh != null else Motion.mesh(48)


func source_bindings() -> Dictionary:
	# These components have no AnimationPlayers, native emitters or hidden
	# controllers. Exact displayed nodes/materials are known at construction.
	var nodes: Array = []
	var materials: Array = []
	for group in [pieces, cores, motes]:
		for node in group:
			nodes.append(node)
			if node.material_override not in materials:
				materials.append(node.material_override)
	return {"geometry": nodes, "materials": materials, "static_material_topology": true}

const VfxPackageIO_5ab0d0eb20 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
