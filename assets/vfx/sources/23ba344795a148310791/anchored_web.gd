extends "res://assets/vfx/sources/e5338118a904c73b413d/continuous_web_binding.gd"
## Exact source net on the GPU. CPU measures real profile changes, never the grid.
var gpu_source_texture: ImageTexture
var gpu_owner_texture: ImageTexture
var gpu_contact_texture: ImageTexture
var gpu_anchor_frames: Dictionary = {}
var gpu_contact_keys: Dictionary = {}
var gpu_owner_bytes := PackedFloat32Array()
var gpu_transform := Transform3D()
var gpu_transform_set := false
var gpu_profile_uploads := 0
var gpu_owner_uploads := 0
var gpu_dirty_profiles := true


static func make_component(input: Dictionary) -> Node3D:
	for key in ["source_shader","source_texture","source_size","source_subdivisions","yaw_degrees",
		"zone_uuid","binding_owners","rise_seconds","release_seconds","anchor_margin_world_units",
		"return_run_height_ratio","surface_clearance_world_units","contact_witness_max_gap_world_units","surface_columns","surface_rows"]:
		assert(input.has(key),"GPU Continuous Web requires explicit "+key)
	assert(is_equal_approx(float(input.source_size),10.6))
	assert(float(input.rise_seconds)>0.0 and float(input.release_seconds)>0.0)
	var instance: Node3D = VfxPackageIO_23ba344795.resource("res://assets/vfx/sources/23ba344795a148310791/anchored_web.gd").new()
	instance.specification = input.duplicate(true)
	instance._prepare_source()
	instance.set_binding_owners(input.binding_owners)
	return instance


func _prepare_source() -> void:
	super._prepare_source()
	var width := mini(256,source_vertices.size())
	var image := Image.create(width,ceili(float(source_vertices.size())/width)*3,false,Image.FORMAT_RGBAF)
	var ids := PackedVector2Array()
	for index in source_specs.size():
		var item: Dictionary = source_specs[index]
		var x := index%width
		var y := (index/width)*3
		image.set_pixel(x,y,Color(item.rest.x,item.rest.y,item.rest.z,item.delay))
		image.set_pixel(x,y+1,Color(item.folded.x,item.folded.y,item.folded.z,item.duration))
		image.set_pixel(x,y+2,Color(item.phase_modulation,item.lift,item.along,item.trailing))
		ids.append(Vector2(index,0))
	gpu_source_texture = ImageTexture.create_from_image(image)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = source_vertices
	arrays[Mesh.ARRAY_NORMAL] = source_normals
	arrays[Mesh.ARRAY_TEX_UV] = source_uv
	arrays[Mesh.ARRAY_TEX_UV2] = ids
	arrays[Mesh.ARRAY_INDEX] = source_indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	net.custom_aabb = AABB(Vector3(-15,-10,-15),Vector3(30,30,30))
	var code: String = material.shader.code
	var insertion := VfxPackageIO_23ba344795.text("res://assets/vfx/sources/2877a4497d67ec36eee7/anchored_web.gdshaderinc")
	var vertex_at := code.find("void vertex()")
	if vertex_at < 0:
		code += "\n"+insertion+"\nvoid vertex(){gpu_web_deform(VERTEX,UV,UV2);}\n"
	else:
		code = code.insert(vertex_at,insertion+"\n")
		vertex_at = code.find("void vertex()")
		code = code.insert(code.find("{",vertex_at)+1,"gpu_web_deform(VERTEX,UV,UV2);")
	var shader := Shader.new()
	shader.code = code
	MaterialBindings.replace_shader(material,shader)
	material.set_shader_parameter("gpu_web_source",gpu_source_texture)
	material.set_shader_parameter("gpu_web_margin",float(specification.anchor_margin_world_units))
	material.set_shader_parameter("gpu_web_rise",float(specification.rise_seconds))
	material.set_shader_parameter("gpu_web_release",float(specification.release_seconds))
	material.set_shader_parameter("gpu_web_clearance",float(specification.surface_clearance_world_units))
	material.set_shader_parameter("gpu_web_wrap_height",float(specification.get("wrap_height_fraction",1.0)))
	material.set_shader_parameter("gpu_web_columns",int(specification.surface_columns))
	material.set_shader_parameter("gpu_web_rows",int(specification.surface_rows))


func set_binding_owners(value: Array) -> void:
	super.set_binding_owners(value)
	gpu_dirty_profiles = true


func _surface_profile(surface: Dictionary) -> Dictionary:
	# The original key predates scale/layer-relative transforms. Reuse its exact
	# measurement algorithm with the complete supplied geometry identity.
	var measurement := surface.duplicate(false)
	measurement.pose_key = surface.get("gpu_geometry_key",surface.get("pose_key",[]))
	return super._surface_profile(measurement)


func _put(values: PackedFloat32Array, value: Vector4) -> void:
	values.append_array(PackedFloat32Array([value.x,value.y,value.z,value.w]))


func _vector(value: Vector3, w: float = 0.0) -> Vector4:
	return Vector4(value.x,value.y,value.z,w)


