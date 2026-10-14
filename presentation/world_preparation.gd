extends "res://presentation/sprite_sources.gd"
# One unpublished world boundary. Worker owns passive projection/buffers;
# the scene thread builds only changed native groups under this hidden parent.
const WorldRows = preload("res://presentation/world.gd")
const GroundData = preload("res://presentation/ground_data.gd")
const WallReveal = preload("res://presentation/wall_reveal.gd")
var host: Node
var boundary: Dictionary = {}
var epoch = -1
var task = -1
var result: Dictionary = {}
var native_groups: Dictionary = {}
var native_ground: Dictionary = {}
var wanted_ids: Array = []
var ground_keys: Array = []
var cursor = 0
var ground_cursor = 0
var ground_job: Dictionary = {}
var prepared = false
var admitted = false
var initial = false
var phase = "projection"
var frame = -1
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
    source_images = host.source_images; source_depth = host.source_depth; source_normals = host.source_normals
    fixture_clips = host.fixture_clips; fixture_frame_energy = host.fixture_frame_energy; fixture_frame_centroids = host.fixture_frame_centroids
    fixture_clock_owner = host
    presentation_errors = host.presentation_errors
    camera = Camera3D.new(); add_child(camera); camera.basis = host.camera.basis
    var ground_before = {}
    for key in host.ground_groups:
        var group: Dictionary = host.ground_groups[key]
        var entry: Dictionary = group.entries[0]
        ground_before[key] = {"rows":group.rows,"packets":entry.ground_packets,"receiver_bounds":entry.ground_receiver_bounds,"capacity":entry.node.multimesh.instance_count,"ground_version":entry.get("ground_version",0),"address_token":host.native_light_atlas.floor_address_token(entry)}
    # Copy only the cache directory here. Raw authoring values are immutable.
    # The worker forks every mutable retained index before touching it.
    var input = {"state":candidate.presentation_state,"changes":candidate.changes,
        "cache":catalog_cache.duplicate(),"retained":host.world_row_cache,
        "ground":ground_before,"quarter":quarter,"basis":camera.basis,"background":host.ground_is_background,
        "visibility":host.scenery_visibility}
    task = WorkerThreadPool.add_task(_derive.bind(input),false,"Prepare displayed world")

func _derive(input: Dictionary) -> void:
    var started = Time.get_ticks_usec()
    var retained: Dictionary = input.retained.duplicate()
    for name in ["tile_rows","object_rows","missing","wall_cells","assembly","boundaries","boundary_cells","lit_candidates","negative","terrain_materials"]:
        if retained.has(name): retained[name] = retained[name].duplicate()
    for cell in retained.get("wall_cells",{}): retained.wall_cells[cell] = retained.wall_cells[cell].duplicate()
    for cell in retained.get("boundaries",{}): retained.boundaries[cell] = retained.boundaries[cell].duplicate()
    var derived = WorldRows.update_rows(input.state,input.cache,retained,input.changes)
    var cells = {}
    var visibility = WorldRows.current_ids(input.state,retained.boundaries,cells)
    # The live owner replaces this set rather than mutating it. Its identity
    # lets admission reject this delta if sight was refreshed while preparing.
    var visibility_changes = {}
    for id in visibility:
        if not input.visibility.has(id): visibility_changes[id] = true
    for id in input.visibility:
        if not visibility.has(id): visibility_changes[id] = false
    var ground = {}; var wanted = {}; var packets = {}
    var background: bool = retained.negative.is_empty()
    for row in derived.visual_rows:
        if background and row.kind=="terrain" and row.base_height_steps==0 and row.material!="water":
            if not ground.has(row.material): ground[row.material] = []
            ground[row.material].append(row)
        else: wanted[row.id] = row
    for key in ground:
        if input.ground.has(key):
            if input.ground[key].rows!=ground[key]:
                packets[key] = GroundData.prepare(ground[key],input.ground[key],input.quarter,input.basis,visibility)
        else:
            var sorted: Array = ground[key].duplicate()
            var initial_packets = {}
            GroundData.sort_rows(sorted,initial_packets,input.quarter)
            packets[key] = {"new_rows":sorted,"new_packets":initial_packets}
    var geometry = {}
    if input.changes.full or not input.changes.tiles.is_empty() or not input.changes.objects.is_empty():
        geometry = WallReveal.prepare_geometry(input.state.tiles,derived.visual_rows,input.quarter)
    result = {"complete":true,"geometry":geometry,"derived":derived,"retained":retained,"wanted":wanted,"ground":ground,"packets":packets,
        "background":background,"needs_order":retained.changed or input.background!=background,"visibility":visibility,"visible_cells":cells,
        "visibility_base":input.visibility,"visibility_changes":visibility_changes,"worker_ms":(Time.get_ticks_usec()-started)/1000.0}

