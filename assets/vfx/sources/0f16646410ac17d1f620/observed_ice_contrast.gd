extends "res://assets/vfx/sources/460b56ed364586c04386/observed_ice.gd"
## Retain exact admitted geometry/native textures; let clear ice and frost differ.
var contrast_prepared: bool = false


static func make_component(input: Dictionary) -> Node3D:
	var node: Node3D = VfxPackageIO_0f16646410.resource("res://assets/vfx/sources/0f16646410ac17d1f620/observed_ice_contrast.gd").new()
	node.specification = input.duplicate(true)
	node.set_surface_state(input.get("state", {}))
	return node


func sample(seconds: float) -> void:
	super.sample(seconds)
	if contrast_prepared or material == null:
		return
	contrast_prepared = true
	var shader := Shader.new()
	shader.code = material.shader.code.replace("ALBEDO=ice.rgb*0.55;", "float frost=smoothstep(0.38,0.86,dot(ice.rgb,vec3(0.2126,0.7152,0.0722)));ALBEDO=mix(ice.rgb*vec3(0.40,0.58,0.70),ice.rgb*0.9,frost);")
	shader.code = shader.code.replace("ALPHA=(0.45+0.55*ice.a)*payload_alpha;", "ALPHA=(0.35+0.30*frost+0.35*ice.a)*payload_alpha*1.1;")
	Native.Source.replace_shader(material, shader)

const VfxPackageIO_0f16646410 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
