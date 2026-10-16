extends "res://tests/prepared_admission_checks.gd"
# Native-data admission fixtures: explicit projected rows, not gameplay or an
# artwork oracle. Exercise hidden membership, actual MultiMesh publication and
# independent total ordering; recorded-source pixel acceptance is separate.
const WorldRows = preload("res://presentation/world.gd")
const GroundData = preload("res://presentation/ground_data.gd")
const Quarter = preload("res://presentation/quarter_view.gd")

func source(scene: Node, parent: Node, id: String, x: int, flame: bool = false) -> Dictionary:
    var value = entry(scene,id,x)
    value.node.reparent(parent,false)
    value.placement.kind = "resource"; value.role = "body"
    if flame: value.material.shader = scene.FIXTURE_FLAME_SHADER
    return value

func tile(id: String, x: int) -> Dictionary:
    return {"id":id,"kind":"terrain","position":[x,0],"base_height_steps":0,"material":"stone"}

func batch(scene: Node, rows: Array) -> Dictionary:
    var node = MultiMeshInstance3D.new(); scene.sprite_parent.add_child(node)
    var multi = MultiMesh.new(); multi.transform_format=MultiMesh.TRANSFORM_3D
    multi.use_colors=true; multi.use_custom_data=true; multi.instance_count=256; multi.mesh=QuadMesh.new(); node.multimesh=multi
    var material=ShaderMaterial.new(); material.shader=scene.ENVIRONMENT_SHADER; node.material_override=material
    var value={"id":"","placement":rows[0],"node":node,"material":material,"role":"terrain","layer":0,
        "cell":Vector2(128,128),"pivot":Vector2(64,64),"scale":1.0,"ground_receiver_bounds":multi.mesh.get_aabb()}
    var packet=GroundData.prepare(rows,{"receiver_bounds":value.ground_receiver_bounds,"capacity":256},0,Basis.IDENTITY,{})
    scene._ground_publish(value,packet)
    return value

func base_scene() -> Node:
    var scene=Probe.new(); root.add_child(scene)
    scene.sprite_parent=Quarter.new(); scene.add_child(scene.sprite_parent)
    scene.timeline.state={"tiles":{},"objects":{},"actors":{},"senses":{"visible":[],"objects":{}}}
    scene.timeline.initialization_revision=1; scene.timeline.world_revision=7
    scene.timeline.world_changes_consumed=7
    scene.timeline.world_changes={"full":false,"tiles":{},"objects":{},"senses":false,"revision":7}
    scene.world_revision=7; scene.world_generation=3; scene.world_quarter=0; scene.quarter=0
    scene.ground_is_background=true
    # Empty canonical fallback needs no art. Named projected entries below
    # deliberately test native ownership rather than authored source selection.
    scene.catalog_cache={"world.json":{"terrain":{},"props":{}},"environment/index.json":{"doors":{},"props":{},"traps":{}}}
    scene.world_row_cache={}
    WorldRows.apply_changes(scene.world_row_cache,WorldRows.prepare_changes(scene.timeline.state,scene.catalog_cache,scene.world_row_cache,{"full":true}))
    return scene

func prepare(scene: Node, wanted: Dictionary, ground: Dictionary, packets: Dictionary = {}) -> Node:
    var job=Preparation.new(); scene.add_child(job)
    job.host=scene; job.epoch=1; job.quarter=0; job.visible=false
    job.boundary={"world_revision":8}; job._capture_membership()
    job.light_preparation=scene.source_lighting.begin_preparation({"sources":[],"issues":[]})
    while not job.light_preparation.complete:scene.source_lighting.prepare_step(job.light_preparation)
    var rows: Array=[]
    rows.append_array(wanted.values())
    for values in ground.values(): rows.append_array(values)
    job.result={"complete":true,"wanted":wanted,"ground":ground,"packets":packets,
        "needs_order":true,"background":true,"worker_ms":0.0,"geometry":{},
        # Native rows above are deliberate constructor fixtures; canonical state
        # remains the actual empty SDK-shaped state projected by the real owner.
        "row_patch":WorldRows.prepare_changes(scene.timeline.state,scene.catalog_cache,{}, {"full":true}),
        "visibility":{},"visible_cells":{},"visibility_base":scene.scenery_visibility,"visibility_changes":{}}
    job.wanted_ids=wanted.keys(); job.ground_keys=ground.keys()
    return job

func finish_hidden(job: Node) -> void:
    job._begin_membership()
    var deadline=Time.get_ticks_msec()+5000
    while not job.prepared and Time.get_ticks_msec()<deadline:
        job.step(1000); await process_frame
    check(job.prepared and job.media_issue.is_empty(),"Bounded hidden membership and worker order finish")

func target_boundary(scene: Node) -> void:
    scene.timeline.world_revision=8
    scene.timeline.world_changes={"full":false,"tiles":{},"objects":{},"senses":false,"revision":8}

