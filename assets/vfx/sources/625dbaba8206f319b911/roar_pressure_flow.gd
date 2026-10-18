extends "res://assets/vfx/sources/5944248dd6bb52ef8394/class_action.gd"
## Preserve this action's source roar caps/wakes and separate Frightened effect.
## Spatial source-noise varies the pressure crest instead of perfect oval hoops.
const Sources = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	assert(str(input.kind) == "roar")
	var component: Node3D = VfxPackageIO_625dbaba82.resource("res://assets/vfx/sources/625dbaba8206f319b911/roar_pressure_flow.gd").new()
	component.settings = input.duplicate(true)
	component.kind = "roar"
	component._build()
	return component


func _piece(family: String, index: int) -> MeshInstance3D:
	var piece: MeshInstance3D = super._piece(family,index)
	var material: ShaderMaterial = piece.material_override
	var code: String = material.shader.code
	var crest := "r*=1.+.055*sin(a*3.+shell*1.7)+.032*sin(a*7.-age*4.);"
	assert(code.contains(crest))
	code = code.replace(crest,"""
float crest_noise=textureLod(source_noise,vec2(cos(a),sin(a))*.23+vec2(shell*.17,age*.08),0.0).r;
r*=.87+.26*crest_noise;
""")
	code = code.replace("r*=radial;", "z+=.22*(crest_noise-.5)*(wake?.5:1.);r*=radial;")
	code = code.replace("smoothstep(.22,.47,noise+.10*sin(a*5.+shell))", "smoothstep(.30,.62,noise+.10*sin(a*5.+shell))")
	var shader := Shader.new()
	shader.code = code
	Sources.replace_shader(material,shader)
	return piece

const VfxPackageIO_625dbaba82 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
