extends "res://presentation/sprite_sources.gd"
# One unpublished world boundary. Worker owns passive projection/buffers;
# the scene thread builds changed native groups and owns hidden atlas receivers.
const WorldRows = preload("res://presentation/world.gd")
const Characters = preload("res://presentation/characters.gd")
const ActorConstruction = preload("res://presentation/actor_construction.gd")
const GroundData = preload("res://presentation/ground_data.gd")
const WallReveal = preload("res://presentation/wall_reveal.gd")
const AtlasDelta = preload("res://presentation/native_light_delta.gd")
const GroundReceiving = preload("res://presentation/ground_receiving.gd")
const SourceLighting = preload("res://presentation/lighting_2d.gd")
var host: Node
var boundary: Dictionary = {}
var epoch = -1
var task = -1
var result: Dictionary = {}
var native_groups: Dictionary = {}
var native_ground: Dictionary = {}
var native_actors: Dictionary = {}
var actor_ids: Array = []
var actor_cursor: int = 0
var actor_catalog_owner: Dictionary = {}
var actor_bases:Dictionary={}
var light_preparation:Dictionary={}
var cookie_source_cursor:int=0
var cookie_image_cursor:int=0
var cookie_jobs:Array=[]
var cookie_seen:Dictionary={}
var wanted_ids: Array = []
var ground_keys: Array = []
var cursor = 0
var ground_cursor = 0
var ground_job: Dictionary = {}
var prepared = false
var admitted = false
var stale = false
var initial = false
var phase = "projection"
var created_count = 0
var order_records: Array = []
var order_keys: Array = []
var order_ids: Array = []
var sorted_indices: Array = []
var membership_base: Dictionary = {}
var membership: Dictionary = {}
var retired_ids: Array = []
var retired_ground_keys: Array = []
var complete_order: Array = []
var complete_nodes: Dictionary = {}
var order_updates: Array = []
var atlas_jobs: Array = []
var atlas_shells: Dictionary = {}
var atlas_cursor = 0
var atlas_row_cursor = 0
var atlas_prefix: Dictionary = {}
# Shared data ownership survives this Node's retirement until atlas publication
# has either consumed or rejected the private prefix.
var atlas_retirement: Dictionary = {"blocked":false,"payloads":[],"directories":[],"unused":[],"active":{}}

func texture(path: String) -> Texture2D:
    var value: Texture2D = host.texture(path)
    if value==null: media_issue = "World preparation is missing texture: "+path
    return value
func _light_entry(entry: Dictionary) -> void: host._light_entry(entry)

func configure(owner: Node, candidate: Dictionary, first: bool = false) -> void:
    host = owner; boundary = candidate; initial = first; quarter = host.quarter
    epoch = host.timeline.initialization_revision
    _capture_membership()
    visible = false; catalog_cache = host.catalog_cache; profile = host.profile
    actor_catalog_owner=host.catalog_cache;rig_config=host.rig_config;rigs=host.rigs
    source_images = host.source_images; source_depth = host.source_depth; source_normals = host.source_normals
    fixture_clips = host.fixture_clips; fixture_frame_energy = host.fixture_frame_energy; fixture_frame_centroids = host.fixture_frame_centroids
    fixture_clock_owner = host
    presentation_errors = host.presentation_errors
    camera = Camera3D.new(); add_child(camera); camera.basis = host.camera.basis
    var ground_before = {}
    var affected_materials = {}
    var global_rows: bool = first or candidate.changes.get("full",false) or host.world_quarter!=quarter \
        or not candidate.changes.get("order",[]).is_empty() or _background_for(candidate.presentation_state,host.world_row_cache,candidate.changes)!=host.ground_is_background
    if global_rows:
        for key in host.ground_groups: affected_materials[key] = true
    else:
        for key in candidate.changes.get("tiles",{}):
            var old: Dictionary = host.world_row_cache.get("tile_rows",{}).get(key,{})
            if not old.is_empty(): affected_materials[old.material] = true
            if candidate.presentation_state.tiles.has(key): affected_materials[candidate.presentation_state.tiles[key].surface.base_material] = true
    for key in affected_materials:
        if not host.ground_groups.has(key): continue
        var group: Dictionary = host.ground_groups[key]
        var entry: Dictionary = group.entries[0]
        # Only numeric immutable geometry crosses the worker boundary. Visibility
        # and atlas addresses continue to belong to the displayed entry/atlas.
        ground_before[key] = {"rows":group.rows,"geometry":entry.ground_geometry,
            "receiver_bounds":entry.ground_receiver_bounds,"capacity":entry.node.multimesh.instance_count,
            "ground_version":entry.get("ground_version",0)}
    # Copy only the cache directory here. Raw authoring values are immutable.
    # The worker borrows the published row/index base until completion.
    var worker_cache:Dictionary=ActorConstruction.source_cache(catalog_cache)
    var existing_actors:Dictionary={}
    for id in host.visual_actors:
        var row:Dictionary=host.visual_actors[id].row
        var geometry:Dictionary={}
        for entry in host.visual_actors[id].entries:
            geometry[entry.actor_layer.slot]={"present":bool(SourceMaterial.value(entry,"has_component_geometry")),
                "cell":entry.get("geometry_cell_size",Vector2(128,128))}
        existing_actors[id]={"rig":row.rig,"appearance":row.appearance,"equipment_layers":row.equipment_layers,"geometry":geometry}
        actor_bases[id]={"actor":host.visual_actors[id],"playback":host.playbacks[id]}
    var input = {"state":candidate.presentation_state,"changes":candidate.changes,
        "actor_state":candidate.state,"staged_actors":candidate.get("staged_actors",{}),
        "actor_samples":candidate.get("actor_samples",{}),
        "actor_loadouts":ActorConstruction.loadouts(candidate.get("actor_samples",{}),candidate.get("actor_layers",[])),"existing_actors":existing_actors,
        "cache":worker_cache,"retained":host.world_row_cache,
        "ground":ground_before,"quarter":quarter,"basis":camera.basis,"background":host.ground_is_background,
        "global_rows":global_rows,"visibility":host.scenery_visibility,"visible_cells":host.scenery_visible_cells}
    task = WorkerThreadPool.add_task(_derive.bind(input),false,"Prepare displayed world")

