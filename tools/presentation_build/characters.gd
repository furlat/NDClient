extends RefCounted
## Builds the characters runtime files from authoring/characters.tres into
## build/presentation/characters/:
##   body-sources/index.res plus one .res per rig category and per category
##   clip: rigs, their layers and clips with res://assets/art paths, depth and
##   normal companions, measured sockets and palette ranges, gear looks keyed by
##   server item id, and the appearance mapping;
##   icons.json: HUD icons (items, common controls) and portraits.
## Coverage: every server creature and item id.
const Common = preload("res://tools/presentation_build/common.gd")
const Index = preload("res://presentation/resources/body_source_index.gd")
const Layer = preload("res://presentation/resources/body_source_layer.gd")
const Clip = preload("res://presentation/resources/body_source_clip.gd")
const Records = preload("res://tools/presentation_build/ability_records.gd")
const PROFILES := ["original", "gentle", "reference"]
const GEAR_SLOTS := ["weapon_melee_main", "weapon_melee_off", "weapon_ranged_main", "weapon_ranged_off", "helmet", "body_armor", "gauntlets", "boots", "cloak", "backpack"]
## Effect slots the runtime keeps out of gear (presentation/characters.gd EFFECT_SLOTS).
const EFFECT_SLOTS := ["weaponGlow", "aura", "slash", "effect", "effect2", "effect3"]
const ROOT := "res://assets"
const EFFECT_PART := "Effect or shadow"

static func build(source: Dictionary, out_dir: String, report: Dictionary) -> void:
    var entries: Dictionary = source.entries
    var state := {"report": report, "out": out_dir.path_join("body-sources"), "parts": entries.get("parts", {}), "rigs": entries.get("rigs", {}),
        "headers": {}, "measured": {}, "index": Index.new(), "layers": 0, "descriptors": 0}
    for section in ["rigs", "characters", "parts", "gear", "appearance", "portraits", "ui", "sheets"]:
        if not entries.has(section):Common.error(report, "characters", "section missing: " + section)
    _check_parts(state)
    _check_rigs(state)
    var bound: Dictionary = _check_characters(state, entries.get("characters", {}))
    var gear: Dictionary = _check_gear(state, entries.get("gear", {}))
    if not report.errors.is_empty():return
    _clear(state.out)
    DirAccess.make_dir_recursive_absolute(state.out)
    var index: Index = state.index
    index.revision = "presentation"
    index.root_rig = bound.root
    index.creature_rigs = bound.creatures
    index.effect_owned_creatures = bound.effects
    var runtime: Array = [bound.root]
    for rig in bound.creatures.values():
        if rig not in runtime:runtime.append(rig)
    for rig_id in runtime:_rig(state, state.rigs[rig_id])
    _external(state, entries.get("sheets", {}))
    _equipment(state, gear)
    _appearance(state, entries.get("appearance", {}).get("modular"))
    _palette_ranges(state)
    if ResourceSaver.save(index, state.out.path_join("index.res")) != OK:Common.error(report, "characters", "cannot save the body-source index")
    _icons(state, entries, out_dir)
    print("CHARACTERS_BUILD ", JSON.stringify({"rigs": index.rigs.size(), "layers": state.layers, "descriptors": state.descriptors, "source_paths": index.source_owners.size(),
        "headers": state.headers.size(), "equipment": index.equipment.size(), "gear": index.gear.size()}))

static func _clear(folder: String) -> void:
    var dir := DirAccess.open(folder)
    if dir == null:return
    for file in dir.get_files():DirAccess.remove_absolute(folder.path_join(file))

static func _res(path: String) -> String:
    return "" if path.is_empty() else ROOT.path_join(path)

## Plain JSON types, exactly as the old JSON tables parsed (every number a float).
static func _plain(value: Variant) -> Variant:
    return JSON.parse_string(JSON.stringify(value, "", false, true))

static func _header(state: Dictionary, path: String) -> Dictionary:
    if state.headers.has(path):return state.headers[path]
    var file := FileAccess.open(path, FileAccess.READ)
    var result := {"error": "Cannot inspect authored PNG: " + path}
    if file != null:
        var bytes := file.get_buffer(24)
        if bytes.size() == 24:
            result = {"width": (int(bytes[16]) << 24) | (int(bytes[17]) << 16) | (int(bytes[18]) << 8) | int(bytes[19]),
                "height": (int(bytes[20]) << 24) | (int(bytes[21]) << 16) | (int(bytes[22]) << 8) | int(bytes[23])}
    state.headers[path] = result
    return result

static func _measured(state: Dictionary, path: String) -> Dictionary:
    if path.is_empty():return {}
    if not state.measured.has(path):
        var file := ROOT.path_join(path)
        state.measured[path] = JSON.parse_string(FileAccess.get_file_as_string(file)) if FileAccess.file_exists(file) else {}
    return state.measured[path]

# ---------------------------------------------------------------- checks

