extends "res://tests/native_surface_receiving_checks.gd"
# Run this same immutable recording twice, selecting only the atlas script.
# This captures evidence; cross-run byte comparison belongs to the caller.
var publication_captures:Array=[]
var output_directory:String
var run_label:String
var reveal_indices:Array=[1,2,3]
var cap_during_reveals=false
var rotation_failures:Array=[]

func argument(name:String,fallback:String="")->String:
    var args=OS.get_cmdline_user_args()
    for i in args.size():
        if args[i].begins_with(name+"="):return args[i].substr(name.length()+1)
        if args[i]==name and i+1<args.size():return args[i+1]
    return fallback

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

func refresh_capture(scene:Node,label:String)->Image:
    scene.set_process(true)
    await scene.presentation_updated
    return await save_first_draw(scene,label)

func apply_mode(scene:Node,wall:String,cap:bool,normals:bool)->void:
    # In-memory controls only: the user's persisted settings are never changed.
    scene.wall_mode=wall
    if scene.world_revision>=0:scene.update_wall_visibility()
    scene.light_cap_enabled=cap;scene.native_light_atlas.set_light_cap(1.0 if cap else 0.0)
    scene.set_normals_visible(normals)

func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1280,800)
    var reference=argument("--reference-atlas")
    run_label="reference" if not reference.is_empty() else "current"
    var requested=argument("--reveal-indices")
    if not requested.is_empty():
        reveal_indices=[]
        for value in requested.split(","):
            if value.is_valid_int() and int(value)>0 and int(value) not in reveal_indices:reveal_indices.append(int(value))
        reveal_indices.sort()
    cap_during_reveals=argument("--reveal-cap")=="on"
    output_directory="res://.captures/atlas-publication"+("-cap" if cap_during_reveals else "")+"/"+run_label
    DirAccess.make_dir_recursive_absolute(output_directory)
    ProjectSettings.set_setting("source_data/encounter_cache_mib",0)
    var scene=Player.instantiate();scene.timeline.paused=true
    if not reference.is_empty():
        var selected=preload("res://tests/atlas_reference.gd").instantiate(reference)
        if selected==null:
            check(false,"Reference atlas script loads: "+reference);scene.free();finish_report();return
        scene.native_light_atlas=selected
    root.add_child(scene)
    # _ready reads local settings, so override only this scene immediately after
    # attachment. The two separate runs use these same deterministic controls.
    scene.character_light_profile="reference"
    scene.fire_light_flicker=false;scene.source_lighting.fire_light_flicker=false
    scene.set_light_strength(1.0,false)
    scene.source_depth=true;scene.source_normals=true
    scene.grid_visible=false;scene.hud.hide();scene.camera.size=8.137
    scene.initial_focus=true;scene.camera_focus=Vector3(4,0,5);scene.position_camera()
    apply_mode(scene,"solid",cap_during_reveals,false)
    var deadline=Time.get_ticks_msec()+600000
    while (not scene.session.recording_ready or not scene._media_ready({}) or scene.world_revision<0) and scene.session.issue.is_empty() and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline:
        await process_frame
    check(scene.session.recording_ready and scene.media_initial_ready and scene.world_revision>=0,"Immutable recording initializes exact visible sources")
    if not failures.is_empty():
        scene.queue_free();await process_frame;finish_report();return
    await scene.presentation_updated
    var previous=disclosed(scene)
    var generation:int=scene.world_generation
    var reveal=0
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
                if reveal in reveal_indices:
                    await save_first_draw(scene,"reveal-%03d"%reveal,{"new_tiles":new_tiles,"new_objects":new_objects})
                    scene.set_process(true)
            previous=current;generation=scene.world_generation
    check(scene.session.terminal and not scene.timeline.busy() and scene.timeline.sequence==scene.session.latest_sequence,"Recording drains every authoritative operation")
    check(scene.timeline.state==scene.session.journal.state,"Final displayed state equals the recording's canonical reduction")
    for selected in reveal_indices:check(selected<=reveal,"Requested newly disclosed publication exists: "+str(selected))
    if not failures.is_empty():
        scene.queue_free();await process_frame;finish_report();return
    scene.session.close();scene.timeline.paused=true
    var canonical=scene.timeline.state.duplicate(true)
    var final_clock:float=scene.timeline.display_ms
    if not scene.actor_rows.is_empty():scene.camera_focus=scene.Placement.contact(scene.actor_rows[0])
    scene.position_camera()
    for quarter in 4:
        scene.set_process(true);scene.request_view(quarter)
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
    scene.queue_free();await process_frame;await process_frame
    finish_report()

func finish_report()->void:
    var report={"run":run_label,"checks":checks,"failures":failures,"recording":argument("--recording"),
        "reference_atlas":argument("--reference-atlas"),"selected_reveals":reveal_indices,"captures":publication_captures,
        "rotation_failures":rotation_failures,
        "renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),
        "scope":"Same immutable recording and1000ms manual timeline requests, paused between requests; no empty-queue clock advances. Selected first-disclosure native frames and24 final captures: four quarters, three wall modes, cap/Normals beauty roundtrip. Fixed source profile/strength and static fire. Cross-run exact pixels and matching clock/source receipts must be compared externally; this report alone does not assert reference/current equality. No timing claim."}
    FileAccess.open(output_directory+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_ATLAS_PUBLICATION ",JSON.stringify({"run":run_label,"checks":checks,"failures":failures,"captures":publication_captures.size()}))
    quit(0 if failures.is_empty() else 1)
