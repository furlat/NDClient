extends SceneTree
## Lawful level10 Sunder action and actual applied results, production renderer.
const Recording=preload("res://studio/recording.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Play=preload("res://play.gd")
const Effects=preload("res://presentation/effect_package.gd")
const ID="action.class.cleric.divine_intervention.sunder_heretical"
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("OBSERVED_DAMAGE_RENDER_FAIL ",label)
func frame()->void:
    await process_frame
    await RenderingServer.frame_post_draw
func settle(world:Node)->bool:
    var deadline:int=Time.get_ticks_msec()+45000
    while Time.get_ticks_msec()<deadline and not world.publication_failed and world.presentation_errors.is_empty() and world.media_issue.is_empty():
        if world.playback_prepared():
            await frame()
            if world.playback_prepared():return true
        await frame()
    check(false,"Native playback prepares: "+str({"errors":world.presentation_errors,"media":world.media_issue,"native":world.component_renderer.native_spells.diagnostics}))
    return false
func changed(a:Image,b:Image)->int:
    var count:int=0
    a=a.duplicate();b=b.duplicate()
    a.convert(Image.FORMAT_RGBA8);b.convert(Image.FORMAT_RGBA8)
    var left:PackedByteArray=a.get_data();var right:PackedByteArray=b.get_data()
    for pixel in a.get_width()*a.get_height():
        var offset:int=pixel*4
        if absi(int(left[offset])-int(right[offset]))+absi(int(left[offset+1])-int(right[offset+1]))+absi(int(left[offset+2])-int(right[offset+2]))>3:count+=1
    return count
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    var cache:Dictionary={}
    var index:Dictionary=Recording.read(Fixtures.journal("divine-sunder","party"),{},{},cache)
    check(index.ok,"Actual single-party lawful level10 recording compiles")
    if not index.ok:finish();return
    var receivers:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_input_evidence",{}).get("outcome")=="damage" and row.component.get("ability_id")==ID)
    check(not receivers.is_empty(),"Actual Sunder action has independently owned positive-damage receivers")
    check(receivers.all(func(row):return row.component.status=="available"),"Every observed damage receiver has its actual construction inputs")
    if receivers.is_empty() or not failures.is_empty():finish();return
    var view:SubViewport=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.media_warmup.budget_bytes=0
    world.playback_end_ms=index.presentation_end_ms;world.component_renderer.audio.set_enabled(false)
    view.add_child(world)
    var at:float=float(receivers[0].start_ms)+minf(180.0,(float(receivers[0].end_ms)-float(receivers[0].start_ms))*.35)
    world.install_playback(Recording.restore(index,at))
    if not await settle(world):view.queue_free();await frame();finish();return
    var first:Dictionary=receivers[0].component
    world.camera_focus=Play.Placement.contact({"position":first.to_position,"base_height_steps":float(first.get("to_elevation_feet",0.0))/5.0})
    world.camera.size=7;world.initial_focus=true;world.position_camera();world.grid_visible=false
    var native=world.component_renderer.native_spells
    var canonical:PackedByteArray=var_to_bytes(world.timeline.state)
    var handles:Array=[]
    for row in receivers:
        if not native.handles.has(row.component.id):continue
        var handle:Dictionary=native.handles[row.component.id]
        var recipients:Array=handle.occurrence.input_receivers.get("set_event_input",[])
        check(recipients.size()==1,"Each result owns one actual native receiving program")
        for program in recipients:
            var observed:Dictionary=program.capture_observation()
            check(observed.divine_study.phase_admitted and observed.divine_study.actual_damage==row.component.native_inputs.event_input.actual_damage,"Source admits exact observed positive damage rather than its review fixture")
            check(program.settings.source_entity_uuid==row.component.actor_uuid and program.settings.recipient_entity_uuid==row.component.target_uuid,"Constructor binds the original source/recipient")
            check(program.event_input.damage_component_uuid==row.component.native_input_evidence.result_occurrence,"Source result identity retains the real native occurrence")
            evidence.append({"target":row.component.target_uuid,"event":program.event_input.duplicate(true),"observation":observed.divine_study})
        handles.append(handle)
    check(handles.size()==receivers.size(),"All actual damage results have prepared source owners")
    await frame();await frame()
    world.set_process(false)
    var present:Image=view.get_texture().get_image()
    for handle in handles:Effects.hide(handle)
    await frame();await frame()
    var absent:Image=view.get_texture().get_image()
    var pixels:int=changed(present,absent)
    check(pixels>0,"Actual receiving programs contribute native framebuffer pixels")
    for handle in handles:handle.root.show()
    for quarter in 4:
        world.set_process(true);world.request_view(quarter)
        var deadline:int=Time.get_ticks_msec()+45000
        while world.rotation_pending() and Time.get_ticks_msec()<deadline:await frame()
        check(world.quarter==quarter and not world.rotation_pending(),"Prepared camera quarter publishes: "+str(quarter))
        if not await settle(world):break
        check(var_to_bytes(world.timeline.state)==canonical,"Rotation changes no canonical result or lifetime")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),"Native result playback has no presentation/resource errors")
    evidence.append({"changed_pixels":pixels,"receivers":receivers.size(),"faction":"party"})
    view.queue_free();await frame();await frame();finish()
func finish()->void:
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Actual lawful single-party Sunder recording, native result ownership/setter/source pixels/four camera views; no two-seat, passive/rider or visual approval claim."}
    FileAccess.open("res://.runtime/native-observed-damage-render-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("OBSERVED_DAMAGE_RENDER ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
