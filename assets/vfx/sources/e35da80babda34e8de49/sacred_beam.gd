extends "res://assets/vfx/sources/e212c77ca5bf64639ea0/base.gd"
## Native source authoring; shared stage, process clock, palette and capture.
const SourceMaterials = preload("res://assets/vfx/sources/5f45d57a61f8be02c69c/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/e35da80babda34e8de49/sacred_beam.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


const SPEED = 1.8
var source: Node


func holy(c: Color) -> Color:
	if c.s < 0.12:
		return c
	return Color.from_hsv(0.12, c.s * 0.8, c.v, c.a)


func recolor_resource(r: Resource) -> void:
	if r == null or visited.has(r.get_instance_id()):
		return
	visited[r.get_instance_id()] = true
	for p in r.get_property_list():
		if not (int(p.usage) & PROPERTY_USAGE_STORAGE):
			continue
		var v = r.get(p.name)
		if v is Color:
			r.set(p.name, holy(v))
		elif v is PackedColorArray:
			var changed := PackedColorArray()
			for c in v:
				changed.append(holy(c))
			r.set(p.name, changed)
		elif v is Resource:
			recolor_resource(v)


func apply_scene_edits(node: Node) -> void:
	source = node
	pass
	node.scale = Vector3(0.28, 0.45, 0.28)
	var flare = node.get_node("muzzle")
	flare.process_material = flare.process_material.duplicate(true)
	flare.process_material.scale_min *= 0.18
	flare.process_material.scale_max *= 0.18
	for child in node.find_children("*", "", true, false):
		if child is GPUParticles3D:
			child.speed_scale = SPEED
		for p in child.get_property_list():
			if int(p.usage) & PROPERTY_USAGE_STORAGE:
				var v = child.get(p.name)
				if v is Resource:
					recolor_resource(v)
		if child is GeometryInstance3D:
			if child.name in ["inner_base", "windsoil", "groundmark1"]:
				child.layers = 0
			if child.material_override is ShaderMaterial:
				var mat: ShaderMaterial = child.material_override.duplicate(true)
				var shader := Shader.new()
				var code: String = mat.shader.code
				code = code.replace("TIME", "source_clock")
				code = code.replace(
					"shader_type spatial;", "shader_type spatial;\nuniform float source_clock=0.0;"
				)
				var sign = "<" if side == "front" else ">="
				var clip = (
					"\nvec3 split_world=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;\nif (dot(split_world,vec3(0.70710678,0.0,0.70710678)) "
					+ sign
					+ " 0.0) discard;\n"
				)
				if side == "full": clip = "\nvec3 split_world=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;\n"
				if (
					String(child.name).begins_with("inner_")
					or String(child.name).begins_with("outter_")
				):
					clip += "if (split_world.y < max(0.0,22.5*(0.65-source_clock)/(0.65-0.433333))) discard;\n"
				code = code.replace("void fragment() {", "void fragment() {" + clip)
				shader.code = code
				mat.shader = shader
				child.material_override = mat
				materials.append(mat)
			elif side == "back":
				child.layers = 0


func advance_lifecycle(_delta: float) -> void:
	if not is_instance_valid(source):
		return
	tick += 1
	for mat in materials:
		mat.set_shader_parameter(
			"source_clock", float(tick) / float(parameters.simulation_hz) * SPEED
		)
	# Ground flare and ancillary sparks begin when the descending front reaches y=0.
	for name in [
		"smallparticles_constant",
		"smallparticles_constant2",
		"floorflash",
		"floorflash2",
		"itemflash",
		"muzzle"
	]:
		if tick < 52:
			source.get_node(name).visible = false
		elif tick == 52:
			source.get_node(name).visible = true