static func _check_parts(state: Dictionary) -> void:
    var report: Dictionary = state.report
    for id in state.parts:
        var part: Resource = state.parts[id]
        if part.id != id:Common.error(report, "parts/" + id, "id differs from its key: " + part.id)
        for action in part.actions:
            var art: Resource = part.actions[action]
            var where: String = "parts/" + id + "/" + action
            if not Common.asset(report, where, art.path):continue
            var surface: Resource = art.surface
            if surface == null or surface.encoding == "none":continue
            _check_normal_profile(surface,report,where)
            _check_camera_origins(surface,report,where)
            var size: Dictionary = _header(state, _res(art.path))
            for path in [surface.depth] + surface.normals.values() + surface.masks.values():
                if Common.asset(report, where, path) and _header(state, _res(path)) != size:Common.error(report, where, "surface size differs from its colour: " + path)
        if not part.measurements.is_empty():Common.asset(report, "parts/" + id, part.measurements)

static func _check_normal_profile(surface:Resource,report:Dictionary,where:String)->void:
    var profile:String=surface.normal_profile
    if profile.is_empty():return
    if profile not in PROFILES or not surface.normals.has(profile) or str(surface.normals[profile]).is_empty():
        Common.error(report,where,"source normal profile needs its actual registered map: "+profile)

static func _check_camera_origins(surface:Resource,report:Dictionary,where:String,facings:Array=[])->void:
    for facing in surface.camera_origins:
        if not surface.camera_origins[facing].is_finite():Common.error(report,where,"nonfinite optical origin: "+facing)
        if not facings.is_empty() and facing not in facings:Common.error(report,where,"optical origin names an unknown facing: "+facing)

static func _check_rigs(state: Dictionary) -> void:
    var report: Dictionary = state.report
    for id in state.rigs:
        var rig: Resource = state.rigs[id]
        var where: String = "rigs/" + id
        if rig.id != id:Common.error(report, where, "id differs from its key: " + rig.id)
        if rig.cell.x <= 0 or rig.cell.y <= 0:Common.error(report, where, "cell size missing")
        if rig.direction_order.size() != 8 and rig.directions == "facing8":Common.error(report, where, "facing8 needs 8 rows")
        for slot in rig.slot_categories:
            if slot not in rig.slot_order:Common.error(report, where, "slot categories for a slot outside slot_order: " + slot)
            if rig.kind == "layered":
                for category in rig.slot_categories[slot]:
                    if not state.parts.has(category):Common.warn(report, where, "slot " + slot + " offers a part with no art: " + category)
        var names := {}
        for clip in rig.clips:
            var at: String = where + "/" + clip.name
            if names.has(clip.name):Common.error(report, at, "duplicate clip")
            names[clip.name] = true
            if clip.frames <= 0:Common.error(report, at, "no frames")
            for marker in clip.markers:
                if clip.markers[marker] < 0 or clip.markers[marker] >= clip.frames:Common.error(report, at, "marker %s outside the clip's %d frames" % [marker, clip.frames])
            for layer in clip.art:Common.asset(report, at, clip.art[layer])
            if clip.surface != null and clip.surface.encoding != "none":
                _check_normal_profile(clip.surface,report,at)
                _check_camera_origins(clip.surface,report,at,Array(rig.direction_order))
                var size: Dictionary = _header(state, _res(clip.art.get("body", "")))
                for path in [clip.surface.depth] + clip.surface.normals.values() + clip.surface.masks.values():
                    if Common.asset(report, at, path) and not size.has("error") and _header(state, _res(path)) != size:Common.error(report, at, "surface size differs from its colour: " + path)
            for key in clip.sheets.values():
                if key.begins_with("/spritesheets/"):
                    var part: String = key.get_slice("/", 2)
                    if not state.parts.has(part) or not state.parts[part].actions.has(key.get_slice("/", 3).get_basename()):Common.error(report, at, "names a missing part sheet: " + key)
        for role in rig.fallbacks:
            if not names.has(rig.fallbacks[role]):Common.error(report, where, "fallback " + role + " names a missing clip: " + rig.fallbacks[role])
        for context in rig.contexts:
            if context.enabled and not names.has(context.clip):Common.error(report, where, context.role + " context names a missing clip: " + context.clip)
        Common.asset(report, where, rig.measurements)

## The rigs the game binds: the player body's (root) and each creature's, by content id.
static func _check_characters(state: Dictionary, characters: Dictionary) -> Dictionary:
    var report: Dictionary = state.report
    var result := {"root": "", "creatures": {}, "effects":{}}
    var ids: Dictionary = Common.server_ids().get("ids", {}).get("creature", {})
    for id in characters:
        var entry: Resource = characters[id]
        var where: String = "characters/" + id
        if entry.id != id:Common.error(report, where, "id differs from its key: " + entry.id)
        if not entry.rig.is_empty() and not state.rigs.has(entry.rig):Common.error(report, where, "rig missing: " + entry.rig);continue
        if id == "creature.player.humanoid_body":result.root = entry.rig;continue
        if not ids.has(id):Common.warn(report, where, "not a server creature id")
        Common.cover(report, "creature", id, entry.status)
        if entry.body_policy=="effect":
            result.effects[id]=true
            continue
        if not entry.rig.is_empty() and entry.status != "missing":result.creatures[id] = entry.rig
    for id in ids:
        if not characters.has(id):Common.error(report, "characters", "no entry for server creature " + id)
    if result.root.is_empty():Common.error(report, "characters", "the player body creature.player.humanoid_body has no rig")
    elif state.rigs[result.root].kind != "layered":Common.error(report, "characters", "the player body needs the layered rig")
    return result

