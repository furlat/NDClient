extends RefCounted
## Builds the abilities runtime files from authoring/abilities.tres (spells,
## conditions, actions, attacks, damage types, contexts, native sources):
##   build/presentation/abilities/docs/<old document>.res  the record tables the
##       game reads, in the shape of the old authoring documents (catalog/*,
##       spells/<id>, native_effects/*, sandbox/feedback), so readers keep
##       their code and every pixel stays; condition_lifecycles (the conditions
##       whose package lifecycle the client turns off) and values;
##   build/presentation/abilities/native_spells/  the native spell records
##       (staging, treated recipe, hit material, requirements) and their index;
##   build/presentation/abilities/icons.json  icon per spell, condition and action;
##   coverage of every spell, condition, action and damage type id.
const Common = preload("res://tools/presentation_build/common.gd")
const F = preload("res://tools/presentation_build/ability_fields.gd")
const R = preload("res://tools/presentation_build/ability_records.gd")
const Feedback = preload("res://presentation/spell_feedback.gd")
const Requirements = preload("res://presentation/requirements.gd")
const Document = preload("res://presentation/resources/ability_document.gd")
const NativeSpell = preload("res://presentation/resources/native_spell.gd")
const NativeIndex = preload("res://presentation/resources/native_presentation_catalog.gd")
const PACKAGE := "res://assets/vfx/index.json"
const CUES := "res://authoring/audio/cues.json"
const BINDINGS := "res://authoring/audio/bindings.json"
const ORDER := "res://tools/presentation_build/ability_record_order.json"
const Catalog = preload("res://source_catalog.gd")

## Context entry id -> the old document it is.
const CONTEXT_DOCUMENTS := {
    "damage": "catalog/damage_context.json", "healing": "catalog/healing_context.json", "death": "catalog/death_context.json",
    "death_save": "catalog/death_save_context.json", "life_state": "catalog/life_state_context.json",
    "number_style": "catalog/number_style.json", "badge_style": "catalog/badge_style.json", "bolt_style": "catalog/bolt_style.json",
    "dart_style": "catalog/dart_style.json", "movement": "catalog/movement_context.json",
    "movement_reaction": "catalog/movement_reaction_context.json", "forced_movement": "catalog/forced_movement_context.json",
    "forced_movement_profile": "catalog/forced_movement_profile.json", "equipment": "catalog/equipment_context.json",
    "interruptions": "catalog/interruptions.json", "body_release_media": "catalog/body_release_media.json",
    "entity_lifecycle_media": "catalog/entity_lifecycle_media.json", "item_attachments": "catalog/item_attachments.json",
    "shove_feedback": "catalog/shove_feedback.json", "relocation": "catalog/relocation_actions.json",
    "body_materials": "catalog/body_materials.json", "action_materials": "catalog/action_materials.json",
    "action_intakes": "catalog/action_intakes.json", "condition_media": "catalog/condition_media.json",
    "hit_flash": "sandbox/feedback.json", "hit_responses": "native_effects/responses.json",
}
const ACTION_KINDS := ["action", "trait", "reaction", "class_feature", "feat"]

static func build(source: Dictionary, out_dir: String, report: Dictionary) -> void:
    var entries: Dictionary = source.entries
    _validate(entries, report)
    var built: Dictionary = documents(entries)
    DirAccess.make_dir_recursive_absolute(out_dir)
    for path in built.docs:save_document(out_dir, path, built.docs[path], report)
    _save_native(out_dir, built.native, report)
    var icons := FileAccess.open(out_dir.path_join("icons.json"), FileAccess.WRITE)
    icons.store_string(JSON.stringify({"domain": "abilities", "root": "res://assets/", "icons": built.icons}, "  "))
    icons.close()
    _coverage(entries, report)

## The runtime document file for an old document path (catalog/x.json -> docs/catalog/x.res).
static func document_file(out_dir: String, path: String) -> String:
    return out_dir.path_join("docs").path_join(path.get_basename() + ".res")

static func save_document(out_dir: String, path: String, data: Variant, report: Dictionary) -> void:
    var document := Document.new()
    if data is Array:document.items = data;document.is_list = true
    else:document.data = data
    var file := document_file(out_dir, path)
    DirAccess.make_dir_recursive_absolute(file.get_base_dir())
    var error := ResourceSaver.save(document, file, ResourceSaver.FLAG_COMPRESS)
    if error != OK:Common.error(report, "abilities", "cannot save " + file + ": " + str(error))

