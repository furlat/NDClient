extends RefCounted
# Source enumeration for disclosed live rows. This is metadata preparation;
# no rasterization, geometry inference, or Godot scene/texture creation occurs.
const Catalog = preload("res://source_catalog.gd")
const WorldRows = preload("res://presentation/world.gd")
const Placement = preload("res://placement.gd")

static func record_paths(record: Dictionary, paths: Dictionary, cache: Dictionary) -> void:
    if record.is_empty(): return
    paths[record.path] = true
    for field in ["geometry_region","hit_mask","door_partition"]:
        if record.has(field): paths[record[field].path] = true
    if record.has("normal"): paths[record.normal.region.path] = true
    for role in record.get("roles",[]):
        if role.selection.kind == "mask": paths[role.selection.mask.region.path] = true
    if record.has("water"):
        paths[Catalog.read_file("assets.json",cache).resources[record.water.ripple].path] = true

static func animation_pages(row: Dictionary, cache: Dictionary) -> Dictionary:
    # Only the explicit finite workshop destruction bank needs its entire page
    # closure. Ordinary live after-values retain row_paths' selected endpoint.
    # Enumerate source records, not time steps, so authored irregular clocks and
    # every camera pose remain covered without inventing a playback phase.
    var paths = {}
    var errors: Array = []
    var source: Dictionary = row.get("break_owner",row)
    if source.has("source_sprite"): return {"paths":paths,"errors":errors}
    var bank_id = Catalog.bank_for(source,true,cache)
    if bank_id.is_empty(): return {"paths":paths,"errors":errors}
    var bank: Dictionary = Catalog.bank_data(bank_id,cache)
    var layouts = Catalog.texture_layouts(cache)
    for frames in bank.surface_frames_by_pose.values():
        for frame in frames:
            var record = Catalog.receiving_normal(frame,cache)
            for region in [record.get("geometry_region",{}),record.get("normal",{}).get("region",{})]:
                var layout: Dictionary = layouts.get(region.get("path",""),{})
                if not layout.has("pages"): continue
                var selected = Catalog._layout_region(region,layouts)
                if selected.is_empty(): errors.append("Invalid animation texture page region: "+str(region))
                else: paths[selected.path] = true
    return {"paths":paths,"errors":errors}

static func row_paths(row: Dictionary, cache: Dictionary) -> Dictionary:
    # Live source selection depends on these authored selectors, not ID/contact.
    # Repeated tiles/walls in large rooms share a finite original source set.
    var key = JSON.stringify([row.kind,row.get("material"),row.get("asset"),row.get("orientation"),
        row.get("state"),row.get("boundaries",[]),row.get("views"),row.get("lit_animation"),
        row.get("destroyed",false),row.get("outcome")])
    if not cache.has("__live_media_sources"): cache.__live_media_sources = {}
    if cache.__live_media_sources.has(key): return cache.__live_media_sources[key]
    var paths = {}
    for quarter in range(4):
        var source: Dictionary = row.duplicate()
        if source.has("views"): source.asset = source.views[Placement.pose(source.orientation,quarter)]
        record_paths(Catalog.environment(source,quarter,cache),paths,cache)
        if row.kind == "door": record_paths(Catalog.door_frame(source,quarter,cache),paths,cache)
    if row.has("lit_animation"):
        var assets = Catalog.read_file("assets.json",cache)
        if not cache.has("__live_fixture_frames"): cache.__live_fixture_frames = {}
        for frame in assets.animations[row.lit_animation].frames:
            var path: String = assets.resources[frame].path
            paths[path] = true
            cache.__live_fixture_frames[path] = true
    cache.__live_media_sources[key] = paths
    return paths

static func _collect(state: Dictionary, paths: Dictionary, cache: Dictionary) -> void:
    var rows = WorldRows.rows(state,cache)
    for row in rows.visual_rows:
        paths.merge(row_paths(row,cache))
        # Hidden corners and Ctrl picks use the original straight members.
        for member in row.get("wall_members",[]): paths.merge(row_paths(member,cache))

static func _cell(object: Dictionary) -> String:
    return WorldRows.cell_key(object.placement.position)

static func _index(cache: Dictionary) -> Dictionary:
    if not cache.has("__environment_demand_index"):
        cache.__environment_demand_index = {"tiles":{},"objects":{},"visual":{},"cells":{},"tile_paths":{},"cell_paths":{},
            "contacts":{},"tile_materials":{},"changed_row_builds":0,"plans":0}
    return cache.__environment_demand_index