static func _check_item_effect_selector(use:Resource,where:String,report:Dictionary,_impact:bool=false)->void:
    # Impacts may select from the actual AttackFact.item_effects snapshot.
    # This is membership-qualified contact, never an applied damage verdict.
    if use.item_effect_behavior_id.is_empty() and not use.item_effect_damage_type.is_empty():
        Common.error(report,where,"item-effect damage selector requires its actual behavior id")
    if not use.item_effect_damage_type.is_empty() and use.item_effect_damage_type not in ["Acid","Bludgeoning","Cold","Fire","Force","Lightning","Necrotic","Piercing","Poison","Psychic","Radiant","Slashing","Thunder"]:
        Common.error(report,where,"unknown public item-effect damage type "+use.item_effect_damage_type)

static func _check_gear(state: Dictionary, gear: Dictionary) -> Dictionary:
    var report: Dictionary = state.report
    var ids: Dictionary = Common.server_ids().get("ids", {}).get("item", {})
    var clips: Dictionary = {}
    var root: Resource = null
    for rig in state.rigs.values():
        if rig.kind == "layered":root = rig
    for id in gear:
        var entry: Resource = gear[id]
        var where: String = "gear/" + id
        if entry.id != id:Common.error(report, where, "id differs from its key: " + entry.id)
        if not entry.family.is_empty() and not gear.has(entry.family):Common.error(report, where, "family missing: " + entry.family)
        if entry.icon != null and entry.icon.status != "missing":Common.asset(report, where, entry.icon.path)
        for use in entry.effects:
            if use==null:Common.error(report,where,"null item decoration");continue
            _check_item_effect_selector(use,where,report)
            if clips.is_empty():
                var package:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/index.json"))
                for clip in package.clips:clips[clip.clip_id]=clip
            if not clips.has(use.clip):Common.error(report,where,"item decoration clip is not delivered: "+use.clip)
            elif "created_item_binding" in clips[use.clip].get("inputs",[]):
                Common.error(report,where,"native item-body source cannot be authored as a weapon decoration: "+use.clip)
            if use.role not in ["sustain","attached"] or use.at not in ["","owner_start"] or not is_zero_approx(use.delay):
                Common.error(report,where,"item decorations sustain on actual item membership; finite/delayed cues belong to spells/actions/conditions")
            if not use.lifecycle.is_empty() or not is_zero_approx(use.source_start) or use.source_end>=0 or not is_equal_approx(use.source_rate,1.0):
                Common.error(report,where,"intrinsic item effects use the unscaled held source clock; finite/rate staging belongs to event/condition authoring")
            if not use.follow:Common.error(report,where,"intrinsic weapon decorations must follow the displayed weapon")
            if use.attachment not in ["item","recipient_weapon"]:
                Common.error(report,where,"item decoration requires an item or recipient_weapon attachment")
            if use.recipient_slots.is_empty():Common.error(report,where,"modular item decoration requires explicit recipient_slots")
            for slot in use.recipient_slots:
                if slot not in ["weapon","offhand"]:Common.error(report,where,"item decoration needs a separate modular weapon/offhand receiver: "+slot)
            for slot in use.extra.get("equipment_slots",[]):
                if slot not in GEAR_SLOTS:Common.error(report,where,"unknown item decoration equipment slot "+str(slot))
        for use in entry.impact_effects:
            if use==null:Common.error(report,where,"null weapon impact");continue
            _check_item_effect_selector(use,where,report,true)
            if clips.is_empty():
                var package:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/index.json"))
                for clip in package.clips:clips[clip.clip_id]=clip
            if not clips.has(use.clip):Common.error(report,where,"weapon impact clip is not delivered: "+use.clip)
            elif "created_item_binding" in clips[use.clip].get("inputs",[]):Common.error(report,where,"native weapon body cannot be an impact")
            if use.role!="impact" or use.at not in ["","body.impact"] or use.attachment!="recipient_body":
                Common.error(report,where,"weapon impact requires impact/body.impact/recipient_body staging")
            if not use.constructor_input.is_empty():Common.error(report,where,"weapon impact constructor result projection is not authored; use public weapon_impact input")
            if use.follow:Common.error(report,where,"weapon impacts retain the actual contact; following body effects belong to conditions")
            if use.delay<0 or use.source_rate<=0 or not is_zero_approx(use.source_start) or not use.lifecycle.is_empty():
                Common.error(report,where,"weapon impacts require nonnegative contact delay, positive source rate and an ordinary finite source window")
        var looks: Array = []
        for slot in entry.slots:
            if slot not in GEAR_SLOTS:Common.error(report, where, "unknown visual slot " + slot)
            looks.append(entry.slots[slot].layers)
            looks.append_array(entry.slots[slot].variants.values())
        for slot in entry.hands:looks.append_array(entry.hands[slot].values())
        for layers in looks:
            for layer in layers:
                if root != null and (layer.slot not in root.slot_order or layer.part not in root.slot_categories.get(layer.slot, [])):
                    Common.error(report, where, "layer %s/%s is not a part of the layered rig's slot" % [layer.slot, layer.part])
        if ids.has(id):Common.cover(report, "item", id, entry.status)
    for id in ids:
        if not gear.has(id):Common.error(report, "gear", "no entry for server item " + id)
    return gear

