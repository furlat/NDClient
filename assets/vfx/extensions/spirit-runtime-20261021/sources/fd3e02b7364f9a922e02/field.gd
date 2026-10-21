extends "res://assets/vfx/extensions/spirit-runtime-20261021/sources/d3632d60843e51e3f3eb/spirit.gd"
## Public owner orbit/admission unchanged; only declared native mesh storage differs.
var native_layer_mask := 0
var layer_witness: GeometryInstance3D


static func preparation_resources(input: Dictionary) -> Array:
	return preload("res://assets/vfx/extensions/spirit-runtime-20261021/sources/aa6d31e0db538a4bab5e/assembly.gd").preparation_resources(input)


static func make_component(input: Dictionary) -> Node3D:
	if str(input.get("owner_uuid", "")).is_empty():
		return null
	var node: Node3D = VfxPackageIO_fd3e02b736.resource("res://assets/vfx/extensions/spirit-runtime-20261021/sources/fd3e02b7364f9a922e02/field.gd").new()
	node.owner_uuid = input.owner_uuid
	node.selections = input.entries.duplicate(true)
	node.opacity_control = input.get("opacity_control", false)
	return node


func prepare_source_layer_mask(value: int) -> void:
	native_layer_mask = value
	if prepared:
		_publish_layer_mask()


func _publish_layer_mask() -> void:
	for entry: Dictionary in entries:
		for leaf: Node3D in entry.composition.components.values():
			if leaf.has_method("set_native_layer_mask"):
				leaf.set_native_layer_mask(native_layer_mask)


func _prepare() -> void:
	super._prepare()
	# The actual unchanged ground draw participates in NativeSource.set_layer.
	# Every captured Spirit mesh has that same native enabled-layer policy.
	assert(cached_bindings.geometry.size() == 1)
	layer_witness = cached_bindings.geometry[0]
	_publish_layer_mask()


func _enter_tree() -> void:
	if not RenderingServer.frame_pre_draw.is_connected(_sync_native_layer):
		RenderingServer.frame_pre_draw.connect(_sync_native_layer)


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_sync_native_layer):
		RenderingServer.frame_pre_draw.disconnect(_sync_native_layer)


func _sync_native_layer() -> void:
	if not prepared or not is_instance_valid(layer_witness):
		return
	var actual_mask: int = layer_witness.layers
	if actual_mask != native_layer_mask:
		native_layer_mask = actual_mask
		_publish_layer_mask()


func native_draw_count() -> int:
	var count := 0
	for entry: Dictionary in entries:
		for leaf: Node3D in entry.composition.components.values():
			if leaf.has_method("capture_native_draws"):
				count += leaf.native_instances.size()
	return count

const VfxPackageIO_fd3e02b736 = preload("res://assets/vfx/extensions/spirit-runtime-20261021/scoped_resource_io.gd")
