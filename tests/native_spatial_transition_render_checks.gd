extends "res://tests/native_restoration_owner_checks.gd"
## Genuine partial/full IGNITE; both existing source clips use the same provider.
## Alternate source assignment is private test staging, not production approval.
const Support=preload("res://tests/spatial_transition_support.gd")
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    for seat in ["amber","blue"]:
        for clip in Support.CLIPS:await qualify(seat,clip)
    finish()

func qualify(seat:String,clip:String)->void:
    var cache:Dictionary=Support.source_cache(clip)
    var index:Dictionary=Support.read(Support.BURN,seat,cache)
    check(index.ok,seat+" original Plant Growth interaction compiles for "+clip)
    if not index.ok:return
    var changes:Array=Support.changes(index)
    var partial:Array=changes.filter(func(entry):return entry.row.operation=="footprint_changed" and entry.row.interaction_operation=="ignite")
    var removal:Array=changes.filter(func(entry):return entry.row.operation=="removed" and entry.row.interaction_operation=="ignite")
    check(partial.size()==1 and removal.size()==1,seat+" original has one partial and one full native IGNITE")
    if partial.size()!=1 or removal.size()!=1:return
    var identity:String=partial[0].row.spatial_effect_uuid
    check(identity==removal[0].row.spatial_effect_uuid and partial[0].row.removed_positions.size()==26 and removal[0].row.removed_positions.size()==23,seat+" actual source owner retires26 then23 original cells")
    var media:Dictionary=RecordingMedia.plan(index)
    check(media.errors.is_empty(),seat+" ordinary Studio media closure prepares every immutable group")
    if not media.errors.is_empty():return
    Play.Catalog.adopt_snapshot(index.cache,media.source_files)
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true
    world.media_warmup.budget_bytes=0;world.media_warmup.encounter_override=media
    world.native_startup_plan=Play.NativeStartup.recording_plan(index.rows)
    world.native_startup_requested_ms=maxf(0.0,float(partial[0].at_ms)-1.0)
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache)
    world.playback_end_ms=index.presentation_end_ms+1500.0;world.component_renderer.audio.set_enabled(false)
    view.add_child(world)
    var before:float=maxf(0.0,float(partial[0].at_ms)-1.0)
    world.install_playback(Recording.restore(index,before))
    if not await settle(world):view.queue_free();await frame();return
    world.camera_focus=Play.Placement.contact({"position":[6,7],"base_height_steps":0.0})
    world.camera.size=11;world.initial_focus=true;world.position_camera();world.grid_visible=false
    var initial:Dictionary=handle(world,identity)
    check(not initial.is_empty(),seat+" exact real field has one prepared native source")
    if initial.is_empty():view.queue_free();await frame();return
    var program:Node=initial.occurrence.input_receivers.set_removed_cells[0]
    check(program.specification.cells.size()==49 and program.specification.observed_removals.is_empty() and program.removal_times.is_empty(),seat+" private constructor has actual topology and no future/review burn")
    var original_source:WeakRef=weakref(program)
    var clock_start:float=float(initial.component.absolute_start_ms)
    for entry in [partial[0],removal[0]]:
        var at:float=float(entry.at_ms)+350.0
        if not await advance(world,at):break
        if not await settle(world):break
        var active:Dictionary=handle(world,identity)
        check(not active.is_empty(),seat+" actual source remains for its own0.70second removal interval")
        if active.is_empty():break
        var sampled:Node=active.occurrence.input_receivers.set_removed_cells[0]
        check(original_source.get_ref()==sampled and active.component.absolute_start_ms==clock_start,seat+" ordinary ordered publication retains the private instance and original application clock")
        check(not active.component.native_cue.has("fade_out_seconds"),seat+" no second generic fade alters the sealed cell dissolve")
        var source_anchor:Array=active.component.position
        for cell in entry.row.removed_positions:
            var local:=Vector2i(cell[0]-source_anchor[0],cell[1]-source_anchor[1])
            check(sampled.removal_times.has(local) and is_equal_approx(float(sampled.removal_times[local]),(float(entry.at_ms)-clock_start)/1000.0),seat+" original native cell records the exact factual owner-relative retirement time")
        check(entry.row.removed_positions.all(func(cell):return cell in active.component.resolved_area_positions),seat+" physical removal tail retains only its observed cells in the optical mask")
        check(is_equal_approx(float(sampled.current_seconds),(at-clock_start)/1000.0),seat+" source sample uses the existing actual owner clock")
        await frame();await frame();world.set_process(false)
        var canonical:PackedByteArray=var_to_bytes(world.timeline.state)
        var present:Image=view.get_texture().get_image()
        Effects.hide(active);await frame();await frame()
        var pixels:int=changed(present,view.get_texture().get_image())
        check(pixels>0,seat+" real constructed vegetation contributes framebuffer pixels during the actual removal tail")
        active.root.show();world.set_process(true)
        check(var_to_bytes(world.timeline.state)==canonical,seat+" source visibility probe changes no canonical cell or transition")
        if entry.row.operation=="footprint_changed":
            var exact_mask:Array=active.component.resolved_area_positions
            var exact_times:Dictionary=sampled.removal_times.duplicate()
            var exact_age:float=sampled.current_seconds
            var original_quarter:int=world.quarter
            for quarter in [0,1,2,3,original_quarter]:
                world.request_view(quarter)
                var deadline:int=Time.get_ticks_msec()+45000
                while world.rotation_pending() and Time.get_ticks_msec()<deadline:await frame()
                check(not world.rotation_pending() and world.quarter==quarter and world.world_quarter==quarter,seat+" requested camera quarter is actually published: "+str(quarter))
                if not await settle(world):break
                var rotated:Dictionary=handle(world,identity)
                check(not rotated.is_empty(),seat+" source owner remains displayed in actual quarter: "+str(quarter))
                if rotated.is_empty():break
                var rotated_program:Node=rotated.occurrence.input_receivers.set_removed_cells[0]
                check(rotated_program==sampled and rotated.component.absolute_start_ms==clock_start \
                    and rotated_program.removal_times==exact_times and is_equal_approx(float(rotated_program.current_seconds),exact_age),seat+" camera rebind preserves the private source, factual retirement times and source clock")
                check(rotated.component.resolved_area_positions==exact_mask and var_to_bytes(world.timeline.state)==canonical,seat+" camera changes neither factual source cells nor its exact tail mask")
                await frame();await frame();world.set_process(false)
                var shown:Image=view.get_texture().get_image();Effects.hide(rotated);await frame();await frame()
                var quarter_pixels:int=changed(shown,view.get_texture().get_image())
                check(quarter_pixels>0,seat+" actual quarter has original native vegetation contribution: "+str(quarter))
                rotated.root.show();world.set_process(true)
                evidence.append({"seat":seat,"clip":clip,"quarter":quarter,"published_quarter":world.world_quarter,
                    "owner_uuid":identity,"source_start_ms":clock_start,"source_seconds":exact_age,"changed_pixels":quarter_pixels})
        evidence.append({"seat":seat,"clip":clip,"owner_uuid":identity,"event_uuid":entry.row.event_uuid,
            "lineage_uuid":entry.row.lineage_uuid,"operation":entry.row.operation,"interaction_operation":entry.row.interaction_operation,
            "physical_at_ms":entry.at_ms,"sample_at_ms":at,"source_start_ms":clock_start,
            "removed_cells":entry.row.removed_positions,"changed_pixels":pixels})
    if await advance(world,float(removal[0].at_ms)+701.0):
        check(not world.timeline.state.senses.spatial_effects.has(identity),seat+" final canonical source owner is already mechanically absent")
        check(world.timeline.component_samples(index.cache).all(func(component):return component.get("spatial_effect_uuid")!=identity),seat+" source-owned tail ends without retained optical components")
    for at in [before,float(partial[0].at_ms)+350.0,float(removal[0].at_ms)+350.0,before]:
        world.install_playback(Recording.restore(index,at))
        if not await settle(world):break
        var restored:Dictionary=handle(world,identity)
        check(not restored.is_empty(),seat+" seek/loop reifies the actual owner inside its original lifetime")
        if restored.is_empty():continue
        var restored_program:Node=restored.occurrence.input_receivers.set_removed_cells[0]
        var expected:int=0 if at==before else (26 if at<float(removal[0].at_ms) else 49)
        check(restored_program.removal_times.size()==expected,seat+" fresh epoch restores only the native retirement prefix, with no stale future cells")
        check(restored.component.absolute_start_ms==clock_start,seat+" seek retains the same original application age")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),seat+" production native playback reports no resource/presentation errors")
    view.queue_free();await frame();await frame()

func handle(world:Node,identity:String)->Dictionary:
    var matches:Array=world.component_renderer.native_spells.handles.values().filter(func(value):
        return value.component.get("spatial_effect_uuid")==identity and value.root.is_visible_in_tree())
    return matches[0] if matches.size()==1 else {}

func finish()->void:
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Original two-seat Plant Growth partial/full IGNITE through ordinary Studio/Play preparation+publication; both supplied vegetation clips test-staged privately, exact local cells/private clock/source-owned0.70s tail/native pixels/seek-loop/teardown. No reactive liquid/contact/topology extension or art approval claim."}
    DirAccess.make_dir_recursive_absolute("res://.runtime/spatial-transitions-20261020")
    FileAccess.open("res://.runtime/spatial-transitions-20261020/native-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_SPATIAL_TRANSITION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
