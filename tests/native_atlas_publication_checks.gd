extends "res://tests/native_surface_receiving_checks.gd"
# Run this same immutable recording twice, selecting only the atlas script.
# This captures evidence; cross-run byte comparison belongs to the caller.
var publication_captures:Array=[]
var output_directory:String
var run_label:String
var reveal_indices:Array=[1,2,3]
var cap_during_reveals=false
var rotation_failures:Array=[]
var reveal_log:Array=[]
var initialization:Dictionary={}
const INITIALIZATION_MS=120000
const DRAIN_MS=300000
const STEP_MS=60000
var watched:Node
var stage:String=""
var stage_limit:int=0
var stall:Dictionary={}
var report_written:=false
var settled:Dictionary={}

func argument(name:String,fallback:String="")->String:
    var args=OS.get_cmdline_user_args()
    for i in args.size():
        if args[i].begins_with(name+"="):return args[i].substr(name.length()+1)
        if args[i]==name and i+1<args.size():return args[i+1]
    return fallback

func open_requested_recording(scene:Node,directory:String)->Dictionary:
    # play.gd opens only the separated form `--recording <dir>`. The
    # `--recording=<dir>` form is invisible to it: no replay starts, no live
    # config exists, and the session waits forever without an issue. Open the
    # same directory through the same entry point play.gd uses, once.
    if scene.session.replay_thread!=null:return {"ok":true,"value":null,"opened_by":"player"}
    var opened:Dictionary=scene.session.open_recording(directory)
    scene.notice_text="Playing recorded subjective events." if opened.ok else str(opened.error)
    opened.opened_by="harness"
    return opened

func enter(label:String,limit_ms:int=STEP_MS)->void:
    stage=label;stage_limit=Time.get_ticks_msec()+limit_ms

func _watch()->void:
    # A publication failure stops play.gd _process, so presentation_updated
    # never comes again; bound every await instead of hanging the run.
    if report_written or watched==null or not is_instance_valid(watched) or stage.is_empty():return
    var failed:bool=watched.publication_failed
    if not failed and Time.get_ticks_msec()<stage_limit:return
    stall={"stage":stage,"publication_failed":failed,"timed_out":not failed,"media_issue":watched.media_issue,
        "presentation_errors":watched.presentation_errors.slice(0,5),"atlas_errors":watched.native_light_atlas.errors.slice(0,5),
        "quarter":watched.quarter,"wall_mode":watched.wall_mode,"cap":watched.native_light_atlas.light_cap,"normals":watched.normals_visible,
        "sequence":watched.timeline.sequence,"captures":publication_captures.size(),"components":component_status(watched)}
    print("STALL ",JSON.stringify(stall))
    check(false,"Publication continues through "+stage)
    finish_report()

func initialization_receipt(scene:Node,directory:String,started_ms:int)->Dictionary:
    var session=scene.session
    var preparation:Dictionary=session.diagnostics();preparation.erase("network")
    var cause="ready"
    if session.replay_thread==null:cause="recording never opened (Player reads only `--recording <dir>`)"
    elif not session.issue.is_empty():cause="recording rejected: "+str(session.issue.get("message",session.issue))
    elif not scene.media_issue.is_empty():cause="media failed: "+str(scene.media_issue)
    elif not session.replay_finished:cause="journal scan unfinished"
    elif not session.recording_ready:cause="no operation prepared"
    elif not scene._media_ready({}):cause="mandatory initial media not ready"
    elif scene.world_revision<0:cause="world never published"
    return {"cause":cause,"recording":directory,"recording_opened":session.replay_thread!=null,
        "replay_finished":session.replay_finished,"recording_ready":session.recording_ready,
        "session_issue":session.issue,"media_issue":scene.media_issue,"media_initial_ready":scene.media_initial_ready,
        "world_revision":scene.world_revision,"notice":scene.notice_text,"preparation":preparation,
        "presentation_errors":scene.presentation_errors.slice(0,5),"waited_ms":Time.get_ticks_msec()-started_ms}