# ---------------------------------------------------------------- body sources

## The legacy-shaped rig record the runtime reads (cell, pivot, facing rows,
## slots, clips with their sheet keys, contexts and measured sockets).
static func _rig_record(state: Dictionary, rig: Resource) -> Dictionary:
    var record := {"cell_width": rig.cell.x, "cell_height": rig.cell.y, "origin_y_from_ground": rig.cell.y - rig.pivot.y,
        "body_anchor": {"x": rig.anchor.x, "y": rig.anchor.y}, "facing_rows": {}, "slot_order": Array(rig.slot_order), "slot_categories": {}, "clips": {}}
    for row in rig.direction_order.size():record.facing_rows[rig.direction_order[row]] = row
    for slot in rig.slot_categories:record.slot_categories[slot] = Array(rig.slot_categories[slot])
    if not rig.excluded_categories.is_empty():record.selection_excluded_categories = Array(rig.excluded_categories)
    if rig.shadow_alpha >= 0.0:record.shadow_alpha = rig.shadow_alpha
    if rig.lifecycle_scale > 0.0:record.lifecycle_scale = rig.lifecycle_scale
    if rig.native_wings:record.native_wings = true
    var measured: Dictionary = _measured(state, rig.measurements)
    record.rest_pose_anchors = measured.get("rest_pose_anchors", {}).duplicate()
    for clip in rig.hold_clips:
        if not record.rest_pose_anchors.has(clip):record.rest_pose_anchors[clip] = {}
    if measured.has("pose_sockets"):record.pose_sockets = measured.pose_sockets
    for clip in rig.clips:
        var value := {"source_clip": clip.source_clip, "frames": clip.frames, "fps": clip.fps, "sheets": _clip_sheets(state, rig, clip)}
        if clip.loop != "rig":value.loop = clip.loop == "loop"
        if not clip.effect_layers.is_empty():
            var layers := []
            for category in clip.effect_layers:layers.append({"slot": _slot_of(rig, category), "category": category, "enabled": clip.effect_layers[category]})
            value.layers = layers
        if not clip.markers.is_empty():
            var anchors := []
            for marker in clip.markers:anchors.append({"name": marker, "frame": clip.markers[marker]})
            anchors.sort_custom(func(a, b): return a.frame < b.frame or (a.frame == b.frame and a.name < b.name))
            value.anchors = anchors
        if clip.owns_cast_preparation:value.owns_cast_preparation = true
        if measured.get("clip_sockets", {}).has(clip.name):value.source_sockets = measured.clip_sockets[clip.name]
        record.clips[clip.name] = value
    # An explicit stand-in plays another clip of this rig under the role's name.
    for role in rig.fallbacks:
        var target: String = rig.fallbacks[role]
        if not record.clips.has(role) and record.clips.has(target):
            record.clips[role] = record.clips[target].duplicate(true)
            record.clips[role].stand_in = target
    if not rig.contexts.is_empty():
        var contexts := []
        for context in rig.contexts:
            var body := {"actor": {"enabled": context.enabled, "clip": context.clip, "playbackSpeed": context.playback_speed, "hiddenSlots": Array(context.hidden_slots), "media": context.media}}
            if not context.playback.is_empty():body.playback = context.playback
            if not context.frame_keys.is_empty():body.frameKeys = context.frame_keys
            if not context.anchors.is_empty():body.anchors = context.anchors
            if context.rest_frame >= 0:body.restFrame = context.rest_frame
            if context.reversed:body.reversed = true
            contexts.append({"role": context.role, "qualifier": context.qualifier, "body": body})
        record.body_contexts = contexts
    return _plain(record)

static func _slot_of(rig: Resource, category: String) -> String:
    for slot in rig.slot_order:
        if category in rig.slot_categories.get(slot, []):return slot
    return ""

## Category -> sheet key; on the layered rig every solid part with the action
## plus the effect parts the clip names.
static func _clip_sheets(state: Dictionary, rig: Resource, clip: Resource) -> Dictionary:
    var result := {}
    if not clip.sheets.is_empty() or rig.kind != "layered":
        for category in clip.sheets:result[category] = clip.sheets[category]
        return result
    for slot in rig.slot_order:
        for category in rig.slot_categories.get(slot, []):
            var part: Resource = state.parts.get(category)
            if result.has(category) or part == null or not part.actions.has(clip.source_clip):continue
            if part.notes.begins_with(EFFECT_PART) and not clip.effect_parts.has(category):continue
            result[category] = "/spritesheets/" + category + "/" + clip.source_clip + ".png"
    return result

static func _optical_camera(surface:Resource,elevation:float)->Dictionary:
    var camera:Dictionary={"origin":[surface.camera_origin.x,surface.camera_origin.y],"elevation_degrees":elevation,"physical_camera_calibrated":false}
    if not surface.camera_origins.is_empty():
        var origins:Dictionary={}
        for facing in surface.camera_origins:
            var origin:Vector2=surface.camera_origins[facing]
            origins[facing]=[origin.x,origin.y]
        camera.origins_by_facing=origins
    return camera

