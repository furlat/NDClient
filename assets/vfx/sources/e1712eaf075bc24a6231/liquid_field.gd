extends RefCounted
## Shared live field upload and GPU droplet instancing; source masks stay intact.
const Network = preload("res://assets/vfx/sources/c43d754ae69cc0329592/electric_network.gd")
const FastConduction = preload("res://assets/vfx/sources/a30a2bcc236447517879/liquid_conduction.gd")
static var program_ref: WeakRef


static func install(source: Node3D) -> void:
	var program: Shader = program_ref.get_ref() if program_ref != null else null
	if program == null:
		program = VfxPackageIO_e1712eaf07.resource("res://assets/vfx/sources/05027e971745044b7568/liquid_droplets.gdshader")
		program_ref = weakref(program)
	var material := ShaderMaterial.new()
	material.shader = program
	var colours: Array = source.settings.get("colours", ["315464", "548695", "9db5ba"])
	material.set_shader_parameter("gpu_drop_colour", Color(colours[1]))
	source.droplets.multimesh.mesh.material = material
	for index in source.droplets.multimesh.instance_count:
		source.droplets.multimesh.set_instance_transform(index, Transform3D.IDENTITY)
	source.droplets.custom_aabb = AABB(Vector3.ONE * -32.0, Vector3.ONE * 64.0)


static func set_fluid(source: Node3D, value: PackedVector4Array) -> void:
	if source.fluid == value:
		return
	source.fluid = value
	source.support_points.clear()
	for drop in value:
		if drop.y < .03:
			source.support_points.append(Vector3(drop.x, drop.y, drop.z))
	source.material.set_shader_parameter("fluid", value)
	source.droplets.multimesh.mesh.material.set_shader_parameter("gpu_fluid", value)


static func electricity(input: Dictionary) -> Node3D:
	var parameters := input.duplicate(true)
	var paths: Array = []
	for index in parameters.edges.size():
		paths.append("factory-path:authoring/gpu-liquids-v375/banks/chain-%d.res" % (47291 + index * 773))
	parameters.gpu_shape_banks = paths
	return Network.make_component(parameters)


static func charge_can_be_visible(source: Node3D,seconds: float) -> bool:
	# The actual reactive fragment explicitly discards every filament while
	# state.y is zero. Before the first admitted charge, graph construction has
	# no possible visual output. Leave the precise live graph active thereafter.
	for event in source.events:
		if float(event.at)>seconds:break
		if event.operation=="charge":return true
	return false

const VfxPackageIO_e1712eaf07 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
