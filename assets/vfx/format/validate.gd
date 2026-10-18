extends SceneTree
## Runs unchanged in a fresh project and in the real client project. Does not
## import, rewrite or bake anything; only loads and exercises finished files.
var failures: Array = []
var rows: Array = []


func geometry(actor: String) -> Dictionary:
	var points := []
	for row in 15:
		for column in 11:
			points.append({"pixel": Vector2i(column, row), "position": Vector3(float(column - 5) * .052, float(14 - row) * .085, .035 * cos(float(row) * .34)),
				"normal": Vector3(0.0, 0.0, 1.0), "slot": "body", "uv": Vector2(float(column) / 10.0, float(row) / 14.0)})
	return {"actor": actor, "origin": Vector3.ZERO, "points": points,
		"gpu_geometry_key": ["package-fixture", 0], "pose_key": ["package-fixture", 0]}


func supply_geometry(instance: Node3D) -> void:
	var endpoints := []
	for index in 16:
		endpoints.append({"point": Vector3(-1.5, .7, 0.0) if index == 0 else Vector3(float(index) * .35, .6, .15),
			"actor": "caster" if index == 0 else "target", "view_basis": Basis.IDENTITY})
	for node in instance.handle.root.find_children("*", "Node", true, false):
		if node.get_script() != null and node.get_script().resource_path.ends_with("/blade_barrier.gd"):
			endpoints[0].point = Vector3.ZERO
			endpoints[1].point = Vector3(node.cached_length, 0.0, 0.0)
	instance.set_targets(endpoints)
	for node in instance.handle.root.find_children("*", "Node", true, false):
		if node.get_script() != null and node.get_script().resource_path.ends_with("/blade_barrier.gd"):
			node.set_live_endpoints([{"point": Vector3.ZERO}, {"point": Vector3(node.cached_length, 0.0, 0.0)}])
		if node.has_method("set_entity_geometry"):
			var actor := "target"
			for property in node.get_property_list():
				if property.name in ["settings", "specification", "parameters"]:
					var specification: Variant = node.get(property.name)
					if specification is Dictionary:
						actor = str(specification.get("geometry_actor", actor))
						actor = str(specification.get("application", {}).get("target_actor", actor))
			node.set_entity_geometry(geometry(actor))
	instance.refresh_material_bindings()


func warm_resources(instance: Node3D) -> Array:
	var result := []
	var seen := {}
	var materials := []
	var visited := {}
	for node in instance.handle.root.find_children("*", "Node", true, false):
		instance._collect_materials(node, visited, materials)
	for material in materials:
		var key: String
		if material is ShaderMaterial:
			key = material.shader.code.sha256_text()
		else:
			var fields := {}
			for property in material.get_property_list():
				if int(property.usage) & PROPERTY_USAGE_STORAGE:
					var value: Variant = material.get(property.name)
					fields[property.name] = value.resource_path if value is Resource else value
			key = str(fields).sha256_text()
		if seen.has(key):
			continue
		seen[key] = true
		var target := "res://assets/vfx/warm/" + key + ".res"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target.get_base_dir()))
		if not FileAccess.file_exists(target):
			assert(ResourceSaver.save(material, target, ResourceSaver.FLAG_COMPRESS) == OK)
		result.append(target)
	return result


func _initialize() -> void:
	call_deferred("run")


func gpu_memory() -> int:
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) + RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)


func run() -> void:
	var options := {}
	for argument in OS.get_cmdline_user_args():
		var parts := argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/index.json"))
	var start: int = int(options.get("start", "0"))
	var limit: int = int(options.get("limit", str(index.clips.size())))
	var holder := Node3D.new()
	root.add_child(holder)
	var camera := Camera3D.new()
	holder.add_child(camera)
	camera.position = Vector3(3.0, 3.0, 6.0)
	camera.look_at(Vector3(0.0, 0.5, 0.0))
	for clip_index in range(start, mini(start + limit, index.clips.size())):
		var clip: Dictionary = index.clips[clip_index]
		for approach in clip.approaches:
			print("PACKAGE_VALIDATE_BEGIN ", clip_index, " ", clip.clip_id, " ", approach.id)
			var row := {"clip_id": clip.clip_id, "approach": approach.id, "errors": []}
			var begun := Time.get_ticks_usec()
			var resource: Resource = ResourceLoader.load(approach.path)
			row.load_ms = float(Time.get_ticks_usec() - begun) / 1000.0
			if resource == null:
				row.errors.append("ResourceLoader.load failed")
			elif approach.kind in ["native", "gpu"] and options.has("construct"):
				var before := gpu_memory()
				begun = Time.get_ticks_usec()
				var instance: Node3D = resource.make_component({"layer_mask": 2})
				if instance == null:
					row.errors.append("Constructor returned null")
				else:
					holder.add_child(instance)
					row.construction_ms = float(Time.get_ticks_usec() - begun) / 1000.0
					for input_name in clip.input_setters:
						if not instance.has_method(clip.input_setters[input_name]):
							row.errors.append("Missing input setter: " + str(input_name))
					if not instance.construction_error.is_empty():
						row.errors.append(instance.construction_error)
					elif options.has("geometry"):
						supply_geometry(instance)
					if options.has("warm"):
						row.warm = warm_resources(instance)
					var samples := []
					for tick in 4:
						begun = Time.get_ticks_usec()
						instance.sample(float(tick) / float(clip.simulation_hz))
						samples.append(Time.get_ticks_usec() - begun)
						await process_frame
						await RenderingServer.frame_post_draw
					samples.sort()
					row.sample_us = samples[2]
					row.gpu_bytes = maxi(0, gpu_memory() - before)
					row.clock_slot = instance.clock.slot if instance.clock != null else -1
					row.clock_materials = instance.clock.bindings.size() if instance.clock != null else 0
					instance.free()
					await process_frame
			elif approach.kind == "recorded" and resource != null:
				var scene: Node = resource.scene.instantiate()
				for node in scene.find_children("*", "Node", true, false):
					if node.get_script() != null:
						row.errors.append("Recorded scene has running script")
					if node is GPUParticles3D and node.process_material != null:
						row.errors.append("Recorded scene has particle playback shader")
				scene.free()
			rows.append(row)
			if not row.errors.is_empty():
				failures.append(row)
		var report_path: String = options.get("report", "user://vfx-package-validation.json")
		FileAccess.open(report_path, FileAccess.WRITE).store_string(JSON.stringify({"rows": rows, "failures": failures, "project": ProjectSettings.globalize_path("res://"), "package_version": index.version, "index_sha256": FileAccess.get_sha256("res://assets/vfx/index.json")}, "  "))
	print("PACKAGE_VALIDATION ", rows.size(), " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
