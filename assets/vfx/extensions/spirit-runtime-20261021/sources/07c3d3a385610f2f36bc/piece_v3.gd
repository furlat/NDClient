extends "res://assets/vfx/extensions/spirit-runtime-20261021/sources/76db23b5acd9f6737e38/piece_v2.gd"
## Native draw updates read typed binding members; observations are built on demand.
var draw_binding: RefCounted


static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_recipient_bank]


static func make_component(input: Dictionary) -> Node3D:
	var bank: Resource = VfxPackageIO_07c3d3a385.resource(input.prepared_recipient_bank)
	if bank == null or not bank.interface_ready:
		return null
	return bank.restore_controller("res://assets/vfx/extensions/spirit-runtime-20261021/sources/07c3d3a385610f2f36bc/piece_v3.gd", input)


func create_native_draws() -> bool:
	if not super.create_native_draws():
		return false
	draw_binding = transform_publisher.new()
	draw_binding.bind(native_instances, local_transforms)
	return true


func publish_native_transforms(force: bool = false) -> void:
	if not is_inside_tree() or native_skeleton.is_empty() or not native_skeleton.back().is_inside_tree():
		return
	if group_transforms.size() != native_skeleton.size():
		group_transforms.resize(native_skeleton.size())
		force = true
	for parent: int in native_skeleton.size():
		var world: Transform3D = native_skeleton[parent].global_transform
		if not force and group_transforms[parent] == world:
			continue
		group_transforms[parent] = world
		match parent:
			0:
				published_transforms += draw_binding.publish_root(world)
			1:
				published_transforms += draw_binding.publish_first_wing(world)
			2:
				published_transforms += draw_binding.publish_second_wing(world)


func capture_native_draws() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in native_instances.size():
		# The actual command used this cached parent, not a future/unpublished
		# Node transform. This diagnostic does not issue native setters.
		var world: Transform3D = group_transforms[native_bank.draw_parents[index]]
		result.append({"path": native_bank.draw_paths[index], "instance": native_instances[index],
			"mesh": native_bank.meshes[index], "material": native_material,
			"transform": world * local_transforms[index], "state": native_bank.geometry_states[index],
			"visible": native_visible and native_bank.geometry_states[index].visible,
			"layer_mask": native_layer_mask, "scenario": native_scenario})
	return result

const VfxPackageIO_07c3d3a385 = preload("res://assets/vfx/extensions/spirit-runtime-20261021/scoped_resource_io.gd")
