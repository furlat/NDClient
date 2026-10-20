extends RefCounted
## Opt-in mesh-only topology. Default sources retain their original discovery.
const CLAIM := "factory_live_geometry_private_claim"
const OWNER_KEY := "factory_live_geometry_owner_id"
static var script_interfaces: Dictionary = {}


static func claim_private_material(owner: Node3D, draw: MeshInstance3D) -> bool:
	if not is_instance_valid(owner) or not owner.is_ancestor_of(draw) or not draw.material_override is ShaderMaterial:
		return false
	var material: ShaderMaterial = draw.material_override
	if material.has_meta(CLAIM):
		var previous: Dictionary = material.get_meta(CLAIM)
		return previous.owner.get_ref() == owner and previous.material.get_ref() == material and previous.shader == material.shader
	material.set_meta(CLAIM,{"owner":weakref(owner),"material":weakref(material),"shader":material.shader})
	return true


static func _private(owner: Node3D, material: ShaderMaterial) -> bool:
	if not material.has_meta(CLAIM):
		return false
	var claim: Dictionary = material.get_meta(CLAIM)
	return claim.owner.get_ref() == owner and claim.material.get_ref() == material and claim.shader == material.shader


static func reject(handle: Dictionary, reason: String) -> bool:
	if handle.get("error","").is_empty():
		handle.error = "Live geometry registration rejected: "+reason
	if is_instance_valid(handle.get("root")):
		handle.root.hide()
	return false


static func _safe_script(script: Script) -> bool:
	if script == null:
		return true
	if script_interfaces.has(script):
		return script_interfaces[script]
	var current: Script = script
	var safe := true
	while current != null:
		for method: Dictionary in current.get_script_method_list():
			if method.name in ["_enter_tree","_ready","_process","_physics_process","_input","_unhandled_input","_notification"]:
				safe = false
		current = current.get_base_script()
	script_interfaces[script] = safe
	return safe


static func _interface(material: ShaderMaterial) -> Dictionary:
	return {"clock_names":material.get_meta("factory_clock_names",null),
		"pool_required":material.get_meta("factory_clock_pool_required",null),
		"world_space":material.get_meta("factory_world_space_uniform",null)}


static func _validate(handle: Dictionary, owner: Node3D, bindings: Dictionary, programs: Dictionary) -> bool:
	if not bindings.get("geometry_only_live_rebinding",false) or not bindings.get("static_material_topology",false) \
		or not bindings.get("players",[]).is_empty() or not bindings.get("lights",[]).is_empty() \
		or not bindings.get("recorded_time_emitters",[]).is_empty():
		return reject(handle,"only explicitly prepared mesh geometry may rebind")
	if not str(handle.clip.get("opacity_uniform",handle.clip.get("placement",{}).get("opacity_uniform",""))).is_empty():
		return reject(handle,"dynamic mesh source has no qualified occurrence-opacity interface")
	if not _safe_script(owner.get_script()):
		return reject(handle,"source callback ownership is not a pure explicit sampler")
	var actual_geometry := []
	for node: Node in owner.find_children("*","",true,false):
		if node.get_class() not in ["Node3D","MeshInstance3D"] or not _safe_script(node.get_script()):
			return reject(handle,"unqualified native node/controller in changed source")
		if node is MeshInstance3D:
			actual_geometry.append(node)
	if actual_geometry != bindings.geometry:
		return reject(handle,"source must declare every actual mesh in native child order")
	var actual_materials := []
	for draw: MeshInstance3D in bindings.geometry:
		if not owner.is_ancestor_of(draw) or draw.mesh == null or draw.material_overlay != null or not draw.material_override is ShaderMaterial:
			return reject(handle,"unsupported changed displayed material slot")
		for surface in draw.get_surface_override_material_count():
			if draw.get_surface_override_material(surface) != null:
				return reject(handle,"undeclared surface override")
		for surface in draw.mesh.get_surface_count():
			if draw.mesh.surface_get_material(surface) != null:
				return reject(handle,"undeclared mesh surface material")
		var material: ShaderMaterial = draw.material_override
		if material.shader == null or material.next_pass != null or not _private(owner,material):
			return reject(handle,"changed material lacks its actual private owner identity")
		if material.get_meta("factory_prepared_shader",null) != material.shader:
			return reject(handle,"changed material is not its prepared program")
		var interface := _interface(material)
		if interface.world_space != false or interface.pool_required != true or not interface.clock_names is Array or interface.clock_names.is_empty():
			return reject(handle,"unknown source-space/clock interface")
		if not programs.is_empty() and (not programs.has(material.shader) or programs[material.shader] != interface):
			return reject(handle,"new program or clock interface cannot join at runtime")
		if material not in actual_materials:
			actual_materials.append(material)
	if actual_materials != bindings.materials:
		return reject(handle,"source must declare exactly its displayed private materials")
	return true


