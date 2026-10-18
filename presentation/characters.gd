extends RefCounted
const CharacterGeometry = preload("res://presentation/character_geometry.gd")
const Catalog = preload("res://source_catalog.gd")
const BodySources=preload("res://presentation/body_sources.gd")
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

## The server's creature id inside a ContentRef identity key (pack:creature:id@version).
static func content_id(ref: Variant) -> String:
    var text:String=str(ref)
    return text.get_slice(":",2).get_slice("@",0) if text.count(":")>=2 else text

static func rig_id(actor: Dictionary, cache: Dictionary) -> String:
    var admitted=BodySources.index(cache)
    if admitted==null:return ""
    var creature:Variant=actor.get("creature_content_ref")
    return admitted.root_rig if creature==null else admitted.creature_rigs.get(content_id(creature),"")

static func rigs(cache:Dictionary)->Dictionary:
    var admitted=BodySources.index(cache)
    return {} if admitted==null else admitted.rigs

static func resolve(actor: Dictionary, state: Dictionary, cache: Dictionary) -> Dictionary:
    if not actor.get("present", true) or actor.get("last_visual_position") == null \
        or actor.get("spatial_disposition", "present") != "present" \
        or actor.get("remains_disposition", "intact") == "disintegrated":
        return {"ok":true, "value":null}
    var selected = structure(actor,cache)
    if not selected.ok:return selected
    var position: Array = actor.last_visual_position
    var tile_key = "%d,%d" % [position[0], position[1]]
    var tile: Dictionary = state.get("tiles", {}).get(tile_key, {})
    if not tile.has("elevation_steps"): return _error("No disclosed elevation for actor tile " + tile_key)
    var appearance: Dictionary = actor.appearance
    return {"ok":true, "value":{"id":actor.uuid, "kind":"actor", "rig":selected.value.rig,
        "position":position.duplicate(), "base_height_steps":tile.elevation_steps, "visual_height":0.0,
        "scale":float(appearance.visual_scale), "scale_x":float(appearance.visual_scale_x),
        "appearance":appearance.duplicate(true), "equipment_layers":selected.value.equipment_layers,
        "facing":"SW", "life_state":actor.life_state}}

static func structure(actor:Dictionary,cache:Dictionary)->Dictionary:
    # The compiler compares these same constructor operands without inventing
    # a support tile or resolving position on every ordinary actor after-value.
    var id=rig_id(actor,cache)
    var available:Dictionary=rigs(cache)
    if id.is_empty() or not available.has(id):return _error("No authored rig for actor "+str(actor.get("uuid")))
    var selected=_select_layers(actor,available[id],id==BodySources.index(cache).root_rig,cache)
    if not selected.ok:return selected
    return {"ok":true,"value":{"rig":id,"appearance":actor.appearance,"equipment_layers":selected.value}}

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
        # The built appearance mapping: AppearanceConfig fields and equipment slots -> rig slots and parts.
        var mapping: Dictionary = BodySources.index(cache).appearance
        var visual_slots: Dictionary = mapping.equipment_slots
        var weapon_sets: Dictionary = mapping.weapon_sets
        # Modular shadows are generated from original component geometry.
        selected.body = _layer(appearance.body_category, int(appearance.skin_tint))
        if appearance.head_category != null: selected.head = _layer(appearance.head_category, int(appearance.hair_tint))
        if appearance.has_beard: selected.beard = _layer(mapping.flag_parts.has_beard, int(appearance.beard_tint))
        var loadout: Dictionary = actor.visual_loadout
        for item in loadout.layers:
            if not visual_slots.has(item.slot): continue
            if weapon_sets.has(item.slot) and weapon_sets[item.slot] != loadout.active_weapon_set: continue
            if item.equipped_visual_policy == "hidden": continue
            var authored = BodySources.equipment(item,visual_slots[item.slot],cache)
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
            selected[slot].source_path=BodySources.layer_path(rig_id(actor,cache),selected[slot].category,cache)
            if selected[slot].source_path.is_empty():return _error("No imported body category: "+selected[slot].category)
            result.append(selected[slot])
    return {"ok":true, "value":result}

static func _equipment(item: Dictionary, slot: String, _visuals: Dictionary, _appearances: Dictionary, cache: Dictionary={}) -> Dictionary:
    return BodySources.equipment(item,slot,cache)

static func _generated_creature_shadow(actor:Dictionary,rig:Dictionary,cache:Dictionary)->bool:
    return rigs(cache).get(rig_id(actor,cache),rig).get("generated_shadow",false)

static func _sheet_path(slot:String,sheet:String,_resources:Dictionary,_components:Dictionary,cache:Dictionary)->String:
    var admitted=BodySources.index(cache)
    if admitted==null:return ""
    var source:Dictionary=admitted.sheets.get(sheet,{})
    return source.get(slot,source.get("default",""))

