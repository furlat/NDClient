extends SceneTree
## Re-runnable converter for the characters presentation source. Writes
## authoring/characters.tres and one entry per rig, character, part, gear item,
## portrait bank and icon set under authoring/characters/, plus the measured
## data (sockets, ground lines, surface-socket samples, palette ranges) under
## assets/measured/characters/. Inputs: today's client data (rigs, creature
## bindings, sheet components, geometry tables, items, UI) for the values the
## game uses now, which convert exactly; the full deliveries under assets/art
## and authoring/server_ids.json for everything else.
##   --headless --script res://tools/presentation_build/convert_characters.gd
const Root = preload("res://presentation/source/source_root.gd")
const ArtSource = preload("res://presentation/source/art_source.gd")
const ImageRef = preload("res://presentation/source/image_ref.gd")
const Palette = preload("res://presentation/source/palette.gd")
const BodySurface = preload("res://presentation/source/characters/body_surface.gd")
const Rig = preload("res://presentation/source/characters/rig.gd")
const RigClip = preload("res://presentation/source/characters/rig_clip.gd")
const RigContext = preload("res://presentation/source/characters/rig_context.gd")
const Character = preload("res://presentation/source/characters/character.gd")
const Part = preload("res://presentation/source/characters/part.gd")
const Gear = preload("res://presentation/source/characters/gear.gd")
const Appearance = preload("res://presentation/source/characters/appearance.gd")
const PortraitBank = preload("res://presentation/source/characters/portraits.gd")
const IconSet = preload("res://presentation/source/characters/icons.gd")
const SheetTable = preload("res://presentation/source/characters/sheet_table.gd")
const Roster = preload("res://tools/presentation_build/characters_roster.gd")
const AUTHORING := "res://authoring/"
const OUT := "res://authoring/characters/"
const MEASURED := "res://assets/measured/characters/"
const ART := "res://assets/"
const FACINGS := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
const PLAYER_BODY := "creature.player.humanoid_body"
## Visual loadout slots the body draws (server slot names map to these).
const GEAR_SLOTS := ["weapon_melee_main", "weapon_melee_off", "weapon_ranged_main", "weapon_ranged_off", "helmet", "body_armor", "gauntlets", "boots", "cloak", "backpack"]
## Old absolute delivery roots (project.godot [source_data]) -> their copies in assets/art.
var modular_root: String = ""
var profile_root: String = ""
var creature_root: String = ""
var media_root: String = ""
var rigs_json: Dictionary = {}
var resources: Dictionary = {}
var components: Dictionary = {}
var modular_geometry: Dictionary = {}
var creature_geometry: Dictionary = {}
var normal_profiles: Dictionary = {}
var server: Dictionary = {}
var source_root := Root.new()
var errors: Array = []
var notes: Array = []
var written: Dictionary = {}

func _initialize() -> void:
    run.call_deferred()

func read(path: String) -> Variant:
    return JSON.parse_string(FileAccess.get_file_as_string(path))

func fail(message: String) -> void:
    errors.append(message)

## /media/X -> art/media/X; absolute delivery paths -> their copy under art/geometry.
func art(path: String) -> String:
    if path.is_empty():return ""
    if path.begins_with("/media/"):return "art/media/" + path.trim_prefix("/media/")
    for pair in [[modular_root + "/exports/fused/maps/", "art/geometry/modular/"], [profile_root + "/", "art/geometry/modular-profiles/"],
            [creature_root + "/delivery/actions/", "art/geometry/creatures/first/actions/"], [creature_root + "/animals/delivery/actions/", "art/geometry/creatures/animals/actions/"],
            [creature_root + "/full-library/delivery/actions/", "art/geometry/creatures/library/actions/"]]:
        if path.begins_with(pair[0]):return pair[1] + path.trim_prefix(pair[0])
    fail("No assets/art copy for " + path)
    return ""

func exists(relative: String) -> bool:
    return not relative.is_empty() and FileAccess.file_exists(ART + relative)

func png_size(relative: String) -> Vector2i:
    var file := FileAccess.open(ART + relative, FileAccess.READ)
    if file == null:return Vector2i.ZERO
    var bytes := file.get_buffer(24)
    if bytes.size() != 24:return Vector2i.ZERO
    return Vector2i((bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19], (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23])

func hex(value: Variant) -> String:
    return "#%06x" % int(value)

func save(resource: Resource, section: String, id: String, folder: String) -> void:
    var path: String = OUT + folder + "/" + id + ".tres"
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    if ResourceSaver.save(resource, path) != OK:fail("Cannot save " + path);return
    if not source_root.sections.has(section):source_root.sections[section] = {}
    source_root.sections[section][id] = path
    written[path] = true

func save_measured(relative: String, value: Variant) -> void:
    var path: String = MEASURED + relative
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:fail("Cannot write " + path);return
    file.store_string(JSON.stringify(value, "", true, true))

func run() -> void:
    var started := Time.get_ticks_msec()
    modular_root = str(ProjectSettings.get_setting("source_data/character_geometry_root", ""))
    profile_root = str(ProjectSettings.get_setting("source_data/normal_profiles_root", ""))
    creature_root = str(ProjectSettings.get_setting("source_data/creature_geometry_root", ""))
    media_root = str(ProjectSettings.get_setting("source_data/media_root", ""))
    var index: Dictionary = read(AUTHORING + "catalog-index.json")
    rigs_json = read(AUTHORING + index.rigs)
    resources = read(AUTHORING + index.resources)
    components = read(AUTHORING + index.sheet_components)
    modular_geometry = read("res://generated/character_geometry.json")
    creature_geometry = read("res://generated/creature_geometry.json")
    normal_profiles = read("res://generated/normal_profiles.json")
    server = read(AUTHORING + "server_ids.json")
    _overlay_clips()
    source_root.domain = "characters"
    var parts: Dictionary = _parts()
    var rigs: Dictionary = _current_rigs(parts)
    var library: Dictionary = _library_rigs(rigs)
    _characters(rigs, library)
    _gear()
    _appearance()
    _portraits()
    _icons()
    _external_sheets()
    _palette_ranges(parts)
    for section in source_root.sections:
        var sorted := {}
        var keys: Array = source_root.sections[section].keys();keys.sort()
        for key in keys:sorted[key] = source_root.sections[section][key]
        source_root.sections[section] = sorted
    if ResourceSaver.save(source_root, "res://authoring/characters.tres") != OK:fail("Cannot save the root")
    _remove_stale()
    var counts := {}
    for section in source_root.sections:counts[section] = source_root.sections[section].size()
    print("CHARACTERS_CONVERT ", JSON.stringify({"counts": counts, "errors": errors.size(), "notes": notes.size(), "ms": Time.get_ticks_msec() - started}))
    for line in errors.slice(0, 60):print("CONVERT_ERROR ", line)
    for line in notes.slice(0, 20):print("CONVERT_NOTE ", line)
    quit(0 if errors.is_empty() else 1)

