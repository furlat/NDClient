extends "res://assets/vfx/extensions/late-20261020/sources/28b0b8f827f5c7be91cd/summon_lifecycle.gd"
const Programs=preload("res://assets/vfx/extensions/material-runtime-20261021/sources/801b495c0bd760a8e358/directed_program.gd")
var gpu_ribbon_templates: Dictionary={}

static func make_component(input: Dictionary) -> Node3D:
	var instance := construct("res://assets/vfx/extensions/material-runtime-20261021/sources/92fd8420b6249066d8eb/summon_lifecycle.gd",input)
	instance.parameters.lifecycle_sampling = "analytical"
	return instance

func sample_analytical_tick(desired_tick: int) -> bool:
	# The parent sets pure poses/materials at (tick-1)/simulation_hz. Owner
	# admission and movement remain in the outer live manifestation controller.
	tick = desired_tick - 1
	advance_lifecycle(1.0 / float(parameters.simulation_hz))
	return true

func _ribbon_mesh(j: int,_t: float) -> ArrayMesh:
	ribbons[j].material_override.set_shader_parameter("gpu_summon_age",_t)
	if gpu_ribbon_templates.has(j):return gpu_ribbon_templates[j]
	var material: ShaderMaterial=ribbons[j].material_override
	Programs.prepare(material,"summon_lifecycle")
	material.set_shader_parameter("gpu_summon_kind",["arrival","departure","bond","cast"].find(settings.kind))
	material.set_shader_parameter("gpu_summon_index",j)
	ribbons[j].custom_aabb=AABB(Vector3(-1.5,-.5,-1.5),Vector3(3,3,3))
	var mesh:=Programs.template(28,1,false)
	gpu_ribbon_templates[j]=mesh
	return mesh


func sample(seconds: float) -> void:
	super.sample(seconds)
	# Preserve each source AABB centre for transparent sorting. This small
	# source-station bound is updated once per rendered sample, not every144Hz
	# source substep; no triangle or mesh resource is rebuilt.
	for index in ribbons.size():
		if ribbons[index].get_meta("gpu_bound_age",-INF)==time:continue
		var vertices:=ribbon_vertices(index,time)
		var bounds:=AABB(vertices[0],Vector3.ZERO)
		for point in vertices:bounds=bounds.expand(point)
		ribbons[index].custom_aabb=bounds
		ribbons[index].set_meta("gpu_bound_age",time)
