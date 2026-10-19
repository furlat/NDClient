extends RefCounted
# Source enumeration for disclosed live rows. This is metadata preparation;
# no rasterization, geometry inference, or Godot scene/texture creation occurs.
const Catalog = preload("res://source_catalog.gd")
const WorldRows = preload("res://presentation/world.gd")
const Placement = preload("res://placement.gd")
const EncounterMedia=preload("res://presentation/encounter_media.gd")

static func record_paths(record: Dictionary, paths: Dictionary, cache: Dictionary) -> void:
    if record.is_empty(): return
    paths[record.path] = true
    for field in ["geometry_region","hit_mask","door_partition"]:
        if record.has(field): paths[record[field].path] = true
    if record.has("normal"): paths[record.normal.region.path] = true
    for role in record.get("roles",[]):
        if role.selection.kind == "mask": paths[role.selection.mask.region.path] = true
    if record.has("water"):
        paths[Catalog.environment_resources(cache).resources[record.water.ripple].path] = true

static func animation_pages(row: Dictionary, cache: Dictionary) -> Dictionary:
    # Only the explicit finite workshop destruction bank needs its entire page
    # closure. Ordinary live after-values retain row_paths' selected endpoint.
    # Enumerate source records, not time steps, so authored irregular clocks and
    # every camera pose remain covered without inventing a playback phase.
    var paths = {}
    var errors: Array = []
    var bank_id = Catalog.bank_for(row,true,cache)
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
        var assets = Catalog.environment_resources(cache)
        if not cache.has("__live_fixture_frames"): cache.__live_fixture_frames = {}
        for frame in assets.animations[row.lit_animation].frames:
            var path: String = assets.resources[frame].path
            paths[path] = true
            if not cache.__live_fixture_frames.has(path):cache.__live_fixture_revision=int(cache.get("__live_fixture_revision",0))+1
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
            "contacts":{},"senses":null,"tile_materials":{},"changed_row_builds":0,"plans":0,"paths_dirty":true,"paths":{}}
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
        index.paths_dirty=true
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
    index.contacts = contacts;index.senses=senses
    for cell in cells:
        var members: Dictionary = index.cells[cell]
        if members.is_empty():
            index.cells.erase(cell)
            if index.cell_paths.erase(cell):index.paths_dirty=true
            continue
        var paths = {}
        _collect({"tiles":{},"objects":members,"senses":senses},paths,cache)
        var previous:Dictionary=index.cell_paths.get(cell,{})
        if previous.keys()!=paths.keys():
            paths.make_read_only();index.cell_paths[cell]=paths;index.paths_dirty=true
        changed_paths.merge(paths)
        index.changed_row_builds += members.size()
    return changed_paths

static func _all_paths(index: Dictionary) -> Dictionary:
    if not index.get("paths_dirty",true):return index.paths
    var paths = {}
    # Terrain source selection is keyed solely by base material above. Merge
    # its first disclosed closure once, preserving the original path order.
    var materials = {}
    for key in index.tile_paths:
        var material: String = index.tile_materials[key]
        if materials.has(material): continue
        materials[material] = true
        paths.merge(index.tile_paths[key])
    for closure in index.cell_paths.values(): paths.merge(closure)
    paths.make_read_only();index.paths=paths;index.paths_dirty=false
    return paths

static func _extend_paths(paths:Dictionary,extra:Dictionary)->Dictionary:
    var added:bool=false
    for path in extra:
        if not paths.has(path):added=true;break
    if not added:return paths
    if paths.is_read_only():paths=paths.duplicate()
    paths.merge(extra)
    return paths

static func _first_use(initial: Dictionary, times: Dictionary, paths: Dictionary, at_ms: float) -> void:
    for path in paths:
        if not initial.has(path): times[path] = minf(float(times.get(path,at_ms)),at_ms)

static func _timeline(initial: Dictionary, times: Dictionary) -> Dictionary:
    if not initial.is_read_only():initial = initial.duplicate()
    var by_time = {}
    for path in times:
        var at_ms: float = times[path]
        if at_ms <= 0:
            if not initial.has(path):
                if initial.is_read_only():initial=initial.duplicate()
                initial[path]=true
            continue
        if not by_time.has(at_ms): by_time[at_ms] = {}
        by_time[at_ms][path] = true
    var keys: Array = by_time.keys(); keys.sort()
    var changes: Array = []
    initial.make_read_only()
    var cumulative: Dictionary = initial
    for at_ms in keys:
        cumulative = cumulative.duplicate()
        cumulative.merge(by_time[at_ms])
        cumulative.make_read_only()
        changes.append({"at_ms":at_ms,"paths":cumulative})
    return {"initial":initial,"changes":changes}

