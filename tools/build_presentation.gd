extends SceneTree
## The one presentation build: checks the three sources in authoring/ and
## writes what the game and the Studio load into build/presentation/ (no dot,
## so Godot's export includes it), plus a coverage report against every id the
## server can send (authoring/server_ids.json).
##   --headless --script res://tools/build_presentation.gd [-- --only=characters,environment,abilities]
const Common = preload("res://tools/presentation_build/common.gd")
const DOMAINS := {
    "characters": "res://tools/presentation_build/characters.gd",
    "environment": "res://tools/presentation_build/environment.gd",
    "abilities": "res://tools/presentation_build/abilities.gd",
}
const COVERAGE_KINDS := {
    "characters": ["creature", "item"],
    "environment": ["connector", "battlefield", "tile_material", "boundary_structure", "environment_object",
        "spatial_effect", "residue", "spatial_effect_layer", "light_appearance"],
    "abilities": ["spell", "condition", "damage_type", "action", "trait", "reaction", "class_feature", "feat"],
}
const OUT := "res://build/presentation"

func _initialize() -> void:
    run.call_deferred()

func run() -> void:
    var only := PackedStringArray()
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--only="):only = argument.trim_prefix("--only=").split(",")
    var selected: Array = DOMAINS.keys().filter(func(domain):return only.is_empty() or only.has(domain))
    var report := Common.report()
    DirAccess.make_dir_recursive_absolute(OUT)
    for domain in selected:
        var root: String = "res://authoring/" + domain + ".tres"
        if not FileAccess.file_exists(root):Common.warn(report, domain, "no source yet");continue
        var source: Dictionary = Common.load_root(root, report)
        if source.is_empty():continue
        load(DOMAINS[domain]).build(source, OUT.path_join(domain), report)
    var summary: Dictionary = publish_coverage(report, selected, Common.server_ids(), OUT.path_join("coverage.json"))
    print("PRESENTATION_BUILD ", JSON.stringify({"errors": report.errors.size(), "warnings": report.warnings.size(),
        "selected_domains": selected, "unlisted_server_ids": summary.unlisted_server_ids}))
    for line in report.errors.slice(0, 40):print("PRESENTATION_ERROR ", line)
    quit(0 if report.errors.is_empty() else 1)

## Partial builds replace their whole owned kinds, including IDs no longer
## emitted. Other domains retain their last coverage, not revalidation claims.
static func publish_coverage(report: Dictionary, selected: Array, ids: Dictionary, path: String) -> Dictionary:
    var coverage: Dictionary = {}
    if selected.size() < DOMAINS.size() and FileAccess.file_exists(path):
        var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
        if previous is Dictionary:coverage = previous.get("coverage", {}).duplicate()
    for domain in selected:
        for kind in COVERAGE_KINDS[domain]:coverage.erase(kind)
    coverage.merge(report.coverage, true)
    var gaps := {}
    for kind in ids.get("ids", {}):
        for id in ids.ids[kind]:
            if not coverage.get(kind, {}).has(id):gaps[kind] = gaps.get(kind, 0) + 1
    var summary := {"errors": report.errors, "warnings": report.warnings, "selected_domains": selected,
        "unlisted_server_ids": gaps, "coverage": coverage}
    FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(summary, "  ", true))
    return summary
