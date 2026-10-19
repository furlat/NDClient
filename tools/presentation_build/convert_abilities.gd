extends SceneTree
## Converts today's ability data into the abilities source, re-runnably:
## authoring/abilities.tres (the root), one entry per id under
## authoring/abilities/<section>/ and measured data under
## assets/measured/abilities/. Inputs: the old authoring JSON (spell drafts,
## catalog recipes and contexts, with the old .tres overlays applied), the
## .derived native spell snapshot the game plays today, sandbox staging,
## native_effects, the VFX package's selections, the icon banks, the audio
## library's bindings and authoring/server_ids.json (every id gets an entry).
## Then it builds the runtime documents from the saved entries and compares
## them with today's documents, value by value and type by type.
##   --headless --script res://tools/presentation_build/convert_abilities.gd [-- --verify-only]
## Its inputs (authoring/spells, the catalog recipes and contexts, sandbox
## staging, native_effects, the overlays) were deleted once the game read the
## build; it stays as the record of how the source was made.
const F = preload("res://tools/presentation_build/ability_fields.gd")
const R = preload("res://tools/presentation_build/ability_records.gd")
const Builder = preload("res://tools/presentation_build/abilities.gd")
const Common = preload("res://tools/presentation_build/common.gd")
const NativeAuthoring = preload("res://presentation/native_authoring.gd")
const Root = preload("res://presentation/source/source_root.gd")
const ImageRef = preload("res://presentation/source/image_ref.gd")
const SoundRef = preload("res://presentation/source/sound_ref.gd")
const Spell = preload("res://presentation/source/abilities/spell.gd")
const SpellVariant = preload("res://presentation/source/abilities/spell_variant.gd")
const Condition = preload("res://presentation/source/abilities/condition.gd")
const Action = preload("res://presentation/source/abilities/action.gd")
const Attack = preload("res://presentation/source/abilities/attack.gd")
const AttackVariant = preload("res://presentation/source/abilities/attack_variant.gd")
const DamageType = preload("res://presentation/source/abilities/damage_type.gd")
const Context = preload("res://presentation/source/abilities/context.gd")
const NativeSource = preload("res://presentation/source/abilities/native_source.gd")
const AUTHORING := "res://authoring/"
const ROOT := "res://authoring/abilities.tres"
const ENTRIES := "res://authoring/abilities"
const MEASURED := "res://assets/measured/abilities"
const UI_DELIVERY := "art/ui-delivery-20261018"
## Action ids the server sends as behavior_id without a catalogue entry
## (modern branch, schema 15).
const UNREGISTERED_ACTIONS := ["action.class.barbarian.rage", "action.class.barbarian.end_rage", "action.class.barbarian.frenzy",
    "action.class.barbarian.frenzied_strike", "action.class.barbarian.intimidating_presence", "action.class.barbarian.extend_intimidating_presence",
    "action.class.fighter.action_surge", "action.class.fighter.second_wind", "action.feature.extra_attack",
    "action.class.sorcerer.quickened_spell", "action.class.sorcerer.twinned_spell", "action.class.sorcerer.distant_spell",
    "action.class.sorcerer.draconic_presence", "action.class.sorcerer.dragon_wings.toggle", "action.class.sorcerer.elemental_affinity.resistance",
    "action.class.sorcerer.convert_slot_to_sorcery_points", "action.class.sorcerer.convert_sorcery_points_to_slot", "action.origin.dragonborn.breath_weapon"]
## Native sources nothing reads (deposits belong to the environment's
## residues; the Magic Missile records were replaced by the package).
const DEAD_SOURCES := ["blood.deposit_a1", "blood.deposit_j1", "spell.magic_missile.travel", "spell.magic_missile.impact"]
const DEAD_SOURCE_FIELDS := ["source", "qualification"]
const DEAD_PALETTE_FIELDS := ["neutral_levels", "mapping_source", "source"]

