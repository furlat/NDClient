extends RefCounted
## Resource-only prepublication admission for an already-authored PackedScene.
## Never creates a Node, duplicates/rewrites a Material, samples time, changes
## ownership/local flags, or reflects ShaderMaterial properties (which can prune
## native cached operands). Per-owner resources still localize at instantiation.

static func _append(material: Material, site: String, result: Array) -> void:
	if material == null: return
	result.append({"material":material,"site":site})
	if material.next_pass != null:
		_append(material.next_pass,site+"/next_pass",result)

static func _mesh(mesh: Mesh, site: String, result: Array) -> void:
	if mesh == null: return
	for surface in mesh.get_surface_count():
		_append(mesh.surface_get_material(surface),site+"/surface[%d]" % surface,result)

static func sites(scene: PackedScene) -> Array:
	assert(scene != null)
	var result: Array = []
	var state: SceneState = scene.get_state()
	for index in state.get_node_count():
		for property_index in state.get_node_property_count(index):
			var value: Variant = state.get_node_property_value(index,property_index)
			var site := str(state.get_node_path(index))+":"+str(state.get_node_property_name(index,property_index))
			if value is Material:
				_append(value,site,result)
			elif value is Mesh:
				_mesh(value,site,result)
			elif value is MultiMesh:
				_mesh(value.mesh,site+"/multimesh_mesh",result)
	return result

static func begin(scene: PackedScene) -> Dictionary:
	var started := Time.get_ticks_usec()
	var seen := {}
	var materials: Array[Material] = []
	var actual_sites := sites(scene)
	for entry: Dictionary in actual_sites:
		var material: Material = entry.material
		var identity := material.get_instance_id()
		if seen.has(identity): continue
		seen[identity] = true
		materials.append(material)
	return {"materials":materials,"at":0,"complete":materials.is_empty(),"actual_sites":actual_sites.size(),
		"classes":{},"discovery_us":Time.get_ticks_usec()-started,"native_rid_total_us":0,
		"native_rid_max_us":0,"native_rid_last_us":0,"native_rid_last_class":""}

static func progress(state: Dictionary) -> Dictionary:
	return {"complete":state.complete,"actual_materials":state.materials.size(),"prepared_materials":state.at,
		"actual_sites":state.actual_sites,"classes":state.classes.duplicate(),"discovery_us":state.discovery_us,
		"native_rid_total_us":state.native_rid_total_us,"native_rid_max_us":state.native_rid_max_us,
		"native_rid_last_us":state.native_rid_last_us,"native_rid_last_class":state.native_rid_last_class,
		"resource_only_admission_us":int(state.discovery_us)+int(state.native_rid_total_us),
		"nodes_created":0,"source_samples":0,"material_duplicates":0,"shader_material_property_reflections":0}

static func step(state: Dictionary) -> Dictionary:
	if state.complete: return progress(state)
	var material: Material = state.materials[int(state.at)]
	var started := Time.get_ticks_usec()
	# One native Resource operation is indivisible. Yield between Materials;
	# never hide a slow unit behind an occurrence or a sample.
	assert(material.get_rid().is_valid(),"Actual native material admission must succeed before publication")
	var elapsed := Time.get_ticks_usec()-started
	var kind := material.get_class()
	state.classes[kind] = int(state.classes.get(kind,0))+1
	state.native_rid_total_us = int(state.native_rid_total_us)+elapsed
	state.native_rid_max_us = maxi(int(state.native_rid_max_us),elapsed)
	state.native_rid_last_us = elapsed
	state.native_rid_last_class = kind
	state.at = int(state.at)+1
	state.complete = int(state.at) == state.materials.size()
	return progress(state)

static func prepare(scene: PackedScene) -> Dictionary:
	# Bounded diagnostics/offline callers may explicitly finish this Resource
	# work synchronously; live readiness uses begin/step and yields each unit.
	var state := begin(scene)
	while not state.complete: step(state)
	return progress(state)
