extends "res://assets/vfx/sources/0738fb3bb59ec8922b87/directed_eye.gd"
const Programs=preload("res://assets/vfx/sources/801b495c0bd760a8e358/directed_program.gd")
var gpu_prepared:=false

static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/cddbd0d0900c8425a935/directed_eye.gd",input)

func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	var material: ShaderMaterial=link_draw.material_override
	Programs.prepare(material,"eye_link")
	link_draw.mesh=Programs.template(128,1,false)
	material.set_shader_parameter("gpu_eye_width",float(settings.width_cells)*.5)
	material.set_shader_parameter("gpu_eye_arc",float(settings.arc_height_world))
	gpu_prepared=true

func _write_link(start: Vector3,recipient: Vector3,across: Vector3) -> void:
	assert(gpu_prepared)
	var material: ShaderMaterial=link_draw.material_override
	var key: Array=[start,recipient,across]
	if material.get_meta("gpu_eye_inputs",[])==key:return
	material.set_meta("gpu_eye_inputs",key)
	material.set_shader_parameter("gpu_eye_start",start)
	material.set_shader_parameter("gpu_eye_recipient",recipient)
	material.set_shader_parameter("gpu_eye_across",across)
	link_draw.custom_aabb=AABB(start,Vector3.ZERO).expand(recipient).grow(absf(float(settings.arc_height_world))+float(settings.width_cells))
