extends "res://assets/vfx/sources/a94997293ede91d50273/cloud_billow_formation.gd"
## The source billows still obscure the area. Shared, slowly moving density
## groups soften their individual outlines without thinning the whole volume.


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/8276f656aec47f29e62c/fog_density_flow.gd", input)


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	for material in mats:
		var code: String = material.shader.code
		var source_knee := "smoothstep(.12,.62,alpha)"
		assert(code.contains(source_knee), "Fog source opacity knee changed")
		code = code.replace(source_knee, "smoothstep(.04,.72,alpha)")
		code = SourceMaterials.finish_fragment(code, """
float fog_density=loop_texture(mask2_texture,cloud_world.xz*.12+vec2(.17,0.0),vec2(.009,-.007)).r;
ALPHA*=mix(.38,1.0,smoothstep(.18,.70,fog_density));
""")
		var shader := Shader.new()
		shader.code = code
		SourceMaterials.replace_shader(material, shader)
