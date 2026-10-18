extends "res://assets/vfx/sources/31dc71c377ddd08598f4/fire_pillar_flow.gd"
## Source cylinders nested inside the same footprint, with their original
## animated noise, gradient, particle curves and one-shot clock.


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/8302a6453a9f295d55ac/fire_pillar_layers.gd", input)


func apply_scene_edits(node: Node) -> void:
	# Whole-source intent is explicit; the shared live stage also removes the
	# legacy numeric cut, so this option is not a newly repaired runtime cut.
	assert(settings.get("strikeWhole", false) and side == "full")
	super.apply_scene_edits(node)
	var outer: GPUParticles3D = node.get_node("outter_rays")
	if parameters.has("volume_flow_uv_scale"):
		# All source/material clocks stay unchanged. This explicit override changes
		# the length of moving native flame tongues, not the cylinder dimensions.
		source_scale_uv = Vector2(float(parameters.volume_flow_uv_scale[0]), float(parameters.volume_flow_uv_scale[1]))
		outer.material_override.set_shader_parameter("Scale_XY", source_scale_uv)
		outer.material_override.set_shader_parameter("repair_native_scale", source_scale_uv)
	var original: Mesh = outer.draw_pass_1
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in parameters.volume_layers:
		var arrays: Array = original.surface_get_arrays(0)
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV].duplicate()
		for index in uv.size():
			uv[index] += Vector2(float(layer.uv_offset[0]), float(layer.uv_offset[1]))
		arrays[Mesh.ARRAY_TEX_UV] = uv
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var radius: float = float(layer.radius)
		surface.append_from(mesh, 0, Transform3D(Basis.from_scale(Vector3(radius, 1.0, radius)), Vector3.ZERO))
	outer.draw_pass_1 = surface.commit()
	# Source radial ramp ends in opaque black. In a transparent live floor cue
	# this is an occluding plate; retain its coloured wave, clear that endpoint.
	var floor_material: ShaderMaterial = node.get_node("floorflash").material_override
	var ramp: GradientTexture1D = floor_material.get_shader_parameter("Color_1D_Gradient")
	var colors: PackedColorArray = ramp.gradient.colors
	assert(colors[colors.size() - 1].v < 0.001)
	colors[colors.size() - 1].a = 0.0
	ramp.gradient.colors = colors


func capture_observation() -> Dictionary:
	var result: Dictionary = super.capture_observation()
	result.native_cylinder_layers = parameters.volume_layers.size()
	result.outer_radius_unchanged = true
	result.whole_source_requested = settings.strikeWhole
	result.shared_stage_already_strips_legacy_cut = true
	result.floor_black_endpoint_alpha = 0.0
	return result