## The record the runtime binds for one sheet in one slot: files relative to
## _source_root, depth range, optical camera and ground line.
static func _part_geometry(part: Resource, action: String, slot: String) -> Dictionary:
    var art: Resource = part.actions.get(action)
    if art == null or art.surface == null or art.surface.encoding == "none" or slot == "shadow" or slot not in part.slots:return {}
    var surface: Resource = art.surface
    var record := {"status": surface.status, "role": "body", "category": part.id, "source_action": action, "slots": Array(part.slots), "_source_root": ROOT,
        "files": {"depth": surface.depth, "normal": surface.normals.get("original" if surface.normal_profile.is_empty() else surface.normal_profile,""), "support": surface.masks.support, "normal_valid": surface.masks.normal_valid},
        "depth_range": Array(surface.depth_limits) if surface.depth_limits.size() == 2 else [surface.depth_range.x, surface.depth_range.y],
        "reference": surface.masks.solid, "solid": surface.masks.solid, "measurements": part.measurements,
        "optical_camera": _optical_camera(surface,art.camera_elevation_degrees)}
    if not surface.normal_profile.is_empty():record.normal_profile=surface.normal_profile
    return record

static func _body_geometry(rig: Resource, clip: Resource) -> Dictionary:
    var surface: Resource = clip.surface
    if surface == null or surface.encoding == "none":return {}
    var record := {"status": surface.status, "role": "body", "slots": ["body"], "_source_root": ROOT,
        "files": {"depth": surface.depth, "normal": surface.normals.get("original" if surface.normal_profile.is_empty() else surface.normal_profile,""), "support": surface.masks.support, "normal_valid": surface.masks.normal_valid},
        "normal_profiles": surface.normals.duplicate(),
        "depth_range": Array(surface.depth_limits) if surface.depth_limits.size() == 2 else [surface.depth_range.x, surface.depth_range.y],
        "depth_byte_range": [surface.depth_byte_range.x, surface.depth_byte_range.y],
        "optical_camera": _optical_camera(surface,rig.camera_elevation_degrees),
        "cell_size": [rig.cell.x, rig.cell.y], "frames": clip.frames, "source_coverage": surface.coverage}
    record.optical_ground_pixels = surface.optical_ground_pixels if is_finite(surface.optical_ground_pixels) else null
    if not surface.normal_profile.is_empty():record.normal_profile=surface.normal_profile
    if clip.art.get("body", "").begins_with("art/geometry/"):record.colour_path = clip.art.body
    return record

static func _role_record(paths: Dictionary, cpu: Dictionary) -> Dictionary:
    var roles := {}
    for path in paths:roles[path] = [path, int(cpu.has(path)), 0, 0]
    return {"roles": roles}

## One sheet's runtime descriptor: its colour path, depth/normal companions,
## optical paths, baked socket samples and the media role records.
static func _descriptor(state: Dictionary, path: String, geometry: Dictionary) -> Dictionary:
    var companions := {}
    var normals := {}
    var optical := {}
    var sockets := {}
    var fixed_profile:String=str(geometry.get("normal_profile",""))
    if not geometry.is_empty():
        var root: String = geometry._source_root
        for field in geometry.files:
            if field!="normal" or fixed_profile.is_empty():companions[root.path_join(geometry.files[field])] = true
        if geometry.has("normal_profiles"):
            for profile in geometry.normal_profiles:normals[profile] = root.path_join(geometry.normal_profiles[profile])
        else:
            var part: Resource = state.parts[geometry.category]
            for profile in part.actions[geometry.source_action].surface.normals:
                normals[profile] = _res(part.actions[geometry.source_action].surface.normals[profile])
        for profile in normals:
            if fixed_profile.is_empty() or profile==fixed_profile:companions[normals[profile]] = true
        if geometry.has("reference"):
            optical = {"colour": path, "depth": root.path_join(geometry.files.depth), "support": root.path_join(geometry.files.support), "solid": root.path_join(geometry.solid)}
            var baked: Dictionary = _measured(state, geometry.measurements).get("actions", {}).get(geometry.source_action, {})
            if not baked.is_empty():
                var samples := {}
                var pixels: Array = baked.pixels
                var values: Array = baked.values
                for i in pixels.size() / 2:samples["%d,%d" % [int(pixels[i * 2]), int(pixels[i * 2 + 1])]] = values.slice(i * 4, i * 4 + 4)
                sockets = _plain({"valid": true, "size": baked.size, "samples": samples})
        geometry = geometry.duplicate()
        for key in ["solid", "measurements"]:geometry.erase(key)
        geometry = _plain(geometry)
    var sources := {}
    for profile in PROFILES:
        var selected := {path: true}
        var selected_profile:String=profile if fixed_profile.is_empty() else fixed_profile
        for companion in companions:
            if companion not in normals.values() or companion == normals.get(selected_profile):selected[companion] = true
        sources[profile] = _role_record(selected, {path: true})
    var native_paths := {}
    var native_cpu := {}
    for channel in optical:
        if channel == "colour":continue
        if channel == "solid" or not sockets.get("valid", false):
            native_paths[optical[channel]] = true
            if not sockets.get("valid", false):native_cpu[optical[channel]] = true
    return {"path": path, "geometry": geometry, "companions": companions, "normal_paths": normals, "normal_sets": {} if normals.is_empty() or not fixed_profile.is_empty() else {path: normals},
        "optical_paths": optical, "sockets": sockets, "source_records": sources, "native_record": _role_record(native_paths, native_cpu)}

