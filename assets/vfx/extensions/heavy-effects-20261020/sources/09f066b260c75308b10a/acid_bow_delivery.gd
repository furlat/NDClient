extends Node3D
## Arrow-shaped spell energy, drawn through a transient hand-bound acid bow.
## Extracts every visual mesh of the selected Javelin donor; no donor controller,
## animation player, showcase movement, light or gameplay is imported.
const Materials = preload("res://assets/vfx/extensions/late-20261020/sources/0f15a3f72a38e511db8c/acid_sickness_materials.gd")
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Geometry = preload("res://assets/vfx/extensions/late-20261020/sources/6da451cc20b3d3ad0c68/arcane_arrow_geometry.gd")
const Ribbon = preload("res://assets/vfx/sources/31348bd589e2d41ae443/path_ribbon.gd")

var specification: Dictionary = {}
var endpoints: Array = []
var launch_seconds: float = 0.3
var travel_seconds: float = 0.5
var missile: Node3D
var bow: Node3D
var native_draws: Array[MeshInstance3D] = []
var native_materials: Array[ShaderMaterial] = []
var bow_limbs: MeshInstance3D
var bow_limb_core: MeshInstance3D
var bow_string: MeshInstance3D
var bow_material: ShaderMaterial
var string_material: ShaderMaterial
var head_material: ShaderMaterial
var head_core_material: ShaderMaterial
var wake_material: ShaderMaterial
var drop_material: ShaderMaterial
var wakes: Array[MeshInstance3D] = []
var drops: Array[MeshInstance3D] = []
var last_tip := Vector3.ZERO
var last_source := Vector3.ZERO
var last_recipient := Vector3.ZERO
var last_bow_envelope: float = 0.0


static func make_component(input: Dictionary) -> Node3D:
	var effect: Node3D = VfxPackageIO_09f066b260.resource("res://assets/vfx/extensions/heavy-effects-20261020/sources/09f066b260c75308b10a/acid_bow_delivery.gd").new()
	effect.specification = input.duplicate(true)
	effect.launch_seconds = float(input.launch_seconds)
	effect.travel_seconds = float(input.travel_seconds)
	return effect


func set_live_endpoints(value: Array) -> void:
	endpoints = value


func set_delivery_timing(launch: float, travel: float) -> void:
	launch_seconds = maxf(0.0, launch)
	travel_seconds = maxf(0.001, travel)


func _material(path: String, gain: float, opacity_exponent: float = 1.0) -> ShaderMaterial:
	var material := Materials.load_selected(path, specification.palette, gain)
	var code: String = material.shader.code.replace("shader_type spatial;", "shader_type spatial;\nuniform float acid_shape_exponent=1.0;")
	code = code.replace("ALPHA *= projectile_envelope;", "ALPHA=pow(clamp(ALPHA,0.0,1.0),acid_shape_exponent);\nALPHA *= projectile_envelope;")
	var shader := Shader.new()
	shader.code = code
	SourceMaterials.replace_shader(material, shader)
	material.set_shader_parameter("acid_shape_exponent", opacity_exponent)
	material.set_shader_parameter("native_palette_exposure", 1.4)
	material.set_shader_parameter("billboard", false)
	return material


func prepare() -> void:
	missile = Node3D.new()
	missile.name = "LayeredAcidArrow"
	add_child(missile)
	var source: Node3D = VfxPackageIO_09f066b260.resource(specification.source_scene).instantiate()
	var conversion := Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.0, -0.58, 0.0))
	for label in ["Head", "Core", "Trail"]:
		var original: MeshInstance3D = source.get_node(label)
		var material: ShaderMaterial = Materials.extract(original.material_override, specification.palette, 0.24)
		material.set_shader_parameter("native_palette_exposure", 1.4)
		var draw := Materials.draw(missile, "Donor" + label, original.mesh, material)
		draw.transform = conversion * original.transform
		native_draws.append(draw)
		native_materials.append(material)
	source.free()
	head_material = _material(specification.head_material, 0.28, 0.55)
	var head := Materials.draw(missile, "CorrosiveBarbedHead", Geometry.barbed_head(0.9, 0.48), head_material)
	native_draws.append(head)
	head_core_material = _material(specification.core_material, 0.24, 0.7)
	var head_core := Materials.draw(missile, "SpectralArrowSilhouette", Geometry.barbed_head(0.86, 0.38), head_core_material)
	native_draws.append(head_core)
	bow = Node3D.new()
	bow.name = "HandBoundAcidBow"
	add_child(bow)
	bow_material = _material(specification.head_material, 0.18, 0.6)
	bow_material.set_shader_parameter("displacement_scale", 0.012)
	string_material = _material(specification.core_material, 0.18, 0.75)
	bow_limbs = Materials.draw(bow, "FlowingRecurveLimbs", null, bow_material)
	bow_limb_core = Materials.draw(bow, "SpectralRecurveCore", null, string_material)
	bow_string = Materials.draw(bow, "DrawnAcidString", null, string_material)
	wake_material = _material(specification.trail_material, 0.18, 0.65)
	drop_material = _material(specification.droplet_material, 0.18, 0.55)
	for index in 2:
		wakes.append(Materials.draw(missile, "CorrosiveFilament" + str(index), null, wake_material))
	var bead := SphereMesh.new()
	bead.radius = 0.025
	bead.height = 0.085
	bead.radial_segments = 8
	bead.rings = 4
	for index in 12:
		drops.append(Materials.draw(self, "ShedAcid" + str(index), bead, drop_material))
	_rebuild_bow(0.0)