var package: Dictionary
var package_version: String
var server: Dictionary
var cache := {}
var files: Array = []
var measured: Array = []
var notes: Array = []

func _initialize() -> void:
    run.call_deferred()

## The .derived native spell snapshot the game played before the switch to
## the abilities build (the old import of spells/*.json and the staging).
func derived_index() -> Resource:
    if not cache.has("derived_index"):
        var marker := FileAccess.get_file_as_string("res://.derived/native-spells/current").strip_edges()
        cache.derived_index = ResourceLoader.load(marker, "", ResourceLoader.CACHE_MODE_REUSE)
    return cache.derived_index

func json(path: String) -> Variant:
    return JSON.parse_string(FileAccess.get_file_as_string(AUTHORING + path))

## An old document as the game reads it today (old .tres overlays applied).
func effective(path: String) -> Variant:
    var document: Variant = json(path)
    return NativeAuthoring.overlay(path, document, cache) if document is Dictionary else document

func run() -> void:
    var verify_only := OS.get_cmdline_user_args().has("--verify-only")
    package = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/index.json"))
    package_version = "factory@" + str(package.version)
    server = JSON.parse_string(FileAccess.get_file_as_string("res://authoring/server_ids.json")).ids
    if not verify_only:
        var sections := {}
        sections.spells = spells()
        sections.conditions = conditions()
        sections.actions = actions()
        sections.attacks = attacks()
        sections.damage_types = damage_types()
        sections.contexts = contexts()
        sections.sources = sources()
        save(sections)
        learn_order()
    var failures: int = verify()
    for line in notes:print("ABILITIES_NOTE ", line)
    print("ABILITIES_CONVERT ", JSON.stringify({"files": files.size(), "measured": measured.size(), "failures": failures}))
    quit(0 if failures == 0 else 1)

# --- Spells ------------------------------------------------------------------

## Factory selections by spell id: the spell's own selection and its variants.
func factory_selections() -> Dictionary:
    var result := {}
    var spell_ids: Dictionary = server.spell
    for selection in package.selections:
        if not selection.get("condition", {}).is_empty():continue
        var id := ""
        var reference: Dictionary = selection.get("definition_ref", {})
        if str(reference.get("content_id", "")).begins_with("spell."):id = reference.content_id
        elif spell_ids.has("spell." + str(selection.key)):id = "spell." + str(selection.key)
        elif str(selection.get("runtime_key", "")).begins_with("spell."):id = selection.runtime_key
        elif str(selection.get("runtime_key", "")).begins_with("reaction.spell."):id = "spell." + str(selection.runtime_key).trim_prefix("reaction.spell.")
        if id.is_empty():continue
        if not result.has(id):result[id] = []
        result[id].append(selection)
    return result

func spell_icon(id: String) -> ImageRef:
    var resources: Dictionary = json("ui/resources.json")
    var name := id.trim_prefix("spell.")
    var delivered := "res://assets/" + UI_DELIVERY + "/runtime/smooth48/" + id + ".png"
    for key in ["icon:" + id.replace("_", "-"), "icon:spell." + name.replace("_", "-"), "icon:" + id]:
        if resources.has(key):return image(resources[key], key)
    if FileAccess.file_exists(delivered):
        var icon := ImageRef.new();icon.path = UI_DELIVERY + "/runtime/smooth48/" + id + ".png";icon.native_size = Vector2i(48, 48)
        icon.source = "ui-delivery-20261018";return icon
    return null

## An image from ui/resources.json (/media/... -> art/media/...).
func image(resource: Dictionary, key: String) -> ImageRef:
    var icon := ImageRef.new()
    icon.path = "art/media/" + str(resource.path).trim_prefix("/media/")
    if resource.get("rect") is Array:icon.rect = Rect2i(resource.rect[0], resource.rect[1], resource.rect[2], resource.rect[3])
    if resource.get("native_size") is Array:icon.native_size = Vector2i(resource.native_size[0], resource.native_size[1])
    icon.source = "ui/resources.json " + key
    if not FileAccess.file_exists("res://assets/" + icon.path):icon.status = "missing"
    return icon

