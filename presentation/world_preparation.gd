extends "res://presentation/sprite_sources.gd"
const Tracks=preload("res://presentation/tracks.gd")
# One unpublished world boundary. Worker owns passive projection/buffers;
# the scene thread builds changed native groups.
const WorldRows = preload("res://presentation/world.gd")
const Characters = preload("res://presentation/characters.gd")
const ActorConstruction = preload("res://presentation/actor_construction.gd")
const GroundData = preload("res://presentation/ground_data.gd")
const WallReveal = preload("res://presentation/wall_reveal.gd")
const GroundReceiving = preload("res://presentation/ground_receiving.gd")
const SourceLighting = preload("res://presentation/lighting_2d.gd")
const Blood=preload("res://presentation/blood.gd")
const MediaWarmup=preload("res://presentation/media_warmup.gd")
const GroundOverlay=preload("res://presentation/ground_overlay.gd")
const EnvironmentResources=preload("res://presentation/environment_resources.gd")
const ActorResources=preload("res://presentation/actor_resources.gd")
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
var actor_scan_cursor:int=0
var actor_resource_task:int=-1
var actor_resources_started:bool=false
var actor_resource_output:Dictionary={}
var actor_resource_inputs:Dictionary={}
var actor_resource_textures:Dictionary={}
var actor_resource_names:Dictionary={}
var object_cursor:int=0
var objects_complete:Dictionary={}
var object_target_count:int=-1
var ground_target_count:int=-1
var construction_turn:int=0
var actor_blocked_frame:int=-1
var object_blocked_frame:int=-1
var object_work_counts:Dictionary={"attempts":0,"visited":0,"completed_skips":0,"source_waits":0,"retained":0,"constructed":0,"primed":0}
var ground_complete:Dictionary={}
var environment_task:int=-1
var environment_capture_complete:bool=false
var environment_capture_cursor:int=0
var environment_scan_cursor:int=0
var environment_ids:Array=[]
var environment_inputs:Dictionary={}
var environment_output:Dictionary={}
var environment_batch_output:Dictionary={}
var blocked_actor:Dictionary={}
var blocked_source:Dictionary={}
var phase_usec:Dictionary={}
var actor_catalog_owner: Dictionary = {}
var actor_bases:Dictionary={}
var actor_bindings:Array=[]
var binding_cursor:int=0
var blood_preparation:Dictionary={"handles":{},"retired":[]}
var blood_renderer:RefCounted
var required_source_record:Dictionary={}
var environment_source_record:Dictionary={}
var optical_owner:RefCounted
var light_preparation:Dictionary={}
var cookie_source_cursor:int=0
var wanted_ids: Array = []
var ground_keys: Array = []
var cursor = 0
var ground_cursor = 0
var ground_job: Dictionary = {}
var prepared = false
var handles_released:bool=false
var admitted = false
var stale = false
var initial = false
var phase = "projection"
var created_count = 0
var order_records: Array = []
var order_keys: Array = []
var order_ids: Array = []
var sorted_indices: Array = []
var sort_worker_ms:float=0.0
var membership_base: Dictionary = {}
var membership: Dictionary = {}
var retired_ids: Array = []
var retired_ground_keys: Array = []
var complete_order: Array = []
var complete_nodes: Dictionary = {}
var order_updates: Array = []
var scenery_jobs:Array=[]
var scenery_cursor:int=0
var scenery_style_ids:Array=[]
var scenery_style_cursor:int=0
var scenery_packet_entries:Dictionary={}
# Every new entry of this preparation, for the spell receiver boundary.
var boundary_jobs: Array = []
var membership_inputs_ready:bool=false
var membership_full:bool=false
var native_receiver_boundary:Dictionary={}

func texture(path: String) -> Texture2D:
    var value: Texture2D = host.texture(path)
    if value==null: media_issue = "World preparation is missing texture: "+path
    return value
func _light_entry(entry: Dictionary) -> void: host._light_entry(entry)

static func capture_static(owner:Node,candidate:Dictionary,first:bool=false)->Dictionary:
    # One passive forecast borrows the same published static owners as an
    # ordinary preparation. No Node, actor pose/material or timeline advances.
    var target_quarter:int=owner.quarter
    var ground_before = {}
    var affected_materials = {}
    var global_rows: bool = first or candidate.changes.get("full",false) or owner.world_quarter!=target_quarter \
        or not candidate.changes.get("order",[]).is_empty() or _background_for(candidate.presentation_state,owner.world_row_cache,candidate.changes)!=owner.ground_is_background
    if global_rows:
        for key in owner.ground_groups: affected_materials[key] = true
    else:
        for key in candidate.changes.get("tiles",{}):
            var old: Dictionary = owner.world_row_cache.get("tile_rows",{}).get(key,{})
            if not old.is_empty(): affected_materials[old.material] = true
            if candidate.presentation_state.tiles.has(key): affected_materials[candidate.presentation_state.tiles[key].surface.base_material] = true
    for key in affected_materials:
        if not owner.ground_groups.has(key): continue
        var group: Dictionary = owner.ground_groups[key]
        var entry: Dictionary = group.entries[0]
        # Only numeric immutable geometry crosses the worker boundary. Visibility
        # continues to belong to the displayed entry.
        ground_before[key] = {"rows":group.rows,"geometry":entry.ground_geometry,
            "receiver_bounds":entry.ground_receiver_bounds,"capacity":entry.node.multimesh.instance_count,
            "ground_version":entry.get("ground_version",0)}
    var source_cache:Dictionary=ActorConstruction.source_cache(owner.catalog_cache)
    var measured:bool=bool(owner.profile.get("recording",false))
    # This private worker owns diagnostics from its first source admission,
    # including static tables loaded before actor preparation begins.
    if measured:source_cache.__actor_source_profile={}
    return {"state":candidate.presentation_state,"changes":candidate.changes,
        "initial":first,"world_changed":first or candidate.get("world_revision",-1)!=owner.world_revision,
        "canonical_tiles":candidate.state.tiles,"light_state":candidate.state,
        "light_inputs":owner.light_source_inputs if owner.light_source_epoch==owner.timeline.initialization_revision else null,
        "light_resolution":{"sources":owner.source_lighting.sources,"issues":[]},
        "blood_existing":owner.component_renderer.blood.world_values(),
        "blood_index_full":first or candidate.changes.get("full",false) or owner.component_renderer.blood.tiles_revision<0,
        "cache":source_cache,"profile_actor_worker":measured,"retained":owner.world_row_cache,
        "environment_options":{"depth":owner.source_depth,"normals":owner.source_normals},
        "ground":ground_before,"quarter":target_quarter,"basis":owner.camera.basis,"background":owner.ground_is_background,
        "global_rows":global_rows,"visibility":owner.scenery_visibility,"visible_cells":owner.scenery_visible_cells,
        "ground_support":owner.ground_overlay.capture_support(),
        "base":{"epoch":owner.timeline.initialization_revision,"world_revision":owner.world_revision,
            "quarter":target_quarter,"world_generation":owner.world_generation,"row_owner":owner.world_row_cache,
            "source_depth":owner.source_depth,"source_normals":owner.source_normals,
            "groups":owner.world_groups,"ground":owner.ground_groups,"entries":owner.static_entries,
            "support_owner":owner.ground_overlay.support_owner,
            "preparation_key":candidate.key if first else candidate.preparation_key}}

func configure(owner:Node,candidate:Dictionary,first:bool=false,forecast:Dictionary={})->void:
    host=owner;boundary=candidate;initial=first;quarter=host.quarter
    blood_renderer=host.component_renderer.blood
    epoch=host.timeline.initialization_revision
    _capture_membership()
    visible=false;catalog_cache=host.catalog_cache;profile=host.profile
    actor_catalog_owner=host.catalog_cache;rig_config=host.rig_config;rigs=host.rigs
    source_images=host.source_images;source_depth=host.source_depth;source_normals=host.source_normals
    fixture_clips=host.fixture_clips;fixture_frame_energy=host.fixture_frame_energy;fixture_frame_centroids=host.fixture_frame_centroids
    fixture_clock_owner=host;presentation_errors=host.presentation_errors
    camera=Camera3D.new();add_child(camera);camera.basis=host.camera.basis
    if not forecast.is_empty() and not forecast.complete:
        result=forecast;media_issue=str(forecast.error);phase="failed"
        return
    var input:Dictionary=capture_static(owner,candidate,first) if forecast.is_empty() else {
        "cache":ActorConstruction.source_cache(host.catalog_cache),"global_rows":forecast.static_result.global_rows}
    # Actor operands belong to promotion, after the previous source-only cut has
    # published. A static forecast never lends old layer/pose/native bindings.
    var existing_actors:Dictionary={}
    for id in host.visual_actors:
        var row:Dictionary=host.visual_actors[id].row
        var geometry:Dictionary={};var layers:Array=[];var binding_keys:Dictionary={}
        for entry in host.visual_actors[id].entries:
            layers.append(entry.actor_layer)
            binding_keys[entry.actor_layer.slot]=entry.get("prepared_source_binding",{}).get("geometry",{}).get("key",[])
            geometry[entry.actor_layer.slot]={"present":bool(SourceMaterial.value(entry,"has_component_geometry")),
                "cell":entry.get("geometry_cell_size",Vector2(128,128))}
        existing_actors[id]={"rig":row.rig,"appearance":row.appearance,"equipment_layers":row.equipment_layers,"geometry":geometry,"layers":layers,"binding_keys":binding_keys}
        actor_bases[id]={"actor":host.visual_actors[id],"playback":host.playbacks[id]}
    input.merge({"state":candidate.presentation_state,"changes":candidate.changes,
        "initial":first,"world_changed":first or candidate.get("world_revision",-1)!=host.world_revision,
        "actor_state":candidate.state,"staged_actors":candidate.get("staged_actors",{}),
        "actor_samples":candidate.get("actor_samples",{}),
        "profile_actor_worker":bool(host.profile.get("recording",false)),
        "layer_clips":candidate.get("actor_layers",[]).filter(func(row):return row.kind=="sprite_layer").reduce(func(values,row):values[row.id]=row.get("clip","");return values,{}),
        "source_options":{"depth":host.source_depth,"normals":host.source_normals,"profile":host.character_light_profile,"tile_width":host.rig_config.TILE_W},
        "actor_loadouts":ActorConstruction.loadouts(candidate.get("actor_samples",{}),candidate.get("actor_layers",[])),"existing_actors":existing_actors},true)
    if forecast.is_empty():task=WorkerThreadPool.add_task(_derive.bind(input),false,"Prepare displayed world")
    else:task=WorkerThreadPool.add_task(_derive_forecast.bind(input,forecast),false,"Prepare current world actors")

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
        cells = {}; visibility = WorldRows.current_ids(input.state,input.retained.get("boundaries",{}),cells,patch,patch.get("prepared_indexes",{}).get("spatial_rows",input.retained.get("spatial_rows",{})),patch.get("prepared_indexes",{}).get("residue_rows",input.retained.get("residue_rows",{})))
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
        for id in patch.get("writes",{}).get("residue_rows",{}):
            var row:Dictionary=patch.writes.residue_rows[id]
            changes[id]=cells.has(WorldRows.cell_key(row.position))
        for id in patch.get("removes",{}).get("residue_rows",{}):changes[id]=false
        for id in patch.get("writes",{}).get("spatial_rows",{}):changes[id]=true
        for id in patch.get("removes",{}).get("spatial_rows",{}):changes[id]=false
    return {"visibility":visibility,"cells":cells,"changes":changes,"sparse":not full}

