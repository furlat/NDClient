extends SceneTree
## Converts today's environment data into the environment presentation source:
## authoring/environment.tres and one entry per id under authoring/environment/
## (terrain, structures, objects, library, surfaces, connectors, lighting,
## battlefields, art), with every server id of those kinds given an entry.
## The delivered registration (atlas rects, contacts, depth/normal packets,
## particle sets, old effect blocks) is copied into assets/measured/environment/
## with its number text unchanged, since Godot's writers shorten some doubles.
## Reads the legacy files read-only: world.json, assets.json, environment/,
## catalog/{devices,device_wrecks,portals,world_animations,action_media_assets}.json,
## generated/environment_{receiving_normals,texture_layouts}.json, the server id
## snapshot, the VFX package's surface scenarios and, when present, the
## fantasy-unified-catalog catalogue. Re-runnable: entries keep their files and
## uids; entries and measured files it no longer writes are removed.
##   --headless --script res://tools/presentation_build/convert_environment.gd [-- --catalogue=<catalog.json>]
const Spans = preload("res://tools/presentation_build/json_spans.gd")
const Root = preload("res://presentation/source/source_root.gd")
const ArtSource = preload("res://presentation/source/art_source.gd")
const Surface = preload("res://presentation/source/surface.gd")
const ImageRef = preload("res://presentation/source/image_ref.gd")
const SoundRef = preload("res://presentation/source/sound_ref.gd")
const EffectUse = preload("res://presentation/source/effect_use.gd")
const Art = preload("res://presentation/source/environment/art.gd")
const Terrain = preload("res://presentation/source/environment/terrain.gd")
const Slope = preload("res://presentation/source/environment/terrain_slope.gd")
const Structure = preload("res://presentation/source/environment/structure.gd")
const EnvironmentObject = preload("res://presentation/source/environment/object.gd")
const State = preload("res://presentation/source/environment/object_state.gd")
const Transition = preload("res://presentation/source/environment/object_transition.gd")
const Part = preload("res://presentation/source/environment/object_part.gd")
const Ground = preload("res://presentation/source/environment/ground_surface.gd")
const Operation = preload("res://presentation/source/environment/surface_operation.gd")
const Connector = preload("res://presentation/source/environment/connector.gd")
const LightAppearance = preload("res://presentation/source/environment/light_appearance.gd")
const Lighting = preload("res://presentation/source/environment/lighting.gd")
const Battlefield = preload("res://presentation/source/environment/battlefield.gd")

const LEGACY := "res://authoring/"
const OUT := "res://authoring/environment/"
const ROOT_PATH := "res://authoring/environment.tres"
const MEASURED := "res://assets/measured/environment/"
const MEASURED_REL := "measured/environment/"
const CATALOGUE := "C:/Users/tommaso/Documents/assets/fantasy-unified-catalog/catalog.json"
const SECTIONS := ["terrain", "structures", "objects", "library", "surfaces", "connectors", "lighting", "battlefields", "art"]
## Bank fields the art entry owns; the rest of a bank is delivered registration.
const BANK_FIELDS := ["cell", "rows", "scale", "fps", "frame_count", "path", "state_change_frame", "clear_at_end", "camera_quarter_by_pose"]
const MEDIA := "NDClientData/.media@2026-10-17"
const GEOMETRY := "environment-geometry-production-2026-10-09"
const QUALITY := "environment-normal-quality-2026-10-12"
const VIEWS := ["e", "n", "s", "w"]
const FACINGS := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
const STRUCTURES := ["cliff", "door", "embankment", "fence", "retaining_wall", "wall"]
## The rest pose of these chest banks shows the original vendor art (the
## reconstructed rest rays disagree on north/south); was ORIGINAL_CHEST_RESTS
## in source_catalog.gd.
const ORIGINAL_CHEST_RESTS := {
    "prop.chest-a1.intact": "fantasy.chest.a1", "prop.chest-a2.intact": "fantasy.chest.a2",
    "prop.chest-a3.intact": "fantasy.chest.a3", "prop.chest-a4.intact": "fantasy.chest.a4",
    "prop.chest-b1.intact": "fantasy.chest.b1", "prop.chest-b2.intact": "fantasy.chest.b2",
}
## Was lighting_2d.gd TORCH_COLOUR / TORCH_ITEM_IDS / DEFAULT_COOKIE and
## lighting.gd CARRIED/UNREGISTERED_OPTICAL_LIFT_STEPS.
const TORCH_COLOUR := Color(0.809372, 0.429306, 0.269121, 1.0)
const TORCH_ITEM_IDS := ["equipment.portable_torch", "environment.wall_torch"]
const FALLBACK_COOKIE := "art/lighting/T_basic1_vfx.PNG"
const CARRIED_LIFT := 2.5
const UNREGISTERED_LIFT := 1.0
## The engine's spatial interaction rules (modern branch dnd/spatial/
## environmental_conditions.py, gas_traps.py, spells/*): surface ->
## [[operation, becomes, also creates]]; empty becomes = removed.
const OPERATIONS := {
    "spatial_effect.material.oil": [["ignite", "spatial_effect.material.fire", ""]],
    "spatial_effect.material.fire": [["douse", "", ""]],
    "spatial_effect.material.water_surface": [["freeze", "spatial_effect.material.ice", ""], ["electrify", "spatial_effect.material.electrified_water", ""],
        ["vaporize", "", "spatial_effect.material.steam"], ["dry", "", ""]],
    "spatial_effect.material.ice": [["dry", "", ""], ["vaporize", "", "spatial_effect.material.steam"]],
    "spatial_effect.material.electrified_water": [["freeze", "spatial_effect.material.ice", ""], ["vaporize", "", "spatial_effect.material.steam"], ["dry", "", ""]],
    "spatial_effect.material.steam": [["dry", "", ""]],
    "spatial_effect.spell.web": [["ignite", "spatial_effect.spell.web.burning", ""]],
    "spatial_effect.spell.web.burning": [["douse", "", ""]],
    "spatial_effect.spell.cloudkill": [["disperse", "", ""]],
    "spatial_effect.spell.fog_cloud": [["disperse", "", ""]],
    "spatial_effect.spell.stinking_cloud": [["disperse", "", ""]],
    "spatial_effect.environment.poison_gas": [["disperse", "", ""]],
    "spatial_effect.spell.plant_growth": [["ignite", "", ""]],
    "spatial_effect.spell.simple_toxin": [["dry", "", ""]],
}
## Factory surface scenarios (assets/vfx/index.json selections) and the
## surface use they serve: [surface, lasting or operation, selection, clip].
const SCENARIOS := [
    ["spatial_effect.spell.grease", "lasting", "grease__surface", "review/grease/surface/lifecycle"],
    ["spatial_effect.material.oil", "ignite", "oil_ignite_douse", "oil-local-fire"],
    ["spatial_effect.material.fire", "douse", "oil_ignite_douse", "oil-local-fire"],
    ["spatial_effect.spell.web", "ignite", "web_ignite_douse", "web-local-fire"],
    ["spatial_effect.spell.web.burning", "douse", "web_ignite_douse", "web-local-fire"],
    ["spatial_effect.material.water_surface", "freeze", "surface_water_freeze_thaw", "surface_water_freeze_thaw"],
    ["spatial_effect.material.water_surface", "vaporize", "water_vaporize_steam_owner", "water-secondary-source"],
    ["spatial_effect.material.steam", "lasting", "water_vaporize_steam_owner", "steam-maintained-owner"],
    ["residue.blood", "freeze", "surface_blood_freeze_thaw", "surface_blood_freeze_thaw"],
    ["spatial_effect.spell.wall_of_ice", "lasting", "ice_dome_native", "wall-native/ice_dome_surface_breakup_native/lifecycle"],
]
## World blocks that describe surfaces, kept as delivered in each surface's legacy file.
const SURFACE_BLOCKS := ["spatial_effects", "spatial_media", "deposit_media", "liquid_surfaces", "residue_ground", "residue_particles", "residue_surfaces"]

