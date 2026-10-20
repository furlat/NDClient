extends RefCounted
## Builds the environment runtime files from authoring/environment.tres into
## build/presentation/environment/, in the shapes the game reads (binary, so
## every delivered number survives as read):
##   world.res      terrain views, wall and cliff pieces, fixtures, directional light
##   resources.res  every single image the world draws, the flame animation, the water look
##   index.res      door/prop/trap owners, bank and library paths, wall destructions, chest
##                  rests, and for the Studio's views: wrecks, old spatial media, portal,
##                  world-animation and device ids
##   banks/<id>.res, library/<id>.res   one bank each, and the library families rest poses show
##   receiving_normals.res, texture_layouts.res + pages/   normal selection and paged packets
##   fixture_optics.res   measured flame energy and emission centre per frame
##   residues/blood.res   the blood region particles
##   lighting.res, light_ranges.res   torch colour, cookie, optical heights, range profile
## and reports every server id of its kinds through Common.cover().
const Common = preload("res://tools/presentation_build/common.gd")
const Record = preload("res://presentation/source/environment/runtime_record.gd")
const AssetMetadata = preload("res://presentation/resources/asset_metadata.gd")
const Facts = preload("res://presentation/fixture_optical_facts.gd")
const LightRanges = preload("res://presentation/resources/light_range_profile.gd")
const Media = preload("res://presentation/media_warmup.gd")
const Art = preload("res://presentation/source/environment/art.gd")
const Terrain = preload("res://presentation/source/environment/terrain.gd")
const Structure = preload("res://presentation/source/environment/structure.gd")
const EnvironmentObject = preload("res://presentation/source/environment/object.gd")
const Ground = preload("res://presentation/source/environment/ground_surface.gd")
const Connector = preload("res://presentation/source/environment/connector.gd")
const LightAppearance = preload("res://presentation/source/environment/light_appearance.gd")
const Lighting = preload("res://presentation/source/environment/lighting.gd")
const Battlefield = preload("res://presentation/source/environment/battlefield.gd")
const SECTION_TYPES := {"terrain": Terrain, "structures": Structure, "objects": EnvironmentObject, "library": EnvironmentObject,
    "surfaces": Ground, "connectors": Connector, "battlefields": Battlefield, "art": Art}
const STATUSES := ["ready", "partial", "stand_in", "missing", "internal"]
const ASSETS := "res://assets/"
## Numeric packets above this size are split into pages of PAGE_SIZE whole cells.
const PAGE_SIZE := Vector2i(1536, 768)
const PAGE_MIN_BYTES := 16 * 1024 * 1024
const PAGE_CACHE_VERSION := 1

