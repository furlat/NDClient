extends "res://tests/native_vampiric_touch_render_checks.gd"
const MEDIA=preload("res://studio/recording_media.gd")
const PREPARED=preload("res://tests/dynamic_weapon_support.gd")
const JOURNAL=preload("res://sdk/journal.gd")
const ROOT_PATH="res://tests/fixtures/schema16/scenarios/goodberry-consume"
const OUTPUT_PATH="res://.runtime/native-goodberry-consumption"
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute(OUTPUT_PATH)
    for seat in ["amber","blue"]:await actual_consumer(seat)
    var result={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Three actual accepted berry consumptions with exact disclosed charge identities and healing admission; ordinary Play/Studio source pixels, four views, finite seek/loop, canonical endpoint and cleanup. Peer item omission stays missing. No eating body-pose or art-approval claim."}
    FileAccess.open(OUTPUT_PATH+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("NATIVE_GOODBERRY_CONSUMPTION ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
func actual_consumer(seat:String)->void:
    var directory:String=ROOT_PATH.path_join(seat)
    var index:Dictionary=Recording.read(directory);var journal:RefCounted=JOURNAL.new();var opened:Dictionary=journal.open(directory,true)
    check(opened.ok and index.ok,seat+": actual originals independently fold and compile")
    if not opened.ok or not index.ok:return
    var immutable:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows]);index.media_preload=MEDIA.plan(index)
    var rows:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("native_cue",{}).get("constructor_input",{}).get("kind")=="item_consumption")
    check(rows.size()==3,seat+": actual accepted actions retain all three consume outcomes")
    if rows.size()!=3:return
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true;world.media_warmup.budget_bytes=0
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.media_warmup.encounter_override=index.media_preload
    world.playback_end_ms=index.presentation_end_ms;world.component_renderer.audio.set_enabled(false);view.add_child(world)
    var native:RefCounted=world.component_renderer.native_spells
    for row in rows:
        var component:Dictionary=row.component;var at:float=row.start_ms+250.0
        world.install_playback(Recording.restore(index,at))
        var ready:bool=await PREPARED.settle(self,world,[] if seat=="blue" else [component.id])
        check(ready,seat+": actual published consume cut prepares")
        if not ready:break
        if seat=="blue":
            check(component.status=="missing" and not native.handles.has(component.id),seat+": undisclosed exact item never constructs a fixture/proxy source")
            continue
        var handle:Dictionary=native.handles[component.id];var program:Node=handle.inner.components.nature
        var private:WeakRef=weakref(handle.root)
        check(program.specification.item_uuids==[component.native_constructor_evidence.item_uuid] \
            and program.specification.healing_admitted==(not component.native_constructor_evidence.was_blocked),seat+": exact consumed item and positive/blocked heal reach the native source")
        check(program.endpoints.size()==2 and program.endpoints.all(func(endpoint):return endpoint.actor_uuid==component.actor_uuid) \
            and program.endpoints[0].socket=="hand" and program.endpoints[1].socket=="face",seat+": actual consumer hand-to-face endpoints are supplied")
        check(not program.capture_observation().creates_light and program.petals.all(func(petal):return not petal.visible),seat+": early hand phase adds no light or premature healing petals")
        for quarter in 4:
            if world.quarter!=quarter:world.request_view(quarter)
            var deadline:int=Time.get_ticks_msec()+15000
            while world.rotation_pending() and Time.get_ticks_msec()<deadline:await frame()
            check(not world.rotation_pending(),seat+": requested view publishes")
            if not await PREPARED.settle(self,world,[component.id]):check(false,seat+": actual rotated source ready");break
            world.camera_focus=Play.Placement.contact(world.visual_actors[component.actor_uuid].row);world.initial_focus=true;world.camera.size=2.8
            world.position_camera();world.grid_visible=false;world.wall_mode="hidden";world.update_wall_visibility();await frame();await frame();world.set_process(false)
            var shown:Image=view.get_texture().get_image();handle.root.hide();await frame();await frame()
            var pixels:int=changed(shown,view.get_texture().get_image())
            check(pixels>0,seat+": consumed berry contributes native pixels in view "+str(quarter))
            evidence.append({"seat":seat,"quarter":quarter,"at_ms":at,"item_uuid":component.native_constructor_evidence.item_uuid,"healing_admitted":program.specification.healing_admitted,"changed_pixels":pixels})
            handle.root.show();world.set_process(true)
        world.install_playback(Recording.restore(index,row.start_ms+650.0))
        var late_ready:bool=await PREPARED.settle(self,world,[component.id])
        check(late_ready,seat+": late healing phase actually prepares")
        if late_ready:
            var actual:Node=native.handles[component.id].inner.components.nature
            check(actual.petals.any(func(petal):return petal.visible)==actual.specification.healing_admitted,seat+": actual heal admission alone selects late healing petals")
        world.install_playback(Recording.restore(index,maxf(0.0,row.start_ms-.01)))
        if await settle(world):check(not native.handles.has(component.id) or not native.handles[component.id].root.visible,seat+": rewind before actual action has no future consume draw")
        world.install_playback(Recording.restore(index,at))
        var loop_ready:bool=await PREPARED.settle(self,world,[component.id])
        check(loop_ready,seat+": looped source actually prepares")
        if loop_ready:check(private.get_ref()==null and is_equal_approx(native.handles[component.id].inner.components.nature.current_seconds,.25),seat+": loop frees old source and restores exact source time")
    world.install_playback(Recording.restore(index,index.presentation_end_ms+1.0))
    if await settle(world):check(world.timeline.state==journal.snapshot(),seat+": full canonical end equals independent original reducer")
    check(var_to_bytes([index.initialization,index.groups,index.rows])==immutable and world.presentation_errors.is_empty() and world.media_issue.is_empty(),seat+": immutable facts and error-free renderer retained")
    native.close(world);check(native.handles.is_empty() and native.groups.is_empty(),seat+": private sources close")
    view.queue_free();await frame();await frame()
