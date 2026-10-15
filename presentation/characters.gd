extends RefCounted
const CharacterGeometry = preload("res://presentation/character_geometry.gd")
const Catalog = preload("res://source_catalog.gd")
# Passive adapter from canonical player data to the existing authoring owners.
# The caller owns the cache; keep it on the same thread as its reader.
const VISUAL_SLOT = {"MELEE_MAIN":"weapon_melee_main", "MELEE_OFF":"weapon_melee_off",
    "RANGED_MAIN":"weapon_ranged_main", "RANGED_OFF":"weapon_ranged_off",
    "Head":"helmet", "Body":"body_armor", "Hands":"gauntlets", "Feet":"boots",
    "Cloak":"cloak", "Backpack":"backpack"}
const WEAPON_SET = {"MELEE_MAIN":"melee", "MELEE_OFF":"melee", "RANGED_MAIN":"ranged", "RANGED_OFF":"ranged"}
const EFFECT_SLOTS = ["weaponGlow", "aura", "slash", "effect", "effect2", "effect3"]

static func _read(path: String, cache: Dictionary) -> Variant:
    return Catalog.read_file(path, cache)

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
        var generated_shadow = _generated_creature_shadow(actor,rig,cache)
        var transient: Dictionary = {}
        for clip in rig.clips.values():
            for layer in clip.get("layers", []): transient[layer.slot] = true
        for slot in rig.slot_order:
            if slot=="shadow" and generated_shadow: continue
            if slot in EFFECT_SLOTS or transient.has(slot): continue
            var categories: Array = rig.slot_categories[slot]
            if categories.size() != 1: return _error("Fixed rig slot requires one authored category: " + slot)
            selected[slot] = _layer(categories[0], 0xFFFFFF, float(rig.get("shadow_alpha", 1.0)) if slot == "shadow" else 1.0)
    else:
        var appearance: Dictionary = actor.appearance
        if appearance.presentation_kind != "layered": return _error("Root rig requires layered actor appearance")
        # Modular shadows are generated from original component geometry.
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
            var authored = _equipment(item, VISUAL_SLOT[item.slot], visuals, appearances, cache)
            if not authored.ok: return authored
            for layer in authored.value:
                if layer.render_layer in EFFECT_SLOTS: continue
                var value = _layer(layer.sprite_key, int(layer.tint_rgb))
                value.equipment = true
                value.item_uuid = item.item_uuid
                selected[layer.render_layer] = value
    for effect in actor.get("presentation_layers",[]):
        var slot: String=effect.slot
        var value=_layer(effect.category)
        value.effect=effect
        selected[slot]=value
    var result: Array = []
    for slot in selected:
        if slot not in rig.slot_order or selected[slot].category not in rig.slot_categories[slot]:
            return _error("Unsupported authored rig layer " + slot + "/" + selected[slot].category)
    for slot in rig.slot_order:
        if selected.has(slot):
            selected[slot].slot = slot
            result.append(selected[slot])
    return {"ok":true, "value":result}

static func _equipment_index(visuals: Dictionary, appearances: Dictionary, cache: Dictionary) -> Dictionary:
    var previous:Dictionary=cache.get("__equipment_index",{})
    if not previous.is_empty() and is_same(previous.visuals,visuals) and is_same(previous.appearances,appearances) \
        and is_same(previous.categories,visuals.categories) and is_same(previous.hands,appearances.hands):return previous
    # Build once from immutable admitted documents. Only this cache shell is
    # changed; completed indexes and their original source arrays are read-only.
    var result={"visuals":visuals,"appearances":appearances,"categories":visuals.categories,"hands":appearances.hands,
        "roots":{},"bindings":{},"hand_layers":{}}
    for category in visuals.categories:
        if not result.roots.has(category.base_category):result.roots[category.base_category]=category
        for binding in category.factory_presentation_bindings:
            var key:Array=[binding.factory_identity,binding.equipment_slot]
            if not result.bindings.has(key):result.bindings[key]=[]
            if category not in result.bindings[key]:result.bindings[key].append(category)
    for hand in appearances.hands:
        var key:Array=[hand.category,hand.variant,hand.slot]
        if not result.hand_layers.has(key):result.hand_layers[key]=hand.layers
    cache.__equipment_index=result
    return result