static func build(source: Dictionary, out_dir: String, report: Dictionary) -> void:
    var started := Time.get_ticks_msec()
    var entries: Dictionary = source.entries
    var root: Resource = source.root
    for section in SECTION_TYPES.keys() + ["lighting"]:
        if not entries.has(section): entries[section] = {}
    for section in entries:
        for id in entries[section]:
            var expected: Script = SECTION_TYPES.get(section, null)
            if section == "lighting": expected = Lighting if id == "lighting" else LightAppearance
            if expected == null: Common.error(report, "environment", "unknown section " + section); break
            if entries[section][id].get_script() != expected: Common.error(report, "environment/" + section + "/" + id, "entry is not a " + expected.resource_path.get_file())
            if "status" in entries[section][id] and not entries[section][id].status in STATUSES: Common.error(report, "environment/" + section + "/" + id, "unknown status")
    DirAccess.make_dir_recursive_absolute(out_dir)
    var context := {"report": report, "entries": entries, "out": out_dir, "art": entries.art, "resources": {}, "animations": {},
        "paths": {}, "banks": {}, "library": {}, "normals": {}, "layouts": {}, "selections": {}, "rests": {},
        "packet_headers": {}, "page_cache": {}, "previous_layouts": {}, "previous_page_cache": {}}
    for previous in [["texture_layouts.res", "previous_layouts", "layouts"], ["texture_page_cache.res", "previous_page_cache", "sources"]]:
        var path: String = out_dir.path_join(previous[0])
        if FileAccess.file_exists(path):
            var record: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
            if record != null: context[previous[1]] = record.value.get(previous[2], {})
    for id in entries.art:
        if not entries.art[id].rest_library.is_empty(): context.rests[entries.art[id].rest_library] = true
    var package: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/index.json"))
    for selection in package.selections: context.selections[selection.key] = selection
    _receiving_normals(root, context)
    _art(context)
    var world := {}
    var resources := {"resources": context.resources, "animations": context.animations}
    _terrain(context, world, resources)
    var index := {"doors": {}, "props": {}, "traps": {}, "banks": context.banks, "library": context.library, "wall_destructions": {}, "rests": {},
        "wrecks": {}, "spatial_media": {}, "inspection": {"portal": {}, "world_animation": {}, "device": {}}}
    _structures(context, world, index)
    _objects(context, world, index)
    _surfaces(context, index)
    _lighting(context, world)
    for kind in entries.connectors: Common.cover(report, "connector", kind, entries.connectors[kind].status)
    for id in entries.battlefields: Common.cover(report, "battlefield", id, entries.battlefields[id].status)
    for id in entries.art:
        var art: Art = entries.art[id]
        if art.rest_library.is_empty(): continue
        if not context.library.has(art.rest_library): Common.error(report, "environment/art/" + id, "rest library family missing: " + art.rest_library)
        index.rests[id] = art.rest_library
    for path in context.paths:
        if not FileAccess.file_exists(path): Common.error(report, "environment", "asset missing: " + path)
    _write(out_dir.path_join("world.res"), world, report)
    _write(out_dir.path_join("resources.res"), resources, report)
    _write(out_dir.path_join("index.res"), index, report)
    _write(out_dir.path_join("receiving_normals.res"), {"normals": context.normals}, report)
    _write(out_dir.path_join("texture_layouts.res"), {"version": 2.0, "operation": "lossless_frame_cell_pages", "layouts": context.layouts}, report)
    # Offline output reuse only. The renderer consumes texture_layouts, never stamps.
    _write(out_dir.path_join("texture_page_cache.res"), {"sources": context.page_cache}, report)
    print("ENVIRONMENT_BUILD ", JSON.stringify({"art": entries.art.size(), "banks": context.banks.size(), "library": context.library.size(),
        "resources": context.resources.size(), "paths_checked": context.paths.size(), "seconds": (Time.get_ticks_msec() - started) / 1000.0}))

static func _write(path: String, value: Dictionary, report: Dictionary) -> void:
    var record := Record.new()
    record.value = value
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    var error := ResourceSaver.save(record, path)
    if error != OK: Common.error(report, path, "cannot save: " + error_string(error))

## Measured registration as the runtime reads it: asset paths become res:// paths.
static func _measured(context: Dictionary, where: String, relative: String) -> Variant:
    if relative.is_empty() or not Common.asset(context.report, where, relative): return null
    var text := FileAccess.get_file_as_string(ASSETS + relative)
    text = text.replace("\"art/media/", "\"res://assets/art/media/").replace("\"art/geometry/", "\"res://assets/art/geometry/")
    var value: Variant = JSON.parse_string(text)
    if value == null: Common.error(context.report, where, "measurements do not parse: " + relative)
    return value

static func runtime_path(path: String) -> String:
    return "" if path.is_empty() else ASSETS + path

## An untyped copy, as the game's documents hold (typed source dictionaries stay in the source).
static func _plain(value: Dictionary) -> Dictionary:
    var result := {}
    for key in value: result[key] = value[key]
    return result

static func _floats(value: Vector2i) -> Array:
    return [float(value.x), float(value.y)]

static func _collect_paths(context: Dictionary, value: Variant) -> void:
    if value is Dictionary:
        for key in value: _collect_paths(context, value[key])
    elif value is Array:
        for item in value: _collect_paths(context, item)
    elif value is String and value.begins_with(ASSETS):
        context.paths[value] = true

# --- art ----------------------------------------------------------------------

static func _art(context: Dictionary) -> void:
    var report: Dictionary = context.report
    for id in context.art:
        var art: Art = context.art[id]
        var where: String = "environment/art/" + id
        if art.id != id: Common.error(report, where, "id field says " + art.id)
        if art.art == null: Common.error(report, where, "no art source"); continue
        Common.asset(report, where, art.art.path)
        for file in art.art.files: Common.asset(report, where, file)
        match art.kind:
            "bank": _bank(context, art, where)
            "images": _images(context, art, where)
            "samples":
                var family: Variant = _measured(context, where, art.art.measurements)
                # Every family's art must resolve; the game reads only the ones a rest pose shows.
                if family is Dictionary:
                    _collect_paths(context, family)
                    if not context.rests.has(id): continue
                    var path: String = context.out.path_join("library/" + id + ".res")
                    _write(path, family, report)
                    context.library[id] = path
            _:
                # Sprite, device and portal art is not drawn yet; its registration must still resolve.
                Common.asset(report, where, art.art.measurements)

