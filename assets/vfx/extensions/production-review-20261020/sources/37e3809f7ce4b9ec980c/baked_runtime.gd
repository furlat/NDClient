extends RefCounted
## Current execution adapter. The pinned player owns recorded VAT/path state;
## preserved native GPU ribbon emitters keep their real history. Such hybrids
## require replay for arbitrary seeks, rather than a fake seekable recording.
const Recorded = preload("res://assets/vfx/extensions/production-review-20261020/sources/c80c403105490edb11e8/baked_effect.gd")
const ParticleUnits = preload("res://assets/vfx/extensions/followup-20261020/sources/dce4978aa79c8ef7fd8e/runtime_particle_units.gd")
const Placement = preload("res://assets/vfx/extensions/production-review-20261020/sources/9c6c13300477124c2cf5/recorded_placement.gd")
const SourceValues = preload("res://assets/vfx/extensions/production-review-20261020/sources/87dd100983f5c2792f7b/recorded_source_values.gd")

static func make(parent: Node3D, bundle: Resource, clip: Dictionary, layer_mask: int) -> Dictionary:
	var handle: Dictionary = _make_recorded(parent, bundle, clip, layer_mask)
	if not handle.error.is_empty():
		return handle
	var declarations: Variant = bundle.get("material_placements")
	if declarations is Array and not declarations.is_empty():
		var admitted := Placement.prepare(handle.root, declarations, bundle.private_materials)
		handle.recorded_placement_bindings = admitted.bindings
		handle.error = admitted.error
		if not handle.error.is_empty():
			handle.root.hide()
			return handle
	# Only the explicit new data Resource opts in. Old recording constructors
	# retain their original track traversal and source-age path.
	if bundle.get("source_loop") is Dictionary:
		handle.declared_source_values = true
		handle.error = SourceValues.prepare(handle)
		if not handle.error.is_empty():
			handle.root.hide()
			return handle
	# Zero-scale reveals are valid source transforms. Transform3D's quaternion
	# interpolation rejects their singular bases, even at an exact frame. Keep
	# endpoints exact and interpolate those exceptional matrices directly.
	handle.transform_tracks = handle.tracks.filter(func(entry):return entry.track.values[0] is Transform3D)
	handle.tracks = handle.tracks.filter(func(entry):return not entry.track.values[0] is Transform3D)
	handle.native_gpu_emitters = []
	handle.native_gpu_units = []
	handle.native_gpu_age = 0.
	for entry in handle.root.get_meta("factory_native_gpu_emitters", []):
		var node: GPUParticles3D = handle.root.get_node(entry.path)
		if node.process_material != null:
			node.process_material = node.process_material.duplicate(true)
		var binding := ParticleUnits.prepare(node)
		if not binding.is_empty():
			handle.native_gpu_units.append(binding)
		handle.native_gpu_emitters.append({"node":node,"speed":entry.speed})
	return handle

static func sample(handle: Dictionary, seconds: float) -> void:
	var previous: float = handle.get("native_gpu_age", 0.)
	ParticleUnits.restore(handle.get("native_gpu_units", []))
	var source_seconds: float = SourceValues.source_seconds(handle.bundle, seconds) if handle.get("declared_source_values", false) else seconds
	_sample_transforms(handle, source_seconds)
	Recorded.sample(handle, source_seconds)
	if handle.get("declared_source_values", false): SourceValues.sample(handle, source_seconds)
	if handle.has("recorded_placement_bindings"):
		var error := Placement.apply(handle.recorded_placement_bindings)
		if not error.is_empty():
			handle.error = error
			handle.root.hide()
			return
	var emitters: Array = handle.get("native_gpu_emitters", [])
	if emitters.is_empty() or is_equal_approx(seconds, previous):
		return
	var delta := maxf(0., seconds - previous)
	var native_delta: float = handle.root.get_process_delta_time()
	if seconds < previous:
		for entry in emitters:
			entry.node.restart()
		handle.native_gpu_replay_required = seconds > 0.
	var speed := delta / minf(native_delta, .1) if native_delta > 0. else 0.
	for entry in emitters:
		entry.node.speed_scale = speed * float(entry.speed)
	ParticleUnits.apply(handle.native_gpu_units, handle.root.global_basis.get_scale().x)
	handle.native_gpu_age = seconds
	if speed > 0.:
		RenderingServer.frame_post_draw.connect(func():
			for entry in emitters:
				if is_instance_valid(entry.node):
					entry.node.speed_scale = 0., CONNECT_ONE_SHOT)

