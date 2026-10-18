extends Node3D
## Formed layered orb. Element/side/outcomes/surface state are explicit inputs.
const Materials = preload("res://assets/vfx/sources/782125cbcfc15cad7fd7/orb_burst_materials.gd")
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")

var specification: Dictionary = {}
var endpoints: Array = []
var recipient_geometry: Dictionary = {}
var pivot: Node3D
var shells: Array[MeshInstance3D] = []
var splinters: Array[MeshInstance3D] = []
var materials: Array[ShaderMaterial] = []
var launch_seconds: float = 0.3
var travel_seconds: float = 0.52
var last_source := Vector3.ZERO
var last_recipient := Vector3.ZERO
var last_center := Vector3.ZERO


static func make_component(input: Dictionary) -> Node3D:
	assert(input.get("element", "") in ["acid", "cold", "fire", "lightning", "poison", "thunder"], "Orb requires an explicitly selected element")
	assert(input.get("side", "") in ["creature", "ground"], "Orb requires an explicitly selected side")
	assert(not (input.element == "thunder" and input.side == "ground"), "No thunder ground selection exists")
	var node: Node3D = VfxPackageIO_9632af18c9.resource("res://assets/vfx/sources/9632af18c96679529624/chromatic_orb.gd").new()
	node.specification = input.duplicate(true)
	node.launch_seconds = float(input.get("launch_seconds", 0.3))
	node.travel_seconds = float(input.get("travel_seconds", 0.52))
	return node


func set_live_endpoints(value: Array) -> void:
	endpoints = value


func set_entity_geometry(value: Dictionary) -> void:
	recipient_geometry = value


func set_delivery_timing(launch: float, travel: float) -> void:
	launch_seconds = maxf(launch, 0.0)
	travel_seconds = maxf(travel, 0.001)


func prepare() -> void:
	var donor: Node3D = VfxPackageIO_9632af18c9.resource(specification.scene).instantiate()
	pivot = Node3D.new()
	pivot.name = "FormedElementalOrb"
	add_child(pivot)
	for name in ["Inner", "Orbit_01", "Orbit_02"]:
		var source: MeshInstance3D = donor.get_node(name)
		var material: ShaderMaterial = Materials.extract(source.material_override, specification.palette, 0.08)
		material.set_shader_parameter("displacement_scale", 0.025 if name == "Inner" else 0.06)
		material.set_shader_parameter("emission_strength", 0.7)
		var code: String = material.shader.code
		if name == "Inner":
			code = SourceMaterials.finish_fragment(code, """
				vec2 orb_core_uv=UV*mask1_scale+vec2(orb_burst_seconds*time_scale)*mask1_scroll;
				float orb_core_flow=smoothstep(0.25,0.75,texture(mask1_texture,orb_core_uv).r);
				ALBEDO*=0.12+0.88*orb_core_flow;
				EMISSION*=0.35+0.65*orb_core_flow;
				ALPHA*=0.2+0.8*orb_core_flow;
			""")
		else:
			# Retain the actual three native moving band masks and their zeroes.
			code = SourceMaterials.finish_fragment(code, "\nALPHA=pow(clamp(ALPHA/max(orb_burst_envelope,0.0001),0.0,1.0),0.25)*orb_burst_envelope;\n")
		var shader := Shader.new()
		shader.code = code
		SourceMaterials.replace_shader(material, shader)
		materials.append(material)
		var draw: MeshInstance3D = Materials.draw(pivot, name, source.mesh, material)
		draw.transform = source.transform
		draw.sorting_offset = source.sorting_offset
		if name != "Inner":
			draw.scale *= 1.13
		shells.append(draw)
	var fragment := SphereMesh.new()
	fragment.radius = 0.025
	fragment.height = 0.07
	fragment.radial_segments = 12
	fragment.rings = 6
	for index in 9:
		splinters.append(Materials.draw(self, "OrbFragment" + str(index), fragment, materials[1]))
	donor.free()