static func _bank(context: Dictionary, art: Art, where: String) -> void:
    var report: Dictionary = context.report
    var source = art.art
    var value: Variant = _measured(context, where, source.measurements)
    if not value is Dictionary: return
    var bank: Dictionary = value
    bank.cell = _floats(source.cell)
    bank.rows = Array(source.direction_order)
    bank.scale = source.scale
    bank.frame_count = float(source.frames)
    if source.fps > 0.0: bank.fps = source.fps
    if not source.path.is_empty(): bank.path = runtime_path(source.path)
    if art.state_change_frame >= 0: bank.state_change_frame = float(art.state_change_frame)
    if art.clear_at_end: bank.clear_at_end = true
    if not art.camera_quarters.is_empty():
        var quarters := {}
        for pose in art.camera_quarters: quarters[pose] = float(art.camera_quarters[pose])
        bank.camera_quarter_by_pose = quarters
    for pose in source.direction_order:
        if bank.surface_frames_by_pose.get(pose, []).size() != source.frames: Common.error(report, where, "pose " + pose + " does not hold " + str(source.frames) + " surface frames")
        if bank.has("frames_by_pose") and bank.frames_by_pose.get(pose, []).size() != source.frames: Common.error(report, where, "pose " + pose + " does not hold " + str(source.frames) + " colour frames")
    if art.state_change_frame >= source.frames: Common.error(report, where, "state_change_frame outside the bank")
    _collect_paths(context, bank)
    _page(context, art.id, bank, where, art.paged)
    var path: String = context.out.path_join("banks/" + art.id + ".res")
    _write(path, bank, report)
    context.banks[art.id] = path

static func _images(context: Dictionary, art: Art, where: String) -> void:
    var report: Dictionary = context.report
    var source = art.art
    var measured: Variant = _measured(context, where, source.measurements)
    if not measured is Dictionary: return
    if art.images.size() != source.files.size(): Common.error(report, where, "images and files differ in count"); return
    for i in art.images.size():
        var image: String = art.images[i]
        if context.resources.has(image): Common.error(report, where, "image id used twice: " + image)
        var delivered: Dictionary = measured.get(image, {})
        var record := {"path": runtime_path(source.files[i])}
        if not delivered.has("native_size"): record.native_size = _floats(source.cell)
        if not delivered.has("pivot"): record.pivot = [float(source.pivot.x), float(source.pivot.y)]
        if not delivered.has("scale"): record.scale = source.scale
        record.merge(delivered, true)
        _collect_paths(context, record)
        context.resources[image] = record
    if source.fps > 0.0: context.animations[art.id] = {"frames": Array(art.images), "fps": source.fps}

## View -> image id of an images art entry (the first frame of each view).
static func _view_images(context: Dictionary, art_id: String, where: String) -> Dictionary:
    var art: Art = context.art.get(art_id)
    if art == null or art.kind != "images" or art.art.direction_order.is_empty():
        Common.error(context.report, where, "no per-view images art " + art_id); return {}
    var result := {}
    var frames: int = maxi(1, art.art.frames)
    for i in art.images.size():
        if i % frames == 0: result[art.art.direction_order[i / frames]] = art.images[i]
    return result

# --- receiving normals and texture pages ----------------------------------------

static func _receiving_normals(root: Resource, context: Dictionary) -> void:
    var shared: Resource = root.shared.get("receiving_normals")
    if shared == null: return
    var selection: Variant = _measured(context, "environment/shared/receiving_normals", shared.normals.get("quality", ""))
    if not selection is Dictionary: return
    for original in selection.normals:
        context.normals[original] = selection.normals[original]
        context.paths[selection.normals[original].path] = true