static func _update(index: Dictionary, tiles: Dictionary, objects: Dictionary, removed: Array,
        senses: Variant, cache: Dictionary) -> Dictionary:
    var changed_paths = {}
    var contacts: Dictionary = senses.get("objects",{}) if senses != null else {}
    var cells = {}
    for key in tiles:
        var tile: Dictionary = tiles[key]
        var material: String = tile.surface.base_material
        index.tiles[key] = tile
        # WorldRows terrain rows have fixed orientation/boundaries; row_paths
        # selects their sheets only by base material. Contact/elevation/light
        # still reach the world renderer, but cannot change this source closure.
        if index.tile_materials.get(key)==material: continue
        index.tile_materials[key] = material
        var paths = {}
        _collect({"tiles":{key:tiles[key]},"objects":{},"senses":senses},paths,cache)
        index.tile_paths[key] = paths
        changed_paths.merge(paths)
        index.changed_row_builds += 1
    for id in removed:
        if not index.objects.has(id): continue
        var old_cell = _cell(index.objects[id])
        cells[old_cell] = true
        index.cells[old_cell].erase(id)
        index.objects.erase(id); index.visual.erase(id)
    for id in objects:
        var visual = contacts.get(id,{}).get("visual",false)
        if index.objects.get(id)==objects[id] and index.visual.get(id)==visual: continue
        if index.objects.has(id):
            var old_cell = _cell(index.objects[id])
            index.cells[old_cell].erase(id); cells[old_cell] = true
        var cell = _cell(objects[id])
        if not index.cells.has(cell): index.cells[cell] = {}
        index.cells[cell][id] = objects[id]
        index.objects[id] = objects[id]; index.visual[id] = visual
        cells[cell] = true
    # Sense-only commits can switch a registered fixture animation. No terrain
    # or wall-source selection depends on the full visible-tile list.
    if index.contacts != contacts:
        for id in index.objects:
            var visual = contacts.get(id,{}).get("visual",false)
            if index.visual.get(id)==visual: continue
            index.visual[id] = visual; cells[_cell(index.objects[id])] = true
    index.contacts = contacts
    for cell in cells:
        var members: Dictionary = index.cells[cell]
        if members.is_empty(): index.cells.erase(cell); index.cell_paths.erase(cell); continue
        var paths = {}
        _collect({"tiles":{},"objects":members,"senses":senses},paths,cache)
        index.cell_paths[cell] = paths
        changed_paths.merge(paths)
        index.changed_row_builds += members.size()
    return changed_paths

static func _all_paths(index: Dictionary) -> Dictionary:
    var paths = {}
    for values in [index.tile_paths,index.cell_paths]:
        for closure in values.values(): paths.merge(closure)
    return paths

static func plan(state: Dictionary, groups: Array, cache: Dictionary) -> Dictionary:
    var required = {}
    var upcoming = {}
    if state.is_empty(): return {"required":required,"upcoming":upcoming,"fixtures":{},"disclosed":{}}
    var phase_started = Time.get_ticks_usec()
    var phases = {"initial_update":0.0,"all_paths":0.0,"commit_updates":0.0}
    var index = _index(cache)
    index.plans += 1
    # Index only the last requested map, never historical worlds. Full table
    # comparison happens once per plan; expensive row/join conversion happens
    # only for changed records and their original shared wall cell.
    for key in index.tiles.keys():
        if not state.tiles.has(key): index.tiles.erase(key); index.tile_paths.erase(key); index.tile_materials.erase(key)
    var removed: Array = []
    for id in index.objects:
        if not state.objects.has(id): removed.append(id)
    var senses: Variant = state.senses
    _update(index,state.tiles,state.objects,removed,senses,cache)
    phases.initial_update = (Time.get_ticks_usec()-phase_started)/1000.0
    phase_started = Time.get_ticks_usec()
    required = _all_paths(index)
    phases.all_paths += (Time.get_ticks_usec()-phase_started)/1000.0
    var disclosed: Dictionary = required.duplicate()
    for group_index in range(groups.size()):
        var paths: Dictionary = required if group_index==0 else upcoming
        if group_index>0:
            phase_started = Time.get_ticks_usec()
            paths.merge(_all_paths(index))
            phases.all_paths += (Time.get_ticks_usec()-phase_started)/1000.0
        phase_started = Time.get_ticks_usec()
        var group: Dictionary = groups[group_index]
        for key in group.get("staged_tiles",{}):
            if not index.tiles.has(key):
                _collect({"tiles":{key:group.staged_tiles[key]},"objects":{},"senses":senses},paths,cache)
        for commit in group.get("commits",[]):
            var delta: Dictionary = commit.delta
            if delta.get("tiles",{}).is_empty() and delta.get("objects",{}).is_empty() and delta.get("objects_removed",[]).is_empty() and not delta.get("set",{}).has("senses"): continue
            senses = delta.get("set",{}).get("senses",senses)
            # Existing paths were included at group entry. Add only changed
            # closures, preserving the exhaustive within-group union.
            paths.merge(_update(index,delta.get("tiles",{}),delta.get("objects",{}),delta.get("objects_removed",[]),senses,cache))
        phases.commit_updates += (Time.get_ticks_usec()-phase_started)/1000.0
    var fixtures = {}
    for paths in [required,upcoming]:
        for path in paths:
            if cache.get("__live_fixture_frames",{}).has(path): fixtures[path] = true
    return {"required":required,"upcoming":upcoming,"fixtures":fixtures,"disclosed":disclosed,
        "diagnostics":{"plans":index.plans,"changed_row_builds":index.changed_row_builds,"phases":phases}}