func _rebuild_bow(tension: float) -> void:
	var points: Array[Vector3] = []
	var radii: Array[float] = []
	for index in 41:
		var weight: float = float(index) / 40.0
		var vertical: float = weight * 2.0 - 1.0
		# Recurved tips bend forwards again; the grip stays on the hand axis.
		var angle: float = vertical * PI * 0.5
		var along: float = 0.34 * (cos(angle) - 1.0) + 0.06 * pow(absf(vertical), 10.0)
		along -= tension * 0.06 * sin(absf(vertical) * PI)
		points.append(Vector3(0.0, along, sin(angle) * 0.58))
		radii.append(0.017 + 0.022 * pow(sin(weight * PI), 0.6))
	if specification.get("gpu_paths",false):
		preload("res://assets/vfx/extensions/heavy-effects-20261020/sources/abe6eb6721b80fc713e6/arcane_tube.gd").assign(bow_limbs,points, radii)
	else:
		bow_limbs.mesh = Geometry.tube(points, radii)
	var core_radii: Array[float] = []
	for radius in radii:
		core_radii.append(radius * 0.42)
	if specification.get("gpu_paths",false):
		preload("res://assets/vfx/extensions/heavy-effects-20261020/sources/abe6eb6721b80fc713e6/arcane_tube.gd").assign(bow_limb_core,points, core_radii)
	else:
		bow_limb_core.mesh = Geometry.tube(points, core_radii)
	var string_points: Array[Vector3] = [points[0], Vector3(0.0, -0.28 - tension * 0.2, 0.0), points[-1]]
	if specification.get("gpu_paths",false):
		preload("res://assets/vfx/extensions/heavy-effects-20261020/sources/abe6eb6721b80fc713e6/arcane_tube.gd").assign(bow_string,string_points, [0.006, 0.008, 0.006], 6)
	else:
		bow_string.mesh = Geometry.tube(string_points, [0.006, 0.008, 0.006], 6)


func _basis(direction: Vector3) -> Basis:
	var upright := Vector3.UP - direction * Vector3.UP.dot(direction)
	if upright.length_squared() < 0.001:
		upright = Vector3.BACK - direction * Vector3.BACK.dot(direction)
	upright = upright.normalized()
	return Basis(direction.cross(upright).normalized(), direction, upright)