func sample(seconds: float) -> void:
	if pivot == null:
		prepare()
	for draw in shells + splinters:
		draw.hide()
	for material in materials:
		Materials.clock(material, seconds, 0.0)
	if endpoints.size() < 3:
		return
	var inverse: Transform3D = global_transform.affine_inverse()
	var hand: Vector3 = inverse * endpoints[0].point
	var recipient: Vector3 = inverse * endpoints[1].point
	var source: Vector3 = inverse * endpoints[2].point
	last_source = source
	last_recipient = recipient
	if specification.phase == "impact":
		_sample_impact(seconds, recipient, source, inverse)
		return
	var preparing: bool = seconds < launch_seconds
	var along: float = clampf((seconds - launch_seconds) / travel_seconds, 0.0, 1.0)
	var after_contact: float = seconds - launch_seconds - travel_seconds
	var envelope: float = smoothstep(0.0, maxf(launch_seconds, 0.001), seconds) if preparing else 1.0 - smoothstep(-0.015, 0.1, after_contact)
	if envelope <= 0.001:
		return
	pivot.position = hand if preparing else source.lerp(recipient, along)
	var direction: Vector3 = (recipient - source).normalized()
	if not direction.is_zero_approx():
		pivot.basis = Basis(Quaternion(Vector3.BACK, direction))
	pivot.scale = Vector3.ONE * (0.22 * (0.25 + 0.75 * envelope) if preparing else 0.22)
	for draw in shells:
		draw.show()
	Materials.clock(materials[0], seconds, envelope * 0.55)
	Materials.clock(materials[1], seconds, envelope * 0.95)
	Materials.clock(materials[2], seconds + 0.27, envelope * 0.85)
	last_center = pivot.position


func _sample_impact(seconds: float, recipient: Vector3, source: Vector3, inverse: Transform3D) -> void:
	var outcome: String = specification.get("attack_outcome", "")
	if outcome == "miss" and not bool(specification.get("observed_ground_splash", false)):
		return
	var envelope: float = smoothstep(0.0, 0.035, seconds) * (1.0 - smoothstep(0.10, 0.52, seconds))
	if envelope <= 0.001:
		return
	pivot.position = recipient
	pivot.scale = Vector3.ONE * (0.22 + minf(seconds, 0.18) * 0.45)
	for draw in shells:
		draw.show()
	for index in materials.size():
		Materials.clock(materials[index], seconds, envelope * (0.55 if index == 0 else 0.7))
	var back: Vector3 = (source - recipient).normalized()
	var side: Vector3 = back.cross(Vector3.UP).normalized()
	if side.is_zero_approx():
		side = Vector3.RIGHT
	var measured: Array = recipient_geometry.get("points", [])
	for index in splinters.size():
		var angle: float = float(index) * 2.39996
		var direction: Vector3 = (side * cos(angle) + Vector3.UP * sin(angle) + back * 0.35).normalized()
		var start: Vector3 = recipient
		if not measured.is_empty() and outcome in ["hit", "crit"]:
			var point: Dictionary = measured[(index * 127 + 23) % measured.size()]
			var candidate: Vector3 = inverse * point.position
			if candidate.distance_to(recipient) < 0.35:
				start = candidate
				direction = (inverse.basis * point.normal).normalized()
		splinters[index].position = start + direction * seconds * 0.65
		splinters[index].basis = Basis(Quaternion(Vector3.UP, direction))
		splinters[index].scale = Vector3(0.8, 1.4, 0.8)
		splinters[index].show()
	last_center = recipient


func capture_observation() -> Dictionary:
	return {"phase": specification.phase, "selected_element": specification.element,
		"selected_side": specification.side, "source_scene": specification.scene,
		"source_author": "BinbunVFX", "center": last_center,
		"source": last_source, "recipient": last_recipient,
		"attack_outcome": specification.get("attack_outcome", ""),
		"recipient_surface_points": recipient_geometry.get("points", []).size(),
		"creates_surface": false, "applies_damage_or_condition": false,
		"retained_condition": false, "optical_lights": 0}

const VfxPackageIO_9632af18c9 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