static func _background_for(state: Dictionary, base: Dictionary, changes: Dictionary) -> bool:
    if changes.get("full",false) or not base.has("negative"):
        for tile in state.tiles.values():
            if tile.elevation_steps<0: return false
        for object in state.objects.values():
            if object.placement.base_height_steps<0: return false
        return true
    var count: int = base.negative.size()
    for kind in ["tiles","objects"]:
        for id in changes.get(kind,{}):
            var negative: bool = false
            if state[kind].has(id):
                negative = state[kind][id].elevation_steps<0 if kind=="tiles" else state[kind][id].placement.base_height_steps<0
            count += int(negative)-int(base.negative.has(kind+":"+id))
    return count==0

static func _floor(row: Dictionary, background: bool) -> bool:
    return background and row.get("kind")=="terrain" and row.base_height_steps==0 and row.material!="water"

static func _old_visual(base: Dictionary, id: String) -> Dictionary:
    var slot: int = base.get("visual_slots",{}).get(id,-1)
    return {} if slot<0 else base.result.visual_rows[slot]

static func _all_visual(base: Dictionary, patch: Dictionary) -> Array:
    if patch.has("prepared_visual"): return patch.prepared_visual
    # Explicit global classification changes (background/view) need full rows.
    var result_rows: Array = []
    for row in base.result.visual_rows: result_rows.append(patch.visual_changes.get(row.id,row))
    return result_rows

static func _candidate_visibility(input: Dictionary, patch: Dictionary) -> Dictionary:
    var cells: Dictionary = input.visible_cells
    var visibility: Dictionary = input.visibility
    var changes = {}
    var full: bool = patch.full or input.changes.get("senses",false)
    if full:
        cells = {}; visibility = WorldRows.current_ids(input.state,input.retained.get("boundaries",{}),cells,patch)
        for id in visibility:
            if not input.visibility.has(id): changes[id] = true
        for id in input.visibility:
            if not visibility.has(id): changes[id] = false
    else:
        var senses: Dictionary = input.state.get("senses",{}) if input.state.get("senses")!=null else {}
        for key in input.changes.get("tiles",{}):
            var old: Dictionary = input.retained.tile_rows.get(key,{})
            var row: Dictionary = WorldRows.projected_row(input.retained,patch,"tiles",key)
            if not old.is_empty() and (row.is_empty() or old.id!=row.id) and visibility.has(old.id): changes[old.id] = false
            if not row.is_empty() and visibility.has(row.id)!=cells.has(WorldRows.cell_key(row.position)): changes[row.id] = cells.has(WorldRows.cell_key(row.position))
        for id in input.changes.get("objects",{}):
            var current: bool = false
            if input.state.objects.has(id):
                current = senses.get("objects",{}).get(id,{}).get("visual",false)
                for cell in WorldRows.projected_index(input.retained,patch,"boundary_cells",id,[]): current = current or cells.has(cell)
            if visibility.has(id)!=current: changes[id] = current
    return {"visibility":visibility,"cells":cells,"changes":changes,"sparse":not full}

func candidate_visible(id: String) -> bool:
    return bool(result.visibility_changes.get(id,result.visibility.has(id)))