func candidate_visible(id: String) -> bool:
    return bool(result.visibility_changes.get(id,result.visibility.has(id)))

static func _derive_support_walls(input:Dictionary,rebuild_rows:bool,all_rows:Array,full_membership:bool,side:Dictionary)->void:
    var started:int=Time.get_ticks_usec()
    side.support=GroundOverlay.prepare_support(input.state.tiles,input.changes,input.get("ground_support",{}),rebuild_rows)
    side.support_ms=(Time.get_ticks_usec()-started)/1000.0;started=Time.get_ticks_usec()
    # Full membership/view changes are explicit larger geometry jobs. Sparse
    # source changes use the existing owner-side wall bucket invalidations.
    side.geometry=WallReveal.prepare_geometry(input.state.tiles,all_rows,input.quarter) if full_membership else {}
    side.walls_ms=(Time.get_ticks_usec()-started)/1000.0

static func _row_sources(row:Dictionary,quarter:int,cache:Dictionary)->Dictionary:
    var paths:Dictionary={};var fixtures:Dictionary={}
    var variants:Array=[row]
    variants.append_array(row.get("wall_members",[]))
    for value in variants:
        var source:Dictionary=value
        if value.has("views"):
            source=value.duplicate();source.asset=source.views[Placement.pose(source.orientation,quarter)]
        EnvironmentMedia.record_paths(Catalog.environment(source,quarter,cache),paths,cache)
        if source.kind=="door":EnvironmentMedia.record_paths(Catalog.door_frame(source,quarter,cache),paths,cache)
        if source.get("water_surface",false):
            var assets:Dictionary=Catalog.environment_resources(cache)
            paths[assets.resources[assets.water.ripple].path]=true
    paths.merge(EnvironmentMedia.world_media_paths(row,cache))
    if row.has("lit_animation"):
        var assets:Dictionary=Catalog.environment_resources(cache)
        for frame in assets.animations[row.lit_animation].frames:
            var path:String=assets.resources[frame].path
            paths[path]=true;fixtures[path]=true
    return {"paths":paths,"fixtures":fixtures}

func _derive(input:Dictionary)->void:
    var forecast:Dictionary={}
    derive_static(input,forecast)
    if not forecast.get("complete",false):result=forecast;return
    result=_complete_actors(input,forecast)

func _derive_forecast(input:Dictionary,forecast:Dictionary)->void:
    # Fresh actor sources admitted by the predecessor and passive sources
    # admitted by forecasting both survive in the worker's private cache shell.
    Catalog.adopt_snapshot(input.cache,forecast.source_files)
    # Static forecasting has finished before promotion. Retain its private
    # counters while admitting current actor sources into the new cache shell.
    if input.get("profile_actor_worker",false):
        input.cache.__actor_source_profile=forecast.cache.get("__actor_source_profile",{})
    result=_complete_actors(input,forecast)

static func _derive_ground_material(input:Dictionary,job:Dictionary,full_membership:bool,sight:Dictionary,slots:Dictionary)->void:
    var key:String=job.key
    var before: Dictionary = input.ground.get(key,{})
    if not full_membership and not before.is_empty():
        var geometry_patch = GroundData.prepare_changes(job.changes,job.removed,before.geometry)
        if not geometry_patch.rebuild_required:
            if not geometry_patch.changed.is_empty():
                var changed_packets = {}
                for id in geometry_patch.records:
                    changed_packets[id] = GroundData._packet(geometry_patch.records[id],bool(sight.changes.get(id,sight.visibility.has(id))))
                job.result.packet = {"sparse":true,"geometry_patch":geometry_patch,"row_changes":job.changes,
                    "packets":changed_packets,"indices":before.geometry.indices,"rows":before.geometry.rows,
                    "geometry_changes":{"base_version":before.ground_version,"changed":geometry_patch.changed,"removed":[]}}
            return
    var rows: Array = job.rows
    if not full_membership:
        var by_id = {}
        if not before.is_empty():
            for row in before.rows: by_id[row.id] = row
        for id in job.removed: by_id.erase(id)
        by_id.merge(job.changes,true)
        rows = by_id.values()
        rows.sort_custom(func(a,b):return slots[a.id]<slots[b.id])
        job.result.rows = rows
    if rows.is_empty(): return
    if before.is_empty():
        var sorted: Array = rows.duplicate(); var initial_packets = {}; var ranks = {}
        for i in rows.size(): ranks[rows[i].id] = i
        GroundData.sort_rows(sorted,initial_packets,input.quarter)
        job.result.packet = {"new_rows":sorted,"new_packets":initial_packets,"source_ranks":ranks}
    elif before.rows!=rows:
        var visible = {}
        for row in rows:
            if sight.changes.get(row.id,sight.visibility.has(row.id)): visible[row.id] = true
        job.result.packet = GroundData.prepare(rows,before,input.quarter,input.basis,visible)

const SOURCE_CHUNK_ROWS:=24
const SOURCE_CHUNKS:=4

static func _derive_row_sources(input:Dictionary,wanted:Dictionary,sight:Dictionary,chunk:Dictionary)->void:
    var cache:Dictionary=chunk.cache
    for id in chunk.ids:
        var row:Dictionary=wanted[id]
        var previous:Dictionary=_old_visual(input.retained,id)
        var packet:Dictionary={}
        if input.get("initial",false) or previous!=row:
            var options:Dictionary=input.environment_options
            packet=EnvironmentSource.row_packet(row,input.quarter,input.basis,cache,options.depth,options.normals)
        if packet.get("eligible",false):
            # This is the same visibility operand applied by the private
            # scenery owner. Seed it before final source construction.
            for selected in packet.entries:
                selected.light_parameters=SourceMaterial.environment_policy(selected.placement.kind,selected.role)
                if selected.descriptor.get("empty",false):continue
                var source_id:String=str(selected.placement.id)
                selected.descriptor.parameters.current_visibility=1.0 if sight.changes.get(source_id,sight.visibility.has(source_id)) else 0.0
            chunk.packets[id]=packet
            # A fixture flame still needs its frames and optical facts.
            chunk.sources[id]=_row_sources(row,input.quarter,cache) if row.has("lit_animation") else {"paths":packet.paths,"fixtures":{}}
        else:chunk.sources[id]=_row_sources(row,input.quarter,cache)

