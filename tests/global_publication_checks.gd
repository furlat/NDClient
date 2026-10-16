extends "res://tests/world_incremental_checks.gd"
# Actual Play coordinator, with its strict prepared-publication guard enabled.
# Requests below change in-memory preferences only; no saved setting is written.
var timings:Array=[]
class RejectedInitial extends "res://play.gd":
    var refused_initial:bool=false
    var premature_actor_samples:int=0
    var actor_sample_calls:int=0
    func _world_can_publish()->bool:
        if not refused_initial and world_revision<0 and pending_world!=null and pending_world.initial and pending_world.prepared:
            refused_initial=true
            return false
        return super._world_can_publish()
    func _sync_actors()->void:
        actor_sample_calls+=1
        if world_revision<0:premature_actor_samples+=1
        super._sync_actors()

func sample_frame(scene:Node)->void:
    scene._sample_actors();scene._sample_fixtures();scene._sync_native_lighting();scene._sort_draws()
    scene.native_light_atlas.sync_output(scene,[scene.world_generation,scene.quarter,scene.scenery_revision,scene.wall_mode,scene.native_light_atlas.revision],true)

func drive_global(scene:Node,target:int,cap:bool,normals:bool,label:String)->Image:
    var old_quarter:int=scene.quarter
    var old_basis:Basis=scene.camera.global_basis
    var old_cap:float=scene.native_light_atlas.light_cap
    var old_normals:bool=scene.normals_visible
    scene.light_cap_enabled=cap;scene.set_normals_visible(normals)
    if target!=scene.quarter:scene.request_view(target)
    var deadline:int=Time.get_ticks_msec()+60000
    var frames:int=0;var maximum:float=0.0;var commit:float=0.0
    while Time.get_ticks_msec()<deadline and not scene.publication_failed:
        var started:int=Time.get_ticks_usec()
        var budget:Dictionary=scene._preparation_budget()
        scene._dispose_views(budget,true)
        scene._prepare_render_options();scene._prepare_rotation()
        sample_frame(scene)
        var elapsed:float=(Time.get_ticks_usec()-started)/1000.0
        maximum=maxf(maximum,elapsed);frames+=1
        var finished:bool=scene.quarter==target and scene.native_light_atlas.light_cap==(1.0 if cap else 0.0) \
            and scene.normals_visible==normals and scene.pending_global_atlas.is_empty()
        if finished:
            commit=elapsed;await process_frame;await RenderingServer.frame_post_draw
            timings.append({"case":label,"frames":frames,"max_step_cpu_ms":maximum,"last_publication_cpu_ms":commit})
            check(scene.native_light_atlas.errors.is_empty() and not scene.publication_failed,label+" publishes through strict preparation without a fallback")
            return root.get_texture().get_image()
        if scene.rotation_pending():
            check(scene.quarter==old_quarter and scene.camera.global_basis==old_basis,label+" retains displayed camera until complete target publication")
        elif scene.quarter==old_quarter:
            check(scene.native_light_atlas.light_cap==old_cap and scene.normals_visible==old_normals,
                label+" retains displayed render options while their binding work is private")
        await process_frame
    check(false,label+" completes within its explicit preparation boundary: "+str(scene.presentation_errors)+" "+scene.media_issue)
    return Image.new()

func compare_full(scene:Node,actual:Image,label:String)->void:
    if actual.is_empty():return
    # A test-only independent complete source planner. Normal Play stays strict;
    # this explicit oracle does not weaken its publication flag or call a fallback.
    # Sparse published records intentionally omit the old complete-planner
    # replay arrays. Give the oracle its own empty source directory, as its
    # original caller does, while preserving committed integer reservations.
    scene.native_light_atlas.entry_specs={};scene.native_light_atlas.membership=[]
    scene.native_light_atlas.delta_ready=false
    check(scene.native_light_atlas._reconcile(scene),label+" complete source reference accepts current displayed geometry")
    scene.NativeLightAtlas.Delta.rebuild(scene.native_light_atlas,scene.native_light_change_serial)
    scene._sync_native_lighting();scene._sort_draws()
    await process_frame;await RenderingServer.frame_post_draw
    var expected:Image=root.get_texture().get_image()
    var pixels:int=0;var maximum:float=0.0
    for y in actual.get_height():
        for x in actual.get_width():
            var a:Color=actual.get_pixel(x,y);var b:Color=expected.get_pixel(x,y)
            var error:float=maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
            maximum=maxf(maximum,error)
            if error>1.0/255+.00001:pixels+=1
    check(pixels==0,label+" first published framebuffer matches independent complete lighting: "+str(pixels)+" pixels")
    comparisons.append({"case":label,"different_pixels":pixels,"maximum_error":maximum})
    actual.save_png("res://.captures/global-"+label+"-prepared.png")
    expected.save_png("res://.captures/global-"+label+"-reference.png")

