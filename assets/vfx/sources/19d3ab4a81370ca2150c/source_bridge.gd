extends RefCounted
## Offline comparison bridge: the same Factory sampler used by its actor stage.
## The fourth argument matches the production baker's no-prepared-source call.
const NativeSource = preload("res://assets/vfx/sources/e139201e6fe67fc24627/recording_source_sampler.gd")
const SourceSpace = preload("res://assets/vfx/sources/6487dfcacdbd7bcc9361/native_source_space.gd")
const ResourceGraph = preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")


static func make(parent: Node3D, clip: Dictionary, layer_mask: int, _use_prepared: bool = false) -> Dictionary:
	ResourceGraph.native_sampler_scopes += 1
	var handle: Dictionary = NativeSource.make(parent, clip.duplicate(true), layer_mask)
	ResourceGraph.native_sampler_scopes -= 1
	if handle.error.is_empty():
		preload("res://assets/vfx/sources/e8a2e9f9c17a7274c3d7/stable_source_paths.gd").normalize(handle.root)
		for geometry in handle.geometry:
			geometry.path = str(handle.root.get_path_to(geometry.node))
		SourceSpace.adapt(handle.root)
	return handle


static func sample(handle: Dictionary, seconds: float, frame_seconds: float, motion_seconds: float = NAN) -> void:
	NativeSource.sample(handle, seconds, frame_seconds, motion_seconds)


static func close(handle: Dictionary) -> void:
	NativeSource.close(handle)
