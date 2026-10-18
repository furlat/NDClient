extends Node3D
## Archived ground strips/motes and source clock, with supplied finite activation.
## Finishing is a qualified live-3D derivative of the original post-raster pack.
const SourceFinish = preload("res://assets/vfx/sources/b80cef04b29a6a0ea421/accepted_recovery_finish_v190.gd")

var settings: Dictionary = {}
var owner_projection: Dictionary = {}
var activation_projection: Dictionary = {}
var geometry: Dictionary = {}
var pieces: Array[MeshInstance3D] = []
var motes: Array[MeshInstance3D] = []
var fit: Node3D
var source_noise: NoiseTexture2D
var sample_seconds := 0.0
var native_seconds := 0.0
var supplied_envelope := 0.0


static func make_component(input: Dictionary) -> Node3D:
	for key in ["source_shader", "source_noise", "mote_shader", "finish", "owner_projection", "activation_projection", "requires_frenzied_child", "gain"]:
		assert(input.has(key), "Accepted ground source needs explicit " + key)
	assert(float(input.gain) >= 0.0)
	var instance := preload("res://assets/vfx/sources/861a64dfc7b97476a8d9/accepted_ground_source_v191.gd").new()
	instance.settings = input.duplicate(true)
	assert(instance.set_owner_projection(input.owner_projection))
	assert(instance.set_activation_projection(input.activation_projection))
	instance._build()
	instance.sample(0.0)
	return instance


func set_owner_projection(value: Dictionary) -> bool:
	for key in ["actor_id", "owner_uuid", "behavior_id", "admitted", "begin_seconds", "removed_seconds"]:
		if not value.has(key):
			return false
	if str(value.actor_id).is_empty() or str(value.owner_uuid).is_empty():
		return false
	if not is_finite(float(value.begin_seconds)) or not is_finite(float(value.removed_seconds)):
		return false
	owner_projection = value.duplicate(true)
	if fit != null:
		sample(sample_seconds)
	return true


func set_activation_projection(value: Dictionary) -> bool:
	for key in ["actor_id", "action_uuid", "behavior_id", "admitted", "parent_owner_uuid", "begin_seconds"]:
		if not value.has(key):
			return false
	if not is_finite(float(value.begin_seconds)):
		return false
	activation_projection = value.duplicate(true)
	if fit != null:
		sample(sample_seconds)
	return true


func set_entity_geometry(value: Dictionary) -> void:
	geometry = value
	if fit != null:
		sample(sample_seconds)


func owner_admitted() -> bool:
	if not bool(owner_projection.get("admitted", false)) or str(owner_projection.get("behavior_id", "")) != "class_feature.barbarian.raging":
		return false
	if str(geometry.get("actor", "")) != str(owner_projection.actor_id) or geometry.get("points", []).size() < 8:
		return false
	if not bool(activation_projection.get("admitted", false)) or str(activation_projection.get("action_uuid", "")).is_empty():
		return false
	if str(activation_projection.actor_id) != str(owner_projection.actor_id) or str(activation_projection.parent_owner_uuid) != str(owner_projection.owner_uuid):
		return false
	if not is_equal_approx(float(activation_projection.begin_seconds), float(owner_projection.begin_seconds)):
		return false
	var required_action := "action.class.barbarian.frenzy" if bool(settings.requires_frenzied_child) else "action.class.barbarian.rage"
	if str(activation_projection.behavior_id) != required_action:
		return false
	if bool(settings.requires_frenzied_child):
		var child: Dictionary = owner_projection.get("frenzied_child", {})
		return bool(child.get("admitted", false)) and not str(child.get("owner_uuid", "")).is_empty() \
			and str(child.get("behavior_id", "")) == "class_feature.barbarian.frenzied" \
			and str(child.get("parent_owner_uuid", "")) == str(owner_projection.owner_uuid)
	return true


