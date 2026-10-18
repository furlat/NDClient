extends Node3D
## One owned vertical field. Movement and exposure events are supplied, not solved.
const Graph = preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const NativePalette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")
var specification: Dictionary = {}
var layers: Array[Dictionary] = []
var field: Node3D
var endpoints: Array = []


static func make_component(input: Dictionary) -> Node3D:
	var effect: Node3D = VfxPackageIO_08327bdb7a.resource("res://assets/vfx/sources/08327bdb7a95631435c4/moonbeam.gd").new()
	effect.specification = input.duplicate(true)
	return effect


func set_live_endpoints(value: Array) -> void:
	endpoints = value


func prepare() -> void:
	field = Node3D.new()
	field.name = "OneMoonbeamOwner"
	add_child(field)
	# Extract named source layers; donor demo scripts, light, soil crack, flashes
	# and autonomous eight-second animation are not a spell lifetime controller.
	var source: Node3D = VfxPackageIO_08327bdb7a.resource(specification.scene).instantiate()
	for selected in specification.layers:
		var original: MeshInstance3D = source.get_node(selected.node)
		var layer := MeshInstance3D.new()
		layer.name = original.name
		layer.mesh = original.mesh
		layer.material_override = Graph.clone_value(original.material_override, {})
		layer.scale = Vector3(selected.scale[0], selected.scale[1], selected.scale[2])
		layer.position = Vector3(selected.position[0], selected.position[1], selected.position[2])
		layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material: ShaderMaterial = layer.material_override
		var shader := Shader.new()
		var token := RegEx.new()
		token.compile("\\bTIME\\b")
		shader.code = token.sub(SourceMaterials.expand_shader(material.shader.code, material.shader.resource_path.get_base_dir()), "moon_clock", true).replace("shader_type spatial;", "shader_type spatial;\nuniform float moon_clock=0.0;\nuniform float moon_opacity=1.0;")
		shader.code = _fragment_finish(shader.code, "\nALPHA *= moon_opacity;\n")
		if selected.get("shaft", false):
			shader.code = shader.code.replace("shader_type spatial;", "shader_type spatial;\nvarying float moon_height;")
			if shader.code.contains("void vertex()"):
				shader.code = shader.code.replace("void vertex() {", "void vertex() {\nmoon_height=VERTEX.y;")
			else:
				shader.code += "\nvoid vertex(){moon_height=VERTEX.y;}\n"
			shader.code = _fragment_finish(shader.code, "\nALPHA *= smoothstep(0.0,0.12,moon_height)*(1.0-smoothstep(0.75,1.0,moon_height));\nfloat moon_facing=abs(dot(normalize(NORMAL),normalize(VIEW)));\nALPHA*=smoothstep(0.0,0.42,moon_facing)*smoothstep(0.08,0.34,ALPHA);\n")
		SourceMaterials.replace_shader(material, shader)
		for uniform in selected.uniforms:
			var value: Variant = selected.uniforms[uniform]
			if value is Array and value.size() == 2:
				value = Vector2(value[0], value[1])
			material.set_shader_parameter(uniform, value)
		NativePalette.apply(material, specification.palette, {"quantize": false, "emission_gain": 0.15})
		field.add_child(layer)
		layers.append({"node": layer, "material": material, "opacity": selected.opacity})
	source.free()


static func _fragment_finish(code: String, addition: String) -> String:
	var begin: int = code.find("{", code.find("void fragment()"))
	assert(begin >= 0, "Moonbeam source has no fragment output")
	var depth: int = 1
	var cursor: int = begin + 1
	while cursor < code.length() and depth > 0:
		if code[cursor] == "{": depth += 1
		elif code[cursor] == "}": depth -= 1
		cursor += 1
	assert(depth == 0, "Moonbeam source has an unclosed fragment")
	return code.insert(cursor - 1, addition)


func sample(seconds: float) -> void:
	if field == null:
		prepare()
	var envelope: float = 1.0
	if specification.phase == "apply": envelope = smoothstep(0.0, 0.45, seconds)
	elif specification.phase == "remove": envelope = 1.0 - smoothstep(0.0, 0.55, seconds)
	var clock: float = seconds + float(specification.source_time_offset)
	for layer in layers:
		layer.material.set_shader_parameter("moon_clock", clock)
		layer.material.set_shader_parameter("moon_opacity", envelope * float(layer.opacity))
	field.visible = envelope > 0.001
	if not endpoints.is_empty():
		field.position = global_transform.affine_inverse() * endpoints[0].point


func capture_observation() -> Dictionary:
	return {"source_scene": specification.scene, "field_owners": 1,
		"radius_cells": specification.radius_cells, "geometry_layers": layers.size(),
		"phase": specification.phase, "optical_lights": 0,
		"field_position": [field.global_position.x, field.global_position.y, field.global_position.z] if field != null else []}

const VfxPackageIO_08327bdb7a = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