static func _order() -> Dictionary:
    if not FileAccess.file_exists(ORDER):return {}
    return JSON.parse_string(FileAccess.get_file_as_string(ORDER))

## A document laid out like the old one: spell recipes share one generic
## order, each table its own; exceptions per path.
static func _ordered(order: Dictionary, document: String, value: Variant) -> Variant:
    var spell := document.begins_with("spells/")
    var layout := {"generic": order.get("spells" if spell else document, {}).get("generic", {}),
        "exact": order.get(document, {}).get("exact", {})}
    return F.plain(F.ordered(layout, value, "", not spell))

## A measured file (path relative to res://assets/), parsed.
static func measured(path: String) -> Variant:
    if path.is_empty():return null
    var file := "res://assets/".path_join(path)
    if not FileAccess.file_exists(file):return null
    return JSON.parse_string(FileAccess.get_file_as_string(file))

static func short(spell_id: String) -> String:
    return spell_id.trim_prefix("spell.")

static func _sorted(map: Dictionary) -> Array:
    var keys: Array = map.keys()
    keys.sort()
    return keys

## Every runtime document: {docs: {old path: data}, native: {id: NativeSpell},
## native_conditions: {condition id: spell id}, icons: {id: row}}.
static func documents(entries: Dictionary) -> Dictionary:
    var order := _order()
    var docs := {}
    var spells: Dictionary = entries.get("spells", {})
    var conditions: Dictionary = entries.get("conditions", {})
    var actions: Dictionary = entries.get("actions", {})
    var attacks: Dictionary = entries.get("attacks", {})
    var contexts: Dictionary = entries.get("contexts", {})
    # Spells: one old recipe per spell that has a body recipe, plus the old
    # child drafts its variants carry.
    for id in _sorted(spells):
        var e: Resource = spells[id]
        if e.body != null or not e.unported.is_empty():docs["spells/" + id + ".json"] = _ordered(order, "spells/" + id + ".json", raw_recipe(e))
        for variant in e.variants:
            if not variant.recipe.is_empty():docs["spells/" + variant.id + ".json"] = _ordered(order, "spells/" + variant.id + ".json", variant.recipe)
    # Conditions.
    var recipes := {}
    var rates := {}
    var suppressed: Array = []
    for id in _sorted(conditions):
        var e: Resource = conditions[id]
        if not e.disposition.is_empty():recipes[id] = R.condition_recipe(e)
        if e.playback_rate != 0.0:rates[id] = e.playback_rate
        if not e.play_package_lifecycle:suppressed.append(id)
    docs["catalog/condition_recipes.json"] = _ordered(order, "catalog/condition_recipes.json", recipes)
    docs["catalog/action_playback_rates.json"] = F.plain(rates)
    docs["condition_lifecycles.json"] = {"suppressed": suppressed}
    # Actions and attacks.
    var bodies := {}
    var shoves := {}
    var bindings := {}
    var deliveries := {}
    for id in _sorted(actions):
        var e: Resource = actions[id]
        if not e.disposition.is_empty():
            if e.shove:shoves[id] = R.action_recipe(e)
            else:bodies[id] = R.action_recipe(e)
        if not e.plays.is_empty():
            var binding := {"source_recipe": e.plays, "action_feedback": null}
            if e.feedback != null and e.disposition.is_empty():binding.action_feedback = {"text": e.feedback.text, "color": F.to_legacy("colour", e.feedback.colour)}
            if not e.target.is_empty():binding.interaction_target = e.target
            bindings[id] = binding
        if not e.delivers_spell.is_empty():deliveries[id] = e.delivers_spell
    docs["catalog/body_action_recipes.json"] = _ordered(order, "catalog/body_action_recipes.json", bodies)
    docs["catalog/shove_recipes.json"] = _ordered(order, "catalog/shove_recipes.json", shoves)
    docs["catalog/body_action_bindings.json"] = F.plain(bindings)
    docs["catalog/action_deliveries.json"] = F.plain(deliveries)
    var attack_recipes := {}
    for id in _sorted(attacks):
        var e: Resource = attacks[id]
        var trail: Variant = measured(e.trail_points)
        var sockets: Variant = measured(e.variant_sockets)
        attack_recipes[id] = R.attack_recipe(e, trail.get("poses") if trail is Dictionary else null, sockets if sockets is Dictionary else {})
    docs["catalog/attack_recipes.json"] = _ordered(order, "catalog/attack_recipes.json", attack_recipes)
    # Contexts, damage types and native sources.
    for id in contexts:
        if CONTEXT_DOCUMENTS.has(id):docs[CONTEXT_DOCUMENTS[id]] = R.context_document(contexts[id], id)
    var damage_types: Dictionary = entries.get("damage_types", {})
    if docs.get("catalog/damage_context.json") is Dictionary and docs["catalog/damage_context.json"].get("palette") is Dictionary:
        var by_type := {}
        for id in damage_types:
            var e: Resource = damage_types[id]
            if e.palette != null or not e.unported.is_empty():by_type[id] = R.damage_type_palette(e)
        docs["catalog/damage_context.json"].palette.byDamageType = by_type
    if docs.get("native_effects/responses.json") is Dictionary:
        var by_type := {}
        for id in damage_types:
            if not damage_types[id].hit_response.is_empty():by_type[id] = damage_types[id].hit_response
        docs["native_effects/responses.json"].damage_types = by_type
    for id in contexts:
        if CONTEXT_DOCUMENTS.has(id):docs[CONTEXT_DOCUMENTS[id]] = _ordered(order, CONTEXT_DOCUMENTS[id], docs[CONTEXT_DOCUMENTS[id]])
    var sources := {}
    for id in _sorted(entries.get("sources", {})):sources[id] = F.plain(F.deep(entries.sources[id].record))
    var native := native_records(spells, docs.get("sandbox/feedback.json", {}))
    var owners := {}
    for id in _sorted(native.records):
        var selection: Dictionary = native.records[id].selection
        if not selection.lifecycle.is_empty():owners[id] = {"id": selection.id, "lifecycle": F.deep(selection.lifecycle)}
    docs["native_effects/index.json"] = F.plain({"sources": sources, "spells": owners})
    var movement: Resource = contexts.get("movement")
    docs["values.json"] = {"movement_reference_speed_feet": float(movement.values.get("reference_speed_feet", 30.0)) if movement != null else 30.0}
    return {"docs": docs, "native": native, "icons": icons(entries)}