func _derive(input: Dictionary) -> void:
    var started = Time.get_ticks_usec()
    var patch = WorldRows.prepare_changes(input.state,input.cache,input.retained,input.changes)
    var sight = _candidate_visibility(input,patch)
    var background: bool = _background_for(input.state,input.retained,input.changes)
    var full_membership: bool = input.global_rows or patch.rebuild_visual
    # Moving between a native source and a batch is a real membership change.
    for id in patch.visual_changes:
        var old: Dictionary = _old_visual(input.retained,id)
        var row: Dictionary = patch.visual_changes[id]
        var was_static: bool = not old.is_empty() and not _floor(old,input.background)
        var now_static: bool = not row.is_empty() and not _floor(row,background)
        full_membership = full_membership or was_static!=now_static
    var ground = {}; var wanted = {}; var packets = {}; var supports = {}
    var ground_changes = {}; var ground_removed = {}; var removed_wanted: Array = []
    var all_rows: Array = _all_visual(input.retained,patch) if full_membership else []
    var rows_to_route: Array = all_rows if full_membership else patch.visual_changes.values()
    if not full_membership:
        for id in patch.visual_changes:
            var old: Dictionary = _old_visual(input.retained,id)
            var row: Dictionary = patch.visual_changes[id]
            if old.is_empty(): continue
            if _floor(old,input.background):
                if not ground_changes.has(old.material): ground_changes[old.material] = {}
                if row.is_empty() or not _floor(row,background) or row.material!=old.material:
                    if not ground_removed.has(old.material): ground_removed[old.material] = []
                    ground_removed[old.material].append(id)
            elif row.is_empty() or _floor(row,background): removed_wanted.append(id)
    for row in rows_to_route:
        if row.is_empty(): continue
        if _floor(row,background):
            if full_membership:
                if not ground.has(row.material): ground[row.material] = []
                ground[row.material].append(row)
            else:
                if not ground_changes.has(row.material): ground_changes[row.material] = {}
                ground_changes[row.material][row.id] = row
        else: wanted[row.id] = row
        # Only neighboring tile heights are needed by these prepared receivers.
        if GroundReceiving.eligible(row):
            var cell = Vector2(row.position[0],row.position[1])
            for offset in GroundReceiving.DIRECTIONS+[Vector2.ZERO]:
                var point = cell+offset
                var key = WorldRows.cell_key([point.x,point.y])
                var tile: Dictionary = WorldRows.projected_row(input.retained,patch,"tiles",key)
                if GroundReceiving.eligible(tile): supports[point] = float(tile.base_height_steps)
    var affected: Array = ground.keys() if full_membership else ground_changes.keys()
    for key in affected:
        var before: Dictionary = input.ground.get(key,{})
        if not full_membership and not before.is_empty():
            var geometry_patch = GroundData.prepare_changes(ground_changes[key],ground_removed.get(key,[]),before.geometry)
            if not geometry_patch.rebuild_required:
                if not geometry_patch.changed.is_empty():
                    var changed_packets = {}
                    for id in geometry_patch.records:
                        changed_packets[id] = GroundData._packet(geometry_patch.records[id],bool(sight.changes.get(id,sight.visibility.has(id))))
                    packets[key] = {"sparse":true,"geometry_patch":geometry_patch,"row_changes":ground_changes[key],
                        "packets":changed_packets,"indices":before.geometry.indices,"rows":before.geometry.rows,
                        "geometry_changes":{"base_version":before.ground_version,"changed":geometry_patch.changed,"removed":[]}}
                continue
        var rows: Array = ground.get(key,[])
        if not full_membership:
            var by_id = {}
            if not before.is_empty():
                for row in before.rows: by_id[row.id] = row
            for id in ground_removed.get(key,[]): by_id.erase(id)
            by_id.merge(ground_changes[key],true)
            rows = by_id.values()
            var slots: Dictionary = patch.get("prepared_visual_slots",input.retained.get("visual_slots",{}))
            rows.sort_custom(func(a,b):return slots[a.id]<slots[b.id])
            ground[key] = rows
        if rows.is_empty(): continue
        if before.is_empty():
            var sorted: Array = rows.duplicate(); var initial_packets = {}; var ranks = {}
            for i in rows.size(): ranks[rows[i].id] = i
            GroundData.sort_rows(sorted,initial_packets,input.quarter)
            packets[key] = {"new_rows":sorted,"new_packets":initial_packets,"source_ranks":ranks}
        elif before.rows!=rows:
            var visible = {}
            for row in rows:
                if sight.changes.get(row.id,sight.visibility.has(row.id)): visible[row.id] = true
            packets[key] = GroundData.prepare(rows,before,input.quarter,input.basis,visible)
    # Full membership/view changes are explicit larger geometry jobs. Sparse
    # source changes use the existing owner-side wall bucket invalidations.
    var geometry = WallReveal.prepare_geometry(input.state.tiles,all_rows,input.quarter) if full_membership else {}
    var actors:Dictionary={}
    var actor_members:Dictionary={}
    var actor_ids:Array=input.actor_state.actors.keys()
    for id in input.staged_actors:
        if not input.actor_state.actors.has(id):actor_ids.append(id)
    for id in actor_ids:
        var actor:Dictionary=input.actor_state.actors.get(id,input.staged_actors.get(id,{}))
        actor=ActorConstruction.actor_with_loadout(actor,input.actor_loadouts)
        if not WorldRows.visible_actor(actor,input.actor_state,input.staged_actors.has(id)):continue
        var resolved:Dictionary=Characters.resolve(actor,input.state,input.cache)
        # The displayed path owns authoring diagnostics. A failed preparation
        # cannot silently replace or suppress that current result.
        if not resolved.ok or resolved.value==null:continue
        var row:Dictionary=resolved.value
        actor_members[id]=row
        var before:Dictionary=input.existing_actors.get(id,{})
        if ActorConstruction.matches(row,before):continue
        var index:Dictionary=Characters._read("catalog-index.json",input.cache)
        var rig:Dictionary=Characters._read(index.rigs,input.cache)[row.rig]
        var resting:Dictionary=Characters.rest_sample(actor,rig,input.cache)
        var source_sample:Dictionary=input.actor_samples.get(id,resting.get("value",{}))
        var retained_slots:Dictionary={}
        var same_rig:bool=not before.is_empty() and row.rig==before.rig
        if same_rig and row.appearance==before.appearance:
            var selectors:Dictionary={}
            for layer in before.equipment_layers:selectors[layer.slot]=layer
            for layer in row.equipment_layers:
                if selectors.get(layer.slot)==layer:retained_slots[layer.slot]=true
        var layers:Array=Characters.layers(row,rig,input.cache)
        for layer in layers:
            if not retained_slots.has(layer.slot):continue
            var source:Dictionary=ActorConstruction.CharacterGeometry.record(layer.paths.get(source_sample.get("clip",""),""),layer.slot,input.cache)
            var prior_geometry:Dictionary=before.geometry[layer.slot]
            var cell:Array=source.get("cell_size",[128,128])
            if prior_geometry.present!=(not source.is_empty()) or (not source.is_empty() and prior_geometry.cell!=Vector2(cell[0],cell[1])):
                retained_slots.erase(layer.slot)
        actors[id]={"row":row,"rig":rig,"layers":layers,"entries":[],"new_entries":[],"playback":null,
            "reuse_actor":same_rig,"retained_slots":retained_slots,"source_sample":source_sample}
    result = {"complete":true,"actors":actors,"actor_members":actor_members,"light_resolution":SourceLighting.resolve(input.actor_state),"geometry":geometry,
        "row_patch":patch,"wanted":wanted,"removed_wanted":removed_wanted,"ground":ground,"packets":packets,"supports":supports,
        "background":background,"full_membership":full_membership,"needs_order":full_membership,
        "visibility":sight.visibility,"visibility_sparse":sight.sparse,"visible_cells":sight.cells,
        "visibility_base":input.visibility,"visibility_changes":sight.changes,"worker_ms":(Time.get_ticks_usec()-started)/1000.0}