static func derive_static(input:Dictionary,output:Dictionary)->void:
    var started = Time.get_ticks_usec()
    var worker_phases:Dictionary={};var phase_started:int=started
    var patch = WorldRows.prepare_changes(input.state,input.cache,input.retained,input.changes)
    worker_phases.rows=(Time.get_ticks_usec()-phase_started)/1000.0;phase_started=Time.get_ticks_usec()
    var background: bool = _background_for(input.state,input.retained,input.changes)
    var full_membership: bool = input.global_rows or patch.rebuild_visual
    # Moving between a native source and a batch is a real membership change.
    for id in patch.visual_changes:
        var old: Dictionary = _old_visual(input.retained,id)
        var row: Dictionary = patch.visual_changes[id]
        var was_static: bool = not old.is_empty() and not _floor(old,input.background)
        var now_static: bool = not row.is_empty() and not _floor(row,background)
        full_membership = full_membership or was_static!=now_static
    var all_rows: Array = _all_visual(input.retained,patch) if full_membership else []
    # Terrain supports for the lit floors' join masks, rebuilt only when terrain rows change.
    var terrain_changed: bool = full_membership
    if not terrain_changed:
        for id in patch.visual_changes:
            if GroundReceiving.eligible(patch.visual_changes[id]) or GroundReceiving.eligible(_old_visual(input.retained,id)):
                terrain_changed = true; break
    var ground_supports: Dictionary = GroundReceiving.support_image_rows(all_rows if full_membership else _all_visual(input.retained,patch)) if terrain_changed else {}
    # Support directories and wall geometry read only immutable after-values
    # and touch no catalog cache. They overlap visibility, routing, ground and
    # source preparation instead of extending this worker's sequence.
    var side:Dictionary={}
    var side_task:int=WorkerThreadPool.add_task(_derive_support_walls.bind(input,patch.rebuild_rows,all_rows,full_membership,side),false,"Prepare support and wall geometry")
    var sight = _candidate_visibility(input,patch)
    worker_phases.visibility=(Time.get_ticks_usec()-phase_started)/1000.0;phase_started=Time.get_ticks_usec()
    var ground = {}; var wanted = {}; var packets = {}; var supports = {}
    var ground_changes = {}; var ground_removed = {}; var removed_wanted: Array = []
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
    worker_phases.routing=(Time.get_ticks_usec()-phase_started)/1000.0;phase_started=Time.get_ticks_usec()
    # Each floor material is independent: one task per material, results
    # merged in material order.
    var affected: Array = ground.keys() if full_membership else ground_changes.keys()
    var slots: Dictionary = patch.get("prepared_visual_slots",input.retained.get("visual_slots",{}))
    var ground_jobs: Array = []
    for key in affected:
        ground_jobs.append({"key":key,"rows":ground.get(key,[]),"changes":ground_changes.get(key,{}),"removed":ground_removed.get(key,[]),"result":{}})
    var ground_tasks: Array = []
    for job in ground_jobs.slice(1):
        ground_tasks.append(WorkerThreadPool.add_task(_derive_ground_material.bind(input,job,full_membership,sight,slots),false,"Prepare floor material"))
    if not ground_jobs.is_empty(): _derive_ground_material(input,ground_jobs[0],full_membership,sight,slots)
    for task in ground_tasks: WorkerThreadPool.wait_for_task_completion(task)
    for job in ground_jobs:
        if job.result.has("rows"): ground[job.key] = job.result.rows
        if job.result.has("packet"): packets[job.key] = job.result.packet
    worker_phases.ground=(Time.get_ticks_usec()-phase_started)/1000.0;phase_started=Time.get_ticks_usec()
    var object_sources:Dictionary={};var ground_sources:Dictionary={};var environment_packets:Dictionary={}
    # Rows are independent: chunks run on their own catalog snapshots and are
    # merged back in row order, with the records they admitted.
    var ids:Array=wanted.keys()
    var chunk_count:int=clampi(ids.size()/SOURCE_CHUNK_ROWS,1,SOURCE_CHUNKS)
    var chunks:Array=[]
    for index in chunk_count:
        chunks.append({"ids":ids.slice(index*ids.size()/chunk_count,(index+1)*ids.size()/chunk_count),
            "cache":Catalog.source_snapshot(input.cache) if chunk_count>1 else input.cache,"packets":{},"sources":{}})
    var chunk_tasks:Array=[]
    for chunk in chunks.slice(1):
        chunk_tasks.append(WorkerThreadPool.add_task(_derive_row_sources.bind(input,wanted,sight,chunk),false,"Prepare environment row sources"))
    _derive_row_sources(input,wanted,sight,chunks[0])
    for task in chunk_tasks:WorkerThreadPool.wait_for_task_completion(task)
    for chunk in chunks:
        if not is_same(chunk.cache,input.cache):Catalog.adopt_snapshot(input.cache,chunk.cache)
        environment_packets.merge(chunk.packets);object_sources.merge(chunk.sources)
    var ordered_sources:Dictionary={}
    for id in ids:ordered_sources[id]=object_sources[id]
    object_sources=ordered_sources
    var ordered_packets:Dictionary={}
    for id in ids:
        if environment_packets.has(id):ordered_packets[id]=environment_packets[id]
    environment_packets=ordered_packets
    for key in ground:
        if not ground[key].is_empty() and not input.ground.has(key):ground_sources[key]=_row_sources(ground[key][0],input.quarter,input.cache)
    var environment_paths:Dictionary={};var environment_fixtures:Dictionary={}
    for sources in object_sources.values()+ground_sources.values():
        environment_paths.merge(sources.paths);environment_fixtures.merge(sources.fixtures)
    environment_paths.make_read_only()
    worker_phases.sources=(Time.get_ticks_usec()-phase_started)/1000.0;phase_started=Time.get_ticks_usec()
    WorkerThreadPool.wait_for_task_completion(side_task)
    var ground_support:Dictionary=side.support;var geometry:Dictionary=side.geometry
    worker_phases.support=side.support_ms;worker_phases.walls=side.walls_ms
    worker_phases.side_wait=(Time.get_ticks_usec()-phase_started)/1000.0;phase_started=Time.get_ticks_usec()
    var canonical_tiles:Dictionary=input.canonical_tiles if input.has("canonical_tiles") else input.actor_state.tiles
    # The existing sparse/full terrain walk supplies authoritative residue
    # values, including remembered/offscreen cells. Camera motion cannot create
    # an unprepared deposit later merely because a field was offscreen here.
    var blood_rows:Dictionary={}
    var blood_index:Dictionary={"full":input.get("blood_index_full",input.changes.get("full",false)),"updates":{},"removed":{}}
    var blood_keys:Dictionary=input.changes.get("tiles",{}).duplicate()
    if blood_index.full:
        for key in canonical_tiles:blood_keys[key]=true
    if full_membership:
        for row in rows_to_route:
            if not row.is_empty() and row.kind=="terrain":blood_keys[WorldRows.cell_key(row.position)]=true
        for key in input.get("blood_existing",{}):blood_keys[key]=true
    var residue_ids:Array=Blood.residue_ids(input.cache)
    var cells:Dictionary={}
    for field in blood_keys:cells[Blood.field_cell(str(field))]=true
    for cell in cells:
        var tile:Dictionary=input.state.tiles.get(cell,{})
        var canonical:Dictionary=canonical_tiles.get(cell,{})
        for residue_id in residue_ids:
            var key:String=Blood.field_id(cell,residue_id)
            var residue:Dictionary=Blood.residue(tile,residue_id)
            var canonical_residue:Dictionary=residue if is_same(tile,canonical) else Blood.residue(canonical,residue_id)
            if not canonical_residue.is_empty():blood_index.updates[key]=canonical
            elif not blood_index.full:blood_index.removed[key]=true
            if residue.is_empty():
                if input.get("blood_existing",{}).has(key):blood_rows[key]={"removed":true}
                continue
            var source:Dictionary=Catalog.residue_asset(input.cache,residue_id)
            if source.is_empty():output.merge({"complete":false,"error":"Cannot prepare selected residue source: "+str(residue_id)});return
            var prior:Dictionary=input.get("blood_existing",{}).get(key,{})
            if is_same(prior.get("value"),residue) and is_same(prior.get("source"),source):continue
            var kernel_cache:Dictionary={}
            var kernels:Array=Blood.kernels(residue,tile.position,[],source,kernel_cache)
            blood_rows[key]={"tile":tile,"value":residue,"source":source,"cache":kernel_cache,"kernels":kernels,"coverage":Blood.has_coverage(kernels)}
    worker_phases.blood=(Time.get_ticks_usec()-phase_started)/1000.0;phase_started=Time.get_ticks_usec()
    var light_state:Dictionary=input.light_state if input.has("light_state") else input.actor_state
    var light_resolution:Dictionary={}
    var senses:Variant=light_state.get("senses")
    var optical:Variant=light_state.get("light_sources",{})
    if optical!=null and input.get("light_inputs")!=null and optical==input.light_inputs:
        light_resolution=input.light_resolution
    else:light_resolution=SourceLighting.resolve(light_state)
    worker_phases.lights=(Time.get_ticks_usec()-phase_started)/1000.0;phase_started=Time.get_ticks_usec()
    var source_files:Dictionary=Catalog.source_snapshot(input.cache)
    worker_phases.source_snapshot=(Time.get_ticks_usec()-phase_started)/1000.0
    var value:Dictionary={"light_resolution":light_resolution,"geometry":geometry,
        "row_patch":patch,"wanted":wanted,"removed_wanted":removed_wanted,"ground":ground,"packets":packets,"supports":supports,
        "background":background,"full_membership":full_membership,"global_rows":input.global_rows,"needs_order":full_membership,
        "visibility":sight.visibility,"visibility_sparse":sight.sparse,"visible_cells":sight.cells,"ground_support":ground_support,"ground_supports":ground_supports,
        "visibility_base":input.visibility,"visibility_changes":sight.changes,"blood_rows":blood_rows,"blood_index":blood_index,
        "object_sources":object_sources,"ground_sources":ground_sources,"environment_paths":environment_paths,"environment_packets":environment_packets,
        "environment_source_record":MediaWarmup.source_record(environment_paths,environment_paths,environment_fixtures)}
    output.merge({"complete":true,"base":input.get("base",{}),"static_result":value,"cache":input.cache,
        "worker_ms":(Time.get_ticks_usec()-started)/1000.0,"worker_phases":worker_phases,"source_files":source_files})

static func _complete_actors(input:Dictionary,forecast:Dictionary)->Dictionary:
    var started:int=Time.get_ticks_usec();var phase_started:int=started
    var worker_phases:Dictionary=forecast.worker_phases.duplicate()
    var measured:bool=input.get("profile_actor_worker",false)
    var actor_profile:Dictionary={}
    if measured:
        actor_profile=input.cache.get("__actor_source_profile",{})
        actor_profile.merge({"phase_usec":{},"actors_seen":0,"actors_visible":0,"actors_resolved":0,
            "prepare_layer_calls":0,"retained_layer_sets":0,"layers_seen":0,"bindings_prepared":0,"bindings_retained":0,"optical_lookups":0},true)
        input.cache.__actor_source_profile=actor_profile
    var actors:Dictionary={};var bindings:Dictionary={};var future_solid_paths:Dictionary={}
    var actor_members:Dictionary={}
    var actor_ids:Array=input.actor_state.actors.keys()
    for id in input.staged_actors:
        if not input.actor_state.actors.has(id):actor_ids.append(id)
    for id in actor_ids:
        var actor_started:int=Time.get_ticks_usec() if measured else 0
        if measured:actor_profile.actors_seen+=1
        var actor:Dictionary=input.actor_state.actors.get(id,input.staged_actors.get(id,{}))
        actor=ActorConstruction.actor_with_loadout(actor,input.actor_loadouts)
        var visible_actor:bool=WorldRows.visible_actor(actor,input.actor_state,input.staged_actors.has(id))
        _record_actor_worker_phase(actor_profile,"loadout_visibility",actor_started)
        if not visible_actor:continue
        if measured:actor_profile.actors_visible+=1
        var resolve_started:int=Time.get_ticks_usec() if measured else 0
        var resolved:Dictionary=Characters.resolve(actor,input.state,input.cache)
        _record_actor_worker_phase(actor_profile,"resolve_select",resolve_started)
        if not resolved.ok:
            return {"complete":false,"error":resolved.error.message,"worker_ms":(Time.get_ticks_usec()-started)/1000.0}
        if resolved.value==null:continue
        if measured:actor_profile.actors_resolved+=1
        var operands_started:int=Time.get_ticks_usec() if measured else 0
        var row:Dictionary=resolved.value
        actor_members[id]=row
        var before:Dictionary=input.existing_actors.get(id,{})
        var same_structure:bool=ActorConstruction.matches(row,before)
        var rig:Dictionary=Characters.rigs(input.cache)[row.rig]
        var source_sample:Dictionary=input.actor_samples.get(id,{})
        if source_sample.is_empty():
            var condition:Dictionary=ActorConstruction.Conditions.pose(actor,row.rig,input.cache)
            var resting:Dictionary={"ok":true,"value":{"clip":condition.clip,"source_seconds":0.0}} if not condition.is_empty() and rig.clips.has(condition.clip) else Characters.rest_sample(actor,rig,input.cache)
            if not resting.ok:
                return {"complete":false,"error":resting.error.message,"worker_ms":(Time.get_ticks_usec()-started)/1000.0}
            source_sample=resting.value
        var retained_slots:Dictionary={}
        var same_rig:bool=not before.is_empty() and row.rig==before.rig
        if same_rig and row.appearance==before.appearance:
            var selectors:Dictionary={}
            for layer in before.equipment_layers:selectors[layer.slot]=layer
            for layer in row.equipment_layers:
                if selectors.get(layer.slot)==layer:retained_slots[layer.slot]=true
        _record_actor_worker_phase(actor_profile,"rig_pose_membership",operands_started)
        var layers_started:int=Time.get_ticks_usec() if measured else 0
        if measured:
            if same_structure and before.has("layers"):actor_profile.retained_layer_sets+=1
            else:actor_profile.prepare_layer_calls+=1
        var selected:Dictionary={"ok":true,"value":before.layers} if same_structure and before.has("layers") else Characters.prepare_layers(row,rig,input.cache)
        _record_actor_worker_phase(actor_profile,"prepare_layers",layers_started)
        if not selected.ok:
            return {"complete":false,"error":selected.error.message,"worker_ms":(Time.get_ticks_usec()-started)/1000.0}
        var layers:Array=selected.value
        var source_bindings:Dictionary={}
        var options:Dictionary=input.get("source_options",{})
        for layer in layers:
            var selection_started:int=Time.get_ticks_usec() if measured else 0
            if measured:actor_profile.layers_seen+=1
            var selected_clip:String=input.get("layer_clips",{}).get(layer.get("effect",{}).get("component_id",""),source_sample.get("clip",""))
            if not layer.paths.has(selected_clip):
                _record_actor_worker_phase(actor_profile,"source_selection",selection_started)
                continue
            var source_key:Array=[layer.paths[selected_clip],options.get("depth",true),options.get("normals",true),
                128.0/float(options.get("tile_width",128))*row.scale,row.get("scale_x",1.0),options.get("profile","original")]
            var retained_binding:bool=same_structure and before.get("binding_keys",{}).get(layer.slot)==source_key
            _record_actor_worker_phase(actor_profile,"source_selection",selection_started)
            if retained_binding:
                if measured:actor_profile.bindings_retained+=1
                continue
            var binding_started:int=Time.get_ticks_usec() if measured else 0
            source_bindings[layer.slot]=ActorConstruction.prepare_binding(rig,layer,layer.paths[selected_clip],input.cache,
                options.get("depth",true),options.get("normals",true),options.get("profile","original"),
                128.0/float(options.get("tile_width",128))*row.scale,row.get("scale_x",1.0))
            _record_actor_worker_phase(actor_profile,"binding_geometry",binding_started)
            if measured:actor_profile.bindings_prepared+=1
            if layer.slot!="shadow" and (layer.get("effect",{}).is_empty() or layer.get("effect",{}).get("kind")=="condition_appearance"):
                var optical_started:int=Time.get_ticks_usec() if measured else 0
                var optical:Dictionary=ActorConstruction.CharacterGeometry.BodySources.descriptor(layer.paths[selected_clip],layer.slot,input.cache).get("optical_paths",{})
                if not optical.is_empty():future_solid_paths[optical.solid]=true
                _record_actor_worker_phase(actor_profile,"source_descriptor_optical",optical_started)
                if measured:actor_profile.optical_lookups+=1
        bindings[id]=source_bindings
        if same_structure:continue
        var retained_geometry_started:int=Time.get_ticks_usec() if measured else 0
        for layer in layers:
            if not retained_slots.has(layer.slot):continue
            var source:Dictionary=ActorConstruction.CharacterGeometry.record(layer.paths.get(source_sample.get("clip",""),""),layer.slot,input.cache)
            var prior_geometry:Dictionary=before.geometry[layer.slot]
            var cell:Array=source.get("cell_size",[128,128])
            if prior_geometry.present!=(not source.is_empty()) or (not source.is_empty() and prior_geometry.cell!=Vector2(cell[0],cell[1])):
                retained_slots.erase(layer.slot)
        _record_actor_worker_phase(actor_profile,"retained_geometry",retained_geometry_started)
        actors[id]={"row":row,"rig":rig,"layers":layers,"entries":[],"new_entries":[],"playback":null,
            "reuse_actor":same_rig,"retained_slots":retained_slots,"source_sample":source_sample,"source_bindings":source_bindings,
            "layer_clips":input.get("layer_clips",{}),"source_ready":{},"source_cursor":0}
    worker_phases.actors=(Time.get_ticks_usec()-phase_started)/1000.0
    if measured:actor_profile.actor_elapsed_usec=Time.get_ticks_usec()-phase_started
    var source_only:bool=not input.get("initial",false) and not input.get("world_changed",true) and not input.global_rows and actors.is_empty() \
        and not input.changes.get("full",false) and input.changes.get("tiles",{}).is_empty() \
        and input.changes.get("objects",{}).is_empty() and not input.changes.get("senses",false) \
        and input.changes.get("order",[]).is_empty() and actor_members.size()==input.existing_actors.size()
    if source_only:
        for id in input.existing_actors:
            if not actor_members.has(id):source_only=false;break
    var value:Dictionary=forecast.static_result.duplicate()
    value.merge({"complete":true,"source_only":source_only,"actors":actors,"actor_members":actor_members,
        "actor_bindings":bindings,"source_files":Catalog.source_snapshot(input.cache),"worker_phases":worker_phases,
        "required_source_record":MediaWarmup.source_record(future_solid_paths,{},{},future_solid_paths) if not future_solid_paths.is_empty() else {},
        "worker_ms":forecast.worker_ms+(Time.get_ticks_usec()-started)/1000.0},true)
    if source_only:value.light_resolution={}
    if measured:value.actor_worker_profile=actor_profile
    return value

