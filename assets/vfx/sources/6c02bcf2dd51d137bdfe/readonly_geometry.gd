extends RefCounted
const PackageIO = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")

static func instantiate(registry_path: String) -> Node3D:
	var entry: Dictionary = JSON.parse_string(PackageIO.text(registry_path))
	return PackageIO.resource(entry.windows_path).instantiate()