var sections := {}
var written := {}
var errors: Array = []
var server: Dictionary
var world: Dictionary
var world_bytes: PackedByteArray
var assets: Dictionary
var index: Dictionary
var art_of_image := {}
var groups := {}
var bank_rows := {}
var package_selections := {}
var package_version := ""
var _identifier := RegEx.create_from_string("[^A-Za-z0-9_]")

func _initialize() -> void:
    run.call_deferred()

func run() -> void:
    var started := Time.get_ticks_msec()
    var catalogue_path := CATALOGUE
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--catalogue="): catalogue_path = argument.trim_prefix("--catalogue=")
    for section in SECTIONS: sections[section] = {}
    server = _json(LEGACY + "server_ids.json").ids
    world_bytes = FileAccess.get_file_as_bytes(LEGACY + "world.json")
    world = JSON.parse_string(world_bytes.get_string_from_utf8())
    assets = _json(LEGACY + "assets.json")
    index = _json(LEGACY + "environment/index.json")
    var package: Dictionary = _json("res://assets/vfx/index.json")
    package_version = str(package.version)
    for selection in package.selections: package_selections[selection.key] = selection
    _images()
    _banks()
    _library_art()
    _devices_and_portals()
    _terrain()
    _structures()
    _objects()
    _library(catalogue_path)
    _surfaces()
    _connectors_lighting_battlefields()
    _shared_measurements()
    var root := Root.new()
    root.domain = "environment"
    for section in SECTIONS: root.sections[section] = sections[section]
    var normals := Surface.new()
    normals.encoding = "rg16_depth_oct_normal"
    normals.normals = {"quality": MEASURED_REL + "receiving_normals.json"}
    normals.source = QUALITY
    root.shared["receiving_normals"] = normals
    _save(root, ROOT_PATH)
    _remove_stale()
    var counts := {}
    for section in SECTIONS: counts[section] = sections[section].size()
    print("ENVIRONMENT_CONVERTED ", JSON.stringify({"counts": counts, "errors": errors.size(), "seconds": (Time.get_ticks_msec() - started) / 1000.0}))
    for line in errors.slice(0, 40): print("CONVERT_ERROR ", line)
    quit(0 if errors.is_empty() else 1)

# --- helpers -----------------------------------------------------------------

func _json(path: String) -> Variant:
    return JSON.parse_string(FileAccess.get_file_as_string(path))

static func asset_path(path: String) -> String:
    if path.begins_with("/media/"): return "art/media/" + path.trim_prefix("/media/")
    var quality := QUALITY + "/"
    if path.contains(quality): return "art/geometry/environment-quality/" + path.substr(path.find(quality) + quality.length())
    return path

static func rewrite(text: String) -> String:
    return text.replace("\"/media/", "\"art/media/")

func _save(resource: Resource, path: String) -> void:
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    _name_parts(resource, "")
    var error := ResourceSaver.save(resource, path)
    if error != OK: errors.append("cannot save " + path + ": " + error_string(error))
    written[path] = true

## Stable sub-resource ids from their property paths, so a re-run rewrites the same text.
func _name_parts(resource: Resource, prefix: String) -> void:
    for property in resource.get_property_list():
        if property.usage & PROPERTY_USAGE_STORAGE and property.name != "script":
            _name_value(resource.get(property.name), property.name if prefix.is_empty() else prefix + "_" + property.name)

func _name_value(value: Variant, name: String) -> void:
    if value is Resource and value.resource_path.is_empty():
        value.resource_scene_unique_id = _identifier.sub(name, "_", true)
        _name_parts(value, name)
    elif value is Array:
        for i in value.size(): _name_value(value[i], name + "_" + str(i))
    elif value is Dictionary:
        for key in value: _name_value(value[key], name + "_" + str(key))

func _entry(section: String, id: String, resource: Resource) -> void:
    var path: String = OUT + section + "/" + id.replace("/", ".") + ".tres"
    if sections[section].has(id): errors.append(section + "/" + id + " written twice")
    sections[section][id] = path
    _save(resource, path)

