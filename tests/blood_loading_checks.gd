extends SceneTree
## Real recorded blood, through the production renderer's loading boundary.
const Preview=preload("res://presentation/blood_preview.gd")
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Profile=preload("res://frame_profile.gd")
var checks:int=0
var failures:Array=[]
var measurements:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr(label)
func frame()->void:
    await process_frame;await RenderingServer.frame_post_draw
func fixture(renderer:Script=null)->Node3D:
    var viewport=SubViewport.new();viewport.size=Vector2i(384,256);viewport.own_world_3d=true
    viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
    var world=Preview.new()
    if renderer!=null:world.renderer=renderer.new()
    viewport.add_child(world)
    world.camera=Camera3D.new();world.add_child(world.camera)
    world.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;world.camera.size=6.5
    world.camera.basis=Basis.from_euler(Vector3(-atan(sqrt(.5)),PI/4,0));world.camera.position=Vector3(4,.4,6)+world.camera.basis.z*12
    return world
func image(world:Node3D)->Image:return world.get_viewport().get_texture().get_image()
func field(world:Node3D,key:String)->Image:
    # The pre-edit oracle owns one viewport per tile; the atlas reads its slot.
    var handle:Dictionary=world.renderer.deposits[key]
    return handle.field.get_texture().get_image() if handle.has("field") else world.renderer.field_image(handle)
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(384,256)
    Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    create_timer(45).timeout.connect(func():printerr("Blood loading test deadline");quit(2))
    var path:String="res://.runtime/studio-cases/dash-seed3/amber/journal";var oracle:String=""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--oracle="):oracle=argument.trim_prefix("--oracle=")
    var journal=Journal.new();var opened:Dictionary=journal.open(path,true,false)
    check(opened.ok,"Actual opportunity-hit journal opens")
    if not opened.ok:quit(1);return
    var replay:Dictionary=journal.replay(2);check(replay.ok,"Actual before-state admits")
    var packet=journal.protocol.decode("PlayerOperation",FileAccess.get_file_as_bytes(path.path_join("0000000000000003.json")))
    check(packet.ok,"Actual operation decodes")
    var canonical:Dictionary=journal.state.duplicate(true);var cache:Dictionary={}
    var compiled=Compiler.compile(journal.state,journal.protocol.normalize("PlayerOperation",packet.value),cache)
    check(compiled.ok,"Actual operation compiles")
    var component:Dictionary={};var group:Dictionary={}
    for item in compiled.value.groups:
        for candidate in item.components:
            if candidate.kind=="residue_deposit":component=candidate;group=item
    check(not component.is_empty() and component.reveals.size()==20,"Recorded release owns twenty receiving tiles")
    if component.is_empty():quit(1);return
    var held:Dictionary=component.duplicate(true)
    var world=fixture();world.catalog_cache=cache
    var loading:Array=[];var complete:bool=false
    for attempt in 20:
        var began:int=Time.get_ticks_usec();complete=world.renderer.prepare(world,[]);loading.append((Time.get_ticks_usec()-began)/1000.)
        check(world.actor_entries.is_empty() and world.renderer.deposits.is_empty() and world.renderer.pending_deposits.is_empty(),"Loading creates no residue entries "+str(attempt))
        check(world.timeline.state.tiles.is_empty(),"Loading creates no canonical residue "+str(attempt))
        world.sample()
        if complete:break
        await frame()
    check(complete and world.renderer.resources_ready,"Loading waits for the blood shader programs")
    # Blood lights itself from the light table: no receiving viewport exists.
    check(world.find_children("*","SubViewport",true,false).is_empty(),"Loading creates no receiving viewport")
    world.timeline.queue=[group]
    world.renderer.prepare(world,[group],{"used_usec":2000,"limit_usec":2000})
    check(world.renderer.pending_deposits.is_empty() and world.renderer.kernel_jobs.is_empty(),"Exhausted admission starts neither worker work nor native field allocation")
    var future_budget={"used_usec":0,"limit_usec":100000}
    var future_ready:bool=world.renderer.prepare(world,[group],future_budget)
    check(world.renderer.pending_deposits.size()>2 and world.renderer.pending_deposits.size()<=20,"Available time admits more than two exact received fields without a fixed frame-count cap")
    check(not future_ready and world.renderer.pending_deposits.values().all(func(handle):return not handle.ready and not handle.entry.node.visible),"Even a complete allocation turn cannot bypass the actual draw fence or publish residue")
    world.timeline.queue=[];world.sample()
    check(world.renderer.pending_deposits.is_empty() and world.actor_entries.is_empty(),"Cancelling future groups retires their unpublished fields")
    check(world.timeline.state.tiles.is_empty() and world.renderer.deposits.is_empty(),"Cancelled preparation publishes no residue")
    await frame()
    world.timeline.queue=[group]
    var costs:Array=[];var first_construction:Array=[];complete=false
    for attempt in 20:
        var before:int=world.renderer.deposit_create_usec;var began:int=Time.get_ticks_usec()
        var field_budget={"used_usec":0,"limit_usec":2000}
        complete=world.renderer.prepare(world,[group],field_budget);costs.append((Time.get_ticks_usec()-began)/1000.)
        if world.renderer.prepare_allocations>0:first_construction.append((world.renderer.deposit_create_usec-before)/1000.)
        check(field_budget.used_usec>=0 and world.renderer.pending_deposits.size()<=20,"Actual preparation remains budget-accounted and confined to the received closure: "+str(attempt))
        for handle in world.renderer.pending_deposits.values():check(not handle.entry.node.visible,"Prepared actual field stays hidden")
        world.sample();await frame()
        if complete:break
    check(complete and world.renderer.pending_deposits.size()==20,"Actual owner finishes twenty hidden fields")
    check(world.timeline.state.tiles.is_empty(),"Preparation does not publish future tile state")
    world.timeline.world_revision+=1
    world.camera.free();var before_pipelines:Dictionary=Profile.pipeline_compilations();var began:int=Time.get_ticks_usec()
    world.configure(component,cache,350.,0,world.source_lighting)
    measurements.first_air_sample_ms=(Time.get_ticks_usec()-began)/1000.
    await frame();await frame()
    measurements.first_air_through_draw_ms=(Time.get_ticks_usec()-began)/1000.
    measurements.first_air_pipeline_delta={}
    var after_pipelines:Dictionary=Profile.pipeline_compilations()
    for key in before_pipelines:measurements.first_air_pipeline_delta[key]=after_pipelines[key]-before_pipelines[key]
    check(not world.renderer.flights.is_empty(),"Actual release has airborne geometry")
    check(world.renderer.pending_deposits.is_empty() and world.renderer.deposits.size()==20,"Only actual admitted residue adopts prepared fields")
    var reference:Node3D
    if not oracle.is_empty():
        reference=fixture(load(oracle));reference.catalog_cache=cache;reference.timeline.queue=[group]
        # Fields exist only through preparation; the oracle prepares its own.
        var reference_ready:bool=false
        for attempt in 40:
            reference_ready=reference.renderer.prepare(reference,[group],{"used_usec":0,"limit_usec":100000})
            reference.sample();await frame()
            if reference_ready:break
        check(reference_ready,"Pre-edit oracle prepares its twenty fields")
        reference.timeline.world_revision+=1;reference.camera.free()
        reference.configure(component,cache,350.,0,reference.source_lighting)
        await frame();await frame()
    var pixel_samples:Array=[]
    for quarter in [0,1,2,3]:
        for age in [50.,150.,350.,500.,800.,component.duration_ms+1.]:
            for instance in [world,reference]:
                if instance==null:continue
                instance.camera.basis=Basis.from_euler(Vector3(-atan(sqrt(.5)),PI/4+quarter*PI/2,0))
                instance.camera.position=Vector3(component.position[0],.4,component.position[1])+instance.camera.basis.z*12.
                instance.samples[0].age_ms=age;instance.sample()
                # The swatch's floor/air priority holds for flights first drawn
                # after configure too (the oracle's per-flight materials kept 0).
                for entry in instance.actor_entries:entry.material.render_priority=0 if entry.role=="covering" else 1
            await frame();await frame()
            if reference!=null:
                check(image(world).get_data()==image(reference).get_data(),"Original final scene pixels preserved at view/age "+str([quarter,age]))
                for key in world.renderer.deposits:
                    var actual:Image=field(world,key)
                    var expected:Image=field(reference,key)
                    check(actual.get_data()==expected.get_data(),"Original field bytes preserved "+str([quarter,age,key]))
                pixel_samples.append({"quarter":quarter,"age_ms":age,"fields":world.renderer.deposits.size()})
    check(component==held and journal.state==canonical,"Preparation and playback preserve actual event/canonical inputs")
    world.close();await frame()
    check(world.actor_entries.is_empty() and not world.renderer.resources_ready,"Close retires all per-world receiving resources")
    world.timeline.state.tiles={};world.timeline.queue=[];world.samples=[]
    complete=false
    for attempt in 8:
        complete=world.renderer.prepare(world,[]);world.sample();await frame()
        if complete:break
    check(complete and world.renderer.resources_ready,"A new epoch prepares its resources again")
    world.close();world.get_viewport().queue_free()
    if reference!=null:reference.close();reference.get_viewport().queue_free()
    await frame();await frame()
    measurements.loading_calls_ms=loading;measurements.recorded_prepare_calls_ms=costs;measurements.deposit_construction_ms=first_construction
    var report={"checks":checks,"failures":failures,"measurements":measurements,"pixel_samples":pixel_samples,"scope":"Actual recorded blood source; loading and first field/air timings, no fabricated gameplay. Exact pre-edit pixel comparison only when --oracle supplied. No full-game performance claim."}
    FileAccess.open("res://.runtime/blood-loading-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("BLOOD_LOADING_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
