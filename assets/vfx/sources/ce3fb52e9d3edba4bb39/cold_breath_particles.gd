extends "res://assets/vfx/sources/2f6628255a3170c06996/dragons_breath.gd"
## The inspected Binbun Core/Mist emitters breathe from the current face.
## Grant ownership, retained element and action admission remain inherited.
const DonorScene = preload("res://assets/vfx/sources/7fb2e55699a318c2dafb/donor_scene.gd")
const MIST_SCENE = "res://assets/vfx/sources/06788cda4d826eb97b05/ice_mist_vfx_04.tscn"
const CONTROLLER = "res://assets/vfx/sources/b5b38e908a188529d3aa/vfx_controller.gd"

var plume: Node3D
var plume_materials: Array[ShaderMaterial] = []
var plume_emitters: Array[GPUParticles3D] = []


static func make_component(input: Dictionary) -> Node3D:
	assert(input.element == "cold" and input.phase == "exhale")
	assert(not str(input.get("grant_uuid", "")).is_empty())
	assert(not str(input.get("recipient_uuid", "")).is_empty())
	var node: Node3D = VfxPackageIO_ce3fb52e9d.resource("res://assets/vfx/sources/ce3fb52e9d3edba4bb39/cold_breath_particles.gd").new()
	node.specification = input.duplicate(true)
	node.set_grant_state(input.get("state", {}))
	node.prepare_plume()
	return node


func prepare_plume() -> void:
	plume = DonorScene.instantiate(VfxPackageIO_ce3fb52e9d.resource(MIST_SCENE), [CONTROLLER])
	Native.Graph.native_sampler_scopes += 1
	Native.Graph.isolate_node(plume, {})
	Native.Graph.native_sampler_scopes -= 1
	# The source controller only drives its material envelopes. The occurrence
	# owns those clocks; native masks, two meshes and particle colours survive.
	plume.get_node("AnimationPlayer").free()
	add_child(plume)
	plume.top_level = true
	for index in 2:
		var emitter: GPUParticles3D = plume.get_node("Core" if index == 0 else "Mist")
		var source_material: ShaderMaterial = emitter.material_override
		var adapted: ShaderMaterial = Native.finite(source_material, .3 if index == 0 else .65, MIST_SCENE + ("::Core" if index == 0 else "::Mist"))
		var code: String = Native.Source.scaled_billboard(adapted.shader.code)
		# Keep all three native masks. Cubing their product left isolated ice
		# points; the mist layer needs the lower-opacity connective wisps too.
		code = code.replace("pow(alpha_mask, 3.0)", "pow(max(alpha_mask,0.0),1.15)")
		code = code.replace("render_mode blend_mix;", "render_mode blend_mix,unshaded,cull_disabled,depth_draw_never;")
		code = code.replace("uniform float ward_alpha=0.0;", """uniform float ward_alpha=0.0;
uniform vec3 plume_origin=vec3(0.0);
uniform vec3 plume_forward=vec3(0.0,0.0,-1.0);
varying vec3 plume_world;
""")
		code = Native.Source.finish_function(code, "vertex", "\nplume_world=(INV_VIEW_MATRIX*MODELVIEW_MATRIX*vec4(VERTEX,1.0)).xyz;\n")
		code = Native.Source.finish_fragment(code, """
vec3 offset=plume_world-plume_origin;
float along=dot(offset,plume_forward);
float radial=length(offset-plume_forward*along);
float width=max(.075,along*.5);
ALPHA*=smoothstep(-.025,.035,along)*(1.0-smoothstep(2.75,3.0,along));
ALPHA*=1.0-smoothstep(max(.02,width-.18),width,radial);
""")
		var shader := Shader.new()
		shader.code = code
		Native.Source.replace_shader(adapted, shader)
		adapted.set_shader_parameter("emission_strength", .35)
		emitter.material_override = adapted
		plume_materials.append(adapted)
		emitter.use_fixed_seed = true
		emitter.seed = 7273 + index
		emitter.fixed_fps = 144
		emitter.local_coords = false
		emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		emitter.preprocess = 0.0
		emitter.lifetime = .58
		emitter.amount = 16 if index == 0 else 80
		var process: ParticleProcessMaterial = emitter.process_material
		process.emission_sphere_radius = .035
		process.emission_shape_scale = Vector3.ONE
		process.direction = Vector3.FORWARD
		process.spread = 16.0 if index == 0 else 24.0
		process.initial_velocity_min = 4.0
		process.initial_velocity_max = 5.6
		process.scale_min = .13 if index == 0 else .28
		process.scale_max = .24 if index == 0 else .48
		emitter.emitting = false
		plume_emitters.append(emitter)
	plume.hide()


func sample(seconds: float) -> void:
	active = false
	plume.hide()
	var admitted: bool = Native.observed(state) and endpoints.size() >= 4
	admitted = admitted and bool(state.get("recipient_action_discovered", false))
	admitted = admitted and str(specification.get("acting_recipient_uuid", "")) == str(specification.recipient_uuid)
	var emitting: bool = admitted and seconds >= 0.0 and seconds < .56
	for emitter in plume_emitters:
		emitter.emitting = emitting
	if not admitted:
		return
	origin = endpoints[1].point
	var direction: Vector3 = endpoints[3].point - origin
	if direction.is_zero_approx():
		return
	heading = direction.normalized()
	var up: Vector3 = Vector3.RIGHT if absf(heading.dot(Vector3.UP)) > .99 else Vector3.UP
	plume.global_transform = Transform3D(Basis.looking_at(heading, up), origin)
	var alpha: float = smoothstep(0.0, .045, seconds) * (1.0 - smoothstep(.82, 1.08, seconds))
	for index in plume_materials.size():
		var adapted: ShaderMaterial = plume_materials[index]
		Native.clock(adapted, seconds, alpha * (.28 if index == 0 else 1.0))
		adapted.set_shader_parameter("plume_origin", origin)
		adapted.set_shader_parameter("plume_forward", heading)
	plume.visible = alpha > .001
	active = plume.visible


func capture_observation() -> Dictionary:
	return {"phase": "exhale", "grant_uuid": specification.grant_uuid,
		"recipient_uuid": specification.recipient_uuid, "original_caster_uuid": specification.original_caster_uuid,
		"origin": origin, "heading": heading, "range_cells": 3.0, "visible": active,
		"source_scene": MIST_SCENE, "native_layers": ["Core", "Mist"],
		"source_socket": "face", "receiver_socket": "body_center", "optical_lights": 0,
		"solves_area_save_damage_or_surface": false, "seek_qualified": false}

func source_bindings() -> Dictionary:
	# This source retains actual GPU emitters. Use the source sampler's emitter
	# registration; the inherited single-static-mesh shortcut does not apply.
	return {}

const VfxPackageIO_ce3fb52e9d = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