func _measured(relative: String, text: String) -> String:
    var path := MEASURED + relative
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null: errors.append("cannot write " + path); return ""
    file.store_string(text if text.ends_with("\n") else text + "\n")
    written[path] = true
    return MEASURED_REL + relative

func _remove_stale() -> void:
    var stale: Array = []
    for section in SECTIONS: _collect(OUT + section, ".tres", stale)
    _collect(MEASURED, "", stale)
    for path in stale:
        if not written.has(path): DirAccess.remove_absolute(path)

func _collect(folder: String, extension: String, out: Array) -> void:
    var dir := DirAccess.open(folder)
    if dir == null: return
    for sub in dir.get_directories(): _collect(folder.path_join(sub), extension, out)
    for file in dir.get_files():
        if extension.is_empty() or file.ends_with(extension): out.append(folder.path_join(file))

func _status_note(resource: Resource, status: String, note: String) -> void:
    resource.status = status
    resource.notes = note

static func _floats(values: Array) -> PackedFloat64Array:
    return PackedFloat64Array(values)

## Splits an image id into its group and the view/frame suffixes it carries.
static func _image_group(id: String) -> String:
    var parts := id.split(".")
    while parts.size() > 1 and (parts[-1] in VIEWS or parts[-1] in FACINGS or parts[-1].is_valid_int()): parts.remove_at(parts.size() - 1)
    return ".".join(parts)

static func _image_view(id: String, group: String) -> String:
    var rest := id.trim_prefix(group).trim_prefix(".")
    for part in rest.split("."):
        if part in VIEWS or part in FACINGS: return part
    return ""

static func _exact_vector(values: Array) -> bool:
    var vector := Vector2(values[0], values[1])
    return vector.x == float(values[0]) and vector.y == float(values[1])

# --- art: images --------------------------------------------------------------

func _images() -> void:
    var bytes := FileAccess.get_file_as_bytes(LEGACY + "assets.json")
    var top := Spans.members(bytes)
    var resource_span: Array = top.filter(func(m): return m[0] == "resources")[0]
    var spans := {}
    for member in Spans.members(bytes, resource_span[1]): spans[member[0]] = [member[1], member[2]]
    for id in assets.resources:
        if id.begins_with("support."): continue # condition media (abilities); duplicates catalog/condition_media.json
        var group := _image_group(id)
        if not groups.has(group): groups[group] = []
        groups[group].append(id)
    var animations: Dictionary = assets.get("animations", {})
    for group in groups:
        var ids: Array = groups[group]
        var records: Array = ids.map(func(id): return assets.resources[id])
        var first: Dictionary = records[0]
        var uniform_size := records.all(func(r): return r.native_size == first.native_size)
        var uniform_scale := records.all(func(r): return r.scale == first.scale)
        var uniform_pivot := records.all(func(r): return r.pivot == first.pivot) and _exact_vector(first.pivot)
        var views: Array = []
        for id in ids:
            var view := _image_view(id, group)
            if not view.is_empty() and not views.has(view): views.append(view)
        var measured := {}
        for i in ids.size():
            var id: String = ids[i]
            var record_bytes := bytes.slice(spans[id][0], spans[id][1])
            var kept := {}
            for member in Spans.members(record_bytes):
                var key: String = member[0]
                if key == "path" or (key == "native_size" and uniform_size) or (key == "scale" and uniform_scale) or (key == "pivot" and uniform_pivot): continue
                kept[key] = rewrite(Spans.text(record_bytes, member[1], member[2]))
            measured[id] = Spans.object(kept, "  ")
            art_of_image[id] = group
        var source := ArtSource.new()
        source.container = "atlas" if first.has("rect") else ("views_as_files" if not views.is_empty() else ("frames_as_files" if ids.size() > 1 else "views_as_files"))
        source.files = PackedStringArray(records.map(func(r): return asset_path(r.path)))
        if uniform_size: source.cell = Vector2i(first.native_size[0], first.native_size[1])
        if uniform_scale: source.scale = float(first.scale)
        if uniform_pivot: source.pivot = Vector2(first.pivot[0], first.pivot[1])
        source.directions = "camera4" if views.size() == 4 and views.all(func(v): return v in VIEWS) else ("facing8" if views.size() == 8 else "single")
        source.direction_order = PackedStringArray(views)
        source.frames = ids.size() / maxi(1, views.size())
        if animations.has(group):
            if animations[group].frames != ids: errors.append("animation " + group + " frames differ from its images")
            source.fps = float(animations[group].fps)
        source.surface = _surface(first)
        source.measurements = _measured("art/" + group + ".json", Spans.object(measured))
        source.source = MEDIA
        var legacy: bool = group.begins_with("web") or group.begins_with("trap-workshop") or group.begins_with("spikes") or group.begins_with("residue")
        source.status = "ready"
        var art := Art.new()
        art.id = group
        art.kind = "sprite" if legacy else "images"
        art.art = source
        art.images = PackedStringArray(ids)
        if legacy: source.notes = "Pre-rendered sprite from the old client; nothing draws it today."
        _entry("art", group, art)

func _surface(record: Dictionary) -> Surface:
    var surface := Surface.new()
    var geometry: Dictionary = record.get("geometry", {})
    surface.encoding = "rg16_depth_oct_normal" if geometry.get("encoding", "") == "rg16be_oct8_rgba8" else "none"
    if surface.encoding != "none": surface.source = GEOMETRY
    return surface

# --- art: banks ---------------------------------------------------------------

