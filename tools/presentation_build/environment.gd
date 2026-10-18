extends RefCounted
## Builds the environment runtime files from authoring/environment.tres. Owned by the environment migration.
const Common = preload("res://tools/presentation_build/common.gd")

static func build(source: Dictionary, out_dir: String, report: Dictionary) -> void:
    Common.warn(report, "environment", "builder not written yet")
