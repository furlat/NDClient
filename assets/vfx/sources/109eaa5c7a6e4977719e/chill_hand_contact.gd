extends "res://assets/vfx/sources/a841c38a7f2c9593bff8/chill_hand_readable.gd"
## Second isolated corrective. Only the native muzzle flare's HDR colour and
## alpha change; its source mask/emission/size/motion and all hand layers stay.
var native_muzzle_colour := Color.WHITE
var bounded_muzzle_colour := Color.WHITE
var muzzle_material: StandardMaterial3D

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = construct("res://assets/vfx/sources/109eaa5c7a6e4977719e/chill_hand_contact.gd", input)
	var light: OmniLight3D = instance.subject.get_node("OmniLight3D")
	assert(is_zero_approx(light.light_energy), "Initial-zero Chill light contract changed")
	light.free()
	return instance

func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	var muzzle: GPUParticles3D = node.get_node("muzzle")
	var process: ParticleProcessMaterial = muzzle.process_material
	native_muzzle_colour = process.color
	var largest := maxf(native_muzzle_colour.r, maxf(native_muzzle_colour.g, native_muzzle_colour.b))
	var cap := float(parameters.muzzle_value_cap)
	assert(cap > 0.0 and cap <= 1.0)
	var factor := minf(1.0, cap / maxf(.00001, largest))
	bounded_muzzle_colour = Color(native_muzzle_colour.r * factor, native_muzzle_colour.g * factor, native_muzzle_colour.b * factor, native_muzzle_colour.a)
	# Preserve the source's hue, saturation, texture, additive operator, emitter
	# and native lifetime. Bound only the original HDR vertex energy before it
	# reaches the ordinary material/receiving pipeline. No manual gamma pass.
	process.color = bounded_muzzle_colour
	muzzle_material = muzzle.material_override
	var tint := muzzle_material.albedo_color
	tint.a *= clampf(float(parameters.muzzle_alpha), 0.0, 1.0)
	muzzle_material.albedo_color = tint

func capture_observation() -> Dictionary:
	var row := super.capture_observation()
	row.chill_muzzle_contact = {"native_process_colour":native_muzzle_colour,"bounded_process_colour":bounded_muzzle_colour,"material_alpha":muzzle_material.albedo_color.a,"native_mask":muzzle_material.albedo_texture.resource_path,"native_additive_operator_retained":muzzle_material.blend_mode == BaseMaterial3D.BLEND_MODE_ADD,"hand_smoke_portal_animation_unchanged":true,"optical_lights":0}
	return row