static func required_at(schedule: Dictionary, local_ms: float, fallback: Dictionary = {}) -> Dictionary:
    # Older/unassessed plans retain the complete readiness gate. Source loading
    # still owns the full group union; only its first-use gate is time-specific.
    if not schedule.has("initial") or not schedule.has("changes"): return fallback
    var paths: Dictionary = schedule.initial
    for change in schedule.changes:
        if float(change.at_ms) > local_ms + 0.000001: break
        paths = change.paths
    return paths

static func _role_records(paths:Dictionary,fixtures:Dictionary,previous:Dictionary,retained:Dictionary,reuse:Dictionary)->Dictionary:
    for set in reuse.previous:
        if is_same(set.paths,paths) and set.fixture_revision==reuse.fixture_revision:
            reuse.current.append(set)
            for record in set.records:retained[record.source_id]=record
            return set
    var records:Array=[]
    for path in paths:
        var fixture:bool=fixtures.has(path)
        var identity:StringName=StringName("environment:"+path+"#fixture:"+str(int(fixture)))
        var record:Dictionary=retained.get(identity,previous.get(identity,{}))
        if record.is_empty():
            var role:Array=[Catalog.media_path(path),1,int(fixture),1];role.make_read_only()
            var roles:Dictionary={path:role};roles.make_read_only()
            record={"source_id":identity,"roles":roles};record.make_read_only()
        retained[identity]=record;records.append(record)
    records.make_read_only()
    var sizes:Dictionary=EncounterMedia.source_sizes(paths,reuse.cache);sizes.make_read_only()
    var absolute:Dictionary={};var cpu:Dictionary={};var selected_fixtures:Dictionary={}
    for record in records:
        for path in record.roles:
            absolute[path]=record.roles[path][0];cpu[path]=true
            if fixtures.has(path):selected_fixtures[path]=true
    var ordered:Array=absolute.keys();ordered.make_read_only()
    for values in [absolute,cpu,selected_fixtures]:values.make_read_only()
    var gpu:Dictionary={};gpu.make_read_only()
    var family:Dictionary={"paths":absolute,"environment":cpu,"fixtures":selected_fixtures,"cpu_required":cpu,
        "gpu_only":gpu,"ordered_paths":ordered,"source_sizes":sizes};family.make_read_only()
    var set:Dictionary={"paths":paths,"fixture_revision":reuse.fixture_revision,"records":records,"source_sizes":sizes,"family":family,
        "source_headers":EncounterMedia.source_headers(paths,reuse.cache)}
    reuse.current.append(set)
    return set

