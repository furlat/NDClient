extends "res://assets/vfx/sources/137cf9cc5700f7fe4686/cone_of_cold.gd"
## Preserve every cold source layer and its travel. The frost trace is broken
## by its own noise instead of painting a uniformly tinted triangular sheet.


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/a100769e182ade6887cc/cone_frost_edges.gd", input)


func adapt(shader_code: String) -> Shader:
	var source := shader_code
	if int(settings.layer) == 3:
		var old_boundary := "float boundary=(1.-smoothstep(.414+noise*.03,.46251225,angle))*(1.-smoothstep(11.35+noise*.30,12.,r));"
		var new_boundary := """float side_distance=p.x*tan(.46251225)-abs(p.y);
 float edge_depth=.18+.35*noise;
 float boundary=smoothstep(.02+.12*(1.-noise),edge_depth,side_distance)*(1.-smoothstep(11.15+noise*.50,12.,r));"""
		assert(source.contains(old_boundary), "Cold floor source boundary changed")
		source = source.replace(old_boundary, new_boundary)
		var old_density := "ALPHA=boundary*envelope*(.08+.23*lace)*smoothstep(.25,.70,r);"
		assert(source.contains(old_density), "Cold floor source density changed")
		source = source.replace(old_density, """float frost_group=texture(edge_noise,p*.135+vec2(.27,.13)).r;
 ALPHA=boundary*envelope*(.018+.30*lace*smoothstep(.18,.66,frost_group))*smoothstep(.25,.70,r);""")
	var shader := super.adapt(source)
	if int(settings.layer) < 3:
		var old_edge := "(1.-smoothstep(.418+grain*.026,.46251225,angular))"
		assert(shader.code.contains(old_edge), "Cold volume source boundary changed")
		shader.code = shader.code.replace(old_edge, "smoothstep(.015+.12*(1.-grain),.18+.34*grain,realp.x*tan(.46251225)-abs(realp.z))")
		# Adjacent copies retain their original geometry and clocks. Complementary
		# weights remove the hard recorder-depth boundary between their domains.
		var cuts: Array = settings.get("source_depth_cuts", [4.5, 9.])
		var first: float = cuts[0]
		var second: float = cuts[1]
		var old_cut: String
		var weight: String
		if int(settings.layer) == 0:
			old_cut = "if(depth>=%.12f)discard;" % first
			weight = "float cold_partition=1.-smoothstep(%.12f,%.12f,depth);" % [first-.24, first+.24]
		elif int(settings.layer) == 1:
			old_cut = "if(depth<%.12f||depth>=%.12f)discard;" % [first, second]
			weight = "float cold_partition=smoothstep(%.12f,%.12f,depth)*(1.-smoothstep(%.12f,%.12f,depth));" % [first-.24, first+.24, second-.24, second+.24]
		else:
			old_cut = "if(depth<%.12f)discard;" % second
			weight = "float cold_partition=smoothstep(%.12f,%.12f,depth);" % [second-.24, second+.24]
		assert(shader.code.contains(old_cut), "Cold source partition changed")
		shader.code = shader.code.replace(old_cut, weight)
		shader.code = SourceMaterials.finish_fragment(shader.code, "\nALPHA*=cold_partition;\n")
	return shader
