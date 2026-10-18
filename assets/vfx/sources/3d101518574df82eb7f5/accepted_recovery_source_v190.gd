extends Node3D
## Exact archived heal path/radial strip frame/Flow equations. Explicit supplied
## successful self-heal owns one finite occurrence. No rules or stage inference.
const SourceFinish = preload("res://assets/vfx/sources/b80cef04b29a6a0ea421/accepted_recovery_finish_v190.gd")

var settings: Dictionary = {}
var owner_projection: Dictionary = {}
var geometry: Dictionary = {}
var pieces: Array[MeshInstance3D] = []
var motes: Array[MeshInstance3D] = []
var fit: Node3D
var source_noise: NoiseTexture2D
var sample_seconds := 0.0
var native_seconds := 0.0
var source_strength := 0.0


static func make_component(input: Dictionary) -> Node3D:
	for key in ["source_shader", "source_noise", "mote_shader", "finish", "owner_projection", "source_seconds"]:
		assert(input.has(key), "Recovery source needs explicit " + key)
	var instance := preload("res://assets/vfx/sources/3d101518574df82eb7f5/accepted_recovery_source_v190.gd").new()
	instance.settings = input.duplicate(true)
	assert(is_equal_approx(float(instance.settings.source_seconds), 1.5), "Archived nonloop heal source is 1.5 seconds")
	assert(instance.set_owner_projection(input.owner_projection))
	instance._build()
	instance.sample(0.0)
	return instance


func set_owner_projection(value: Dictionary) -> bool:
	for key in ["actor_id", "actor_uuid", "action_uuid", "behavior_id", "admitted", "begin_seconds", "healing"]:
		if not value.has(key):
			return false
	if str(value.actor_id).is_empty() or str(value.actor_uuid).is_empty() or str(value.action_uuid).is_empty():
		return false
	if not value.healing is Dictionary:
		return false
	owner_projection = value.duplicate(true)
	if fit != null:
		sample(sample_seconds)
	return true


func set_entity_geometry(value: Dictionary) -> void:
	geometry = value
	if fit != null:
		sample(sample_seconds)


func owner_admitted() -> bool:
	if not bool(owner_projection.get("admitted", false)) or str(owner_projection.get("behavior_id", "")) != "action.class.fighter.second_wind":
		return false
	if str(geometry.get("actor", "")) != str(owner_projection.actor_id) or geometry.get("points", []).size() < 8:
		return false
	var healing: Dictionary = owner_projection.healing
	return bool(healing.get("observed_completion", false)) and not str(healing.get("event_uuid", "")).is_empty() \
		and int(healing.get("actual_healing", 0)) > 0 and not bool(healing.get("was_blocked", true)) \
		and str(healing.get("parent_event_uuid", "")) == str(owner_projection.action_uuid) \
		and str(healing.get("source_entity_uuid", "")) == str(owner_projection.actor_uuid) \
		and str(healing.get("target_entity_uuid", "")) == str(owner_projection.actor_uuid)


func _material(path: String) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = VfxPackageIO_3d10151857.text(path)
	assert(not shader.code.is_empty())
	result.shader = shader
	SourceFinish.apply(result, settings.finish)
	return result


func _build() -> void:
	fit = Node3D.new()
	fit.name = "AcceptedRecoveryFit"
	fit.scale.y = .816496580927726
	add_child(fit)
	source_noise = VfxPackageIO_3d10151857.resource(str(settings.source_noise)).duplicate(true)
	for index in 6:
		var piece := MeshInstance3D.new()
		piece.name = "AcceptedRadialStrip%d" % index
		piece.material_override = _material(str(settings.source_shader))
		piece.material_override.set_shader_parameter("flow_tex", source_noise)
		piece.material_override.set_shader_parameter("seed", float(index) * .173)
		piece.material_override.set_shader_parameter("side", 0.0)
		piece.material_override.set_shader_parameter("broad", 0.0)
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.custom_aabb = AABB(Vector3(-4, -2, -4), Vector3(8, 8, 8))
		fit.add_child(piece)
		pieces.append(piece)
	for index in 12:
		var mote := MeshInstance3D.new()
		mote.name = "OriginalRecoveryMote%d" % index
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
	var angle := float(index) * 1.047 + .25 * sin(phase + u * 2.0)
	var radius := .22 + .07 * sin(u * PI)
	return Vector3(cos(angle) * radius, u * 1.32, sin(angle) * radius)