## The old recipe of a spell, with its measured sockets.
static func raw_recipe(e: Resource) -> Dictionary:
    var sockets: Variant = measured(e.sockets)
    return R.spell_recipe(e, sockets if sockets is Dictionary else {})

## Native spell records for the spells whose staged effects play in the game:
## the staging selection, the recipe with the native hand/flash treatment
## (`policy`: hand glow categories and flash envelope), the hit material and
## the requirements; plus which spell owns each condition's lifecycle staging.
static func native_records(spells: Dictionary, policy: Dictionary) -> Dictionary:
    var result := {"records": {}, "conditions": {}}
    for id in _sorted(spells):
        var e: Resource = spells[id]
        if not e.native_staging:continue
        var name := short(id)
        var bounds: Variant = measured(e.bounds)
        var spell := NativeSpell.new()
        spell.selection = F.plain(R.spell_selection(e, name, bounds if bounds is Dictionary else {}))
        if e.body != null or not e.unported.is_empty():
            var raw: Dictionary = F.plain(raw_recipe(e))
            var treatment: Dictionary = Feedback.prepare(raw, spell.selection.palette, spell.selection.staging, policy)
            spell.recipe = raw.duplicate(true)
            spell.recipe.cast = treatment.cast
            if spell.recipe.get("damage") != null and not treatment.flash.is_empty():spell.recipe.damage.hitFlash = treatment.flash
        spell.hit = F.plain(R.spell_hit(e, name))
        spell.requirement_source = "spells/" + id + ".json:"
        spell.requirements = Requirements.recipe(spell.recipe, spell.requirement_source, ["spell"], {})
        result.records[id] = spell
        if e.owner_kind == "condition":
            for owner in e.owner_ids:
                if not result.conditions.has(owner):result.conditions[owner] = id
    return result