## Entry files from an earlier run that this run no longer writes.
func _remove_stale() -> void:
    for folder in ["rigs", "characters", "parts", "gear", "appearance", "portraits", "ui", "sheets"]:
        var dir := DirAccess.open(OUT + folder)
        if dir == null:continue
        for file in dir.get_files():
            var path: String = OUT + folder + "/" + file
            if file.ends_with(".tres") and not written.has(path):DirAccess.remove_absolute(path)

## The layered rig's crouch clips are registered by presentation/clips/*.tres.
func _overlay_clips() -> void:
    var catalog: Resource = load(AUTHORING + "presentation/catalog.tres")
    for path in catalog.body_clips:
        var clip: Resource = load(path)
        var rig: Dictionary = rigs_json[clip.rig_id]
        var sheets := {}
        for category in clip.sheets:sheets[category] = clip.sheets[category]
        rig.clips[clip.clip] = {"source_clip": clip.source_clip, "frames": clip.frame_count, "fps": clip.fps, "loop": clip.loop, "sheets": sheets, "_overlay": path}

# ---------------------------------------------------------------- parts

func _parts() -> Dictionary:
    var modular: Dictionary = rigs_json[str(read(AUTHORING + "catalog/root_rig.json"))]
    var slots := {}
    for slot in modular.slot_order:
        for category in modular.slot_categories[slot]:
            if not slots.has(category):slots[category] = []
            slots[category].append(slot)
    var palettes := {}
    for entry in read(AUTHORING + "materials/source-palettes.json").entries:palettes[entry.category] = entry
    var socket_root := "res://.derived/surface-sockets/"
    var parts := {}
    var by_category := {}
    for media in modular_geometry.records:
        var record: Dictionary = modular_geometry.records[media]
        if not by_category.has(record.category):by_category[record.category] = {}
        by_category[record.category][record.source_action] = media
    var camera: Dictionary = modular_geometry.optical_camera
    var categories: Array = by_category.keys();categories.sort_custom(func(a, b): return a.naturalnocasecmp_to(b) < 0)
    for category in categories:
        var part := Part.new()
        part.id = category
        var family: String = category
        while not family.is_empty() and family[-1] in "0123456789":family = family.left(-1)
        part.family = family
        part.slots = PackedStringArray(slots.get(category, []))
        var samples := {}
        var actions: Array = by_category[category].keys();actions.sort_custom(func(a, b): return a.naturalnocasecmp_to(b) < 0)
        var statuses := {}
        for action in actions:
            var media: String = by_category[category][action]
            var record: Dictionary = modular_geometry.records[media]
            var source := ArtSource.new()
            source.path = art(media)
            if not exists(source.path):fail("Part sheet missing: " + source.path)
            var size := png_size(source.path)
            source.cell = Vector2i(128, 128)
            source.frames = size.x / 128
            source.direction_order = PackedStringArray(FACINGS)
            source.pivot = Vector2(64, 87)
            source.anchor = Vector2(64, 60)
            source.camera_elevation_degrees = 45.0
            source.source = "smallscale-modular/fantasy-v1.3"
            var surface := BodySurface.new()
            surface.status = record.status
            surface.source = "modular-character-geometry-2026-10-11"
            statuses[record.status] = true
            if record.has("files"):
                surface.encoding = "normal_rgb_depth_byte"
                surface.depth = art(modular_root + "/" + record.files.depth)
                surface.normals = {"original": art(modular_root + "/" + record.files.normal)}
                var profiles: Dictionary = normal_profiles.records.get(media, {})
                for profile in ["gentle", "reference"]:
                    if profiles.has(profile):surface.normals[profile] = art(profile_root + "/" + profiles[profile])
                var folder: String = surface.depth.get_base_dir()
                surface.masks = {"support": art(modular_root + "/" + record.files.support), "normal_valid": art(modular_root + "/" + record.files.normal_valid),
                    "solid": folder + "/solid-valid.png", "lighting_valid": folder + "/lighting-valid.png"}
                surface.depth_range = Vector2(record.depth_range[0], record.depth_range[1])
                surface.depth_limits = PackedFloat64Array(record.depth_range)
                surface.camera_origin = Vector2(camera.origin[0], camera.origin[1])
                surface.qualification = "source"
                for path in [surface.depth] + surface.normals.values() + surface.masks.values():
                    if not exists(path):fail("Part surface file missing: " + path)
                if PackedStringArray(record.slots) != part.slots:fail("Part slots differ from the geometry record: " + media)
                var socket_file: String = socket_root + media.trim_prefix("/media/").get_basename() + ".json"
                if FileAccess.file_exists(socket_file):
                    var baked: Dictionary = read(socket_file)
                    var pixels := PackedInt32Array()
                    var values := PackedInt32Array()
                    for key in baked.samples:
                        pixels.append(int(key.get_slice(",", 0)));pixels.append(int(key.get_slice(",", 1)))
                        for value in baked.samples[key]:values.append(int(value))
                    samples[action] = {"size": [int(baked.size[0]), int(baked.size[1])], "pixels": Array(pixels), "values": Array(values)}
            else:
                surface.encoding = "none"
                surface.coverage = 0.0
            source.surface = surface
            source.status = "ready" if record.has("files") else ("missing" if record.status == "empty_source_no_surface" else "ready")
            part.actions[action] = source
        if palettes.has(category):
            var palette := Palette.new()
            palette.id = "source." + category
            var colours: Array = palettes[category].colors
            for i in colours.size():palette.roles[["primary", "secondary", "tertiary"][i] if i < 3 else "colour_%d" % i] = Color.hex(int(colours[i]) << 8 | 0xff)
            part.palette = palette
            for gray in palettes[category].isGray:part.palette_gray.append(bool(gray))
        if not samples.is_empty():
            part.measurements = "measured/characters/parts/" + category + ".json"
            save_measured("parts/" + category + ".json", {"schema": "surface-socket-samples/1", "part": category,
                "layout": "per action: socket pixels [x, y, ...] and their depth, depth alpha, support, solid bytes [d, a, s, o, ...]", "actions": samples})
        part.status = "ready" if statuses.has("validated_partial") or statuses.has("validated_complete") else "partial"
        if statuses.has("excluded_non_solid"):part.notes = "Effect or shadow layer: drawn flat, no depth or normals by design."
        elif statuses.has("empty_source_no_surface"):part.notes = "Only the ride actions have pixels; the other sheets are blank."
        if part.slots.is_empty():part.notes += ("\n" if part.notes else "") + "No rig slot accepts this part."
        parts[category] = part
        save(part, "parts", category, "parts")
    return parts

# ---------------------------------------------------------------- rigs (today)