static func _record_actor_worker_phase(profile:Dictionary,name:String,started:int)->void:
    if started>0:profile.phase_usec[name]=profile.phase_usec.get(name,0)+Time.get_ticks_usec()-started

func step(budget_usec: int = 2000) -> void:
    _refresh_actor_binding_owner()
    _poll_environment_resources()
    if prepared or stale or not media_issue.is_empty(): return
    var started = Time.get_ticks_usec()
    var environment_attempted:bool=false
    var timed:bool=host.profile.get("recording",false)
    var timed_phase:String=phase;var timed_from:int=started
    while not prepared:
        if timed and phase!=timed_phase:
            var now:int=Time.get_ticks_usec()
            phase_usec["phase:"+timed_phase]=phase_usec.get("phase:"+timed_phase,0)+now-timed_from
            timed_phase=phase;timed_from=now
        # A completed passive result may hand off even after another owner has
        # spent the allowance. The caller charges this real work; native scene
        # construction below still requires time in the same frame allowance.
        if task>=0:
            if not WorkerThreadPool.is_task_completed(task): break
            WorkerThreadPool.wait_for_task_completion(task); task = -1
            if not result.get("complete",false):
                media_issue = str(result.get("error","World preparation failed before publishing its complete result."))
                phase = "failed"
                if not media_issue in presentation_errors: presentation_errors.append(media_issue)
                break
            if phase=="sort_wait":
                if sorted_indices.size()!=order_records.size():
                    media_issue = "World preparation failed to sort its complete static membership."; phase = "failed"; break
                result.worker_ms+=sort_worker_ms;sort_worker_ms=0.0
                phase = "order_publish"; cursor = 0
            else:
                # Worker admission owns native body descriptors. Publish its
                # immutable references before any scene-thread source binding;
                # descriptor lookup during sampling never loads a Resource.
                Catalog.adopt_snapshot(host.catalog_cache,result.source_files)
                required_source_record=result.get("required_source_record",{})
                environment_source_record=result.get("environment_source_record",{})
                wanted_ids = result.wanted.keys(); ground_keys = result.ground.keys()
                environment_ids=result.get("environment_packets",{}).keys()
                environment_capture_complete=environment_ids.is_empty()
                for key in result.packets:
                    if key not in ground_keys: ground_keys.append(key)
                actor_ids=result.actors.keys()
                object_target_count=wanted_ids.size();ground_target_count=ground_keys.size()
                if source_only():
                    membership={"complete":true}
                    phase="sampling"
                else:
                    light_preparation=host.source_lighting.begin_preparation(result.light_resolution)
                    if light_preparation.complete:cookie_source_cursor=result.light_resolution.sources.size()
                    phase="construction"
                for id in result.get("actor_bindings",{}):
                    if result.actors.has(id):continue
                    for entry in host.visual_actors.get(id,{}).get("entries",[]):
                        var value:Dictionary=result.actor_bindings[id].get(entry.actor_layer.slot,{})
                        if not value.is_empty():actor_bindings.append({"entry":entry,"value":value,"actor":id,"owner":actor_bases[id].actor})
            continue
        if _advance_completed_phase():continue
        # These existing owners enforce the remaining allowance at each actual
        # constructor/upload. Polling their completed handles may settle now,
        # including a field whose real post-draw fence finished this frame.
        var polls_prepared:bool=phase=="native_receivers" or (phase=="sampling" and binding_cursor==actor_bindings.size())
        if Time.get_ticks_usec()-started>=budget_usec and not polls_prepared:break
        if phase=="construction":
            # This finite producer accepts missing texture refs and is independent
            # of cookie/light or environment construction. Start at the first
            # actual remaining allowance, never during a zero-budget ACK.
            if not actor_resources_started:_prepare_actor_resources()
            if not media_issue.is_empty():break
            if Time.get_ticks_usec()-started>=budget_usec:break
        if not environment_attempted and not environment_capture_complete and phase=="construction":
            environment_attempted=true
            _prepare_environment_resources(started+budget_usec)
            if Time.get_ticks_usec()-started>=budget_usec:break
        if not media_issue.is_empty() or stale:break
        if phase=="construction":
            if not _prepare_construction_turn(started+budget_usec):break
            if not media_issue.is_empty():
                phase="failed"
                if media_issue not in presentation_errors:presentation_errors.append(media_issue)
                break
        elif phase=="membership_begin":_begin_membership()
        elif phase=="membership_objects":
            var id: String = wanted_ids[cursor]; cursor += 1
            var group: Dictionary = native_groups.get(id,membership_base.groups.get(id,{}))
            if membership.full: membership.groups[id] = group; _collect_membership(group)
            elif native_groups.has(id):
                membership.group_updates[id] = group
                _collect_replacement(membership_base.groups[id],group)
            if native_groups.has(id):
                membership.new_groups.append(group)
                _queue_scenery(group.entries,true)
                membership.upserts.append_array(group.entries)
                membership.entries_changed = true
                membership.walls_changed = membership.walls_changed or group.row.kind in ["wall","cliff"]
        elif phase=="membership_ground":
            var key: String = ground_keys[ground_cursor]; ground_cursor += 1
            var group: Dictionary = native_ground.get(key,membership_base.ground.get(key,{}))
            var packet: Dictionary = result.packets.get(key,{})
            var representative: Dictionary = {}
            if packet.has("rows"):
                representative = packet.get("row_changes",{}).get(packet.rows[0].id,packet.rows[0])
            if native_ground.has(key):
                membership.new_groups.append(group)
                _queue_scenery(group.entries,true)
                membership.upserts.append_array(group.entries)
                membership.entries_changed = true
            elif not representative.is_empty():
                membership.ground_updates.append({"entry":group.entries[0],"packet":packet})
                membership.upserts.append(group.entries[0])
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
            var id: String = retired_ids[cursor]; cursor += 1
            if not result.wanted.has(id) or native_groups.has(id):
                var group: Dictionary = membership_base.groups[id]
                _collect_retired(group)
                membership.walls_changed = membership.walls_changed or group.row.kind in ["wall","cliff"]
        elif phase=="retire_ground":
            if ground_cursor==retired_ground_keys.size():
                membership.complete = true
                phase="scenery";scenery_cursor=0
                continue
            var key: String = retired_ground_keys[ground_cursor]; ground_cursor += 1
            if not result.ground.has(key): _collect_retired(membership_base.ground[key])
        elif phase=="scenery":
            _prepare_scenery_step()
        elif phase=="scenery_styles":
            _prepare_scenery_style()
        elif phase=="order_collect":
            if cursor==membership.entries.size():
                phase = "sort_wait"
                task = WorkerThreadPool.add_task(_sort_order,false,"Sort prepared world")
                continue
            var entry: Dictionary = membership.entry_replacements.get(cursor,membership.entries[cursor])
            var representative: Dictionary = membership.representatives.get(entry.node.get_instance_id(),{})
            _collect_order([entry],representative); cursor += 1
        elif phase=="order_publish":
            _prepare_order_record(sorted_indices[cursor]); cursor += 1
        elif phase=="order_release":
            if not order_records.is_empty(): order_records.pop_back()
            else:
                order_keys = []; order_ids = []; sorted_indices = []
                _finish_receivers()
        elif phase=="native_receivers":
            var receiver_budget:Dictionary={"used_usec":Time.get_ticks_usec()-started,"limit_usec":budget_usec}
            var receiver_started:int=Time.get_ticks_usec()
            var receiver_ready:bool=host.component_renderer.native_spells.prepare_boundary(self,boundary_jobs,native_receiver_boundary,receiver_budget)
            FrameProfile.end_phase(profile,"world_prepare_native_receivers",receiver_started)
            if receiver_ready:phase="sampling"
            else:break
        elif phase=="sampling":
            if binding_cursor<actor_bindings.size():
                var binding:Dictionary=actor_bindings[binding_cursor]
                var value:Dictionary=binding.get("prepared",{})
                if value.is_empty():value=ActorConstruction.realize_binding(host,binding.value)
                if value.is_empty():break
                binding.prepared=value
                var optical:Dictionary=host.component_renderer.native_spells.prepare_actor_binding(value.path,binding.entry.actor_layer.slot,host)
                if not optical.ready:break
                binding.optical=optical
                binding.prepared=value;binding_cursor+=1
                continue
            if host.component_renderer.blood.prepare_world(host,self,result.get("blood_rows",{}),blood_preparation,_preparation_allowance(started,budget_usec)):
                prepared=true;phase="ready"
            else:break
    if timed:phase_usec["phase:"+timed_phase]=phase_usec.get("phase:"+timed_phase,0)+Time.get_ticks_usec()-timed_from
    FrameProfile.end_phase(profile,"world_prepare_native",started)

