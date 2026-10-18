extends Node3D
## An autonomous spectral blade; independent occurrence phases, live aim and
## a blade-tip trail. The caster does not perform its follow-up attack.
const ResourceGraph = preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const NativePalette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")
const PathRibbon = preload("res://assets/vfx/sources/31348bd589e2d41ae443/path_ribbon.gd")
var specification: Dictionary
var endpoints: Array = []
var pivot: Node3D
var blade: MeshInstance3D
var trail: MeshInstance3D
var material: ShaderMaterial
var blade_height_cells: float
var age_seconds: float
var halo: MeshInstance3D
var impacts: Array[MeshInstance3D] = []
var owner_state: Dictionary = {}
var current_owner: Dictionary = {}


static func make_component(input: Dictionary) -> Node3D:
	var effect: Node3D = VfxPackageIO_c9d1d6e8de.resource("res://assets/vfx/sources/c9d1d6e8ded305efee38/spiritual_weapon.gd").new()
	effect.specification = input.duplicate(true)
	return effect


func set_live_endpoints(value: Array) -> void:
	endpoints = value.duplicate(true)
	if pivot != null:
		sample(age_seconds)


func set_owner_state(value: Dictionary) -> bool:
	# Only an explicitly supplied matching occurrence may change this instance.
	var expected: String = str(specification.get("owner_uuid", ""))
	if not expected.is_empty() and str(value.get("owner_uuid", "")) != expected:
		return false
	owner_state = value.duplicate(true)
	if pivot != null:
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
	pivot = Node3D.new()
	pivot.name = "AutonomousWeaponHilt"
	add_child(pivot)
	blade = MeshInstance3D.new()
	blade.name = "SpectralBlade"
	blade.mesh = VfxPackageIO_c9d1d6e8de.resource(specification.mesh)
	blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bounds: AABB = blade.mesh.get_aabb()
	blade_height_cells = float(specification.height_cells)
	var scale_factor: float = blade_height_cells / bounds.size.y
	blade.scale = Vector3.ONE * scale_factor
	# A real spectral blade still has volume when its broad face turns away.
	# Keep its source outline and hilt, with explicit game-scale cross-section.
	blade.scale.z = maxf(scale_factor, float(specification.get("blade_depth_cells", 0.10)) / bounds.size.z)
	blade.position.y = -bounds.position.y * scale_factor
	material = ResourceGraph.clone_value(VfxPackageIO_c9d1d6e8de.resource(specification.material_resource), {})
	var shader := Shader.new()
	var code: String = SourceMaterials.expand_shader(material.shader.code, material.shader.resource_path.get_base_dir())
	code = code.replace("TIME", "weapon_clock").replace("depth_draw_opaque", "depth_draw_never").replace("cull_back", "cull_disabled")
	code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform float weapon_clock=0.0;\nuniform float weapon_alpha=1.0;")
	shader.code = SourceMaterials.finish_fragment(code, "\nALPHA*=weapon_alpha;\n")
	SourceMaterials.replace_shader(material, shader)
	material.set_shader_parameter("Arua_Power", 2.3)
	material.set_shader_parameter("SPEED_Big_Line", 0.6)
	material.set_shader_parameter("fresnel", 0.35)
	material.set_shader_parameter("Has_mask", false)
	NativePalette.apply(material, specification.palette, {"quantize": false, "emission_gain": 0.18})
	blade.material_override = material
	pivot.add_child(blade)
	var surface_shader := Shader.new()
	var surface_code: String = material.shader.code.replace("shader_type spatial;", "shader_type spatial;\nvarying vec3 spectral_surface;\n")
	surface_code = SourceMaterials.finish_function(surface_code, "vertex", "\nspectral_surface=VERTEX;\n")
	surface_code = surface_code.replace("uniform float weapon_alpha=1.0;", "uniform float weapon_alpha=1.0;\nuniform float weapon_body_alpha_floor=0.52;")
	surface_code = SourceMaterials.finish_fragment(surface_code, "\nfloat surface_flow=texture(Distortion_Texture,spectral_surface.xy*vec2(3.0,0.5)+vec2(weapon_clock*.08,-weapon_clock*.18)).r;\nfloat surface_rim=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),1.8);\nALBEDO*=.65+.35*surface_flow;\nALPHA=max(ALPHA,weapon_alpha*weapon_body_alpha_floor)*(.75+.25*surface_flow);\n")
	surface_shader.code = surface_code
	SourceMaterials.replace_shader(material, surface_shader)
	material.set_shader_parameter("weapon_body_alpha_floor", float(specification.get("body_alpha_floor", 0.52)))
	halo = MeshInstance3D.new()
	halo.name = "MeasuredBladeSpiritEdge"
	halo.mesh = blade.mesh
	halo.transform = blade.transform
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.material_override = material.duplicate(true)
	var edge_shader := Shader.new()
	var edge_code: String = SourceMaterials.finish_function(material.shader.code, "vertex", "\nVERTEX+=NORMAL*.10;\n")
	edge_shader.code = SourceMaterials.finish_fragment(edge_code, "\nALPHA*=surface_rim*.3;\n")
	SourceMaterials.replace_shader(halo.material_override, edge_shader)
	pivot.add_child(halo)
	for index in 5:
		var impact := MeshInstance3D.new()
		impact.name = "ForceContact" + str(index)
		impact.material_override = material.duplicate(true)
		impact.material_override.set_shader_parameter("Has_mask", false)
		impact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(impact)
		impacts.append(impact)
	trail = MeshInstance3D.new()
	trail.name = "ActualBladeTipSweep"
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail.material_override = material.duplicate(true)
	trail.material_override.set_shader_parameter("Has_mask", false)
	add_child(trail)


