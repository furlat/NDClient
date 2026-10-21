extends RefCounted
## Import-free counterpart to source-image reads in original constructors.
static var paths: Dictionary = {}
static var images: Dictionary = {}
static var encoded_images: Dictionary = {}
static var aliases: Dictionary = {}


static func resolve(path: String) -> String:
	if not path.begins_with("factory-path:"):
		return path
	if paths.is_empty():
		paths = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/format/source-preparation-20261020-aliases.json"))
	if path.begins_with("factory-path:"):
		var resolved: String = paths.get(path.trim_prefix("factory-path:"), "")
		assert(resolved.begins_with("res://assets/vfx/"), "Unresolved package resource alias: " + path)
		return resolved
	return path


static func resource(path: String) -> Resource:
	return ResourceLoader.load(resolve(path))


static func has_source_suffix(path: String, suffix: String) -> bool:
	if path.ends_with(suffix):
		return true
	if paths.is_empty():
		paths = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/format/source-preparation-20261020-aliases.json"))
	if aliases.is_empty():
		for original in paths:
			var target: String = paths[original]
			if not aliases.has(target):
				aliases[target] = []
			aliases[target].append(original)
	for original in aliases.get(path, []):
		if str(original).ends_with(suffix):
			return true
	return false


static func text(path: String) -> String:
	return FileAccess.get_file_as_string(resolve(path))


static func bytes(path: String) -> PackedByteArray:
	var resolved: String = resolve(path)
	if resolved.ends_with("/texture.res"):
		if encoded_images.has(resolved):
			return encoded_images[resolved]
		var source: Image = image(resolved)
		if source != null:
			encoded_images[resolved] = source.save_png_to_buffer()
			return encoded_images[resolved]
	return FileAccess.get_file_as_bytes(resolved)


static func image(path: String) -> Image:
	var resolved := resolve(path)
	if images.has(resolved):
		return images[resolved].duplicate()
	var raw_path: String = resolved.get_basename() + ".raw.res"
	var value: Resource = load(raw_path if FileAccess.file_exists(raw_path) else resolved)
	if value is Texture2D:
		var result: Image = value.get_image()
		if result != null and result.is_compressed():
			result.decompress()
		images[resolved] = result
		return result
	if value is Image:
		return value.duplicate()
	push_error("Package image resource cannot load: " + path)
	return null