## Native spell records go to native_spells/<revision>/ with their index, and
## native_spells/current names that index (a Studio reload picks up a new
## build without reusing records cached from the previous one).
static func _save_native(out_dir: String, native: Dictionary, report: Dictionary) -> void:
    var root := out_dir.path_join("native_spells")
    var hashed := PackedStringArray()
    for id in _sorted(native.records):hashed.append(JSON.stringify([id, native.records[id].selection, native.records[id].recipe, native.records[id].hit]))
    var revision := "".join(hashed).sha256_text().left(16)
    var directory := root.path_join(revision)
    if DirAccess.dir_exists_absolute(root):
        for old in DirAccess.get_directories_at(root):
            if old == revision:continue
            for file in DirAccess.get_files_at(root.path_join(old)):DirAccess.remove_absolute(root.path_join(old).path_join(file))
            DirAccess.remove_absolute(root.path_join(old))
    DirAccess.make_dir_recursive_absolute(directory)
    var index := NativeIndex.new()
    var schema: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Requirements.SCHEMA))
    for kind in schema["$defs"].PlayerNode.properties.fact.anyOf[0].discriminator.mapping:index.fact_requirements[kind] = Requirements.fact(kind)
    for id in _sorted(native.records):
        var path := directory.path_join(short(id) + ".res")
        if ResourceSaver.save(native.records[id], path, ResourceSaver.FLAG_COMPRESS) != OK:Common.error(report, "abilities", "cannot save " + path);continue
        index.spells[id] = path
    index.conditions = native.conditions
    index.revision = "abilities-" + revision
    var index_path := directory.path_join("index.res")
    if ResourceSaver.save(index, index_path, ResourceSaver.FLAG_COMPRESS) != OK:Common.error(report, "abilities", "cannot save native spell index");return
    var marker := FileAccess.open(root.path_join("current"), FileAccess.WRITE)
    marker.store_string(index_path);marker.close()

## Icon per spell, condition and action id (paths relative to res://assets/).
static func icons(entries: Dictionary) -> Dictionary:
    var result := {}
    for section in ["spells", "conditions", "actions"]:
        for id in _sorted(entries.get(section, {})):
            var icon: Resource = entries[section][id].icon
            if icon == null or icon.path.is_empty():continue
            var row := {"path": icon.path, "status": icon.status}
            if icon.rect.size != Vector2i.ZERO:row.rect = [icon.rect.position.x, icon.rect.position.y, icon.rect.size.x, icon.rect.size.y]
            if icon.native_size != Vector2i.ZERO:row.native_size = [icon.native_size.x, icon.native_size.y]
            if not icon.reuses.is_empty():row.reuses = icon.reuses
            if not icon.source.is_empty():row.source = icon.source
            result[id] = row
    return result