## raw (the sheet the key names), colour (the sheet drawn in this slot) and the
## geometry record, for one sheet key of one clip in one slot.
static func _resolve(state: Dictionary, rig: Resource, clip: Resource, key: String, slot: String) -> Dictionary:
    if key.begins_with("/spritesheets/"):
        var part: Resource = state.parts.get(key.get_slice("/", 2))
        var action: String = key.get_slice("/", 3).get_basename()
        var raw: String = _res(part.actions[action].path)
        return {"raw": raw, "colour": raw, "geometry": _part_geometry(part, action, slot)}
    if slot == "body":return {"raw": _res(clip.art.combined), "colour": _res(clip.art.body), "geometry": _body_geometry(rig, clip)}
    if not slot in ["shadow", "effect"] or not clip.art.has(slot):
        Common.error(state.report, "rigs/" + rig.id + "/" + clip.name, "no art for sheet " + key + " in slot " + slot)
        return {}
    return {"raw": _res(clip.art[slot]), "colour": _res(clip.art[slot]), "geometry": {}}

static func _rig(state: Dictionary, rig: Resource) -> void:
    var index: Index = state.index
    var record: Dictionary = _rig_record(state, rig)
    record.generated_shadow = true
    index.layers[rig.id] = {}
    var categories := {}
    for slot in rig.slot_order:
        for category in rig.slot_categories.get(slot, []):
            if not categories.has(category):categories[category] = []
            categories[category].append(slot)
    var modular: bool = rig.kind == "layered"
    var clips := {}
    for clip in rig.clips:clips[clip.name] = clip
    for category in categories:
        var layer := Layer.new()
        layer.rig_id = rig.id
        layer.category = category
        var path: String = state.out.path_join(rig.id + "--" + category + ".res")
        for name in record.clips:
            var key: String = record.clips[name].sheets.get(category, "")
            if key.is_empty():continue
            var clip: Resource = clips.get(name, clips.get(record.clips[name].get("stand_in", "")))
            layer.clips[name] = {}
            var selected := Clip.new()
            var clip_path: String = state.out.path_join(rig.id + "--" + category + "--" + name + ".res")
            for slot in categories[category]:
                var resolved: Dictionary = _resolve(state, rig, clip, key, slot)
                if resolved.is_empty():continue
                var colour: String = resolved.colour
                var descriptor: Dictionary = _descriptor(state, colour, resolved.geometry)
                for profile in descriptor.source_records:descriptor.source_records[profile].source_id = StringName(path + "::" + name + "/" + slot + "/" + profile)
                descriptor.native_record.source_id = StringName(path + "::" + name + "/" + slot + "/native")
                selected.descriptors[slot] = descriptor
                state.descriptors += 1
                var thin := {"path": descriptor.path, "companions": descriptor.companions}
                # Light-profile switches request only the selected modular normal map.
                if modular and not descriptor.normal_paths.is_empty():thin.profiles = descriptor.normal_paths
                layer.clips[name][slot] = thin
                if not layer.paths_by_slot.has(slot):layer.paths_by_slot[slot] = {}
                layer.paths_by_slot[slot][name] = descriptor.path
                if slot == "body" and descriptor.geometry.get("optical_ground_pixels") == null:record.generated_shadow = false
                var all := {colour: true}
                all.merge(descriptor.companions)
                for value in descriptor.optical_paths.values():all[value] = true
                for file in all:
                    layer.headers[file] = _header(state, file)
                    if not index.source_owners.has(file):index.source_owners[file] = [path, name]
                if not index.source_owners.has(resolved.raw):index.source_owners[resolved.raw] = [path, name]
                if not index.sheets.has(key):index.sheets[key] = {}
                index.sheets[key][slot] = colour
                index.sheets[key].default = resolved.raw
            if ResourceSaver.save(selected, clip_path) != OK:Common.error(state.report, "characters", "cannot save " + clip_path)
            layer.clip_sources[name] = clip_path
        if ResourceSaver.save(layer, path) != OK:Common.error(state.report, "characters", "cannot save " + path)
        index.layers[rig.id][category] = path
        state.layers += 1
    index.rigs[rig.id] = record