func step(budget_usec: int = 2000) -> void:
    if prepared or stale or not media_issue.is_empty(): return
    var started = Time.get_ticks_usec()
    while not prepared and Time.get_ticks_usec()-started<budget_usec:
        # A worker poll spends no frame token. The caller may return after other
        # required work, using the same remaining allowance, and observe its
        # completed result without inserting another display-frame wait.
        if task>=0:
            if not WorkerThreadPool.is_task_completed(task): break
            WorkerThreadPool.wait_for_task_completion(task); task = -1
            if not result.get("complete",false):
                media_issue = "World preparation failed before publishing its complete result."
                phase = "failed"
                if not media_issue in presentation_errors: presentation_errors.append(media_issue)
                break
            if phase=="atlas_prefix_wait":
                result.worker_ms+=float(atlas_prefix.get("worker_ms",0.0))
                phase="atlas_prefix_bind"
            elif phase=="sort_wait":
                if sorted_indices.size()!=order_records.size():
                    media_issue = "World preparation failed to sort its complete static membership."; phase = "failed"; break
                phase = "order_publish"; cursor = 0
            else:
                wanted_ids = result.wanted.keys(); ground_keys = result.ground.keys()
                for key in result.packets:
                    if key not in ground_keys: ground_keys.append(key)
                light_preparation=host.source_lighting.begin_preparation(result.light_resolution)
                actor_ids=result.actors.keys();phase="cookie_resources"
            continue
        if phase=="cookie_resources":
            if cookie_source_cursor==result.light_resolution.sources.size():phase="light_nodes";continue
            _prepare_cookie_resource()
        elif phase=="cookie_images":
            if cookie_image_cursor==cookie_jobs.size():prepared=true;phase="ready";continue
            var job:Dictionary=cookie_jobs[cookie_image_cursor]
            if not job.drawn:break
            var cookie_started:int=Time.get_ticks_usec()
            var ok:bool=host.generated_shadows.prepare_cookie(job.texture)
            FrameProfile.end_phase(profile,"world_prepare_cookie_image",cookie_started)
            if not ok:
                media_issue="World preparation could not read the exact native light cookie."
                phase="failed";return
            cookie_image_cursor+=1
        elif phase=="light_nodes":
            if light_preparation.complete:phase="actors";continue
            host.source_lighting.prepare_step(light_preparation)
        elif phase=="actors":
            if actor_cursor==actor_ids.size():phase="objects";continue
            _prepare_actor()
            if not media_issue.is_empty():
                if media_issue not in presentation_errors:presentation_errors.append(media_issue)
                break
            if actor_cursor<actor_ids.size() and result.actors[actor_ids[actor_cursor]].has("unbound_entry"):break
        elif phase=="objects":
            if cursor==wanted_ids.size(): phase = "ground"; continue
            var id: String = wanted_ids[cursor]; cursor += 1
            var row: Dictionary = result.wanted[id]
            var old: Dictionary = membership_base.groups.get(id,{})
            if not old.is_empty() and old.row==row: continue
            var first = static_entries.size()
            _environment_row(row.duplicate(true))
            native_groups[id] = {"row":row,"entries":static_entries.slice(first)}
            created_count += static_entries.size()-first
            if not media_issue.is_empty(): phase = "failed"; return
        elif phase=="ground":
            if ground_cursor==ground_keys.size():
                _begin_membership()
                continue
            var key: String = ground_keys[ground_cursor]
            if membership_base.ground.has(key): ground_cursor += 1; continue
            if ground_job.is_empty():
                var packet: Dictionary = result.packets[key]
                ground_job = _ground_begin(packet.new_rows,packet.new_packets,packet.get("source_ranks",{}))
                if not media_issue.is_empty(): phase = "failed"; return
            elif _ground_fill(ground_job):
                _ground_finish(ground_job)
                native_ground[key] = {"rows":result.ground[key],"entries":[ground_job.entry]}
                ground_job = {}; ground_cursor += 1
        elif phase=="membership_objects":
            if cursor==wanted_ids.size(): phase = "membership_ground"; ground_cursor = 0; continue
            var id: String = wanted_ids[cursor]; cursor += 1
            var group: Dictionary = native_groups.get(id,membership_base.groups.get(id,{}))
            if membership.full: membership.groups[id] = group; _collect_membership(group)
            elif native_groups.has(id):
                membership.group_updates[id] = group
                _collect_replacement(membership_base.groups[id],group)
            if native_groups.has(id):
                membership.new_groups.append(group)
                membership.upserts.append_array(group.entries)
                membership.entries_changed = true
                membership.walls_changed = membership.walls_changed or group.row.kind in ["wall","cliff"]
        elif phase=="membership_ground":
            if ground_cursor==ground_keys.size():
                phase = "retire_objects"; cursor = 0; continue
            var key: String = ground_keys[ground_cursor]; ground_cursor += 1
            var group: Dictionary = native_ground.get(key,membership_base.ground.get(key,{}))
            var packet: Dictionary = result.packets.get(key,{})
            var representative: Dictionary = {}
            if packet.has("rows"):
                representative = packet.get("row_changes",{}).get(packet.rows[0].id,packet.rows[0])
            if native_ground.has(key):
                membership.new_groups.append(group)
                membership.upserts.append_array(group.entries)
                membership.entries_changed = true
            elif not representative.is_empty():
                membership.ground_updates.append({"entry":group.entries[0],"packet":packet})
                membership.upserts.append(group.entries[0])
                membership.entries_changed = membership.entries_changed or group.entries[0].placement!=representative
                if packet.get("sparse",false):
                    membership.ground_row_updates.append({"group":group,"rows":packet.row_changes})
                else: group = {"rows":result.ground[key],"entries":group.entries}
            if membership.full:
                membership.ground[key] = group
                _collect_membership(group,representative)
            elif not packet.is_empty():
                membership.ground_group_updates[key] = group
                _collect_replacement(membership_base.ground[key],group,representative)
        elif phase=="retire_objects":
            if cursor==retired_ids.size(): phase = "retire_ground"; ground_cursor = 0; continue
            var id: String = retired_ids[cursor]; cursor += 1
            if not result.wanted.has(id) or native_groups.has(id):
                var group: Dictionary = membership_base.groups[id]
                _collect_retired(group)
                membership.walls_changed = membership.walls_changed or group.row.kind in ["wall","cliff"]
        elif phase=="retire_ground":
            if ground_cursor==retired_ground_keys.size():
                membership.complete = true
                if not result.needs_order: _begin_atlas_preparation()
                elif not membership.full:
                    phase = "order_collect"; cursor = 0
                else:
                    phase = "sort_wait"
                    task = WorkerThreadPool.add_task(_sort_order,false,"Sort prepared world")
                continue
            var key: String = retired_ground_keys[ground_cursor]; ground_cursor += 1
            if not result.ground.has(key): _collect_retired(membership_base.ground[key])
        elif phase=="order_collect":
            if cursor==membership.entries.size():
                phase = "sort_wait"
                task = WorkerThreadPool.add_task(_sort_order,false,"Sort prepared world")
                continue
            var entry: Dictionary = membership.entry_replacements.get(cursor,membership.entries[cursor])
            var representative: Dictionary = membership.representatives.get(entry.node.get_instance_id(),{})
            _collect_order([entry],representative); cursor += 1
        elif phase=="order_publish":
            if cursor==sorted_indices.size(): phase = "order_release"; continue
            _prepare_order_record(sorted_indices[cursor]); cursor += 1
        elif phase=="order_release":
            if not order_records.is_empty(): order_records.pop_back()
            else:
                order_keys = []; order_ids = []; sorted_indices = []
                _begin_atlas_preparation()
        elif phase=="atlas_receivers":
            if atlas_cursor==atlas_jobs.size():
                atlas_prefix=AtlasDelta.begin_candidate(host.native_light_atlas,atlas_jobs,membership.removed,host)
                phase="atlas_prefix_capture";continue
            _prepare_atlas_receiver()
        elif phase=="atlas_prefix_capture":
            if AtlasDelta.capture_candidate(host.native_light_atlas,atlas_prefix,host):
                if atlas_prefix.has("error"):
                    _prefix_failed();return
                phase="atlas_prefix_wait"
                task=WorkerThreadPool.add_task(AtlasDelta.compute_candidate.bind(atlas_prefix),false,"Plan prepared lighting addresses")
                continue
        elif phase=="atlas_prefix_bind":
            if AtlasDelta.prepare_candidate_binding(host.native_light_atlas,atlas_prefix,atlas_shells):
                if atlas_prefix.has("error"):_prefix_failed();return
                _finish_preparation()
    FrameProfile.end_phase(profile,"world_prepare_native",started)

