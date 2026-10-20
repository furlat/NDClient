extends "res://assets/vfx/extensions/followup-20261020/sources/672c1ceae061a45e68c9/runtime.gd"
## Additive source-stage variant of the retained public condition occurrence.
## Keep its exact scene, private materials, public inputs and single Clock pool.
const PreparedSurface = preload("res://assets/vfx/extensions/followup-20261020/sources/2f7d88c56bdaa7d52c1c/condition_surface.gd")
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
var source_interface: Resource


func _ready() -> void:
	Profile.begin("condition_original_ready")
	super._ready()
	Profile.end("condition_original_ready")
	if not construction_error.is_empty():
		return
	Profile.begin("condition_pose_interface")
	var interface: Resource=VfxPackageIO_d9eb87da8c.resource(parameters.pose_interface_bank)
	source_interface = interface
	for entry in handle.geometry:
		var material: Material=entry.node.material_override
		if material is ShaderMaterial:
			var matched: bool=interface.bind_private(material,entry.path)
			if not matched:
				print("CONDITION_POSE_INTERFACE_MISMATCH ",JSON.stringify({"bank":parameters.pose_interface_bank,"role":parameters.phase,
					"node":entry.path,"shader":material.shader.resource_path,"source_sha256":material.shader.code.sha256_text(),
					"expected":interface.receipt.shaders}))
			assert(matched,"Actual private material matches immutable original condition shader")
	Profile.end("condition_pose_interface")
	var specification: Dictionary=parameters.get("adaptive_surface",{})
	assert(specification.get("prepared_pose_table",false) and specification.get("kind","") in PreparedSurface.PoseTable.KINDS,"Explicit source-stage optical-table candidate")
	# The original occurrence has registered its original geometry/materials
	# and sampled only the unadmitted zero-age state. No source node, palette,
	# particle simulation or second global clock is introduced here.
	Profile.begin("condition_pose_receiver")
	receiving=PreparedSurface.new()
	receiving.configure(handle.root,specification,handle.geometry)
	Profile.end("condition_pose_receiver")


func _static_bindings(interface: Resource) -> Dictionary:
	# Only these inspected receiver-only scenes have fixed displayed material
	# ownership. Body/history/appearance/live-pose paths retain conservative
	# outer discovery, including their late-created/replaced actor materials.
	for option in ["actor_operation","actor_history","appearance_operation","live_pose"]:
		if parameters.has(option):
			return {}
	if parameters.get("cell_mask",false) or not handle.emitters.is_empty():
		return {}
	if parameters.scene != interface.receipt.scene or interface.scene == null:
		return {}
	var state: SceneState = interface.scene.get_state()
	var actual_nodes := [handle.root]
	actual_nodes.append_array(handle.root.find_children("*","Node",true,false))
	if actual_nodes.size() != state.get_node_count():
		return {}
	var expected_geometry := []
	for entry in handle.geometry:
		expected_geometry.append(entry.node)
	var geometry := []
	var materials := []
	for index in state.get_node_count():
		if state.get_node_instance(index) != null:
			return {}
		var path := str(state.get_node_path(index)).trim_prefix("./")
		var node: Node = handle.root.get_node_or_null(NodePath(path))
		var kind := str(state.get_node_type(index))
		if node == null or node.get_script() != null or node.get_class() != kind or kind not in ["Node3D","MeshInstance3D"]:
			return {}
		if kind != "MeshInstance3D":
			continue
		var draw: MeshInstance3D = node
		var material: ShaderMaterial = draw.material_override as ShaderMaterial
		if draw not in expected_geometry or material == null or material.next_pass != null or draw.material_overlay != null:
			return {}
		if material.shader != interface.prototypes.get(path) or material.get_meta("factory_prepared_shader",null) != material.shader:
			return {}
		var original_mesh: Mesh
		for property_index in state.get_node_property_count(index):
			if state.get_node_property_name(index,property_index) == &"mesh":
				original_mesh = state.get_node_property_value(index,property_index)
		# Some retained sources deliberately contain empty MeshInstance3D
		# placeholders. Keep them, including their material/layer ownership;
		# do not invent geometry or discard source nodes for a cheaper count.
		if draw.mesh != original_mesh:
			return {}
		for surface in draw.get_surface_override_material_count():
			if draw.get_surface_override_material(surface) != null:
				return {}
		geometry.append(draw)
		if material not in materials:
			materials.append(material)
	if geometry.is_empty() or geometry.size() != expected_geometry.size():
		return {}
	return {"geometry":geometry,"materials":materials,"lights":[],"players":[],
		"static_material_topology":true,"static_geometry_layers":true}


func source_bindings() -> Dictionary:
	if source_interface == null or not construction_error.is_empty():
		return {}
	Profile.begin("condition_pose_bindings")
	var result := _static_bindings(source_interface)
	Profile.end("condition_pose_bindings")
	return result

const VfxPackageIO_d9eb87da8c = preload("res://assets/vfx/extensions/followup-20261020/scoped_resource_io.gd")
