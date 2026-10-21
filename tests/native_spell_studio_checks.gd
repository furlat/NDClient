extends SceneTree
## Actual Studio controls and independent replay hosts, using a real journal.
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Studio=preload("res://studio/studio.gd")
var checks:=0
var failures:Array=[]
var observations:Array=[]
var studio:Control

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("NATIVE_STUDIO_FAIL ",label)
func settle()->bool:
    var deadline=Time.get_ticks_msec()+120000
    while Time.get_ticks_msec()<deadline:
        if not studio.index.is_empty() and studio.loader==null and studio.seeker==null and not studio.installing and studio.requested_seek<0 and studio.pending_directory.is_empty() and studio.world.playback_prepared():
            await RenderingServer.frame_post_draw
            if studio.seeker==null and not studio.installing and studio.requested_seek<0 and studio.pending_directory.is_empty() and studio.world.playback_prepared():return true
        await process_frame
    check(false,"Actual Studio seek/prepare completes within finite budget")
    return false
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    DisplayServer.window_set_size(Vector2i(1280,720))
    studio=Studio.new();root.add_child(studio)
    var directory:String=Fixtures.journal("fireball")
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--recording="):directory=argument.trim_prefix("--recording=")
    studio._select_browser_path(directory);studio._load(directory)
    if not await settle():await finish();return
    check(studio.index.directory==directory,"Actual Studio test displays the exact requested original journal")
    var phases:Array=studio.index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("native_spell",false))
    check(not phases.is_empty(),"Real recording exposes native phase rows")
    if phases.is_empty():await finish();return
    var flights:Array=phases.filter(func(row):return row.component.native_cue.role=="flight")
    check(not flights.is_empty(),"Actual selected original includes a native flight phase")
    if flights.is_empty():await finish();return
    var flight:Dictionary=flights[0]
    # These are actual derived rows from this original, not another presenter
    # or synthetic Light/Material proxy. The UI target must be their source ID.
    for kind in ["native_light","native_material"]:
        var channels:Array=studio.index.rows.filter(func(row):return row.kind==kind)
        check(not channels.is_empty(),"Actual Fireball original exposes its "+kind+" inspection channels")
        for channel in channels:
            var parent:String=str(channel.component.parent_id)
            var parents:Array=studio.index.rows.filter(func(row):return row.get("component",{}).get("id")==parent and row.kind in ["native_effect","material_flash"])
            var expected_kind:String="native_effect" if kind=="native_light" else "material_flash"
            check(parents.size()==1 and parents[0].kind==expected_kind \
                and (parents[0].component.get("native_spell",false) if kind=="native_light" else parents[0].component.has("native_hit") \
                    and parents[0].component.actor_uuid==channel.component.actor_uuid),"Derived inspection channel belongs to its actual native source/recipient presenter: "+kind)
            studio.selected_row=channel
            check(studio._diagnostic_id()==parent and parent!=channel.component.id,"Derived menu targets its source presenter: "+kind)
            studio._menu_selected(7)
            check(studio.world.presentation_mutes.has(parent) and not studio.world.presentation_mutes.has(channel.component.id),"Derived mute addresses the existing source draw: "+kind)
            studio._menu_selected(7)
    check(studio.world.presentation_mutes.is_empty(),"Channel target controls restore the unchanged diagnostic state")
    var at:float=flight.start_ms+(flight.component.native_cue.launch+flight.component.native_cue.contact)*500.0
    studio._seek(at)
    if not await settle():await finish();return
    check(studio.world.component_renderer.native_spells.handles.has(flight.component.id),"Studio seek uses the production native occurrence")
    check(studio.world.presentation_errors.is_empty(),"Studio native frame has no presentation errors")
    studio._select_row(flight)
    check(studio.selected_row.id==flight.id,"Selecting the phase retains its source and timing")
    studio.tracks.reveal(flight.id)
    var preview_deadline=Time.get_ticks_msec()+120000
    var previews:Dictionary=studio.tracks.prepare_visible(true)
    while previews.pending>0 and Time.get_ticks_msec()<preview_deadline:
        await process_frame
        previews=studio.tracks.prepare_visible(true)
    check(previews.pending==0 and previews.errors.is_empty(),"Revealed native phase publishes its actual timeline previews: "+str(previews.errors))
    var before:bool=studio.world.native_spell_hit_material
    studio._menu_selected(12)
    check(studio.world.native_spell_hit_material!=before,"Studio Inspect changes the actual hit-material choice")
    check(studio.replay_diagnostics().panes.size()==1,"Studio renders only the selected recorded faction")
    studio._menu_selected(12)
    observations.append({"phase_count":phases.size(),"light_channels":studio.index.rows.filter(func(row):return row.kind=="native_light").size(),"paired":false,"at_ms":at,"visible_source_previews":studio.tracks.preview_demand.size()})
    DirAccess.make_dir_recursive_absolute("res://.captures/native-spell-studio")
    await process_frame;await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.captures/native-spell-studio/actual-studio.png")
    studio._seek(0)
    if await settle():check(studio.world.component_renderer.native_spells.groups.is_empty(),"Studio reverse seek retires the active phase pass")
    studio._seek(at)
    if await settle():check(studio.world.component_renderer.native_spells.handles.has(flight.component.id),"Repeated Studio seek reconstructs the same real occurrence")
    await finish()
func finish()->void:
    studio.queue_free();await process_frame;await process_frame;await RenderingServer.frame_post_draw
    var report={"checks":checks,"failures":failures,"observations":observations,"scope":"Actual Studio recorded-event controls, native occurrence seek/reseek, hit choice, and independent pane owners when present. Native phase/source pixels have separate tests."}
    FileAccess.open("res://.runtime/native-spell-studio-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_SPELL_STUDIO ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
