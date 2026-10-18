extends Node3D
## Small radiant comet, target contact and the separately owned revealing wisp.
const Graph = preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Palette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")
const Ribbon = preload("res://assets/vfx/sources/31348bd589e2d41ae443/path_ribbon.gd")
var specification: Dictionary = {}
var endpoints: Array = []
var mote: Node3D
var draws: Array[MeshInstance3D] = []
var materials: Array[ShaderMaterial] = []
var trail: MeshInstance3D
var target_light: OmniLight3D
var launch_seconds: float = 0.35
var travel_seconds: float = 0.5
var launch_position := Vector3.ZERO
var launched: bool = false
var owner_state: Dictionary = {}
var age_seconds: float = 0.0
var current_owner: Dictionary = {}


static func make_component(input: Dictionary) -> Node3D:
	var effect: Node3D = VfxPackageIO_6a26750475.resource("res://assets/vfx/sources/6a26750475be495fd6d7/starry_wisp.gd").new()
	effect.specification = input.duplicate(true)
	effect.launch_seconds = float(input.get("launch_seconds", 0.35))
	effect.travel_seconds = float(input.get("travel_seconds", 0.5))
	return effect


func set_live_endpoints(value: Array) -> void:
	endpoints = value.duplicate(true)
	if mote != null:
		sample(age_seconds)


func set_delivery_timing(launch: float, travel: float) -> void:
	launch_seconds = launch
	travel_seconds = maxf(0.001, travel)


func set_owner_state(value: Dictionary) -> bool:
	# Only an explicitly supplied matching occurrence may change this instance.
	var expected: String = str(specification.get("owner_uuid", ""))
	if not expected.is_empty() and str(value.get("owner_uuid", "")) != expected:
		return false
	owner_state = value.duplicate(true)
	if mote != null:
		sample(age_seconds)
	return true


func observed_owner(seconds: float) -> Dictionary:
	# Fixture rows replay supplied observations; seconds never solve a rule/turn.
	var state: Dictionary = specification.get("state", {}).duplicate(true)
	for row in specification.get("review_owner_states", []):
		if seconds >= float(row.seconds):
			state.merge(row.state, true)
	if not owner_state.is_empty():
		state = owner_state.duplicate(true)
	var expected: String = str(specification.get("owner_uuid", ""))
	if expected.is_empty():
		return {"present": true, "observed": true, "suppressed": false, "visibility": 1.0}
	if str(state.get("owner_uuid", "")) != expected:
		return {"present": false, "observed": false, "suppressed": true, "visibility": 0.0}
	return state


func owner_visibility(state: Dictionary) -> float:
	if not bool(state.get("present", false)) or not bool(state.get("observed", false)) or bool(state.get("suppressed", true)):
		return 0.0
	return clampf(float(state.get("visibility", 1.0)), 0.0, 1.0)


func prepare() -> void:
	mote = Node3D.new()
	mote.name = "StarryMote"
	add_child(mote)
	var source: Node3D = VfxPackageIO_6a26750475.resource(specification.scene).instantiate()
	for path in ["Glow", "Flare"]:
		var original: MeshInstance3D = source.get_node(path)
		var draw := MeshInstance3D.new()
		draw.name = path
		draw.mesh = original.mesh
		draw.material_override = Graph.clone_value(original.material_override, {})
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material: ShaderMaterial = draw.material_override
		var shader := Shader.new()
		var token := RegEx.new()
		token.compile("\\bTIME\\b")
		shader.code = token.sub(SourceMaterials.expand_shader(material.shader.code, material.shader.resource_path.get_base_dir()), "wisp_clock", true).replace("shader_type spatial;", "shader_type spatial;\nuniform float wisp_clock=0.0;")
		shader.code = SourceMaterials.scaled_billboard(shader.code)
		SourceMaterials.replace_shader(material, shader)
		material.set_shader_parameter("proximity_fade", false)
		material.set_shader_parameter("emission_strength", 1.0)
		Palette.apply(material, specification.palette, {"quantize": false, "emission_gain": 0.5})
		mote.add_child(draw)
		draws.append(draw)
		materials.append(material)
	source.free()
	trail = MeshInstance3D.new()
	trail.name = "CometWake"
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail.material_override = materials[1].duplicate(true)
	trail.material_override.set_shader_parameter("billboard", false)
	trail.material_override.set_shader_parameter("use_mask3", false)
	var trail_shader := Shader.new()
	trail_shader.code = trail.material_override.shader.code.replace("blend_mix;", "blend_mix, cull_disabled;")
	SourceMaterials.replace_shader(trail.material_override, trail_shader)
	add_child(trail)
	target_light = OmniLight3D.new()
	target_light.name = "RecipientDimLight"
	target_light.omni_range = 2.0
	target_light.light_color = Color(specification.palette[3])
	target_light.light_energy = 0.0
	target_light.set_meta("factory_light_role", "optical")
	add_child(target_light)