func strike_basis(seconds: float, target: Vector3) -> Basis:
	var direction: Vector3 = (target - pivot.position).normalized()
	var contact := Quaternion(Vector3.UP, direction)
	var anticipation := Quaternion(Vector3.RIGHT, -0.35)
	var swing: float = smoothstep(0.16, 0.45, seconds)
	var recover: float = smoothstep(0.55, 1.0, seconds)
	var windup: Quaternion = Quaternion.IDENTITY.slerp(anticipation, smoothstep(0.0, 0.16, seconds))
	return Basis(windup.slerp(contact, swing).slerp(Quaternion.IDENTITY, recover))


func sample(seconds: float) -> void:
	if pivot == null:
		prepare()
	age_seconds = seconds
	current_owner = observed_owner(seconds)
	var owner_alpha: float = owner_visibility(current_owner)
	if endpoints.size() < 2:
		hide()
		return
	visible = owner_alpha > 0.001
	var origin: Vector3 = to_local(endpoints[0].point)
	var recipient: Vector3 = to_local(endpoints[1].point)
	pivot.position = origin + Vector3(0.0, 0.42, 0.0)
	var phase: String = specification.phase
	var opacity := owner_alpha
	if phase == "application":
		opacity = owner_alpha * smoothstep(0.0, 0.45, seconds)
		pivot.position.y -= 0.15 * (1.0 - opacity)
	elif phase == "retirement":
		opacity = owner_alpha * (1.0 - smoothstep(0.0, 0.5, seconds))
	pivot.basis = strike_basis(seconds, recipient) if phase == "strike" else Basis.IDENTITY
	material.set_shader_parameter("weapon_clock", float(current_owner.get("visual_age_seconds", seconds + float(specification.get("clock_offset_seconds", 0.0)))))
	material.set_shader_parameter("weapon_alpha", opacity * 0.85)
	var clock: float = float(current_owner.get("visual_age_seconds", seconds + float(specification.get("clock_offset_seconds", 0.0))))
	halo.material_override.set_shader_parameter("weapon_clock", clock)
	halo.material_override.set_shader_parameter("weapon_alpha", opacity * .65)
	var impact_age: float = seconds - 0.45
	for index in impacts.size():
		var impact: MeshInstance3D = impacts[index]
		impact.visible = phase == "strike" and bool(specification.get("contact_enabled", true)) and owner_alpha > 0.001 and impact_age >= 0.0 and impact_age < 0.35
		if not impact.visible:
			continue
		var points: Array[Vector3] = []
		var widths: Array[float] = []
		var angle: float = float(index) * TAU / 5.0
		var outward := Vector3(cos(angle), sin(angle), 0.0)
		for segment in 12:
			var progress: float = float(segment) / 11.0
			points.append(recipient + outward * progress * (0.16 + impact_age * 0.5) + Vector3(0.0, 0.0, sin(progress * PI) * 0.09))
			widths.append(0.025 * sin(progress * PI))
		if specification.get("gpu_paths",false):
			preload("res://assets/vfx/sources/34e0f9ed9a909885cd97/path_ribbon.gd").assign(impact,points,widths,Color.WHITE,Vector2(0,1),false)
		else:
			impact.mesh = PathRibbon.build(points, widths)
		impact.material_override.set_shader_parameter("weapon_clock", clock)
		impact.material_override.set_shader_parameter("weapon_alpha", owner_alpha * (1.0 - smoothstep(0.04, 0.35, impact_age)))
	trail.visible = phase == "strike" and owner_alpha > 0.001 and seconds > 0.16 and seconds < 0.65
	if trail.visible:
		var points: Array[Vector3] = []
		var widths: Array[float] = []
		for index in 16:
			var weight: float = float(index) / 15.0
			var sample_time: float = seconds - 0.14 * (1.0 - weight)
			points.append(pivot.position + strike_basis(sample_time, recipient) * Vector3.UP * blade_height_cells)
			widths.append(0.035 * sin(weight * PI))
		if specification.get("gpu_paths",false):
			preload("res://assets/vfx/sources/34e0f9ed9a909885cd97/path_ribbon.gd").assign(trail,points,widths,Color.WHITE,Vector2(0,1),false)
		else:
			trail.mesh = PathRibbon.build(points, widths)
		trail.material_override.set_shader_parameter("weapon_clock", seconds)
		trail.material_override.set_shader_parameter("weapon_alpha", 0.6 * owner_alpha)


func capture_observation() -> Dictionary:
	return {"phase": specification.phase, "height_cells": blade_height_cells,
		"optical_lights": 0, "caster_controls_followup": false,
		"independent_construct_owner": true, "age_seconds": age_seconds, "contact_enabled":specification.get("contact_enabled", true), "owner_uuid":specification.get("owner_uuid", ""), "state":current_owner.duplicate(true), "rule_solver":false, "construct_actor_uuid":specification.get("construct_actor_uuid", ""), "construct_hilt_world":pivot.global_position if pivot != null else Vector3.ZERO, "visible_contact_draws":impacts.filter(func(piece: Node3D) -> bool: return piece.visible).size(), "trail_visible":trail.visible if trail != null else false}

const VfxPackageIO_c9d1d6e8de = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
