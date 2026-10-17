extends "res://tests/world_incremental_checks.gd"
# Actual Play coordinator: a rejected initial preflight, then quarter, cap and
# Normals requests. Sprites light themselves from the light table; cap/Normals
# are receiving globals written at once and a quarter publishes its prepared
# view. Each first published frame is compared with a complete republication
# of every receiving global. Requests change in-memory preferences only.
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

func published(scene:Node,cap:bool,normals:bool)->bool:
    return scene.receiving_globals==[1.0 if cap else 0.0,normals] and scene.normals_visible==normals

func drive_global(scene:Node,target:int,cap:bool,normals:bool,label:String)->Image:
    var old_quarter:int=scene.quarter
    var old_basis:Basis=scene.camera.global_basis
    scene.light_cap_enabled=cap;scene.set_normals_visible(normals)
    if target!=scene.quarter:scene.request_view(target)
    var deadline:int=Time.get_ticks_msec()+60000
    var frames:int=0;var maximum:float=0.0;var commit:float=0.0
    while Time.get_ticks_msec()<deadline and not scene.publication_failed:
        var started:int=Time.get_ticks_usec()
        var budget:Dictionary=scene._preparation_budget()
        scene._dispose_views(budget,true)
        scene._prepare_rotation()
        sample_frame(scene)
        var elapsed:float=(Time.get_ticks_usec()-started)/1000.0
        maximum=maxf(maximum,elapsed);frames+=1
        if frames==1:check(published(scene,cap,normals),label+" cap/Normals publish on the first sampled frame")
        if scene.quarter==target and not scene.rotation_pending() and published(scene,cap,normals):
            commit=elapsed;await process_frame;await RenderingServer.frame_post_draw
            timings.append({"case":label,"frames":frames,"max_step_cpu_ms":maximum,"last_publication_cpu_ms":commit})
            check(scene.light_table.issues.is_empty() and not scene.publication_failed,label+" publishes without a light-table issue or publication failure")
            return root.get_texture().get_image()
        if scene.rotation_pending():
            check(scene.quarter==old_quarter and scene.camera.global_basis==old_basis,label+" retains displayed camera until complete target publication")
        await process_frame
    check(false,label+" completes within its explicit preparation boundary: "+str(scene.presentation_errors)+" "+scene.media_issue)
    return Image.new()

func compare_full(scene:Node,actual:Image,label:String)->void:
    if actual.is_empty():return
    # Independent complete reference: forget every uploaded receiving global
    # (light table, cookies, cap/Normals/ambient, ground supports) and republish.
    scene.claim_receiving()
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
    check(pixels==0,label+" first published framebuffer matches a complete receiving republication: "+str(pixels)+" pixels")
    comparisons.append({"case":label,"different_pixels":pixels,"maximum_error":maximum})
    actual.save_png("res://.captures/global-"+label+"-prepared.png")
    expected.save_png("res://.captures/global-"+label+"-reference.png")

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
        var original_cap:bool=scene.light_cap_enabled
        for request in [[0,not original_cap,false,"cap"],[0,not original_cap,true,"normals"],
                [1,not original_cap,true,"quarter-one"],[2,not original_cap,true,"quarter-two"],
                [0,original_cap,false,"restore"]]:
            var actual:Image=await drive_global(scene,request[0],request[1],request[2],request[3])
            if actual.is_empty():break
            await compare_full(scene,actual,request[3])
        check(scene.presentation_errors.is_empty(),"Global requests produce no presentation errors")
    var report={"checks":checks,"failures":failures,"timings":timings,"comparisons":comparisons,
        "scope":"Actual frozen recording through Play quarter/cap/Normals requests; cap/Normals are receiving globals published on the first sampled frame, a quarter publishes its prepared view. First published frame versus a complete republication of every receiving global. CPU slices include sampling and draw synchronization; no live latency acceptance."}
    var file=FileAccess.open("res://generated/global_publication_checks.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  "));file.close()
    print("GLOBAL_PUBLICATION_CHECKS ",JSON.stringify(report))
    scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
