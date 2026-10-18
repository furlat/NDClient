extends SceneTree
## Where the abilities source's spell staging and the VFX package's own
## staging (assets/vfx/index.json `selections`) differ, for review: staging
## imported from the Factory and changed since (by the package or by hand),
## and the client's own staging against the package's. The source decides;
## this only lists the differences so the user can choose a side.
##   --headless --script res://tools/presentation_build/staging_diff.gd [-- --output=<json>] [--spell=<id>]
const Common = preload("res://tools/presentation_build/common.gd")
const R = preload("res://tools/presentation_build/ability_records.gd")
const F = preload("res://tools/presentation_build/ability_fields.gd")
const ROOT := "res://authoring/abilities.tres"
## Cue fields the client's game path does not read (sandbox probes, review
## aids, fixture data); they are not staging differences.
const IGNORED := ["id", "live_endpoints", "follow_attachment", "dynamic_geometry", "entity_geometry", "delivery_timing",
    "source_launch_local", "aim_from_ground", "condition_fixture", "footprint", "registration_note", "timing_note"]

func _initialize() -> void:
    run.call_deferred()

func run() -> void:
    var output := "";var only := ""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--output="):output = argument.trim_prefix("--output=")
        elif argument.begins_with("--spell="):only = argument.trim_prefix("--spell=")
    var package: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/index.json"))
    var selections := {}
    for selection in package.selections:selections[str(selection.key)] = selection
    var report := Common.report()
    var source: Dictionary = Common.load_root(ROOT, report)
    if source.is_empty():print("STAGING_DIFF no source");quit(1);return
    var result := {"package": package.version, "spells": {}}
    var counts := {"same": 0, "differs": 0, "no_selection": 0, "no_staging": 0}
    for id in source.entries.spells:
        if not only.is_empty() and id != only:continue
        var e: Resource = source.entries.spells[id]
        var key := selection_key(e, id, selections, package)
        if key.is_empty():
            counts["no_selection" if not e.effects.is_empty() else "no_staging"] += 1
            if not e.effects.is_empty():result.spells[id] = {"staging_from": e.staging_from, "selection": "", "differences": ["the package has no selection for this spell"]}
            continue
        var theirs: Dictionary = selections[key].get("staging", {})
        var lines := compare(e, theirs)
        if lines.is_empty():counts.same += 1;continue
        counts.differs += 1
        result.spells[id] = {"staging_from": e.staging_from, "selection": key, "differences": lines}
    result.counts = counts
    for id in result.spells:
        print("STAGING_DIFF ", id, " [", result.spells[id].staging_from, " vs ", result.spells[id].selection, "] ", "; ".join(PackedStringArray(result.spells[id].differences.slice(0, 6))))
    print("STAGING_DIFF_SUMMARY ", JSON.stringify(counts))
    if not output.is_empty():
        var file := FileAccess.open(output, FileAccess.WRITE);file.store_string(JSON.stringify(result, "  "));file.close()
    quit(0)

## The package selection the spell's staging is compared with.
func selection_key(e: Resource, id: String, selections: Dictionary, package: Dictionary) -> String:
    var named: String = str(e.staging_unported.get("selection", ""))
    if selections.has(named):return named
    var name := id.trim_prefix("spell.")
    if selections.has(name):return name
    for selection in package.selections:
        if str(selection.get("definition_ref", {}).get("content_id", "")) == id:return str(selection.key)
    return ""

func compare(e: Resource, theirs: Dictionary) -> Array:
    var lines: Array = []
    var cues: Array = theirs.get("cues", [])
    if cues.size() != e.effects.size():lines.append("cues: %d here, %d in the package" % [e.effects.size(), cues.size()])
    for i in mini(cues.size(), e.effects.size()):
        var mine: Dictionary = R.cue_from_effect(e.effects[i], -1)
        var other: Dictionary = cues[i].duplicate(true)
        for field in IGNORED:mine.erase(field);other.erase(field)
        for field in mine:
            if not other.has(field):lines.append("cue %d %s: %s here, absent there" % [i, field, short(mine[field])])
            elif not F.same(F.plain(mine[field]), other[field]) and not (mine[field] is float and other[field] is float and is_equal_approx(mine[field], other[field])):
                lines.append("cue %d %s: %s here, %s there" % [i, field, short(mine[field]), short(other[field])])
        for field in other:
            if not mine.has(field):lines.append("cue %d %s: absent here, %s there" % [i, field, short(other[field])])
    var multiplier: float = e.light_multiplier if e.light_multiplier >= 0.0 else 1.0
    if theirs.has("decorative_light_multiplier") and not is_equal_approx(multiplier, float(theirs.decorative_light_multiplier)):
        lines.append("light multiplier: %s here, %s there" % [short(multiplier), short(theirs.decorative_light_multiplier)])
    if str(theirs.get("light_color", "")) != e.light_colour and (theirs.has("light_color") or not e.light_colour.is_empty()):
        lines.append("light colour: %s here, %s there" % [e.light_colour, str(theirs.get("light_color", ""))])
    return lines

func short(value: Variant) -> String:
    return JSON.stringify(F.plain(value)).left(70)