## Shared role vocabulary from a clip or source animation name.
static func role_of(name: String) -> String:
    var key := name.to_lower().replace(" ", "").replace("_", "").replace("(", "").replace(")", "")
    var table := {"idle": "idle", "idle1": "idle", "idle2": "idle_alt", "walk": "walk", "run": "run", "runbackwards": "run_back", "backwardsrun": "run_back",
        "strafebackwards3": "run_back", "strafeleft": "strafe_left", "straferight": "strafe_right", "crouch": "crouch_idle", "crouchidle": "crouch_idle",
        "crouchwalk": "crouch_move", "crouchrun": "crouch_move", "roll1": "roll", "rolling": "roll", "backflip1": "flip", "backflip": "flip", "frontflip": "flip",
        "slide": "slide", "slide1": "slide", "quickslide": "slide", "slidestart": "slide_start", "slideend": "slide_end", "jump": "jump", "fly": "fly",
        "180turn": "turn", "runattack": "attack_run", "attackrun": "attack_run", "attackrun1": "attack_run", "attackrun2": "attack_run_2", "meleerun": "attack_run",
        "quickshot": "shoot", "castspell": "cast", "kick": "kick", "pummel": "pummel", "melee": "attack_1", "melee2": "attack_2", "meleespin": "attack_3",
        "block": "block_hold", "blockstart": "block_start", "blockmid": "block_hold", "shieldblockstart": "block_start", "shieldblockmid": "block_hold",
        "takedamage": "hurt", "takedamage1": "hurt", "die": "die", "die1": "die", "die2": "die_alt", "death": "die_alt", "diegore": "die_gore", "explode": "explode",
        "explodecopy": "explode", "emerge": "emerge", "wakeup": "wake_up", "standup1": "stand_up", "standup2": "stand_up_2", "zombiestand1": "stand_up",
        "zombiestand2": "stand_up_2", "crawl": "crawl", "bite": "bite", "zombiebite1": "bite", "zombiebite2": "bite_2", "crouchbite": "bite_crouch",
        "zombiemelee1": "attack_1", "meleeuppercut": "attack_2", "zombiescream1": "taunt", "taunt": "taunt", "eat": "eat", "eating": "eat", "sittingchair": "sit",
        "unsheath": "unsheath", "unsheathsword": "unsheath", "special1": "special_1", "special2": "special_2", "point": "point",
        "physicalgesture": "gesture", "rideidle": "ride_idle", "riderun": "ride_run", "rideidleattack1": "ride_attack", "riderunattack1": "ride_attack_run"}
    if table.has(key):return table[key]
    var regex := RegEx.create_from_string("^(attack|idle)(\\d+)$")
    var found := regex.search(key)
    if found != null:return found.get_string(1) + "_" + found.get_string(2)
    return key

func _clip_role_from(clip_name: String, source_clip: String) -> String:
    var by_name := role_of(clip_name)
    return by_name if by_name != clip_name.to_lower() else role_of(source_clip)

func _surface_from_record(record: Dictionary) -> BodySurface:
    var surface := BodySurface.new()
    surface.encoding = "normal_rgb_depth_byte"
    surface.status = record.status
    surface.source = "authored-creature-geometry-2026-10-12"
    surface.depth = art(creature_root + "/" + record.files.depth)
    surface.normals = {}
    for profile in ["original", "gentle", "reference"]:surface.normals[profile] = art(creature_root + "/" + record.normal_profiles[profile])
    surface.masks = {"support": art(creature_root + "/" + record.files.support), "normal_valid": art(creature_root + "/" + record.files.normal_valid)}
    surface.depth_range = Vector2(record.depth_range[0], record.depth_range[1])
    surface.depth_limits = PackedFloat64Array(record.depth_range)
    surface.depth_byte_range = Vector2i(record.depth_byte_range[0], record.depth_byte_range[1])
    surface.camera_origin = Vector2(record.optical_camera.origin[0], record.optical_camera.origin[1])
    if record.get("optical_ground_pixels") != null:surface.optical_ground_pixels = record.optical_ground_pixels
    surface.coverage = record.get("source_coverage", 1.0)
    surface.flags = PackedStringArray(record.get("qualification", {}).get("flags", []))
    surface.qualification = "source"
    for path in [surface.depth] + surface.normals.values() + surface.masks.values():
        if not exists(path):fail("Creature surface file missing: " + path)
    return surface

## The pack, layer folder and variant a delivered sheet path names.
static func sheet_origin(path: String) -> Dictionary:
    var parts := path.trim_prefix("art/media/smallscale/authored/").split("/")
    if parts.size() < 3:return {}
    var pack: String = parts[0]
    var variant: String = parts[parts.size() - 2]
    if variant in ["Shadows", "Effects"]:variant = parts[parts.size() - 3]
    return {"pack": pack, "variant": variant}