func _prefix_failed() -> void:
    var reason:String=str(atlas_prefix.get("error","incomplete_private_prefix"))
    if reason in ["atlas_changed_during_capture","source_changed_before_prefix_capture"]:
        stale=true;phase="stale"
    else:
        media_issue="World lighting preparation failed: "+reason
        phase="failed"
        if media_issue not in presentation_errors:presentation_errors.append(media_issue)

func _prepare_cookie_resource() -> void:
    var source:Dictionary=result.light_resolution.sources[cookie_source_cursor]
    cookie_source_cursor+=1
    var texture:Texture2D=host.source_lighting.prepare_cookie(source)
    if texture==null or host.generated_shadows.cookie_prepared(texture) or cookie_seen.has(texture.get_rid()):return
    cookie_seen[texture.get_rid()]=true
    var job:Dictionary={"texture":texture,"drawn":false}
    cookie_jobs.append(job)
    # Let the existing actor/static preparation continue while the native
    # GradientTexture is processed. No current light node is configured here.
    if not RenderingServer.frame_post_draw.is_connected(_cookie_drawn):
        RenderingServer.frame_post_draw.connect(_cookie_drawn,CONNECT_ONE_SHOT)

func _cookie_drawn() -> void:
    for job in cookie_jobs:job.drawn=true

func _finish_preparation() -> void:
    if cookie_image_cursor<cookie_jobs.size():phase="cookie_images"
    else:prepared=true;phase="ready"

func _prepare_actor() -> void:
    var id:String=actor_ids[actor_cursor]
    var prepared:Dictionary=result.actors[id]
    if prepared.playback==null:
        if prepared.reuse_actor:
            var base:Dictionary=actor_bases[id]
            prepared.actor_base=base.actor;prepared.playback=base.playback
            prepared.retained_entries={}
            for entry in base.actor.entries:
                if prepared.retained_slots.has(entry.actor_layer.slot):prepared.retained_entries[entry.actor_layer.slot]=entry
        else:prepared.playback=ActorConstruction.graph(self,prepared.rig,host.animation_templates)
        native_actors[id]=prepared
        return
    if prepared.has("unbound_entry"):
        if _prepare_actor_source(prepared,prepared.unbound_entry,prepared.unbound_private):prepared.erase("unbound_entry")
        return
    var index:int=prepared.entries.size()
    if index<prepared.layers.size():
        var layer:Dictionary=prepared.layers[index]
        var entry:Dictionary=prepared.get("retained_entries",{}).get(layer.slot,{})
        var owned:bool=entry.is_empty()
        if owned:
            entry=ActorConstruction.layer(self,prepared.row,prepared.rig,layer,index)
            ActorConstruction.prepare_neutral(entry,host.textures,host.resources)
            prepared.new_entries.append(entry);created_count+=1
        if not _prepare_actor_source(prepared,entry,owned):
            prepared.unbound_entry=entry;prepared.unbound_private=owned
        prepared.entries.append(entry)
    elif host.generated_shadows.prepare_actor_step(self,prepared):actor_cursor+=1

func _prepare_actor_source(prepared:Dictionary,entry:Dictionary,private:bool=true)->bool:
    var selected:Dictionary=prepared.get("source_sample",{})
    var clip:String=selected.get("clip","")
    var layer:Dictionary=entry.actor_layer
    var admission:Dictionary={"status":"no_selected_clip","clip":clip}
    if private:entry.atlas_preparation=admission
    if not layer.paths.has(clip) or not prepared.rig.clips.has(clip):
        media_issue="Prepared actor has no authored source for "+str(prepared.row.id)+" / "+layer.slot+" / "+clip
        phase="failed"
        return false
    var path:String=layer.paths[clip]
    # This only initializes hidden material resources. It never requests media
    # or samples a graph; the displayed actor still chooses its current pose.
    admission.path=path
    if not host.textures.has(path):admission.status="missing_colour_texture";return false
    if not host.source_images.has(path):admission.status="missing_colour_image";return false
    for companion in ActorConstruction.CharacterGeometry.paths(path,layer.slot,host.catalog_cache,host.character_light_profile):
        if not host.textures.has(companion):
            admission.status="missing_companion";admission.missing_path=companion;return false
    # Retained sources already own their native receiving materials and shape.
    # Their exact next sheet/geometry resources are resident; normal displayed
    # sampling updates those operands without constructing another receiver.
    if not private:return true
    var facing:String=prepared.row.facing
    if host.external_playback:facing="SW"
    var cycle:Array=host.rig_config.FACING_CYCLE
    facing=cycle[posmod(cycle.find(facing)+quarter*2,8)]
    # A valid source frame is enough to prepare all non-frame bindings. The
    # actual first sample either certifies the adjacent UV change or fully binds.
    var frame:int=clampi(int(float(selected.get("source_seconds",0.0))*prepared.rig.clips[clip].fps),0,int(prepared.rig.clips[clip].frames)-1)
    var neutral:Dictionary=ActorConstruction.Conditions.material(entry.placement.id,[])
    var parameters:Dictionary=ActorConstruction.Conditions.parameters(neutral,host.textures,host.resources)
    ActorConstruction.bind_source(host,entry,prepared.rig,path,frame,facing,parameters)
    admission.status="source_bound"
    return true

func take_actor(id:String,row:Dictionary,rig:Dictionary)->Dictionary:
    var prepared:Dictionary=native_actors.get(id,{})
    if prepared.is_empty() or epoch!=host.timeline.initialization_revision or quarter!=host.quarter \
        or not is_same(actor_catalog_owner,host.catalog_cache) or not is_same(prepared.rig,rig) \
        or not ActorConstruction.matches(row,prepared.row):return {}
    if prepared.entries.size()!=prepared.layers.size() or prepared.playback==null:return {}
    native_actors.erase(id)
    return prepared

