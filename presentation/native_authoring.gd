extends RefCounted
## Conditions, actions and rig clips all come from the presentation build
## (build/presentation/<domain>); no Resource overlay remains. Errors found
## while reading the built tables collect here, and source pointers still name
## the field an ability entry was converted from.
const CONDITION_FILE = "catalog/condition_recipes.json"
const ACTION_FILE = "catalog/body_action_recipes.json"

static func _error(cache: Dictionary, message: String) -> void:
    if not cache.has("native_authoring_errors"): cache.native_authoring_errors = []
    if message not in cache.native_authoring_errors: cache.native_authoring_errors.append(message)

static func overlay(document: String, legacy: Variant, cache: Dictionary) -> Variant:
    return legacy

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