func _banks() -> void:
    var layouts: Dictionary = _json("res://generated/environment_texture_layouts.json").layouts
    for bank_id in index.banks:
        var bytes := FileAccess.get_file_as_bytes(LEGACY + index.banks[bank_id])
        var bank: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
        var kept := {}
        for member in Spans.members(bytes):
            if member[0] in BANK_FIELDS: continue
            kept[member[0]] = rewrite(Spans.text(bytes, member[1], member[2]))
        var source := ArtSource.new()
        source.container = "atlas" if bank.has("frames_by_pose") else "grid_sheet"
        source.path = asset_path(bank.get("path", ""))
        var pages := {}
        for frames in bank.get("frames_by_pose", {}).values():
            for frame in frames: pages[asset_path(frame.path)] = true
        source.files = PackedStringArray(pages.keys())
        source.cell = Vector2i(bank.cell[0], bank.cell[1])
        source.frames = int(bank.frame_count)
        source.fps = float(bank.get("fps", 0.0))
        source.directions = "camera4"
        source.direction_order = PackedStringArray(bank.rows)
        bank_rows[bank_id] = source.direction_order
        source.scale = float(bank.scale)
        var first: Dictionary = bank.surface_frames_by_pose.values()[0][0]
        source.surface = _surface(first)
        source.measurements = _measured("art/" + bank_id + ".json", Spans.object(kept))
        source.source = MEDIA
        source.status = "ready"
        if bank.has("actor_depth"): source.notes = "Also carries the legacy RG16 little-endian painter depth (actor_depth) that splits door leaves against their frame."
        var art := Art.new()
        art.id = bank_id
        art.kind = "bank"
        art.art = source
        for pose in bank.get("camera_quarter_by_pose", {}): art.camera_quarters[pose] = int(bank.camera_quarter_by_pose[pose])
        art.state_change_frame = int(bank.get("state_change_frame", -1))
        art.clear_at_end = bank.get("clear_at_end", false)
        for frames in bank.surface_frames_by_pose.values():
            for frame in frames:
                if layouts.has(frame.get("geometry_region", {}).get("path", "")): art.paged = true
        art.rest_library = ORIGINAL_CHEST_RESTS.get(bank_id, "")
        _entry("art", bank_id, art)

# --- art: library families, devices, portals ---------------------------------

func _library_art() -> void:
    for family in index.library:
        var text := FileAccess.get_file_as_string(LEGACY + index.library[family])
        var source := ArtSource.new()
        source.container = "frames_as_files"
        source.directions = "camera4"
        source.measurements = _measured("art/" + family + ".json", rewrite(text))
        source.source = GEOMETRY
        source.status = "ready"
        var art := Art.new()
        art.id = family
        art.kind = "samples"
        art.art = source
        _entry("art", family, art)

func _devices_and_portals() -> void:
    var device_bytes := FileAccess.get_file_as_bytes(LEGACY + "catalog/devices.json")
    var devices: Dictionary = JSON.parse_string(device_bytes.get_string_from_utf8())
    var wrecks: Dictionary = _json(LEGACY + "catalog/device_wrecks.json")
    for member in Spans.members(device_bytes):
        var id: String = member[0]
        var device: Dictionary = devices[id]
        var source := ArtSource.new()
        source.container = "atlas"
        source.cell = Vector2i(device.cell[0], device.cell[1])
        source.frames = int(device.frame_count)
        source.fps = float(device.fps)
        source.directions = "facing8"
        source.direction_order = PackedStringArray(device.rows)
        source.pivot = Vector2(device.anchor[0], device.anchor[1])
        source.scale = float(device.scale)
        source.measurements = _measured("art/device." + id.trim_prefix("environment.") + ".json", rewrite(Spans.text(device_bytes, member[1], member[2])))
        source.source = MEDIA
        source.status = "ready"
        if wrecks.get(id + ".wreck", {}) == device: source.notes = "catalog/device_wrecks.json held an identical copy under " + id + ".wreck; its destruction block is the wreck."
        else: errors.append("device wreck differs from its device: " + id)
        var art := Art.new()
        art.id = "device." + id.trim_prefix("environment.")
        art.kind = "device"
        art.art = source
        _entry("art", art.id, art)
    var portal_bytes := FileAccess.get_file_as_bytes(LEGACY + "catalog/portals.json")
    for member in Spans.members(portal_bytes):
        var id: String = member[0]
        var source := ArtSource.new()
        source.container = "atlas"
        source.directions = "camera4"
        source.measurements = _measured("art/portal." + _short(id) + ".json", rewrite(Spans.text(portal_bytes, member[1], member[2])))
        source.source = MEDIA
        source.status = "ready"
        var art := Art.new()
        art.id = "portal." + _short(id)
        art.kind = "portal"
        art.art = source
        _entry("art", art.id, art)

static func _short(id: String) -> String:
    return id.trim_prefix("spatial_effect.")

# --- terrain ------------------------------------------------------------------

func _terrain() -> void:
    var footstep := SoundRef.new()
    footstep.cue = "footstep"
    footstep.at = "body.source_frame"
    for material in server.tile_material:
        var terrain := Terrain.new()
        terrain.material = material
        terrain.footstep = footstep
        var views: Variant = world.terrain.get(material)
        if material == "water":
            terrain.shader = "water"
            terrain.receiving = "flat_plane"
            var water: Dictionary = assets.water
            terrain.floor = art_of_image[water.mask]
            terrain.water_images = {"ripple": water.ripple, "normal": water.normal}
            for key in water:
                if key in ["mask", "ripple", "normal"]: continue
                terrain.water_look[key.to_snake_case()] = water[key]
            _status_note(terrain, "ready", "Animated water shader over the mask image. The old world.json terrain value (\"water.unity\") was never read. Dead look values kept for completeness: detail_pan, detail_influence, uv_wobble_amount, normal_pan_a/b, normal_tiling_multiplier, normal_scale, premultiply_output, blend, and the normal image.")
        elif views is Dictionary:
            terrain.floor = _group_of(views.values())
            _status_note(terrain, "ready", "")
        else:
            _status_note(terrain, "missing", "The server sends this material; no floor art is bound, so the game does not draw these tiles.")
        var stairs := Slope.new()
        stairs.kind = "stairs"
        if material == "earth":
            var definition: Dictionary = world.terrain_stairs
            stairs.art = _group_of(definition.poses.values())
            stairs.rise_steps = int(definition.rise_steps)
            for view in definition.contacts_px:
                stairs.contacts[view] = PackedVector2Array(definition.contacts_px[view].map(func(p): return Vector2(p[0], p[1])))
            for offset in definition.support_offsets: stairs.support_offsets.append(Vector3i(offset[0], offset[1], offset[2]))
            stairs.status = "partial"
            stairs.notes = "Earth stairs art (ground-g17) from the old terrain_stairs block; only the workshop draws it. The game maps no server surface_kind to it yet."
        else:
            stairs.status = "missing"
            stairs.notes = "Server surface_kind stairs with slope_axis; no art for this material."
        var ramp := Slope.new()
        ramp.kind = "ramp"
        ramp.status = "missing"
        ramp.notes = "Server surface_kind ramp with slope_axis; no art."
        terrain.slopes.assign([stairs, ramp])
        _entry("terrain", material, terrain)