func _begin_atlas_preparation() -> void:
    # A new empty atlas is a valid base. Its first displayed world follows the
    # same private construction and exact admission path as later reveals.
    if not host.native_light_atlas.delta_ready and host.native_light_atlas.entry_specs.is_empty():
        AtlasDelta.rebuild(host.native_light_atlas,host.native_light_change_serial)
    if not host.native_light_atlas.delta_ready:
        _finish_preparation();return
    # Structural actor cuts carry their private source bindings alongside the
    # static rows. Actor sampling may change pose later, never membership here.
    if result.has("actor_members"):
        for id in host.visual_actors:
            if not result.actor_members.has(id) or native_actors.has(id):
                var retained:Array=native_actors.get(id,{}).get("retained_entries",{}).values()
                for entry in host.visual_actors[id].entries:
                    if entry not in retained:membership.removed[entry.node.get_instance_id()]=true
        for actor in native_actors.values():
            for entry in actor.new_entries:
                if entry.has("cell") and entry not in membership.upserts:membership.upserts.append(entry)
    var updated: Dictionary={}
    for update in membership.ground_updates:
        updated[update.entry.node.get_instance_id()]=update.packet
    var source_rows:Dictionary={}
    var sources:Dictionary={}
    for entry in membership.upserts:
        if not entry.has("cell"):continue
        var id:int=entry.node.get_instance_id()
        sources[id]=entry
        var packet:Dictionary=updated.get(id,{})
        var selected:Array=packet.geometry_changes.changed if not packet.is_empty() else entry.batch_rows if entry.has("batch_rows") else [entry.placement]
        source_rows[id]={}
        for row in selected:source_rows[id][str(row.id) if row is Dictionary else str(row)]=row
    # Visibility variants own receiving materials too. Prepare their exact rows
    # at the same cut, including sight-only updates with unchanged geometry.
    for row_id in result.get("visibility_changes",{}):
        for consumer in host.scenery_consumers.get(row_id,[]):
            var entry:Dictionary=consumer.entry;var id:int=entry.node.get_instance_id()
            if membership.removed.has(id) or not entry.has("cell"):continue
            if not sources.has(id):sources[id]=entry;source_rows[id]={};membership.upserts.append(entry)
            source_rows[id][row_id]=entry.placement
        for entry in host.scenery_batches:
            var id:int=entry.node.get_instance_id()
            if membership.removed.has(id) or not entry.ground_indices.has(row_id):continue
            var packet:Dictionary=updated.get(id,{})
            if not packet.is_empty() and not packet.indices.has(row_id):continue
            if not sources.has(id):sources[id]=entry;source_rows[id]={};membership.upserts.append(entry)
            if not source_rows[id].has(row_id):source_rows[id][row_id]=str(row_id)
    for id in sources:
        atlas_jobs.append({"entry":sources[id],"rows":source_rows[id].values(),"packet":updated.get(id,{})})
    # State/sight boundaries can leave static atlas membership unchanged.
    # Current actor, fixture, visibility and camera samples still use normal
    # atlas synchronization; there is no future static layout to capture here.
    if atlas_jobs.is_empty() and membership.removed.is_empty():
        _finish_preparation();return
    phase="atlas_receivers"

func _prepare_atlas_receiver() -> void:
    var job: Dictionary=atlas_jobs[atlas_cursor]
    var entry: Dictionary=job.entry
    var id: int=entry.node.get_instance_id()
    if not job.has("prepared"):
        if is_ancestor_of(entry.node) and not entry.has("batch_rows"):
            var visibility:float=1.0 if entry.placement.kind=="actor" or candidate_visible(str(entry.placement.id)) else 0.0
            SourceMaterial.set_parameter(entry,"current_visibility",visibility)
            entry.scenery_value=visibility
        var snapshot:Dictionary=entry.duplicate()
        var packet:Dictionary=job.packet
        if not packet.is_empty():
            snapshot.ground_version=entry.get("ground_version",0)+1
            snapshot.batch_rows=packet.rows;snapshot.ground_packets=packet.packets
            snapshot.ground_indices=packet.indices
            if packet.get("sparse",false):
                snapshot.sparse_ground=true;snapshot.ground_row_changes=packet.row_changes
                snapshot.erase("ground_buffer");snapshot.erase("scenery_values")
                snapshot.ground_visibility={}
                for row_id in packet.row_changes:snapshot.ground_visibility[row_id]=1.0 if candidate_visible(row_id) else 0.0
                snapshot.placement=packet.row_changes.get(str(packet.rows[0].id),packet.rows[0])
            else:
                snapshot.ground_buffer=packet.buffer;snapshot.scenery_values=packet.values
                snapshot.placement=packet.rows[0]
        if snapshot.has("batch_rows") and not snapshot.get("sparse_ground",false):
            snapshot.scenery_values=snapshot.scenery_values.duplicate()
            snapshot.ground_buffer=snapshot.ground_buffer.duplicate()
            snapshot.ground_packets=snapshot.ground_packets.duplicate()
        elif not snapshot.has("batch_rows"):
            snapshot.scenery_value=1.0 if snapshot.placement.kind=="actor" or candidate_visible(str(snapshot.placement.id)) else 0.0
        job.prepared=host.native_light_atlas.prepare_source_binding(entry,snapshot,host,true)
        if job.prepared.is_empty():
            media_issue="World lighting preparation has no valid source bounds: "+str(entry.get("id",id))+" "+str(entry.get("atlas_preparation",{}))
            phase="failed"
            return
        # Receiver nodes can enter their final canvas while hidden. Their maps
        # stay exclusively owned here until the exact displayed atlas accepts
        # them, so preparation neither publishes addresses nor exposes pixels.
        job.prepared.receiver_parent=host.native_light_atlas.projection_root
        job.prepared.output.private_node=is_ancestor_of(entry.node)
        atlas_shells[id]=job.prepared
        return
    if atlas_row_cursor==job.rows.size():
        atlas_cursor+=1; atlas_row_cursor=0; return
    if not is_instance_valid(job.prepared.receiver_parent) or job.prepared.receiver_parent!=host.native_light_atlas.projection_root:
        atlas_cursor+=1; atlas_row_cursor=0; return
    var sampled:Dictionary=job.prepared.snapshot
    var selected:Variant=job.rows[atlas_row_cursor]
    var row:Dictionary=selected if selected is Dictionary else AtlasDelta.sampled_row(sampled,str(selected))
    atlas_row_cursor+=1
    var visibility:float=1.0 if row.kind=="actor" or candidate_visible(str(row.id)) else 0.0
    if sampled.has("batch_rows") and not sampled.get("sparse_ground",false):
        var row_id:String=str(row.id);var index:int=sampled.ground_indices[row_id]
        sampled.scenery_values[index]=visibility;sampled.ground_buffer[index*20+16]=visibility
        var packet:Dictionary=sampled.ground_packets[row_id].duplicate()
        packet.data=packet.data.duplicate();packet.data[16]=visibility
        sampled.ground_packets[row_id]=packet
    host.native_light_atlas.prepare_source_row(job.prepared,row,job.prepared.receiver_parent,result.supports,visibility)