static func direct_seek_supported(handle: Dictionary) -> bool:
	return handle.get("native_gpu_emitters", []).is_empty()

static func follow(handle: Dictionary, cue: Dictionary, seconds: float, root_at: Callable) -> void:
	Recorded.follow(handle, cue, seconds, root_at)

static func release(handle: Dictionary) -> void:
	Recorded.release(handle)

static func _sample_transforms(handle: Dictionary, seconds: float) -> void:
	if handle.get("sampled", false) and is_equal_approx(float(handle.age), seconds):
		return
	var frame := clampf(seconds * handle.bundle.rate, 0.0, float(handle.bundle.frames - 1))
	var low := int(frame)
	var high := mini(low + 1, handle.bundle.frames - 1)
	var weight := frame - float(low)
	for entry in handle.transform_tracks:
		var first: Transform3D = entry.track.values[low]
		var value := first
		if entry.track.blend and high != low and weight > 0.0:
			var last: Transform3D = entry.track.values[high]
			if is_zero_approx(first.basis.determinant()) or is_zero_approx(last.basis.determinant()):
				value = Transform3D(Basis(first.basis.x.lerp(last.basis.x, weight),
					first.basis.y.lerp(last.basis.y, weight), first.basis.z.lerp(last.basis.z, weight)),
					first.origin.lerp(last.origin, weight))
			else:
				value = first.interpolate_with(last, weight)
		entry.target.set(entry.track.property, value)

static func _make_recorded(parent: Node3D, bundle: Resource, clip: Dictionary, layer_mask: int) -> Dictionary:
	var mesh_private: Array = bundle.get_meta("factory_mesh_private_materials", [])
	if mesh_private.is_empty():
		return Recorded.make(parent, bundle, clip, layer_mask)
	var compatible: Resource = bundle.duplicate()
	compatible.tracks = bundle.tracks.filter(func(track):return track.kind=="node" or int(track.material) not in mesh_private)
	var source_clip := clip.duplicate(false)
	source_clip.erase("opacity_uniform")
	Recorded._textures[compatible] = Recorded._textures.get(bundle, [])
	var handle: Dictionary = Recorded.make(parent, compatible, source_clip, layer_mask)
	Recorded._textures.erase(compatible)
	if not handle.error.is_empty():
		return handle
	handle.bundle = bundle
	handle.clip = clip.duplicate(false)
	var locations: Array = Recorded.material_locations(handle.root)
	var copies := {}
	var meshes := {}
	for index in mesh_private:
		var material: Material = locations[index].material.duplicate()
		copies[index] = material
		for location in locations[index].locations:
			if location.kind != "pass":
				Recorded._bind(handle.root, location, material)
				continue
			var node: GPUParticles3D = handle.root.get_node(location.path)
			var key: Array = [node, location.pass]
			if not meshes.has(key):
				# One import-time geometry copy, never a per-frame readback. The
				# separate passes/surfaces retain their original materials and UVs.
				var copy: Mesh = node.get_draw_pass_mesh(location.pass).duplicate()
				node.set_draw_pass_mesh(location.pass, copy)
				meshes[key] = copy
			meshes[key].surface_set_material(location.surface, material)
	for track in bundle.tracks:
		if track.kind == "material" and int(track.material) in mesh_private:
			handle.tracks.append({"target":copies[int(track.material)],"track":track})
	var opacity := str(clip.get("opacity_uniform", ""))
	if not opacity.is_empty():
		for entry in Recorded.material_locations(handle.root):
			var material: Material = entry.material
			if material is ShaderMaterial and material.shader.get_shader_uniform_list().any(func(uniform):return uniform.name==opacity):
				var value: Variant = material.get_shader_parameter(opacity)
				handle.opacity_bindings.append({"material":material,"uniform":opacity,"native":1. if value==null else float(value)})
		if handle.opacity_bindings.is_empty():
			handle.error = "Missing recorded opacity control: " + opacity
	return handle
