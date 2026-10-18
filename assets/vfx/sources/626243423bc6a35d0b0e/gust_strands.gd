extends "res://assets/vfx/sources/bccb9b827ea1205577dd/gust_airy_strands.gd"
## Original fronts, rolled airy strands, normal maps and actual hand registration.
const GPUProgram = preload("res://assets/vfx/sources/801b495c0bd760a8e358/directed_program.gd")
var gpu_gust_meshes: Array[ArrayMesh] = []


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/626243423bc6a35d0b0e/gust_strands.gd",input)


func ribbon_mesh(which: int,_reach: float,_time: float) -> ArrayMesh:
	while gpu_gust_meshes.size() <= which:
		gpu_gust_meshes.append(GPUProgram.template(64,1,true))
	return gpu_gust_meshes[which]


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	for index in strands.size():
		GPUProgram.prepare(strands[index].material_override,"gust_strands")
		strands[index].material_override.set_shader_parameter("gpu_gust_piece",index)
		strands[index].custom_aabb = AABB(Vector3.ONE*-70,Vector3.ONE*140)


func sample(seconds: float) -> void:
	if not initialized:
		super.sample(0.0)
	tick = maxi(0,roundi(seconds*float(parameters.simulation_hz)))-1
	advance_lifecycle(0.0)


func advance_lifecycle(delta: float) -> void:
	super.advance_lifecycle(delta)
	var age := float(tick)/144.0
	var reach := 24.0 if age>1.5 else clampf((age-.08)*16.0,0.0,24.0)
	for strip in strands:
		strip.material_override.set_shader_parameter("gpu_gust_time",age)
		strip.material_override.set_shader_parameter("gpu_gust_reach",reach)
		strip.material_override.set_shader_parameter("gpu_gust_hand",hand)
		strip.material_override.set_shader_parameter("gpu_gust_direction",direction)
		strip.material_override.set_shader_parameter("gpu_gust_across",across)