func _current_rigs(parts: Dictionary) -> Dictionary:
    var result := {}
    var root_rig := str(read(AUTHORING + "catalog/root_rig.json"))
    for rig_id in rigs_json:
        var source: Dictionary = rigs_json[rig_id]
        var rig := Rig.new()
        rig.id = rig_id
        rig.kind = "layered" if rig_id == root_rig else "fixed"
        rig.cell = Vector2i(int(source.cell_width), int(source.cell_height))
        rig.pivot = Vector2(source.cell_width * 0.5, source.cell_height - source.origin_y_from_ground)
        if source.has("body_anchor"):rig.anchor = Vector2(source.body_anchor.x, source.body_anchor.y)
        var order := []
        for facing in source.facing_rows:order.append([int(source.facing_rows[facing]), facing])
        order.sort()
        rig.direction_order = PackedStringArray(order.map(func(row): return row[1]))
        rig.slot_order = PackedStringArray(source.slot_order)
        for slot in source.slot_categories:rig.slot_categories[slot] = PackedStringArray(source.slot_categories[slot])
        rig.excluded_categories = PackedStringArray(source.get("selection_excluded_categories", []))
        if source.has("shadow_alpha"):rig.shadow_alpha = source.shadow_alpha
        if source.has("lifecycle_scale"):rig.lifecycle_scale = source.lifecycle_scale
        rig.native_wings = bool(source.get("native_wings", false))
        rig.hold_clips = PackedStringArray(source.get("rest_pose_anchors", {}).keys())
        var category_slot := {}
        for slot in source.slot_order:
            for category in source.slot_categories[slot]:category_slot[category] = slot
        var measured := {"schema": "rig-measurements/1", "rig": rig_id, "rest_pose_anchors": source.get("rest_pose_anchors", {})}
        if source.has("pose_sockets"):measured.pose_sockets = source.pose_sockets
        var clip_sockets := {}
        var all_ground := true
        var origin := {}
        for clip_name in source.clips:
            var clip_source: Dictionary = source.clips[clip_name]
            var clip := RigClip.new()
            clip.name = clip_name
            clip.source_clip = clip_source.source_clip
            clip.role = _clip_role_from(clip_name, clip.source_clip)
            clip.frames = int(clip_source.frames)
            clip.fps = clip_source.fps
            if clip_source.has("loop"):clip.loop = "loop" if clip_source.loop else "once"
            for anchor in clip_source.get("anchors", []):clip.markers[anchor.name] = int(anchor.frame)
            clip.owns_cast_preparation = bool(clip_source.get("owns_cast_preparation", false))
            if clip_source.has("source_sockets"):clip_sockets[clip_name] = clip_source.source_sockets
            if clip_source.has("description"):clip.notes = _describe(clip_source.description)
            for layer in clip_source.get("layers", []):
                if category_slot.get(layer.category) != layer.slot:fail("Clip layer slot differs from its category's slot: " + rig_id + "/" + clip_name)
                clip.effect_layers[layer.category] = bool(layer.enabled)
            if rig.kind == "layered":
                var authored := {}
                for category in clip_source.sheets:
                    authored[category] = "/spritesheets/" + category + "/" + clip.source_clip + ".png"
                    if parts.has(category) and parts[category].notes.begins_with("Effect or shadow"):clip.effect_parts.append(category)
                var derived := _part_sheets(source, parts, clip.source_clip, clip.effect_parts)
                if clip_source.has("_overlay"):
                    for category in clip_source.sheets:
                        if clip_source.sheets[category] != "/media/smallscale/modular/" + category + "/" + clip.source_clip + ".png":fail("Overlay clip sheet outside its part: " + category)
                elif authored != _key_map(clip_source.sheets):fail("Layered clip sheet keys are not part sheets: " + clip_name)
                var same: bool = derived.size() == authored.size()
                for category in authored:same = same and derived.has(category)
                if not same:
                    for category in authored:clip.sheets[category] = authored[category]
                    notes.append("Layered clip " + clip_name + " lists its own sheets")
            else:
                for category in clip_source.sheets:
                    var key: String = clip_source.sheets[category]
                    clip.sheets[category] = key
                    if key.begins_with("/spritesheets/"):continue
                    var slot: String = category_slot.get(category, "")
                    var raw: String = resources.get(key, "")
                    if raw.is_empty():fail("Sheet key without a resource: " + key);continue
                    if slot == "body":
                        clip.art.combined = art(raw)
                        var shown: String = components.get(raw, {}).get("source_layers", {}).get("body", raw)
                        var record: Dictionary = creature_geometry.records.get(shown, {})
                        clip.art.body = art(creature_root + "/" + record.colour_path) if record.has("colour_path") else art(shown)
                        if not record.is_empty():
                            clip.surface = _surface_from_record(record)
                            if record.get("optical_ground_pixels") == null:all_ground = false
                        else:all_ground = false
                        if origin.is_empty():origin = sheet_origin(art(raw))
                    elif slot == "shadow":clip.art.shadow = art(raw)
                    elif slot == "effect":clip.art.effect = art(raw)
                    else:fail("Own sheet in an unexpected slot: " + rig_id + "/" + category)
                    var mask: Dictionary = components.get(raw, {}).get("accent_material_mask", {}).get("mask", {})
                    if slot == "body" and mask.has("path"):clip.art.mask_material = art(mask.path)
                for value in clip.art.values():
                    if not exists(value):fail("Rig art missing: " + value)
            rig.clips.append(clip)
        if not clip_sockets.is_empty():measured.clip_sockets = clip_sockets
        for context in source.get("body_contexts", []):rig.contexts.append(_context(context))
        if rig.kind == "layered":
            rig.shadow = "generated"
            rig.ground_pixels = 19.0
            rig.source = "smallscale-modular/fantasy-v1.3"
            rig.pack = "modular"
            rig.notes = "Modular characters: parts per slot. The 19 px optical ground line is the client's standing assumption (the modular packets carry none)."
        else:
            rig.shadow = "generated" if all_ground else ("separate" if source.slot_order.has("shadow") else "baked")
            rig.pack = origin.get("pack", "")
            rig.variant = origin.get("variant", "")
            rig.source = "smallscale-authored/" + rig.pack
        rig.measurements = "measured/characters/rigs/" + rig_id + ".json"
        save_measured("rigs/" + rig_id + ".json", measured)
        rig.status = "ready"
        if rig.shadow == "baked":
            rig.status = "partial"
            rig.notes = "Shadow is baked into the delivered sheet and no geometry is loaded for this rig."
        result[rig_id] = rig
    return result

func _key_map(sheets: Dictionary) -> Dictionary:
    var result := {}
    for category in sheets:result[category] = sheets[category]
    return result

## Parts of the layered rig that have a sheet for this source action: every
## solid part, and the effect parts the clip names.
static func _part_sheets(rig: Dictionary, parts: Dictionary, action: String, effects: PackedStringArray) -> Dictionary:
    var result := {}
    var seen := {}
    for slot in rig.slot_order:
        for category in rig.slot_categories[slot]:
            if seen.has(category):continue
            seen[category] = true
            if not parts.has(category) or not parts[category].actions.has(action):continue
            if parts[category].notes.begins_with("Effect or shadow") and not effects.has(category):continue
            result[category] = true
    return result

func _describe(description: Variant) -> String:
    if description is String:return description
    var lines := []
    if description.has("body"):lines.append(str(description.body))
    for layer in description.get("layers", {}):lines.append(layer + ": " + str(description.layers[layer]))
    return "\n".join(lines)

func _context(source: Dictionary) -> RigContext:
    var context := RigContext.new()
    context.role = source.role
    context.qualifier = source.qualifier.duplicate(true)
    var body: Dictionary = source.body
    var actor: Dictionary = body.actor
    context.clip = actor.clip
    context.enabled = actor.enabled
    context.playback_speed = actor.playbackSpeed
    context.hidden_slots = PackedStringArray(actor.hiddenSlots)
    context.media = actor.media.duplicate(true)
    for key in body:
        if not key in ["actor", "playback", "frameKeys", "anchors", "restFrame", "reversed"]:fail("Unknown body context field " + key)
    context.playback = body.get("playback", "")
    context.frame_keys = body.get("frameKeys", []).duplicate(true)
    context.anchors = body.get("anchors", []).duplicate(true)
    context.reversed = body.get("reversed", false)
    context.rest_frame = int(body.get("restFrame", -1))
    return context

# ---------------------------------------------------------------- rigs (deliveries)

## Every authored variant that has no rig yet, from the geometry catalogs
## (which index every delivered body sheet) and the pack folders.
func _library_rigs(current: Dictionary) -> Dictionary:
    var covered := {}
    for rig in current.values():
        if rig.kind == "fixed":covered[rig.pack + "/" + rig.variant] = rig.id
    var catalogs := [["art/geometry/creatures/first/catalog-goblins-orcs.json", "first"], ["art/geometry/creatures/first/catalog-demons.json", "first"],
        ["art/geometry/creatures/library/catalog-people.json", "library"], ["art/geometry/creatures/library/catalog-zombies.json", "library"],
        ["art/geometry/creatures/library/catalog-animals.json", "library"]]
    var families := {}
    for pair in catalogs:
        var catalog: Dictionary = read(ART + pair[0])
        var base: String = pair[0].get_base_dir() + "/"
        var family_rows := {}
        for family in catalog.families:family_rows[family.family] = family
        for row in catalog.actions:
            var family: Dictionary = family_rows[row.family]
            var combined: String = row.layers.get("combined", {}).get("media", "")
            if combined.is_empty():fail("Catalog action without its delivered sheet: " + row.id);continue
            var origin := sheet_origin(art(combined))
            var key: String = origin.pack + "/" + origin.variant
            if covered.has(key):continue
            if not families.has(key):families[key] = {"pack": origin.pack, "variant": origin.variant, "family": row.family, "rows": [], "catalog": catalog, "base": base, "group": pair[1]}
            families[key].rows.append(row)
    var result := {}
    var keys: Array = families.keys();keys.sort_custom(func(a, b): return a.naturalnocasecmp_to(b) < 0)
    for key in keys:
        var rig := _delivery_rig(families[key])
        if rig == null:continue
        if current.has(rig.id) or result.has(rig.id):fail("Duplicate rig id from the deliveries: " + rig.id);continue
        result[rig.id] = rig
        save(rig, "rigs", rig.id, "rigs")
    for rig in current.values():save(rig, "rigs", rig.id, "rigs")
    return result

