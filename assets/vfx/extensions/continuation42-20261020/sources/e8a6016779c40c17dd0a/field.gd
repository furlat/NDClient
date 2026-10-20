extends "res://assets/vfx/extensions/continuation42-20261020/sources/1aba5a2937d9632fe87b/fire_trail.gd"
## Original stationary-owner sampler/adjacency. Only construction is prepared.
const Readiness = preload("res://assets/vfx/extensions/followup-20261020/sources/7dd1897cdd5ee8a903b9/source_readiness.gd")
const SurfaceField = preload("res://assets/vfx/extensions/continuation42-20261020/sources/427e33ec633145d58dd7/surface.gd")
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
const LiveGeometry = preload("res://assets/vfx/extensions/continuation42-20261020/sources/1923f32af33912b47512/live_geometry_bindings.gd")
var bank: Resource
var geometry_revision := 0
var draw_layer_mask := 1
var prepared_geometry: Array[GeometryInstance3D] = []
var prepared_materials: Array[Material] = []


static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.fire_trail_bank)]


static func make_component(input: Dictionary) -> Node3D:
	var path := str(input.fire_trail_bank)
	assert(Readiness.resources.has(path),"Prepare exact native Fire Trail Resources before publication")
	var prepared: Resource = Readiness.resources[path]
	assert(prepared.interface_ready and str(input.source_material) == prepared.source_material)
	var node: Node3D = VfxPackageIO_e8a6016779.resource("res://assets/vfx/extensions/continuation42-20261020/sources/e8a6016779c40c17dd0a/field.gd").new()
	node.bank = prepared
	node.specification = input.duplicate(true)
	node.set_patch_states(input.get("patches",[]))
	return node


func set_patch_states(value: Array) -> bool:
	var supplied: Array = value.duplicate(true)
	for patch: Dictionary in supplied:
		if patch.get("position",null) is Array and patch.position.size() == 3:
			patch.position = Vector3(float(patch.position[0]),float(patch.position[1]),float(patch.position[2]))
	for patch: Dictionary in supplied:
		if str(patch.get("owner_uuid","")) == "" or str(patch.get("surface_kind","")) != "spatial_effect.material.fire" \
			or not patch.get("position",null) is Vector3 or patch.get("cells",[]).is_empty():
			_release()
			patches.clear()
			return false
	patches = supplied
	if is_inside_tree():
		prepare()
	return true


func _release() -> void:
	if not prepared_geometry.is_empty():
		geometry_revision += 1
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	layers.clear()
	flames.clear()
	materials.clear()
	prepared_geometry.clear()
	prepared_materials.clear()


func _surface_input(patch: Dictionary) -> Dictionary:
	return {"source_material":specification.source_material,"perimeter_texture_parameter":"Base_noise2",
		"native_parameters":{"enable_vertex_movement":false,"Color_Intensity2":.6},"opacity":.30,"emission_gain":.18,
		"observed_surface_kind":"spatial_effect.material.fire","surface_admitted":true,"admitted_cells":patch.cells,
		"birth_seconds":.2,"retire_at_seconds":float(patch.get("remove_seconds",1000000.0))}


func prepare() -> void:
	assert(bank != null and bank.interface_ready)
	Profile.begin("fire_trail_actual_patch_resources")
	var previous_geometry := prepared_geometry.duplicate()
	# Retain exactly the current source topology; there is no unbounded hidden
	# pool or precomputed encounter. Surplus old owners/cells are removed.
	while layers.size() > patches.size():
		var layer: Node3D = layers.pop_back()
		remove_child(layer)
		layer.queue_free()
		var removed: Array = flames.pop_back()
		for draw: MeshInstance3D in removed:
			remove_child(draw)
			draw.queue_free()
		materials.pop_back()
	for index in patches.size():
		var patch: Dictionary = patches[index]
		if index == layers.size():
			var layer := SurfaceField.new()
			layer.name = "SurfacePatch%d"%index
			layer.configure_patch(_surface_input(patch),bank.private_material(0),draw_layer_mask)
			add_child(layer)
			layers.append(layer)
			flames.append([])
			materials.append([])
		else:
			layers[index].configure_patch(_surface_input(patch),layers[index].material,draw_layer_mask)
		layers[index].set_live_endpoints([{"point":patch.position}])
		layers[index].sample(0.0)
		var count: int = patch.cells.size()*3
		while flames[index].size() > count:
			var removed: MeshInstance3D = flames[index].pop_back()
			remove_child(removed)
			removed.queue_free()
			materials[index].pop_back()
		for ordinal in count:
			if ordinal == flames[index].size():
				var material: ShaderMaterial = bank.private_material(1)
				var draw := MeshInstance3D.new()
				draw.name = "FirePatch%dFlame%d"%[index,ordinal]
				draw.mesh = bank.cone
				draw.material_override = material
				draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				draw.layers = draw_layer_mask
				draw.hide()
				add_child(draw)
				draw.top_level = true
				flames[index].append(draw)
				materials[index].append(material)
			var cell: Array = patch.cells[ordinal/3]
			var around: int = ordinal%3
			var offset := Vector3(.10 if around == 0 else (-.16 if around == 1 else .18),.018,
				.08 if around == 0 else (-.10 if around == 1 else -.13))
			var draw: MeshInstance3D = flames[index][ordinal]
			# The original setter removes every child before its following sample.
			# Reused identities must remain just as hidden between setter/sample.
			draw.hide()
			draw.global_position = patch.position+Vector3(float(cell[0]),0,float(cell[1]))+offset
			var height := .075 if around == 0 else (.10 if around == 1 else .062)
			var direction := Vector3(.13 if around == 0 else -.12,1,.06).normalized()
			draw.basis = Basis(Quaternion(Vector3.UP,direction))*Basis.from_scale(Vector3(.039 if around == 0 else .032,height,.035))
	prepared_geometry.clear()
	prepared_materials.clear()
	var child_order := 0
	for index in layers.size():
		move_child(layers[index],child_order)
		child_order += 1
		prepared_geometry.append(layers[index].plane)
		prepared_materials.append(layers[index].material)
		for draw: MeshInstance3D in flames[index]:
			move_child(draw,child_order)
			child_order += 1
			prepared_geometry.append(draw)
			prepared_materials.append(draw.material_override)
	for draw: MeshInstance3D in prepared_geometry:
		assert(LiveGeometry.claim_private_material(self,draw),"Only this actual source's private material can rebind")
	if previous_geometry != prepared_geometry:
		geometry_revision += 1
	Profile.end("fire_trail_actual_patch_resources")


func source_bindings() -> Dictionary:
	return {"geometry":prepared_geometry,"materials":prepared_materials,"players":[],"lights":[],
		"static_material_topology":true,"static_geometry_layers":true,"geometry_only_live_rebinding":true}


func source_geometry_revision() -> int:
	return geometry_revision


func prepare_source_layer_mask(mask: int) -> void:
	assert(not is_inside_tree() and mask > 0)
	draw_layer_mask = mask
	for draw: GeometryInstance3D in prepared_geometry:
		if draw.layers != 0:
			draw.layers = mask


func has_verified_stable_paths() -> bool:
	return bank != null and prepared_geometry.size() == prepared_materials.size()


func refresh_live_inputs(seconds: float) -> void:
	# No particle/history/player exists in this source. Actual new state/cells
	# may refresh its inherited adjacency/envelope at a held display age.
	sample(seconds)

const VfxPackageIO_e8a6016779 = preload("res://assets/vfx/extensions/continuation42-20261020/scoped_resource_io.gd")