func _prepare_construction_turn(deadline:int)->bool:
    # These are the existing five finite lanes, not additional task queues.
    # One success advances the turn so ready actor work cannot monopolize rows
    # whose independent environment resources already completed.
    for unused in 5:
        if Time.get_ticks_usec()>=deadline:return false
        var turn:int=construction_turn
        construction_turn=(construction_turn+1)%5
        match turn:
            0:
                if cookie_source_cursor<result.light_resolution.sources.size():
                    _prepare_cookie_resource();return true
            1:
                if not light_preparation.complete:
                    host.source_lighting.prepare_step(light_preparation);return true
            2:
                if _prepare_actor(deadline):return true
            3:
                if _prepare_object(deadline):return true
            4:
                if _prepare_ground(deadline):return true
        if not media_issue.is_empty():return false
    return false

func _prepare_environment_resources(deadline:int)->void:
    # One finite producer owns all selected rows. Submit the resident rows now:
    # an unrelated missing PNG must not hold their private resources or Nodes.
    # Each task writes a fresh result; only its joined result enters this owner.
    if environment_task>=0:return
    var began:int=Time.get_ticks_usec()
    var packets:Dictionary={};var textures:Dictionary={}
    var checked:int=0
    while checked<environment_ids.size() and Time.get_ticks_usec()<deadline:
        var id:String=environment_ids[environment_scan_cursor]
        environment_scan_cursor=(environment_scan_cursor+1)%environment_ids.size();checked+=1
        if environment_inputs.has(id):continue
        var row:Dictionary=result.wanted[id]
        var old:Dictionary=membership_base.groups.get(id,{})
        if native_groups.has(id) or (not old.is_empty() and old.row==row):
            environment_inputs[id]={}
            environment_capture_cursor+=1;continue
        if not _sources_ready(result.object_sources[id],id):continue
        var packet:Dictionary=result.environment_packets[id]
        environment_inputs[id]=packet
        packets[id]=packet
        for path in packet.paths:
            textures[path]=host.textures[path]
        environment_capture_cursor+=1
    environment_capture_complete=environment_capture_cursor==environment_ids.size()
    if not packets.is_empty():
        var declared:Dictionary=environment_parameter_names()
        environment_batch_output={}
        # This Godot dummy backend's material RID owner is not thread-safe.
        # Keep the same private constructor/adoption path on its scene thread.
        if DisplayServer.get_name()=="headless" and RenderingServer.get_rendering_device()==null:
            EnvironmentResources.build_private(packets,textures,declared,environment_batch_output)
            _poll_environment_resources()
        else:
            environment_task=WorkerThreadPool.add_task(EnvironmentResources.build_private.bind(packets,textures,declared,environment_batch_output),false,"Prepare resident environment resources")
    if host.profile.get("recording",false):phase_usec.environment_resource_capture=phase_usec.get("environment_resource_capture",0)+Time.get_ticks_usec()-began

func _poll_environment_resources()->void:
    if environment_task>=0:
        if not WorkerThreadPool.is_task_completed(environment_task):return
        WorkerThreadPool.wait_for_task_completion(environment_task);environment_task=-1
    elif environment_batch_output.is_empty():return
    if not environment_batch_output.get("complete",false) or not str(environment_batch_output.get("error","")).is_empty():
        media_issue=str(environment_batch_output.get("error","Private environment resources did not complete"));phase="failed"
        if media_issue not in presentation_errors:presentation_errors.append(media_issue)
        return
    if environment_output.is_empty():environment_output={"rows":{},"worker_ms":0.0,"batches":0}
    environment_output.rows.merge(environment_batch_output.rows)
    var elapsed:float=environment_batch_output.get("worker_ms",0.0)
    environment_output.worker_ms+=elapsed;environment_output.batches+=1
    environment_batch_output={}
    result.worker_ms+=elapsed
    result.worker_phases.environment_resources=float(result.worker_phases.get("environment_resources",0.0))+elapsed

func _advance_completed_phase()->bool:
    # Finishing an empty/already-completed lane does not need another frame's
    # construction allowance. Actual nodes, bindings, uploads and worker starts
    # remain below the elapsed guard in step(). The caller charges all elapsed
    # handoff work even when the shared allowance was already spent.
    match phase:
        "construction":
            if cookie_source_cursor!=result.light_resolution.sources.size() or not light_preparation.complete \
                or actor_cursor!=actor_ids.size() \
                or objects_complete.size()!=(object_target_count if object_target_count>=0 else wanted_ids.size()) \
                or ground_complete.size()!=(ground_target_count if ground_target_count>=0 else ground_keys.size()):return false
            blocked_actor={}
            phase="membership_begin"
        "membership_objects":
            if cursor!=wanted_ids.size():return false
            phase="membership_ground";ground_cursor=0
        "membership_ground":
            if ground_cursor!=ground_keys.size():return false
            phase="retire_objects";cursor=0
        "retire_objects":
            if cursor!=retired_ids.size():return false
            phase="retire_ground";ground_cursor=0
        "order_publish":
            if cursor!=sorted_indices.size():return false
            phase="order_release"
        "scenery":
            if scenery_cursor!=scenery_jobs.size():return false
            scenery_style_ids=result.get("visibility_changes",{}).keys();scenery_style_cursor=0
            for update in membership.ground_updates:scenery_packet_entries[update.entry.node.get_instance_id()]=update.packet
            phase="scenery_styles"
        "scenery_styles":
            if scenery_style_cursor!=scenery_style_ids.size():return false
            if not result.needs_order:_finish_receivers()
            elif not membership.full:phase="order_collect";cursor=0
            else:
                phase="sort_wait"
                task=WorkerThreadPool.add_task(_sort_order,false,"Sort prepared world")
        _:return false
    return true

# A light's cookie is generated off the main thread (with its image kept for
# CPU consumers); its source advances once the cookie exists.
func _prepare_cookie_resource() -> void:
    var source:Dictionary=result.light_resolution.sources[cookie_source_cursor]
    host.source_lighting.prepare_cookie(source)
    if not host.source_lighting.cookie_pending(source):cookie_source_cursor+=1

func _finish_preparation() -> void:
    phase="native_receivers"

func _prepare_actor(deadline:int=9223372036854775807)->bool:
    # Native entries remain in canonical layer order. A missing source defers
    # that entry's binding, not the graph/layers of another ready actor.
    if actor_cursor==actor_ids.size():return false
    # A pass that found every actor waiting (worker result or texture) is not
    # repeated in the same frame: those inputs arrive between frames.
    if actor_blocked_frame==Engine.get_process_frames():return false
    var checked:int=0
    while checked<actor_ids.size() and Time.get_ticks_usec()<deadline:
        var id:String=actor_ids[actor_scan_cursor]
        actor_scan_cursor=(actor_scan_cursor+1)%actor_ids.size();checked+=1
        var actor:Dictionary=result.actors[id]
        if actor.get("complete",false):continue
        var began:int=Time.get_ticks_usec()
        var progress:bool=_prepare_actor_step(actor,deadline)
        phase_usec.actors=phase_usec.get("actors",0)+Time.get_ticks_usec()-began
        if progress:return true
    if checked>=actor_ids.size():actor_blocked_frame=Engine.get_process_frames()
    return false