static func rig_id_for(pack: String, variant: String) -> String:
    var slug := variant.to_lower().strip_edges()
    if pack in ["orcs-and-goblins", "demons"]:
        var found := RegEx.create_from_string("^(.*?)\\s*(\\d+)$").search(slug)
        if found != null and not slug.begins_with("animal"):return "smallscale." + found.get_string(1).replace(" ", "") + "%02d" % int(found.get_string(2))
    return "smallscale." + pack + "." + slug.replace(" ", "-")

func _delivery_rig(family: Dictionary) -> Rig:
    var rows: Array = family.rows
    var pack: String = family.pack
    var rig := Rig.new()
    rig.id = rig_id_for(pack, family.variant)
    rig.kind = "fixed"
    rig.pack = pack
    rig.variant = family.variant
    rig.source = "smallscale-authored/" + pack
    var first: Dictionary = rows[0]
    var size: Array = first.size
    var frames: int = int(first.frames)
    var cell: Array = first.get("cell_size", [size[0] / frames, size[1] / 8])
    rig.cell = Vector2i(int(cell[0]), int(cell[1]))
    rig.direction_order = PackedStringArray(FACINGS)
    var stem: String = rig.id.trim_prefix("smallscale.").replace(".", "-").replace("-", "_")
    var body: String = stem.capitalize().replace(" ", "")
    var has_shadow := false
    var has_effect := false
    var names := {}
    rows.sort_custom(func(a, b): return str(a.source_action).naturalnocasecmp_to(str(b.source_action)) < 0)
    for row in rows:
        var clip := RigClip.new()
        clip.source_clip = row.source_action
        clip.role = role_of(clip.source_clip)
        clip.name = _library_clip_name(clip.source_clip, names)
        names[clip.name] = true
        clip.frames = int(row.frames)
        clip.fps = 12.0
        var layers: Dictionary = row.layers
        clip.art.combined = art(layers.combined.media)
        var base: String = family.base
        var colour: String = base + row.files["colour.png"].path if row.files.has("colour.png") else ""
        clip.art.body = art(layers.body.media) if layers.get("body", {}).get("media") != null and str(layers.body.media).begins_with("/media/") else colour
        if layers.has("shadow") and layers.shadow.get("media") != null:clip.art.shadow = art(layers.shadow.media);has_shadow = true
        if layers.has("accent") and layers.accent.get("media") != null:clip.art.effect = art(layers.accent.media);has_effect = true
        var mask: Dictionary = components.get(layers.combined.media, {})
        if mask.get("accent_material_mask", {}).get("mask", {}).has("path"):clip.art.mask_material = art(mask.accent_material_mask.mask.path)
        if mask.get("selection", {}).get("kind") == "mask":clip.art.mask_component = art(mask.selection.mask.path)
        for value in clip.art.values():
            if not exists(value):fail("Delivery art missing: " + value)
        clip.surface = _surface_from_catalog(row, family)
        clip.sheets[body] = "/rigs/" + stem + "/body/" + clip.source_clip + ".png"
        if clip.art.has("shadow"):clip.sheets[body + "Shadow"] = "/rigs/" + stem + "/shadow/" + clip.source_clip + ".png"
        if clip.art.has("effect"):clip.sheets[body + "Effect"] = "/rigs/" + stem + "/effect/" + clip.source_clip + ".png";clip.effect_layers[body + "Effect"] = false
        rig.clips.append(clip)
    rig.slot_order = PackedStringArray((["shadow"] if has_shadow else []) + ["body"] + (["effect"] if has_effect else []))
    rig.slot_categories["body"] = PackedStringArray([body])
    if has_shadow:rig.slot_categories["shadow"] = PackedStringArray([body + "Shadow"])
    if has_effect:rig.slot_categories["effect"] = PackedStringArray([body + "Effect"])
    rig.shadow = "generated"
    rig.hold_clips = PackedStringArray(rig.clips.filter(func(clip): return clip.role in ["die", "die_alt", "die_gore", "explode"]).map(func(clip): return clip.name))
    _place(rig, family)
    rig.status = "partial"
    rig.notes = "From the delivery: clip names, frames and art from the files; 12 fps is the client's clock (the delivery has none); pivot and body anchor measured from the Idle body (median opaque extent), not hand-placed."
    return rig

## Clip keys follow the client's own names (Attack1, TakeDamage, Die, Death ...).
func _library_clip_name(source: String, taken: Dictionary) -> String:
    var role := role_of(source)
    var table := {"idle": "Idle", "idle_alt": "Idle2", "walk": "Walk", "run": "Run", "run_back": "RunBackwards", "strafe_left": "StrafeLeft", "strafe_right": "StrafeRight",
        "crouch_idle": "Crouch", "crouch_move": "CrouchWalk", "roll": "Rolling", "flip": "BackFlip", "hurt": "TakeDamage", "die": "Die", "die_alt": "Death",
        "taunt": "Taunt", "block_hold": "Block", "block_start": "BlockStart", "cast": "CastSpell", "shoot": "QuickShot", "attack_run": "AttackRun", "attack_run_2": "AttackRun2"}
    var name: String = table.get(role, "")
    if name.is_empty():
        var found := RegEx.create_from_string("^attack_(\\d+)$").search(role)
        name = "Attack" + found.get_string(1) if found != null else source.replace(" ", "").replace("(", "").replace(")", "")
    while taken.has(name):name += "B"
    return name

func _surface_from_catalog(row: Dictionary, family: Dictionary) -> BodySurface:
    var surface := BodySurface.new()
    var base: String = family.base
    var files: Dictionary = row.files
    surface.encoding = "normal_rgb_depth_byte"
    surface.source = "authored-creature-geometry-2026-10-12"
    surface.depth = base + files["depth.png"].path
    surface.normals = {"original": base + files["normals.png"].path, "gentle": base + files["normals-gentle.png"].path, "reference": base + files["normals-reference.png"].path}
    surface.masks = {"support": base + files["raw-support.png"].path, "normal_valid": base + files["normal-valid.png"].path}
    var catalog: Dictionary = family.catalog
    var range: Array = row.get("depth_range", catalog.get("recipe", {}).get("common_depth_world_range", [0, 0]))
    surface.depth_range = Vector2(range[0], range[1])
    surface.depth_limits = PackedFloat64Array(range)
    var origin: Array = row.get("optical_origin", catalog.get("recipe", {}).get("origin_xy", [64, 96]))
    surface.camera_origin = Vector2(origin[0], origin[1])
    var counts: Dictionary = row.coverage.counts
    surface.status = "validated_partial" if counts.missing or counts.valid_pixels < counts.raw_pixels else "validated_complete"
    surface.coverage = row.coverage.source_coverage
    var flags := {}
    for item in row.coverage.get("flagged_frames", []):
        for flag in item.flags:flags[flag] = true
    surface.flags = PackedStringArray(flags.keys())
    surface.repeated_rows = bool(row.get("source_facing_rows_repeated", false))
    surface.qualification = "source"
    for path in [surface.depth] + surface.normals.values() + surface.masks.values():
        if not exists(path):fail("Delivery surface file missing: " + path)
    return surface