func delivery_of(info: Dictionary) -> String:
    var shape: String = str(info.get("shape", ""))
    var catalog: String = str(info.get("delivery", {}).get("catalog", ""))
    var area: Variant = info.get("delivery", {}).get("area")
    if not info.get("summons", []).is_empty():return "summon"
    match shape:
        "projectile", "ray", "touch", "self", "teleport", "summon", "wall", "zone":return shape
    if area is Dictionary:
        match str(area.get("shape", "")):
            "cone":return "cone"
            "line":return "line"
            "sphere", "cube", "cylinder":return "sphere" if shape != "cloud" else "cloud"
    if catalog.contains("melee"):return "melee_spell"
    return shape if not shape.is_empty() else "buff"

func spells() -> Dictionary:
    var ids := {}
    var drafts := {}
    var dir := DirAccess.open(AUTHORING + "spells")
    for file in dir.get_files():
        if not file.ends_with(".json"):continue
        var id := file.get_basename()
        if id.begins_with("spell."):ids[id] = true
        else:drafts[id] = json("spells/" + file)
    for id in server.spell:ids[id] = true
    var index: Resource = derived_index()
    for id in index.spells:ids[id] = true
    var staged := {}
    for path in ["sandbox/staging.json", "sandbox/batches/combat.json", "sandbox/batches/support.json"]:
        var document: Dictionary = json(path)
        for name in document.spells:
            var value: Dictionary = document.spells[name]
            staged["spell." + name] = {"staging": value.get("staging", value), "source": path + ":/spells/" + name + ("/staging" if value.has("staging") else "")}
    var factory := factory_selections()
    var bindings: Dictionary = json("audio/bindings.json").get("spells", {})
    var result := {}
    var keys := ids.keys();keys.sort()
    for id in keys:
        var e := Spell.new();e.id = id
        var info: Dictionary = server.spell.get(id, {})
        e.delivery = delivery_of(info) if not info.is_empty() else ""
        e.applies_conditions = PackedStringArray(info.get("conditions", []))
        e.applies_surfaces = PackedStringArray(info.get("spatial_effects", []))
        e.summons = PackedStringArray(info.get("summons", []))
        e.icon = spell_icon(id)
        if FileAccess.file_exists(AUTHORING + "spells/" + id + ".json"):
            var sockets: Dictionary = R.spell_from_recipe(e, json("spells/" + id + ".json"))
            if not sockets.is_empty():e.sockets = write_measured("spells/" + id + ".sockets.json", sockets)
        if index.spells.has(id):
            var record: Resource = load(index.spells[id])
            var bounds: Dictionary = R.spell_from_selection(e, record.selection, record.hit, "client")
            if not bounds.is_empty():e.bounds = write_measured("spells/" + id + ".bounds.json", bounds)
            e.native_staging = true
        elif staged.has(id):
            for cue in staged[id].staging.get("cues", []):e.effects.append(R.effect_from_cue(cue, "client"))
            var staging: Dictionary = staged[id].staging
            if staging.has("light_color"):e.light_colour = staging.light_color
            if staging.has("decorative_light_multiplier"):e.light_multiplier = staging.decorative_light_multiplier
            e.staging_from = "client"
            e.staging_unported = {"source": staged[id].source}
            notes.append(id + ": staged in the sandbox only; its staging is review data (native_staging false)")
        var selections: Array = factory.get(id, [])
        # The spell's own selection: its bare key, else <key>_native, else the
        # first naming the spell; the others are its variants.
        var main: Dictionary = {}
        for name in [id.trim_prefix("spell."), id.trim_prefix("spell.") + "_native"]:
            for selection in selections:
                if main.is_empty() and selection.key == name:main = selection
        for selection in selections:
            if main.is_empty() and str(selection.get("definition_ref", {}).get("content_id", "")) == id:main = selection
        if main.is_empty() and not selections.is_empty():main = selections[0]
        if e.effects.is_empty() and not main.is_empty():
            for cue in main.get("staging", {}).get("cues", []):e.effects.append(R.effect_from_cue(cue, package_version, false))
            var staging: Dictionary = main.get("staging", {})
            if staging.has("light_color"):e.light_colour = str(staging.light_color)
            if staging.has("decorative_light_multiplier"):e.light_multiplier = float(staging.decorative_light_multiplier)
            e.staging_from = package_version
            e.staging_unported = {"selection": main.key}
        for selection in selections:
            if selection == main:continue
            e.variants.append(factory_variant(id, selection))
        for draft_id in drafts:
            if drafts[draft_id].get("definitionRef", {}).get("content_id") == id:e.variants.append(draft_variant(draft_id, drafts[draft_id]))
        if bindings.has(id):e.sounds.append(sound(bindings[id]))
        e.status = spell_status(e)
        result[id] = e
    return result

