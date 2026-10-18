extends RefCounted
## Builds the characters runtime files from authoring/characters.tres. Owned by the characters migration.
const Common = preload("res://tools/presentation_build/common.gd")

static func build(source: Dictionary, out_dir: String, report: Dictionary) -> void:
    Common.warn(report, "characters", "builder not written yet")
