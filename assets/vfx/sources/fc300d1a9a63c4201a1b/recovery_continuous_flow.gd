extends "res://assets/vfx/sources/3d101518574df82eb7f5/accepted_recovery_source_v190.gd"
## Same successful self-heal/Idle2/source geometry and mint finishing. Advected
## source noise replaces four evenly spaced bright beads on each recovery strip.
const Bindings = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = VfxPackageIO_fc300d1a9a.resource("res://assets/vfx/sources/fc300d1a9a63c4201a1b/recovery_continuous_flow.gd").new()
	instance.settings = input.duplicate(true)
	assert(is_equal_approx(float(input.source_seconds), 1.5))
	assert(instance.set_owner_projection(input.owner_projection))
	instance._build()
	instance.sample(0.0)
	return instance


func _material(path: String) -> ShaderMaterial:
	var result: ShaderMaterial = super._material(path)
	if result.shader.code.contains("float st = .5 + .5*sin(UV.x*25.132741"):
		var shader := Shader.new()
		shader.code = result.shader.code.replace(
			"float st = .5 + .5*sin(UV.x*25.132741 - phase*2.0+seed*10.0);",
			"float st = .25 + .65*smoothstep(.15,.85,n);")
		Bindings.replace_shader(result, shader)
	return result


func sample(seconds: float) -> void:
	super.sample(seconds)
	for index in motes.size():
		var phase := fmod(native_seconds/2.0 + float(index)*.083333333333, 1.0)
		motes[index].material_override.set_shader_parameter("source_alpha",
			0.8 * sin(phase*PI) * source_strength if visible else 0.0)


func capture_observation() -> Dictionary:
	var result: Dictionary = super.capture_observation()
	result.flow_revision = "original noise replaces repeated sine beads; source mote tail follows actual finite recovery envelope"
	result.original_source_pulse_and_mote_alpha_parity = false
	return result

const VfxPackageIO_fc300d1a9a = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
