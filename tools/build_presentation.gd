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
const OUT := "res://build/presentation"

func _initialize() -> void:
    run.call_deferred()

func run() -> void:
    var only := PackedStringArray()
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--only="):only = argument.trim_prefix("--only=").split(",")
    var report := Common.report()
    DirAccess.make_dir_recursive_absolute(OUT)
    for domain in DOMAINS:
        if not only.is_empty() and not only.has(domain):continue
        var root: String = "res://authoring/" + domain + ".tres"
        if not FileAccess.file_exists(root):Common.warn(report, domain, "no source yet");continue
        var source: Dictionary = Common.load_root(root, report)
        if source.is_empty():continue
        load(DOMAINS[domain]).build(source, OUT.path_join(domain), report)
    var ids: Dictionary = Common.server_ids()
    var gaps := {}
    for kind in ids.get("ids", {}):
        for id in ids.ids[kind]:
            if not report.coverage.get(kind, {}).has(id):gaps[kind] = gaps.get(kind, 0) + 1
    var summary := {"errors": report.errors, "warnings": report.warnings, "unlisted_server_ids": gaps, "coverage": report.coverage}
    FileAccess.open(OUT.path_join("coverage.json"), FileAccess.WRITE).store_string(JSON.stringify(summary, "  ", true))
    print("PRESENTATION_BUILD ", JSON.stringify({"errors": report.errors.size(), "warnings": report.warnings.size(), "unlisted_server_ids": gaps}))
    for line in report.errors.slice(0, 40):print("PRESENTATION_ERROR ", line)
    quit(0 if report.errors.is_empty() else 1)