func build_strip(index: int, seconds: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var offsets: Array = []
	var across := Vector3(cos(float(index) * 1.047), 0, sin(float(index) * 1.047))
	for step in range(33):
		var u := float(step) / 32.0
		var point := path_point(index, u, seconds)
		offsets.append([point - across * .065, point + across * .065])
	for step in 32:
		for coordinate in [Vector2i(step, 0), Vector2i(step, 1), Vector2i(step + 1, 1), Vector2i(step, 0), Vector2i(step + 1, 1), Vector2i(step + 1, 0)]:
			surface.set_uv(Vector2(float(coordinate.x) / 32.0, float(coordinate.y)))
			surface.add_vertex(offsets[coordinate.x][coordinate.y])
	return surface.commit()


func _fit_actual_geometry() -> void:
	if geometry.get("points", []).is_empty():
		return
	var inverse := global_transform.affine_inverse()
	var low := INF
	var high := -INF
	var radius := 0.0
	for support in geometry.points:
		var point: Vector3 = inverse * support.position
		low = minf(low, point.y)
		high = maxf(high, point.y)
		radius = maxf(radius, Vector2(point.x, point.z).length())
	# Retain the existing native host's measured actor-size normalization. This
	# is disclosed fitting, not the archived fixed-bank actor projection.
	var horizontal := clampf(radius / .38, .65, 2.5)
	fit.scale = Vector3(horizontal, clampf(high - low, .65, 3.0) * .81649658, horizontal)
	fit.position.y = low


func sample(seconds: float) -> void:
	sample_seconds = seconds
	native_seconds = seconds - float(owner_projection.begin_seconds)
	_fit_actual_geometry()
	visible = owner_admitted() and native_seconds >= 0.0 and native_seconds < float(settings.source_seconds)
	source_strength = smoothstep(0.0, .16, native_seconds) * (1.0 - smoothstep(1.0, 1.5, native_seconds)) if visible else 0.0
	for index in pieces.size():
		pieces[index].mesh = build_strip(index, native_seconds)
		pieces[index].material_override.set_shader_parameter("clock", native_seconds)
		pieces[index].material_override.set_shader_parameter("strength", source_strength)
	for index in motes.size():
		var phase := fmod(native_seconds / 2.0 + float(index) * .083333333333, 1.0)
		var angle := float(index) * 2.399963 + .14 * sin(native_seconds * PI)
		motes[index].position = Vector3(cos(angle) * .32, .06 + phase * 1.14, sin(angle) * .32)
		# Exact accepted source mote alpha has no heal envelope. The original
		# exported nonloop 1.5-second occurrence clips these small motes at end.
		motes[index].material_override.set_shader_parameter("source_alpha", .8 * sin(phase * PI) if visible else 0.0)


func capture_observation() -> Dictionary:
	return {
		"family": "accepted_recovery_radial_source", "source_seconds": native_seconds,
		"strip_count": pieces.size(), "strip_segments": 32, "original_mote_count": motes.size(),
		"source_strength": source_strength, "owner_admitted": owner_admitted(),
		"action_uuid": owner_projection.action_uuid, "actor_id": owner_projection.actor_id,
		"geometry_actor": geometry.get("actor", ""), "measured_points": geometry.get("points", []).size(),
		"source_finish": settings.finish.kind, "post_raster_export_parity": false,
		"native_depth_replaces_camera_half_bank": true, "gameplay_rules_solver": false,
		"no_lights": true, "finite_original_nonloop_seconds": settings.source_seconds,
	}

const VfxPackageIO_3d10151857 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
