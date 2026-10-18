extends "res://assets/vfx/sources/50f35275a290e51059ff/combustible_liquid.gd"
## The same physical spill, coverage and committed ignition/douse. Its existing
## marble supplies a shallow liquid normal under the actual scene lighting.


static func make_component(input: Dictionary) -> Node3D:
	var instance := VfxPackageIO_2572219a2d.resource("res://assets/vfx/sources/2572219a2ddff406e89a/oil_liquid_reflection.gd").new() as Node3D
	instance.settings = input.duplicate(true)
	instance.settings.charge_at = 0.0
	instance.simulation = JSON.parse_string(VfxPackageIO_2572219a2d.text(input.simulation))
	instance._build()
	return instance


func _build() -> void:
	super._build()
	var shader := Shader.new()
	var code: String = material.shader.code.replace("render_mode unshaded,cull_disabled,blend_mix;", "render_mode cull_disabled,blend_mix;")
	code = Materials.finish_fragment(code, """
float oil_dx=texture(marble,world*.675+drift+vec2(.014,0.)).r-n;
float oil_dy=texture(marble,world*.675+drift+vec2(0.,.014)).r-n;
NORMAL_MAP=normalize(vec3(-oil_dx*.45,-oil_dy*.45,1.))*.5+.5;
ROUGHNESS=mix(.12,.26,smoothstep(.0,.65,state.z));
SPECULAR=.65;
""")
	shader.code = code
	Materials.replace_shader(material, shader)

const VfxPackageIO_2572219a2d = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
