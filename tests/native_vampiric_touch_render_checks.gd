extends SceneTree
## Original first-cast impact only: real setter, measured recipient, pixels and epochs.
const Recording=preload("res://studio/recording.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Play=preload("res://play.gd")
const Effects=preload("res://presentation/effect_package.gd")
const IMPACT="bg3-36/vampiric-touch/vampiric_touch_native/impact"
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("NATIVE_VAMPIRIC_FAIL ",label)
func frame()->void:
    await process_frame
    await RenderingServer.frame_post_draw
func settle(world:Node,component_id:String="")->bool:
    var deadline:int=Time.get_ticks_msec()+45000
    while Time.get_ticks_msec()<deadline and not world.publication_failed and world.presentation_errors.is_empty() and world.media_issue.is_empty():
        var bindings:Dictionary=world.component_renderer.native_spells.diagnostics.get(component_id,{}).get("input_bindings",{})
        var inputs_ready:bool=component_id.is_empty() or (not bindings.is_empty() and bindings.unavailable.is_empty())
        if world.playback_prepared() and inputs_ready:
            await frame()
            if world.playback_prepared():return true
        await frame()
    check(false,"Native preparation: "+str({"errors":world.presentation_errors,"media":world.media_issue,"native":world.component_renderer.native_spells.diagnostics}))
    return false
func changed(a:Image,b:Image)->int:
    a=a.duplicate();b=b.duplicate();a.convert(Image.FORMAT_RGBA8);b.convert(Image.FORMAT_RGBA8)
    var left:PackedByteArray=a.get_data();var right:PackedByteArray=b.get_data();var count:int=0
    for pixel in a.get_width()*a.get_height():
        var at:int=pixel*4
        if absi(int(left[at])-int(right[at]))+absi(int(left[at+1])-int(right[at+1]))+absi(int(left[at+2])-int(right[at+2]))>3:count+=1
    return count
func received_contact(world:Node,index:Dictionary,row:Dictionary,seat:String)->void:
    var component:Dictionary=row.component
    var before:float=maxf(0.0,float(row.start_ms)-2.0)
    world.install_playback(Recording.restore(index,before))
    if not await settle(world):return
    var surface:RefCounted=world.component_renderer.native_spells.inputs.surfaces
    var canonical:PackedByteArray=var_to_bytes(world.timeline.state)
    var prepared:bool=false
    var deadline:int=Time.get_ticks_msec()+10000
    while Time.get_ticks_msec()<deadline:
        var exact:Array=surface.received_poses.filter(func(source):return source.actor==component.target_uuid and source.clip=="TakeDamage")
        prepared=not exact.is_empty() and surface.jobs.is_empty() and surface.pending.is_empty() and exact.all(func(source):return surface.sources.keys().any(func(key):return key[0]==source.path))
        if prepared:break
        await frame()
    check(prepared,seat+" original received TakeDamage source is measured before contact")
    check(world.timeline.display_ms==before and var_to_bytes(world.timeline.state)==canonical,seat+" asynchronous future source work leaves the original pre-contact prefix undisplayed")
    if not prepared:
        var diagnostics:Array=[]
        var renderer:RefCounted=world.component_renderer.native_spells
        for source in surface.received_poses:
            var packet:Dictionary=renderer.Inputs.Surface.admitted_images(world,source.path,source.slot)
            diagnostics.append({"actor":source.actor,"clip":source.clip,"source":source.path,"slot":source.slot,
                "frames":source.frames,"reason":packet.reason,"missing_paths":packet.get("missing_paths",{}),
                "cpu_requested":packet.get("paths",{}).values().filter(func(path):return renderer.required_cpu_images.has(path)),
                "measured_frames":surface.sources.keys().filter(func(key):return key[0]==source.path).map(func(key):return key[-1][0])})
        var diagnostic:Dictionary={"seat":seat,"kind":"future_surface_timeout","display_ms":world.timeline.display_ms,
            "sources":diagnostics,"worker_jobs":surface.jobs.size(),"pending_sources":surface.pending.size(),"owner_scans":surface.received_scans,
            "required_cpu_images":renderer.required_cpu_images.keys()}
        evidence.append(diagnostic);print("VAMPIRIC_FUTURE_TIMEOUT ",JSON.stringify(diagnostic));return
    var measured:Array=surface.sources.keys()
    var built:int=surface.source_builds
    var target:float=float(row.start_ms)+1.0
    var plan:Dictionary=world.timeline.replay_plan(target)
    var published:bool=false
    deadline=Time.get_ticks_msec()+10000
    while Time.get_ticks_msec()<deadline:
        if world.timeline.replay_prepare(plan) and world.can_publish_replay_advance(plan):
            published=world.publish_replay_advance(plan);await frame();break
        await frame()
    check(published,seat+" exact original contact publishes through the ordinary shared replay boundary")
    if not published:return
    check(world.playbacks[component.target_uuid].clip=="TakeDamage",seat+" actual recipient changes to the received damage pose at contact")
    var slots:Array=Array(component.native_cue.entity_geometry.slots)
    var current:Dictionary=surface._capture(world,component.target_uuid,slots)
    check(current.reason.is_empty() and current.selected.all(func(source):return source.key in measured),seat+" exact published recipient source keys were already measured before contact")
    check(surface.source_builds==built and surface.jobs.is_empty() and surface.pending.is_empty(),seat+" first contact requires zero new source measurements or queued jobs")
    evidence.append({"seat":seat,"preparation":"original_precontact_to_contact_same_epoch","precontact_ms":before,
        "contact_ms":target,"measured_sources":measured.size(),"source_builds_before":built,"source_builds_at_contact":surface.source_builds})
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    for seat in ["amber","blue"]:await read_seat(seat)
    finish()
func read_seat(seat:String)->void:
    var index:Dictionary=Recording.read(Fixtures.journal("vampiric-touch",seat))
    check(index.ok,seat+" original journal compiles")
    if not index.ok:return
    var rows:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_cue",{}).get("staged_clip")==IMPACT)
    check(rows.size()==1,seat+" original first cast owns exactly one finite impact")
    if rows.size()!=1:return
    var row:Dictionary=rows[0];var component:Dictionary=row.component
    check(component.status=="available",seat+" exact first-hit constructor is available")
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true;world.media_warmup.budget_bytes=0
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.playback_end_ms=index.presentation_end_ms
    world.component_renderer.audio.set_enabled(false);view.add_child(world)
    await received_contact(world,index,row,seat)
    var start:float=float(row.start_ms);var hit:float=start+minf(140.0,(float(row.end_ms)-start)*.35)
    var previous:WeakRef
    # Two actual seek/loop passes share the immutable recording, never a native
    # source instance or its future sampled state across presentation epochs.
    for at in [maxf(0.0,start-2.0),hit,minf(index.presentation_end_ms,float(row.end_ms)+2.0),maxf(0.0,start-2.0),hit]:
        world.install_playback(Recording.restore(index,at))
        if not await settle(world,component.id if at==hit else ""):view.queue_free();await frame();return
        if previous!=null:check(previous.get_ref()==null,seat+" replacing the replay epoch frees its previous impact owner")
        var native=world.component_renderer.native_spells
        if at!=hit:
            check(native.witnesses.all(func(witness):return witness.id!=component.id),seat+" no first-impact draw witness outside its finite lifetime")
            if native.handles.has(component.id):check(not native.handles[component.id].root.is_visible_in_tree(),seat+" prepared future/retired impact remains hidden")
            previous=null
            continue
        check(native.handles.has(component.id),seat+" finite impact has its own prepared owner")
        if not native.handles.has(component.id):continue
        var handle:Dictionary=native.handles[component.id]
        var programs:Array=handle.occurrence.input_receivers.get("set_strike_input",[])
        check(programs.size()==1,seat+" one actual delivered source receives the strike")
        if programs.size()!=1:continue
        var program:Node3D=programs[0]
        check(program.strike==component.native_inputs.strike_input and program.payload_admitted(),seat+" source setter admits exactly the original first-hit result")
        check(not program.owner_admitted() and not program.healing_admitted(),seat+" unrelated held/healing phases have no fabricated success packet")
        check(program.endpoints.size()==2 and program.endpoints[0].actor_uuid==component.actor_uuid and program.endpoints[1].actor_uuid==component.target_uuid,seat+" original source and recipient bind independently")
        if program.endpoints.size()==2:
            check(program.endpoints[0].point.is_equal_approx(handle.endpoints.hand),seat+" drain reaches the measured casting hand")
            check(program.endpoints[1].socket=="body_center" and not program.recipient_surface().get("points",[]).is_empty() and not program.contact().is_empty(),seat+" impact uses actual recipient body socket, depth/normal points and measured contact")
        var bindings:Dictionary=native.diagnostics.get(component.id,{}).get("input_bindings",{})
        check("strike_input" in bindings.get("supplied",[]) and bindings.get("unavailable",{}).is_empty(),seat+" diagnostic reports actual strike supply without unresolved required inputs")
        check(bindings.get("not_applicable",{}).size()==4,seat+" four exact unused impact-branch inputs remain explicitly N/A")
        check(program.capture_observation().smite.visible_meshes>0,seat+" admitted finite source submits its own native geometry")
        world.camera_focus=Play.Placement.contact({"position":component.to_position,"base_height_steps":float(component.get("to_elevation_feet",0.0))/5.0})
        world.camera.size=5;world.initial_focus=true;world.position_camera();world.grid_visible=false
        await frame();await frame();world.set_process(false)
        var present:Image=view.get_texture().get_image();Effects.hide(handle);await frame();await frame()
        var pixels:int=changed(present,view.get_texture().get_image())
        check(pixels>0,seat+" actual finite impact contributes framebuffer pixels after seeking/looping")
        evidence.append({"seat":seat,"at_ms":at,"changed_pixels":pixels,"strike":program.strike.duplicate(true),"contact":program.contact()})
        previous=weakref(handle.root);handle.root.show();world.set_process(true)
    var native=world.component_renderer.native_spells
    native.close(world)
    check(native.handles.is_empty() and native.groups.is_empty() and native.prepared_layers.is_empty(),seat+" explicit native teardown releases all impact owners and render passes")
    check(previous==null or previous.get_ref()==null,seat+" final impact owner is freed on close")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),seat+" real seek/loop introduces no presentation/resource errors")
    view.queue_free();await frame();await frame()
func finish()->void:
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Original independent first-cast Vampiric Touch impact, real strike setter/admission, measured hand/recipient surface, native pixels and seek/loop/cleanup. Held/repeat/healing, performance and user visual acceptance remain unqualified."}
    FileAccess.open("res://.runtime/native-vampiric-touch-render-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_VAMPIRIC ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
