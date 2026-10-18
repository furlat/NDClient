extends Node3D
## Original approved locust flight, wings and source geometry. Their offline
## native transform buffers are instanced on the GPU, never simulated on CPU.
const Programs = preload("res://assets/vfx/sources/801b495c0bd760a8e358/directed_program.gd")
const Materials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
static var identity_buffers: Dictionary = {}
var source_data: Resource
var materials: Array[ShaderMaterial] = []

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D=VfxPackageIO_26c98431fd.resource("res://assets/vfx/sources/26c98431fd81e43423d8/recorded_swarm.gd").new()
	instance.source_data=VfxPackageIO_26c98431fd.resource("res://assets/vfx/sources/eb33aa08af5e8ddd5dfe/locust-trajectory.res")
	assert(instance.source_data!=null,"Build the exact native swarm transform source first")
	var texture:=ImageTexture.create_from_image(instance.source_data.trajectory)
	for group in instance.source_data.groups:
		var mesh: ArrayMesh=group.mesh.duplicate()
		for index in group.materials.size():
			var original: Material=group.materials[index]
			var material: ShaderMaterial
			if original is ShaderMaterial:
				material=original.duplicate(true)
			else:
				material=ShaderMaterial.new()
				material.shader=VfxPackageIO_26c98431fd.resource("res://assets/vfx/sources/1715e8bd06d0747f6f63/recorded_solid.gdshader")
				material.set_shader_parameter("source_colour",original.albedo_color)
			Programs.prepare(material,"swarm_flight",false,"float present;gpu_swarm_vertex(VERTEX,NORMAL,INSTANCE_ID,present);gpu_swarm_visible=present;")
			var shader:=Shader.new()
			shader.code=Materials.finish_fragment(material.shader.code,"\nif(gpu_swarm_visible<.5)discard;\n")
			Materials.replace_shader(material,shader)
			material.set_shader_parameter("gpu_swarm_trajectory",texture)
			material.set_shader_parameter("gpu_swarm_seed",group.seed)
			material.set_shader_parameter("gpu_swarm_wing_sign",group.wing_sign)
			material.set_shader_parameter("gpu_swarm_before",Projection(group.before))
			material.set_shader_parameter("gpu_swarm_after",Projection(group.after))
			mesh.surface_set_material(index,material)
			instance.materials.append(material)
		var draw:=MultiMeshInstance3D.new()
		draw.name=group.name
		draw.multimesh=MultiMesh.new()
		draw.multimesh.transform_format=MultiMesh.TRANSFORM_3D
		draw.multimesh.instance_count=group.count
		draw.multimesh.mesh=mesh
		draw.multimesh.custom_aabb=group.bounds
		if not identity_buffers.has(group.count):
			var buffer:=PackedFloat32Array()
			buffer.resize(group.count*12)
			for index in group.count:
				for diagonal in [0,5,10]:
					buffer[index*12+diagonal]=1.
			identity_buffers[group.count]=buffer
		draw.multimesh.buffer=identity_buffers[group.count]
		draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.add_child(draw)
	return instance

func sample(seconds: float) -> void:
	var clock:=maxf(0.,seconds)
	if clock>source_data.formation_seconds+source_data.loop_seconds:
		clock=source_data.formation_seconds+fposmod(clock-source_data.formation_seconds,source_data.loop_seconds)
	var frame:=roundf(clock*source_data.rate)
	for material in materials:
		material.set_shader_parameter("gpu_swarm_seconds",frame/source_data.rate)

func capture_observation() -> Dictionary:
	return {"gpu_recorded_swarm":{"source":source_data.source,"groups":get_child_count(),"formation_seconds":source_data.formation_seconds,"loop_seconds":source_data.loop_seconds,"live_cpu_boids":false}}

const VfxPackageIO_26c98431fd = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
