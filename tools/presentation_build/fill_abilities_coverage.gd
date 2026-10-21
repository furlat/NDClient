extends SceneTree
## One-time authoring help that fills the abilities source's coverage from
## data that already exists, one step at a time (each its own commit):
##   --step=spells      spells whose staging is imported from the Factory
##                      become playable (native_staging, a delivery scope from
##                      the server's delivery) only for an assigned source
##                      without an explicit unresolved constructor input;
##                      artwork remains unreviewed. Every spell without a body gets a stand-in
##                      cast body (role cast, Attack5, release frame 7: the
##                      most common old gesture), so no spell is silent;
##   --step=conditions  HUD icons from the icon banks;
##   --step=actions     body roles from the server's body kind, and icons;
##   --step=icons       every spell, condition and action without an icon gets
##                      one from the 18 October delivery (its srd22.* keys),
##                      its owning spell's, or an explicit generic stand-in.
## It edits the entries in place (authoring/abilities/...); the source stays
## the authority and every change shows in the coverage report.
##   --headless --script res://tools/presentation_build/fill_abilities_coverage.gd -- --step=<step>
const Common = preload("res://tools/presentation_build/common.gd")
const BodyUse = preload("res://presentation/source/abilities/body_use.gd")
const ImageRef = preload("res://presentation/source/image_ref.gd")
const Effects = preload("res://presentation/effect_package.gd")
const ROOT := "res://authoring/abilities.tres"
const UI_DELIVERY := "art/ui-delivery-20261018"
## Server body kind -> clip role in the shared vocabulary.
const BODY_ROLES := {
    "attack": "attack", "weapon_attack": "attack", "natural_attack": "attack", "multiattack": "attack",
    "area_attack": "attack", "shield_bash": "attack", "throw": "throw", "cast": "cast",
    "targeted_ability": "cast", "area_ability": "cast", "self_ability": "cast_alt",
    "interact": "act", "use_item": "act", "consume": "eat", "pick_up": "act", "drop": "act",
    "assist": "act", "struggle": "act", "stance": "idle_alt", "hide": "crouch_idle",
    "move": "walk", "traverse": "walk", "prone": "die", "stand": "stand_up", "block": "block_start",
    "shove": "kick", "weapon_rider": "", "passive": "", "none": "",
}

var server: Dictionary
var resources: Dictionary
var changed: Array = []

func _initialize() -> void:
    run.call_deferred()

func run() -> void:
    var step := ""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--step="):step = argument.trim_prefix("--step=")
    var report := Common.report()
    var source: Dictionary = Common.load_root(ROOT, report)
    if source.is_empty():print("FILL no source");quit(1);return
    server = JSON.parse_string(FileAccess.get_file_as_string("res://authoring/server_ids.json")).ids
    resources = JSON.parse_string(FileAccess.get_file_as_string("res://authoring/ui/resources.json"))
    match step:
        "spells":spells(source)
        "conditions":conditions(source)
        "actions":actions(source)
        "icons":icons(source)
        _:print("FILL use --step=spells|conditions|actions|icons");quit(2);return
    for item in changed:
        var error := ResourceSaver.save(item[1], item[0])
        if error != OK:push_error("cannot save " + item[0])
    print("FILL ", step, " changed=", changed.size())
    quit(0)

func entry_path(source: Dictionary, section: String, id: String) -> String:
    return source.root.sections[section][id]

# --- Spells -------------------------------------------------------------------

## Source availability and explicit input refusals determine staging admission.
## This helper neither accepts artwork nor clears another cue's refusal.
func has_assigned_source(entry: Resource) -> bool:
    for index in entry.effects.size():
        if index in entry.excluded_cues:continue
        var use: Resource = entry.effects[index]
        if not use.unbound_constructor_inputs.is_empty():continue
        var cue := {"clip":use.clip,"selection":use.selection,"role":use.role,
            "source_phase":use.source_phase.resource_path if use.source_phase != null else "",
            "source_inputs":use.source_inputs,"source_seekable":use.source_seekable}
        if not Effects.for_cue(cue, use.selection if not use.selection.is_empty() else str(entry.id).trim_prefix("spell."), use.role).is_empty():return true
    return false