static func _validate(entries: Dictionary, report: Dictionary) -> void:
    var package: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACKAGE))
    var clips := {}
    for clip in package.get("clips", []):clips[clip.clip_id] = true
    var cues: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CUES)).get("cues", {})
    var bindings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BINDINGS))
    for section in entries:
        for id in entries[section]:
            var e: Resource = entries[section][id]
            var where: String = "abilities/" + section + "/" + id
            if e.get("id") != null and e.id != id:Common.error(report, where, "entry id " + str(e.id) + " differs from its key")
            if e.get("icon") != null:Common.asset(report, where, e.icon.path)
            for field in ["sockets", "bounds", "trail_points", "variant_sockets"]:
                if e.get(field) is String:Common.asset(report, where, e.get(field))
            if e.get("sounds") is Array:
                for sound in e.sounds:
                    if not sound.cue.is_empty() and not cues.has(sound.cue):Common.warn(report, where, "sound cue not in the audio library: " + sound.cue)
    for id in entries.get("spells", {}):
        var e: Resource = entries.spells[id]
        var where: String = "abilities/spells/" + id
        for use in e.effects:
            if clips.has(use.clip):continue
            if e.native_staging:Common.warn(report, where, "staged clip resolves by role or rename, not by id: " + use.clip)
            elif use.staging_from.begins_with("factory"):Common.error(report, where, "imported clip not in the package: " + use.clip)
        for variant in e.variants:
            for use in variant.effects:
                if not clips.has(use.clip):Common.error(report, where, "variant " + variant.id + " clip not in the package: " + use.clip)
        for sound in e.sounds:_check_binding(report, where, bindings.get("spells", {}).get(id), sound)
    for id in entries.get("conditions", {}):
        var e: Resource = entries.conditions[id]
        for phase in e.sounds:_check_binding(report, "abilities/conditions/" + id, bindings.get("conditions", {}).get(id, {}).get(phase), e.sounds[phase])
    for id in entries.get("actions", {}):
        var e: Resource = entries.actions[id]
        var where: String = "abilities/actions/" + id
        if not e.plays.is_empty() and not entries.actions.has(e.plays):Common.error(report, where, "plays an action with no entry: " + e.plays)
        if not e.delivers_spell.is_empty() and not entries.get("spells", {}).has(e.delivers_spell):Common.error(report, where, "delivers a spell with no entry: " + e.delivers_spell)
        for source in e.effect_sources:
            if not entries.get("sources", {}).has(source):Common.error(report, where, "effect source has no entry: " + source)
        for sound in e.sounds:
            if sound.at != "effect":_check_binding(report, where, bindings.get("actions", {}).get(id), sound)
    for id in entries.get("damage_types", {}):
        for sound in entries.damage_types[id].sounds:_check_binding(report, "abilities/damage_types/" + id, bindings.get("damage_types", {}).get(id), sound)
    _validate_rigs(entries, report)
    for id in entries.get("conditions", {}):_validate_condition(entries.conditions[id], "abilities/conditions/" + id, report)

static func _in(value: float, low: float, high: float) -> bool:
    return is_finite(value) and value >= low and value <= high

static func _colour(value: Color) -> bool:
    return _in(value.r, 0, 1) and _in(value.g, 0, 1) and _in(value.b, 0, 1)

## The ranges the old overlay enforced, now checked once at build time: body
## adjust (alpha 0-1, saturation and brightness 0-2), outline (alpha 0-1,
## onset up to 10 s, colours), feedback durations, pose speeds.
static func _validate_condition(e: Resource, where: String, report: Dictionary) -> void:
    if e.look != null:
        for step in e.look.steps:
            match step.kind:
                "body_adjust":
                    if not _in(step.alpha, 0, 1) or not _in(step.saturation, 0, 2) or not _in(step.brightness, 0, 2) or not _colour(step.rgb):Common.error(report, where, "body adjust out of range")
                "outline":
                    if not _in(step.alpha, 0, 1) or not _in(step.fade_in, 0, 10) or not _colour(step.rgb) or not _colour(step.pulse_colour):Common.error(report, where, "outline out of range")
                    var outline: Dictionary = e.unported.get("persistent", {}).get("bodyOutline", {})
                    if outline.has("pulseOpacity") and not _in(float(outline.pulseOpacity), 0, 1):Common.error(report, where, "outline pulse opacity out of range")
                    if outline.has("periodMs") and not _in(float(outline.periodMs), 1, 10000):Common.error(report, where, "outline period out of range")
                    if outline.has("alphaThreshold") and not _in(float(outline.alphaThreshold), 1, 255):Common.error(report, where, "outline alpha threshold out of range")
                "body_film":
                    if not _in(step.fade_in, 0, 10) or not _in(step.fade_out, 0, 10):Common.error(report, where, "body film fades out of range")
    for text in [e.application_text, e.removal_text]:
        if text != null and text.duration != 0.0 and not _in(text.duration, 0.001, 10):Common.error(report, where, "feedback duration out of range")
