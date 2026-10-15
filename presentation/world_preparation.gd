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
var atlas_jobs: Array = []
var atlas_shells: Dictionary = {}
var atlas_fixture_shells: Dictionary = {}
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
    for key in host.ground_groups:
        var group: Dictionary = host.ground_groups[key]
        var entry: Dictionary = group.entries[0]
        ground_before[key] = {"rows":group.rows,"packets":entry.ground_packets,"receiver_bounds":entry.ground_receiver_bounds,"capacity":entry.node.multimesh.instance_count,"ground_version":entry.get("ground_version",0),"address_token":host.native_light_atlas.floor_address_token(entry)}
    # Copy only the cache directory here. Raw authoring values are immutable.
    # The worker forks every mutable retained index before touching it.
    var worker_cache:Dictionary=ActorConstruction.source_cache(catalog_cache)
    var existing_actors:Dictionary={}
    for id in host.visual_actors:
        var row:Dictionary=host.visual_actors[id].row
        existing_actors[id]={"rig":row.rig,"appearance":row.appearance,"equipment_layers":row.equipment_layers}
    var input = {"state":candidate.presentation_state,"changes":candidate.changes,
        "actor_state":candidate.state,"staged_actors":candidate.get("staged_actors",{}),
        "actor_samples":candidate.get("actor_samples",{}),
        "actor_loadouts":ActorConstruction.loadouts(candidate.get("actor_samples",{}),candidate.get("actor_layers",[])),"existing_actors":existing_actors,
        "cache":worker_cache,"retained":host.world_row_cache,
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
    var ground = {}; var wanted = {}; var packets = {}; var supports = {}
    var background: bool = retained.negative.is_empty()
    for row in derived.visual_rows:
        if GroundReceiving.eligible(row):
            var cell=Vector2(row.position[0],row.position[1])
            supports[cell]=maxf(float(supports.get(cell,-INF)),float(row.base_height_steps))
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
    var actors:Dictionary={}
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
        if ActorConstruction.matches(row,input.existing_actors.get(id,{})):continue
        var index:Dictionary=Characters._read("catalog-index.json",input.cache)
        var rig:Dictionary=Characters._read(index.rigs,input.cache)[row.rig]
        var resting:Dictionary=Characters.rest_sample(actor,rig,input.cache)
        var source_sample:Dictionary=input.actor_samples.get(id,resting.get("value",{}))
        actors[id]={"row":row,"rig":rig,"layers":Characters.layers(row,rig,input.cache),"entries":[],"playback":null,
            "source_sample":source_sample}
    result = {"complete":true,"actors":actors,"light_sources":SourceLighting.resolve(input.actor_state).sources,"geometry":geometry,"derived":derived,"retained":retained,"wanted":wanted,"ground":ground,"packets":packets,"supports":supports,
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
        if phase=="atlas_prefix_wait":
            result.worker_ms+=float(atlas_prefix.get("worker_ms",0.0))
            phase="atlas_prefix_bind"
        elif phase=="sort_wait":
            if sorted_indices.size()!=order_records.size():
                media_issue = "World preparation failed to sort its complete static membership."; phase = "failed"; return
            phase = "order_publish"; cursor = 0
        else:
            wanted_ids = result.wanted.keys(); ground_keys = result.ground.keys()
            actor_ids=result.actors.keys();phase="cookie_resources"
    var started = Time.get_ticks_usec()
    while not prepared and Time.get_ticks_usec()-started<budget_usec:
        if phase=="cookie_resources":
            if cookie_source_cursor==result.light_sources.size():phase="actors";continue
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
        elif phase=="actors":
            if actor_cursor==actor_ids.size():phase="objects";continue
            _prepare_actor()
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
                if not result.needs_order: _begin_atlas_preparation()
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
                _begin_atlas_preparation()
        elif phase=="atlas_receivers":
            if atlas_cursor==atlas_jobs.size():
                atlas_prefix=AtlasDelta.begin_candidate(host.native_light_atlas,atlas_jobs,membership.removed,host)
                phase="atlas_prefix_capture";continue
            _prepare_atlas_receiver()
        elif phase=="atlas_prefix_capture":
            if AtlasDelta.capture_candidate(host.native_light_atlas,atlas_prefix,host):
                if atlas_prefix.has("error"):
                    _finish_preparation();continue
                phase="atlas_prefix_wait"
                task=WorkerThreadPool.add_task(AtlasDelta.compute_candidate.bind(atlas_prefix),false,"Plan prepared lighting addresses")
                break
        elif phase=="atlas_prefix_bind":
            if AtlasDelta.prepare_candidate_binding(host.native_light_atlas,atlas_prefix,atlas_shells):
                _finish_preparation()
    FrameProfile.end_phase(profile,"world_prepare_native",started)

func _prepare_cookie_resource() -> void:
    var source:Dictionary=result.light_sources[cookie_source_cursor]
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
        prepared.playback=ActorConstruction.graph(self,prepared.rig,host.animation_templates)
        native_actors[id]=prepared
        return
    var index:int=prepared.entries.size()
    if index<prepared.layers.size():
        var entry:Dictionary=ActorConstruction.layer(self,prepared.row,prepared.rig,prepared.layers[index],index)
        ActorConstruction.prepare_neutral(entry,host.textures,host.resources)
        _prepare_actor_source(prepared,entry)
        prepared.entries.append(entry)
        created_count+=1
    else:actor_cursor+=1

func _prepare_actor_source(prepared:Dictionary,entry:Dictionary)->void:
    var selected:Dictionary=prepared.get("source_sample",{})
    var clip:String=selected.get("clip","")
    var layer:Dictionary=entry.actor_layer
    entry.atlas_preparation={"status":"no_selected_clip","clip":clip}
    if not layer.paths.has(clip) or not prepared.rig.clips.has(clip):return
    var path:String=layer.paths[clip]
    # This only initializes hidden material resources. It never requests media
    # or samples a graph; the displayed actor still chooses its current pose.
    entry.atlas_preparation.path=path
    if not host.textures.has(path):entry.atlas_preparation.status="missing_colour_texture";return
    if not host.source_images.has(path):entry.atlas_preparation.status="missing_colour_image";return
    for companion in ActorConstruction.CharacterGeometry.paths(path,layer.slot,host.catalog_cache,host.character_light_profile):
        if not host.textures.has(companion):
            entry.atlas_preparation.status="missing_companion";entry.atlas_preparation.missing_path=companion;return
    var facing:String=prepared.row.facing
    if host.external_playback:facing="SW"
    var cycle:Array=host.rig_config.FACING_CYCLE
    facing=cycle[posmod(cycle.find(facing)+quarter*2,8)]
    # A valid source frame is enough to prepare all non-frame bindings. The
    # actual first sample either certifies the adjacent UV change or fully binds.
    var frame:int=clampi(int(float(selected.get("source_seconds",0.0))*prepared.rig.clips[clip].fps),0,int(prepared.rig.clips[clip].frames)-1)
    var neutral:Dictionary=ActorConstruction.Conditions.material(entry.placement.id,[])
    var key:Array=ActorConstruction.material_key(neutral,host.textures,host.resources)
    ActorConstruction.bind_source(host,entry,prepared.rig,path,frame,facing,neutral,key,[])
    entry.atlas_preparation.status="atlas_not_ready"
    if host.native_light_atlas.delta_ready:
        entry.atlas_preparation.status="empty_material_binding"
        var materials:Dictionary=host.native_light_atlas.prepare_source_binding(entry,{},host,true)
        if not materials.is_empty():
            if not prepared.has("materials"):prepared.materials={}
            prepared.materials[entry.node.get_instance_id()]=materials
            entry.atlas_preparation.status="prepared"

func take_actor(id:String,row:Dictionary,rig:Dictionary)->Dictionary:
    var prepared:Dictionary=native_actors.get(id,{})
    if prepared.is_empty() or epoch!=host.timeline.initialization_revision or quarter!=host.quarter \
        or not is_same(actor_catalog_owner,host.catalog_cache) or not is_same(prepared.rig,rig) \
        or not ActorConstruction.matches(row,prepared.row):return {}
    if prepared.entries.size()!=prepared.layers.size() or prepared.playback==null:return {}
    native_actors.erase(id)
    return prepared

func _begin_atlas_preparation() -> void:
    # Private bindings are admitted by the sparse transaction. Initial/mode
    # rebuilds use the complete planner, so do not prepare resources it cannot
    # consume. Ordinary world/ground construction above remains unchanged.
    if not host.native_light_atlas.delta_ready:
        _finish_preparation();return
    var updated: Dictionary={}
    for update in membership.ground_updates:
        updated[update.entry.node.get_instance_id()]=update.packet
    for entry in membership.upserts:
        if not entry.has("cell"): continue
        var id: int=entry.node.get_instance_id()
        var packet:Dictionary=updated.get(id,{})
        var rows:Array=packet.geometry_changes.changed if not packet.is_empty() else entry.batch_rows if entry.has("batch_rows") else [entry.placement]
        atlas_jobs.append({"entry":entry,"rows":rows,"packet":packet})
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
        var snapshot:Dictionary=entry.duplicate()
        var packet:Dictionary=job.packet
        if not packet.is_empty():
            snapshot.ground_version=entry.get("ground_version",0)+1
            snapshot.batch_rows=packet.rows;snapshot.ground_packets=packet.packets
            snapshot.ground_indices=packet.indices;snapshot.ground_buffer=packet.buffer
            snapshot.scenery_values=packet.values;snapshot.placement=packet.rows[0]
        if snapshot.has("batch_rows"):
            # New native batches still contain the unpublished zero visibility.
            # Copy their mutable payloads; each row below receives the exact
            # prepared sight value without touching the displayed entry.
            snapshot.scenery_values=snapshot.scenery_values.duplicate()
            snapshot.ground_buffer=snapshot.ground_buffer.duplicate()
            snapshot.ground_packets=snapshot.ground_packets.duplicate()
        else:snapshot.scenery_value=1.0 if result.visibility.has(str(snapshot.placement.id)) else 0.0
        job.prepared=host.native_light_atlas.prepare_source_binding(entry,snapshot,host)
        if job.prepared.is_empty():
            if host.native_light_atlas._entry_info(entry).dynamic:
                # No clock is sampled here. The complete source already exists;
                # prepare its private copies beside the unassigned native node.
                var atlas=host.native_light_atlas
                if entry.material.shader==FIXTURE_FLAME_SHADER and not atlas.receiver_index.has(str(id)+":source"):
                    atlas_fixture_shells[id]={"entry":entry,"parent":atlas.projection_root,
                        "nodes":[atlas.prepare_receiver_node(atlas.projection_root)],
                        "materials":atlas.prepare_source_binding(entry,snapshot,host,true)}
                atlas_cursor+=1;atlas_row_cursor=0;return
            media_issue="World lighting preparation has no valid source bounds: "+str(entry.get("id",id))
            phase="failed"
            return
        # Receiver nodes can enter their final canvas while hidden. Their maps
        # stay exclusively owned here until the exact displayed atlas accepts
        # them, so preparation neither publishes addresses nor exposes pixels.
        job.prepared.receiver_parent=host.native_light_atlas.projection_root
        atlas_shells[id]=job.prepared
        return
    if atlas_row_cursor==job.rows.size():
        atlas_cursor+=1; atlas_row_cursor=0; return
    if not is_instance_valid(job.prepared.receiver_parent) or job.prepared.receiver_parent!=host.native_light_atlas.projection_root:
        atlas_cursor+=1; atlas_row_cursor=0; return
    var sampled:Dictionary=job.prepared.snapshot
    var row:Dictionary=sampled.batch_rows[sampled.ground_indices[str(job.rows[atlas_row_cursor])]] if not job.packet.is_empty() else job.rows[atlas_row_cursor]
    atlas_row_cursor+=1
    var visibility:float=1.0 if result.visibility.has(str(row.id)) else 0.0
    if sampled.has("batch_rows"):
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
    for id in atlas_fixture_shells.keys():
        var fixture:Dictionary=atlas_fixture_shells[id]
        if is_instance_valid(fixture.parent) and host.native_light_atlas.adopt_prepared_receivers(fixture.entry,fixture.nodes,fixture.parent):
            var materials:Dictionary=fixture.get("materials",{})
            if not materials.is_empty() and not host.native_light_atlas.adopt_source_binding(materials):
                AtlasDelta.retire_candidate(atlas_retirement,{}, {id:materials},false)
            atlas_fixture_shells.erase(id)
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
    var held = entries.duplicate()
    for prepared in native_actors.values():
        held.append_array(prepared.entries)
        if not prepared.get("materials",{}).is_empty():
            AtlasDelta.retire_candidate(atlas_retirement,{},prepared.materials,false)
            prepared.erase("materials")
    native_actors={};actor_ids=[];actor_catalog_owner={}
    cookie_jobs=[];cookie_seen={}
    for prepared in atlas_shells.values():
        for receiver in prepared.receivers.values():
            receiver.retire_external=true
            held.append(receiver)
    for fixture in atlas_fixture_shells.values():
        for node in fixture.nodes:held.append({"node":node,"retire_external":true})
        if not fixture.get("materials",{}).is_empty():
            AtlasDelta.retire_candidate(atlas_retirement,{}, {"fixture":fixture.materials},false)
    atlas_fixture_shells={}
    if not atlas_prefix.is_empty() or not atlas_shells.is_empty():
        AtlasDelta.retire_candidate(atlas_retirement,atlas_prefix,atlas_shells,false)
    entries = []; static_entries = []; actor_entries = []; native_groups = {}; native_ground = {}; ground_job = {}
    order_records = []; order_keys = []; order_ids = []; sorted_indices = []
    membership_base = {}; membership = {}; complete_order = []; complete_nodes = {}; order_updates = []
    retired_ids = []; retired_ground_keys = []; atlas_jobs=[]; atlas_shells={}; atlas_prefix={}
    return held
