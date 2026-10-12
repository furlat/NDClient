extends RefCounted
const CharacterGeometry = preload("res://presentation/character_geometry.gd")
# Passive adapter from canonical player data to the existing authoring owners.
# The caller owns the cache; keep it on the same thread as its reader.
const VISUAL_SLOT = {"MELEE_MAIN":"weapon_melee_main", "MELEE_OFF":"weapon_melee_off",
    "RANGED_MAIN":"weapon_ranged_main", "RANGED_OFF":"weapon_ranged_off",
    "Head":"helmet", "Body":"body_armor", "Hands":"gauntlets", "Feet":"boots",
    "Cloak":"cloak", "Backpack":"backpack"}
const WEAPON_SET = {"MELEE_MAIN":"melee", "MELEE_OFF":"melee", "RANGED_MAIN":"ranged", "RANGED_OFF":"ranged"}
const EFFECT_SLOTS = ["weaponGlow", "aura", "slash", "effect", "effect2", "effect3"]

static func _read(path: String, cache: Dictionary) -> Variant:
    if not cache.has(path):
        var root: String = ProjectSettings.get_setting("source_data/authoring_root")
        cache[path] = JSON.parse_string(FileAccess.get_file_as_string(root.path_join(path)))
    return cache[path]

static func _error(message: String) -> Dictionary:
    return {"ok":false, "error":{"kind":"authoring", "message":message, "retryable":false}}

static func rig_id(actor: Dictionary, cache: Dictionary) -> String:
    var index: Dictionary = _read("catalog-index.json", cache)
    var creature: Variant = actor.get("creature_content_ref")
    if creature == null: return _read(index.root_rig, cache)
    var owners: Dictionary = _read(index.creature_rigs, cache)
    return owners.get(creature, "")

static func resolve(actor: Dictionary, state: Dictionary, cache: Dictionary) -> Dictionary:
    if not actor.get("present", true) or actor.get("last_visual_position") == null \
        or actor.get("spatial_disposition", "present") != "present" \
        or actor.get("remains_disposition", "intact") == "disintegrated":
        return {"ok":true, "value":null}
    var id = rig_id(actor, cache)
    var index: Dictionary = _read("catalog-index.json", cache)
    var rigs: Dictionary = _read(index.rigs, cache)
    if id.is_empty() or not rigs.has(id): return _error("No authored rig for actor " + str(actor.get("uuid")))
    var position: Array = actor.last_visual_position
    var tile_key = "%d,%d" % [position[0], position[1]]
    var tile: Dictionary = state.get("tiles", {}).get(tile_key, {})
    if not tile.has("elevation_steps"): return _error("No disclosed elevation for actor tile " + tile_key)
    var selected = _select_layers(actor, rigs[id], id == _read(index.root_rig, cache), cache)
    if not selected.ok: return selected
    var appearance: Dictionary = actor.appearance
    return {"ok":true, "value":{"id":actor.uuid, "kind":"actor", "rig":id,
        "position":position.duplicate(), "base_height_steps":tile.elevation_steps, "visual_height":0.0,
        "scale":float(appearance.visual_scale), "scale_x":float(appearance.visual_scale_x),
        "appearance":appearance.duplicate(true), "equipment_layers":selected.value,
        "facing":"SW", "life_state":actor.life_state}}

static func _layer(category: String, tint: int = 0xFFFFFF, alpha: float = 1.0) -> Dictionary:
    return {"category":category, "tint":tint, "alpha":alpha}

static func _select_layers(actor: Dictionary, rig: Dictionary, modular: bool, cache: Dictionary) -> Dictionary:
    var selected: Dictionary = {}
    if not modular:
        var transient: Dictionary = {}
        for clip in rig.clips.values():
            for layer in clip.get("layers", []): transient[layer.slot] = true
        for slot in rig.slot_order:
            if slot in EFFECT_SLOTS or transient.has(slot): continue
            var categories: Array = rig.slot_categories[slot]
            if categories.size() != 1: return _error("Fixed rig slot requires one authored category: " + slot)
            selected[slot] = _layer(categories[0], 0xFFFFFF, float(rig.get("shadow_alpha", 1.0)) if slot == "shadow" else 1.0)
    else:
        var appearance: Dictionary = actor.appearance
        if appearance.presentation_kind != "layered": return _error("Root rig requires layered actor appearance")
        selected.shadow = _layer("Shadow", 0xFFFFFF, 0.5)
        selected.body = _layer(appearance.body_category, int(appearance.skin_tint))
        if appearance.head_category != null: selected.head = _layer(appearance.head_category, int(appearance.hair_tint))
        if appearance.has_beard: selected.beard = _layer("Head2", int(appearance.beard_tint))
        var loadout: Dictionary = actor.visual_loadout
        var items: Dictionary = _read("items/index.json", cache)
        var visuals: Dictionary = _read(items.item_visuals, cache)
        var appearances: Dictionary = _read(items.item_appearances, cache)
        for item in loadout.layers:
            if not VISUAL_SLOT.has(item.slot): continue
            if WEAPON_SET.has(item.slot) and WEAPON_SET[item.slot] != loadout.active_weapon_set: continue
            if item.equipped_visual_policy == "hidden": continue
            var authored = _equipment(item, VISUAL_SLOT[item.slot], visuals, appearances)
            if not authored.ok: return authored
            for layer in authored.value:
                if layer.render_layer in EFFECT_SLOTS: continue
                var value = _layer(layer.sprite_key, int(layer.tint_rgb))
                value.equipment = true
                value.item_uuid = item.item_uuid
                selected[layer.render_layer] = value
    var result: Array = []
    for slot in selected:
        if slot not in rig.slot_order or selected[slot].category not in rig.slot_categories[slot]:
            return _error("Unsupported authored rig layer " + slot + "/" + selected[slot].category)
    for slot in rig.slot_order:
        if selected.has(slot):
            selected[slot].slot = slot
            result.append(selected[slot])
    return {"ok":true, "value":result}

