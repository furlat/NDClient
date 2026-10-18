extends "res://assets/vfx/sources/ff65d5f8d1d289d3f69b/live_disintegrate.gd"
## Same long three-fin projectile/corona; arbitrary live ends, immutable meshes.
const GPUProgram = preload("res://assets/vfx/sources/801b495c0bd760a8e358/directed_program.gd")
var gpu_ray_mesh: ArrayMesh
var gpu_corona_mesh: ArrayMesh
var gpu_mote_materials: Array[ShaderMaterial] = []


static func make_component(input: Dictionary) -> Node3D:
	assert(input.settings.shape == "creature" and input.settings.mode == "lifecycle" and input.side == "spell",
		"Standalone Disintegrate art: target walls/creatures retain their own independently owned breakup")
	return construct("res://assets/vfx/sources/cf995e6631c7778d627a/disintegrate_projectile.gd",input)


func ray_mesh(_head: float = 0.0, width_scale: float = 1.0) -> ArrayMesh:
	# Keep separate immutable draw resources: sharing the same mesh RID changes
	# transparent sort tie order against the charge and spark layers.
	if width_scale>1.0 or (is_instance_valid(beam_corona) and beam_corona.mesh == null):
		if gpu_corona_mesh == null:
			gpu_corona_mesh = GPUProgram.template(16,3,false)
		return gpu_corona_mesh
	if gpu_ray_mesh == null:
		gpu_ray_mesh = GPUProgram.template(16,3,false)
	return gpu_ray_mesh


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	GPUProgram.prepare(beam_material,"disintegrate_projectile")
	GPUProgram.prepare(corona_material,"disintegrate_projectile")
	beam.custom_aabb = AABB(Vector3.ONE*-70,Vector3.ONE*140)
	beam_corona.custom_aabb = beam.custom_aabb
	_prepare_instanced_motes()


func _prepare_instanced_motes() -> void:
	var body := Image.create(mote_origins.size(),2,false,Image.FORMAT_RGBAF)
	for index in mote_origins.size():
		var point: Vector3 = mote_origins[index]-ray_end
		var velocity: Vector3 = mote_velocities[index]
		body.set_pixel(index,0,Color(point.x,point.y,point.z,1))
		body.set_pixel(index,1,Color(velocity.x,velocity.y,velocity.z,1))
	var flight := Image.create(flight_velocities.size(),2,false,Image.FORMAT_RGBAF)
	for index in flight_velocities.size():
		var velocity: Vector3 = flight_velocities[index]
		flight.set_pixel(index,1,Color(velocity.x,velocity.y,velocity.z,1))
	for entry in [[impact_mote_material,48,0,false,body],[mote_material,motes.size()-48,48,false,body],[flight_material,flight_sparks.size(),0,true,flight]]:
		var value: ShaderMaterial = entry[0]
		GPUProgram.prepare(value,"disintegrate_motes",true)
		value.set_shader_parameter("gpu_mote_data",ImageTexture.create_from_image(entry[4]))
		value.set_shader_parameter("gpu_mote_offset",int(entry[2]))
		value.set_shader_parameter("gpu_mote_flight",bool(entry[3]))
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		instances.mesh = quad
		instances.instance_count = int(entry[1])
		for index in instances.instance_count:
			instances.set_instance_transform(index,Transform3D.IDENTITY)
		instances.custom_aabb = AABB(Vector3.ONE*-70,Vector3.ONE*140)
		var draw := MultiMeshInstance3D.new()
		draw.name = "SourceFlightSparks" if entry[3] else "SourceMotes%d"%int(entry[2])
		draw.multimesh = instances
		draw.material_override = value
		subject.add_child(draw)
		gpu_mote_materials.append(value)
	for draw in motes+flight_sparks:
		draw.free()
	motes.clear()
	flight_sparks.clear()
	mote_origins.clear()
	mote_velocities.clear()
	flight_velocities.clear()


func sample(seconds: float) -> void:
	if not initialized:
		super.sample(0.0)
	# This source has analytical motion, not accumulated particle geometry.
	tick = maxi(0,roundi(seconds*float(parameters.simulation_hz)))-1
	advance_lifecycle(0.0)


func advance_lifecycle(delta: float) -> void:
	super.advance_lifecycle(delta)
	var age := float(tick)/float(parameters.simulation_hz)
	var head := clampf((age-3.72)/.38,0.0,1.0)
	var tail := maxf(0.0,head-.70)
	var first: Vector3 = ray_start.lerp(ray_end,tail)
	var last: Vector3 = ray_start.lerp(ray_end,head)
	for entry in [[beam_material,1.0],[corona_material,1.8]]:
		var value: ShaderMaterial = entry[0]
		value.set_shader_parameter("gpu_ray_start",ray_start)
		value.set_shader_parameter("gpu_ray_end",ray_end)
		value.set_shader_parameter("gpu_ray_head",head)
		value.set_shader_parameter("gpu_ray_width",float(entry[1]))
	# Transparent ordering uses the geometry bounds centre. An oversized box
	# centred at the origin incorrectly swaps the early projectile/charge layers.
	# Track the live finite longitudinal span without rebuilding any vertices.
	var span := AABB(first,Vector3.ZERO).expand(last)
	gpu_ray_mesh.custom_aabb = span.grow(.52*1.8)
	if gpu_corona_mesh != null:
		gpu_corona_mesh.custom_aabb = span.grow(.52*1.8)
	beam.custom_aabb = span.grow(.52)
	beam_corona.custom_aabb = span.grow(.52*1.8)
	for value in gpu_mote_materials:
		value.set_shader_parameter("gpu_mote_age",age)
		value.set_shader_parameter("gpu_mote_ray_start",ray_start)
		value.set_shader_parameter("gpu_mote_ray_end",ray_end)
		value.set_shader_parameter("gpu_mote_camera_sign",camera_sign)
