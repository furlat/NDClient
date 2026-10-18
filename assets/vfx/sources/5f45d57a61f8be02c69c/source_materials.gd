extends RefCounted


## Native source loading semantics used by archived authoring code.
static func raw_texture(path: String, cache: Dictionary = {}) -> ImageTexture:
	if not cache.has(path):
		cache[path] = ImageTexture.create_from_image(
			VfxPackageIO_5f45d57a61.image(ProjectSettings.globalize_path(path))
		)
	return cache[path]


static func expand_shader(code: String, base: String) -> String:
	var result = ""
	for line in code.split("\n"):
		if line.strip_edges().begins_with("#include"):
			var path = line.get_slice('"', 1)
			if not path.begins_with("res://assets/vfx/"):
				path = base.path_join(path)
			result += expand_shader(VfxPackageIO_5f45d57a61.text(path), path.get_base_dir()) + "\n"
		else:
			result += line + "\n"
	return result

const VfxPackageIO_5f45d57a61 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