static func _equipment(item: Dictionary, slot: String, visuals: Dictionary, appearances: Dictionary) -> Dictionary:
    var root: Dictionary = {}
    for category in visuals.categories:
        if category.base_category == item.visual_item_name: root = category; break
    if root.is_empty() or root.mechanical_factory_identity == null:
        return _error("No authored item visual " + item.visual_item_name)
    for hand in appearances.hands:
        if hand.category == item.visual_item_name and hand.variant == item.visual_variant_id and hand.slot == slot:
            return {"ok":true, "value":hand.layers}
    var matches: Array = []
    for category in visuals.categories:
        for binding in category.factory_presentation_bindings:
            if binding.factory_identity == root.mechanical_factory_identity and binding.equipment_slot == slot:
                if not category in matches: matches.append(category)
    if matches.size() != 1: return _error("No unique authored equipment binding " + item.visual_item_name + "/" + slot)
    var category: Dictionary = matches[0]
    if item.visual_variant_id == null: return {"ok":true, "value":category.base_presentation.equipment_layers}
    for variant in category.variants:
        if variant.visual_variant_id == item.visual_variant_id: return {"ok":true, "value":variant.equipment_layers}
    return _error("No authored item variant " + item.visual_item_name + "/" + str(item.visual_variant_id) + "/" + slot)

static func _sheet_path(slot: String, sheet: String, resources: Dictionary, components: Dictionary) -> String:
    var path: String = resources[sheet]
    # Fixed-creature combined sheets can contain effects and a second shadow.
    if slot == "body": return components.get(path, {}).get("source_layers", {}).get("body", path)
    return path

static func layers(row: Dictionary, rig: Dictionary, cache: Dictionary) -> Array:
    var result: Array = row.equipment_layers.duplicate(true)
    var index: Dictionary = _read("catalog-index.json", cache)
    var resources: Dictionary = _read(index.resources, cache)
    var components: Dictionary = _read(index.sheet_components, cache)
    for layer in result:
        layer.paths = {}
        for clip in rig.clips:
            var sheet: String = rig.clips[clip].sheets.get(layer.category, "")
            if sheet.is_empty(): continue
            layer.paths[clip] = _sheet_path(layer.slot,sheet,resources,components)
    return result

static func sheet_paths(actor: Dictionary, clips: Array, cache: Dictionary) -> Dictionary:
    # Media preparation uses the same outfit and separated-body owners as the
    # draw adapter, without inventing a future support tile just to find a PNG.
    var index: Dictionary = _read("catalog-index.json", cache)
    var id = rig_id(actor, cache)
    var rigs: Dictionary = _read(index.rigs, cache)
    if not rigs.has(id): return _error("No authored rig for actor " + str(actor.get("uuid")))
    var rig: Dictionary = rigs[id]
    var selected = _select_layers(actor, rig, id == _read(index.root_rig, cache), cache)
    if not selected.ok: return selected
    var paths = {}
    var colour_paths = {}
    var gpu_only = {}
    var resources: Dictionary = _read(index.resources, cache)
    var components: Dictionary = _read(index.sheet_components, cache)
    for clip in clips:
        if not rig.clips.has(clip): return _error("Rig has no authored clip " + id + "/" + clip)
        for layer in selected.value:
            var sheet: String = rig.clips[clip].sheets.get(layer.category, "")
            if not sheet.is_empty():
                var path = _sheet_path(layer.slot,sheet,resources,components)
                paths[path] = true
                colour_paths[path] = true
                var companions = CharacterGeometry.source_paths(path,layer.slot,cache)
                if not companions.ok: return companions
                paths.merge(companions.value)
                gpu_only.merge(companions.value)
    for path in colour_paths: gpu_only.erase(path)
    return {"ok":true,"value":paths,"gpu_only":gpu_only,"cpu_required":colour_paths}

static func rest_sample(actor: Dictionary, rig: Dictionary, cache: Dictionary) -> Dictionary:
    var index: Dictionary = _read("catalog-index.json", cache)
    var clip = "Idle"
    var terminal: bool = actor.life_state in ["dead", "dying", "stable"]
    if actor.life_state == "dead":
        var death: Dictionary = _read(index.death_context, cache)
        clip = death.bodyClip
        for context in rig.get("body_contexts", []):
            if context.role == "death" and context.qualifier.kind == "default" and context.body.actor.enabled:
                clip = context.body.actor.clip
                break
    elif actor.life_state in ["dying", "stable"]:
        var lifecycle: Dictionary = _read(index.life_state_context, cache)
        clip = lifecycle.bodyPoses[actor.life_state].bodyPose
    if not rig.clips.has(clip): return _error("Rig has no authored resting clip " + clip)
    var source: Dictionary = rig.clips[clip]
    return {"ok":true, "value":{"clip":clip, "source_seconds":float(source.frames)/float(source.fps) if terminal else 0.0}}
