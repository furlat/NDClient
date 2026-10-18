extends Node3D
## Original skeletal rig and Darkness meshes, registered to a caster and an
## admitted target. Geometry/materials never select or move gameplay actors.
const SourceGraph = preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")

var parameters: Dictionary
var hand: Node3D
var projectile: Node3D
var endpoints: Array = []
var projectile_materials: Array[ShaderMaterial] = []
var splinters: Array[MeshInstance3D] = []
var emission_point: Vector3 = Vector3.ZERO
var target_point: Vector3 = Vector3.ZERO
var head_point: Vector3 = Vector3.ZERO

static func make_component(input: Dictionary) -> Node3D:
	var node := VfxPackageIO_5bf1f373ac.resource("res://assets/vfx/sources/5bf1f373ac1affd0173c/skeletal_cast.gd").new() as Node3D
	node.parameters = input.duplicate(true)
	return node

func set_live_endpoints(value: Array) -> void:
	endpoints = value

func set_delivery_timing(launch: float, travel: float) -> void:
	parameters.launch_seconds = launch
	parameters.travel_seconds = maxf(.001, travel)

func _prepare() -> void:
	var source: Script = VfxPackageIO_5bf1f373ac.resource(parameters.hand_script)
	hand = source.make_component(parameters.hand_input)
	add_child(hand)
	hand.scale = Vector3.ONE / float(parameters.native_units_per_cell)
	if parameters.get("counterspell", false):
		return
	projectile = VfxPackageIO_5bf1f373ac.resource(parameters.projectile_scene).instantiate()
	SourceGraph.isolate_node(projectile, {})
	add_child(projectile)
	for child in projectile.get_children():
		if not child is MeshInstance3D or child.name not in ["FBHead", "FBHead2inner", "FBHead3outside"]:
			child.free()
			continue
		var material: ShaderMaterial = child.material_override
		_gray_resource(material, {})
		var original: Shader = material.shader
		var shader := Shader.new()
		var code := SourceMaterials.expand_shader(original.code, original.resource_path.get_base_dir())
		code = code.replace("TIME", "delivery_clock")
		code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform float delivery_clock=0.;\nuniform float delivery_envelope=0.;")
		var end := code.rfind("}")
		code = code.insert(end, "\nALPHA *= delivery_envelope;\n")
		shader.code = code
		SourceMaterials.replace_shader(material, shader)
		projectile_materials.append(material)
	var source_mesh: Dictionary = JSON.parse_string(VfxPackageIO_5bf1f373ac.text(parameters.splinter_geometry))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	for value in source_mesh.vertices:
		vertices.append(Vector3(value[0], value[1], value[2]))
	for value in source_mesh.uv:
		uv.append(Vector2(value[0], value[1]))
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(source_mesh.indices)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	for index in 30:
		var piece := MeshInstance3D.new()
		piece.mesh = mesh
		piece.material_override = VfxPackageIO_5bf1f373ac.resource(parameters.splinter_material).duplicate(true)
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(piece)
		splinters.append(piece)

func _gray_resource(resource: Resource, seen: Dictionary) -> void:
	if resource == null or seen.has(resource):
		return
	seen[resource] = true
	for property in resource.get_property_list():
		if not int(property.usage) & PROPERTY_USAGE_STORAGE:
			continue
		var value: Variant = resource.get(property.name)
		if value is Color:
			resource.set(property.name, Color(value.v, value.v, value.v, value.a))
		elif value is PackedColorArray:
			var colours := PackedColorArray()
			for colour in value:
				colours.append(Color(colour.v, colour.v, colour.v, colour.a))
			resource.set(property.name, colours)
		elif value is Resource and not value is Shader:
			_gray_resource(value, seen)

func sample(seconds: float) -> void:
	if hand == null:
		_prepare()
	hand.sample(seconds)
	if endpoints.size() < 2:
		return
	var inverse := global_transform.affine_inverse()
	var native_tip: Array = parameters.emission_point_native
	emission_point = hand.to_global(Vector3(native_tip[0], native_tip[1], native_tip[2]))
	target_point = endpoints[1].point
	if projectile == null:
		return
	var start: Vector3 = inverse * emission_point
	var end: Vector3 = inverse * target_point
	var launch: float = parameters.launch_seconds
	var travel: float = maxf(.001, parameters.travel_seconds)
	var progress := clampf((seconds - launch) / travel, 0., 1.)
	head_point = emission_point.lerp(target_point, progress)
	projectile.position = start.lerp(end, progress)
	var direction := (end - start).normalized()
	projectile.basis = Basis.IDENTITY if direction.is_zero_approx() else Basis.looking_at(direction, Vector3.FORWARD if absf(direction.y) > .99 else Vector3.UP)
	projectile.scale *= Vector3(.4, .4, .68) / float(parameters.native_units_per_cell)
	var age := 1.10 + (seconds - launch) / travel * .65
	var envelope := smoothstep(1.08, 1.12, age) * (1. - smoothstep(1.75, 1.84, age))
	projectile.visible = seconds >= launch - .02 and age < 1.84
	for material in projectile_materials:
		material.set_shader_parameter("delivery_clock", age)
		material.set_shader_parameter("delivery_envelope", envelope)
	var right := direction.cross(Vector3.UP).normalized()
	if right.is_zero_approx():
		right = Vector3.RIGHT
	var up := right.cross(direction).normalized()
	for index in splinters.size():
		var lag := float(index) * .012
		var piece: MeshInstance3D = splinters[index]
		piece.visible = age > 1.10 + lag and age < 1.82
		var along := clampf((age - 1.10 - lag) / .65, 0., 1.)
		var angle := float(index) * 2.399963 + age * 8.
		var radius := .06 + float(index % 4) * .028
		piece.position = start.lerp(end, along) + (right * sin(angle) + up * cos(angle)) * radius / float(parameters.native_units_per_cell)
		piece.scale = Vector3.ONE * .10 / float(parameters.native_units_per_cell)
		piece.rotation = Vector3(angle, age * 2., angle * .3)

func capture_observation() -> Dictionary:
	return {"caster_origin": _coordinates(global_position), "emission_world": _coordinates(emission_point),
		"target_world": _coordinates(target_point), "projectile_head_world": _coordinates(head_point),
		"counterspell": parameters.get("counterspell", false)}

func _coordinates(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

const VfxPackageIO_5bf1f373ac = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