## Pivot and body anchor from the Idle body's opaque extent (median over every
## frame and facing): the foot line one pixel above the lowest opaque row, the
## anchor half way up. The optical ground line follows from the pivot.
func _place(rig: Rig, family: Dictionary) -> void:
    var idle: RigClip = null
    for clip in rig.clips:
        if clip.role == "idle":idle = clip;break
    if idle == null:idle = rig.clips[0]
    var image := Image.load_from_file(ProjectSettings.globalize_path(ART + idle.art.body))
    var tops := []
    var feet := []
    if image != null and not image.is_empty():
        for row in 8:
            for frame in idle.frames:
                var used := image.get_region(Rect2i(frame * rig.cell.x, row * rig.cell.y, rig.cell.x, rig.cell.y)).get_used_rect()
                if used.has_area():tops.append(used.position.y);feet.append(used.end.y - 1)
    if feet.is_empty():
        rig.pivot = Vector2(rig.cell.x * 0.5, rig.cell.y * 0.68)
        rig.anchor = Vector2(rig.cell.x * 0.5, rig.cell.y * 0.56)
        fail("No opaque Idle body to place " + rig.id)
        return
    tops.sort();feet.sort()
    var foot: float = feet[feet.size() / 2] - 1
    rig.pivot = Vector2(rig.cell.x * 0.5, foot)
    rig.anchor = Vector2(rig.cell.x * 0.5, roundf((tops[tops.size() / 2] + foot) * 0.5))
    for clip in rig.clips:
        if clip.surface != null:clip.surface.optical_ground_pixels = (clip.surface.camera_origin.y - rig.pivot.y) / cos(deg_to_rad(rig.camera_elevation_degrees))

# ---------------------------------------------------------------- characters

## The roster NPCs without a rig today stay unbound until they are wired (a
## separate change); their delivered variant is named in the entry's notes.
const BIND_ROSTER := false

static func content_id(identity: String) -> String:
    return identity.get_slice(":", 2).get_slice("@", 0)

func _characters(current: Dictionary, library: Dictionary) -> void:
    var bindings := {}
    var creature_rigs: Dictionary = read(AUTHORING + "catalog/creature_rigs.json")
    for identity in creature_rigs:bindings[content_id(identity)] = {"identity": identity, "rig": creature_rigs[identity]}
    var ui_resources: Dictionary = read(AUTHORING + "ui/resources.json")
    var attacks := {}
    var recipes: Dictionary = read(AUTHORING + "catalog/attack_recipes.json")
    for recipe_id in recipes:
        for variant in recipes[recipe_id].get("variants", []):
            for rig_id in variant.match.get("rigIds", []) if variant.match.get("rigIds") != null else []:
                if not attacks.has(rig_id):attacks[rig_id] = []
                var row := {"recipe": recipe_id, "variant": variant.id, "delivery": variant.match.get("delivery"), "clip": variant.get("actor", {}).get("clip", "")}
                for anchor in variant.get("anchors", []):
                    if anchor.name in ["contact", "release"]:row[anchor.name] = int(anchor.frame)
                if variant.match.get("sourceItemIds") != null:row.items = variant.match.sourceItemIds
                attacks[rig_id].append(row)
    var by_variant := {}
    for rig in current.values() + library.values():
        if rig.kind == "fixed":by_variant[rig.pack + "/" + rig.variant] = rig
    var ids: Dictionary = server.ids.creature.duplicate()
    ids[PLAYER_BODY] = {"name": "Player character", "size": "Medium", "ui_group": "player"}
    for id in ids:
        var entry := Character.new()
        entry.id = id
        entry.size = str(ids[id].get("size", ""))
        var roster: Array = Roster.NPCS.get(id, [])
        var delivered: Rig = by_variant.get(roster[0] + "/" + roster[1]) if not roster.is_empty() else null
        if not roster.is_empty() and delivered == null:fail("Roster variant without a rig: " + id)
        if id == PLAYER_BODY:entry.rig = "neuroclient.modular"
        elif bindings.has(id):
            entry.rig = bindings[id].rig
            entry.identity = bindings[id].identity
        elif BIND_ROSTER and delivered != null:entry.rig = delivered.id
        var rig: Rig = current.get(entry.rig, library.get(entry.rig))
        if not entry.rig.is_empty() and rig == null:fail("Character rig missing: " + id + " -> " + entry.rig)
        if ui_resources.has("portrait:" + id):entry.portrait = id
        elif id.begins_with("creature.configured_srd.") and ui_resources.has("portrait:creature." + id.trim_prefix("creature.configured_srd.")):
            entry.portrait = "creature." + id.trim_prefix("creature.configured_srd.")
        entry.kit_mismatch = Roster.MISMATCH.get(id, "") if not Roster.MISMATCH.get(id, "").begins_with("1") else ""
        if Roster.MISMATCH.get(id, "").contains(" px cells"):entry.size_note = Roster.MISMATCH[id];entry.kit_mismatch = ""
        if rig != null:
            for row in attacks.get(rig.id, []):entry.attacks.append(row)
            for context in rig.contexts:
                if context.role == "cast" and context.enabled:entry.cast = {"clip": context.clip}
                if context.role == "death" and context.qualifier.get("kind") == "default" and context.enabled and not entry.death.has("default"):entry.death["default"] = context.clip
            for clip in rig.clips:
                if clip.owns_cast_preparation and entry.cast.is_empty():entry.cast = {"clip": clip.name}
                if clip.role in ["block_hold", "block_start"] and not entry.reactions.has("block"):entry.reactions["block"] = clip.name
                if clip.role == "die" and not entry.death.has("default"):entry.death["default"] = clip.name
        if id == PLAYER_BODY:
            entry.status = "ready"
            entry.notes = "The player's own body: the layered rig dressed from the server's appearance and loadout; the portrait is the player's saved choice."
        elif rig == null:
            entry.status = "missing"
            entry.notes = "No rig: the game has no body for this creature."
            if delivered != null:entry.notes = "Delivered art: %s/%s (rig %s), not bound to this creature yet." % [roster[0], roster[1], delivered.id]
            elif ids[id].get("ui_group") == "creatures.spell_summon":entry.notes = "Spell summon: no delivered sheets."
        elif rig.kind == "layered":
            entry.status = "stand_in"
            entry.notes = "Drawn by the layered humanoid rig from the server's appearance; no creature art of its own."
        else:
            entry.status = "ready" if rig.status == "ready" else "partial"
            if rig.status != "ready":entry.notes = rig.notes
        if not roster.is_empty():entry.notes += ("\n" if entry.notes else "") + "Roster: %s, %s, kit %s." % [roster[2], roster[3], roster[4]]
        save(entry, "characters", id, "characters")

