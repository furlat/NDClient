extends "res://assets/vfx/sources/979ecf1a1d9d8264d287/reactive_liquid.gd"
## Crystalline veins cover the red deposit selectively, rather than averaging
## its low-value red with a bright blue wash across every frozen pixel.
## Particle positions, source density mask and committed freeze/thaw fronts stay.
const Sources = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	var component: Node3D = VfxPackageIO_3a64ecce0f.resource("res://assets/vfx/sources/3a64ecce0f09c5dc8358/blood_crystal_veil.gd").new()
	component.settings = input.duplicate(true)
	component.settings.charge_at = 0.0
	component.simulation = JSON.parse_string(VfxPackageIO_3a64ecce0f.text(input.simulation))
	component._build()
	return component


func _build() -> void:
	super._build()
	assert(settings.kind == "blood")
	var code: String = material.shader.code
	assert(code.contains("mix(liquid,icy,.43)"))
	var shader := Shader.new()
	shader.code = code.replace("mix(liquid,icy,.43)", "mix(liquid*vec3(.88,.88,.95),icy,smoothstep(.20,.60,crystal)*.70)")
	Sources.replace_shader(material, shader)
	material.set_shader_parameter("frozen_blood",true)

const VfxPackageIO_3a64ecce0f = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