func disclosed(scene:Node)->Dictionary:
    var state:Dictionary=scene.timeline.presentation_state()
    return {"tiles":state.tiles.keys(),"objects":state.objects.keys()}

func added(before:Array,after:Array)->Array:
    var known={}
    for id in before:known[id]=true
    var result=[]
    for id in after:
        if not known.has(id):result.append(id)
    result.sort()
    return result

func sample_receipt(scene:Node)->Array:
    var result=[]
    var ids=scene.visual_actors.keys();ids.sort()
    for id in ids:
        var visual:Dictionary=scene.visual_actors[id]
        var playback:Node=scene.playbacks[id]
        var layers=[]
        for entry in visual.entries:
            var frame:Variant=entry.material.get_shader_parameter("frame_uv")
            layers.append({"id":entry.id,"visible":entry.node.visible,"source":entry.get("texture_path",""),
                "frame_uv":[frame.x,frame.y,frame.z,frame.w] if frame!=null else [],
                "position":[entry.node.position.x,entry.node.position.y,entry.node.position.z]})
        result.append({"id":id,"position":visual.row.position.duplicate(),"height":visual.row.base_height_steps,
            "facing":visual.row.facing,"clip":playback.clip,"source_seconds":playback.sample_seconds,"layers":layers})
    return result

func save_first_draw(scene:Node,label:String,extra:Dictionary={})->Image:
    # The caller has just awaited presentation_updated. Freeze before another
    # process tick; capture the first native draw using that publication.
    scene.set_process(false)
    var clock:float=scene.timeline.display_ms
    var actors=sample_receipt(scene)
    var item={"label":label,"sequence":scene.timeline.sequence,"display_ms":clock,
        "group":scene.timeline.current.get("id",""),"commit_index":scene.timeline.commit_index,
        "completed_groups":scene.timeline.completed_group_count,"world_revision":scene.world_revision,
        "quarter":scene.quarter,"wall_mode":scene.wall_mode,"cap":scene.native_light_atlas.light_cap,
        "normals":scene.normals_visible,"actors":actors,"tiles":scene.timeline.presentation_state().tiles.size(),
        "objects":scene.timeline.state.objects.size(),"receivers":scene.native_light_atlas.receivers.size(),
        "effects_ready":scene.component_renderer.ready,"effect_issues":scene.component_renderer.native_spells.issues.duplicate(),
        "camera_focus":[scene.camera_focus.x,scene.camera_focus.y,scene.camera_focus.z],"camera_size":scene.camera.size}
    item.merge(extra)
    await RenderingServer.frame_post_draw
    var image=root.get_texture().get_image()
    var path=output_directory+"/"+label+".png"
    check(image.save_png(path)==OK,"Capture saves "+label)
    item.file=path
    publication_captures.append(item)
    check(scene.timeline.display_ms==clock and sample_receipt(scene)==actors,"First draw retains exact clock/source samples "+label)
    return image

func mode_published(scene:Node)->bool:
    var cap:float=1.0 if scene.light_cap_enabled else 0.0
    return scene.native_light_atlas.light_cap==cap and scene.native_light_atlas.normals_visible==scene.requested_normals_visible \
        and scene.normals_visible==scene.requested_normals_visible and scene.pending_global_atlas.is_empty()

func component_status(scene:Node)->Dictionary:
    var renderer=scene.component_renderer
    var rows=[]
    for row in renderer.native_spells.diagnostics.values():rows.append({"id":row.get("id",""),"status":row.get("status",""),"reason":row.get("reason",""),
        "age_ms":row.get("age_ms",-1),"requested_age_ms":row.get("requested_age_ms",-1),"source_age":row.get("source_age",-1)})
    return {"ready":renderer.ready,"spells":renderer.native_spells.ready,"hits":renderer.native_hits.ready,"blood":renderer.blood.ready,
        "spell_issues":renderer.native_spells.issues.slice(0,5),"spell_rows":rows.slice(0,8),"handles":renderer.native_spells.handles.size(),
        "displayed_components":scene.displayed_components.size()}

