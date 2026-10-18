extends "res://assets/vfx/sources/5944248dd6bb52ef8394/class_action.gd"
## Local appearance derivative: retain the original three planes, displacement,
## noise, palette and clock. Restrict the existing folded detail instead of
## filling the whole radial footprint with the source constant-alpha veil.
const PresenceBindings = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	var node := VfxPackageIO_d7435b0a61.resource("res://assets/vfx/sources/d7435b0a61b906124713/presence_wisps.gd").new() as Node3D
	node.settings = input.duplicate(true)
	node.kind = input.kind
	node._build()
	return node


func _piece(family: String, index: int) -> MeshInstance3D:
	var piece := super._piece(family, index)
	assert(family == "presence", "This local finish only accepts the Presence source")
	var material: ShaderMaterial = piece.material_override
	var code: String = material.shader.code
	var source_alpha := "ALPHA=radial*(.065+.18*n*n+.055*n2*fold);"
	assert(code.count(source_alpha) == 1, "Original Presence coverage changed")
	code = code.replace("shader_type spatial;", """shader_type spatial;
uniform float presence_fold_start=0.82;
uniform float presence_fold_end=0.99;
uniform float presence_alpha_gain=0.45;
""")
	code = code.replace(source_alpha, "ALPHA=radial*(.18*n*n+.055*n2*fold)*smoothstep(presence_fold_start,presence_fold_end,fold)*presence_alpha_gain;")
	var shader := Shader.new()
	shader.code = code
	PresenceBindings.replace_shader(material, shader)
	var finish: Dictionary = settings.presence_finish
	for key: String in ["fold_start", "fold_end", "alpha_gain"]:
		material.set_shader_parameter("presence_" + key, float(finish[key]))
	return piece

const VfxPackageIO_d7435b0a61 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