func factory_variant(id: String, selection: Dictionary) -> SpellVariant:
    var variant := SpellVariant.new()
    variant.id = selection.key;variant.selection = selection.key
    var key: String = selection.key
    variant.kind = "outcome"
    for word in ["miss", "saved", "critical", "blocked", "consumed", "refresh", "removed", "ended", "recovered", "already", "suppressed", "rest", "detonation", "partial", "moving", "members", "transfer", "inventory", "self", "doused", "concentration", "healing_blocked", "eat"]:
        if key.contains("_" + word):variant.kind = "outcome"
    var element := ""
    for name in ["acid", "cold", "fire", "lightning", "poison", "psychic", "thunder", "radiant", "necrotic", "warm", "chill"]:
        if key.contains("_" + name) or key.contains("__" + name):element = name
    if not element.is_empty() and not key.contains("miss") and not key.contains("ground"):variant.kind = "element";variant.value = element
    if key.contains("__") or key.contains("_native") and variant.kind == "outcome" and not ["miss", "saved", "critical", "blocked", "consumed"].any(func(word): return key.contains(word)):
        variant.kind = "form" if element.is_empty() else variant.kind
    for cue in selection.get("staging", {}).get("cues", []):variant.effects.append(R.effect_from_cue(cue, package_version, false))
    variant.staging_from = package_version
    variant.status = "partial" if not variant.effects.is_empty() else "missing"
    return variant

func draft_variant(draft_id: String, draft: Dictionary) -> SpellVariant:
    var variant := SpellVariant.new()
    variant.id = draft_id
    variant.kind = "sub_action" if draft_id.begins_with("action.") else ("reaction" if draft_id.begins_with("reaction.") else ("option" if draft_id.begins_with("control.") else "form"))
    variant.value = draft_id.get_slice(".", draft_id.get_slice_count(".") - 1)
    variant.recipe = draft
    variant.staging_from = "client"
    variant.status = "partial"
    variant.notes = "Old child draft (" + draft_id + "), a complete recipe of the old model; nothing maps a server fact to it."
    return variant

func spell_status(e: Resource) -> String:
    if e.native_staging:return "ready"
    if e.body != null or not e.effects.is_empty() or not e.variants.is_empty():return "partial"
    return "missing"

func sound(binding: Dictionary) -> SoundRef:
    var result := SoundRef.new()
    result.cue = str(binding.get("cue", ""));result.at = str(binding.get("timing", ""))
    result.enabled = bool(binding.get("enabled", true))
    return result

func write_measured(relative: String, data: Variant) -> String:
    var path := MEASURED.path_join(relative)
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    var file := FileAccess.open(path, FileAccess.WRITE)
    file.store_string(F.to_json(data))
    file.close()
    measured.append(path)
    return path.trim_prefix("res://assets/")

# --- Conditions -----------------------------------------------------------------

