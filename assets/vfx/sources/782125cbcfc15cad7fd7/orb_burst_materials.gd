extends RefCounted
## Scoped extraction of selected original projectile materials. No effect routing.
const Graph = preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Palette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")
const Immutable = preload("res://assets/vfx/sources/c1e0733a7ef81c657ab9/immutable_materials.gd")


static func extract(original: ShaderMaterial, colors: Array, gain: float, finite_power: bool = false) -> ShaderMaterial:
	assert(original != null and original.shader != null, "Selected original material is absent")
	# These callers extract untouched source-scene materials. Their stable
	# resource identity and exact shader source identify the selected graph.
	assert(not original.resource_path.is_empty(), "Prepared extraction requires a saved untouched donor material")
	var recipe := [original.resource_path, colors, gain, finite_power]
	var prepared := Immutable.take("orb_burst", recipe)
	if prepared != null:
		return prepared
	Graph.native_sampler_scopes += 1
	var material: ShaderMaterial = Graph.clone_value(original, {})
	Graph.native_sampler_scopes -= 1
	var code: String = SourceMaterials.expand_shader(original.shader.code, original.shader.resource_path.get_base_dir())
	# The selected Binbun transparent shader passes (lower, upper, mask) to
	# clamp(x, min, max). A mask below upper then has reversed bounds, whose
	# GPU result is undefined. Preserve the source mask/limits in their intended
	# order; a flat carrier can otherwise replace the native moving mask.
	var misplaced_alpha := "clamp(0.5 - (alpha_smoothness * .5), 0.5 + (alpha_smoothness * .5), mask_value)"
	if code.contains(misplaced_alpha):
		code = code.replace(misplaced_alpha, "clamp(mask_value, 0.5 - (alpha_smoothness * .5), 0.5 + (alpha_smoothness * .5))")
		material.set_meta("native_alpha_clamp_corrected", true)
	if finite_power:
		# The selected FireStrike graph subtracts its gradient before a fractional
		# power. Negative bases have no real result; zero is its dissolved region.
		code = code.replace("pow(n_out23p0, n_out58p0)", "pow(max(n_out23p0,0.0),n_out58p0)")
	var token := RegEx.new()
	token.compile("\\bTIME\\b")
	code = token.sub(code, "orb_burst_seconds", true)
	code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform float orb_burst_seconds=0.0;\nuniform float orb_burst_envelope=0.0;")
	code = SourceMaterials.finish_fragment(code, "\nALPHA*=orb_burst_envelope;\n")
	var shader := Shader.new()
	shader.code = code
	SourceMaterials.replace_shader(material, shader)
	Palette.apply(material, colors, {"quantize": false, "emission_gain": gain})
	return Immutable.capture("orb_burst", recipe, material)


static func draw(parent: Node3D, label: String, mesh: Mesh, material: ShaderMaterial) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.hide()
	parent.add_child(node)
	return node


static func clock(material: ShaderMaterial, seconds: float, envelope: float) -> void:
	material.set_shader_parameter("orb_burst_seconds", seconds)
	material.set_shader_parameter("orb_burst_envelope", clampf(envelope, 0.0, 1.0))


static func axial_uv(mesh: ArrayMesh) -> ArrayMesh:
	var arrays: Array = mesh.surface_get_arrays(0)
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	for index in uv.size():
		uv[index] = Vector2(uv[index].y, uv[index].x)
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