func pending_effects(scene:Node)->Array:
    var rows=[]
    for row in scene.component_renderer.native_spells.diagnostics.values():
        if not str(row.get("reason","")).is_empty():rows.append({"id":row.id,"reason":row.reason,"age_ms":row.get("age_ms",-1),"requested_age_ms":row.get("requested_age_ms",-1)})
    return rows

func refresh_capture(scene:Node,label:String)->Image:
    enter(label)
    scene.set_process(true)
    await scene.presentation_updated
    # Cap/Normals on a published world arrive through a prepared global atlas
    # over later frames; capture the first draw of that publication.
    while not mode_published(scene) and not scene.publication_failed:await scene.presentation_updated
    return await save_first_draw(scene,label)

func apply_mode(scene:Node,wall:String,cap:bool,normals:bool)->void:
    # In-memory controls only: the user's persisted settings are never changed.
    # Same routing as set_light_cap_enabled minus its settings write: a
    # published world takes cap/Normals as a prepared global-atlas publication;
    # switching the atlas directly would discard its committed lighting delta.
    scene.wall_mode=wall
    if scene.world_revision>=0:scene.update_wall_visibility()
    scene.light_cap_enabled=cap
    if scene.entries.is_empty() or scene.world_prepare_epoch!=scene.timeline.initialization_revision:
        scene.native_light_atlas.set_light_cap(1.0 if cap else 0.0)
    scene.set_normals_visible(normals)