# ---------------------------------------------------------------- gear

static func layers_of(rows: Array) -> Array:
    var result := []
    for row in rows:result.append({"slot": row.render_layer, "part": row.sprite_key, "tint": "#%06x" % int(row.tint_rgb)})
    return result

func _gear() -> void:
    var visuals: Dictionary = read(AUTHORING + "items/visuals.json")
    var appearances: Dictionary = read(AUTHORING + "items/appearances.json")
    var ui: Dictionary = read(AUTHORING + "ui/presentation.json")
    var ui_resources: Dictionary = read(AUTHORING + "ui/resources.json")
    var roots := {}
    var bindings := {}
    var owners := {}
    var members := {}
    for category in visuals.categories:
        if not roots.has(category.base_category):roots[category.base_category] = category
        for binding in category.factory_presentation_bindings:
            var key := [binding.factory_identity, binding.equipment_slot]
            if not bindings.has(key):bindings[key] = []
            if category not in bindings[key]:bindings[key].append(category)
            if binding.root_presentation_owner and binding.factory_identity == category.mechanical_factory_identity:owners[content_id(binding.factory_identity)] = category.base_category
            if not members.has(content_id(binding.factory_identity)):members[content_id(binding.factory_identity)] = category.base_category
    var hands := {}
    for hand in appearances.hands:
        var key := [hand.category, hand.variant, hand.slot]
        if not hands.has(key):hands[key] = hand.layers
    var ground := {}
    for row in appearances.ground:
        if not ground.has(row.category):ground[row.category] = []
        ground[row.category].append(row)
    ## The family (root item id) of every visual name the server can send.
    var families := {}
    for family in owners:families[family] = owners[family]
    var presets := {}
    for category in visuals.categories:
        for variant in category.variants:
            if variant.get("preset_id") != null:presets[variant.preset_id] = [category.base_category, variant.visual_variant_id]
    var entries := {}
    for family in families:
        var name: String = families[family]
        var root: Dictionary = roots[name]
        var gear := Gear.new()
        gear.id = family
        for slot in GEAR_SLOTS:
            var matches: Array = bindings.get([root.mechanical_factory_identity, slot], [])
            if matches.size() == 1:
                var variants := {}
                for variant in matches[0].variants:variants[variant.visual_variant_id] = layers_of(variant.equipment_layers)
                gear.slots[slot] = {"layers": layers_of(matches[0].base_presentation.equipment_layers), "variants": variants}
                if matches[0] != root:gear.slots[slot].look = matches[0].base_category
            elif matches.size() > 1:notes.append("Gear %s/%s is bound to %d looks; it shows none" % [family, slot, matches.size()])
            for key in hands:
                if key[0] != name or key[2] != slot:continue
                if not gear.hands.has(slot):gear.hands[slot] = {}
                gear.hands[slot]["" if key[1] == null else key[1]] = layers_of(hands[key])
        for row in ground.get(name, []):
            gear.ground.append({"variant": "" if row.variant == null else row.variant, "part": row.sprite_key, "clip": row.clip, "frame": int(row.frame),
                "cell": row.get("cell", [128, 128]), "rows_by_camera": row.rows_by_camera, "pivots_by_camera": row.pivots_by_camera, "scale": row.scale,
                "rotation": row.get("rotation", 0), "tint": hex(row.tint), "shadow_part": row.get("shadow_sprite_key", ""), "shadow_scale": row.get("shadow_scale", 0.0)})
        gear.notes = "Visual name " + name + "; " + str(root.base_presentation.get("notes", "")).strip_edges()
        entries[family] = gear
    for id in server.ids.item:
        var gear: Gear = entries.get(id)
        if gear == null:
            gear = Gear.new()
            gear.id = id
            var family := ""
            var variant := ""
            if presets.has(id) and owners.values().has(presets[id][0]):
                family = owners.find_key(presets[id][0]);variant = presets[id][1]
            elif members.has(id):family = owners.find_key(members[id]) if owners.values().has(members[id]) else ""
            elif ".roster." in id:
                var found := _roster_family(id, entries)
                family = found[0];variant = found[1]
            gear.family = family
            gear.visual_variant_id = variant
            if family.is_empty():
                gear.natural = id.contains(".creature.") or id.begins_with("weapon.spell_summon.") or id.begins_with("spell_construction.") or id.begins_with("spell_payload.")
                gear.notes = "Natural or summoned: drawn by the creature's own body." if gear.natural else "No worn look authored."
        gear.kind = str(server.ids.item[id].get("kind", ""))
        var direct: Dictionary = ui.direct_items.get(id, {})
        var key: Variant = direct.get("presentation", {}).get("icon_key")
        if key != null and ui_resources.has("icon:" + str(key)):
            gear.icon = _image(ui_resources["icon:" + str(key)], "ui-icons-bg3-glyphs-2026-10-07")
            if direct.get("approximation") != null:
                gear.icon.reuses = str(key)
                gear.notes += ("\n" if gear.notes else "") + "Icon: " + str(direct.approximation)
        if id == "equipment.portable_torch":gear.lights = true
        var draws: bool = not gear.slots.is_empty() or not gear.hands.is_empty() or not gear.family.is_empty()
        if gear.natural:gear.status = "internal"
        elif draws and gear.icon != null:gear.status = "ready"
        elif draws or gear.icon != null:gear.status = "partial"
        else:gear.status = "missing"
        save(gear, "gear", id, "gear")
    for family in entries:
        if not server.ids.item.has(family):notes.append("Gear look without a server id: " + family)

## kind.roster.<base>_<variant> (or kind.roster.<quality>_<base>) -> [family, variant].
func _roster_family(id: String, families: Dictionary) -> Array:
    var kind := id.get_slice(".", 0)
    var rest := id.get_slice(".", 2)
    var words := rest.split("_")
    for cut in range(words.size(), 0, -1):
        var base := kind + "." + "_".join(words.slice(0, cut))
        if families.has(base):
            var suffix := "_".join(words.slice(cut))
            for slot in families[base].slots.values():
                if slot.variants.has(suffix):return [base, suffix]
                if slot.variants.has("roster." + suffix):return [base, "roster." + suffix]
            return [base, ""]
    for start in range(1, words.size()):
        var base := kind + "." + "_".join(words.slice(start))
        if families.has(base):return [base, ""]
    return ["", ""]

func _image(resource: Dictionary, source: String) -> ImageRef:
    var image := ImageRef.new()
    image.path = art(resource.path)
    if not exists(image.path):fail("Image missing: " + image.path)
    image.native_size = Vector2i(int(resource.native_size[0]), int(resource.native_size[1]))
    image.pivot = Vector2(resource.get("pivot", [0, 0])[0], resource.get("pivot", [0, 0])[1])
    if resource.has("rect"):image.rect = Rect2i(resource.rect[0], resource.rect[1], resource.rect[2], resource.rect[3])
    image.source = source
    return image

