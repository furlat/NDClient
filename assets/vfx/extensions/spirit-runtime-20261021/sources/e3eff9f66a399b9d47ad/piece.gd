extends "res://assets/vfx/extensions/spirit-runtime-20261021/sources/422f318d32d3bc476875/absolute_spirit_piece.gd"
## Individual native draw instances; original controller still owns every wing/clock.
var native_bank: Resource
var native_skeleton: Array[Node3D] = []
var native_material: ShaderMaterial
var native_instances: Array[RID] = []
var native_transforms: Array[Transform3D] = []
var native_layer_mask := 0
var native_visible := false
var native_scenario := RID()
var group_transforms: Array[Transform3D] = []
var published_transforms := 0


static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_recipient_bank]


static func make_component(input: Dictionary) -> Node3D:
	var bank: Resource = VfxPackageIO_e3eff9f66a.resource(input.prepared_recipient_bank)
	if bank == null or not bank.interface_ready:
		return null
	return bank.restore_controller("res://assets/vfx/extensions/spirit-runtime-20261021/sources/e3eff9f66a399b9d47ad/piece.gd", input)


func create_native_draws() -> bool:
	for index: int in native_bank.meshes.size():
		var instance := RenderingServer.instance_create()
		if not instance.is_valid():
			return false
		native_instances.append(instance)
		native_transforms.append(Transform3D())
		RenderingServer.instance_set_visible(instance, false)
		RenderingServer.instance_set_base(instance, native_bank.meshes[index].get_rid())
		RenderingServer.instance_geometry_set_material_override(instance, native_material.get_rid())
		RenderingServer.instance_attach_object_instance_id(instance, get_instance_id())
		RenderingServer.instance_set_layer_mask(instance, native_layer_mask)
		# The compiler rejects any nondefault GeometryInstance3D field. The native
		# source constructors also leave these exact RenderingServer defaults alone.
		# Full captured settings remain in the bank/state oracle, not new setters.
	set_notify_transform(true)
	return true


func set_native_layer_mask(value: int) -> void:
	if native_layer_mask == value:
		return
	native_layer_mask = value
	for instance: RID in native_instances:
		RenderingServer.instance_set_layer_mask(instance, value)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for instance: RID in native_instances:
			RenderingServer.free_rid(instance)
		native_instances.clear()
	elif what == NOTIFICATION_ENTER_WORLD:
		native_scenario = get_world_3d().scenario
		for instance: RID in native_instances:
			RenderingServer.instance_set_scenario(instance, native_scenario)
		group_transforms.clear()
		if is_node_ready():
			_restore_reentered_world.call_deferred()
	elif what == NOTIFICATION_EXIT_WORLD:
		native_scenario = RID()
		for instance: RID in native_instances:
			RenderingServer.instance_set_scenario(instance, RID())
		native_visible = false
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_inside_tree():
			publish_native_visibility()
	elif what == NOTIFICATION_TRANSFORM_CHANGED:
		if is_inside_tree() and is_visible_in_tree():
			publish_native_transforms()


func publish_native_visibility() -> void:
	if native_skeleton.is_empty() or not native_skeleton.back().is_inside_tree():
		return
	var admitted := is_inside_tree() and is_visible_in_tree()
	if native_visible == admitted:
		return
	if admitted:
		publish_native_transforms(true)
	native_visible = admitted
	for index: int in native_instances.size():
		RenderingServer.instance_set_visible(native_instances[index], admitted and native_bank.geometry_states[index].visible)


func publish_native_transforms(force: bool = false) -> void:
	if not is_inside_tree() or native_skeleton.is_empty() or not native_skeleton.back().is_inside_tree():
		return
	var current: Array[Transform3D] = []
	for part: Node3D in native_skeleton:
		current.append(part.global_transform)
	for index: int in native_instances.size():
		var parent: int = native_bank.draw_parents[index]
		if not force and group_transforms.size() == current.size() and current[parent] == group_transforms[parent]:
			continue
		var actual: Transform3D = current[parent] * native_bank.draw_transforms[index]
		native_transforms[index] = actual
		RenderingServer.instance_set_transform(native_instances[index], actual)
		published_transforms += 1
	group_transforms = current


func sample(seconds: float) -> void:
	super.sample(seconds)
	publish_native_transforms()
	publish_native_visibility()


func _ready() -> void:
	super._ready()
	publish_native_transforms(true)
	publish_native_visibility()


func _restore_reentered_world() -> void:
	if is_inside_tree():
		publish_native_transforms()
		publish_native_visibility()


func source_bindings() -> Dictionary:
	return {"geometry": [], "materials": [native_material], "lights": [], "players": [],
		"static_material_topology": true, "static_geometry_layers": true}


func capture_native_draws() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in native_instances.size():
		result.append({"path": native_bank.draw_paths[index], "instance": native_instances[index],
			"mesh": native_bank.meshes[index], "material": native_material,
			"transform": native_transforms[index], "state": native_bank.geometry_states[index],
			"visible": native_visible and native_bank.geometry_states[index].visible,
			"layer_mask": native_layer_mask, "scenario": native_scenario})
	return result

const VfxPackageIO_e3eff9f66a = preload("res://assets/vfx/extensions/spirit-runtime-20261021/scoped_resource_io.gd")
