extends RefCounted
## Immutable material recipes only. No occurrence, actor, event, pose or clock.
## Candidates bind explicit native paths before construction; archived sources
## retain their original compiler when no prepared recipe is supplied.
static var recording := false
static var captured := {}
static var used: Array[String] = []
static var assets := {}

static func key(family: String, definition: Variant) -> String:
	return (family + "\n" + JSON.stringify(definition, "", true)).sha256_text()

static func take(family: String, definition: Variant) -> ShaderMaterial:
	var identity := key(family, definition)
	if recording:
		if identity not in used:
			used.append(identity)
		return null
	return assets[identity].duplicate(false) if assets.has(identity) else null

static func capture(family: String, definition: Variant, material: ShaderMaterial) -> ShaderMaterial:
	if recording:
		var identity := key(family, definition)
		# The source may change its returned material later. Retain the immutable
		# recipe result now, never that caller's mutable instance.
		if not captured.has(identity):
			captured[identity] = material.duplicate(false)
	return material

static func bind(records: Array) -> void:
	for record in records:
		if not assets.has(record.key):
			var material: ShaderMaterial = VfxPackageIO_c1e0733a7e.resource(record.path)
			assert(material != null, "Prepared immutable material unavailable: " + record.path)
			assets[record.key] = material

const VfxPackageIO_c1e0733a7e = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
