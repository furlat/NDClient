extends SceneTree
## Actual canonical residue values without injury components, through the
## production worker/native/publication split. No fabricated injury or artwork.
const Preview=preload("res://presentation/blood_preview.gd")
const Preparation=preload("res://presentation/world_preparation.gd")
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Blood=preload("res://presentation/blood.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
var checks:int=0
var failures:Array=[]
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("BLOOD_WORLD_PREPARATION_FAIL ",label)
func _initialize()->void:run.call_deferred()
func frame()->void:
    await process_frame;await RenderingServer.frame_post_draw
func prepare(renderer:RefCounted,world:Node,owner:Node,rows:Dictionary,packet:Dictionary)->bool:
    for attempt in 80:
        if renderer.prepare_world(world,owner,rows,packet,{"used_usec":0,"limit_usec":4000}):return true
        await frame()
    return false
func dispose_packet(packet:Dictionary,renderer:RefCounted)->void:
    for held in renderer.release_world(packet):
        if is_instance_valid(held.node):held.node.queue_free()
func select_overlap(journal:RefCounted,directory:String)->Dictionary:
    var previous:Dictionary={};var cache:Dictionary={}
    for row in Fixtures.fact_rows("gallery","damage"):
        if row.fact.get("body_release")==null:continue
        var release:Dictionary=row.fact.body_release
        var sequence:int=int(row.sequence)
        for region in release.get("regions",[]):
            for point in region.positions:
                var key:String=Blood.key(point)
                if previous.has(key) and int(previous[key])<sequence:
                    var restored:Dictionary=journal.replay(sequence-1)
                    check(restored.ok,"Original canonical prefix before later blood release reduces")
                    if not restored.ok:return {}
                    var tile:Dictionary=journal.state.tiles.get(key,{})
                    if Blood.residue(tile).is_empty() or journal.state.senses==null or not Journal.Reducer.Cells.contains(journal.state.senses.visible,point):continue
                    var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join("%016d.json"%sequence))
                    var decoded:Dictionary=journal.protocol.decode("PlayerOperation",raw)
                    check(decoded.ok,"Original later injury packet admits without wire translation")
                    if not decoded.ok:return {}
                    var compiled:Dictionary=Compiler.compile(journal.state,journal.protocol.normalize("PlayerOperation",decoded.value),cache)
                    check(compiled.ok,"Actual later injury compiles before choosing its existing blood tile")
                    if not compiled.ok:return {}
                    for group in compiled.value.groups:
                        for component in group.components:
                            if component.kind=="residue_deposit" and component.start_ms>0 and component.reveals.any(func(reveal):return Blood.key(reveal.position)==key):
                                return {"sequence":sequence,"key":key,"tile":tile,"state":journal.state,"cache":cache,
                                    "earlier_sequence":int(previous[key]),"source_event_uuid":component.source_event_uuid}
                previous[key]=sequence
    return {}
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(384,256)
    create_timer(45).timeout.connect(func():printerr("Blood world preparation deadline");quit(2))
    var journal=Journal.new()
    var directory:String=Fixtures.journal("gallery")
    var opened:Dictionary=journal.open(directory,true,false)
    check(opened.ok,"Actual Gallery journal opens")
    if not opened.ok:quit(1);return
    var selected:Dictionary=select_overlap(journal,directory)
    check(not selected.is_empty(),"Original Gallery contains persistent blood followed by a later actual overlapping release")
    if selected.is_empty():quit(1);return
    var tile:Dictionary=selected.tile;var key:String=selected.key
    # Isolate the exact tile in a native swatch. Keep the actual canonical
    # compact sensory mask and schema16 stores; the original journal is intact.
    var state:Dictionary=selected.state.duplicate()
    state.tiles={key:tile};state.actors={};state.objects={};state.object_members={};state.connectors={};state.light_sources={}
    state.senses=state.senses.duplicate();state.senses.objects={};state.senses.entities={}
    var input={"state":state,"actor_state":state,"changes":{"full":true,"tiles":{},"objects":{},"senses":true,"order":[]},
        "staged_actors":{},"actor_samples":{},"actor_loadouts":{},"existing_actors":{},"cache":selected.cache,"retained":{},"ground":{},
        "quarter":0,"basis":Basis.IDENTITY,"background":true,"global_rows":true,"visibility":{},"visible_cells":{},"initial":true,"world_changed":true}
    var worker_owner=Preparation.new()
    var task:int=WorkerThreadPool.add_task(worker_owner._derive.bind(input));WorkerThreadPool.wait_for_task_completion(task)
    check(worker_owner.result.get("complete",false) and worker_owner.result.blood_rows.has(key),"Worker prepares actual tile after-value with no injury event")
    if not worker_owner.result.get("complete",false):worker_owner.free();quit(1);return
    var rows:Dictionary=worker_owner.result.blood_rows
    var viewport=SubViewport.new();viewport.size=Vector2i(384,256);viewport.own_world_3d=true
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
    var world=Preview.new();viewport.add_child(world);world.catalog_cache=worker_owner.result.source_files
    world.camera=Camera3D.new();world.add_child(world.camera);world.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;world.camera.size=5
    world.camera.basis=Basis.from_euler(Vector3(-atan(sqrt(.5)),PI/4,0))
    world.camera.position=Vector3(tile.position[0],0,tile.position[1])+world.camera.basis.z*12
    var owner=Node3D.new();world.add_child(owner)
    var packet={"handles":{},"retired":[]}
    check(await prepare(world.renderer,world,owner,rows,packet),"Initial field and actual pages draw privately before publication")
    check(world.actor_entries.is_empty() and world.renderer.deposits.is_empty(),"Private world preparation registers no displayed field")
    var handle:Dictionary=packet.handles[key].handle
    check(handle.ready and not handle.entry.node.visible and not handle.registered and handle.slot>=0,"Native field stays hidden in a private, unregistered atlas slot")
    var created:int=world.renderer.deposit_create_usec
    world.renderer.publish_world(world,packet)
    check(world.renderer.deposits.size()==1 and world.actor_entries.size()==1 and is_same(world.actor_entries[0],handle.entry) and handle.registered,"Publication registers the exact prepared draw once")
    world.timeline.state=state;world.timeline.world_revision+=1;world.scenery_visible_cells={key:true}
    var uploads:int=world.renderer.field_uploads
    world.sample()
    check(world.renderer.last_allocations==0 and world.renderer.deposit_create_usec==created,"First actual field sample constructs no native nodes")
    check(world.renderer.field_uploads==uploads and is_same(handle.kernel_cache,rows[key].cache),"First settled sample reuses worker kernels and pre-drawn upload")
    check(world.renderer.ready and handle.entry.node.visible,"Initial actual residue is ready when revealed")
    var decoded:Dictionary=journal.protocol.decode("PlayerOperation",FileAccess.get_file_as_bytes(directory.path_join("%016d.json"%int(selected.sequence))))
    check(decoded.ok,"Actual later overlapping injury operation admits")
    if not decoded.ok:worker_owner.free();world.close();quit(1);return
    var future:Dictionary=Compiler.compile(journal.state,journal.protocol.normalize("PlayerOperation",decoded.value),world.catalog_cache)
    check(future.ok,"Actual later injury compiles its future blood releases")
    if not future.ok:worker_owner.free();world.close();quit(1);return
    var next_group:Dictionary={}
    for group in future.value.groups:
        for component in group.components:
            if component.kind=="residue_deposit" and component.start_ms>0 and component.reveals.any(func(reveal):return Blood.key(reveal.position)==key):next_group=group;break
        if not next_group.is_empty():break
    check(not next_group.is_empty(),"An actual future release crosses the existing authoritative blood tile")
    if not next_group.is_empty():
        var pixels:PackedByteArray=world.renderer.field_image(handle).get_data()
        var was_covered:bool=world.renderer.visible_fields.has(key)
        world.timeline.current=next_group;world.timeline.display_ms=0.;world.timeline.group_start_ms=0.
        world.sample()
        check(world.renderer.field_uploads==uploads and handle.phase.is_empty(),"Inert future release does not reevaluate or upload an unchanged pre-drawn blood field")
        check(world.renderer.ready and handle.entry.node.visible and world.renderer.visible_fields.has(key)==was_covered,"Existing authoritative blood retains its exact native coverage while the next injury is pending")
        await frame()
        check(world.renderer.field_image(handle).get_data()==pixels,"Exact native field pixels stay unchanged before the real future release")
        world.timeline.current=null
    future={};decoded={};next_group={}
    for quarter in [0,1,2,3]:
        world.camera.basis=Basis.from_euler(Vector3(-atan(sqrt(.5)),PI/4+quarter*PI/2,0))
        world.camera.position=Vector3(tile.position[0],0,tile.position[1])+world.camera.basis.z*12
        world.sample()
        check(world.renderer.last_allocations==0 and world.renderer.field_uploads==uploads,"Rotation reuses exact prepared field at quarter "+str(quarter))
    world.camera.position+=Vector3(100,0,100);world.sample()
    check(not handle.entry.node.visible and world.renderer.deposits.size()==1,"Offscreen canonical field stays retained without a new draw")
    world.camera.position-=Vector3(100,0,100);world.sample()
    check(handle.entry.node.visible and world.renderer.last_allocations==0,"Returning to remembered field requires no allocation")
    # A source revision can retain identical artwork/value while changing source
    # identity. It must get private operands; it cannot overwrite displayed data.
    var changed:Dictionary=rows[key].duplicate();changed.source=rows[key].source.duplicate()
    changed.cache={};changed.kernels=Blood.kernels(changed.value,changed.tile.position,[],changed.source,changed.cache)
    var cancelled={"handles":{},"retired":[]};var cancelled_owner=Node3D.new();world.add_child(cancelled_owner)
    check(await prepare(world.renderer,world,cancelled_owner,{key:changed},cancelled),"Changed source with same canonical value receives private field")
    check(is_same(world.renderer.deposits[key],handle) and handle.entry.node.visible and world.actor_entries.size()==1,"Future source cannot mutate or replace displayed field before cue")
    var cancelled_handle:Dictionary=cancelled.handles[key].handle;var cancelled_slot:int=cancelled_handle.slot
    dispose_packet(cancelled,world.renderer);cancelled_owner.queue_free();await frame()
    check(cancelled_handle.slot<0 and world.renderer._free_slots.has(cancelled_slot) and not cancelled_handle.entry.node.visible and is_same(world.renderer.deposits[key],handle) and handle.slot>=0 and handle.entry.node.visible,"Canceled candidate returns only its private slot and draw to the pool")
    var replacement={"handles":{},"retired":[]};var replacement_owner=Node3D.new();world.add_child(replacement_owner)
    check(await prepare(world.renderer,world,replacement_owner,{key:changed},replacement),"Next source candidate can prepare independently after cancellation")
    world.renderer.publish_world(world,replacement)
    check(not handle.entry.node.visible and world.actor_entries.size()==1 and not is_same(world.renderer.deposits[key],handle),"Cue swaps prepared source while the hidden old field waits for release")
    var old_slot:int=handle.slot
    var held:Array=world.renderer.release_world(replacement)
    check(held.is_empty() and handle.slot<0 and world.renderer._free_slots.has(old_slot) and world.renderer.deposits[key].slot!=old_slot,"Old field slot and draw return to the renderer pool; nothing needs external retirement")
    for entry in held:entry.node.queue_free()
    world.sample();check(world.renderer.last_allocations==0,"Reloaded source first sample allocates nothing")
    var removal={"handles":{},"retired":[]}
    check(world.renderer.prepare_world(world,owner,{key:{"removed":true}},removal,{"used_usec":0,"limit_usec":0}),"Authoritative field removal needs no native allocation allowance")
    world.renderer.publish_world(world,removal);world.timeline.state=state.duplicate();world.timeline.state.tiles={};world.timeline.world_revision+=1
    world.sample()
    check(world.renderer.deposits.is_empty() and world.actor_entries.is_empty() and world.renderer.last_allocations==0,"Removal publication removes field before sampling")
    dispose_packet(removal,world.renderer);dispose_packet(packet,world.renderer)
    worker_owner.free();world.close();viewport.queue_free();await frame();await frame()
    var report={"checks":checks,"failures":failures,"recording":directory,"earlier_sequence":selected.earlier_sequence,
        "later_sequence":selected.sequence,"tile":tile.position,"source_event_uuid":selected.source_event_uuid,
        "scope":"Actual canonical no-event residue worker/native ownership, late overlapping injury, unchanged native pixels, rotation, cancellation, source replacement and field removal. No whole-game performance claim."}
    FileAccess.open("res://.runtime/blood-world-preparation-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("BLOOD_WORLD_PREPARATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