func _prepare_actor_resources()->void:
    if actor_resources_started:return
    actor_resources_started=true
    var measured:bool=host.profile.get("recording",false)
    var started:int=Time.get_ticks_usec() if measured else 0
    var noise_resources:Dictionary={};var cycle:Array=host.rig_config.FACING_CYCLE
    for id in result.actors:
        var actor:Dictionary=result.actors[id];var layers:Dictionary={}
        var facing:String=actor.source_sample.get("world_facing","SW" if host.external_playback else actor.row.facing)
        facing=cycle[posmod(cycle.find(facing)+quarter*2,8)]
        for index in actor.layers.size():
            var layer:Dictionary=actor.layers[index]
            if actor.retained_slots.has(layer.slot):continue
            var clip:String=actor.get("layer_clips",{}).get(layer.get("effect",{}).get("component_id",""),actor.source_sample.get("clip",""))
            var binding:Dictionary=actor.source_bindings.get(layer.slot,{})
            if binding.is_empty() or not actor.rig.clips.has(clip):
                media_issue="Prepared actor has no selected source for "+str(id)+" / "+layer.slot+" / "+clip;phase="failed";return
            var clip_time:float=Tracks.sample_seconds(float(actor.source_sample.get("source_seconds",0.0)),maxf(float(actor.rig.clips[clip].frames)/float(actor.rig.clips[clip].fps),.001),Tracks.character_loops(actor.rig,clip))
            var frame:int=clampi(int(clip_time*actor.rig.clips[clip].fps),0,int(actor.rig.clips[clip].frames)-1)
            layers[index]={"layer":layer,"binding":binding,"frame":frame}
            actor_resource_textures[binding.path]=host.textures.get(binding.path)
            for path in binding.geometry.textures.values():actor_resource_textures[path]=host.textures.get(path)
            var palette:Dictionary=layer.get("effect",{}).get("palette",{}) if layer.get("effect",{}).get("palette")!=null else {}
            var noise:Variant=palette.get("noiseSheet")
            if noise!=null and host.resources.has(noise):
                var path:String=host.resources[noise];noise_resources[noise]=path;actor_resource_textures[path]=host.textures.get(path)
        if not layers.is_empty():
            actor_resource_inputs[id]={"row":actor.row,"rig":actor.rig,"layers":layers,"facing":facing,"quarter":quarter,
                "scale":128.0/host.rig_config.TILE_W*actor.row.scale,"light_parameters":{"authored_base_light":0.0}}
    if actor_resource_inputs.is_empty():actor_resource_output={"complete":true,"error":"","rows":{},"worker_ms":0.0}
    else:
        actor_resource_names=ActorConstruction.source_parameter_names()
        # The headless dummy renderer cannot allocate materials concurrently.
        # Native GPU views retain the ordinary finite resource worker.
        if DisplayServer.get_name()=="headless" and RenderingServer.get_rendering_device()==null:
            ActorResources.build_private(actor_resource_inputs,actor_resource_textures,noise_resources,actor_resource_names,actor_resource_output)
            _complete_actor_resources()
        else:
            actor_resource_task=WorkerThreadPool.add_task(ActorResources.build_private.bind(actor_resource_inputs,actor_resource_textures,noise_resources,actor_resource_names,actor_resource_output),false,"Prepare private actor resources")
    _record_actor_phase("actor_resource_capture",started)

func _poll_actor_resources()->bool:
    if actor_resource_task>=0:
        if not WorkerThreadPool.is_task_completed(actor_resource_task):return false
        WorkerThreadPool.wait_for_task_completion(actor_resource_task);actor_resource_task=-1
        if not _complete_actor_resources():return false
    return actor_resource_output.get("complete",false)

func _complete_actor_resources()->bool:
    if not actor_resource_output.get("complete",false) or not str(actor_resource_output.get("error","")).is_empty():
        media_issue=str(actor_resource_output.get("error","Private actor resources did not complete"));phase="failed"
        if media_issue not in presentation_errors:presentation_errors.append(media_issue)
        return false
    var elapsed:float=actor_resource_output.get("worker_ms",0.0)
    result.worker_ms+=elapsed;result.worker_phases.actor_resources=elapsed
    return true

func _adopt_actor_resource(prepared:Dictionary,index:int)->Dictionary:
    if not _poll_actor_resources():return {}
    var packet:Dictionary=actor_resource_output.rows.get(prepared.row.id,{}).get(index,{})
    if packet.is_empty():
        media_issue="Private actor resources have no selected layer: "+str(prepared.row.id)+" / "+str(index);phase="failed";return {}
    var path:String=packet.entry.texture_path
    if not host.source_images.has(path):blocked_actor={"actor":prepared.row.id,"path":path,"status":"missing_colour_image"};return {}
    var measured:bool=host.profile.get("recording",false)
    var complete_started:int=Time.get_ticks_usec() if measured else 0
    if not ActorConstruction.complete_private_layer(packet,host.textures):
        blocked_actor={"actor":prepared.row.id,"path":path,"status":"missing_binding_texture"};return {}
    _record_actor_phase("actor_layer_complete",complete_started)
    var adopt_started:int=Time.get_ticks_usec() if measured else 0
    var entry:Dictionary=ActorConstruction.adopt_private_layer(self,packet)
    _record_actor_phase("actor_layer_attach",adopt_started)
    entry.private_resource_bound=true
    prepared.condition_parameters=packet.condition_parameters
    return entry

func _prepare_actor_step(prepared:Dictionary,deadline:int)->bool:
    var measured:bool=host.profile.get("recording",false)
    _prepare_actor_resources()
    if not media_issue.is_empty():return false
    if prepared.playback==null:
        var graph_started:int=Time.get_ticks_usec() if measured else 0
        prepared.source_ready={};prepared.source_cursor=0
        if prepared.reuse_actor:
            var base:Dictionary=actor_bases[prepared.row.id]
            prepared.actor_base=base.actor;prepared.playback=base.playback
            prepared.retained_entries={}
            for entry in base.actor.entries:
                if prepared.retained_slots.has(entry.actor_layer.slot):prepared.retained_entries[entry.actor_layer.slot]=entry
        else:prepared.playback=ActorConstruction.graph(self,prepared.rig,host.animation_templates)
        _record_actor_phase("actor_reuse" if prepared.reuse_actor else "actor_graph",graph_started)
        var condition_started:int=Time.get_ticks_usec() if measured else 0
        var neutral:Dictionary=ActorConstruction.Conditions.material(prepared.row.id,[])
        prepared.condition_parameters=ActorConstruction.Conditions.parameters(neutral,host.textures,host.resources)
        prepared.condition_parameters.make_read_only()
        _record_actor_phase("actor_conditions",condition_started)
        native_actors[prepared.row.id]=prepared
        return true
    var index:int=prepared.entries.size()
    if index<prepared.layers.size():
        var layer:Dictionary=prepared.layers[index]
        var entry:Dictionary=prepared.get("retained_entries",{}).get(layer.slot,{})
        var owned:bool=entry.is_empty()
        if owned:
            var layer_started:int=Time.get_ticks_usec() if measured else 0
            entry=_adopt_actor_resource(prepared,index)
            # Blocked attempts wait for the resource worker or a texture.
            _record_actor_phase("actor_layer" if not entry.is_empty() else "actor_layer_blocked",layer_started)
            if entry.is_empty():return false
            prepared.new_entries.append(entry);created_count+=1
        prepared.entries.append(entry)
        if _prepare_actor_source(prepared,entry,owned):prepared.source_ready[index]=true
        return true
    var checked:int=0
    while checked<prepared.entries.size() and Time.get_ticks_usec()<deadline:
        index=prepared.source_cursor
        prepared.source_cursor=(index+1)%prepared.entries.size();checked+=1
        if prepared.source_ready.has(index):continue
        var entry:Dictionary=prepared.entries[index]
        var owned:bool=not is_same(prepared.get("retained_entries",{}).get(entry.actor_layer.slot),entry)
        if _prepare_actor_source(prepared,entry,owned):
            prepared.source_ready[index]=true
            return true
    if prepared.source_ready.size()!=prepared.entries.size():return false
    # All selected source operands are resident. Shadow snapshots may now copy
    # real bound geometry; retained live materials have never been mutated.
    if Time.get_ticks_usec()>=deadline:return false
    var shadow_started:int=Time.get_ticks_usec() if measured else 0
    var shadow_ready:bool=host.generated_shadows.prepare_actor_step(self,prepared)
    _record_actor_phase("actor_shadow",shadow_started)
    if shadow_ready:
        prepared.complete=true;actor_cursor+=1
        prepared.outfit_clip=prepared.source_sample.get("clip","")
        prepared.outfit_profile=host.character_light_profile
    return true

func _record_actor_phase(name:String,started:int)->void:
    if started>0:phase_usec[name]=phase_usec.get(name,0)+Time.get_ticks_usec()-started

func _sources_ready(sources:Dictionary,id:String)->bool:
    for path in sources.get("paths",{}):
        if not host.textures.has(path):
            blocked_source={"id":id,"path":path,"status":"missing_texture"};return false
        if not host.source_images.has(path):
            blocked_source={"id":id,"path":path,"status":"missing_environment_image"};return false
    for path in sources.get("fixtures",{}):
        if not host.source_images.has(path) or not host.fixture_frame_energy.has(path) or not host.fixture_frame_centroids.has(path):
            blocked_source={"id":id,"path":path,"status":"missing_fixture_facts"};return false
    return true

func _prepare_object(deadline:int)->bool:
    if objects_complete.size()==(object_target_count if object_target_count>=0 else wanted_ids.size()):return false
    var measured:bool=bool(host.profile.get("recording",false))
    var started:int=Time.get_ticks_usec() if measured else 0
    var nested_before:int=phase_usec.get("objects",0)+phase_usec.get("object_sources",0)+phase_usec.get("object_source_priming",0) if measured else 0
    if measured:object_work_counts.attempts+=1
    var progress:bool=_prepare_object_step(deadline,measured)
    if measured:
        var elapsed:int=Time.get_ticks_usec()-started
        var nested_after:int=phase_usec.get("objects",0)+phase_usec.get("object_sources",0)+phase_usec.get("object_source_priming",0)
        phase_usec.object_dispatch=phase_usec.get("object_dispatch",0)+elapsed
        phase_usec.object_scan=phase_usec.get("object_scan",0)+maxi(0,elapsed-(nested_after-nested_before))
    return progress