func sample(seconds: float) -> void:
	if missile == null:
		prepare()
	missile.hide()
	bow.hide()
	for drop in drops:
		drop.hide()
	last_bow_envelope = 0.0
	if endpoints.size() < 2:
		return
	var inverse: Transform3D = global_transform.affine_inverse()
	var hand: Vector3 = inverse * endpoints[0].point
	var recipient: Vector3 = inverse * endpoints[1].point
	var source: Vector3 = inverse * endpoints[2].point if endpoints.size() >= 3 else hand
	var direction: Vector3 = (recipient - (hand if seconds < launch_seconds else source)).normalized()
	if direction.is_zero_approx():
		return
	last_source = source
	last_recipient = recipient
	var charge: float = smoothstep(0.0, maxf(launch_seconds, 0.001), seconds)
	var flight_age: float = seconds - launch_seconds
	var progress: float = clampf(flight_age / travel_seconds, 0.0, 1.0)
	var retiring: float = 1.0 - smoothstep(0.0, 0.10, flight_age - travel_seconds)
	var energy: float = charge * retiring
	if energy <= 0.001:
		return
	missile.position = hand if flight_age < 0.0 else source.lerp(recipient, progress)
	missile.basis = _basis(direction)
	var size: float = float(specification.projectile_scale) * (0.35 + charge * 0.65)
	var expansion: float = smoothstep(0.0, 0.065, flight_age)
	missile.scale = Vector3(lerpf(0.62, 1.0, expansion), lerpf(0.34, 1.0, expansion), lerpf(0.62, 1.0, expansion)) * size
	missile.show()
	last_tip = missile.position
	for draw in native_draws:
		draw.show()
	var projectile_energy: float = energy * lerpf(0.45, 1.0, expansion)
	for material in native_materials:
		Materials.clock(material, seconds, projectile_energy)
	Materials.clock(head_material, seconds, projectile_energy)
	Materials.clock(head_core_material, seconds, projectile_energy * 0.9)
	Materials.clock(wake_material, seconds, projectile_energy * 0.8)
	Materials.clock(drop_material, seconds, energy * 0.9)
	# The bow follows the posed hand during preparation, then stays at release.
	# Its limbs relax and dissolve as the actual missile leaves the string.
	last_bow_envelope = charge * (1.0 - smoothstep(0.0, 0.22, flight_age))
	bow.position = hand if flight_age < 0.0 else source
	bow.basis = _basis(direction)
	bow.scale = Vector3.ONE * (0.7 + 0.3 * charge)
	bow.visible = last_bow_envelope > 0.001
	bow_limbs.show()
	bow_limb_core.show()
	bow_string.show()
	_rebuild_bow(charge * (1.0 - smoothstep(0.0, 0.075, flight_age)))
	Materials.clock(bow_material, seconds, last_bow_envelope)
	Materials.clock(string_material, seconds, last_bow_envelope * 0.85)
	_update_wakes(seconds, maxf(flight_age, 0.0), charge)
	if flight_age > 0.0:
		_update_drops(seconds, flight_age, source, recipient, direction, inverse)


func _update_wakes(seconds: float, flight_age: float, charge: float) -> void:
	for strand in wakes.size():
		var points: Array[Vector3] = []
		var widths: Array[float] = []
		for index in 25:
			var weight: float = float(index) / 24.0
			var along: float = -0.28 - weight * (1.15 + minf(flight_age * 0.35, 0.3))
			var angle: float = weight * TAU * 0.65 + float(strand) * PI - seconds * 4.5
			var radius: float = sin(weight * PI) * 0.12 * charge
			points.append(Vector3(cos(angle) * radius, along, sin(angle) * radius))
			widths.append(0.045 * sin(weight * PI))
		if specification.get("gpu_paths",false):
			preload("res://assets/vfx/extensions/heavy-effects-20261020/sources/34e0f9ed9a909885cd97/path_ribbon.gd").assign(wakes[strand],points,widths,Color.WHITE,Vector2(0,1),false)
		else:
			wakes[strand].mesh = Ribbon.build(points, widths)
		wakes[strand].show()


func _update_drops(seconds: float, flight_age: float, source: Vector3, recipient: Vector3, direction: Vector3, inverse: Transform3D) -> void:
	var ground: float = (inverse * endpoints[3].point).y if endpoints.size() > 3 else recipient.y - 0.8
	var axes: Basis = _basis(direction)
	for index in drops.size():
		var emission_age: float = float(index) * 0.027
		var age: float = flight_age - emission_age
		if age < 0.0 or age > 0.26 or emission_age > travel_seconds:
			continue
		var origin: Vector3 = source.lerp(recipient, clampf(emission_age / travel_seconds, 0.0, 1.0))
		var angle: float = float(index) * 2.39996
		var drift: Vector3 = axes.x * sin(angle) * age * 0.35 + axes.z * cos(angle) * age * 0.25
		drops[index].position = origin + direction * age * 0.8 + drift - Vector3.UP * age * age * 1.4
		drops[index].scale = Vector3.ONE * (1.0 - age / 0.26)
		drops[index].visible = drops[index].position.y > ground + 0.02


func capture_observation() -> Dictionary:
	return {"phase": "delivery", "tip": last_tip, "source": last_source,
		"recipient": last_recipient, "native_source_visuals": ["Head", "Core", "Trail"],
		"source_scene": specification.source_scene, "bow_hand_bound": true,
		"bow_envelope": last_bow_envelope, "optical_lights": 0,
		"applies_damage_or_condition": false}

const VfxPackageIO_09f066b260 = preload("res://assets/vfx/extensions/heavy-effects-20261020/scoped_resource_io.gd")
