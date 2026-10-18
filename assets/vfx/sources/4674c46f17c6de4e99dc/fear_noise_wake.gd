extends "res://assets/vfx/sources/7a3ca4045a81c94c5ca9/fear_path.gd"
## Fear's own folded front and source-noise ground wake. Replace repeated radial
## sine lanes, not the separate Frightened artwork or its owner/timing.
var endpoints: Array = []
var front_speed := 0.0
var recipient_distance := 0.0


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/4674c46f17c6de4e99dc/fear_noise_wake.gd", input)


func set_live_endpoints(value: Array) -> void:
	endpoints = value


func apply_scene_edits(node: Node) -> void:
	var noise: Texture2D = VfxPackageIO_4674c46f17.resource(settings.noise_resource).duplicate(true)
	for trail in [false, true]:
		var mesh := MeshInstance3D.new()
		mesh.name = "SourceNoiseWake" if trail else "SourceFoldedFront"
		mesh.mesh = make_surface(trail)
		mesh.custom_aabb = AABB(Vector3(-5.7, 0, -0.6), Vector3(11.4, 2.0, 12.5))
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mesh)
		var code: String = PATH if trail else CREST
		code = code.replace("TIME*7.", "TIME*front_speed")
		code = code.replace("UV.y*11.3/7.", "UV.y*11.3/max(front_speed,0.001)")
		if trail:
			code = code.replace(
				"float stream=.5+.5*sin(UV.x*40.+n*5.+UV.y*4.);",
				"float stream=smoothstep(.25,.72,n*.65+n2*.35+.12*sin(UV.y*10.-TIME*2.+n2*4.));")
			code = code.replace("float strands=pow(stream,5.)*(.35+.65*curl);", "float strands=stream*(.45+.55*curl);")
			code = code.replace("float fade=1.-smoothstep(2.0,3.1,age);", "float fade=1.-smoothstep(1.25,2.2,age);")
			code = code.replace("ALBEDO=vec3(.035+.34*strands+.055*n);", "ALBEDO=vec3(.025+.22*strands+.065*n);")
			code = code.replace("ALPHA=edge*(.26+.42*n+.18*strands);", "ALPHA=edge*smoothstep(.18,.62,n*.65+n2*.35)*(.12+.52*strands);")
		else:
			code = code.replace(
				"float fold=.5+.5*sin(UV.x*32.+UV.y*9.+n*6.-TIME*4.);",
				"float fold=smoothstep(.20,.78,texture(source_noise,UV*vec2(4.,2.)+vec2(-.17,.25)*TIME+vec2(n*.18,0.)).r);")
			code = code.replace("float ridge=pow(fold,4.);", "float ridge=fold*fold;")
			code = code.replace("ALBEDO=vec3(.08+.42*ridge+.10*n);", "ALBEDO=vec3(.04+.24*ridge+.08*n);")
		code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform float front_speed=7.0;\nuniform float endpoint_admitted=0.0;\n")
		var shader := Shader.new()
		shader.code = SourceMaterials.finish_fragment(code, "\nALPHA *= endpoint_admitted;\n")
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("source_noise", noise)
		adapt(material)
		mesh.material_override = material


func update_geometry() -> void:
	var admitted := endpoints.size() >= 2
	if admitted:
		var source: Vector3 = endpoints[0].point
		var target: Vector3 = endpoints[1].point
		recipient_distance = Vector2(target.x - source.x, target.z - source.z).length()
		admitted = recipient_distance > 0.001
		front_speed = recipient_distance * float(parameters.source_units_per_cell) / float(parameters.contact_seconds)
	for material in materials:
		material.set_shader_parameter("front_speed", maxf(0.001, front_speed))
		material.set_shader_parameter("endpoint_admitted", 1.0 if admitted else 0.0)


func capture_observation() -> Dictionary:
	var result := super.capture_observation()
	result["fear_front"] = {"recipient_distance_cells": recipient_distance,
		"front_speed_source_units": front_speed, "contact_seconds": parameters.contact_seconds,
		"range_source_units": 11.3, "endpoint_count": endpoints.size(),
		"straight_sine_lanes": false, "frightened_changed": false}
	return result

const VfxPackageIO_4674c46f17 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
