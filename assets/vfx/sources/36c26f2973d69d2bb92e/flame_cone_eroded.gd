extends "res://assets/vfx/sources/6a0e630617b8d7cbec14/flame_cone_volume.gd"
## Erode low-energy plate coverage using the artist's actual animated flame
## intensity. Keep hot tongues, all three meshes, smoke and sparks intact.
var eroded_materials := 0


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/36c26f2973d69d2bb92e/flame_cone_eroded.gd", input)


func clipped_material(old: Material, cell: Vector2, facing: String) -> ShaderMaterial:
	var material: ShaderMaterial = super.clipped_material(old, cell, facing)
	var code: String = material.shader.code
	if not code.contains("float img = texture(sprite_sheet"):
		return material
	assert(code.count("ALPHA = tex.a;") == 1 and code.count("ALPHA_SCISSOR_THRESHOLD =  alphad;") == 1)
	var interval: Array = parameters.flame_erosion
	code = code.replace("ALPHA = tex.a;", "ALPHA = tex.a * smoothstep(%s,%s,img);" % interval)
	code = code.replace("ALPHA_SCISSOR_THRESHOLD =  alphad;", "")
	material.shader.code = code
	eroded_materials += 1
	return material


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	assert(eroded_materials == 3, "Expected three original animated flame materials")