func publish_atlas_receivers() -> void:
    for id in atlas_shells.keys():
        if host.native_light_atlas.adopt_source_binding(atlas_shells[id]):
            atlas_shells.erase(id)
    # A replaced atlas rejects the old parent. Those private nodes remain ours
    # and are released by the same bounded retirement path as cancellation.
    host.native_light_atlas.prepared_delta=atlas_prefix
    if not atlas_prefix.is_empty() or not host.native_light_atlas.prepared_source_bindings.is_empty() \
        or not host.native_light_atlas.prepared_receiver_sources.is_empty():
        atlas_retirement.blocked=true
        host.native_light_atlas.prepared_cleanup=atlas_retirement
    atlas_prefix={};atlas_jobs=[]

func _capture_membership() -> void:
    # These collection owners are replaced at static admission, never updated by
    # actor sampling. Dynamic entries deliberately aren't part of this proof.
    membership_base = {"groups":host.world_groups,"ground":host.ground_groups,"entries":host.static_entries,
        "groups_size":host.world_groups.size(),"ground_size":host.ground_groups.size(),"entries_size":host.static_entries.size(),
        "generation":host.world_generation,"quarter":host.world_quarter,"revision":host.world_revision,
        "light_serial":host.native_light_change_serial}

func can_publish_membership(target_revision: int = -1) -> bool:
    if not prepared or stale or not media_issue.is_empty() or not membership.get("complete",false):return false
    for id in native_actors:
        var actor:Dictionary=native_actors[id]
        if actor.get("reuse_actor",false):
            if not is_same(host.visual_actors.get(id),actor.actor_base) or host.playbacks.get(id)!=actor.playback:return false
            if actor.has("shadow_base") and not is_same(host.generated_shadows.actors.get(id),actor.shadow_base):return false
    if not host.source_lighting.preparation_valid(light_preparation):return false
    if not atlas_prefix.is_empty():
        if not AtlasDelta.candidate_base_matches(host.native_light_atlas,atlas_prefix,host):return false
    var expected:int=host.timeline.world_revision if target_revision<0 else target_revision
    return epoch==host.timeline.initialization_revision and quarter==host.quarter \
        and boundary.get("world_revision",-1)==expected \
        and membership_base.generation==host.world_generation and membership_base.quarter==host.world_quarter \
        and membership_base.revision==host.world_revision and membership_base.light_serial==host.native_light_change_serial \
        and is_same(membership_base.groups,host.world_groups) and membership_base.groups_size==host.world_groups.size() \
        and is_same(membership_base.ground,host.ground_groups) and membership_base.ground_size==host.ground_groups.size() \
        and is_same(membership_base.entries,host.static_entries) and membership_base.entries_size==host.static_entries.size()


func _begin_membership() -> void:
    var full: bool = result.get("full_membership",true)
    # Native entry-count changes need a prepared replacement array. An ordinary
    # same-shape source replacement edits the retained arrays at known slots.
    for id in native_groups:
        var old: Dictionary = membership_base.groups.get(id,{})
        var fresh: Dictionary = native_groups[id]
        if old.is_empty() or old.entries.size()!=fresh.entries.size(): full = true; break
        for i in old.entries.size():
            if not old.entries[i].has("static_slot") or (old.entries[i].material.shader==FIXTURE_FLAME_SHADER)!=(fresh.entries[i].material.shader==FIXTURE_FLAME_SHADER): full = true; break
    if not native_ground.is_empty() or not result.get("removed_wanted",[]).is_empty(): full = true
    for key in ground_keys:
        if result.ground.has(key) and result.ground[key].is_empty(): full = true
    if full and not result.get("full_membership",true):
        # A source variant changed native membership during construction. This
        # is explicit larger preparation; publication still installs references.
        var wanted = {}; var ground = {}
        for id in membership_base.groups: wanted[id] = membership_base.groups[id].row
        for id in result.get("removed_wanted",[]): wanted.erase(id)
        wanted.merge(result.wanted,true)
        for key in membership_base.ground: ground[key] = membership_base.ground[key].rows
        for key in result.ground:
            if result.ground[key].is_empty(): ground.erase(key)
            else: ground[key] = result.ground[key]
        var slots: Dictionary = result.row_patch.get("prepared_visual_slots",host.world_row_cache.visual_slots)
        wanted_ids = wanted.keys(); wanted_ids.sort_custom(func(a,b):return slots[a]<slots[b])
        result.wanted = wanted; result.ground = ground; ground_keys = ground.keys()
        ground_keys.sort_custom(func(a,b):return slots[ground[a][0].id]<slots[ground[b][0].id])
    elif full:
        for key in ground_keys.duplicate():
            if result.ground.get(key,[]).is_empty(): ground_keys.erase(key)
    membership = {"complete":false,"full":full,"groups":{} if full else membership_base.groups,
        "ground":{} if full else membership_base.ground,"entries":[] if full else membership_base.entries,
        "fixtures":[] if full else host.fixture_entries,"new_groups":[],"retired_groups":[],"ground_updates":[],
        "removed":{},"upserts":[],"entries_changed":false,"walls_changed":false,"group_updates":{},
        "ground_group_updates":{},"ground_row_updates":[],"entry_replacements":{},"fixture_replacements":{},
        "slot_updates":[],"order_replacements":[],"representatives":{}}
    retired_ids = membership_base.groups.keys() if full else native_groups.keys()
    retired_ground_keys = membership_base.ground.keys() if full else []
    result.needs_order = result.needs_order or full
    phase = "membership_objects"; cursor = 0

func _collect_membership(group: Dictionary, representative: Dictionary = {}) -> void:
    for entry in group.entries:
        var slot = {"entry":entry,"static":membership.entries.size(),"fixture":-1}
        membership.entries.append(entry)
        if entry.material.shader==FIXTURE_FLAME_SHADER:
            slot.fixture = membership.fixtures.size(); membership.fixtures.append(entry)
        membership.slot_updates.append(slot)
    if result.needs_order: _collect_order(group.entries,representative)