func _group_of(ids: Array) -> String:
    var group: String = art_of_image.get(ids[0], "")
    for id in ids:
        if art_of_image.get(id, "") != group: errors.append("images " + str(ids) + " span several art entries")
    return group

# --- structures ---------------------------------------------------------------

func _structures() -> void:
    var destructions: Dictionary = _json(LEGACY + index.wall_destructions)
    var cliff: Dictionary = world.terrain_cliff
    for kind in STRUCTURES:
        for material in server.tile_material:
            var structure := Structure.new()
            structure.structure = kind
            structure.material = material
            if kind in ["wall", "retaining_wall"]:
                if world.has(material + "_wall_straight"):
                    structure.straight = _group_of(world[material + "_wall_straight"].values())
                    structure.corner = _group_of(world[material + "_wall_corner"].values())
                    for view in world.wall_corner_faces: structure.corner_faces[view] = PackedStringArray(world.wall_corner_faces[view])
                    structure.corner_turn = "against_quarter"
                    structure.destruction = destructions.get(material, "")
                    _status_note(structure, "ready", "" if kind == "wall" else "Drawn with the " + material + " wall pieces.")
                else:
                    _status_note(structure, "missing", "No " + material + " wall art; the game reports these edges unresolved.")
            elif kind in ["cliff", "embankment"]:
                structure.straight = _group_of(cliff.straight.values())
                structure.corner = _group_of(cliff.corner.values())
                for view in cliff.corner_faces: structure.corner_faces[view] = PackedStringArray(cliff.corner_faces[view])
                structure.corner_turn = "with_quarter"
                structure.height_steps = int(cliff.rise_steps)
                structure.cutaway = false
                structure.two_sided_light = false
                if kind == "cliff" and material == cliff.bed_material:
                    _status_note(structure, "ready", "Old terrain_cliff block (role cliff, bed_material earth, upper_support_offset [0, 0]).")
                else:
                    _status_note(structure, "stand_in", "Drawn with the earth cliff pieces: the game ignores the server material for cliffs and embankments.")
            else:
                _status_note(structure, "missing", "The game reports " + kind + " boundaries unresolved; environment.door.* objects draw doors.")
            _entry("structures", kind + "/" + material, structure)

# --- objects ------------------------------------------------------------------

static func _kind(id: String) -> String:
    var name := id.trim_prefix("environment.")
    if name.begins_with("door.") or name == "directional_door": return "door"
    if name.begins_with("window.") and name.ends_with(".insert"): return "window_insert"
    if name.begins_with("window."): return "window"
    if name.begins_with("furniture."): return "furniture"
    if name.begins_with("chest.") or name == "storage_chest": return "chest"
    if name.begins_with("trap."): return "trap"
    if name in ["trap_lever", "control_lever"]: return "lever"
    if name in ["wall_torch", "standing_torch"]: return "torch"
    if name == "campfire": return "campfire"
    if name in ["arcane_device", "arcane_machine_gun", "fireball_cannon"]: return "device"
    if name.begins_with("blocker.") and name.ends_with("_barrel"): return "barrel"
    if name.begins_with("blocker."): return "blocker"
    if name.begins_with("wall.") or name == "directional_wall": return "wall"
    if name == "cliff_face": return "cliff"
    if name.begins_with("spell_object."): return "spell_object"
    return "prop"

func _views_of(bank_id: String) -> PackedStringArray:
    return bank_rows[bank_id]

func _state(bank: String, frame: int) -> State:
    var state := State.new()
    state.bank = bank
    state.frame = frame
    return state

func _mask_refs(masks: Dictionary) -> Dictionary[String, ImageRef]:
    var result: Dictionary[String, ImageRef] = {}
    for view in masks:
        var ref := ImageRef.new()
        ref.path = asset_path(masks[view].path)
        var rect: Array = masks[view].rect
        ref.rect = Rect2i(rect[0], rect[1], rect[2], rect[3])
        ref.native_size = Vector2i(rect[2], rect[3])
        result[view] = ref
    return result

func _objects() -> void:
    var wrecks := {}
    var wreck_dir := DirAccess.open(LEGACY + "environment/wrecks")
    for file in wreck_dir.get_files():
        var wreck: Dictionary = _json(LEGACY + "environment/wrecks/" + file)
        if not wrecks.has(wreck.source_item_id): wrecks[wreck.source_item_id] = {}
        wrecks[wreck.source_item_id][file.get_basename()] = wreck.get("outcome", "")
    for id in server.environment_object:
        var object := EnvironmentObject.new()
        object.id = id
        object.kind = _kind(id)
        object.wrecks.assign(wrecks.get(id, {}))
        if index.doors.has(id): _door(object, _json(LEGACY + index.doors[id]))
        elif index.props.has(id): _prop(object, _json(LEGACY + index.props[id]))
        elif index.traps.has(id): _trap(object, _json(LEGACY + index.traps[id]))
        elif world.props.has(id): _fixture(object, world.props[id])
        elif sections.art.has("device." + id.trim_prefix("environment.")):
            object.art = PackedStringArray(["device." + id.trim_prefix("environment.")])
            object.views = PackedStringArray(FACINGS)
            _status_note(object, "partial", "8-direction device banks with firing pitches and a destruction set (old catalog/devices.json); the game does not draw devices yet.")
        else:
            _status_note(object, "missing", _missing_object_note(id))
        _entry("objects", id, object)