## Poses and markers against the rigs' clips (the characters' data as the game
## reads it): a pose's rig and clip exist, a held frame lies inside the clip,
## speeds are sane, and a rig-specific action's markers fall inside its clip.
static func _validate_rigs(entries: Dictionary, report: Dictionary) -> void:
    var rigs: Dictionary = Catalog.read_file("catalog/rigs.json", {})
    for id in entries.get("conditions", {}):
        for pose in entries.conditions[id].poses:
            var where: String = "abilities/conditions/" + id
            var clip: Dictionary = rigs.get(str(pose.get("rig", "")), {}).get("clips", {}).get(str(pose.get("clip", "")), {})
            if clip.is_empty():Common.error(report, where, "pose has no rig clip: " + str(pose.get("rig", "")) + "/" + str(pose.get("clip", "")));continue
            if pose.get("sampling") == "hold" and float(pose.get("frame", 0)) >= float(clip.frames):Common.error(report, where, "held pose frame outside its clip")
            var speed := float(pose.get("playback_speed", 1.0))
            if not is_finite(speed) or speed < 0.01 or speed > 8.0:Common.error(report, where, "pose playback speed out of range")
    for id in entries.get("actions", {}):
        var body: Resource = entries.actions[id].body
        if body == null or body.rig.is_empty():continue
        var where: String = "abilities/actions/" + id
        var clip: Dictionary = rigs.get(body.rig, {}).get("clips", {}).get(body.clip, {})
        if clip.is_empty():Common.error(report, where, "body has no rig clip: " + body.rig + "/" + body.clip);continue
        if not is_finite(body.playback_speed) or body.playback_speed < 0.01 or body.playback_speed > 8.0:Common.error(report, where, "body playback speed out of range")
        for name in body.markers:
            if body.markers[name] > float(clip.frames):Common.error(report, where, "marker " + name + " after the clip's last frame")

## Sounds mirror the audio library's bindings; the build says when they differ.
## Condition ids the installed package plays a lifecycle for (owner_ids).
static func package_lifecycles() -> Dictionary:
    var result := {}
    var package: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACKAGE))
    for selection in package.get("selections", []):
        for id in selection.get("condition", {}).get("owner_ids", []):result[id] = true
    return result

static func package_version() -> String:
    return str(JSON.parse_string(FileAccess.get_file_as_string(PACKAGE)).get("version", ""))

## Old sprite media ids a native source draws (their media_ids).
static func drawn_media(entries: Dictionary) -> Dictionary:
    var result := {}
    for id in entries.get("sources", {}):
        for media in entries.sources[id].record.get("media_ids", []):result[media] = true
    return result

## Coverage of a condition: the installed package's lifecycle or a client
## look that draws makes it ready; a recipe with only feedback or old
## sprite layers, or a zone whose surface draws it, is partial.
static func condition_coverage(e: Resource, lifecycle: bool, drawn: Dictionary) -> String:
    if e.status == "internal":return "internal"
    if (lifecycle and e.play_package_lifecycle) or not e.poses.is_empty() or _visible_look(e.look):return "ready"
    if e.layers.any(func(layer): return layer is Dictionary and drawn.has(str(layer.get("assetId", "")))):return "ready"
    if (not e.disposition.is_empty() and e.disposition != "state_only") or not e.surface.is_empty():return "partial"
    return "missing"

static func _visible_look(look: Resource) -> bool:
    if look == null:return false
    for step in look.steps:
        if step.kind != "body_adjust" or step.alpha < 1.0 or step.rgb != Color.WHITE or step.saturation != 1.0 or step.brightness != 1.0:return true
    return false

static func _check_binding(report: Dictionary, where: String, binding: Variant, sound: Resource) -> void:
    if not binding is Dictionary:Common.warn(report, where, "sound " + sound.cue + " has no binding in the audio library");return
    if binding.get("cue") != sound.cue or binding.get("timing") != sound.at or binding.get("enabled", true) != sound.enabled:
        Common.warn(report, where, "sound differs from the audio library binding: " + sound.cue)

static func _coverage(entries: Dictionary, report: Dictionary) -> void:
    for id in entries.get("spells", {}):Common.cover(report, "spell", id, entries.spells[id].status)
    var lifecycles := package_lifecycles()
    var drawn := drawn_media(entries)
    var without := 0
    for id in entries.get("conditions", {}):
        var e: Resource = entries.conditions[id]
        var status := condition_coverage(e, lifecycles.has(id), drawn)
        if status == "missing":without += 1
        Common.cover(report, "condition", id, status)
    Common.warn(report, "abilities", "%d conditions draw nothing yet: no lifecycle in the installed package (%s) and no client look" % [without, package_version()])
    for id in entries.get("actions", {}):
        var e: Resource = entries.actions[id]
        Common.cover(report, e.kind if e.kind in ACTION_KINDS else "action", id, e.status)
    for id in entries.get("damage_types", {}):Common.cover(report, "damage_type", id, entries.damage_types[id].status)
