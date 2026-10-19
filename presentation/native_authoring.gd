extends RefCounted
## One import boundary: native data Resources become the same passive compiler
## operands. Conditions and actions come from the abilities build
## (build/presentation/abilities); this overlay adds the rig clips only.
const CatalogResource = preload("res://presentation/resources/catalog.gd")
const ClipResource = preload("res://presentation/resources/body_clip.gd")
const CONDITION_FILE = "catalog/condition_recipes.json"
const ACTION_FILE = "catalog/body_action_recipes.json"
const INDEX = "res://authoring/presentation/catalog.tres"

static func _error(cache: Dictionary, message: String) -> void:
    if not cache.has("native_authoring_errors"): cache.native_authoring_errors = []
    if message not in cache.native_authoring_errors: cache.native_authoring_errors.append(message)

static func _load(path: String, cache: Dictionary) -> Resource:
    var key = "native_resource:" + path
    if not cache.has(key):
        if not ResourceLoader.exists(path):
            _error(cache, "Selected presentation Resource is missing: " + path)
            return null
        # Each candidate is independent of the currently displayed authoring.
        # No Resource, including external filter dependencies, holds live state.
        cache[key] = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
        if cache[key] == null: _error(cache, "Cannot load presentation Resource: " + path)
    return cache[key]

static func _catalog(cache: Dictionary) -> CatalogResource:
    var path: String = ProjectSettings.get_setting("source_data/presentation_catalog", INDEX)
    var catalog = _load(path, cache) as CatalogResource
    if catalog == null: _error(cache, "Expected PresentationResourceCatalog: " + path)
    return catalog

static func _range(value: float, low: float, high: float) -> bool:
    return is_finite(value) and value >= low and value <= high

static func overlay(document: String, legacy: Variant, cache: Dictionary) -> Variant:
    if document not in ["catalog/rigs.json", "catalog/resources.json"]: return legacy
    var index = _catalog(cache)
    if index == null: return legacy
    var result = legacy.duplicate()
    for path in index.body_clips:
        var clip = _load(path, cache) as ClipResource
        if clip == null:
            _error(cache, "Expected PresentationBodyClip Resource: " + path)
            continue
        if clip.frame_count <= 0 or not _range(clip.fps,0.01,240) or clip.clip.is_empty() or clip.sheets.is_empty():
            _error(cache, "Incomplete source clip in " + path)
            continue
        if document == "catalog/resources.json":
            for source in clip.sheets.values(): result[source] = source
        elif not legacy.has(clip.rig_id):
            _error(cache, "Clip Resource has no matching rig: " + path)
        else:
            if is_same(result[clip.rig_id], legacy[clip.rig_id]):
                result[clip.rig_id] = legacy[clip.rig_id].duplicate()
                result[clip.rig_id].clips = legacy[clip.rig_id].clips.duplicate()
            result[clip.rig_id].clips[clip.clip] = {"source_clip":clip.source_clip,
                "frames":clip.frame_count, "fps":clip.fps, "loop":clip.loop, "sheets":clip.sheets.duplicate(),
                "resource_source":path}
    return result

static func source_pointer(document: String, pointer: String, data: Dictionary) -> String:
    var normalized = pointer.trim_prefix("/")
    if document in [CONDITION_FILE,ACTION_FILE]:
        var id = normalized.get_slice("/", 0)
        var relative = normalized.trim_prefix(id).trim_prefix("/")
        var fields: Dictionary = data.get(id, {}).get("_source_fields", {})
        var matched = ""
        for field in fields:
            if (relative == field or relative.begins_with(field + "/")) and field.length() > matched.length(): matched = field
        if not matched.is_empty(): return fields[matched] + relative.trim_prefix(matched)
    return document + ":/" + normalized