static func prepare_layers(row:Dictionary,rig:Dictionary,cache:Dictionary)->Dictionary:
    # Category selection is thin. Exact clip geometry is admitted by its own
    # preparation consumer; every actor borrows the same path map.
    var result:Array=row.equipment_layers.duplicate(true)
    for layer in result:
        var resource=BodySources.prepare_layer(layer.source_path,cache)
        if resource==null:return _error("Cannot admit body category: "+layer.source_path)
        layer.source_ref=resource
        var effect:Dictionary=layer.get("effect",{})
        var noise:Variant=effect.get("palette",{}).get("noiseSheet")
        if noise!=null:
            var noise_path:String=_sheet_path(layer.slot,str(noise),{},{},cache)
            if BodySources.prepare_descriptor(noise_path,layer.slot,cache).is_empty():return _error("Cannot admit body noise source: "+str(noise))
        if effect.has("sourceSheet"):
            layer.paths={}
            var path:String=_sheet_path(layer.slot,effect.sourceSheet,{},{},cache)
            if BodySources.prepare_descriptor(path,layer.slot,cache).is_empty():return _error("Cannot admit body sourceSheet: "+effect.sourceSheet)
            for clip in rig.clips:layer.paths[clip]=path
        else:
            layer.paths=resource.paths_by_slot.get(layer.slot,{})
        if layer.paths.is_empty():return _error("No admitted body clips for selected category: "+layer.category)
    return {"ok":true,"value":result}

static func layers(row:Dictionary,rig:Dictionary,cache:Dictionary)->Array:
    # Standalone fixtures and the pre-prepared startup compatibility path use
    # this wrapper. Ordinary publication consumes the explicit worker result.
    var prepared:Dictionary=prepare_layers(row,rig,cache)
    if not prepared.ok:push_error(prepared.error.message);return []
    return prepared.value

static func sheet_paths(actor:Dictionary,clips:Array,cache:Dictionary)->Dictionary:
    var id:String=rig_id(actor,cache)
    var available:Dictionary=rigs(cache)
    if not available.has(id):return _error("No authored rig for actor "+str(actor.get("uuid")))
    var rig:Dictionary=available[id]
    var selected:Dictionary=_select_layers(actor,rig,id==BodySources.index(cache).root_rig,cache)
    if not selected.ok:return selected
    for layer in selected.value:
        layer.source_ref=BodySources.prepare_layer(layer.source_path,cache)
        if layer.source_ref==null:return _error("Cannot admit body category: "+layer.source_path)
    var paths:Dictionary={};var colours:Dictionary={};var geometry_slots:Dictionary={}
    var normal_sets:Dictionary={};var gpu_only:Dictionary={}
    var source_refs:Dictionary={"original":[],"gentle":[],"reference":[]};var native_refs:Array=[]
    var source_seen:Dictionary={"original":{},"gentle":{},"reference":{}};var native_seen:Dictionary={}
    for clip in clips:
        if not rig.clips.has(clip):return _error("Rig has no authored clip "+id+"/"+clip)
        for layer in selected.value:
            var effect:Dictionary=layer.get("effect",{})
            var noise:Variant=effect.get("palette",{}).get("noiseSheet")
            if noise!=null:
                var noise_path:String=_sheet_path(layer.slot,str(noise),{},{},cache)
                if noise_path.is_empty():return _error("No imported body noise source: "+str(noise))
                if not noise_path.is_empty():
                    paths[noise_path]=true;colours[noise_path]=true
                    var noise_descriptor:Dictionary=BodySources.prepare_descriptor(noise_path,layer.slot,cache)
                    if noise_descriptor.is_empty():return _error("Cannot admit body noise source: "+str(noise))
                    for profile in source_refs:
                        var reference:Dictionary=noise_descriptor.get("source_records",{}).get(profile,{})
                        if not reference.is_empty() and not source_seen[profile].has(reference.source_id):
                            source_seen[profile][reference.source_id]=true;source_refs[profile].append(reference)
            var descriptor:Dictionary={}
            if effect.has("sourceSheet"):
                var colour:String=_sheet_path(layer.slot,effect.sourceSheet,{},{},cache)
                descriptor=BodySources.prepare_descriptor(colour,layer.slot,cache)
                if descriptor.is_empty():return _error("Cannot admit body sourceSheet: "+effect.sourceSheet)
            else:
                if not layer.source_ref.clip_sources.has(clip):continue
                var source=BodySources.prepare_clip(layer.source_ref,clip,cache)
                if source==null:return _error("Cannot admit body clip: "+layer.category+"/"+clip)
                descriptor=source.descriptors.get(layer.slot,{})
            if descriptor.is_empty():continue
            for profile in source_refs:
                var reference:Dictionary=descriptor.source_records[profile]
                if not source_seen[profile].has(reference.source_id):
                    source_seen[profile][reference.source_id]=true;source_refs[profile].append(reference)
            var native_reference:Dictionary=descriptor.native_record
            if not native_reference.roles.is_empty() and not native_seen.has(native_reference.source_id):
                native_seen[native_reference.source_id]=true;native_refs.append(native_reference)
            var path:String=descriptor.path
            paths[path]=true;colours[path]=true
            paths.merge(descriptor.companions);gpu_only.merge(descriptor.companions)
            normal_sets.merge(descriptor.normal_sets)
            if effect.is_empty() and not descriptor.companions.is_empty():geometry_slots[path]=layer.slot
    for path in colours:gpu_only.erase(path)
    normal_sets.make_read_only()
    for records in source_refs.values():records.make_read_only()
    source_refs.make_read_only();native_refs.make_read_only()
    return {"ok":true,"value":paths,"gpu_only":gpu_only,"cpu_required":colours,"geometry_slots":geometry_slots,
        "normal_sets":normal_sets,"source_records":source_refs,"native_records":native_refs}

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
