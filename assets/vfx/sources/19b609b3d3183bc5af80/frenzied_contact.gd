extends "res://assets/vfx/sources/048e2881b9068776f055/clocked_source.gd"
## A finite native hit donor at the existing child attack's supplied recipient.
## No attack resolution, new body animation or condition lifetime is inferred.
const Palette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")
var endpoints: Array = []


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/19b609b3d3183bc5af80/frenzied_contact.gd", input)


func set_live_endpoints(value: Array) -> void:
	endpoints = value


func prepare_materials(node: Node) -> void:
	super.prepare_materials(node)
	for child in node.find_children("*", "GeometryInstance3D", true, false):
		if child.material_override is ShaderMaterial:
			Palette.apply(child.material_override, settings.contact_palette, {"quantize": false})


func apply_scene_edits(node: Node) -> void:
	node.scale = Vector3.ONE * float(settings.source_scale)


func update_geometry() -> void:
	if not endpoints.is_empty() and is_instance_valid(subject) and subject.is_inside_tree():
		subject.global_position = endpoints[0].point
