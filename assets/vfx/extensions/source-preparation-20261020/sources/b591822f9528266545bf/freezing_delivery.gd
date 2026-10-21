extends "res://assets/vfx/extensions/source-preparation-20261020/sources/b82a0d5a067fb8aabb72/delivery.gd"
## Inspected native faceted ice globe and its mist, on the supplied hand/path.
const DonorScene = preload("res://assets/vfx/sources/7fb2e55699a318c2dafb/donor_scene.gd")
const ICE_SCENE = "res://assets/vfx/extensions/source-preparation-20261020/sources/633d6f183e88c435bc7c/ice_ball_vfx_03.tscn"
const ICE_CONTROLLER = "res://assets/vfx/sources/b5b38e908a188529d3aa/vfx_controller.gd"
var mist: GPUParticles3D
var mist_material: ShaderMaterial


static func make_component(input: Dictionary) -> Node3D:
	assert(input.kind == "freezing")
	var node: Node3D = VfxPackageIO_b591822f95.resource("res://assets/vfx/extensions/source-preparation-20261020/sources/b591822f9528266545bf/freezing_delivery.gd").new()
	node.specification = input.duplicate(true)
	node.prepare()
	return node


func prepare() -> void:
	if not draws.is_empty():
		return
	var source: Node3D = DonorScene.instantiate(VfxPackageIO_b591822f95.resource(ICE_SCENE), [ICE_CONTROLLER])
	Native.Graph.native_sampler_scopes += 1
	Native.Graph.isolate_node(source, {})
	Native.Graph.native_sampler_scopes -= 1
	for part_name in ["Core", "Surface"]:
		var part: MeshInstance3D = source.get_node(part_name)
		var adapted: ShaderMaterial = Native.finite(part.material_override, .46 if part_name == "Core" else .32)
		var part_shader := Shader.new()
		part_shader.code = adapted.shader.code.replace("clamp(0.5 - (alpha_smoothness * .5), 0.5 + (alpha_smoothness * .5), mask_value)", "clamp(mask_value,0.5 - (alpha_smoothness * .5),0.5 + (alpha_smoothness * .5))")
		Native.Source.replace_shader(adapted, part_shader)
		adapted.set_shader_parameter("alpha_mode", 0)
		adapted.set_shader_parameter("emission_strength", 1.0)
		materials.append(adapted)
		draws.append(Native.draw(self, "NativeIce" + part_name, part.mesh, adapted))
		draws.back().top_level = true
	mist = source.get_node("Mist")
	mist.owner = null
	source.remove_child(mist)
	add_child(mist)
	mist.top_level = true
	mist.local_coords = true
	mist.use_fixed_seed = true
	mist.seed = 62817
	mist.fixed_fps = 144
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mist_material = Native.finite(mist.material_override, .35)
	mist_material.set_shader_parameter("alpha_multiplier", .55)
	var shader := Shader.new()
	shader.code = Native.Source.scaled_billboard(mist_material.shader.code).replace("clamp(0.5 - (alpha_smoothness * .5), 0.5 + (alpha_smoothness * .5), mask_value)", "clamp(mask_value,0.5 - (alpha_smoothness * .5),0.5 + (alpha_smoothness * .5))")
	Native.Source.replace_shader(mist_material, shader)
	mist.material_override = mist_material
	# The discarded demo root contains the source light and animation envelope.
	# The accepted delivery envelope below owns preparation, flight and contact.
	source.free()


func sample(seconds: float) -> void:
	super.sample(seconds)
	var alpha: float = smoothstep(0.0, .18, seconds)
	if not bool(specification.get("cast_or_throw_accepted", false)) or endpoints.size() < 3 or seconds >= launch_seconds + travel_seconds:
		alpha = 0.0
	mist.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * .26), point)
	mist.visible = alpha > .001
	mist.emitting = alpha > .001
	Native.clock(mist_material, seconds, alpha * .45)


func capture_observation() -> Dictionary:
	var result: Dictionary = super.capture_observation()
	result["native_source_scene"] = ICE_SCENE
	result["native_shape_layers"] = ["Core", "Surface", "Mist"]
	result["generic_sphere_replacement"] = false
	return result

const VfxPackageIO_b591822f95 = preload("res://assets/vfx/extensions/source-preparation-20261020/scoped_resource_io.gd")