func _prepare_object_step(deadline:int,measured:bool)->bool:
    if object_blocked_frame==Engine.get_process_frames():return false
    # Ready rows are adopted in one pass up to the deadline; a scene-owned
    # flame or ordinary constructor still ends the turn after one row.
    var progress:bool=false
    var checked:int=0
    while checked<wanted_ids.size() and Time.get_ticks_usec()<deadline:
        var id:String=wanted_ids[object_cursor]
        object_cursor=(object_cursor+1)%wanted_ids.size();checked+=1
        if measured:object_work_counts.visited+=1
        if objects_complete.has(id):
            if measured:object_work_counts.completed_skips+=1
            continue
        var row:Dictionary=result.wanted[id]
        var old:Dictionary=membership_base.groups.get(id,{})
        if not old.is_empty() and old.row==row:
            objects_complete[id]=true
            if measured:object_work_counts.retained+=1
            progress=true;continue
        if native_groups.has(id):
            var group:Dictionary=native_groups[id]
            if group.source_cursor<group.entries.size():
                var priming_started:int=Time.get_ticks_usec() if measured else 0
                if _prepare_private_source(group.entries[group.source_cursor]):
                    group.source_cursor+=1
                    if measured:object_work_counts.primed+=1
                if measured:phase_usec.object_source_priming=phase_usec.get("object_source_priming",0)+Time.get_ticks_usec()-priming_started
                return true
            objects_complete[id]=true;return true
        var from_worker:bool=result.get("environment_packets",{}).has(id)
        if from_worker:
            # The resource producer admits the complete source closure and
            # retains its strong handles. Await its result, not another full
            # per-row source validation while that same producer is pending.
            if not environment_output.get("rows",{}).has(id):
                if environment_capture_complete and environment_task<0:
                    media_issue="Private environment resource task missed its captured row: "+id;phase="failed";return false
                continue
            # The scene-owned flame needs its frames and optical facts.
            if row.has("lit_animation") and not _sources_ready(result.object_sources.get(id,{}),id):
                if measured:object_work_counts.source_waits+=1
                continue
        else:
            var source_started:int=Time.get_ticks_usec() if measured else 0
            var sources_ready:bool=_sources_ready(result.object_sources.get(id,{}),id)
            if measured:phase_usec.object_sources=phase_usec.get("object_sources",0)+Time.get_ticks_usec()-source_started
            if not sources_ready:
                if measured:object_work_counts.source_waits+=1
                continue
        var began:int=Time.get_ticks_usec()
        var first:int=static_entries.size()
        if from_worker:
            var adopt_started:int=Time.get_ticks_usec() if measured else 0
            adopt_environment_row(row,environment_output.rows[id])
            if measured:phase_usec.object_worker_nodes=phase_usec.get("object_worker_nodes",0)+Time.get_ticks_usec()-adopt_started
            if not initial:
                for entry in static_entries.slice(first):
                    if not entry.has("cell"):continue
                    var visibility_started:int=Time.get_ticks_usec() if measured else 0
                    var visibility:float=1.0 if candidate_visible(str(entry.placement.id)) else 0.0
                    SourceMaterial.set_parameter(entry,"current_visibility",visibility);entry.scenery_value=visibility
                    if measured:phase_usec.object_worker_visibility=phase_usec.get("object_worker_visibility",0)+Time.get_ticks_usec()-visibility_started
        else:
            var fallback_started:int=Time.get_ticks_usec() if measured else 0
            _environment_row(row.duplicate(true))
            if measured:phase_usec.object_ordinary_constructor=phase_usec.get("object_ordinary_constructor",0)+Time.get_ticks_usec()-fallback_started
        var flame_index:int=-1
        if from_worker and row.has("lit_animation"):
            flame_index=static_entries.size()-first
            _add_fixture_flame(row)
        if not media_issue.is_empty():return false
        var built:Array=static_entries.slice(first)
        # Worker entries arrive bound; only a scene-owned flame is primed here.
        native_groups[id]={"row":row,"entries":built,"source_cursor":(flame_index if flame_index>=0 else built.size()) if from_worker else 0}
        created_count+=static_entries.size()-first
        if measured:object_work_counts.constructed+=1
        phase_usec.objects=phase_usec.get("objects",0)+Time.get_ticks_usec()-began
        if not from_worker or flame_index>=0:return true
        objects_complete[id]=true;progress=true
    # Every remaining object waits for the resource worker or a source.
    if not progress and checked>=wanted_ids.size():object_blocked_frame=Engine.get_process_frames()
    return progress

func _prepare_ground(deadline:int)->bool:
    if ground_job.is_empty() and ground_complete.size()==(ground_target_count if ground_target_count>=0 else ground_keys.size()):return false
    var checked:int=0
    while checked<ground_keys.size() and Time.get_ticks_usec()<deadline:
        var key:String=ground_keys[ground_cursor]
        if ground_job.is_empty():
            ground_cursor=(ground_cursor+1)%ground_keys.size();checked+=1
            if ground_complete.has(key):continue
            if membership_base.ground.has(key):ground_complete[key]=true;return true
            if not _sources_ready(result.ground_sources.get(key,{}),key):continue
            var packet:Dictionary=result.packets[key]
            var began:int=Time.get_ticks_usec()
            ground_job=_ground_begin(packet.new_rows,packet.new_packets,packet.get("source_ranks",{}))
            ground_job.key=key;ground_job.values=[]
            phase_usec.ground=phase_usec.get("ground",0)+Time.get_ticks_usec()-began
            return true
        var began:int=Time.get_ticks_usec()
        key=ground_job.key
        var first:int=ground_job.index
        var done:bool=_ground_fill(ground_job)
        for i in range(first,ground_job.index):
            var row_id:String=ground_job.rows[i].id
            var value:float=1.0 if candidate_visible(row_id) else 0.0
            ground_job.values.append(value)
            ground_job.packets[row_id].data[16]=value;ground_job.buffer[i*20+16]=value
        if done:
            _ground_finish(ground_job)
            ground_job.entry.scenery_values=ground_job.values
            native_ground[key]={"rows":result.ground[key],"entries":[ground_job.entry]}
            # This private floor owns its final visibility/buffer. Its source
            # setup is picked up below without another packed-floor rebuild.
            ground_complete[key]=true;ground_job={}
        phase_usec.ground=phase_usec.get("ground",0)+Time.get_ticks_usec()-began
        return true
    return false

# A private entry starts with its candidate visibility; sprites light themselves.
func _prepare_private_source(entry:Dictionary)->bool:
    if entry.has("cell") and not initial:
        var shown:float=1.0 if entry.placement.kind=="actor" or candidate_visible(str(entry.placement.id)) else 0.0
        SourceMaterial.set_parameter(entry,"current_visibility",shown);entry.scenery_value=shown
    return true

func _prepare_actor_source(prepared:Dictionary,entry:Dictionary,private:bool=true)->bool:
    var started:int=Time.get_ticks_usec() if host.profile.get("recording",false) else 0
    var ready:bool=_prepare_actor_source_step(prepared,entry,private,started>0)
    _record_actor_phase("actor_source",started)
    return ready

func _prepare_actor_source_step(prepared:Dictionary,entry:Dictionary,private:bool,measured:bool)->bool:
    if private and entry.get("private_resource_bound",false):
        var optical_started:int=Time.get_ticks_usec() if measured else 0
        var value:Dictionary=entry.prepared_source_binding
        var optical:Dictionary=host.component_renderer.native_spells.prepare_actor_binding(value.path,entry.actor_layer.slot,host)
        _record_actor_phase("actor_source_optical",optical_started)
        if not optical.ready:
            blocked_actor={"actor":prepared.row.id,"path":optical.get("mask_path",value.path),"status":"missing_optical_mask"};return false
        actor_bindings.append({"entry":entry,"value":prepared.source_bindings[entry.actor_layer.slot],"prepared":value,"actor":prepared.row.id,"private":true,"optical":optical})
        return true
    var readiness_started:int=Time.get_ticks_usec() if measured else 0
    var selected:Dictionary=prepared.get("source_sample",{})
    var layer:Dictionary=entry.actor_layer
    var clip:String=prepared.get("layer_clips",{}).get(layer.get("effect",{}).get("component_id",""),selected.get("clip",""))
    var admission:Dictionary={"status":"no_selected_clip","clip":clip}
    blocked_actor={"actor":prepared.row.id,"slot":layer.slot,"clip":clip,"status":"checking"}
    if not layer.paths.has(clip) or not prepared.rig.clips.has(clip):
        _record_actor_phase("actor_source_readiness",readiness_started)
        media_issue="Prepared actor has no authored source for "+str(prepared.row.id)+" / "+layer.slot+" / "+clip
        phase="failed"
        return false
    var path:String=layer.paths[clip]
    # This only initializes hidden material resources. It never requests media
    # or samples a graph; the displayed actor still chooses its current pose.
    admission.path=path
    if not host.textures.has(path):
        _record_actor_phase("actor_source_readiness",readiness_started)
        admission.status="missing_colour_texture";blocked_actor.merge({"status":admission.status,"path":path});return false
    if not host.source_images.has(path):
        _record_actor_phase("actor_source_readiness",readiness_started)
        admission.status="missing_colour_image";blocked_actor.merge({"status":admission.status,"path":path});return false
    for companion in ActorConstruction.CharacterGeometry.paths(path,layer.slot,host.catalog_cache,host.character_light_profile):
        if not host.textures.has(companion):
            _record_actor_phase("actor_source_readiness",readiness_started)
            admission.status="missing_companion";admission.missing_path=companion
            blocked_actor.merge({"status":admission.status,"path":companion});return false
    _record_actor_phase("actor_source_readiness",readiness_started)
    var source_binding:Dictionary=prepared.get("source_bindings",{}).get(layer.slot,{})
    if private and not source_binding.is_empty():
        var optical_started:int=Time.get_ticks_usec() if measured else 0
        var optical:Dictionary=host.component_renderer.native_spells.prepare_actor_binding(path,layer.slot,host)
        _record_actor_phase("actor_source_optical",optical_started)
        if not optical.ready:blocked_actor.merge({"status":"missing_optical_mask","path":optical.get("mask_path",path)});return false
        var realize_started:int=Time.get_ticks_usec() if measured else 0
        var ready_binding:Dictionary=ActorConstruction.realize_binding(host,source_binding)
        _record_actor_phase("actor_source_realize",realize_started)
        if ready_binding.is_empty():blocked_actor.status="missing_binding_texture";return false
        entry.prepared_source_binding=ready_binding
        actor_bindings.append({"entry":entry,"value":source_binding,"prepared":ready_binding,"actor":prepared.row.id,"private":true,"optical":optical})
    # Retained sources already own their native receiving materials and shape.
    # Their exact next sheet/geometry resources are resident; normal displayed
    # sampling updates those operands without constructing another receiver.
    if not private:
        if not source_binding.is_empty():actor_bindings.append({"entry":entry,"value":source_binding,"actor":prepared.row.id,"owner":prepared.actor_base})
        return true
    var facing:String=selected.get("world_facing","SW" if host.external_playback else prepared.row.facing)
    var cycle:Array=host.rig_config.FACING_CYCLE
    facing=cycle[posmod(cycle.find(facing)+quarter*2,8)]
    # A valid source frame is enough to prepare all non-frame bindings. The
    # actual first sample either certifies the adjacent UV change or fully binds.
    var clip_time:float=Tracks.sample_seconds(float(selected.get("source_seconds",0.0)),maxf(float(prepared.rig.clips[clip].frames)/float(prepared.rig.clips[clip].fps),.001),Tracks.character_loops(prepared.rig,clip))
    var frame:int=clampi(int(clip_time*prepared.rig.clips[clip].fps),0,int(prepared.rig.clips[clip].frames)-1)
    var binding_started:int=Time.get_ticks_usec() if measured else 0
    ActorConstruction.bind_source(host,entry,prepared.rig,path,frame,facing,prepared.condition_parameters)
    _record_actor_phase("actor_source_bind",binding_started)
    admission.status="source_bound"
    return true

func _preparation_allowance(started:int,allowance:int)->Dictionary:
    return {"used_usec":Time.get_ticks_usec()-started,"limit_usec":allowance}

func publish_actor_bindings()->void:
    # Installing immutable operands changes no visible material. The exact
    # displayed frame/condition clock applies its small delta in bind_source.
    for binding in actor_bindings:
        binding.entry.prepared_source_binding=binding.prepared
        host.component_renderer.native_spells.publish_actor_binding(binding.get("optical",{}))
    if blood_renderer!=null:blood_renderer.publish_world(host,blood_preparation)

func source_only()->bool:
    return result.get("source_only",false)

func _refresh_actor_binding_owner()->void:
    if host==null:return
    var current:RefCounted=host.component_renderer.native_spells.actor_binding_owner()
    if is_same(current,optical_owner):return
    optical_owner=current;binding_cursor=0
    # Only the passive optical operands reopen. Retained source metadata,
    # hidden actors, world geometry and prepared native fields stay owned.
    if prepared:prepared=false;phase="sampling"