func run() -> void:
    var scene=base_scene()
    var keep=source(scene,scene.sprite_parent,"keep",1)
    var old=source(scene,scene.sprite_parent,"replace",2,true)
    var gone=source(scene,scene.sprite_parent,"removed",3)
    var floor=batch(scene,[tile("floor-first",-1),tile("floor-retained",2)])
    scene.world_groups={"keep":{"row":keep.placement,"entries":[keep]},"replace":{"row":old.placement,"entries":[old]},"removed":{"row":gone.placement,"entries":[gone]}}
    scene.ground_groups={"stone":{"rows":floor.batch_rows,"entries":[floor]}}
    scene.static_entries=[keep,old,gone,floor]; scene.fixture_entries=[old]
    # Dynamic actors can be interleaved in the historical combined list.
    var actor=source(scene,scene,"actor",4)
    scene.entries=[keep,actor,old,gone,floor]
    scene._scenery_add(scene.static_entries)
    var new_row=old.placement.duplicate(); new_row.position=[8,0]
    var added_row={"id":"added","kind":"resource","position":[9,0],"base_height_steps":0}
    var rows=[tile("floor-retained",2),tile("floor-new",3)]
    var packet=GroundData.prepare(rows,GroundData.capture_previous({"packets":floor.ground_packets,"receiver_bounds":floor.ground_receiver_bounds,
        "capacity":256,"ground_version":floor.ground_version},0,Basis.IDENTITY),0,Basis.IDENTITY,{"floor-new":true})
    var job=prepare(scene,{"keep":keep.placement,"replace":new_row,"added":added_row},{"stone":rows},{"stone":packet})
    var replacement=source(scene,job,"replace",8,true); replacement.placement=new_row
    var added=source(scene,job,"added",9); added.placement=added_row
    job.native_groups={"replace":{"row":new_row,"entries":[replacement]},"added":{"row":added_row,"entries":[added]}}
    job.entries=[replacement,added]; job.static_entries=job.entries
    var old_floor_group: Dictionary=scene.ground_groups.stone
    var old_floor_rows: Array=floor.batch_rows
    var old_static: Array=scene.static_entries
    var before: Dictionary=scene.timeline.state.duplicate(true)
    await finish_hidden(job)
    check(is_same(scene.static_entries,old_static) and scene.fixture_entries==[old],"Finished preparation leaves current membership and fixture selection untouched")
    check(floor.placement.id=="floor-first" and is_same(floor.batch_rows,old_floor_rows) and is_same(old_floor_group.rows,old_floor_rows),"Prepared floor does not publish its new representative or rows early")
    check(replacement.node.get_parent()==job and not replacement.node.is_visible_in_tree() and not old.node.is_queued_for_deletion(),"Replacement stays hidden while old native group remains owned and visible")
    target_boundary(scene)
    check(job.can_publish_membership(),"Matching admitted boundary accepts prepared ownership")
    # Independent invalidations reject even though the private target is ready.
    for field in ["epoch","quarter","generation","revision","serial","groups","ground","entries","count","target"]:
        var saved: Variant
        match field:
            "epoch": saved=scene.timeline.initialization_revision; scene.timeline.initialization_revision+=1
            "quarter": saved=scene.quarter; scene.quarter=1
            "generation": saved=scene.world_generation; scene.world_generation+=1
            "revision": saved=scene.world_revision; scene.world_revision+=1
            "serial": saved=scene.native_light_change_serial; scene.native_light_change_serial+=1
            "groups": saved=scene.world_groups; scene.world_groups=scene.world_groups.duplicate()
            "ground": saved=scene.ground_groups; scene.ground_groups=scene.ground_groups.duplicate()
            "entries": saved=scene.static_entries; scene.static_entries=scene.static_entries.duplicate()
            "count": scene.static_entries.append(actor)
            "target": saved=scene.timeline.world_revision; scene.timeline.world_revision+=1
        check(not job.can_publish_membership(),"Reject stale prepared "+field)
        match field:
            "epoch": scene.timeline.initialization_revision=saved
            "quarter": scene.quarter=saved
            "generation": scene.world_generation=saved
            "revision": scene.world_revision=saved
            "serial": scene.native_light_change_serial=saved
            "groups": scene.world_groups=saved
            "ground": scene.ground_groups=saved
            "entries": scene.static_entries=saved
            "count": scene.static_entries.pop_back()
            "target": scene.timeline.world_revision=saved
    # Actor addition while hidden must not invalidate static ownership or be lost.
    var later_actor=source(scene,scene,"later-actor",5); scene.entries.append(later_actor)
    check(job.can_publish_membership(),"Dynamic actor membership does not invalidate private static preparation")
    job.admitted=true; scene.pending_world=job
    scene._sync_world(); scene._sort_draws()
    check(scene.static_entries==[keep,replacement,added,floor],"Admission publishes complete canonical static membership exactly once")
    check(scene.entries==[keep,actor,floor,later_actor,replacement,added],"Admission preserves retained insertion order and both dynamic actors")
    check(is_same(scene.world_groups.keep.entries[0],keep) and scene.ground_groups.stone.entries[0].node==floor.node,"Unchanged group and updated floor retain native identities")
    check(scene.fixture_entries==[replacement] and scene.scenery_consumers.get("removed",[]).is_empty(),"Fixture selection and retired picking consumers change at the same boundary")
    check(old.node.is_queued_for_deletion() and gone.node.is_queued_for_deletion() and replacement.node.get_parent()==scene.sprite_parent,"Only retired groups are queued; replacements adopt displayed native ownership")
    check(floor.placement.id=="floor-retained" and floor.batch_rows==packet.rows and floor.node.multimesh.buffer==packet.buffer,"Admitted floor publishes original sorted representative and exact prepared native buffer")
    check(is_same(old_floor_group.rows,old_floor_rows),"Old floor group stays immutable after admission")
    check(floor.ground_version==2 and floor.geometry_changes.base_version==1 and floor.geometry_changes.changed==["floor-new"] and floor.geometry_changes.removed==["floor-first"],"Prepared floor retains exact geometry/version receipt")
    check(scene.native_light_changes.upserts==[replacement,added,floor] and scene.native_light_changes.removed.size()==2,"Lighting admission receives exactly new/replaced/updated native sources")
    assert_order(scene,"prepared membership")
    check(scene.timeline.state==before,"Native admission never mutates canonical state")
    await sparse_replacement_case(scene)
    # A prepared but stale target must be discarded before any of its entries
    # can appear. The actual canonical empty world drives exhaustive fallback.
    var stale=prepare(scene,{},{}); await finish_hidden(stale)
    stale.admitted=true; scene.pending_world=stale; stale.boundary.world_revision=9
    scene.timeline.world_revision=9
    scene.timeline.world_changes={"full":false,"tiles":{},"objects":{},"senses":false,"revision":9}
    scene.world_groups=scene.world_groups.duplicate()
    scene.world_row_cache={} # Full projection of the actual empty canonical fixture.
    scene._sync_world()
    check(scene.static_entries.is_empty() and scene.world_groups.is_empty() and scene.ground_groups.is_empty(),"Stale prepared owner uses exhaustive current canonical world")
    check(scene.entries==[actor,later_actor] and not actor.node.is_queued_for_deletion(),"Fallback removes static sources without losing dynamic actors")
    # Cancellation frees newly built children, never retained live entries.
    var cancel=prepare(scene,{},{}); var hidden=source(scene,cancel,"cancelled",7)
    cancel.entries=[hidden]; cancel.static_entries=cancel.entries
    var held=actor.node
    cancel.membership={"entries":[actor]}; cancel.release_handles(); cancel.free()
    check(is_instance_valid(held) and not held.is_queued_for_deletion() and not is_instance_valid(hidden.node),"Discarded private membership owns only its new native children")
    var report={"checks":checks,"failures":failures,"scope":"Headless native-data admission: hidden preparation, precise stale ownership guards, dynamic interleaving, retired/replaced fixture membership, retained floor packet/representative/version, independent original painter order and exhaustive canonical fallback. No source-pixel or performance claim."}
    FileAccess.open("res://generated/prepared_membership_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("PREPARED_MEMBERSHIP_CHECKS ",JSON.stringify(report))
    scene.queue_free(); await process_frame
    quit(0 if failures.is_empty() else 1)

func sparse_replacement_case(scene: Node) -> void:
    var previous: Dictionary=scene.world_groups["replace"].entries[0]
    var row: Dictionary=previous.placement.duplicate()
    row["source_revision"]=2
    var job=prepare(scene,{"replace":row},{})
    job.result.full_membership=false; job.result.needs_order=false
    job.boundary.world_revision=9
    var next=source(scene,job,"replace",8,true); next.placement=row
    job.native_groups={"replace":{"row":row,"entries":[next]}}
    job.entries=[next];job.static_entries=job.entries
    var held_entries: Array=scene.static_entries
    var held_fixtures: Array=scene.fixture_entries
    var held_order: Array=scene.static_complete_order
    var slot: int=previous.static_slot
    var order_slot: int=previous.order_slot
    await finish_hidden(job)
    check(not job.membership.full and job.membership.entry_replacements.size()==1 and not job.result.needs_order,"One same-order native source replacement prepares one slot without whole membership/order rebuild")
    check(scene.static_entries[slot]==previous and not previous.node.is_queued_for_deletion(),"Sparse native preparation leaves current borrowed slot unchanged")
    scene.timeline.world_revision=9
    scene.timeline.world_changes={"full":false,"tiles":{},"objects":{},"senses":false,"revision":9}
    job.admitted=true;scene.pending_world=job
    scene._sync_world();scene._sort_draws()
    check(is_same(scene.static_entries,held_entries) and is_same(scene.fixture_entries,held_fixtures) and is_same(scene.static_complete_order,held_order),"Sparse adoption retains static, fixture and sorted array owners")
    check(scene.static_entries[slot]==next and scene.static_complete_order[order_slot]==next and scene.world_groups["replace"].entries==[next],"Sparse membership and native order change at the same publication")
    check(previous.node.is_queued_for_deletion() and next.node.get_parent()==scene.sprite_parent,"Sparse replacement retires only the old source and adopts the prepared node")
    assert_order(scene,"sparse replacement")