func _collect_replacement(old: Dictionary, group: Dictionary, representative: Dictionary = {}) -> void:
    for i in group.entries.size():
        var entry: Dictionary = group.entries[i]
        var previous: Dictionary = old.entries[i]
        var slot: int = previous.static_slot
        membership.entry_replacements[slot] = entry
        var fixture: int = previous.get("fixture_slot",-1)
        if fixture>=0: membership.fixture_replacements[fixture] = entry
        membership.slot_updates.append({"entry":entry,"static":slot,"fixture":fixture})
        var row: Dictionary = entry.placement if representative.is_empty() else representative
        var id: String = entry.id if representative.is_empty() else row.id+":0:terrain"
        var key = Order.key(row,entry.role,entry.layer,quarter,result.background)
        if not previous.has("order_slot") or previous.get("order_key",[])!=key or previous.id!=id:
            result.needs_order = true
        membership.order_replacements.append({"old":previous,"entry":entry,"placement":row,"id":id,"key":key})
        if not representative.is_empty(): membership.representatives[entry.node.get_instance_id()] = representative

func publish_membership() -> void:
    # The worker is complete and preflight has accepted this boundary. No
    # discovery/rejection occurs here; adopt maps or apply known native slots.
    if not membership.full:
        for id in membership.group_updates: membership.groups[id] = membership.group_updates[id]
        for key in membership.ground_group_updates: membership.ground[key] = membership.ground_group_updates[key]
        for slot in membership.entry_replacements: membership.entries[slot] = membership.entry_replacements[slot]
        for slot in membership.fixture_replacements: membership.fixtures[slot] = membership.fixture_replacements[slot]
    for update in membership.ground_row_updates:
        var geometry: Dictionary = update.group.entries[0].ground_geometry
        for id in update.rows: update.group.rows[geometry.source_ranks[id]] = update.rows[id]
    for update in membership.slot_updates:
        update.entry.static_slot = update.static; update.entry.fixture_slot = update.fixture
    if result.get("visibility_sparse",false):
        for id in result.visibility_changes:
            if result.visibility_changes[id]: result.visibility[id] = true
            else: result.visibility.erase(id)
    host.static_entries = membership.entries; host.fixture_entries = membership.fixtures
    host.world_groups = membership.groups; host.ground_groups = membership.ground

func _collect_retired(group: Dictionary) -> void:
    membership.retired_groups.append(group); membership.entries_changed = true
    for entry in group.entries: membership.removed[entry.node.get_instance_id()] = true

func _collect_order(group: Array, representative: Dictionary = {}) -> void:
    for entry in group:
        var row: Dictionary = entry.placement if representative.is_empty() else representative
        var id: String = entry.id if representative.is_empty() else row.id+":0:terrain"
        var key: Array = Order.key(row,entry.role,entry.layer,quarter,result.background)
        # References remain on the scene thread. The worker sees keys/IDs only.
        order_records.append({"entry":entry,"placement":row,"id":id,"key":key,"node_id":entry.node.get_instance_id()})
        order_keys.append(key); order_ids.append(id)

func _sort_order() -> void:
    var started = Time.get_ticks_usec()
    var order: Array = range(order_keys.size())
    order.sort_custom(func(a,b):return Order.less(order_keys[a],order_keys[b]) if order_keys[a]!=order_keys[b] else order_ids[a]<order_ids[b])
    sorted_indices = order
    result.worker_ms += (Time.get_ticks_usec()-started)/1000.0

func _prepare_order_record(index: int) -> void:
    var record: Dictionary = order_records[index]
    var entry: Dictionary = record.entry
    record.order_slot = complete_order.size()
    complete_order.append(entry); complete_nodes[record.node_id] = true
    if entry.get("order_slot",-1)!=record.order_slot or not is_same(entry.get("order_placement"),record.placement) or entry.get("order_id","")!=record.id \
            or entry.get("order_quarter",-1)!=quarter or entry.get("order_background",null)!=result.background:
        order_updates.append(record)

func publish_order() -> void:
    if not is_same(host.static_entries,membership.entries): return
    if result.needs_order:
        for record in order_updates:
            var entry: Dictionary = record.entry
            entry.order_key = record.key; entry.order_placement = entry.placement; entry.order_slot = record.order_slot
            entry.order_id = entry.id; entry.order_quarter = quarter; entry.order_background = result.background
        host.static_complete_order = complete_order; host.static_sort_nodes = complete_nodes
    else:
        for record in membership.order_replacements:
            var entry: Dictionary = record.entry
            var slot: int = record.old.order_slot
            host.static_complete_order[slot] = entry
            host.static_sort_nodes.erase(record.old.node.get_instance_id())
            host.static_sort_nodes[entry.node.get_instance_id()] = true
            entry.order_slot = slot; entry.order_key = record.key; entry.order_placement = entry.placement
            entry.order_id = entry.id; entry.order_quarter = quarter; entry.order_background = result.background
    host.prepared_static_order = {"entries":host.static_entries,"order":host.static_complete_order,
        "quarter":quarter,"background":result.background,"generation":host.world_generation,"epoch":epoch}

func worker_finished() -> bool:
    return task<0 or WorkerThreadPool.is_task_completed(task)

func join() -> void:
    if task>=0: WorkerThreadPool.wait_for_task_completion(task); task = -1

func release_handles() -> Array:
    join()
    var held = entries.duplicate()
    for record in light_preparation.get("nodes",[]):held.append({"node":record.node,"retire_external":true})
    light_preparation={}
    for prepared in native_actors.values():
        held.append_array(prepared.get("new_entries",prepared.entries))
    native_actors={};actor_ids=[];actor_catalog_owner={};actor_bases={}
    cookie_jobs=[];cookie_seen={}
    for prepared in atlas_shells.values():
        for receiver in prepared.receivers.values():
            receiver.retire_external=true
            held.append(receiver)
    if not atlas_prefix.is_empty() or not atlas_shells.is_empty():
        AtlasDelta.retire_candidate(atlas_retirement,atlas_prefix,atlas_shells,false)
    entries = []; static_entries = []; actor_entries = []; native_groups = {}; native_ground = {}; ground_job = {}
    order_records = []; order_keys = []; order_ids = []; sorted_indices = []
    membership_base = {}; membership = {}; complete_order = []; complete_nodes = {}; order_updates = []
    retired_ids = []; retired_ground_keys = []; atlas_jobs=[]; atlas_shells={}; atlas_prefix={}
    return held