func _missing_object_note(id: String) -> String:
    if id.begins_with("environment.door.desert_"): return "Desert doors: the Desert family is excluded from the catalogue and the geometry deliveries."
    if id.begins_with("environment.trap."): return "No object art. Its trap field (spatial_effect.environment.*) carries old pre-rendered sprites in the surfaces section."
    return "The server sends this object; no art is bound, so the game reports it unresolved."

func _door(object: EnvironmentObject, owner: Dictionary) -> void:
    object.select_field = "is_open"
    object.views = _views_of(owner.openings.outward)
    object.states["closed"] = _state(owner.openings.outward, 0)
    object.states["open.outward"] = _state(owner.openings.outward, -1)
    object.states["open.inward"] = _state(owner.openings.inward, -1)
    object.destructions.assign(owner.destructions)
    for swing in ["outward", "inward"]:
        for reversed in [false, true]:
            var transition := Transition.new()
            transition.from = "open." + swing if reversed else "closed"
            transition.to = "closed" if reversed else "open." + swing
            transition.bank = owner.openings[swing]
            transition.reversed = reversed
            object.transitions.append(transition)
    var frame := Part.new()
    frame.role = "frame"
    frame.images.assign(owner.frame_resource_by_pose)
    var leaf := Part.new()
    leaf.role = "leaf"
    var bank: Dictionary = _json(LEGACY + index.banks[owner.openings.outward])
    leaf.depth_split = bank.has("actor_depth") and bank.has("depth_frames_by_pose")
    object.parts.assign([leaf, frame])
    var delivery := {}
    var bytes := FileAccess.get_file_as_bytes(LEGACY + index.doors[object.id])
    for member in Spans.members(bytes):
        if member[0] in ["assembly_variants", "authoring_record", "pose_offset"]: delivery[member[0]] = rewrite(Spans.text(bytes, member[1], member[2]))
    if owner.has("authoring_record"): delivery.source_record = rewrite(FileAccess.get_file_as_string(LEGACY + owner.authoring_record))
    object.measurements = _measured("objects/" + object.id + ".json", Spans.object(delivery))
    _status_note(object, "ready", "Open and closed snap to the end poses; the transitions are data only. pose_offset, assembly_variants and the source record are kept as delivered in its measurements.")

func _prop(object: EnvironmentObject, owner: Dictionary) -> void:
    object.select_field = owner.get("state_field", "")
    var first: String = owner.intact.values()[0]
    object.views = _views_of(first)
    for state in owner.intact: object.states[state] = _state(owner.intact[state], 0)
    object.destructions.assign(owner.destructions)
    object.destructions_without_attachments.assign(owner.get("destructions_without_attachments", {}))
    object.hit_masks = _mask_refs(owner.get("selection_masks_by_pose", {}))
    object.aperture_masks = _mask_refs(owner.get("aperture_masks_by_pose", {}))
    object.flat_ground = owner.get("flat_ground", false)
    object.occludes_actor_face = owner.get("occludes_actor_face", false)
    if owner.has("passage_point"): object.passage_point = Vector3(owner.passage_point[0], owner.passage_point[1], owner.passage_point[2])
    if object.kind in ["window", "window_insert"]:
        var part := Part.new()
        part.role = "insert" if object.kind == "window" else "wall"
        var other: String = object.id.trim_suffix(".wall") + ".insert" if object.kind == "window" else object.id.trim_suffix(".insert") + ".wall"
        part.other = other if index.props.has(other) else ""
        part.omit_with_destroyed_parent = owner.get("omit_with_destroyed_parent", false)
        object.parts.append(part)
    elif owner.get("omit_with_destroyed_parent", false):
        errors.append("omit_with_destroyed_parent outside a window: " + object.id)
    if owner.has("authoring_record"):
        object.measurements = _measured("objects/" + object.id + ".json", Spans.object({"authoring_record": JSON.stringify(owner.authoring_record),
            "source_record": rewrite(FileAccess.get_file_as_string(LEGACY + owner.authoring_record))}))
    _status_note(object, "ready", "flat_ground is authored but the draw order does not use it." if object.flat_ground else "")

func _trap(object: EnvironmentObject, owner: Dictionary) -> void:
    object.select_field = "is_engaged"
    object.views = _views_of(owner.intact)
    for state in owner.state_frames: object.states[state] = _state(owner.intact, int(owner.state_frames[state]))
    object.destructions.assign(owner.destructions)
    _status_note(object, "ready", "The game asks for state \"active\" when the trap is engaged, but the states are ready/activated/deactivated (world.gd).")

func _fixture(object: EnvironmentObject, prop: Dictionary) -> void:
    object.select_field = prop.get("state_field", "")
    var resting := State.new()
    resting.images.assign(prop.body_by_pose)
    object.views = PackedStringArray(prop.body_by_pose.keys())
    if object.select_field.is_empty():
        object.states["default"] = resting
    else:
        object.states["false"] = resting
        var active := State.new()
        active.images.assign(prop.get("active_body_by_pose", prop.body_by_pose))
        object.states["true"] = active
    if prop.get("lit_animation") != null:
        object.light = "torch"
        object.flame = prop.lit_animation
    var definition: Variant = prop.get("transition")
    if definition is Dictionary:
        var transition := Transition.new()
        transition.from = "false"
        transition.to = "true"
        for view in definition.frames_by_pose: transition.images[view] = PackedStringArray(definition.frames_by_pose[view])
        transition.fps = float(definition.fps)
        object.transitions.append(transition)
        var back := Transition.new()
        back.from = "true"
        back.to = "false"
        back.images = transition.images
        back.fps = transition.fps
        back.reversed = true
        object.transitions.append(back)
    _status_note(object, "ready", "The lever snaps between its poses; the 24 fps transition is data only (also duplicated in the old catalog/world_animations.json)." if definition is Dictionary else "")

# --- library ------------------------------------------------------------------

