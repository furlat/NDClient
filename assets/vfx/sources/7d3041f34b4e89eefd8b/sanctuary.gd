extends "res://assets/vfx/sources/6c1d2d7edf38924400b5/protection.gd"
## Original ground motif and mark material; camera orientation is native GPU work.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const ExcludedLayers = preload("res://assets/vfx/sources/85f84ad1e9ee65bf3908/excluded_layers.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/7d3041f34b4e89eefd8b/sanctuary.gd", input)


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	var mark: MeshInstance3D = node.get_node("SanctuaryMark")
	assert(mark.mesh is PlaneMesh, "The original Sanctuary glyph is an XZ source plane")
	var material: ShaderMaterial = mark.material_override
	var code: String = material.shader.code
	var facing := """
// The original glyph plane is XZ; place it in camera XY at its authored origin.
vec2 sanctuary_plane = VERTEX.xz;
float sanctuary_roll = sin(vfx_clock * 1.2) * 0.08;
sanctuary_plane = mat2(vec2(cos(sanctuary_roll),sin(sanctuary_roll)),vec2(-sin(sanctuary_roll),cos(sanctuary_roll))) * sanctuary_plane;
VERTEX = vec3(sanctuary_plane, 0.0);
MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
    INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
    INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[2].xyz),
    INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[1].xyz), MODEL_MATRIX[3]);
"""
	if code.contains("void vertex()"):
		code = SourceMaterials.finish_function(code, "vertex", facing)
	else:
		code += "\nvoid vertex(){\n" + facing + "\n}\n"
	var program := Shader.new()
	program.code = code
	SourceMaterials.replace_shader(material, program)
	var excluded: Array = node.find_children("*", "GeometryInstance3D", true, false).filter(func(geometry): return geometry.layers == 0)
	excluded.append_array(node.find_children("*", "Light3D", true, false))
	ExcludedLayers.stop(node, excluded)


func advance_lifecycle(delta: float) -> void:
	super.advance_lifecycle(delta)
	# The shader owns the exact source roll and camera orientation. No redundant
	# recorded per-frame quaternion track is necessary for this native plane.
	subject.get_node("SanctuaryMark").quaternion = Quaternion.IDENTITY