func conditions() -> Dictionary:
    var recipes: Dictionary = effective("catalog/condition_recipes.json")
    var rates: Dictionary = json("catalog/action_playback_rates.json")
    var bindings: Dictionary = json("audio/bindings.json").get("conditions", {})
    var index: Resource = derived_index()
    var ids := {}
    for id in server.condition:ids[id] = true
    for id in recipes:ids[id] = true
    var keys := ids.keys();keys.sort()
    var result := {}
    for id in keys:
        var e := Condition.new();e.id = id
        var info: Dictionary = server.condition.get(id, {})
        if recipes.has(id):R.condition_from_recipe(e, recipes[id])
        e.owner_spell = str(index.conditions.get(id, ""))
        e.surface = str(info.get("zone_spatial_effect", "")) if info.get("zone_spatial_effect") != null else ""
        if rates.has(id):e.playback_rate = rates[id]
        for phase in bindings.get(id, {}):e.sounds[phase] = sound(bindings[id][phase])
        e.status = "internal" if info.get("category") == "internal" or info.get("kind") == "internal" else "ready"
        if not server.condition.has(id):e.notes = "Sent by the pinned engine under this id; not a condition id on the modern branch."
        result[id] = e
    return result

# --- Actions ---------------------------------------------------------------------

func actions() -> Dictionary:
    var recipes: Dictionary = effective("catalog/body_action_recipes.json")
    var shoves: Dictionary = json("catalog/shove_recipes.json")
    var bindings: Dictionary = json("catalog/body_action_bindings.json")
    var deliveries: Dictionary = json("catalog/action_deliveries.json")
    var attacks: Dictionary = json("catalog/attack_recipes.json")
    var sounds: Dictionary = json("audio/bindings.json").get("actions", {})
    var sources: Dictionary = json("native_effects/index.json").sources
    var resources: Dictionary = json("ui/resources.json")
    var ids := {}
    for kind in ["action", "trait", "reaction", "class_feature", "feat"]:
        for id in server[kind]:ids[id] = kind
    for id in UNREGISTERED_ACTIONS:ids[id] = "action"
    for table in [recipes, shoves, bindings, deliveries, attacks]:
        for id in table:
            if not ids.has(id):ids[id] = id.get_slice(".", 0) if id.get_slice(".", 0) in ["action", "trait", "reaction", "class_feature", "feat"] else "action"
    var keys := ids.keys();keys.sort()
    var result := {}
    for id in keys:
        var e := Action.new();e.id = id;e.kind = ids[id]
        var info: Dictionary = server.get(ids[id], {}).get(id, {})
        e.family = str(info.get("family", "")) if info.get("family") != null else ""
        if recipes.has(id):R.action_from_recipe(e, recipes[id])
        elif shoves.has(id):R.action_from_recipe(e, shoves[id]);e.shove = true
        if bindings.has(id):
            e.plays = str(bindings[id].source_recipe)
            if bindings[id].has("interaction_target"):e.target = str(bindings[id].interaction_target)
            if bindings[id].get("action_feedback") is Dictionary and e.feedback == null:
                e.feedback = R.feedback_from(bindings[id], "action_feedback", R.ACTION_TEXT)
        if deliveries.has(id):e.delivers_spell = str(deliveries[id])
        if sounds.has(id):e.sounds.append(sound(sounds[id]))
        var media: Array = e.unported.get("media", [])
        for item in media:
            for source in sources:
                if source in DEAD_SOURCES:continue
                if str(item.get("assetId", "")) in sources[source].get("media_ids", []) and source not in e.effect_sources:e.effect_sources.append(source)
        for key in ["icon:" + id, "icon:" + id.replace("_", "-"), "icon:action." + id.trim_prefix("action.").replace("_", "-")]:
            if resources.has(key) and e.icon == null:e.icon = image(resources[key], key)
        var delivered: String = UI_DELIVERY + "/runtime/smooth48/" + id + ".png"
        if e.icon == null and FileAccess.file_exists("res://assets/" + delivered):
            e.icon = ImageRef.new();e.icon.path = delivered;e.icon.native_size = Vector2i(48, 48);e.icon.source = "ui-delivery-20261018"
        if attacks.has(id):e.notes = "Presented by the attacks section (attacks/" + id + ")."
        e.status = action_status(e, attacks.has(id), info)
        result[id] = e
    return result