func _material(path: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = VfxPackageIO_861a64dfc7.text(path)
	assert(not shader.code.is_empty())
	material.shader = shader
	SourceFinish.apply(material, settings.finish)
	return material


func _build() -> void:
	fit = Node3D.new()
	fit.name = "AcceptedGroundSourceFrame"
	fit.scale.y = .816496580927726
	add_child(fit)
	source_noise = VfxPackageIO_861a64dfc7.resource(str(settings.source_noise)).duplicate(true)
	for index in 7:
		var strip := MeshInstance3D.new()
		strip.name = "AcceptedGroundStrip%d" % index
		strip.material_override = _material(str(settings.source_shader))
		strip.material_override.set_shader_parameter("flow_tex", source_noise)
		strip.material_override.set_shader_parameter("seed", float(index) * .173)
		strip.material_override.set_shader_parameter("side", 0.0)
		strip.material_override.set_shader_parameter("broad", 0.0)
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		strip.custom_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 2, 4))
		fit.add_child(strip)
		pieces.append(strip)
	for index in 12:
		var mote := MeshInstance3D.new()
		mote.name = "AcceptedGroundMote%d" % index
		var sphere := SphereMesh.new()
		sphere.radius = .018
		sphere.height = .036
		sphere.radial_segments = 4
		sphere.rings = 2
		mote.mesh = sphere
		mote.material_override = _material(str(settings.mote_shader))
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fit.add_child(mote)
		motes.append(mote)


func path_point(index: int, u: float, seconds: float) -> Vector3:
	var phase := TAU * seconds / 2.0
	var angle := float(index) * .9 + u * 1.6 + .12 * sin(phase + float(index))
	var radius := .25 + u * .60
	return Vector3(cos(angle) * radius, .025 + .02 * sin(u * PI), sin(angle) * radius)


func build_strip(index: int, seconds: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var offsets: Array = []
	for step in range(33):
		var u := float(step) / 32.0
		var point := path_point(index, u, seconds)
		var next := path_point(index, minf(u + .01, 1.0), seconds)
		var tangent := (next - point).normalized()
		var across := tangent.cross(Vector3.UP).normalized()
		if across.length() < .1:
			across = Vector3.RIGHT
		offsets.append([point - across * .065, point + across * .065])
	for step in 32:
		for coordinate in [Vector2i(step, 0), Vector2i(step, 1), Vector2i(step + 1, 1), Vector2i(step, 0), Vector2i(step + 1, 1), Vector2i(step + 1, 0)]:
			surface.set_uv(Vector2(float(coordinate.x) / 32.0, float(coordinate.y)))
			surface.add_vertex(offsets[coordinate.x][coordinate.y])
	return surface.commit()


func sample(seconds: float) -> void:
	sample_seconds = seconds
	var local := seconds - float(owner_projection.begin_seconds)
	# Original preview selects floor(t*32) of the two-second captured source.
	native_seconds = floorf(maxf(0.0, local) * 32.0) / 32.0
	supplied_envelope = 0.0
	var before_removal := float(owner_projection.removed_seconds) < 0.0 or seconds < float(owner_projection.removed_seconds)
	if owner_admitted() and before_removal and local >= 0.0:
		supplied_envelope = smoothstep(.1, .28, local) * (1.0 - smoothstep(.7, 1.05, local)) * float(settings.gain)
	visible = supplied_envelope > 0.0
	for index in pieces.size():
		pieces[index].mesh = build_strip(index, native_seconds)
		pieces[index].material_override.set_shader_parameter("clock", native_seconds)
		pieces[index].material_override.set_shader_parameter("strength", supplied_envelope)
	for index in motes.size():
		var phase := fmod(native_seconds / 2.0 + float(index) * .083333333333, 1.0)
		var angle := float(index) * 2.399963 + .14 * sin(native_seconds * PI)
		motes[index].position = Vector3(cos(angle) * .65, .02 + .03 * sin(phase * PI), sin(angle) * .65)
		motes[index].material_override.set_shader_parameter("source_alpha", .8 * sin(phase * PI) * supplied_envelope)


func capture_observation() -> Dictionary:
	return {
		"family": "accepted_finite_ground_source", "source_seconds": native_seconds,
		"source_clock": "original32fps", "source_loop_seconds": 2.0,
		"sample_seconds": sample_seconds, "supplied_envelope": supplied_envelope,
		"strip_count": pieces.size(), "strip_segments": 32, "original_mote_count": motes.size(),
		"actor_id": owner_projection.actor_id, "owner_uuid": owner_projection.owner_uuid,
		"action_uuid": activation_projection.action_uuid, "owner_admitted": owner_admitted(),
		"geometry_actor": geometry.get("actor", ""), "measured_points": geometry.get("points", []).size(),
		"fixed_source_scale": true, "source_gain": settings.gain, "source_finish": settings.finish,
		"native_depth_replaces_camera_half_bank": true, "post_raster_export_parity": false,
		"gameplay_rules_solver": false, "no_lights": true,
	}

const VfxPackageIO_861a64dfc7 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