## Other domains' images that cast layers name by sheet key (spell hand noise,
## condition films). They keep their legacy /media/ identity while their
## owner's readers still use it, but load from res://assets/art.
static func _external(state: Dictionary, sheets: Dictionary) -> void:
    var index: Index = state.index
    var loose := 0
    for id in sheets:
        var table: Resource = sheets[id]
        for key in table.sheets:
            if index.sheets.has(key):continue
            var art: String = table.sheets[key]
            if not Common.asset(state.report, "sheets/" + id, art):continue
            var colour: String = "/media/" + art.trim_prefix("art/media/") if table.legacy_media_identity and art.begins_with("art/media/") else _res(art)
            index.sheets[key] = {"default": colour}
            if not colour.to_lower().ends_with(".png") or index.source_owners.has(colour):continue
            var layer := Layer.new()
            layer.category = key
            var path: String = state.out.path_join("accent--%04d.res" % loose)
            var selected := Clip.new()
            var descriptor: Dictionary = _descriptor(state, colour, {})
            for profile in PROFILES:
                descriptor.source_records[profile] = {"roles": {colour: [_res(art), 1, 0, 0]}, "source_id": StringName(path + "/" + profile)}
            descriptor.native_record.source_id = StringName(path + "/native")
            var clip_path: String = path.get_basename() + "--source.res"
            selected.descriptors = {"*": descriptor}
            layer.clips = {"source": {"*": {"path": colour, "companions": descriptor.companions}}}
            layer.clip_sources = {"source": clip_path}
            layer.paths_by_slot = {"*": {"source": colour}}
            layer.headers[colour] = _header(state, _res(art))
            if ResourceSaver.save(selected, clip_path) != OK or ResourceSaver.save(layer, path) != OK:Common.error(state.report, "characters", "cannot save " + path)
            index.source_owners[colour] = [path, "source"]
            loose += 1

# ---------------------------------------------------------------- gear, appearance, palettes

static func _legacy_layers(layers: Array) -> Array:
    var result := []
    for layer in layers:result.append({"render_layer": layer.slot, "sprite_key": layer.part, "tint_rgb": float(("0x" + layer.tint.trim_prefix("#")).hex_to_int())})
    return result

## [family, visual variant or null, visual slot] -> layers, as today's lookup
## resolved it: a hand override wins; otherwise the slot's look, its base
## layers for no variant or the variant's own.
static func _equipment(state: Dictionary, gear: Dictionary) -> void:
    var index: Index = state.index
    for id in gear:
        var entry: Resource = gear[id]
        for field in ["effects","impact_effects"]:
            var uses:Array=entry.effects if field=="effects" else entry.impact_effects
            if uses.is_empty():continue
            var effects:Array=[]
            for ordinal in uses.size():
                var cue:Dictionary=Records.cue_from_effect(uses[ordinal],ordinal)
                cue.source=entry.resource_path+"::"+field+"/"+str(ordinal)
                Records.F.emit(cue,"selection",uses[ordinal],"selection","string")
                Records.F.emit(cue,"offset",uses[ordinal],"offset","vec3")
                Records.F.emit(cue,"item_effect_behavior_id",uses[ordinal],"item_effect_behavior_id","string")
                Records.F.emit(cue,"item_effect_damage_type",uses[ordinal],"item_effect_damage_type","string")
                if not uses[ordinal].recipient_slots.is_empty():
                    cue.entity_geometry={"actor":"recipient","slots":Array(uses[ordinal].recipient_slots)}
                if field=="impact_effects":cue.at="body.impact"
                effects.append(cue)
            if field=="effects":index.item_effects[id]=effects
            else:index.item_impact_effects[id]=effects
        if not entry.ground.is_empty() or not entry.family.is_empty():_ground_equipment(state,entry)
        if not entry.family.is_empty():index.gear[id] = [entry.family, entry.visual_variant_id]
        if entry.slots.is_empty() and entry.hands.is_empty():continue
        index.gear[id] = [id, ""]
        for slot in GEAR_SLOTS:
            var look: Dictionary = entry.slots.get(slot, {})
            var hands: Dictionary = entry.hands.get(slot, {})
            var variants := {null: true}
            for variant in look.get("variants", {}):variants[variant] = true
            for variant in hands:variants[null if variant.is_empty() else variant] = true
            for variant in variants:
                var key := [id, variant, slot]
                var hand_key: String = "" if variant == null else variant
                if hands.has(hand_key):index.equipment[key] = _legacy_layers(hands[hand_key]);continue
                if look.is_empty():index.equipment_errors[key] = "No unique authored equipment binding " + id + "/" + slot;continue
                if variant == null:index.equipment[key] = _legacy_layers(look.layers)
                elif look.variants.has(variant):index.equipment[key] = _legacy_layers(look.variants[variant])