## Read only the PNG header to decide admission; small numeric banks are never decoded here.
static func _packet_header(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null or file.get_length() < 26: return {}
    if file.get_buffer(8) != PackedByteArray([137,80,78,71,13,10,26,10]): return {}
    file.big_endian = true
    file.seek(16)
    var size := Vector2i(file.get_32(), file.get_32())
    return {"size": size, "bits": file.get_8(), "colour_type": file.get_8()}

static func _header(context: Dictionary, path: String) -> Dictionary:
    if not context.packet_headers.has(path): context.packet_headers[path] = _packet_header(path)
    return context.packet_headers[path]

static func _page_eligible(header: Dictionary) -> bool:
    return not header.is_empty() and header.bits == 8 and header.colour_type == 6 and \
        header.size.x * header.size.y * 4 > PAGE_MIN_BYTES

static func _page(context: Dictionary, bank_id: String, bank: Dictionary, where: String, explicitly_paged: bool = false) -> void:
    var report: Dictionary = context.report
    var regions := {}
    for frames in bank.surface_frames_by_pose.values():
        for frame in frames:
            # Independent support masks keep their delivered R8 files. Aliases of
            # these numeric sources are remapped by the catalog, not repacked twice.
            for region in [frame.get("geometry_region", {}), frame.get("normal", {}).get("region", {})]:
                if region.is_empty(): continue
                if not regions.has(region.path): regions[region.path] = []
                regions[region.path].append(region.rect)
    var oversized: Array = []
    for path in regions:
        var selected: String = context.normals.get(path, {}).get("path", path)
        if _page_eligible(_header(context, path)) or _page_eligible(_header(context, selected)): oversized.append(path)
    if explicitly_paged and oversized.is_empty(): Common.error(report, where, "paged, but no RGBA8 numeric packet is larger than 16 MiB")
    for i in oversized.size():
        var original: String = oversized[i]
        var sizes := {}
        for rect in regions[original]: sizes[Vector2i(rect[2], rect[3])] = true
        if sizes.size() != 1: Common.error(report, where, "inconsistent cells in " + original); continue
        var cell: Vector2i = sizes.keys()[0]
        var folder: String = bank_id.trim_prefix("prop.").replace(".", "-") + ("/source-%03d" % i if oversized.size() > 1 else "")
        var selected: String = context.normals.get(original, {}).get("path", original)
        for pair in [[original, "original-depth"], [selected, "selected-normal"]]:
            var path: String = pair[0]
            var header := _header(context, path)
            if not _page_eligible(header): continue
            if not _whole_regions(header.size, cell, regions[original]):
                Common.error(report, where, "numeric regions do not fit unchanged whole cells: " + path); continue
            if context.layouts.has(path):
                if Vector2i(context.layouts[path].cell[0], context.layouts[path].cell[1]) != cell:
                    Common.error(report, where, "shared numeric source has inconsistent cell registration: " + path)
                continue
            var output: String = context.out.path_join("pages/" + folder + "/" + pair[1])
            # Existing source addresses survive generic activation and shared-bank ordering.
            if context.previous_layouts.has(path):
                var previous: Dictionary = context.previous_layouts[path]
                if previous.has("pages") and not previous.pages.is_empty(): output = str(previous.pages[0]).get_base_dir()
            var stamp := _page_stamp(path, cell)
            var cached: Dictionary = context.previous_page_cache.get(path, {})
            var layout: Dictionary = cached.get("layout", {}) if _page_cache_matches(cached, stamp, output) else {}
            if layout.is_empty(): layout = _paginate(path, cell, output, report, where)
            if layout.is_empty(): continue
            context.layouts[path] = layout
            context.page_cache[path] = {"stamp": stamp, "layout": layout, "outputs": _page_outputs(layout)}

static func _whole_regions(size: Vector2i, cell: Vector2i, regions: Array) -> bool:
    if cell.x <= 0 or cell.y <= 0 or cell.x > PAGE_SIZE.x or cell.y > PAGE_SIZE.y or size.x % cell.x != 0 or size.y % cell.y != 0: return false
    for rect in regions:
        if rect.size() != 4 or rect[0] < 0 or rect[1] < 0 or rect[0] != float(int(rect[0])) or rect[1] != float(int(rect[1])) or rect[2] != cell.x or rect[3] != cell.y or \
                int(rect[0]) % cell.x != 0 or int(rect[1]) % cell.y != 0 or rect[0] + rect[2] > size.x or rect[1] + rect[3] > size.y: return false
    return true

static func _file_stamp(path: String) -> Array:
    var file := FileAccess.open(path, FileAccess.READ)
    return [FileAccess.get_modified_time(path), file.get_length()] if file != null else []

static func _page_stamp(path: String, cell: Vector2i) -> Dictionary:
    return {"version": PAGE_CACHE_VERSION, "source": _file_stamp(path), "cell": _floats(cell), "page_size": _floats(PAGE_SIZE)}

static func _page_outputs(layout: Dictionary) -> Dictionary:
    var outputs := {}
    for path in layout.pages: outputs[path] = _file_stamp(path)
    return outputs

static func _page_cache_matches(cached: Dictionary, stamp: Dictionary, folder: String) -> bool:
    if cached.get("stamp", {}) != stamp or cached.get("layout", {}).get("pages", []).is_empty(): return false
    for path in cached.layout.pages:
        if str(path).get_base_dir() != folder or not FileAccess.file_exists(path) or \
                cached.get("outputs", {}).get(path, []) != _file_stamp(path): return false
    return true

static func _paginate(path: String, cell: Vector2i, folder: String, report: Dictionary, where: String, page_size: Vector2i = PAGE_SIZE) -> Dictionary:
    if cell.x <= 0 or cell.y <= 0 or cell.x > page_size.x or cell.y > page_size.y:
        Common.error(report, where, "cell does not fit numeric page: " + path); return {}
    var image := Image.load_from_file(ProjectSettings.globalize_path(path))
    if image == null or image.get_format() != Image.FORMAT_RGBA8 or image.get_width() % cell.x != 0 or image.get_height() % cell.y != 0:
        Common.error(report, where, "expected whole RGBA8 cells: " + path); return {}
    var source_columns := image.get_width() / cell.x
    var count := source_columns * (image.get_height() / cell.y)
    var columns := page_size.x / cell.x
    var rows := page_size.y / cell.y
    var per_page := columns * rows
    var size := Vector2i(columns * cell.x, rows * cell.y)
    DirAccess.make_dir_recursive_absolute(folder)
    var pages: Array = []
    for page in range(ceili(float(count) / per_page)):
        var result := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
        result.fill(Color.TRANSPARENT)
        var used := mini(per_page, count - page * per_page)
        for local in used:
            var cell_index := page * per_page + local
            result.blit_rect(image, Rect2i(Vector2i(cell_index % source_columns * cell.x, cell_index / source_columns * cell.y), cell), Vector2i(local % columns * cell.x, local / columns * cell.y))
        var file := folder.path_join("page-%03d.png" % page)
        if result.save_png(file) != OK:
            Common.error(report, where, "cannot save numeric page: " + file); return {}
        var saved := Image.load_from_file(ProjectSettings.globalize_path(file))
        if saved == null or saved.get_data() != result.get_data():
            Common.error(report, where, "saved numeric page changed RGBA bytes: " + file); return {}
        pages.append(file)
    return {"pages": pages, "source_size": [float(image.get_width()), float(image.get_height())], "size": _floats(size), "cell": _floats(cell),
        "source_columns": float(source_columns), "columns": float(columns), "cells_per_page": float(per_page), "verified_cells": float(count),
        "page_rgba_bytes": float(size.x * size.y * 4)}

# --- terrain and structures -----------------------------------------------------

static func _terrain(context: Dictionary, world: Dictionary, resources: Dictionary) -> void:
    var report: Dictionary = context.report
    world.terrain = {}
    for material in context.entries.terrain:
        var terrain: Terrain = context.entries.terrain[material]
        var where: String = "environment/terrain/" + material
        if terrain.material != material: Common.error(report, where, "material field says " + terrain.material)
        Common.cover(report, "tile_material", material, terrain.status)
        if not terrain.status in ["ready", "partial", "stand_in"]: continue
        if terrain.shader == "water":
            var floor: Art = context.art.get(terrain.floor)
            if floor == null or floor.images.size() != 1: Common.error(report, where, "water needs a single mask image"); continue
            var water := {"mask": floor.images[0]}
            for key in ["ripple", "normal"]:
                var image: String = terrain.water_images.get(key, "")
                if not context.resources.has(image): Common.error(report, where, "water " + key + " image missing: " + image)
                water[key] = image
            for key in terrain.water_look: water[key.to_camel_case()] = terrain.water_look[key]
            resources.water = water
            world.terrain[material] = {}
        else:
            world.terrain[material] = _view_images(context, terrain.floor, where)
        # Stairs and ramps stay in the source: the game maps no server surface_kind to them yet.
        for slope in terrain.slopes:
            if not slope.art.is_empty() and not context.art.has(slope.art): Common.error(report, where, "slope art missing: " + slope.art)

static func _structures(context: Dictionary, world: Dictionary, index: Dictionary) -> void:
    var report: Dictionary = context.report
    var kinds := {}
    var wall_faces: Variant = null
    for key in context.entries.structures:
        var structure: Structure = context.entries.structures[key]
        var where: String = "environment/structures/" + key
        if key != structure.structure + "/" + structure.material: Common.error(report, where, "key does not match structure/material")
        var rank: int = STATUSES.find(structure.status)
        if not kinds.has(structure.structure) or rank < kinds[structure.structure]: kinds[structure.structure] = rank
        if not structure.status in ["ready", "partial", "stand_in"]: continue
        var faces := {}
        for view in structure.corner_faces: faces[view] = Array(structure.corner_faces[view])
        match structure.structure:
            "wall", "retaining_wall", "door", "fence":
                var straight := _view_images(context, structure.straight, where)
                var corner := _view_images(context, structure.corner, where)
                var name: String = structure.material + "_wall_straight"
                if world.has(name):
                    if world[name] != straight or world[structure.material + "_wall_corner"] != corner or index.wall_destructions.get(structure.material, "") != structure.destruction:
                        Common.error(report, where, "the runtime draws one wall per material; this one differs from the other " + structure.material + " wall")
                    continue
                world[name] = straight
                world[structure.material + "_wall_corner"] = corner
                if wall_faces != null and wall_faces != faces: Common.error(report, where, "wall corner faces differ between materials")
                wall_faces = faces
                if not structure.destruction.is_empty():
                    if not context.banks.has(structure.destruction): Common.error(report, where, "destruction bank missing: " + structure.destruction)
                    index.wall_destructions[structure.material] = structure.destruction
            "cliff", "embankment":
                var cliff := {"straight": _view_images(context, structure.straight, where), "corner": _view_images(context, structure.corner, where), "corner_faces": faces}
                if world.has("terrain_cliff") and world.terrain_cliff != cliff: Common.error(report, where, "the runtime draws one cliff set; this one differs")
                world.terrain_cliff = cliff
    if wall_faces != null: world.wall_corner_faces = wall_faces
    for kind in kinds: Common.cover(report, "boundary_structure", kind, STATUSES[kinds[kind]])

# --- objects -------------------------------------------------------------------

static func _objects(context: Dictionary, world: Dictionary, index: Dictionary) -> void:
    var report: Dictionary = context.report
    world.props = {}
    for id in context.entries.library:
        for art in context.entries.library[id].art:
            if not context.art.has(art): Common.error(report, "environment/library/" + id, "art missing: " + art)
    for id in context.entries.objects:
        var object: EnvironmentObject = context.entries.objects[id]
        var where: String = "environment/objects/" + id
        if object.id != id: Common.error(report, where, "id field says " + object.id)
        Common.cover(report, "environment_object", id, object.status)
        Common.asset(report, where, object.measurements)
        for art in object.art:
            if not context.art.has(art): Common.error(report, where, "art missing: " + art)
        for state in object.states:
            var bank: String = object.states[state].bank
            if not bank.is_empty() and not context.banks.has(bank): Common.error(report, where, "state " + state + " bank missing: " + bank)
            elif not bank.is_empty() and object.states[state].frame >= context.art[bank].art.frames: Common.error(report, where, "state " + state + " frame outside its bank")
        for key in object.destructions:
            if not context.banks.has(object.destructions[key]): Common.error(report, where, "destruction bank missing: " + object.destructions[key])
        for wreck in object.wrecks:
            index.wrecks[wreck] = {"source_item_id": id}
            if not object.wrecks[wreck].is_empty(): index.wrecks[wreck].outcome = object.wrecks[wreck]
        if object.transitions.any(func(t): return not t.images.is_empty()): index.inspection.world_animation[id] = {}
        if Array(object.art).any(func(art): return context.art.has(art) and context.art[art].kind == "device"): index.inspection.device[id] = {}
        if object.states.is_empty(): continue
        match object.kind:
            "door": index.doors[id] = _door(context, object, where)
            "trap": index.traps[id] = _trap(context, object, where)
            _:
                if object.states.values()[0].bank.is_empty(): world.props[id] = _fixture(context, object, where)
                else: index.props[id] = _prop(context, object, where)
    # Objects with no art of their own are drawn, silently, by their stand-in's art.
    for id in context.entries.objects:
        var object: EnvironmentObject = context.entries.objects[id]
        if object.stand_in.is_empty(): continue
        var where: String = "environment/objects/" + id
        if not object.states.is_empty(): Common.error(report, where, "has its own states and a stand-in"); continue
        var drawn := false
        for family in [index.doors, index.props, index.traps, world.props]:
            if family.has(object.stand_in): family[id] = family[object.stand_in]; drawn = true
        if not drawn: Common.error(report, where, "stand-in " + object.stand_in + " draws nothing")

static func _door(context: Dictionary, object: EnvironmentObject, where: String) -> Dictionary:
    var closed = object.states.get("closed")
    var outward = object.states.get("open.outward")
    var inward = object.states.get("open.inward")
    if closed == null or outward == null or inward == null or closed.bank != outward.bank or closed.frame != 0 or outward.frame != -1 or inward.frame != -1:
        Common.error(context.report, where, "the runtime draws a door as closed = the outward bank's first frame and open = the swing's bank at its last frame")
        return {}
    var frame := {}
    for part in object.parts:
        if part.role != "frame": continue
        for view in part.images:
            if not context.resources.has(part.images[view]): Common.error(context.report, where, "frame image missing: " + part.images[view])
            frame[view] = part.images[view]
    return {"openings": {"outward": outward.bank, "inward": inward.bank}, "destructions": _plain(object.destructions), "frame_resource_by_pose": frame}

static func _trap(context: Dictionary, object: EnvironmentObject, where: String) -> Dictionary:
    var bank: String = object.states.values()[0].bank
    var frames := {}
    for state in object.states:
        if object.states[state].bank != bank: Common.error(context.report, where, "the runtime draws every trap state from one bank")
        frames[state] = float(object.states[state].frame)
    return {"intact": bank, "state_frames": frames, "destructions": _plain(object.destructions)}

static func _prop(context: Dictionary, object: EnvironmentObject, where: String) -> Dictionary:
    var owner := {"intact": {}, "destructions": _plain(object.destructions)}
    if not object.select_field.is_empty(): owner.state_field = object.select_field
    for state in object.states:
        if object.states[state].frame != 0: Common.error(context.report, where, "the runtime rests props on their first frame")
        owner.intact[state] = object.states[state].bank
    if not object.destructions_without_attachments.is_empty(): owner.destructions_without_attachments = _plain(object.destructions_without_attachments)
    if not object.hit_masks.is_empty():
        var masks := {}
        for view in object.hit_masks:
            var ref = object.hit_masks[view]
            Common.asset(context.report, where, ref.path)
            masks[view] = {"path": runtime_path(ref.path), "rect": [float(ref.rect.position.x), float(ref.rect.position.y), float(ref.rect.size.x), float(ref.rect.size.y)]}
        owner.selection_masks_by_pose = masks
    if object.flat_ground: owner.flat_ground = true
    return owner

static func _fixture(context: Dictionary, object: EnvironmentObject, where: String) -> Dictionary:
    var resting = object.states.get("default", object.states.get("false"))
    if resting == null: Common.error(context.report, where, "a fixture needs a default or false state"); return {}
    var fixture := {"body_by_pose": _plain(resting.images), "lit_animation": object.flame if not object.flame.is_empty() else null}
    if not object.select_field.is_empty():
        fixture.state_field = object.select_field
        fixture.active_body_by_pose = _plain(object.states.get("true", resting).images)
    for state in object.states:
        for view in object.states[state].images:
            if not context.resources.has(object.states[state].images[view]): Common.error(context.report, where, "image missing: " + object.states[state].images[view])
    if not object.flame.is_empty() and not context.animations.has(object.flame): Common.error(context.report, where, "flame animation missing: " + object.flame)
    if not object.light.is_empty() and not context.entries.lighting.has(object.light): Common.error(context.report, where, "light appearance missing: " + object.light)
    return fixture

# --- surfaces and lighting ---------------------------------------------------------

static func _surfaces(context: Dictionary, index: Dictionary) -> void:
    var report: Dictionary = context.report
    for id in context.entries.surfaces:
        var surface: Ground = context.entries.surfaces[id]
        var where: String = "environment/surfaces/" + id
        if surface.id != id: Common.error(report, where, "id field says " + surface.id)
        if surface.source_kind == "spatial_effect": Common.cover(report, "spatial_effect", id, surface.status)
        elif surface.source_kind == "residue": Common.cover(report, "residue", id, surface.status)
        for art in surface.art:
            if not context.art.has(art): Common.error(report, where, "art missing: " + art)
        # Old presentation blocks the Studio's coverage and requirement views still list.
        var legacy: Variant = _measured(context, where, surface.legacy)
        if legacy is Dictionary:
            if legacy.has("spatial_media"): index.spatial_media[id] = legacy.spatial_media
            if legacy.has("spatial_effects"): index.inspection.world_animation[id] = {}
        if Array(surface.art).any(func(art): return context.art.has(art) and context.art[art].kind == "portal"): index.inspection.portal[id] = {}
        var uses: Array = [surface.lasting, surface.appear, surface.disappear, surface.spread]
        for operation in surface.operations:
            uses.append(operation.transition)
            for other in [operation.becomes, operation.also_creates]:
                if not other.is_empty() and not context.entries.surfaces.has(other): Common.error(report, where, operation.operation + " names an unknown surface " + other)
        for use in uses:
            if use == null or use.selection.is_empty(): continue
            if not context.selections.has(use.selection): Common.error(report, where, "Factory selection missing: " + use.selection); continue
            if not use.clip.is_empty() and not context.selections[use.selection].get("clips", []).has(use.clip): Common.error(report, where, "clip " + use.clip + " is not in selection " + use.selection)
        if id != "residue.blood": continue
        var value: Variant = _measured(context, where, surface.region_particles)
        if not value is Dictionary: Common.error(report, where, "residue.blood has no region particles"); continue
        var asset := AssetMetadata.new()
        asset.asset_id = "particles.region.blood"
        asset.value = value
        DirAccess.make_dir_recursive_absolute(context.out.path_join("residues"))
        if ResourceSaver.save(asset, context.out.path_join("residues/blood.res")) != OK: Common.error(report, where, "cannot save the blood particles")
    for layer in ["ground_surface", "cloud", "field"]: Common.cover(report, "spatial_effect_layer", layer, "internal")

static func _lighting(context: Dictionary, world: Dictionary) -> void:
    var report: Dictionary = context.report
    var lighting: Lighting = context.entries.lighting.get("lighting")
    var torch: LightAppearance = context.entries.lighting.get("torch")
    if lighting == null or torch == null: Common.error(report, "environment/lighting", "the lighting entry and the torch appearance are required"); return
    Common.asset(report, "environment/lighting/lighting", lighting.fallback_cookie)
    for id in context.entries.lighting:
        if id == "lighting": continue
        Common.asset(report, "environment/lighting/" + id, context.entries.lighting[id].cookie)
        Common.cover(report, "light_appearance", id, context.entries.lighting[id].status)
    var directional: Array = []
    for source in lighting.directional: directional.append(_plain(source))
    world.lighting = {"directionalSources": directional}
    var ranges := LightRanges.new()
    ranges.very_bright_edge = lighting.very_bright_edge
    ranges.bright_edge = lighting.bright_edge
    if ResourceSaver.save(ranges, context.out.path_join("light_ranges.res")) != OK: Common.error(report, "environment/lighting", "cannot save the light ranges")
    _write(context.out.path_join("lighting.res"), {"torch_colour": torch.colour, "torch_item_ids": Array(torch.item_ids),
        "carried_lift_steps": torch.carried_height_steps, "unregistered_lift_steps": lighting.unregistered_height_steps,
        "fallback_cookie": runtime_path(lighting.fallback_cookie)}, report)
    # Measured flame energy and emission centre, per frame of every lit fixture's flame.
    var facts := Facts.new()
    var flames := {}
    for id in context.entries.objects:
        if not context.entries.objects[id].flame.is_empty(): flames[context.entries.objects[id].flame] = true
    for flame in flames:
        for image in context.animations.get(flame, {}).get("frames", []):
            var path: String = context.resources[image].path
            if facts.frames.has(path): continue
            var decoded := Image.load_from_file(ProjectSettings.globalize_path(path))
            if decoded == null or decoded.is_empty(): Common.error(report, "environment/lighting", "cannot read flame frame " + path); continue
            facts.frames[path] = Media.fixture_facts(decoded)
    if ResourceSaver.save(facts, context.out.path_join("fixture_optics.res")) != OK: Common.error(report, "environment/lighting", "cannot save the fixture optics")