func _library(catalogue_path: String) -> void:
    var entries: Array = []
    if FileAccess.file_exists(catalogue_path): entries = _json(catalogue_path).entries
    else: print("CONVERT_NOTE catalogue not found, library entries come from the library families only: ", catalogue_path)
    var seen := {}
    for entry in entries:
        var id: String = entry.id
        if id.begins_with("created.decal."): seen[id] = true; continue # surfaces section
        var object := EnvironmentObject.new()
        object.id = id
        object.kind = str(entry.get("kind", "")).to_lower()
        object.catalogue_group = str(entry.get("group", ""))
        object.label = str(entry.get("label", ""))
        object.original = str(entry.original_id) if entry.get("original_id") != null else ""
        object.views = PackedStringArray(entry.get("views", {}).keys())
        var notes := "Catalogue status: " + str(entry.get("status", "")) + "."
        if entry.get("has_animation", false): notes += " Animated."
        if not entry.get("native_ids", []).is_empty(): notes += " Native ids: " + ", ".join(PackedStringArray(entry.native_ids)) + "."
        if sections.art.has(id):
            object.art = PackedStringArray([id])
            _status_note(object, "partial", notes + " Art and geometry are in the source; no server id uses it yet.")
        else:
            _status_note(object, "missing", notes + " Outside the geometry delivery: no art copied into the project.")
        seen[id] = true
        _entry("library", id, object)
    for family in index.library:
        if seen.has(family) or family.begins_with("created.decal."): continue
        var object := EnvironmentObject.new()
        object.id = family
        object.kind = "library"
        object.art = PackedStringArray([family])
        _status_note(object, "partial", "Library family without a catalogue entry.")
        _entry("library", family, object)
    var dimension_door := EnvironmentObject.new()
    dimension_door.id = "portal.spell.dimension_door"
    dimension_door.kind = "portal"
    dimension_door.art = PackedStringArray(["portal.spell.dimension_door"])
    _status_note(dimension_door, "partial", "Dimension Door's back/front portal pages (old catalog/portals.json); for the abilities source to use. Not drawn.")
    _entry("library", dimension_door.id, dimension_door)
    var construction := {}
    for member in Spans.members(world_bytes):
        if member[0] == "construction_media":
            for section in Spans.members(world_bytes, member[1]): construction[section[0]] = rewrite(Spans.text(world_bytes, section[1], section[2]))
    for id in construction:
        var object := EnvironmentObject.new()
        object.id = id
        object.kind = "construction"
        object.measurements = _measured("objects/" + id + ".json", construction[id])
        _status_note(object, "partial", "Wall sections a spell constructs (runtime item id). The old construction_media block is kept as delivered; not drawn.")
        _entry("library", id, object)

# --- surfaces -----------------------------------------------------------------

func _surfaces() -> void:
    var blocks := {}
    for member in Spans.members(world_bytes):
        if not member[0] in SURFACE_BLOCKS: continue
        for item in Spans.members(world_bytes, member[1]):
            if not blocks.has(item[0]): blocks[item[0]] = {}
            blocks[item[0]][member[0]] = rewrite(Spans.text(world_bytes, item[1], item[2]))
    var animation_bytes := FileAccess.get_file_as_bytes(LEGACY + "catalog/world_animations.json")
    var animations: Dictionary = JSON.parse_string(animation_bytes.get_string_from_utf8())
    for member in Spans.members(animation_bytes):
        if not member[0].begins_with("spatial_effect."): continue
        if world.spatial_effects.get(member[0]) == animations[member[0]]: continue
        if not blocks.has(member[0]): blocks[member[0]] = {}
        blocks[member[0]]["world_animations"] = rewrite(Spans.text(animation_bytes, member[1], member[2]))
    var ids: Array = server.spatial_effect.keys()
    if not ids.has("spatial_effect.spell.antimagic_field"): ids.append("spatial_effect.spell.antimagic_field")
    for id in ids:
        var surface := Ground.new()
        surface.id = id
        surface.source_kind = "spatial_effect"
        var layer: Variant = server.spatial_effect.get(id, {}).get("layer")
        surface.layer = layer if layer != null else ("field" if id == "spatial_effect.spell.antimagic_field" else "none")
        _fill_surface(surface, blocks.get(id, {}))
        if id == "spatial_effect.spell.antimagic_field": surface.notes = "Removed on the modern branch; the pinned engine still sends it. " + surface.notes
        _entry("surfaces", id, surface)
    var particles: Dictionary = world.residue_particles
    for id in server.residue:
        var surface := Ground.new()
        surface.id = id
        surface.source_kind = "residue"
        surface.layer = "ground_surface"
        surface.coverage = "per_cell"
        surface.max_amount = int(server.residue[id].max_amount)
        surface.region_asset = particles.get(id, "")
        if id == "residue.blood":
            surface.amount_look = "grow"
            surface.region_asset = ""
            var media := FileAccess.get_file_as_bytes(LEGACY + "catalog/action_media_assets.json")
            for member in Spans.members(media):
                if member[0] == "particles.region.blood": surface.region_particles = _measured("residues/particles.region.blood.json", rewrite(Spans.text(media, member[1], member[2])))
            surface.status = "ready"
        _fill_surface(surface, blocks.get(id, {}))
        if id == "residue.blood":
            surface.notes = "A 64 px additive field per tile and a stain quad at the tile's height, grown with amount; a new deposit flies from the body. Wall-face residues and deposit_source are not drawn. " + surface.notes
        _entry("surfaces", id, surface)
    for family in index.library:
        if not family.begins_with("created.decal."): continue
        var surface := Ground.new()
        surface.id = family
        surface.source_kind = "decal"
        surface.layer = "ground_surface"
        surface.coverage = "footprint"
        surface.art = PackedStringArray([family])
        _status_note(surface, "partial", "Decal art on the parent surface's depth and normals; the game does not draw decals.")
        _entry("surfaces", family, surface)

