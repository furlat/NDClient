extends "res://assets/vfx/sources/871a1cecb620379501e9/blade_barrier.gd"
const Programs=preload("res://assets/vfx/sources/801b495c0bd760a8e358/directed_program.gd")

static func make_component(input: Dictionary) -> Node3D:
	var effect: Node3D=VfxPackageIO_01310f2ea9.resource("res://assets/vfx/sources/01310f2ea9d75840951a/blade_barrier.gd").new()
	effect.specification=input.duplicate(true)
	effect.material=MaterialValues.build(input.material)
	effect.wake_material=MaterialValues.build(input.wake_material)
	effect._prepare(float(input.length_cells))
	return effect

func _prepare(length: float) -> void:
	super._prepare(length)
	Programs.prepare(wake_material,"blade_history")
	wake_material.set_shader_parameter("gpu_blade_spin",float(specification.spin_radians_per_second))
	wake_material.set_shader_parameter("gpu_blade_height",float(specification.height_cells))
	wake_material.set_shader_parameter("gpu_blade_length",float(specification.geometry.length_cells))
	var mesh:=Programs.template(11,3,true)
	for index in wakes.size():
		wakes[index].mesh=mesh
		wakes[index].set_instance_shader_parameter("gpu_blade_station",Vector3(stations[index].along,stations[index].height,stations[index].phase))

func sample(seconds: float) -> void:
	if endpoints.size()<2:
		for draw in blades+wakes:draw.hide()
		return
	super.sample(seconds)

func _render_blades(seconds: float,from: Vector3,to: Vector3) -> void:
	wake_material.set_shader_parameter("gpu_blade_seconds",seconds)
	wake_material.set_shader_parameter("gpu_blade_from",from)
	wake_material.set_shader_parameter("gpu_blade_to",to)
	for index in blades.size():
		var pose:=blade_pose(stations[index],seconds,from,to)
		blades[index].global_transform=pose
		blades[index].visible=visibility>.0001
		wakes[index].global_transform=Transform3D.IDENTITY
		var centre:=from.lerp(to,stations[index].along)+Vector3.UP*float(stations[index].height)
		wakes[index].custom_aabb=AABB(centre-Vector3.ONE,Vector3.ONE*2.)
		wakes[index].visible=visibility>.0001

const VfxPackageIO_01310f2ea9 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