static func _equipment(item: Dictionary, slot: String, visuals: Dictionary, appearances: Dictionary, cache: Dictionary={}) -> Dictionary:
    var index:Dictionary=_equipment_index(visuals,appearances,cache)
    var root:Dictionary=index.roots.get(item.visual_item_name,{})
    if root.is_empty() or root.mechanical_factory_identity == null:
        return _error("No authored item visual " + item.visual_item_name)
    var hand:Array=[item.visual_item_name,item.visual_variant_id,slot]
    if index.hand_layers.has(hand):return {"ok":true,"value":index.hand_layers[hand]}
    var matches:Array=index.bindings.get([root.mechanical_factory_identity,slot],[])
    if matches.size() != 1: return _error("No unique authored equipment binding " + item.visual_item_name + "/" + slot)
    var category: Dictionary = matches[0]
    if item.visual_variant_id == null: return {"ok":true, "value":category.base_presentation.equipment_layers}
    for variant in category.variants:
        if variant.visual_variant_id == item.visual_variant_id: return {"ok":true, "value":variant.equipment_layers}
    return _error("No authored item variant " + item.visual_item_name + "/" + str(item.visual_variant_id) + "/" + slot)

static func _generated_creature_shadow(actor: Dictionary, rig: Dictionary, cache: Dictionary) -> bool:
    if not cache.has("__creature_shadow_rigs"): cache.__creature_shadow_rigs = {}
    var id = rig_id(actor,cache)
    if cache.__creature_shadow_rigs.has(id): return cache.__creature_shadow_rigs[id]
    var index: Dictionary = _read("catalog-index.json",cache)
    var resources: Dictionary = _read(index.resources,cache)
    var components: Dictionary = _read(index.sheet_components,cache)
    var categories: Array = rig.slot_categories.get("body",[])
    var covered = not categories.is_empty()
    for clip in rig.clips.values():
        for category in categories:
            if not clip.sheets.has(category): continue
            var path = _sheet_path("body",clip.sheets[category],resources,components,cache)
            var source = CharacterGeometry.record(path,"body",cache)
            if source.is_empty() or source.get("optical_ground_pixels")==null: covered = false
    cache.__creature_shadow_rigs[id] = covered
    return covered

static func _sheet_path(slot: String, sheet: String, resources: Dictionary, components: Dictionary, cache: Dictionary) -> String:
    var path: String = resources[sheet]
    # Fixed-creature combined sheets can contain effects and a second shadow.
    if slot == "body":
        path = components.get(path, {}).get("source_layers", {}).get("body", path)
        return CharacterGeometry.display_path(path,slot,cache)
    return path

static func layers(row: Dictionary, rig: Dictionary, cache: Dictionary) -> Array:
    var result: Array = row.equipment_layers.duplicate(true)
    var index: Dictionary = _read("catalog-index.json", cache)
    var resources: Dictionary = _read(index.resources, cache)
    var components: Dictionary = _read(index.sheet_components, cache)
    for layer in result:
        layer.paths = {}
        for clip in rig.clips:
            var sheet: String = layer.get("effect",{}).get("sourceSheet",rig.clips[clip].sheets.get(layer.category, ""))
            if sheet.is_empty(): continue
            layer.paths[clip] = _sheet_path(layer.slot,sheet,resources,components,cache)
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
    var geometry_slots = {}
    var normal_sets = {}
    var gpu_only = {}
    var resources: Dictionary = _read(index.resources, cache)
    var components: Dictionary = _read(index.sheet_components, cache)
    for clip in clips:
        if not rig.clips.has(clip): return _error("Rig has no authored clip " + id + "/" + clip)
        for layer in selected.value:
            var effect: Dictionary=layer.get("effect",{})
            var noise: Variant=effect.get("palette",{}).get("noiseSheet")
            if noise!=null and resources.has(noise): paths[resources[noise]]=true; colour_paths[resources[noise]]=true
            var sheet: String = effect.get("sourceSheet",rig.clips[clip].sheets.get(layer.category, ""))
            if not sheet.is_empty():
                var path = _sheet_path(layer.slot,sheet,resources,components,cache)
                paths[path] = true
                colour_paths[path] = true
                var companions = CharacterGeometry.source_paths(path,layer.slot,cache)
                if not companions.ok: return companions
                paths.merge(companions.value)
                gpu_only.merge(companions.value)
                normal_sets.merge(companions.get("normal_sets",{}))
                if effect.is_empty() and not companions.value.is_empty():geometry_slots[path]=layer.slot
    for path in colour_paths: gpu_only.erase(path)
    normal_sets.make_read_only()
    return {"ok":true,"value":paths,"gpu_only":gpu_only,"cpu_required":colour_paths,"geometry_slots":geometry_slots,"normal_sets":normal_sets}

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
