extends RefCounted
## Builds the abilities runtime files from authoring/abilities.tres. Owned by the abilities migration.
const Common = preload("res://tools/presentation_build/common.gd")

static func build(source: Dictionary, out_dir: String, report: Dictionary) -> void:
    Common.warn(report, "abilities", "builder not written yet")