func take_actor(id:String,row:Dictionary,rig:Dictionary)->Dictionary:
    var prepared:Dictionary=native_actors.get(id,{})
    if prepared.is_empty() or epoch!=host.timeline.initialization_revision or quarter!=host.quarter \
        or not is_same(actor_catalog_owner,host.catalog_cache) or not is_same(prepared.rig,rig) \
        or not ActorConstruction.matches(row,prepared.row):return {}
    if not prepared.get("complete",false) or prepared.entries.size()!=prepared.layers.size() or prepared.playback==null:return {}
    native_actors.erase(id)
    return prepared

# Every new entry joins the spell receiver boundary; nothing else is prepared
# for lighting: sprites light themselves from the light table.
func _finish_receivers() -> void:
    boundary_jobs=membership.upserts.map(func(entry):return {"entry":entry})
    # New actor layers receive spells from their first displayed frame too.
    for actor in native_actors.values():
        for entry in actor.new_entries:boundary_jobs.append({"entry":entry})
    _finish_preparation()

func _capture_membership() -> void:
    # These collection owners are replaced at static admission, never updated by
    # actor sampling. Dynamic entries deliberately aren't part of this proof.
    membership_base = {"groups":host.world_groups,"ground":host.ground_groups,"entries":host.static_entries,
        "groups_size":host.world_groups.size(),"ground_size":host.ground_groups.size(),"entries_size":host.static_entries.size(),
        "generation":host.world_generation,"quarter":host.world_quarter,"revision":host.world_revision}

func can_publish_membership(target_revision: int = -1) -> bool:
    _refresh_actor_binding_owner()
    if not prepared or stale or not media_issue.is_empty() or not membership.get("complete",false):return false
    for binding in actor_bindings:
        if binding.get("private",false):continue
        if not is_same(host.visual_actors.get(binding.actor),binding.owner):return false
    for id in native_actors:
        var actor:Dictionary=native_actors[id]
        if actor.get("reuse_actor",false):
            if not is_same(host.visual_actors.get(id),actor.actor_base) or host.playbacks.get(id)!=actor.playback:return false
        if actor.has("shadow_base"):
            if not is_same(host.generated_shadows.actors.get(id),actor.shadow_base):return false
            for borrowed in actor.shadow_rekeys:
                if not is_instance_valid(borrowed.node) or actor.shadow_base.casters.get(borrowed.before)!=borrowed.node:return false
                if borrowed.node.mesh!=borrowed.mesh:return false
    if not source_only() and not host.source_lighting.preparation_valid(light_preparation):return false
    var expected:int=host.timeline.world_revision if target_revision<0 else target_revision
    return epoch==host.timeline.initialization_revision and quarter==host.quarter \
        and boundary.get("world_revision",-1)==expected \
        and membership_base.generation==host.world_generation and membership_base.quarter==host.world_quarter \
        and membership_base.revision==host.world_revision \
        and is_same(membership_base.groups,host.world_groups) and membership_base.groups_size==host.world_groups.size() \
        and is_same(membership_base.ground,host.ground_groups) and membership_base.ground_size==host.ground_groups.size() \
        and is_same(membership_base.entries,host.static_entries) and membership_base.entries_size==host.static_entries.size()


func _prepare_membership_inputs()->void:
    if membership_inputs_ready:return
    membership_inputs_ready=true
    var full:bool=result.get("full_membership",true)
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
    membership_full=full

func _begin_membership() -> void:
    _prepare_membership_inputs()
    var full:bool=membership_full
    membership = {"complete":false,"full":full,"groups":{} if full else membership_base.groups,
        "ground":{} if full else membership_base.ground,"entries":[] if full else membership_base.entries,
        "fixtures":[] if full else host.fixture_entries,"new_groups":[],"retired_groups":[],"ground_updates":[],
        "removed":{},"upserts":[],"entries_changed":false,"walls_changed":false,"group_updates":{},
        "ground_group_updates":{},"ground_row_updates":[],"entry_replacements":{},"fixture_replacements":{},
        "slot_updates":[],"order_replacements":[],"representatives":{}}
    membership.scenery={"add":{},"remove":{},"new_consumers":{},"entry_add":[],"entry_remove":[],"writes":[]}
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
            membership.entries_changed=true
        membership.order_replacements.append({"old":previous,"entry":entry,"placement":row,"id":id,"key":key})
        if not representative.is_empty(): membership.representatives[entry.node.get_instance_id()] = representative

func publish_native_receivers() -> void:
    host.component_renderer.native_spells.publish_boundary(native_receiver_boundary)

func publish_membership() -> void:
    publish_native_receivers()
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
    for entry in membership.scenery.entry_remove:
        if entry.placement.has("world_media_content"):host.world_media_entries.erase(entry)
    for entry in membership.scenery.entry_add:
        if entry.placement.has("world_media_content"):host.world_media_entries.append(entry)
    host.static_entries = membership.entries; host.fixture_entries = membership.fixtures
    host.world_groups = membership.groups; host.ground_groups = membership.ground

func _collect_retired(group: Dictionary) -> void:
    membership.retired_groups.append(group); membership.entries_changed = true
    _queue_scenery(group.entries,false)
    for entry in group.entries: membership.removed[entry.node.get_instance_id()] = true

func _queue_scenery(group:Array,add:bool)->void:
    for entry in group:
        scenery_jobs.append({"entry":entry,"add":add})

func _prepare_scenery_step()->void:
    var job:Dictionary=scenery_jobs[scenery_cursor]
    scenery_cursor+=1
    var entry:Dictionary=job.entry
    var delta:Dictionary=membership.scenery
    if job.add:delta.entry_add.append(entry)
    else:delta.entry_remove.append(entry)
    if entry.material.shader not in [ENVIRONMENT_SHADER,WATER_SHADER] or entry.has("batch_rows"):return
    if job.add and is_ancestor_of(entry.node):
        var value:float=1.0 if candidate_visible(str(entry.placement.id)) else 0.0
        SourceMaterial.set_parameter(entry,"current_visibility",value);entry.scenery_value=value
    _prepare_scenery_target(str(entry.placement.id),entry,-1,job.add)

func _prepare_scenery_target(id:String,entry:Dictionary,index:int,add:bool)->void:
    var delta:Dictionary=membership.scenery
    var values:Dictionary=delta.add if add else delta.remove
    if not values.has(id):values[id]=[] if add else {}
    if add:values[id].append({"entry":entry,"index":index})
    else:values[id][entry.node.get_instance_id()]=true
    # Prepared floor packets already contain this boundary's exact visibility.
    # Reindexing retained rows does not make each row a changed style operand.
    if add and index<0 and not is_ancestor_of(entry.node):delta.new_consumers[id]=true

func _prepare_scenery_style()->void:
    var id:String=scenery_style_ids[scenery_style_cursor];scenery_style_cursor+=1
    var value:float=1.0 if result.visibility_changes[id] else 0.0
    var ground_entry:Dictionary=host._scenery_ground_entry(id)
    if not ground_entry.is_empty():_prepare_scenery_write(id,ground_entry,ground_entry.ground_indices[id],value)
    for consumer in host.scenery_consumers.get(id,[]):
        var entry:Dictionary=consumer.entry
        var index:int=entry.ground_indices.get(id,-1) if consumer.index>=0 else -1
        if consumer.index>=0 and index<0:continue
        _prepare_scenery_write(id,entry,index,value)

func _prepare_scenery_write(id:String,entry:Dictionary,index:int,value:float)->void:
    var key:int=entry.node.get_instance_id()
    if membership.removed.has(key) or is_ancestor_of(entry.node):return
    if index>=0:
        var packet:Dictionary=scenery_packet_entries.get(key,{})
        # Full packets adopt every style. Sparse geometry publication preserves
        # live custom channels, so its changed rows still need the sight write.
        if not packet.is_empty() and not packet.get("sparse",false):return
        if entry.scenery_values[index]==value:return
    elif entry.get("scenery_value",-1.0)==value:return
    membership.scenery.writes.append({"entry":entry,"index":index,"id":id,"value":value})

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
    sort_worker_ms=(Time.get_ticks_usec()-started)/1000.0

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
    return (task<0 or WorkerThreadPool.is_task_completed(task)) and (environment_task<0 or WorkerThreadPool.is_task_completed(environment_task)) and (actor_resource_task<0 or WorkerThreadPool.is_task_completed(actor_resource_task))

func join() -> void:
    if task>=0: WorkerThreadPool.wait_for_task_completion(task); task = -1
    if environment_task>=0:WorkerThreadPool.wait_for_task_completion(environment_task);environment_task=-1
    if actor_resource_task>=0:WorkerThreadPool.wait_for_task_completion(actor_resource_task);actor_resource_task=-1

func release_handles() -> Array:
    if handles_released:return []
    join()
    handles_released=true
    var held = entries.duplicate()
    held.append_array(_unadopted_actor_layers())
    held.append_array(_unadopted_environment_entries())
    if blood_renderer!=null:held.append_array(blood_renderer.release_world(blood_preparation))
    blood_preparation={"handles":{},"retired":[]}
    for record in light_preparation.get("nodes",[]):held.append({"node":record.node,"retire_external":true})
    light_preparation={}
    for prepared in native_actors.values():
        held.append_array(prepared.get("new_entries",prepared.entries))
    # Transfer native cleanup handles now. Passive completed projection,
    # membership and support values stay on this already-retiring owner until
    # its budgeted free; eagerly clearing them here made publication pay their
    # large Dictionary/Array destruction cost.
    entries=[];native_receiver_boundary={}
    return held

func _unadopted_actor_layers()->Array:
    var result:Array=[]
    for packets in actor_resource_output.get("rows",{}).values():
        for packet in packets.values():
            if not is_instance_valid(packet.entry.node):continue
            var node:Node=packet.entry.node
            if node.get_parent()==null:
                result.append({"node":node,"retire_external":true})
    return result

func _unadopted_environment_entries()->Array:
    var result:Array=[];var seen:Dictionary={}
    for output in [environment_output,environment_batch_output]:
        for row in output.get("rows",{}).values():
            for entry in row:
                if not is_instance_valid(entry.node):continue
                var node:Node=entry.node
                if node.get_parent()==null and not seen.has(node.get_instance_id()):
                    seen[node.get_instance_id()]=true
                    result.append({"node":node,"retire_external":true})
    return result

func _exit_tree()->void:
    join()
    # Worker-built nodes remain outside the tree until adopted. Their private
    # owner must free them on cancellation/shutdown; refcounting cannot do it.
    for entry in _unadopted_actor_layers():entry.node.free()
    for entry in _unadopted_environment_entries():entry.node.free()
    actor_resource_output.clear()
    environment_output.clear();environment_batch_output.clear()