static func plan(state: Dictionary, groups: Array, cache: Dictionary, origin_state: Dictionary = {}, final_state: Dictionary = {}, partial: bool = false) -> Dictionary:
    var required = {}
    var upcoming = {}
    var environment_timeline = {}
    if state.is_empty(): return {"required":required,"upcoming":upcoming,"fixtures":{},"disclosed":{},"environment_timeline":environment_timeline,
        "required_records":[],"upcoming_records":[],"source_sizes":{},"source_headers":{}}
    var phase_started = Time.get_ticks_usec()
    var phases = {"initial_update":0.0,"all_paths":0.0,"commit_updates":0.0}
    var index = _index(cache)
    index.plans += 1
    # Only the session's immutable canonical owner can prove continuity. A
    # shallow worker snapshot alone cannot prove the previous full operation
    # was planned. Optional/non-session/interleaved plans invalidate this proof.
    var skip_initial: bool = groups.size()<=2 and not origin_state.is_empty() and is_same(index.get("final_owner",{}),origin_state)
    index.erase("final_owner")
    var senses: Variant = state.senses
    if not skip_initial:
        for key in index.tiles.keys():
            if not state.tiles.has(key):
                index.tiles.erase(key); index.tile_paths.erase(key); index.tile_materials.erase(key);index.paths_dirty=true
        var removed: Array = []
        for id in index.objects:
            if not state.objects.has(id): removed.append(id)
        _update(index,state.tiles,state.objects,removed,senses,cache)
    phases.initial_update = (Time.get_ticks_usec()-phase_started)/1000.0
    phase_started = Time.get_ticks_usec()
    required = _all_paths(index)
    phases.all_paths += (Time.get_ticks_usec()-phase_started)/1000.0
    var disclosed: Dictionary = required
    var applied_world_delta:bool=false
    for group_index in range(groups.size()):
        var paths: Dictionary = required if group_index==0 else upcoming
        var initial: Dictionary = disclosed
        if group_index>0:
            phase_started = Time.get_ticks_usec()
            initial = _all_paths(index)
            paths=_extend_paths(paths,initial)
            phases.all_paths += (Time.get_ticks_usec()-phase_started)/1000.0
        phase_started = Time.get_ticks_usec()
        var group: Dictionary = groups[group_index]
        var first_use = {}
        for key in group.get("staged_tiles",{}):
            if not index.tiles.has(key):
                var staged_paths = {}
                _collect({"tiles":{key:group.staged_tiles[key]},"objects":{},"senses":senses},staged_paths,cache)
                paths=_extend_paths(paths,staged_paths)
                _first_use(initial,first_use,staged_paths,float(group.get("staged_tile_at_ms",{}).get(key,0.0)))
        for commit in group.get("commits",[]):
            var delta: Dictionary = commit.delta
            if delta.get("tiles",{}).is_empty() and delta.get("objects",{}).is_empty() and delta.get("objects_removed",[]).is_empty() and not delta.get("set",{}).has("senses"): continue
            applied_world_delta=true
            senses = delta.get("set",{}).get("senses",senses)
            # Existing paths were included at group entry. Add only changed
            # closures, preserving the exhaustive within-group union.
            var changed_paths = _update(index,delta.get("tiles",{}),delta.get("objects",{}),delta.get("objects_removed",[]),senses,cache)
            paths=_extend_paths(paths,changed_paths)
            _first_use(initial,first_use,changed_paths,float(commit.get("at_ms",0.0)))
        if group.has("id"): environment_timeline[group.id] = _timeline(initial,first_use)
        if group_index==0:required=paths
        else:upcoming=paths
        phases.commit_updates += (Time.get_ticks_usec()-phase_started)/1000.0
    if groups.size()<=2 and not final_state.is_empty() and not origin_state.is_empty(): index.final_owner = final_state
    elif partial and not origin_state.is_empty() and not applied_world_delta:
        # Initial synchronization establishes this exact canonical origin.
        # Staged source enumeration does not advance the index; the full
        # continuation can reuse it without walking the room again.
        index.final_owner=origin_state
    var fixtures = {}
    required.make_read_only();upcoming.make_read_only()
    for paths in [required,upcoming]:
        for path in paths:
            if cache.get("__live_fixture_frames",{}).has(path): fixtures[path] = true
    # The same producer owns finite physical source-role refs. An opening cut
    # borrows the previous complete map; only full continuation retires extras.
    var previous:Dictionary=cache.get("__environment_source_records",{})
    var retained:Dictionary=previous.duplicate() if partial else {}
    var reuse:Dictionary={"previous":cache.get("__environment_source_sets",[]),"current":[],"fixture_revision":int(cache.get("__live_fixture_revision",0)),"cache":cache}
    var required_set:Dictionary=_role_records(required,fixtures,previous,retained,reuse)
    var upcoming_set:Dictionary=_role_records(upcoming,fixtures,previous,retained,reuse)
    cache.__environment_source_sets=reuse.current
    var sizes:Dictionary=required_set.source_sizes
    var headers:Dictionary=required_set.source_headers
    if not upcoming_set.paths.is_empty():
        var previous_sizes:Dictionary=required_set.get("size_union",{})
        if is_same(previous_sizes.get("upcoming"),upcoming_set.source_sizes):
            sizes=previous_sizes.value;headers=previous_sizes.headers
        else:
            sizes=sizes.duplicate();sizes.merge(upcoming_set.source_sizes);sizes.make_read_only()
            headers=headers.duplicate();headers.merge(upcoming_set.source_headers);headers.make_read_only()
            required_set.size_union={"upcoming":upcoming_set.source_sizes,"value":sizes,"headers":headers}
    retained.make_read_only();cache.__environment_source_records=retained
    return {"required":required,"upcoming":upcoming,"required_records":required_set.records,"upcoming_records":upcoming_set.records,"source_sizes":sizes,"source_headers":headers,
        "required_family":required_set.family,"upcoming_family":upcoming_set.family,
        "fixtures":fixtures,"disclosed":disclosed,"environment_timeline":environment_timeline,
        "diagnostics":{"plans":index.plans,"changed_row_builds":index.changed_row_builds,"skipped_initial":skip_initial,"phases":phases}}

static func finish_handoff(groups:Array,final_state:Dictionary,cache:Dictionary)->void:
    if final_state.is_empty():return
    # The selected display prefix has its own immutable source cuts. Advance
    # only remaining authoritative world deltas in this private selector index
    # so the next operation can borrow its exact canonical starting owner.
    var index:Dictionary=_index(cache)
    var senses:Variant=index.senses
    for group in groups:
        for commit in group.get("commits",[]):
            var delta:Dictionary=commit.delta
            if delta.get("tiles",{}).is_empty() and delta.get("objects",{}).is_empty() and delta.get("objects_removed",[]).is_empty() and not delta.get("set",{}).has("senses"):continue
            senses=delta.get("set",{}).get("senses",senses)
            _update(index,delta.get("tiles",{}),delta.get("objects",{}),delta.get("objects_removed",[]),senses,cache)
    # Retain the selected final source union with its private canonical owner.
    # The next operation borrows it; it does not rebuild a room-sized union on
    # the opening path merely because this operation changed a few cells.
    _all_paths(index)
    index.final_owner=final_state