func _fill_surface(surface: Ground, legacy: Dictionary) -> void:
    if not legacy.is_empty(): surface.legacy = _measured("surfaces/" + surface.id + ".json", Spans.object(legacy))
    var art := {}
    if legacy.has("spatial_effects"):
        var block: Dictionary = world.spatial_effects[surface.id]
        for frames in block.get("frames_by_pose", {}).values():
            for frame in frames:
                if art_of_image.has(frame): art[art_of_image[frame]] = true
    if legacy.has("residue_ground"):
        for image in world.residue_ground[surface.id].values():
            if art_of_image.has(image): art[art_of_image[image]] = true
    if legacy.has("residue_surfaces"):
        for key in ["floor_atlas", "wall_atlas"]:
            var image: String = world.residue_surfaces[surface.id].get(key, "")
            if art_of_image.has(image): art[art_of_image[image]] = true
    if surface.id == "spatial_effect.spell.web":
        for group in groups:
            if group.begins_with("web"): art[group] = true
    if surface.id.begins_with("spatial_effect.environment.portal"):
        var portal := "portal." + _short(surface.id)
        if sections.art.has(portal): art[portal] = true
    surface.art = PackedStringArray(art.keys())
    for rule in OPERATIONS.get(surface.id, []):
        var operation := Operation.new()
        operation.operation = rule[0]
        operation.becomes = rule[1]
        operation.also_creates = rule[2]
        surface.operations.append(operation)
    var bound := false
    for scenario in SCENARIOS:
        if scenario[0] != surface.id: continue
        if not package_selections.has(scenario[2]): errors.append("Factory selection missing: " + scenario[2]); continue
        var use := EffectUse.new()
        use.selection = scenario[2]
        use.clip = scenario[3]
        use.at = "state_change" if scenario[1] != "lasting" else "owner_start"
        use.attachment = "area"
        use.staging_from = "factory@" + package_version
        bound = true
        if scenario[1] == "lasting":
            use.role = "sustain"
            surface.lasting = use
            continue
        use.role = "transition"
        var operation: Operation = null
        for existing in surface.operations:
            if existing.operation == scenario[1]: operation = existing
        if operation == null:
            operation = Operation.new()
            operation.operation = scenario[1]
            surface.operations.append(operation)
        operation.transition = use
    var notes := PackedStringArray()
    if surface.id == "spatial_effect.spell.web": notes.append("The Web area is drawn today by spell.web's lifecycle (abilities source), clipped to the unsuppressed cells; ignite and burn are not handled.")
    if surface.id == "residue.blood": notes.append("Freeze is a client look (the Factory's blood freeze/thaw scenario); the server has no residue operation.")
    if not surface.region_asset.is_empty(): notes.append("Region particles " + surface.region_asset + " are an asset of catalog/action_media_assets.json (abilities source).")
    if surface.source_kind == "residue": notes.append("Wall-face residue profiles: measured/environment/legacy/residue_wall_faces.json.")
    if surface.status != "ready":
        if surface.id == "spatial_effect.spell.web": surface.status = "partial"
        elif bound or not surface.art.is_empty() or not legacy.is_empty(): surface.status = "partial"; notes.append("Art or a Factory scenario exists; the game does not draw it.")
        else: surface.status = "missing"; notes.append("No art and no Factory scenario.")
    surface.notes = " ".join(notes)

# --- connectors, lighting, battlefields ---------------------------------------

func _connectors_lighting_battlefields() -> void:
    for kind in server.connector:
        var connector := Connector.new()
        connector.kind = kind
        connector.presentation_key = "traversal." + kind
        _status_note(connector, "missing", "No connector art. The actor's movement context on it belongs to the rig (characters source).")
        _entry("connectors", kind, connector)
    var torch := LightAppearance.new()
    torch.appearance = "torch"
    torch.colour = TORCH_COLOUR
    torch.flame = "torch.flame"
    torch.carried_height_steps = CARRIED_LIFT
    torch.item_ids = PackedStringArray(TORCH_ITEM_IDS)
    torch.notes = "Fixture flames flicker by the flame frames' measured energy (build output fixture_optics)."
    _entry("lighting", "torch", torch)
    var neutral := LightAppearance.new()
    neutral.appearance = "neutral"
    neutral.carried_height_steps = CARRIED_LIFT
    _entry("lighting", "neutral", neutral)
    var lighting := Lighting.new()
    var profile: Resource = load("res://authoring/presentation/light_ranges.tres")
    lighting.very_bright_edge = profile.very_bright_edge
    lighting.bright_edge = profile.bright_edge
    lighting.unregistered_height_steps = UNREGISTERED_LIFT
    lighting.fallback_cookie = FALLBACK_COOKIE
    for level in world.treatments:
        lighting.treatments[level] = world.treatments[level].id
        var rgb: Array = world.treatments[level].rgb
        lighting.treatment_tints[level] = Color(rgb[0], rgb[1], rgb[2])
    for source in world.lighting.directionalSources: lighting.directional.append(source)
    lighting.notes = "Light-level treatments are data only today. The fallback cookie is used only without a range profile."
    _entry("lighting", "lighting", lighting)
    for id in server.battlefield:
        var battlefield := Battlefield.new()
        battlefield.id = id
        battlefield.title = server.battlefield[id].get("title", "")
        _status_note(battlefield, "stand_in", "No per-battlefield ambience; the default lighting stands in.")
        _entry("battlefields", id, battlefield)

func _shared_measurements() -> void:
    var normals: Dictionary = _json("res://generated/environment_receiving_normals.json")
    var selected := {}
    for original in normals.normals:
        var choice: Dictionary = normals.normals[original]
        var moved := choice.duplicate()
        moved.path = asset_path(choice.path)
        selected[asset_path(original)] = moved
    _measured("receiving_normals.json", JSON.stringify({"version": normals.version, "selection": asset_path(normals.selection), "normals": selected}, "  ", false))
    for member in Spans.members(world_bytes):
        if member[0] == "residue_wall_faces": _measured("legacy/residue_wall_faces.json", rewrite(Spans.text(world_bytes, member[1], member[2])))
        if member[0] == "concentration_media": _measured("legacy/concentration_media.json", rewrite(Spans.text(world_bytes, member[1], member[2])))