static func capture(handle: Dictionary) -> void:
	var records := []
	for component: Node3D in handle.components.values():
		if not component.has_method("source_geometry_revision"):
			continue
		var bindings: Dictionary = component.source_bindings()
		if not bindings.get("geometry_only_live_rebinding",false):
			continue
		var revision: Variant = component.source_geometry_revision()
		if not revision is int or revision < 0 or not _validate(handle,component,bindings,{}):
			reject(handle,"invalid initial mesh revision/interface")
			return
		var programs := {}
		for material: ShaderMaterial in bindings.materials:
			programs[material.shader] = _interface(material)
		if programs.is_empty():
			reject(handle,"initial source must establish its actual prepared program interfaces")
			return
		var owner_id := component.get_instance_id()
		for entry: Dictionary in handle.geometry:
			if entry.node in bindings.geometry:
				entry[OWNER_KEY] = owner_id
		records.append({"owner":component,"owner_id":owner_id,"revision":revision,
			"programs":programs,"materials":bindings.materials.duplicate(),"dirty":false,"validations":1,
			"geometry_at":handle.geometry.find(handle.geometry.filter(func(entry:Dictionary)->bool:return entry.get(OWNER_KEY,0) == owner_id)[0]),
			"materials_at":handle.materials.find(bindings.materials[0])})
	if not records.is_empty():
		handle.live_geometry_bindings = records
		handle.live_geometry_pending = false


static func note_tree_change(handle: Dictionary, node: Node) -> void:
	for record: Dictionary in handle.get("live_geometry_bindings",[]):
		if record.owner == node or record.owner.is_ancestor_of(node):
			record.dirty = true
			continue
		for entry: Dictionary in handle.geometry:
			if entry.get(OWNER_KEY,0) == record.owner_id and entry.node == node:
				record.dirty = true
				break


static func refresh(handle: Dictionary) -> bool:
	if not handle.has("live_geometry_bindings") or not handle.error.is_empty():
		return false
	var changed := false
	for record: Dictionary in handle.live_geometry_bindings:
		var revision: Variant = record.owner.source_geometry_revision()
		if not revision is int or revision < int(record.revision):
			return reject(handle,"mesh revision must remain monotonic")
		if revision == record.revision:
			if record.dirty:
				return reject(handle,"topology changed without a new declared revision")
			continue
		var bindings: Dictionary = record.owner.source_bindings()
		if not _validate(handle,record.owner,bindings,record.programs):
			return false
		var retained := []
		var previous := {}
		var geometry_at := -1
		for entry: Dictionary in handle.geometry:
			if entry.get(OWNER_KEY,0) == record.owner_id:
				if geometry_at < 0:
					geometry_at = retained.size()
				if is_instance_valid(entry.node):
					previous[entry.node.get_instance_id()] = entry
			else:
				retained.append(entry)
		var current := []
		for draw: MeshInstance3D in bindings.geometry:
			var entry: Dictionary = previous.get(draw.get_instance_id(),{})
			if entry.is_empty():
				entry = {"node":draw,"selected":draw.visible and draw.layers != 0,"layer_enabled":draw.layers != 0}
				entry[OWNER_KEY] = record.owner_id
			entry.path = str(handle.root.get_path_to(draw))
			if draw.layers != 0:
				draw.layers = int(handle.layer_mask)
			current.append(entry)
		if geometry_at < 0:
			geometry_at = mini(int(record.geometry_at),retained.size())
		handle.geometry = retained.slice(0,geometry_at)+current+retained.slice(geometry_at)
		var old_materials: Array = record.materials
		var materials_at: int = handle.materials.find(old_materials[0]) if not old_materials.is_empty() else -1
		var retained_materials: Array = handle.materials.filter(func(material:Material)->bool:return material not in old_materials)
		if materials_at < 0:
			materials_at = mini(int(record.materials_at),retained_materials.size())
		handle.materials = retained_materials.slice(0,materials_at)+bindings.materials+retained_materials.slice(materials_at)
		record.materials = bindings.materials.duplicate()
		record.revision = revision
		record.dirty = false
		record.validations += 1
		changed = true
	if changed:
		handle.live_geometry_pending = true
	return changed


static func acknowledge(handle: Dictionary, clock_owner: RefCounted) -> bool:
	if not handle.get("live_geometry_pending",false):
		return true
	for record: Dictionary in handle.live_geometry_bindings:
		for material: ShaderMaterial in record.materials:
			if clock_owner.slot < 0 or clock_owner.seen_materials.get(material,null) != material.shader \
				or material.get_shader_parameter("vfx_package_clock_slot") != clock_owner.slot:
				return reject(handle,"new draw lacks the actual occurrence-clock binding before display")
	handle.live_geometry_pending = false
	return true


static func ready_to_sample(handle: Dictionary) -> bool:
	if not handle.has("live_geometry_bindings"):
		return true
	refresh(handle)
	if not handle.error.is_empty():
		return false
	if handle.get("live_geometry_pending",false):
		return reject(handle,"caller omitted material-clock registration before source sampling")
	return true


static func after_sample(handle: Dictionary) -> bool:
	for record: Dictionary in handle.get("live_geometry_bindings",[]):
		if record.dirty or record.owner.source_geometry_revision() != record.revision:
			return reject(handle,"source callback changed topology after acknowledgement")
	return true
