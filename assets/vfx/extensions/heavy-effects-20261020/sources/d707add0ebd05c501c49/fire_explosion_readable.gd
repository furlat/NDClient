extends "res://assets/vfx/extensions/heavy-effects-20261020/sources/138cd535f8be5f7a7ac8/fire_explosion.gd"
## Preserve all five donor layers while subordinating the flash and cooling ring.


static func make_component(input: Dictionary) -> Node3D:
	assert(input.kind == "delayed_fire")
	assert(not str(input.get("source_owner_uuid", "")).is_empty())
	assert(not str(input.get("original_caster_uuid", "")).is_empty())
	var node: Node3D = VfxPackageIO_d707add0eb.resource("res://assets/vfx/extensions/heavy-effects-20261020/sources/d707add0ebd05c501c49/fire_explosion_readable.gd").new()
	node.specification = input.duplicate(true)
	node.set_blast_event(input.get("event", {}))
	node.prepare()
	return node


func prepare() -> void:
	if explosion != null:
		return
	super.prepare()
	var flash: ParticleProcessMaterial = explosion.get_node("muzzle").process_material
	flash.scale_min *= .08
	flash.scale_max *= .08
	for label in ["smokeball", "VFX_StylizedSmoke_ring4"]:
		var material: ShaderMaterial = explosion.get_node(label).material_override
		var code: String = material.shader.code
		if label == "smokeball":
			# Source culling hides much of this puff in the opposite camera view.
			# Keep its same geometry visible from both sides, without billboarding.
			code = code.replace("cull_back", "cull_disabled")
			code = Native.Source.finish_fragment(code, "\nALPHA*=0.5;\n")
		else:
			# Keep source particle-age erosion but feather its edge and retire
			# its low dark lobes gradually, rather than showing black cutouts.
			code = code.replace("ALPHA_SCISSOR_THRESHOLD = n_out2p4;", "ALPHA*=smoothstep(n_out2p4,n_out2p4+.1,n_out4p1);")
			code = Native.Source.finish_fragment(code, "\nALPHA*=0.18*(1.0-smoothstep(0.4,0.9,payload_seconds));\n")
		var shader := Shader.new()
		shader.code = code
		Native.Source.replace_shader(material, shader)


func capture_observation() -> Dictionary:
	var result: Dictionary = super.capture_observation()
	result["native_flash_process_scale"] = explosion.get_node("muzzle").process_material.scale_min
	result["native_volume_receiving_weight"] = .5
	result["cooling_ring_edge"] = "native age/noise with finite coverage band and gradual tail"
	return result

const VfxPackageIO_d707add0eb = preload("res://assets/vfx/extensions/heavy-effects-20261020/scoped_resource_io.gd")
