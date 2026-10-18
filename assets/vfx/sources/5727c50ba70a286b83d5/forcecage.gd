extends Node3D
## Explicit native WallSection geometry. Sparse luminous bar traces reveal an
## otherwise invisible cage; collision, ejection and escape stay in backend.
const FieldMaterial = preload("res://assets/vfx/sources/89da09bf4ca66175808e/field_material.gd")

var specification: Dictionary = {}
var endpoints: Array = []
var pieces: Array[GeometryInstance3D] = []
var materials: Array[ShaderMaterial] = []
var sections: Array = []
var local_clock := 0.0
var owner_state: Dictionary = {}
var visible_sections: Array = []

static func _vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

static func _quad(origin: Vector3, horizontal: Vector3, vertical: Vector3) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [origin, origin + horizontal, origin + horizontal + vertical, origin + vertical]
	var normal: Vector3 = horizontal.cross(vertical).normalized()
	var uv := [Vector2.ZERO, Vector2(horizontal.length(), 0), Vector2(horizontal.length(), vertical.length()), Vector2(0, vertical.length())]
	for index in [0, 1, 2, 0, 2, 3]:
		tool.set_normal(normal)
		tool.set_uv(uv[index])
		tool.add_vertex(corners[index])
	return tool.commit()

static func _bars(section: Dictionary, native_radius: float, trace_spacing: float) -> MultiMesh:
	var origin := _vector(section.origin)
	var horizontal := _vector(section.horizontal)
	var vertical := _vector(section.vertical)
	var count := int(floor(horizontal.length() / trace_spacing)) + 1
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = native_radius
	cylinder.bottom_radius = native_radius
	cylinder.height = vertical.length()
	cylinder.radial_segments = 8
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = cylinder
	multimesh.instance_count = count
	var along := vertical.normalized()
	var across := horizontal.normalized()
	var basis := Basis(across, along, across.cross(along).normalized())
	for number in count:
		var centre := origin + horizontal * (float(number) / float(count - 1)) + vertical * .5
		multimesh.set_instance_transform(number, Transform3D(basis, centre))
	return multimesh

static func make_component(input: Dictionary) -> Node3D:
	assert(input.form in ["cage", "box"] and not str(input.owner_uuid).is_empty())
	var effect: Node3D = VfxPackageIO_5727c50ba7.resource("res://assets/vfx/sources/5727c50ba70a286b83d5/forcecage.gd").new()
	effect.specification = input.duplicate(true)
	effect.sections = input.sections.duplicate(true)
	var identities := {}
	for section in effect.sections:
		assert(not identities.has(section.uuid))
		identities[section.uuid] = true
		var piece: GeometryInstance3D
		if input.form == "cage":
			var bars := MultiMeshInstance3D.new()
			# One trace every N actual half-inch bars. Unlit intermediate force
			# remains invisible; this changes no supplied physical WallSection.
			bars.multimesh = _bars(section, float(input.bar_radius_cells), float(input.trace_spacing_cells))
			piece = bars
		else:
			var face := MeshInstance3D.new()
			face.mesh = _quad(_vector(section.origin), _vector(section.horizontal), _vector(section.vertical))
			piece = face
		var material := FieldMaterial.build(input.material)
		piece.name = str(section.uuid).validate_node_name()
		piece.material_override = material
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.top_level = true
		effect.add_child(piece)
		piece.hide()
		effect.pieces.append(piece)
		effect.materials.append(material)
	return effect

func set_live_endpoints(value: Array) -> void:
	endpoints = value.duplicate(true)
	sample(local_clock)

func set_owner_state(value: Dictionary) -> bool:
	if str(value.get("owner_uuid", "")) != str(specification.owner_uuid):
		return false
	owner_state = value.duplicate(true)
	sample(local_clock)
	return true

func sample(seconds: float) -> void:
	local_clock = seconds
	if endpoints.is_empty():
		return
	var state: Dictionary = specification.state.duplicate(true)
	for row in specification.get("review_states", []):
		if seconds >= float(row.seconds):
			state.merge(row.state, true)
	if not owner_state.is_empty():
		state = owner_state.duplicate(true)
	var active: bool = str(state.get("owner_uuid", "")) == str(specification.owner_uuid)
	active = active and bool(state.get("present", false)) and bool(state.get("observed", false)) and not bool(state.get("suppressed", true))
	var envelope: float = smoothstep(0.0, float(specification.apply_seconds), seconds) if active else 0.0
	if state.has("ending_started_at"):
		envelope *= 1.0 - smoothstep(0.0, float(specification.retire_seconds), seconds - float(state.ending_started_at))
	visible_sections.clear()
	for index in sections.size():
		var opacity := envelope
		var section: Dictionary = sections[index]
		for removal in state.get("section_removals", []):
			if str(removal.uuid) == str(section.uuid):
				opacity *= 1.0 - smoothstep(0.0, float(specification.retire_seconds), seconds - float(removal.started_at))
		pieces[index].global_transform = Transform3D(Basis.IDENTITY, endpoints[0].point)
		pieces[index].visible = opacity > .0001
		materials[index].set_shader_parameter("field_clock", seconds + float(specification.get("phase_offset_seconds", 0.0)))
		materials[index].set_shader_parameter("field_opacity", opacity * float(specification.opacity))
		if pieces[index].visible:
			visible_sections.append(section.uuid)

func capture_observation() -> Dictionary:
	return {"forcecage": {"owner_uuid": specification.owner_uuid, "form": specification.form,
		"clock": local_clock, "visible_section_uuids": visible_sections.duplicate(),
		"all_section_uuids": sections.map(func(value: Dictionary) -> String: return value.uuid),
		"optical_lights": 0, "physical_rules": "Supplied backend WallSections; sparse traces only, no local collision/escape"}}

const VfxPackageIO_5727c50ba7 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
