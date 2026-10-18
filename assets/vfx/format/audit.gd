extends SceneTree
## Strict package dependency walk. The receipt also supplies the reachable-file
## set used to omit abandoned staging outputs from the published directory.


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var arguments := OS.get_cmdline_user_args()
	assert(arguments.size() == 1)
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/index.json"))
	var paths: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/format/paths.json"))
	var pending: Array = paths.values()
	for clip in index.clips:
		for approach in clip.approaches:
			pending.append(approach.path)
			pending.append_array(approach.warm)
	var seen := {}
	var failures := []
	while not pending.is_empty():
		var path: String = str(pending.pop_back()).split("::")[0]
		if seen.has(path):
			continue
		seen[path] = true
		if not path.begins_with("res://assets/vfx/"):
			failures.append({"path": path, "error": "external dependency"})
			continue
		if not FileAccess.file_exists(path):
			failures.append({"path": path, "error": "missing file"})
			continue
		if path.ends_with("/texture.res"):
			var raw: String = path.get_basename() + ".raw.res"
			if FileAccess.file_exists(raw):
				pending.append(raw)
		if path.get_extension() in ["json", "gdshaderinc"]:
			continue
		if not path.get_extension() in ["res", "scn", "tres", "tscn", "gdshader", "gd"]:
			failures.append({"path": path, "error": "requires importer or unsupported file type"})
			continue
		for dependency in ResourceLoader.get_dependencies(path):
			pending.append(dependency.split("::")[-1])
		var loaded: Resource = ResourceLoader.load(path)
		if loaded == null:
			failures.append({"path": path, "error": "ResourceLoader.load failed"})
	FileAccess.open(arguments[0], FileAccess.WRITE).store_string(JSON.stringify({"files": seen.keys(), "failures": failures}, "  "))
	print("PACKAGE_DEPENDENCY_AUDIT ", seen.size(), " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
