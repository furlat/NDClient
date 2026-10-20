extends "res://assets/vfx/sources/d7989287f3e6aecf6110/head_accent.gd"
const Programs=preload("res://assets/vfx/sources/801b495c0bd760a8e358/directed_program.gd")

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D=construct("res://assets/vfx/sources/35053d9088ac18c0b474/head_accent.gd",input)
	instance._prepare_gpu()
	return instance

func _prepare_gpu() -> void:
	for material in materials:
		Programs.prepare(material,"head_accent")
		material.set_shader_parameter("gpu_head_shape",0 if settings.shape=="folds" else 1)
		material.set_shader_parameter("gpu_head_mode",1 if settings.get("mode","")=="voice" else 2 if settings.get("mode","")=="saved" else 0)
		material.set_shader_parameter("gpu_head_width",float(settings.get("width_cells",.025)))
		material.set_shader_parameter("gpu_head_intensity",float(settings.get("intensity",1.)))
	var colour:=Color.WHITE
	if settings.has("colour"):
		colour=Color.html(settings.colour).srgb_to_linear()
		colour.a=float(settings.get("source_alpha",.7))
	for index in pieces.size():
		pieces[index].mesh=GpuRibbon.template(33,colour)
		pieces[index].set_instance_shader_parameter("gpu_head_number",index%int(settings.count))
		pieces[index].set_instance_shader_parameter("gpu_head_layer",index/int(settings.count))
		pieces[index].custom_aabb=AABB(Vector3.ONE*-.6,Vector3.ONE*1.2)

func _rebuild() -> void:
	if envelope<=.0001 or not _frame():_hide();return
	var left:=_support(-1.)
	var right:=_support(1.)
	for material in materials:
		material.set_shader_parameter("gpu_head_seconds",local_clock)
		material.set_shader_parameter("gpu_head_heading",heading)
		material.set_shader_parameter("gpu_head_side",side)
		material.set_shader_parameter("gpu_head_left",left.position-centre+left.normal*.035)
		material.set_shader_parameter("gpu_head_right",right.position-centre+right.normal*.035)
		material.set_shader_parameter("gpu_head_left_normal",left.normal)
		material.set_shader_parameter("gpu_head_right_normal",right.normal)
		material.set_shader_parameter("gpu_head_hand",endpoints[0].point-centre)
	for piece in pieces:
		piece.global_transform=Transform3D(Basis.IDENTITY,centre)
		piece.show()