func step(budget_usec: int = 2000) -> void:
    if prepared or not media_issue.is_empty() or frame==Engine.get_process_frames(): return
    frame = Engine.get_process_frames()
    if task>=0:
        if not WorkerThreadPool.is_task_completed(task): return
        WorkerThreadPool.wait_for_task_completion(task); task = -1
        if not result.get("complete",false):
            media_issue = "World preparation failed before publishing its complete result."
            phase = "failed"
            if not media_issue in presentation_errors: presentation_errors.append(media_issue)
            return
        if phase=="sort_wait":
            if sorted_indices.size()!=order_records.size():
                media_issue = "World preparation failed to sort its complete static membership."; phase = "failed"; return
            phase = "order_publish"; cursor = 0
        else:
            wanted_ids = result.wanted.keys(); ground_keys = result.ground.keys(); phase = "objects"
    var started = Time.get_ticks_usec()
    while not prepared and Time.get_ticks_usec()-started<budget_usec:
        if phase=="objects":
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
                ground_job = _ground_begin(packet.new_rows,packet.new_packets)
                if not media_issue.is_empty(): phase = "failed"; return
            elif _ground_fill(ground_job):
                _ground_finish(ground_job)
                native_ground[key] = {"rows":result.ground[key],"entries":[ground_job.entry]}
                ground_job = {}; ground_cursor += 1
        elif phase=="membership_objects":
            if cursor==wanted_ids.size(): phase = "membership_ground"; ground_cursor = 0; continue
            var id: String = wanted_ids[cursor]; cursor += 1
            var group: Dictionary = native_groups.get(id,membership_base.groups.get(id,{}))
            membership.groups[id] = group
            _collect_membership(group)
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
            var representative: Dictionary = result.packets[key].rows[0] if result.packets.has(key) and result.packets[key].has("rows") else {}
            if native_ground.has(key):
                membership.new_groups.append(group)
                membership.upserts.append_array(group.entries)
                membership.entries_changed = true
            elif not representative.is_empty():
                membership.ground_updates.append({"entry":group.entries[0],"packet":result.packets[key]})
                membership.upserts.append(group.entries[0])
                membership.entries_changed = membership.entries_changed or group.entries[0].placement!=representative
                # Keep the displayed group immutable until this boundary is admitted.
                group = {"rows":result.ground[key],"entries":group.entries}
            membership.ground[key] = group
            _collect_membership(group,representative)
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
                if not result.needs_order: prepared = true; phase = "ready"
                else:
                    phase = "sort_wait"
                    task = WorkerThreadPool.add_task(_sort_order,false,"Sort prepared world")
                    break
                continue
            var key: String = retired_ground_keys[ground_cursor]; ground_cursor += 1
            if not result.ground.has(key): _collect_retired(membership_base.ground[key])
        elif phase=="order_publish":
            if cursor==sorted_indices.size(): phase = "order_release"; continue
            _prepare_order_record(sorted_indices[cursor]); cursor += 1
        elif phase=="order_release":
            if not order_records.is_empty(): order_records.pop_back()
            else:
                order_keys = []; order_ids = []; sorted_indices = []
                prepared = true; phase = "ready"
    FrameProfile.end_phase(profile,"world_prepare_native",started)