func action_status(e: Resource, attack: bool, info: Dictionary) -> String:
    if attack or (e.body != null and e.body.enabled) or not e.plays.is_empty():return "ready"
    if not e.disposition.is_empty():return "partial"
    if info.get("body") == "passive":return "internal"
    return "missing"

# --- Attacks, damage types, contexts, sources ------------------------------------

func attacks() -> Dictionary:
    var recipes: Dictionary = json("catalog/attack_recipes.json")
    var result := {}
    var trails := {}
    for id in recipes:
        var e := Attack.new();e.id = id
        var found: Dictionary = R.attack_from_recipe(e, recipes[id], AttackVariant)
        if found.trail != null:
            var key := JSON.stringify(found.trail).sha256_text()
            if not trails.has(key):trails[key] = write_measured("attacks/" + id + ".trail.json", {"poses": found.trail})
            e.trail_points = trails[key]
        if not found.sockets.is_empty():e.variant_sockets = write_measured("attacks/" + id + ".sockets.json", found.sockets)
        result[id] = e
    return result

func damage_types() -> Dictionary:
    var context: Dictionary = json("catalog/damage_context.json")
    var responses: Dictionary = json("native_effects/responses.json")
    var sounds: Dictionary = json("audio/bindings.json").get("damage_types", {})
    var result := {}
    var keys: Array = server.damage_type.keys();keys.sort()
    for id in context.palette.byDamageType:
        if id not in keys:keys.append(id)
    for id in keys:
        var e := DamageType.new();e.id = id;e.label = id
        R.damage_type_from(e, context.palette.byDamageType.get(id), str(responses.get("damage_types", {}).get(id, "")))
        if sounds.has(id):e.sounds.append(sound(sounds[id]))
        e.status = "ready" if e.palette != null else "missing"
        result[id] = e
    return result

func contexts() -> Dictionary:
    var result := {}
    for id in Builder.CONTEXT_DOCUMENTS:
        var path: String = Builder.CONTEXT_DOCUMENTS[id]
        if not FileAccess.file_exists(AUTHORING + path):continue
        var document: Variant = json(path)
        var e := Context.new();e.id = id
        if id == "damage" and document.get("palette") is Dictionary:
            document.palette.erase("byDamageType")
            e.notes = "Each damage type's palette is its damage_types entry."
        if id == "hit_responses":
            document.erase("damage_types")
            for field in ["deposit", "direction_when_undisclosed", "status"]:document.erase(field)
            e.notes = "Per damage type responses are the damage_types entries; deposits belong to the environment's residues."
        R.context_from(e, id, document)
        result[id] = e
    var movement: Context = result.get("movement")
    if movement != null:
        var catalog: Resource = NativeAuthoring._catalog(cache)
        movement.values["reference_speed_feet"] = catalog.movement_reference_speed_feet
    return result

func sources() -> Dictionary:
    var records: Dictionary = json("native_effects/index.json").sources
    var result := {}
    for id in records:
        if id in DEAD_SOURCES:continue
        var record: Dictionary = records[id].duplicate(true)
        for field in DEAD_SOURCE_FIELDS:record.erase(field)
        if record.get("palette") is Dictionary:
            for field in DEAD_PALETTE_FIELDS:record.palette.erase(field)
        var e := NativeSource.new();e.id = id;e.kind = str(record.get("kind", ""));e.record = F.plain(record)
        result[id] = e
    return result

# --- Saving and verifying ----------------------------------------------------------

