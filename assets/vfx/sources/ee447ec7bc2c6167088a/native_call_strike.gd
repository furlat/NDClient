extends "res://assets/vfx/sources/ab791b14589651dcc7e6/call_strike.gd"
## Full original multi-surface strike, with an occurrence-local blue HDR ramp.
## The original mesh, spark, flare and erosion layers remain present.
static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/ee447ec7bc2c6167088a/native_call_strike.gd",input)
func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	for emitter in asset.find_children("*","GPUParticles3D",true,false):
		for pass_index in emitter.draw_passes:
			var mesh: Mesh = emitter.get_draw_pass_mesh(pass_index)
			if mesh==null:continue
			for surface in mesh.get_surface_count():
				var selected: Material = mesh.surface_get_material(surface)
				if selected is not ShaderMaterial:continue
				var ramp: Variant = selected.get_shader_parameter("Texture2DParameter2")
				if ramp is GradientTexture1D:
					var blue: GradientTexture1D = ramp.duplicate(true)
					blue.gradient=ramp.gradient.duplicate(true)
					blue.gradient.colors=PackedColorArray([Color(.015,.4,1.3,1.),Color(.06,1.2,3.,1.)])
					selected.set_shader_parameter("Texture2DParameter2",blue)
				if selected.shader.code.contains("ColorParameter"):
					selected.set_shader_parameter("ColorParameter",Color(.04,.55,1.8,1.))