func sample(seconds: float) -> void:
	if mote == null: prepare()
	age_seconds = seconds
	current_owner = observed_owner(seconds)
	var owner_alpha: float = owner_visibility(current_owner)
	target_light.light_energy = 0.0
	if endpoints.size() < 2:
		mote.hide()
		trail.hide()
		return
	var inverse := global_transform.affine_inverse()
	var source: Vector3 = inverse * endpoints[0].point
	var recipient: Vector3 = inverse * endpoints[1].point
	var envelope: float = 1.0
	var phase: String = specification.phase
	var clock: float = float(current_owner.get("visual_age_seconds", seconds + float(specification.get("source_time_offset", 0.0))))
	var contact_enabled: bool = bool(specification.get("contact_enabled", true))
	trail.hide()
	if phase == "delivery":
		if seconds < launch_seconds:
			launched = false
			mote.position = source
			envelope = smoothstep(0.0, launch_seconds, seconds)
		elif seconds < launch_seconds + travel_seconds:
			if not launched:
				launch_position = endpoints[2].point if endpoints.size() >= 3 else endpoints[0].point
				launched = true
			var progress: float = (seconds - launch_seconds) / travel_seconds
			var launch_local: Vector3 = inverse * launch_position
			mote.position = launch_local.lerp(recipient, progress)
			var points: Array[Vector3] = []
			var widths: Array[float] = []
			for index in 12:
				var weight: float = float(index) / 11.0
				var time: float = maxf(0.0, progress - (1.0 - weight) * 0.32)
				points.append(launch_local.lerp(recipient, time))
				widths.append(0.035 * pow(weight, 0.7))
			if specification.get("gpu_paths",false):
				preload("res://assets/vfx/sources/34e0f9ed9a909885cd97/path_ribbon.gd").assign(trail,points,widths,Color.WHITE,Vector2(0,1),false)
			else:
				trail.mesh = Ribbon.build(points, widths)
			trail.show()
		else:
			mote.position = recipient
			envelope = 1.0 - smoothstep(0.0, 0.42, seconds - launch_seconds - travel_seconds)
		mote.scale = Vector3.ONE * (0.14 if seconds < launch_seconds + travel_seconds or not contact_enabled else 0.35)
	else:
		mote.position = recipient + Vector3(cos(clock * PI) * 0.22, sin(clock * PI) * 0.12, sin(clock * PI) * 0.22)
		mote.scale = Vector3.ONE * 0.10
		if phase == "remove": envelope = 1.0 - smoothstep(0.0, 0.45, seconds)
		elif phase == "reveal": envelope = smoothstep(0.0, 0.25, seconds)
		target_light.position = recipient
		target_light.light_energy = 0.22 * envelope * owner_alpha if contact_enabled else 0.0
	envelope *= owner_alpha
	mote.visible = envelope > 0.001
	trail.visible = trail.visible and owner_alpha > 0.001
	for material in materials:
		material.set_shader_parameter("wisp_clock", clock)
		material.set_shader_parameter("alpha_multiplier", envelope)
	trail.material_override.set_shader_parameter("wisp_clock", clock)
	trail.material_override.set_shader_parameter("alpha_multiplier", 0.7 * owner_alpha)


func capture_observation() -> Dictionary:
	return {"source_scene": specification.scene, "source_author": "BinbunVFX embedded namespace",
		"phase": specification.phase, "live_endpoint_count": endpoints.size(),
		"condition_optical_radius_cells": 2.0, "light_energy": target_light.light_energy if target_light != null else 0.0,
		"native_layers": 2, "flight_ribbon_fins": 3, "surface_or_cage_created": false, "contact_enabled":specification.get("contact_enabled", true), "owner_uuid":specification.get("owner_uuid", ""), "optical_source_uuid":specification.get("optical_source_uuid", ""), "state":current_owner.duplicate(true), "rule_solver":false, "mote_world_position":mote.global_position if mote != null else Vector3.ZERO, "optical_world_position":target_light.global_position if target_light != null else Vector3.ZERO, "visual_clock":materials[0].get_shader_parameter("wisp_clock") if not materials.is_empty() else 0.0}

const VfxPackageIO_6a26750475 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