## Dropped looks retain the original source cell and companion encoding. No
## environment height packet, atlas or inferred contact is baked from these.
static func _ground_equipment(state:Dictionary,entry:Resource)->void:
    var rig:Resource=state.rigs[state.index.root_rig]
    var variants:Dictionary={}
    state.index.ground_equipment[entry.id]={"family":entry.family,"variants":variants}
    for ordinal in entry.ground.size():
        var authored:Dictionary=entry.ground[ordinal]
        var where:String="gear/"+entry.id+"/ground/"+str(ordinal)
        var part:Resource=state.parts.get(authored.get("part",""))
        var clip:String=str(authored.get("clip",""))
        if part==null or not part.actions.has(clip):Common.error(state.report,where,"ground part/action is not authored");continue
        var art:Resource=part.actions[clip]
        var slot:String=""
        for candidate in rig.slot_order:
            if part.id in rig.slot_categories.get(candidate,[]):slot=candidate;break
        if slot.is_empty():Common.error(state.report,where,"ground part is not in the actual source rig");continue
        if float(authored.get("rotation",0.))!=0.:
            Common.error(state.report,where,"ground optical registration does not author rotated source cells");continue
        # Ground rows retain JSON numeric floats; ArtSource.cell is Vector2i.
        # Compare the actual dimensions, not strict Array element variants.
        var cell:Array=authored.get("cell",[])
        if cell.size()!=2 or float(cell[0])!=float(art.cell.x) or float(cell[1])!=float(art.cell.y) or authored.get("rows_by_camera",[]).size()!=4 or authored.get("pivots_by_camera",[]).size()!=4 or float(authored.get("scale",0.))<=0.:
            Common.error(state.report,where,"ground cell/camera registration is incomplete");continue
        var path:String=_res(art.path);var size:Dictionary=_header(state,path)
        var valid:bool=not size.has("error") and int(authored.get("frame",-1))>=0 and int(authored.get("frame",-1))<art.frames
        for row in authored.rows_by_camera:
            valid=valid and int(row)>=0 and (int(row)+1)*art.cell.y<=int(size.get("height",0))
        if not valid:Common.error(state.report,where,"ground frame/row is outside its unchanged source sheet");continue
        var variant:String=str(authored.get("variant",""))
        if variants.has(variant):Common.error(state.report,where,"duplicate ground variant");continue
        var value:Dictionary=_plain(authored)
        value.merge({"path":path,"slot":slot,"source_pivot":[art.pivot.x,art.pivot.y],
            "source":entry.resource_path+"::ground/"+str(ordinal),"status":entry.status})
        var shadow:Resource=state.parts.get(authored.get("shadow_part",""))
        if shadow!=null and shadow.actions.has(clip) and float(authored.get("shadow_scale",0.))>0.:
            var shadow_art:Resource=shadow.actions[clip]
            value.shadow={"path":_res(shadow_art.path),"cell":[shadow_art.cell.x,shadow_art.cell.y],
                "pivot":[shadow_art.pivot.x,shadow_art.pivot.y],"scale":float(authored.shadow_scale)}
        variants[variant]=value

static func _appearance(state: Dictionary, entry: Resource) -> void:
    if entry == null:Common.error(state.report, "characters", "appearance/modular missing");return
    if Array(entry.effect_slots) != EFFECT_SLOTS:Common.error(state.report, "appearance/modular", "effect slots differ from the runtime's")
    state.index.appearance = {"category_slots": entry.category_slots.duplicate(), "flag_parts": entry.flag_parts.duplicate(), "tint_slots": entry.tint_slots.duplicate(),
        "equipment_slots": entry.equipment_slots.duplicate(), "weapon_sets": entry.weapon_sets.duplicate()}

## Measured palette ranges by runtime sheet path and cell height.
static func _palette_ranges(state: Dictionary) -> void:
    var measured: Dictionary = _measured(state, "measured/characters/palette_ranges.json")
    for path in measured.get("sheets", {}):
        var by_height := {}
        for height in measured.sheets[path]:
            var ranges := {}
            for facing in measured.sheets[path][height]:
                var value: Array = measured.sheets[path][height][facing]
                ranges[facing] = Vector2(value[0], value[1])
            by_height[height] = ranges
        state.index.palette_ranges[_res(path)] = by_height

# ---------------------------------------------------------------- icons and portraits

static func _image(image: Resource) -> Dictionary:
    var value := {"path": _res(image.path), "native_size": [image.native_size.x, image.native_size.y]}
    if image.rect.has_area():value.rect = [image.rect.position.x, image.rect.position.y, image.rect.size.x, image.rect.size.y]
    return value

## build/presentation/characters/icons.json: the HUD's icon map for this
## domain (items by server item id, common controls as common.<id>), the
## portrait banks by portrait id, and each creature's portrait.
static func _icons(state: Dictionary, entries: Dictionary, out_dir: String) -> void:
    var icons := {}
    for id in entries.get("gear", {}):
        var gear: Resource = entries.gear[id]
        if gear.icon != null and gear.icon.status != "missing":icons[id] = _image(gear.icon)
    for icon_set in entries.get("ui", {}).values():
        for id in icon_set.icons:
            if icon_set.icons[id].status != "missing":icons["common." + id] = _image(icon_set.icons[id])
    var portraits := {}
    var aliases := {}
    for bank in entries.get("portraits", {}).values():
        for id in bank.portraits:portraits[id] = _image(bank.portraits[id])
        for id in bank.aliases:aliases[id] = bank.aliases[id]
    for id in aliases:
        if portraits.has(aliases[id]):portraits[id] = portraits[aliases[id]]
        else:Common.error(state.report, "portraits", "alias " + id + " names a missing portrait")
    var creatures := {}
    for id in entries.get("characters", {}):
        var entry: Resource = entries.characters[id]
        if entry.portrait.is_empty():continue
        if not portraits.has(entry.portrait):Common.error(state.report, "characters/" + id, "portrait missing: " + entry.portrait);continue
        creatures[id] = entry.portrait
    for value in icons.values() + portraits.values():
        if not FileAccess.file_exists(value.path):Common.error(state.report, "characters", "image missing: " + value.path)
    var file := FileAccess.open(out_dir.path_join("icons.json"), FileAccess.WRITE)
    file.store_string(JSON.stringify({"schema": "presentation-icons/1", "domain": "characters", "icons": icons, "portraits": portraits, "creature_portraits": creatures}, " ", true))
