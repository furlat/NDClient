extends Node3D
## One compact chosen-element bolt; recorded extra dice affect only this impact.
const Materials = preload("res://assets/vfx/sources/782125cbcfc15cad7fd7/orb_burst_materials.gd")
const Ribbon = preload("res://assets/vfx/sources/31348bd589e2d41ae443/path_ribbon.gd")

var specification: Dictionary = {}
var endpoints: Array = []
var pivot: Node3D
var heads: Array[MeshInstance3D] = []
var fragments: Array[MeshInstance3D] = []
var materials: Array[ShaderMaterial] = []
var wake: MeshInstance3D
var launch_seconds: float = 0.3
var travel_seconds: float = 0.38
var native_front: float = 0.0
var last_front := Vector3.ZERO
var last_recipient := Vector3.ZERO
var last_source := Vector3.ZERO


static func make_component(input: Dictionary) -> Node3D:
	assert(input.get("element", "") in ["acid", "cold", "fire", "lightning", "poison", "psychic", "thunder"], "Burst requires an explicitly selected element")
	var node: Node3D = VfxPackageIO_e4239bb3cb.resource("res://assets/vfx/sources/e4239bb3cbe524a9967c/sorcerous_burst.gd").new()
	node.specification = input.duplicate(true)
	node.launch_seconds = float(input.get("launch_seconds", 0.3))
	node.travel_seconds = float(input.get("travel_seconds", 0.38))
	return node


func set_live_endpoints(value: Array) -> void:
	endpoints = value


func set_delivery_timing(launch: float, travel: float) -> void:
	launch_seconds = maxf(launch, 0.0)
	travel_seconds = maxf(travel, 0.001)


func prepare() -> void:
	var donor: Node3D = VfxPackageIO_e4239bb3cb.resource(specification.scene).instantiate()
	pivot = Node3D.new()
	pivot.name = "CompactElementalBolt"
	add_child(pivot)
	for name in ["TBHead_inner", "TBHead"]:
		var source: MeshInstance3D = donor.get_node(name)
		var material: ShaderMaterial = Materials.extract(source.material_override, specification.palette, 0.08, true)
		material.set_shader_parameter("Wave_Intensity", 0.28)
		materials.append(material)
		var draw: MeshInstance3D = Materials.draw(pivot, name, source.mesh, material)
		draw.transform = source.transform
		heads.append(draw)
		var bounds: AABB = source.transform * source.mesh.get_aabb()
		native_front = maxf(native_front, bounds.end.z)
	for draw in heads:
		draw.position.z -= native_front
	var source_wake: MeshInstance3D = donor.get_node("Trail1_static")
	var flow: ShaderMaterial = Materials.extract(source_wake.material_override, specification.palette, 0.05)
	materials.append(flow)
	wake = Materials.draw(self, "ShortNativeFlowWake", null, flow)
	# The native wave is authored for this mesh's UV/size. Putting it on tiny
	# unit-scaled spheres produced expanding blobs and intermittent pops in v56.
	var contact_source: MeshInstance3D = donor.get_node("TBHead_inner")
	var contact: ShaderMaterial = Materials.extract(contact_source.material_override, specification.palette, 0.08, true)
	contact.set_shader_parameter("Wave_Intensity", 0.06)
	materials.append(contact)
	for index in 8:
		fragments.append(Materials.draw(self, "ElementalSplinter" + str(index), contact_source.mesh, contact))
	donor.free()


func sample(seconds: float) -> void:
	if pivot == null:
		prepare()
	for draw in heads + fragments:
		draw.hide()
	wake.hide()
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
		_sample_impact(seconds, recipient, source)
		return
	var direction: Vector3 = (recipient - source).normalized()
	if direction.is_zero_approx():
		return
	var preparing: bool = seconds < launch_seconds
	var along: float = clampf((seconds - launch_seconds) / travel_seconds, 0.0, 1.0)
	var after_contact: float = seconds - launch_seconds - travel_seconds
	var envelope: float = smoothstep(0.0, maxf(launch_seconds, 0.001), seconds) if preparing else 1.0 - smoothstep(0.0, 0.13, after_contact)
	if envelope <= 0.001:
		return
	pivot.position = hand if preparing else source.lerp(recipient, along)
	pivot.basis = Basis(Quaternion(Vector3.BACK, direction))
	pivot.scale = Vector3.ONE * (0.13 * (0.35 + 0.65 * envelope) if preparing else 0.13)
	last_front = pivot.position
	for draw in heads:
		draw.show()
	Materials.clock(materials[0], seconds, envelope * 0.72)
	Materials.clock(materials[1], seconds, envelope * 0.58)
	if preparing or along < 0.001:
		return
	var length_fraction: float = minf(along, 0.48 / maxf(source.distance_to(recipient), 0.001))
	var points: Array[Vector3] = []
	var widths: Array[float] = []
	for index in 18:
		var weight: float = float(index) / 17.0
		points.append(source.lerp(recipient, along - length_fraction * (1.0 - weight)))
		widths.append(0.045 * sin(weight * PI))
	if specification.get("gpu_paths",false):
		preload("res://assets/vfx/sources/34e0f9ed9a909885cd97/path_ribbon.gd").assign(wake,points,widths,Color.WHITE,Vector2(0,1),true)
	else:
		wake.mesh = Materials.axial_uv(Ribbon.build(points, widths))
	wake.show()
	Materials.clock(materials[2], seconds, envelope * 0.45)


func _sample_impact(seconds: float, recipient: Vector3, source: Vector3) -> void:
	if not specification.get("attack_outcome", "") in ["hit", "crit"]:
		return
	var envelope: float = smoothstep(0.0, 0.025, seconds) * (1.0 - smoothstep(0.08, 0.36, seconds))
	if envelope <= 0.001:
		return
	var back: Vector3 = (source - recipient).normalized()
	var side: Vector3 = back.cross(Vector3.UP).normalized()
	if side.is_zero_approx():
		side = Vector3.RIGHT
	# Optional admitted roll metadata changes one bounded local accent. It never
	# schedules another projectile, hit rider, damage event or recursive impact.
	var recorded_extra: int = maxi(0, int(specification.get("recorded_extra_dice", 0)))
	var accent: float = 1.0 + minf(float(recorded_extra), 4.0) * 0.06
	for index in fragments.size():
		var angle: float = float(index) * 2.39996
		var direction: Vector3 = (side * cos(angle) + Vector3.UP * sin(angle) + back * 0.35).normalized()
		fragments[index].position = recipient + direction * seconds * (0.35 + float(index % 3) * 0.12) * accent
		fragments[index].basis = Basis(Quaternion(Vector3.FORWARD, direction))
		fragments[index].scale = Vector3(0.08, 0.08, 0.10) * accent
		fragments[index].show()
	Materials.clock(materials[3], 0.16 + seconds * 0.2, envelope * 0.7)
	last_front = recipient


func capture_observation() -> Dictionary:
	return {"phase": specification.phase, "selected_element": specification.element,
		"source_scene": specification.scene, "source_author": "LeLu",
		"front": last_front, "source": last_source, "recipient": last_recipient,
		"attack_outcome": specification.get("attack_outcome", ""),
		"recorded_extra_dice": specification.get("recorded_extra_dice", null),
		"traveling_projectiles": 1, "applies_damage_or_condition": false,
		"retained_condition": false, "optical_lights": 0}

const VfxPackageIO_e4239bb3cb = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