func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1280,800)
    # The new window can take OS focus before unfocusable applies; keystrokes
    # typed elsewhere (P pause, Q/E rotate, Z walls) must never drive a capture.
    root.gui_disable_input=true
    var reference=argument("--reference-atlas")
    run_label="reference" if not reference.is_empty() else "lit" if "--lit-sprites" in OS.get_cmdline_user_args() else "current"
    var requested=argument("--reveal-indices")
    if not requested.is_empty():
        reveal_indices=[]
        for value in requested.split(","):
            if value.is_valid_int() and int(value)>0 and int(value) not in reveal_indices:reveal_indices.append(int(value))
        reveal_indices.sort()
    cap_during_reveals=argument("--reveal-cap")=="on"
    output_directory="res://.captures/atlas-publication"+("-cap" if cap_during_reveals else "")+"/"+run_label
    DirAccess.make_dir_recursive_absolute(output_directory)
    # One run per folder: stale captures from another journal must not sit
    # beside this run's evidence.
    for stale in DirAccess.get_files_at(output_directory):
        if stale.get_extension()=="png":DirAccess.remove_absolute(output_directory+"/"+stale)
    var recording=argument("--recording")
    if recording.is_empty() or not FileAccess.file_exists(recording.path_join("0000000000000000.json")):
        check(false,"Recording journal exists: "+recording)
        print("INITIALIZATION ",JSON.stringify({"cause":"missing journal; pass --recording=<journal directory>","recording":recording}))
        finish_report();return
    ProjectSettings.set_setting("source_data/encounter_cache_mib",0)
    var scene=Player.instantiate();scene.timeline.paused=true
    if not reference.is_empty():
        var selected=preload("res://tests/atlas_reference.gd").instantiate(reference)
        if selected==null:
            check(false,"Reference atlas script loads: "+reference);scene.free();finish_report();return
        scene.native_light_atlas=selected
    root.add_child(scene)
    scene.set_process_input(false);scene.set_process_unhandled_input(false)
    watched=scene;process_frame.connect(_watch)
    enter("initialization",INITIALIZATION_MS+10000)
    var opened=open_requested_recording(scene,recording)
    check(opened.ok,"Recording opens: "+str(opened.get("error","")))
    # _ready reads local settings, so override only this scene immediately after
    # attachment. The two separate runs use these same deterministic controls.
    scene.character_light_profile="reference"
    scene.fire_light_flicker=false;scene.source_lighting.fire_light_flicker=false
    scene.set_light_strength(1.0,false)
    scene.source_depth=true;scene.source_normals=true
    scene.grid_visible=false;scene.hud.hide();scene.camera.size=8.137
    scene.initial_focus=true;scene.camera_focus=Vector3(4,0,5);scene.position_camera()
    apply_mode(scene,"solid",cap_during_reveals,false)
    var started_ms=Time.get_ticks_msec()
    var deadline=started_ms+INITIALIZATION_MS
    while opened.ok and (not scene.session.recording_ready or not scene._media_ready({}) or scene.world_revision<0) and scene.session.issue.is_empty() and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline:
        await process_frame
    initialization=initialization_receipt(scene,recording,started_ms);initialization.opened_by=opened.get("opened_by","")
    check(scene.session.recording_ready and scene.media_initial_ready and scene.world_revision>=0,"Immutable recording initializes exact visible sources")
    if not failures.is_empty():
        print("INITIALIZATION ",JSON.stringify(initialization))
        scene.queue_free();await process_frame;finish_report();return
    await scene.presentation_updated
    var previous=disclosed(scene)
    var generation:int=scene.world_generation
    var reveal=0
    deadline=Time.get_ticks_msec()+DRAIN_MS
    enter("drain",DRAIN_MS+10000)
    while (not scene.session.terminal or scene.timeline.busy() or scene.timeline.sequence!=scene.session.latest_sequence) and scene.session.issue.is_empty() and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline:
        # Never advance an empty queue: decode/preparation wall time must not
        # add idle time. Pending boundaries retain their exact planned target.
        if scene.timeline.busy():
            if not scene.actor_rows.is_empty():
                scene.camera_focus=scene.Placement.contact(scene.actor_rows[0]);scene.position_camera()
            scene.timeline.paused=false;scene.timeline.advance(1000.0);scene.timeline.paused=true
        await scene.presentation_updated
        if scene.world_generation!=generation:
            var current=disclosed(scene)
            var new_tiles=added(previous.tiles,current.tiles)
            var new_objects=added(previous.objects,current.objects)
            if not new_tiles.is_empty() or not new_objects.is_empty():
                reveal+=1
                reveal_log.append({"index":reveal,"sequence":scene.timeline.sequence,"group":scene.timeline.current.get("id",""),
                    "new_tiles":new_tiles.size(),"new_objects":new_objects.size(),"captured":reveal in reveal_indices})
                if reveal in reveal_indices:
                    await save_first_draw(scene,"reveal-%03d"%reveal,{"new_tiles":new_tiles,"new_objects":new_objects})
                    scene.set_process(true)
            previous=current;generation=scene.world_generation
    check(scene.session.terminal and not scene.timeline.busy() and scene.timeline.sequence==scene.session.latest_sequence,"Recording drains every authoritative operation")
    check(scene.timeline.state==scene.session.journal.state,"Final displayed state equals the recording's canonical reduction")
    for selected in reveal_indices:check(selected<=reveal,"Requested newly disclosed publication exists: "+str(selected))
    if not failures.is_empty():
        print("DRAIN ",JSON.stringify({"reveals":reveal,"sequence":scene.timeline.sequence,"latest_sequence":scene.session.latest_sequence,
            "terminal":scene.session.terminal,"busy":scene.timeline.busy(),"session_issue":scene.session.issue,"media_issue":scene.media_issue,
            "timed_out":Time.get_ticks_msec()>=deadline}))
        scene.queue_free();await process_frame;finish_report();return
    scene.session.close();scene.timeline.paused=true
    var canonical=scene.timeline.state.duplicate(true)
    var final_clock:float=scene.timeline.display_ms
    if not scene.actor_rows.is_empty():scene.camera_focus=scene.Placement.contact(scene.actor_rows[0])
    scene.position_camera()
    # Native effects reach the frozen requested age one source frame per draw
    # (no second clock), so the last 1000ms request leaves them catching up.
    # The final grid assumes a fixed scene: let them reach the final clock.
    enter("settle")
    scene.set_process(true)
    var settle_started=Time.get_ticks_msec();var settle_draws=0;var lagging=pending_effects(scene)
    while not scene.publication_failed and Time.get_ticks_msec()<settle_started+STEP_MS-5000:
        await scene.presentation_updated;settle_draws+=1
        if pending_effects(scene).is_empty():break
    settled={"draws":settle_draws,"ms":Time.get_ticks_msec()-settle_started,"components":component_status(scene),
        "lagging_at_start":lagging,"pending":pending_effects(scene),"display_ms":scene.timeline.display_ms}
    check(pending_effects(scene).is_empty() and scene.timeline.display_ms==final_clock,"Final native effects reach the frozen final clock before the grid")
    for quarter in 4:
        scene.set_process(true);scene.request_view(quarter)
        enter("rotation q%d"%quarter,70000)
        var rotation_deadline=Time.get_ticks_msec()+60000
        while scene.rotation_pending() and Time.get_ticks_msec()<rotation_deadline:await scene.presentation_updated
        check(not scene.rotation_pending() and scene.quarter==quarter,"Final requested quarter publishes "+str(quarter))
        if scene.rotation_pending() or scene.quarter!=quarter:
            var pending=scene.pending_view
            var diagnostic={"requested":quarter,"actual":scene.quarter,"retiring_nodes":scene.retiring_node_count,
                "media_ready":scene._environment_media_ready(),"media_issue":scene.media_issue,
                "world_preparing":scene.pending_world!=null,"world_revision":scene.world_revision,
                "phase":pending.phase if pending!=null else "none","cursor":pending.cursor if pending!=null else -1,
                "prepared":pending.is_prepared if pending!=null else false,
                "style_current":pending.style_is_current() if pending!=null else false,
                "projection_current":pending.projection_is_current() if pending!=null else false}
            rotation_failures.append(diagnostic);print("ROTATION_TIMEOUT ",JSON.stringify(diagnostic))
        for mode in ["solid","translucent","hidden"]:
            apply_mode(scene,mode,false,false)
            await refresh_capture(scene,"final-q%d-%s-off"%[quarter,mode])
        # Keep one exact beauty image for the roundtrip; source clocks are fixed.
        var hidden=Image.load_from_file(output_directory+"/final-q%d-hidden-off.png"%quarter)
        apply_mode(scene,"hidden",true,false)
        await refresh_capture(scene,"final-q%d-hidden-cap"%quarter)
        apply_mode(scene,"hidden",true,true)
        await refresh_capture(scene,"final-q%d-normals"%quarter)
        apply_mode(scene,"hidden",false,false)
        var restored=await refresh_capture(scene,"final-q%d-hidden-restored"%quarter)
        check(hidden.get_data()==restored.get_data(),"Cap/Normals restores final beauty byte-exactly q"+str(quarter))
        check(scene.timeline.display_ms==final_clock,"Quarter/settings preserve final displayed clock q"+str(quarter))
    check(scene.timeline.state==canonical,"Capture matrix never changes canonical state")
    check(scene.presentation_errors.is_empty() and scene.native_light_atlas.errors.is_empty(),"No source/native atlas errors")
    stage=""
    scene.queue_free();await process_frame;await process_frame
    finish_report()

func finish_report()->void:
    if report_written:return
    report_written=true
    var report={"run":run_label,"checks":checks,"failures":failures,"recording":argument("--recording"),
        "reference_atlas":argument("--reference-atlas"),"selected_reveals":reveal_indices,"initialization":initialization,"reveals":reveal_log,"captures":publication_captures,
        "rotation_failures":rotation_failures,"stall":stall,"settled":settled,
        "renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),
        "scope":"Same immutable recording and1000ms manual timeline requests, paused between requests; no empty-queue clock advances. Selected first-disclosure native frames and24 final captures: four quarters, three wall modes, cap/Normals beauty roundtrip. Fixed source profile/strength and static fire. Cross-run exact pixels and matching clock/source receipts must be compared externally; this report alone does not assert reference/current equality. No timing claim."}
    FileAccess.open(output_directory+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_ATLAS_PUBLICATION ",JSON.stringify({"run":run_label,"checks":checks,"failures":failures,"reveals":reveal_log.size(),"captures":publication_captures.size()}))
    quit(0 if failures.is_empty() else 1)