func save(sections: Dictionary) -> void:
    for folder in [ENTRIES, MEASURED]:
        if DirAccess.dir_exists_absolute(folder):remove_tree(folder, folder == MEASURED)
    var root := Root.new();root.domain = "abilities"
    for section in sections:
        var listed := {}
        DirAccess.make_dir_recursive_absolute(ENTRIES.path_join(section))
        for id in sections[section]:
            var path := ENTRIES.path_join(section).path_join(id + ".tres")
            var error := ResourceSaver.save(sections[section][id], path)
            if error != OK:push_error("cannot save " + path + ": " + str(error));continue
            listed[id] = path
            files.append(path)
        root.sections[section] = listed
    ResourceSaver.save(root, ROOT)

## Measured files of this run are kept; the rest of the folder is cleared.
func remove_tree(folder: String, keep_new: bool) -> void:
    var dir := DirAccess.open(folder)
    if dir == null:return
    for sub in dir.get_directories():remove_tree(folder.path_join(sub), keep_new)
    for file in dir.get_files():
        var path := folder.path_join(file)
        if keep_new and path in measured:continue
        DirAccess.remove_absolute(path)

## Key order of today's documents where the build would write another one
## (the .tres text format sorts dictionary keys; typed fields come back last),
## for the build to write records the same way.

func learn_order() -> void:
    if FileAccess.file_exists(Builder.ORDER):DirAccess.remove_absolute(Builder.ORDER)
    var report := Common.report()
    var source: Dictionary = Common.load_root(ROOT, report)
    var built: Dictionary = Builder.documents(source.entries)
    var today := today_documents()
    var needed := {}
    for path in today:
        if built.docs.has(path):needed[path] = F.needed_order(effective(path), built.docs[path])
    var order := {}
    for path in needed:
        var spell: bool = path.begins_with("spells/")
        var group: String = "spells" if spell else path
        if not order.has(group):order[group] = {"generic": {}}
        F.merge_order(order[group].generic, needed[path], not spell)
    for path in needed:
        var spell: bool = path.begins_with("spells/")
        var layout := {"generic": order["spells" if spell else path].generic, "exact": {}}
        var exact := F.needed_order(effective(path), F.ordered(layout, built.docs[path], "", not spell))
        if not exact.is_empty():
            if not order.has(path):order[path] = {}
            order[path].exact = exact
    var file := FileAccess.open(Builder.ORDER, FileAccess.WRITE)
    file.store_string(JSON.stringify(order, "\t", false))
    file.close()

## Today's documents in my domain: what the game reads now.
func today_documents() -> Dictionary:
    var result := {}
    for path in ["catalog/condition_recipes.json", "catalog/action_playback_rates.json", "catalog/body_action_recipes.json",
            "catalog/shove_recipes.json", "catalog/body_action_bindings.json", "catalog/action_deliveries.json", "catalog/attack_recipes.json"]:
        result[path] = effective(path)
    for id in Builder.CONTEXT_DOCUMENTS:
        var path: String = Builder.CONTEXT_DOCUMENTS[id]
        if FileAccess.file_exists(AUTHORING + path):result[path] = effective(path)
    var dir := DirAccess.open(AUTHORING + "spells")
    for file in dir.get_files():
        if file.ends_with(".json"):result["spells/" + file] = json("spells/" + file)
    return result

