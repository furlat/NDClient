extends "res://assets/vfx/sources/3eeeebacf2494b475d88/sunbeam.gd"
## Independent receiving phase from Sunbeam's own native muzzle texture,
## shader, particle curve and palette; no second beam or gameplay light.
const ContactBindings = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
var flash: GPUParticles3D
var fired: bool = false


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/6c2f1f4ebacf2eaa0f07/solar_contact.gd", input)


func apply_scene_edits(node: Node) -> void:
	var donor: Node3D = DonorScene.instantiate(VfxPackageIO_6c2f1f4eba.resource(settings.source_path), [])
	ResourceGraph.isolate_node(donor, {})
	node.add_child(donor)
	prepare_beam(donor)
	flash = donor.get_node("muzzle")
	donor.remove_child(flash)
	node.add_child(flash)
	donor.free()
	flash.name = "ReceivingSolarFlare"
	flash.position = Vector3.ZERO
	flash.scale = Vector3.ONE * float(parameters.contact_scale)
	flash.emitting = false
	flash.speed_scale = 1.0
	flash.local_coords = true
	flash.fixed_fps = int(parameters.simulation_hz)
	flash.seed = int(parameters.seed)
	var material: ShaderMaterial = flash.material_override
	var code: String = material.shader.code
	var beam_crop := "vec3 solar_world=(INV_VIEW_MATRIX*vec4(VERTEX,1.)).xyz;float along=dot(solar_world-beam_origin,beam_axis);if(along<0.||along>12.)discard;float reach=12.*smoothstep(.30,.62,source_clock);if(along>reach)discard;"
	assert(code.count(beam_crop) == 1, "Solar source crop changed")
	var shader := Shader.new()
	shader.code = ContactBindings.stable_proximity(code.replace(beam_crop, ""))
	ContactBindings.replace_shader(material, shader)
	mats.clear()
	mats.append(material)


func advance_lifecycle(_delta: float) -> void:
	tick += 1
	var age: float = float(tick) / float(parameters.simulation_hz)
	if not fired:
		flash.restart()
		flash.emitting = true
		fired = true
	for material in mats:
		material.set_shader_parameter("source_clock", age)


func capture_observation() -> Dictionary:
	return {
		"native_tick": tick,
		"recipient_flare_fired": fired,
		"original_muzzle_lifetime_seconds": flash.lifetime,
		"contact_scale": parameters.contact_scale,
		"new_lights": 0,
	}

const VfxPackageIO_6c2f1f4eba = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
