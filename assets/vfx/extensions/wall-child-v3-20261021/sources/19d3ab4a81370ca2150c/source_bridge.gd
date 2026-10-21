extends RefCounted
## Offline comparison bridge: the same Factory sampler used by its actor stage.
## The fourth argument matches the production baker's no-prepared-source call.
const NativeSource = preload("res://assets/vfx/extensions/wall-child-v3-20261021/sources/e139201e6fe67fc24627/recording_source_sampler.gd")
const SourceSpace = preload("res://assets/vfx/sources/6487dfcacdbd7bcc9361/native_source_space.gd")
const ResourceGraph = preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")


static func make(parent: Node3D, clip: Dictionary, layer_mask: int, _use_prepared: bool = false) -> Dictionary:
	ResourceGraph.native_sampler_scopes += 1
	Profile.begin("source_construction")
	var handle: Dictionary = NativeSource.make(parent, clip.duplicate(true), layer_mask)
	Profile.end("source_construction")
	ResourceGraph.native_sampler_scopes -= 1
	if handle.error.is_empty():
		Profile.begin("source_path_normalization")
		# An exact prepared constructor may prove its complete native names and
		# paths offline. All actual components must opt in; an unknown component,
		# a renamed/ambiguous root or an unprepared source retains normalization.
		# Geometry paths were already collected after component registration.
		var stable: bool = not handle.components.is_empty()
		for key in handle.components:
			var component: Node = handle.components[key]
			if component.name != String(key) or String(component.name).begins_with("@") or not component.has_method("has_verified_stable_paths"):
				stable = false
				break
			var verified: Variant = component.has_verified_stable_paths()
			if not verified is bool or not verified:
				stable = false
				break
		if not stable:
			preload("res://assets/vfx/sources/e8a2e9f9c17a7274c3d7/stable_source_paths.gd").normalize(handle.root)
			for geometry in handle.geometry:
				geometry.path = str(handle.root.get_path_to(geometry.node))
		handle.source_paths_prepared = stable
		Profile.end("source_path_normalization")
		Profile.begin("source_adaptation")
		SourceSpace.adapt_materials(handle.materials) if handle.has("materials") else SourceSpace.adapt(handle.root)
		Profile.end("source_adaptation")
	return handle


static func sample(handle: Dictionary, seconds: float, frame_seconds: float, motion_seconds: float = NAN) -> void:
	NativeSource.sample(handle, seconds, frame_seconds, motion_seconds)


static func refresh_live_geometry(handle: Dictionary) -> bool:
	return NativeSource.LiveGeometry.refresh(handle)


static func acknowledge_live_geometry(handle: Dictionary, clock_owner: RefCounted) -> bool:
	return NativeSource.LiveGeometry.acknowledge(handle,clock_owner)


static func note_live_geometry_change(handle: Dictionary, node: Node) -> void:
	NativeSource.LiveGeometry.note_tree_change(handle,node)


static func close(handle: Dictionary) -> void:
	NativeSource.close(handle)