## Builds from the saved source and compares with today's data.
func verify() -> int:
    var report := Common.report()
    var source: Dictionary = Common.load_root(ROOT, report)
    for line in report.errors:print("ABILITIES_SOURCE_ERROR ", line)
    if source.is_empty():return 1
    var built: Dictionary = Builder.documents(source.entries)
    var failures: int = report.errors.size()
    var today := today_documents()
    var ordered := 0
    for path in today:
        if not built.docs.has(path):print("ABILITIES_VERIFY missing document ", path);failures += 1;continue
        var expected: Variant = today[path]
        var actual: Variant = built.docs[path]
        if path == "native_effects/responses.json":
            for field in ["deposit", "direction_when_undisclosed", "status"]:expected.erase(field)
        var differences := F.differences(expected, actual)
        if not differences.is_empty():
            failures += 1
            print("ABILITIES_VERIFY ", path, " ", JSON.stringify(differences.slice(0, 12)))
        elif not F.order_differences(expected, actual).is_empty():
            ordered += 1
            if OS.get_cmdline_user_args().has("--orders"):print("ABILITIES_ORDER ", path, " ", JSON.stringify(F.order_differences(expected, actual).slice(0, 6)))
    # Native spells: the snapshot the game plays today.
    var index: Resource = derived_index()
    for id in index.spells:
        var today_record: Resource = load(index.spells[id])
        var record: Resource = built.native.records.get(id)
        if record == null:print("ABILITIES_VERIFY native spell missing ", id);failures += 1;continue
        var selection: Dictionary = today_record.selection.duplicate(true)
        for field in ["clips", "clip_by_id"]:selection.erase(field)
        selection.delivery.erase("authored_footprints")
        selection.lifecycle.erase("replaces_media")
        for window in selection.lifecycle.get("cues", {}).values():window.erase("source_evidence")
        selection.staging.erase("light_color_source")
        if selection.staging.get("feedback_palette") is Dictionary:selection.staging.feedback_palette.erase("source")
        for cue in selection.staging.cues:
            for field in R.DEAD_CUE_FIELDS:cue.erase(field)
        var hit: Dictionary = today_record.hit.duplicate(true)
        if hit.has("clip"):hit.clip = {"id": hit.clip.id}
        for field in ["cue_role", "material_class", "source_note"]:hit.definition.erase(field)
        for pair in [["selection", selection, record.selection], ["recipe", today_record.recipe, record.recipe], ["hit", hit, record.hit],
                ["requirements", today_record.requirements, record.requirements], ["requirement_source", today_record.requirement_source, record.requirement_source]]:
            var differences := F.differences(pair[1], pair[2])
            if not differences.is_empty():
                failures += 1
                print("ABILITIES_VERIFY native ", id, " ", pair[0], " ", JSON.stringify(differences.slice(0, 12)))
    if not F.same(index.conditions, built.native.conditions):
        failures += 1;print("ABILITIES_VERIFY native conditions ", index.conditions, " vs ", built.native.conditions)
    # Live readers of native_effects/index.json read its sources, and its
    # spells' lifecycle owners (spatial owners).
    var sources_today: Dictionary = json("native_effects/index.json").sources
    for id in sources_today:
        if id in DEAD_SOURCES:continue
        var expected: Dictionary = sources_today[id].duplicate(true)
        for field in DEAD_SOURCE_FIELDS:expected.erase(field)
        if expected.get("palette") is Dictionary:
            for field in DEAD_PALETTE_FIELDS:expected.palette.erase(field)
        var differences := F.differences(expected, built.docs["native_effects/index.json"].sources.get(id))
        if not differences.is_empty():failures += 1;print("ABILITIES_VERIFY native source ", id, " ", JSON.stringify(differences.slice(0, 8)))
    for id in json("native_effects/index.json").spells:
        var owner: Dictionary = json("native_effects/index.json").spells[id].get("lifecycle", {})
        var built_owner: Dictionary = built.docs["native_effects/index.json"].spells.get(id, {}).get("lifecycle", {})
        if owner.get("owner_kind") == "spatial_effect" and (owner.owner_kind != built_owner.get("owner_kind") or not F.same(owner.owner_ids, built_owner.get("owner_ids"))):
            failures += 1;print("ABILITIES_VERIFY spatial owner ", id)
    for path in F.tiny:print("ABILITIES_TINY ", path)
    print("ABILITIES_VERIFY documents=", today.size(), " native=", index.spells.size(), " order_differences=", ordered, " tiny=", F.tiny.size(), " failures=", failures)
    return failures