func spells(source: Dictionary) -> void:
    for id in source.entries.spells:
        var e: Resource = source.entries.spells[id]
        var touched := false
        var stand_in := e.body == null
        if stand_in:
            e.body = BodyUse.new();e.body.role = "cast";e.body.clip = "Attack5";e.body.markers["release"] = 7.0
            e.body.hidden_slots = PackedStringArray(["weapon", "offhand"])
            e.notes = (e.notes + "\nCast body is a stand-in (Attack5, release 7, the most common old gesture) until the spell has its own (coverage fill).").strip_edges()
            touched = true
        if not e.native_staging and e.staging_from.begins_with("factory@") and has_assigned_source(e):
            e.native_staging = true
            var area: Variant = server.spell.get(id, {}).get("delivery", {}).get("area")
            e.effect_scope = "area" if area is Dictionary else "single"
            var key: String = str(e.staging_unported.get("selection", ""))
            e.staging_unported["source"] = "assets/vfx/index.json:/selections/" + key + "/staging"
            e.notes = (e.notes + "\nAssigned Factory source is enabled for inspection (coverage fill). Explicit cue input refusals remain; artwork needs review.").strip_edges()
            touched = true
        if e.status != "internal":
            e.status = "ready" if e.native_staging and not stand_in else ("stand_in" if stand_in and e.effects.is_empty() else "partial")
        if touched:changed.append([entry_path(source, "spells", id), e])

# --- Icons --------------------------------------------------------------------

## Letters only, for matching icon keys written as one word (dnd-spells-*).
func squash(text: String) -> String:
    var result := ""
    for character in text.to_lower():
        if character >= "a" and character <= "z":result += character
    return result

func bank_icon(key: String) -> ImageRef:
    var resource: Dictionary = resources.get("icon:" + key, {})
    if resource.is_empty():return null
    var icon := ImageRef.new()
    icon.path = "art/media/" + str(resource.path).trim_prefix("/media/")
    if resource.get("native_size") is Array:icon.native_size = Vector2i(resource.native_size[0], resource.native_size[1])
    icon.source = "ui/resources.json icon:" + key
    if not FileAccess.file_exists("res://assets/" + icon.path):icon.status = "missing"
    return icon

func delivered_icon(key: String) -> ImageRef:
    var path := UI_DELIVERY + "/runtime/smooth48/" + key + ".png"
    if not FileAccess.file_exists("res://assets/" + path):return null
    var icon := ImageRef.new();icon.path = path;icon.native_size = Vector2i(48, 48);icon.source = "ui-delivery-20261018 " + key
    return icon

# --- Conditions -----------------------------------------------------------------

func conditions(source: Dictionary) -> void:
    var keys: Array = resources.keys().filter(func(key): return str(key).begins_with("icon:condition."))
    var squashed := {}
    for key in keys:squashed[squash(str(key).trim_prefix("icon:condition.").trim_prefix("dnd-"))] = str(key).trim_prefix("icon:")
    for id in source.entries.conditions:
        var e: Resource = source.entries.conditions[id]
        if e.icon != null:continue
        var icon := condition_icon(id, squashed)
        if icon == null:continue
        e.icon = icon
        changed.append([entry_path(source, "conditions", id), e])

## The bank icon of a condition: its own key, else the old dnd-* icon whose
## name holds the condition's name (spell conditions: school plus name plus
## effect/zone/condition), else a delivered icon.
func condition_icon(id: String, squashed: Dictionary) -> ImageRef:
    var exact := bank_icon(id)
    if exact != null:return exact
    var name := id.trim_prefix("condition.")
    var parts := name.split(".")
    var core := squash(parts[parts.size() - 1])
    var whole := squash(name.trim_prefix("spell.").trim_prefix("class.").trim_prefix("summon."))
    var best := ""
    for candidate in squashed:
        var key: String = squashed[candidate]
        if candidate.ends_with("conditions" + core) or candidate.ends_with(whole) or candidate.ends_with(whole + "effect") or candidate.ends_with(whole + "zone") \
                or candidate.ends_with(whole + "condition") or candidate.ends_with(whole + "buff") or candidate.ends_with(whole + "marked"):
            if best.is_empty() or key.length() < best.length():best = key
    if not best.is_empty():
        var icon := bank_icon(best)
        icon.status = "stand_in" if not best.contains(core) else icon.status
        return icon
    return delivered_icon(id)

