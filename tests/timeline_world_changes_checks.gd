extends SceneTree
# Real compiler commits through Timeline, checked against the exhaustive original
# map adapter. Named batching cases test the one displayed-world consumer boundary.
const Journal = preload("res://sdk/journal.gd")
const Reducer = preload("res://sdk/reducer.gd")
const Compiler = preload("res://presentation/compiler.gd")
const Timeline = preload("res://presentation/timeline.gd")
const World = preload("res://presentation/world.gd")
const Catalog = preload("res://source_catalog.gd")
const Probe = preload("res://tests/ground_visibility_checks.gd").Probe
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Cells=preload("res://sdk/fold_cells.gd")
var checks=0
var failures=[]
var cache={}
var retained={}
var supports={}
var revision=-1
var examined=0
var dirty_records=0
var complete_records=0
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("TIMELINE_WORLD_FAIL ",label)
func compare(timeline:RefCounted,label:String)->Dictionary:
    var changes=timeline.take_world_changes(revision)
    revision=timeline.world_revision
    var staged=timeline.staged_tiles()
    for key in staged:
        if not supports.has(key) or staged[key]!=supports[key]:changes.tiles[key]=true
    for key in supports:
        if not staged.has(key):changes.tiles[key]=true
    supports=staged
    var state=timeline.presentation_state()
    var actual=World.update_rows(state,cache,retained,changes)
    check(actual==World.rows(state,cache),label+" ordered rows and original corner assembly")
    var current=World.current_ids(state,retained.boundaries)
    var expected=World.visibility(state)
    check(current.keys().all(func(id):return expected.get(id,false)) and expected.keys().all(func(id):return current.has(id)==bool(expected[id])),label+" current subjective identities")
    check(retained.negative.is_empty()==World.ground_background(state,timeline.staged_actors()),label+" original below-floor eligibility")
    dirty_records+=retained.resolved;complete_records+=state.tiles.size()+state.objects.size();examined+=1
    return changes
func group(commits:Array,duration:float=20)->Dictionary:
    return {"id":"named-consumer-case","operation_sequence":103,"operation_end":true,"duration_ms":duration,
        "actor_tracks":[],"commits":commits,"staged_actors":{},"staged_tiles":{},"events":[]}