func resize_case(scene:Node)->void:
    var paused:bool=scene.timeline.paused
    scene.timeline.paused=false
    var display_ms:float=scene.timeline.display_ms
    var samples:int=scene.actor_sample_calls
    var updates={"count":0}
    var observe=func():updates.count+=1
    scene.presentation_updated.connect(observe)
    root.size=Vector2i(960,1200)
    await process_frame
    check(scene._atlas_needs_viewport_growth(),"Real window resize exceeds the published receiving height")
    var deadline:int=Time.get_ticks_msec()+60000;var held:int=0;var maximum:float=0.0;var commit:float=0.0
    while scene._atlas_needs_viewport_growth() and not scene.publication_failed and Time.get_ticks_msec()<deadline:
        var started:int=Time.get_ticks_usec()
        scene._process(.016)
        var elapsed:float=(Time.get_ticks_usec()-started)/1000.0
        maximum=maxf(maximum,elapsed)
        if scene._atlas_needs_viewport_growth():
            held+=1
            check(scene.timeline.display_ms==display_ms and scene.actor_sample_calls==samples,
                "Resize preparation retains the displayed clock and actor sample")
            check(not scene.timeline.paused,"Resize hold preserves the user's running intent")
        else:commit=elapsed
        await process_frame
    check(not scene._atlas_needs_viewport_growth() and not scene.publication_failed,
        "Resize publishes its enlarged target through the strict candidate path")
    check(held>0 and updates.count>held,"Resize hold continues presentation/UI notifications through adoption")
    check(scene.timeline.display_ms<=display_ms+16.001,"Resize hold adds no accumulated time debt on release")
    scene.timeline.paused=paused;scene.presentation_updated.disconnect(observe)
    timings.append({"case":"resize","held_frames":held,"max_step_cpu_ms":maximum,"last_publication_cpu_ms":commit})
    if not scene.publication_failed:
        await RenderingServer.frame_post_draw
        await compare_full(scene,root.get_texture().get_image(),"resize")

func run()->void:
    if DisplayServer.get_name()=="headless":quit(2);return
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(960,640)
    # play.tscn is exactly the scripted Node3D root. This test subclass changes
    # only one preflight result, leaving recording, preparation and render flow real.
    var scene=RejectedInitial.new();scene.timeline.paused=true;root.add_child(scene)
    var deadline:int=Time.get_ticks_msec()+90000
    while scene.world_revision<0 and not scene.publication_failed and scene.session.issue.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
    check(scene.world_revision>=0 and not scene.publication_failed,"Real recording initializes through production preparation")
    check(scene.refused_initial and scene.premature_actor_samples==0,
        "One rejected initial preflight keeps actor sampling behind the displayed owner")
    if scene.world_revision>=0 and not scene.publication_failed:
        scene.session.close();scene.set_process(false);scene.hud.hide()
        scene.timeline.current={};scene.timeline.queue=[]
        sample_frame(scene)
        check(scene.native_light_atlas.require_prepared_publication,"Actual Play forbids complete publication fallback")
        var original_cap:bool=scene.light_cap_enabled
        for request in [[0,not original_cap,false,"cap"],[0,not original_cap,true,"normals"],
                [1,not original_cap,true,"quarter-one"],[2,not original_cap,true,"quarter-two"],
                [0,original_cap,false,"restore"]]:
            var actual:Image=await drive_global(scene,request[0],request[1],request[2],request[3])
            if actual.is_empty():break
            await compare_full(scene,actual,request[3])
        if failures.is_empty():await resize_case(scene)
        check(scene.presentation_errors.is_empty(),"Global requests produce no presentation errors")
    var report={"checks":checks,"failures":failures,"timings":timings,"comparisons":comparisons,
        "scope":"Actual frozen recording through strict Play quarter/cap/Normals preparation; independent full lighting reference on first published frame. CPU slices include sampling and draw synchronization; no live latency acceptance or constant-time commit claim."}
    var file=FileAccess.open("res://generated/global_publication_checks.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  "));file.close()
    print("GLOBAL_PUBLICATION_CHECKS ",JSON.stringify(report))
    scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
