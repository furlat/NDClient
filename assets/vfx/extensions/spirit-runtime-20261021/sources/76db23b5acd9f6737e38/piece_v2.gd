extends "res://assets/vfx/extensions/spirit-runtime-20261021/sources/e3eff9f66a399b9d47ad/piece.gd"
## Three real parent groups; no per-draw resource lookup or unchanged-group scan.
var local_transforms: Array[Transform3D] = []
var transform_publisher: Script


static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_recipient_bank]


static func make_component(input: Dictionary) -> Node3D:
	var bank: Resource = VfxPackageIO_76db23b5ac.resource(input.prepared_recipient_bank)
	if bank == null or not bank.interface_ready:
		return null
	return bank.restore_controller("res://assets/vfx/extensions/spirit-runtime-20261021/sources/76db23b5acd9f6737e38/piece_v2.gd", input)


func sample_analytical_tick(desired_tick: int) -> bool:
	# The original controller only writes this sixteen-frame phase to wings
	# and material.clock. Keep its actual integer tick, including skipped phases.
	if tick > 0:
		var previous_frame := maxi(0, int(floor(float(tick - 1) * 32.0 / float(parameters.simulation_hz)))) % 16
		var desired_frame := maxi(0, int(floor(float(desired_tick - 1) * 32.0 / float(parameters.simulation_hz)))) % 16
		if previous_frame == desired_frame:
			tick = desired_tick
			return true
	return super.sample_analytical_tick(desired_tick)


func create_native_draws() -> bool:
	local_transforms = native_bank.draw_transforms
	transform_publisher = native_bank.transform_publisher
	var mesh_rids: Array[RID] = native_bank.mesh_rids
	var material_rid: RID = native_material.get_rid()
	var owner_id: int = get_instance_id()
	for index: int in mesh_rids.size():
		var instance := RenderingServer.instance_create()
		if not instance.is_valid():
			return false
		native_instances.append(instance)
		native_transforms.append(Transform3D())
		RenderingServer.instance_set_visible(instance, false)
		RenderingServer.instance_set_base(instance, mesh_rids[index])
		RenderingServer.instance_geometry_set_material_override(instance, material_rid)
		RenderingServer.instance_attach_object_instance_id(instance, owner_id)
		RenderingServer.instance_set_layer_mask(instance, native_layer_mask)
	set_notify_transform(true)
	return true


func publish_native_transforms(force: bool = false) -> void:
	if not is_inside_tree() or native_skeleton.is_empty() or not native_skeleton.back().is_inside_tree():
		return
	if group_transforms.size() != native_skeleton.size():
		group_transforms.resize(native_skeleton.size())
		force = true
	var sent := 0
	for parent: int in native_skeleton.size():
		var world: Transform3D = native_skeleton[parent].global_transform
		if not force and group_transforms[parent] == world:
			continue
		group_transforms[parent] = world
		match parent:
			0:
				sent += transform_publisher.publish_root(native_instances, local_transforms, native_transforms, world)
			1:
				sent += transform_publisher.publish_first_wing(native_instances, local_transforms, native_transforms, world)
			2:
				sent += transform_publisher.publish_second_wing(native_instances, local_transforms, native_transforms, world)
	published_transforms += sent


func publish_native_visibility() -> void:
	if native_skeleton.is_empty() or not native_skeleton.back().is_inside_tree():
		return
	var admitted := is_inside_tree() and is_visible_in_tree()
	if native_visible == admitted:
		return
	if admitted:
		# A visibility change needs current matrices, not repeated identical writes.
		publish_native_transforms()
	native_visible = admitted
	for instance: RID in native_instances:
		RenderingServer.instance_set_visible(instance, admitted)

const VfxPackageIO_76db23b5ac = preload("res://assets/vfx/extensions/spirit-runtime-20261021/scoped_resource_io.gd")