func _profile_texture() -> void:
	var columns := int(specification.surface_columns)
	var rows := int(specification.surface_rows)
	var image := Image.create(columns*2,rows*maxi(1,owners.size()),false,Image.FORMAT_RGBAF)
	for index in owners.size():
		var actor: String = owners[index].actor_id
		if not profiles.has(actor):
			continue
		var profile: Dictionary = profiles[actor]
		for number in profile.contacts.size():
			var entry: Dictionary = profile.contacts[number]
			var point: Vector3 = entry.position
			var normal: Vector3 = entry.normal
			image.set_pixel((number%columns)*2,(number/columns)+rows*index,Color(point.x,point.y,point.z,1))
			image.set_pixel((number%columns)*2+1,(number/columns)+rows*index,Color(normal.x,normal.y,normal.z,1))
	if gpu_contact_texture != null and Vector2i(gpu_contact_texture.get_size()) == image.get_size():
		gpu_contact_texture.update(image)
	else:
		gpu_contact_texture = ImageTexture.create_from_image(image)
	material.set_shader_parameter("gpu_web_contacts",gpu_contact_texture)
	gpu_profile_uploads += 1
	gpu_dirty_profiles = false


func sample(seconds: float) -> void:
	source_seconds = seconds
	material.set_shader_parameter("gpu_web_clock",seconds)
	var world_transform := global_transform if is_inside_tree() else Transform3D.IDENTITY
	if not gpu_transform_set or gpu_transform != world_transform:
		gpu_transform = world_transform
		gpu_transform_set = true
		material.set_shader_parameter("gpu_web_to_world",Projection(world_transform))
		material.set_shader_parameter("gpu_web_to_local",Projection(world_transform.affine_inverse()))
	var data := PackedFloat32Array()
	var wrap_strength := 0.0
	observations = {"owners":[]}
	for index in owners.size():
		var owner: Dictionary = owners[index]
		var actor: String = owner.actor_id
		var identity: String = owner.owner_uuid
		var strength := owner_envelope(owner,seconds)
		var profile := _surface_profile(surfaces[actor]) if surfaces.has(actor) else {}
		if profile.is_empty() and float(owner.removed_seconds)>=0.0 and seconds>=float(owner.removed_seconds):
			profile = profiles.get(actor,{})
		var available := not profile.is_empty()
		if available:
			var key: Array = profile.pose
			if key.is_empty() or gpu_contact_keys.get(identity) != key:
				gpu_contact_keys[identity] = key.duplicate(true)
				gpu_dirty_profiles = true
			if not anchors.has(identity) and strength>0.0:
				anchors[identity] = {"origin":profile.origin,"side":profile.side,"normal":profile.normal,
					"half_width":profile.half_width,"run":maxf(float(profile.top)*float(specification.return_run_height_ratio),float(profile.half_width)+float(specification.anchor_margin_world_units))}
				gpu_anchor_frames[identity] = world_transform
			wrap_strength = maxf(wrap_strength,strength)
		var active := available and anchors.has(identity)
		var anchor: Dictionary = anchors.get(identity,{})
		_put(data,_vector(profile.get("origin",Vector3.ZERO),1.0 if active else 0.0))
		_put(data,_vector(anchor.get("origin",Vector3.ZERO),float(anchor.get("run",1.0))))
		_put(data,_vector(anchor.get("side",Vector3.RIGHT),float(anchor.get("half_width",.1))))
		_put(data,_vector(anchor.get("normal",Vector3.FORWARD)))
		_put(data,Vector4(float(owner.begin_seconds),float(owner.removed_seconds),0,0))
		var frame: Transform3D = gpu_anchor_frames.get(identity,Transform3D.IDENTITY)
		_put(data,_vector(frame.basis.x))
		_put(data,_vector(frame.basis.y))
		_put(data,_vector(frame.basis.z))
		_put(data,_vector(frame.origin,1.0))
		observations.owners.append({"owner_uuid":identity,"actor_id":actor,"strength":strength,"surface_points":int(profile.get("points",0))})
	if data.is_empty():
		data.resize(9*4)
	if gpu_owner_texture == null or gpu_owner_bytes != data:
		var image := Image.create_from_data(9,maxi(1,owners.size()),false,Image.FORMAT_RGBAF,data.to_byte_array())
		if gpu_owner_texture != null and Vector2i(gpu_owner_texture.get_size()) == image.get_size():
			gpu_owner_texture.update(image)
		else:
			gpu_owner_texture = ImageTexture.create_from_image(image)
		material.set_shader_parameter("gpu_web_owners",gpu_owner_texture)
		gpu_owner_bytes = data
		gpu_owner_uploads += 1
	material.set_shader_parameter("gpu_web_owner_count",owners.size())
	if gpu_dirty_profiles:
		_profile_texture()
	if specification.has("raised_strand_alpha"):
		material.set_shader_parameter("web_wrap_strength",wrap_strength)


func capture_observation() -> Dictionary:
	var result := observations.duplicate(true)
	result.merge({"method":"Original deployment/anchored draping in GPU vertex stage; no cloth simulation",
		"source_seconds":source_seconds,"source_vertices":source_vertices.size(),"source_triangles":source_indices.size()/3,
		"source_uv_unchanged":true,"source_mask_palette_unchanged":true,"mesh_instances":1,"per_frame_mesh_rebuilds":0,
		"admitted_memberships":owners.size(),"profile_uploads":gpu_profile_uploads,"small_owner_uploads":gpu_owner_uploads,
		"actual_deformed_vertex_readback":false,"optical_lights":0,"production_integration_performed":false})
	return result

const VfxPackageIO_23ba344795 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