# ---------------------------------------------------------------- appearance, portraits, icons

func _appearance() -> void:
    var entry := Appearance.new()
    entry.category_slots = {"body_category": "body", "head_category": "head"}
    entry.flag_parts = {"has_beard": "Head2"}
    entry.tint_slots = {"skin_tint": "body", "hair_tint": "head", "beard_tint": "beard"}
    entry.equipment_slots = {"MELEE_MAIN": "weapon_melee_main", "MELEE_OFF": "weapon_melee_off", "RANGED_MAIN": "weapon_ranged_main", "RANGED_OFF": "weapon_ranged_off",
        "Head": "helmet", "Body": "body_armor", "Hands": "gauntlets", "Feet": "boots", "Cloak": "cloak", "Backpack": "backpack"}
    entry.weapon_sets = {"MELEE_MAIN": "melee", "MELEE_OFF": "melee", "RANGED_MAIN": "ranged", "RANGED_OFF": "ranged"}
    entry.effect_slots = PackedStringArray(["weaponGlow", "aura", "slash", "effect", "effect2", "effect3"])
    entry.rules = [{"rule": "helmet_hides_head", "except": ["Head5", "Head8"], "applies": false, "notes": "The old workshop hid the hair under any helmet but Head5 and Head8; play keeps both."}]
    entry.unused_fields = PackedStringArray(["placeholder_tint", "Amulet", "Rings", "Legs"])
    entry.notes = "presentation_kind must be layered for the layered rig. The equipment slots Amulet, Left/Right Ring and Legs draw nothing."
    save(entry, "appearance", "modular", "appearance")

func _portraits() -> void:
    var resources: Dictionary = read(AUTHORING + "ui/resources.json")
    var ui: Dictionary = read(AUTHORING + "ui/presentation.json")
    var player := PortraitBank.new()
    player.id = "player"
    player.source = "portraits-bg-study-2026-10-08"
    var creature := PortraitBank.new()
    creature.id = "creature"
    creature.source = "creature-portraits-bg1-2026-10-08"
    var sizes := {"classic_sheet": Vector2i(110, 170), "classic_sidebar": Vector2i(38, 60), "initiative": Vector2i(36, 48), "hud": Vector2i(48, 64),
        "sheet": Vector2i(96, 128), "preview": Vector2i(192, 256), "face_review": Vector2i(160, 160)}
    for bank in [player, creature]:
        for name in sizes:bank.named_sizes[name] = sizes[name]
    var heroes := {}
    for key in resources:
        if not key.begins_with("portrait:"):continue
        var id: String = key.trim_prefix("portrait:")
        var resource: Dictionary = resources[key]
        if id.begins_with("hero."):heroes[id] = resource;continue
        var bank: PortraitBank = creature if "creature-portraits" in str(resource.path) else player
        var image := _image(resource, bank.source)
        image.sizes["preview"] = image.path
        bank.portraits[id] = image
    for id in heroes:
        var target := ""
        for key in player.portraits:
            if art(heroes[id].path) == player.portraits[key].path:target = key;break
        if target.is_empty():fail("Hero portrait alias without its player portrait: " + id);continue
        player.aliases[id] = target
    for key in ui.portrait_choices:player.labels[key] = str(ui.portrait_choices[key].label)
    player.notes = "Player portraits (class, species group, sex, plus extras), chosen by the player and saved with the character. Only the 192x256 preview size is installed."
    creature.notes = "Creature portraits. Native ids (creature.*) are bound by the characters; source keys (pack--variant) are art not yet bound."
    save(player, "portraits", "player", "portraits")
    save(creature, "portraits", "creature", "portraits")

func _icons() -> void:
    var resources: Dictionary = read(AUTHORING + "ui/resources.json")
    var ui: Dictionary = read(AUTHORING + "ui/presentation.json")
    var icons := IconSet.new()
    icons.id = "common"
    icons.source = "ui-icons-bg3-glyphs-2026-10-07"
    for id in ui.common:
        icons.labels[id] = str(ui.common[id].label)
        var key: Variant = ui.common[id].get("presentation", {}).get("icon_key")
        if key == null or not resources.has("icon:" + str(key)):
            var missing := ImageRef.new()
            missing.status = "missing"
            icons.icons[id] = missing
            continue
        icons.icons[id] = _image(resources["icon:" + str(key)], icons.source)
    icons.notes = "HUD controls. common.unarmed has no icon of its own."
    save(icons, "ui", "common", "ui")

func _external_sheets() -> void:
    var table := SheetTable.new()
    table.id = "external"
    table.owner = "abilities"
    table.legacy_media_identity = true
    for key in resources:
        if key.begins_with("/spritesheets/") or key.begins_with("/rigs/"):continue
        var path: String = art(resources[key])
        if not exists(path):fail("External sheet missing: " + path)
        table.sheets[key] = path
    table.notes = "Spell and condition images (hand noise, films, markers) that cast layers name by sheet key. They keep their /media/ identity at run time until the abilities readers move to res://assets paths."
    save(table, "sheets", "external", "sheets")

# ---------------------------------------------------------------- palette ranges

## Luminance ranges for palette swaps, measured exactly as the runtime did
## (palette.gd): per facing row, 3rd and 98th percentile of opaque luminance.
func _palette_ranges(parts: Dictionary) -> void:
    var measured := {}
    var started := Time.get_ticks_msec()
    for part in parts.values():
        if part.notes.is_empty() or not part.notes.begins_with("Effect or shadow"):continue
        for action in part.actions:
            var path: String = part.actions[action].path
            var image := Image.load_from_file(ProjectSettings.globalize_path(ART + path))
            if image == null or image.is_empty():fail("Cannot measure " + path);continue
            image.convert(Image.FORMAT_RGBA8)
            var ranges := {}
            for row in FACINGS.size():
                var samples := PackedFloat32Array()
                var line := image.get_region(Rect2i(0, row * 128, image.get_width(), 128))
                var used := line.get_used_rect()
                if used.has_area():
                    var bytes: PackedByteArray = line.get_region(used).get_data()
                    for i in range(0, bytes.size(), 4):
                        if bytes[i + 3] > 128:samples.append(bytes[i] * .2126 + bytes[i + 1] * .7152 + bytes[i + 2] * .0722)
                samples.sort()
                var value := Vector2(_percentile(samples, .03), _percentile(samples, .98)) / 255.0
                ranges[FACINGS[row]] = [value.x, value.y]
            measured[path] = {"128": ranges}
    save_measured("palette_ranges.json", {"schema": "palette-ranges/1", "method": "per facing row: 3rd and 98th percentile of opaque (alpha > 128) Rec.709 luminance, / 255", "sheets": measured})
    print("PALETTE_RANGES ", measured.size(), " sheets in ", Time.get_ticks_msec() - started, " ms")

static func _percentile(values: PackedFloat32Array, fraction: float) -> float:
    if values.is_empty():return 0.0
    var at := (values.size() - 1) * fraction
    return lerpf(values[floori(at)], values[ceili(at)], at - floorf(at))
