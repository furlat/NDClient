extends RefCounted
## Transparent tabletop surfaces must draw before the food resting on them.
## This retains the source geometry and live per-role material owners; no layer
## is re-imported, moved, resized or replaced by a flat preview substitute.
const Feast = preload("res://assets/vfx/sources/e6a8d8196a786c079bf3/spectral_feast_materialize.gd")


static func make_component(input: Dictionary) -> Node3D:
	var component: Node3D = Feast.make_component(input)
	if component == null:
		return null
	for kind: String in component.cached_materials:
		var material: ShaderMaterial = component.cached_materials[kind]
		if not kind.begins_with("Spectral"):
			# The source constructor intentionally strips the spectral alpha for
			# solid roles. Initialize their birth coverage before multiplying it.
			var shader: Shader = material.shader.duplicate(false)
			shader.code = shader.code.replace("ALPHA*=materialized;", "ALPHA=materialized;")
			material.shader = shader
		material.render_priority = int(input.role_render_priority.get(kind, 0))
	return component
