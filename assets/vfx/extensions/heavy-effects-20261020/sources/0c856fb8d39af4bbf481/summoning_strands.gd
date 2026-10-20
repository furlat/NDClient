extends "res://assets/vfx/extensions/late-20261020/sources/28b0b8f827f5c7be91cd/summon_lifecycle.gd"
const GPUProgram = preload("res://assets/vfx/extensions/heavy-effects-20261020/sources/801b495c0bd760a8e358/directed_program.gd")
const MoteMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
var gpu_summon_meshes: Array[ArrayMesh] = []
var gpu_motes: MultiMeshInstance3D
var gpu_mote_material: ShaderMaterial


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/extensions/heavy-effects-20261020/sources/0c856fb8d39af4bbf481/summoning_strands.gd",input)


func _ribbon_mesh(index: int,_seconds: float) -> ArrayMesh:
	while gpu_summon_meshes.size() <= index:
		var mesh: ArrayMesh = GPUProgram.template(28,1,false)
		mesh.custom_aabb = AABB(Vector3(-2,-2,-2),Vector3(4,4,4))
		gpu_summon_meshes.append(mesh)
	return gpu_summon_meshes[index]


func build_native() -> void:
	super.build_native()
	for index in ribbons.size():
		var value: ShaderMaterial = ribbons[index].material_override
		GPUProgram.prepare(value,"summoning_strands")
		value.set_shader_parameter("gpu_summon_piece",index)
		value.set_shader_parameter("gpu_summon_kind",["arrival","departure","bond","cast"].find(settings.kind))
	_prepare_gpu_motes()
	set_age(0.0)


func _prepare_gpu_motes() -> void:
	var material: ShaderMaterial = motes[0].material_override.duplicate(true)
	var source_mesh: Mesh = motes[0].mesh
	var source_materials := []
	var count := motes.size()
	for node in motes:
		source_materials.append(node.material_override)
		node.free()
	motes.clear()
	materials = materials.filter(func(value): return value not in source_materials)
	var code: String = material.shader.code
	var vertex := code.find("void vertex()")
	assert(vertex>=0)
	var include := VfxPackageIO_0c856fb8d3.text("res://assets/vfx/sources/fec629dd5aac3dd1733c/summoning_motes.gdshaderinc")
	code = code.insert(code.find("{",vertex)+1,"float instance_strength;gpu_mote_vertex(VERTEX,NORMAL,TANGENT,BINORMAL,INSTANCE_ID,instance_strength);gpu_mote_strength=instance_strength;")
	code = code.insert(vertex,include+"\n")
	var shader := Shader.new()
	shader.code = MoteMaterials.finish_fragment(code,"\nALPHA*=gpu_mote_strength;\n")
	MoteMaterials.replace_shader(material,shader)
	material.set_shader_parameter("strength",1.0)
	material.set_shader_parameter("gpu_summon_kind",["arrival","departure","bond","cast"].find(settings.kind))
	material.set_shader_parameter("gpu_summon_camera_quadrant",int(settings.camera_quadrant))
	gpu_motes = MultiMeshInstance3D.new()
	gpu_motes.name = "AnalyticalSourceMotes"
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = source_mesh
	instances.instance_count = count
	for index in count:
		instances.set_instance_transform(index,Transform3D.IDENTITY)
	instances.custom_aabb = AABB(Vector3(-3,-3,-3),Vector3(6,6,6))
	gpu_motes.multimesh = instances
	gpu_motes.material_override = material
	gpu_motes.set_meta("factory_analytical_source_clock",true)
	gpu_mote_material = material
	materials.append(material)
	subject.add_child(gpu_motes)


func sample(seconds: float) -> void:
	if not initialized:
		super.sample(0.0)
	tick = maxi(0,roundi(seconds*float(parameters.simulation_hz)))
	# The original advance_lifecycle uses tick-1, including its exact frame hold.
	set_age(maxf(0.0,float(tick-1)/float(parameters.simulation_hz)))


func set_age(seconds: float) -> void:
	super.set_age(seconds)
	for ribbon in ribbons:
		ribbon.material_override.set_shader_parameter("gpu_summon_time",seconds)
	if gpu_mote_material != null:
		gpu_mote_material.set_shader_parameter("gpu_summon_time",seconds)


func capture_observation() -> Dictionary:
	return {"native_tick":tick,"source_seconds":time,"source_ribbons":ribbons.size(),
		"analytical_gpu_motes":gpu_motes.multimesh.instance_count if gpu_motes != null else 0,"cpu_mote_transform_updates":0,
		"per_frame_mesh_rebuilds":0,"seek_contract":"Absolute vertex state at supplied source age in the current render",
		"execution_route":"native_gpu_analytical; optional existing material/node recording, no particle simulation"}

const VfxPackageIO_0c856fb8d3 = preload("res://assets/vfx/extensions/heavy-effects-20261020/scoped_resource_io.gd")
