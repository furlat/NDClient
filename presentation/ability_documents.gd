extends RefCounted
## The record tables the presentation build writes from the abilities source
## (build/presentation/abilities/docs/): read in place of the old authoring
## documents they replace, under the same names, so every reader keeps its
## code. A document is reused while its file is unchanged. The setting
## source_data/abilities_build (default ROOT) points a check at another build.
const ROOT := "res://build/presentation/abilities/"
## The old documents the abilities source owns (plus spells/<id>.json).
const DOCUMENTS := [
    "catalog/condition_recipes.json", "catalog/condition_media.json", "catalog/action_playback_rates.json",
    "catalog/body_action_recipes.json", "catalog/body_action_bindings.json", "catalog/shove_recipes.json",
    "catalog/action_deliveries.json", "catalog/attack_recipes.json", "catalog/damage_context.json",
    "catalog/healing_context.json", "catalog/death_context.json", "catalog/death_save_context.json",
    "catalog/life_state_context.json", "catalog/number_style.json", "catalog/badge_style.json",
    "catalog/bolt_style.json", "catalog/dart_style.json", "catalog/movement_context.json",
    "catalog/movement_reaction_context.json", "catalog/forced_movement_context.json",
    "catalog/forced_movement_profile.json", "catalog/equipment_context.json", "catalog/interruptions.json",
    "catalog/body_release_media.json", "catalog/entity_lifecycle_media.json", "catalog/item_attachments.json",
    "catalog/shove_feedback.json", "catalog/relocation_actions.json", "catalog/body_materials.json",
    "catalog/action_materials.json", "catalog/action_intakes.json",
    "native_effects/index.json", "native_effects/responses.json", "sandbox/feedback.json",
    "condition_lifecycles.json", "values.json",
]
static var _documents: Dictionary = {}
static var _mutex := Mutex.new()

static func owns(path: String) -> bool:
    return path in DOCUMENTS or (path.begins_with("spells/") and path.ends_with(".json"))

static func root() -> String:
    return str(ProjectSettings.get_setting("source_data/abilities_build", ROOT))

static func file(path: String) -> String:
    return root().path_join("docs").path_join(path.get_basename() + ".res")

static func exists(path: String) -> bool:
    return FileAccess.file_exists(file(path))

## The document's data (a Dictionary, or an Array for a list document), or
## null when the build has no such document or it is not a record table.
static func read(path: String) -> Variant:
    var source := file(path)
    var exists := FileAccess.file_exists(source)
    var stamp := [FileAccess.get_modified_time(source), FileAccess.get_size(source)] if exists else []
    _mutex.lock();var known: Array = _documents.get(source, []);_mutex.unlock()
    if not known.is_empty() and known[0] == stamp:return known[1]
    var data: Variant = null
    var document: Resource = ResourceLoader.load(source, "", ResourceLoader.CACHE_MODE_IGNORE) if exists else null
    if document != null and document.get("is_list") != null:data = document.items if document.is_list else document.data
    else:push_error("The abilities build has no record table " + source + " (run tools/build_presentation.gd)")
    _mutex.lock();_documents[source] = [stamp, data];_mutex.unlock()
    return data

static func invalidate() -> void:
    _mutex.lock();_documents = {};_mutex.unlock()