func _capture_membership() -> void:
    # These collection owners are replaced at static admission, never updated by
    # actor sampling. Dynamic entries deliberately aren't part of this proof.
    membership_base = {"groups":host.world_groups,"ground":host.ground_groups,"entries":host.static_entries,
        "groups_size":host.world_groups.size(),"ground_size":host.ground_groups.size(),"entries_size":host.static_entries.size(),
        "generation":host.world_generation,"quarter":host.world_quarter,"revision":host.world_revision,
        "light_serial":host.native_light_change_serial}

func can_publish_membership() -> bool:
    return prepared and membership.get("complete",false) and epoch==host.timeline.initialization_revision \
        and quarter==host.quarter and boundary.get("world_revision",-1)==host.timeline.world_revision \
        and membership_base.generation==host.world_generation and membership_base.quarter==host.world_quarter \
        and membership_base.revision==host.world_revision and membership_base.light_serial==host.native_light_change_serial \
        and is_same(membership_base.groups,host.world_groups) and membership_base.groups_size==host.world_groups.size() \
        and is_same(membership_base.ground,host.ground_groups) and membership_base.ground_size==host.ground_groups.size() \
        and is_same(membership_base.entries,host.static_entries) and membership_base.entries_size==host.static_entries.size()

func _begin_membership() -> void:
    membership = {"complete":false,"groups":{},"ground":{},"entries":[],"fixtures":[],"new_groups":[],
        "retired_groups":[],"ground_updates":[],"removed":{},"upserts":[],"entries_changed":false,"walls_changed":false}
    retired_ids = membership_base.groups.keys(); retired_ground_keys = membership_base.ground.keys()
    phase = "membership_objects"; cursor = 0

func _collect_membership(group: Dictionary, representative: Dictionary = {}) -> void:
    membership.entries.append_array(group.entries)
    for entry in group.entries:
        if entry.material.shader==FIXTURE_FLAME_SHADER: membership.fixtures.append(entry)
    if result.needs_order: _collect_order(group.entries,representative)

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
    complete_order.append(entry); complete_nodes[record.node_id] = true
    if not is_same(entry.get("order_placement"),record.placement) or entry.get("order_id","")!=record.id \
            or entry.get("order_quarter",-1)!=quarter or entry.get("order_background",null)!=result.background:
        order_updates.append(record)

func publish_order() -> void:
    if not result.needs_order or not is_same(host.static_entries,membership.entries): return
    for record in order_updates:
        var entry: Dictionary = record.entry
        entry.order_key = record.key; entry.order_placement = entry.placement
        entry.order_id = entry.id; entry.order_quarter = quarter; entry.order_background = result.background
    host.static_complete_order = complete_order; host.static_sort_nodes = complete_nodes
    # This proof belongs to the final adopted membership, and is consumed by
    # the next sort only. Later direct/manual updates still use discovery.
    host.prepared_static_order = {"entries":host.static_entries,"order":complete_order,
        "quarter":quarter,"background":result.background,"generation":host.world_generation,"epoch":epoch}

func worker_finished() -> bool:
    return task<0 or WorkerThreadPool.is_task_completed(task)

func join() -> void:
    if task>=0: WorkerThreadPool.wait_for_task_completion(task); task = -1

func release_handles() -> Array:
    join()
    var held = entries
    entries = []; static_entries = []; native_groups = {}; native_ground = {}; ground_job = {}
    order_records = []; order_keys = []; order_ids = []; sorted_indices = []
    membership_base = {}; membership = {}; complete_order = []; complete_nodes = {}; order_updates = []
    retired_ids = []; retired_ground_keys = []
    return held