# --- Actions --------------------------------------------------------------------

func actions(source: Dictionary) -> void:
    var cues: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://authoring/audio/cues.json")).get("cues", {})
    for id in source.entries.actions:
        var e: Resource = source.entries.actions[id]
        var touched := false
        for sound in e.sounds.duplicate():
            if not cues.has(sound.cue):
                e.sounds.erase(sound);touched = true
                e.notes = (e.notes + "\nThe audio library binds cue " + sound.cue + ", which it does not have.").strip_edges()
        var info: Dictionary = server.get(e.kind, {}).get(id, {})
        var kind: String = str(info.get("body", "")) if info.get("body") != null else ""
        if e.body == null and e.plays.is_empty() and BODY_ROLES.get(kind, "") != "":
            e.body = BodyUse.new();e.body.role = BODY_ROLES[kind];e.body.enabled = false
            e.notes = (e.notes + "\nBody role from the server's body kind (" + kind + "); the rig resolves it to a clip once roles are built (coverage fill).").strip_edges()
            touched = true
        if e.icon == null:
            var icon := action_icon(id)
            if icon != null:e.icon = icon;touched = true
        if touched:changed.append([entry_path(source, "actions", id), e])

func action_icon(id: String) -> ImageRef:
    for key in [id, id.replace("_", "-"), "action." + id.trim_prefix("action.").replace("_", "-").replace(".", "-")]:
        var icon := bank_icon(key)
        if icon != null:return icon
    var delivered := delivered_icon(id)
    if delivered != null:return delivered
    if id.begins_with("action.monster.multiattack"):
        var generic := bank_icon("ui.filter-attacks")
        if generic != null:generic.reuses = "ui.filter-attacks";generic.status = "stand_in"
        return generic
    return null

# --- Remaining icons and stand-ins -----------------------------------------------

## The delivery's own key for an id: srd22.spell.<name>, srd22.status.<name>,
## srd22.creature_action.<name>, srd22.action.<spell action>.
func srd22_icon(candidates: Array) -> ImageRef:
    for key in candidates:
        var icon := delivered_icon(key)
        if icon != null:return icon
    return null

func stand_in(key: String) -> ImageRef:
    var icon := bank_icon(key)
    if icon != null:icon.status = "stand_in";icon.reuses = key
    return icon

func icons(source: Dictionary) -> void:
    for id in source.entries.spells:
        var e: Resource = source.entries.spells[id]
        if e.icon != null:continue
        var name: String = id.trim_prefix("spell.")
        e.icon = srd22_icon(["srd22.spell." + name])
        if e.icon == null:e.icon = bank_icon("reaction." + name.replace("_", "-"))
        if e.icon == null:e.icon = stand_in("ui.filter-spells")
        changed.append([entry_path(source, "spells", id), e])
    for id in source.entries.conditions:
        var e: Resource = source.entries.conditions[id]
        if e.icon != null:continue
        var name: String = id.get_slice(".", id.get_slice_count(".") - 1)
        e.icon = srd22_icon(["srd22.status." + name, "srd22.status." + id.trim_prefix("condition.").replace(".", "_")])
        if e.icon == null and id.begins_with("condition.spell."):
            var spell: Resource = source.entries.spells.get("spell." + id.trim_prefix("condition.spell.").get_slice(".", 0))
            if spell != null and spell.icon != null:
                e.icon = spell.icon.duplicate();e.icon.status = "stand_in";e.icon.reuses = spell.id
        if e.icon == null:e.icon = stand_in("condition.generic")
        changed.append([entry_path(source, "conditions", id), e])
    for id in source.entries.actions:
        var e: Resource = source.entries.actions[id]
        if e.icon != null:continue
        var tail: String = id.get_slice(".", id.get_slice_count(".") - 1)
        var spell_action: String = id.trim_prefix("action.spell.")
        e.icon = srd22_icon(["srd22.creature_action." + tail, "srd22.action." + spell_action, "srd22.action." + tail])
        if e.icon == null:e.icon = stand_in({"reaction": "ui.filter-reactions", "trait": "ui.filter-all", "class_feature": "ui.filter-all", "feat": "ui.filter-all"}.get(e.kind, "ui.filter-actions"))
        changed.append([entry_path(source, "actions", id), e])