func _initialize()->void:run.call_deferred()
func run()->void:
    var directory:String=Fixtures.journal("gallery")
    var journal=Journal.new();var opened=journal.open(directory,true,false)
    check(opened.ok,"Authentic Gallery decoder selected")
    if not opened.ok:quit(1);return
    var timeline=Timeline.new();var count=0;var groups=0;var expected_groups=0
    var files=DirAccess.get_files_at(directory);files.sort()
    for file in files:
        if not file.ends_with(".json") or file.length()!=21:continue
        var name="InitializationResponse" if count==0 else "PlayerOperation"
        var decoded=journal.protocol.decode(name,FileAccess.get_file_as_bytes(directory.path_join(file)))
        check(decoded.ok,"Admitted "+file)
        if not decoded.ok:break
        var packet:Dictionary=journal.protocol.normalize(name,decoded.value)
        if count==0:
            var initial=Reducer.reduce_initialization(packet.initialization,packet.content_additions)
            check(initial.ok,"Real initial reducer")
            timeline.accept({"kind":"initialization","state":initial.value,"sequence":0})
            compare(timeline,"initial")
        else:
            # Each native lineage produces one group; a packet without one
            # still has its independent ordered operation tail.
            expected_groups+=maxi(1,packet.get("lineages",[]).size())
            var compiled=Compiler.compile(timeline.state,packet,cache)
            check(compiled.ok,"Real compiler "+str(count))
            if not compiled.ok:break
            for value in compiled.value.groups:
                var start:float=timeline.display_ms
                timeline.accept({"kind":"operation","groups":[value]})
                var points={0.0:true,float(value.duration_ms):true}
                for commit in value.commits:points[float(commit.at_ms)]=true
                for at in value.get("staged_tile_at_ms",{}).values():points[float(at)]=true
                var times=points.keys();times.sort()
                for at in times:
                    timeline.advance(maxf(0,start+at-timeline.display_ms))
                    compare(timeline,"op%d group%d at%s"%[count,groups,at])
                groups+=1
            check(timeline.state==compiled.value.final_state,"Exact SDK final state after op"+str(count))
        count+=1
    check(count==int(Fixtures.case_record("gallery").packets),"All admitted packets match independent Gallery recording metadata")
    check(groups==expected_groups,"All real native lineages and operation tails compile exactly once")
    # Identical final object value after remove/re-add still changes native order.
    var ids=timeline.state.objects.keys();var id:String=ids[0]
    var original:Dictionary=timeline.state.objects[id]
    var remove=Compiler.empty_delta();remove.objects_removed=[id]
    var readd=Compiler.empty_delta();readd.objects[id]=original
    timeline.accept({"kind":"operation","groups":[group([{"at_ms":5.0,"delta":remove},{"at_ms":10.0,"delta":readd}])]})
    var before_revision=timeline.world_revision
    timeline.media_ready=func(_value):return false
    timeline.advance(100)
    check(timeline.world_revision==before_revision and timeline.state.objects.has(id),"Media hold does not commit or lose pending occurrence")
    timeline.media_ready=Callable()
    timeline.advance(5);timeline.advance(5);timeline.advance(10)
    var changes=compare(timeline,"several advances remove and readd")
    check(not changes.full and changes.objects.has(id),"Union dirty ID retained until the single consumer")
    check(timeline.state.objects.keys().back()==id and retained.result.rows.back().id==id,"Remove/re-add preserves canonical last position and equal-Y input order")
    # Two changes in one advance are both retained, while subsequent consume is empty.
    var tile_keys=timeline.state.tiles.keys()
    var a=Compiler.empty_delta();var b=Compiler.empty_delta()
    a.tiles[tile_keys[0]]=timeline.state.tiles[tile_keys[0]].duplicate(true)
    b.tiles[tile_keys[1]]=timeline.state.tiles[tile_keys[1]].duplicate(true)
    timeline.accept({"kind":"operation","groups":[group([{"at_ms":0.0,"delta":a},{"at_ms":1.0,"delta":b}])]})
    timeline.advance(30);changes=compare(timeline,"two commits one advance")
    check(not changes.full and changes.tiles.has(tile_keys[0]) and changes.tiles.has(tile_keys[1]),"Both commit identities delivered once")
    var empty=timeline.take_world_changes(revision)
    check(not empty.full and empty.tiles.is_empty() and empty.objects.is_empty(),"Successful consume clears only delivered interval")
    # Reset is full even if a new scene uses the same numerical world revision.
    timeline.accept({"kind":"initialization","state":timeline.state.duplicate(true),"sequence":200})
    changes=compare(timeline,"initialization reset")
    check(changes.full,"Initialization invalidates retained source index")
    await scenery_case()
    var report={"checks":checks,"failures":failures,"packets":count,"groups":groups,"observed_boundaries":examined,
        "dirty_records_projected":dirty_records,"records_if_full_scanned":complete_records,
        "scope":"Complete original Gallery compiler/Timeline staging and commits versus exhaustive ordered adapter; media hold, multi-advance remove/readd, reset, and no-force same-visible-ID floor material transfer."}
    var out=FileAccess.open("res://generated/timeline_world_changes_checks.json",FileAccess.WRITE);out.store_string(JSON.stringify(report,"  "));out.close()
    print("TIMELINE_WORLD_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func scenery_case()->void:
    var scene=Probe.new();root.add_child(scene)
    var materials=Catalog.environment_world(cache).terrain.keys().filter(func(value):return value!="water")
    check(materials.size()>1,"Two actual authored floor materials available")
    var tiles={}
    for x in range(3):
        tiles["%d,0"%x]={"tile_uuid":"floor-%d"%x,"position":[x,0],"elevation_steps":0,"surface":{"base_material":materials[0] if x<2 else materials[1]}}
    var state={"tiles":tiles,"objects":{},"actors":{},"audience":{"controlled":[]},"senses":{"visible":Cells.mask([[0,0],[1,0],[2,0]]),"objects":{}}}
    scene.timeline.accept({"kind":"initialization","state":state,"sequence":0})
    scene._sync_world();scene._sync_scenery()
    var target:Dictionary=scene.ground_groups[materials[1]].entries[0]
    var node_id:int=target.node.get_instance_id()
    var generation:int=scene.world_generation
    scene._sync_world();scene._sync_scenery()
    check(scene.world_generation==generation and not scene.world_changes.full,"Repeated direct sync consumes no duplicate world revision or cache reset")
    check(target.node.get_instance_id()==node_id,"Repeated unchanged publication preserves native batch identity")
    var replacement:Dictionary=tiles["0,0"].duplicate(true);replacement.surface.base_material=materials[1]
    var delta=Compiler.empty_delta();delta.tiles["0,0"]=replacement
    scene.timeline.accept({"kind":"operation","groups":[group([{"at_ms":0.0,"delta":delta}],0)]})
    scene.timeline.advance(0);scene._sync_world();scene._sync_scenery()
    check(target.node.get_instance_id()==node_id,"Material transfer retains existing target native batch")
    check(target.scenery_values[target.ground_indices["floor-0"]]==1.0,"Same already-current ID rebuilt into another batch receives current style without force")
    check(scene.scenery_visibility.has("floor-0"),"Transfer never changes native subjective sight")
    check(not scene.scenery_index_dirty,"Small floor update does not request whole consumer rebuild")
    scene.queue_free();await process_frame
