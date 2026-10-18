extends "res://assets/vfx/sources/e8be665fd8664e029046/chill_hand.gd"
## Retain the actual animated hand, source materials, smoke and emerging portal.
## Only the portal's opaque centre is opened; it can no longer cover the hand.
const NativeSources = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
var portal_material: ShaderMaterial

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = construct("res://assets/vfx/sources/a841c38a7f2c9593bff8/chill_hand_readable.gd", input)
	var light: OmniLight3D = instance.subject.get_node("OmniLight3D")
	assert(is_zero_approx(light.light_energy), "Original unkeyed Chill light must stay zero")
	light.free()
	return instance

func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	var portal: MeshInstance3D = node.get_node("portal")
	portal_material = portal.material_override
	var code: String = NativeSources.expand_shader(portal_material.shader.code, portal_material.shader.resource_path.get_base_dir())
	# Keep polar noise, native UV motion, source gradient and geometry. The
	# original broad filled disc masks the emerging finger/palm silhouette.
	# Use an open annular source window; the source ring still owns its motion.
	code = NativeSources.stable_proximity(code)
	code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform float chill_portal_open_radius=.32;\nuniform float chill_portal_feather=.055;\nuniform float chill_portal_opacity=.28;\n")
	var shader := Shader.new()
	shader.code = NativeSources.finish_fragment(code, "\nfloat portal_radius=length(UV-vec2(.5));\nALPHA*=smoothstep(chill_portal_open_radius,chill_portal_open_radius+chill_portal_feather,portal_radius)*chill_portal_opacity;\n")
	NativeSources.replace_shader(portal_material, shader)
	portal_material.set_shader_parameter("Intensity", 1.15)
	portal_material.set_shader_parameter("chill_portal_open_radius", float(parameters.portal_open_radius))
	portal_material.set_shader_parameter("chill_portal_feather", float(parameters.portal_feather))
	portal_material.set_shader_parameter("chill_portal_opacity", float(parameters.portal_opacity))

func capture_observation() -> Dictionary:
	var row := super.capture_observation()
	row.chill_readability = {"actual_native_hand":true,"punch_scale":subject.get_node("punch").scale,"portal_preserved":true,"portal_open_radius":parameters.portal_open_radius,"portal_opacity":parameters.portal_opacity,"original_hand_material_unchanged":true,"optical_lights":0}
	return row
