extends "res://tests/native_vampiric_touch_render_checks.gd"
## Same condition provider as Play/Studio, real affected staff and replacement.
const MEDIA=preload("res://studio/recording_media.gd")
const PREPARED=preload("res://tests/dynamic_weapon_support.gd")
const JOURNAL=preload("res://sdk/journal.gd")
const ROOT_PATH="res://tests/fixtures/schema16/scenarios/shillelagh-equipped-move"
const OUTPUT_PATH="res://.runtime/native-shillelagh"
const ACTOR="31b677d0-3152-4b7e-ba79-ac54dc3dc142"
const OWNER="041ad6ee-6c00-43ed-97db-3eb4aa6473eb"
const STAFF="902a5b65-aeca-494c-8a0d-ce6c3310a1ee"
const SWORD="b21c7b1e-70e2-4659-89ba-9060f8555ed2"
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute(OUTPUT_PATH)
    for seat in ["amber","blue"]:await actual_staff(seat)
    var result={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Original both-seat Shillelagh exact affected-item application, actual movement/Hit, real condition removal and equipment replacement, four views, source pixels, canonical seek/loop and private cleanup. No new source selection, extra contact, other weapon membership or visual approval."}
    FileAccess.open(OUTPUT_PATH+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("NATIVE_SHILLELAGH ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
func actual_staff(seat:String)->void:
    var directory:String=ROOT_PATH.path_join(seat)
    var journal:RefCounted=JOURNAL.new();var opened:Dictionary=journal.open(directory,true)
    var index:Dictionary=Recording.read(directory)
    check(opened.ok and index.ok,seat+": original independent canonical fold and production index open")
    if not opened.ok or not index.ok:return
    index.media_preload=MEDIA.plan(index)
    var immutable:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
    var sources:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("condition_uuid")==OWNER)
    check(not sources.is_empty(),seat+": actual affected-item condition has its existing native source")
    if sources.is_empty():return
    var row:Dictionary=sources[0];var component:Dictionary=row.component;var owner:Dictionary=row.owner
    var motions:Array=index.rows.filter(func(value):return value.kind=="body" and value.track.actor_uuid==ACTOR \
        and value.start_ms>=owner.start_ms and value.end_ms<owner.end_ms and value.track.get("trajectory")=="path")
    var hits:Array=index.rows.filter(func(value):return value.kind=="body" and value.track.actor_uuid==ACTOR and value.track.clip.begins_with("Attack") and value.start_ms>=owner.start_ms and value.end_ms<owner.end_ms)
    check(not motions.is_empty() and not hits.is_empty(),seat+": real held movement and accepted staff Hit are recorded")
    if motions.is_empty() or hits.is_empty():return
    var cuts:Array=[{"at":owner.start_ms+300.0,"phase":"application"},
        {"at":lerpf(motions[0].start_ms,motions[0].end_ms,.5),"phase":"movement"},
        {"at":lerpf(hits[0].start_ms,hits[0].end_ms,.5),"phase":"accepted_hit"}]
    for quarter in 4:
        var label:String=seat+"-q"+str(quarter)
        var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true
        view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
        var world=Play.new();world.external_playback=true;world.external_clock=true;world.quarter=quarter
        world.media_warmup.budget_bytes=0;world.catalog_cache=Play.Catalog.source_snapshot(index.cache)
        world.media_warmup.encounter_override=index.media_preload;world.playback_end_ms=index.presentation_end_ms
        world.component_renderer.audio.set_enabled(false);view.add_child(world)
        var native:RefCounted=world.component_renderer.native_spells;var previous:WeakRef
        for cut in cuts:
            world.install_playback(Recording.restore(index,cut.at))
            var ready:bool=await PREPARED.settle(self,world,[component.id])
            check(ready,label+": real current source prepares at "+cut.phase)
            if not ready:break
            if previous!=null:check(previous.get_ref()==null,label+": seek releases the preceding private source")
            var handle:Dictionary=native.handles[component.id];previous=weakref(handle.root)
            var receiving:RefCounted=handle.occurrence.receiving
            check(receiving.admitted_geometry and receiving.weapon_binding.item_uuid==STAFF \
                and receiving.weapon_binding.effect_uuid==OWNER and receiving.weapon_binding.holder_uuid==ACTOR \
                and handle.component.condition.state.affected_item_uuid==STAFF,label+": actual condition coats only its disclosed affected staff")
            check(world.visual_actors[ACTOR].entries.any(func(entry):return entry.actor_layer.get("item_uuid")==STAFF and entry.node.is_visible_in_tree()),label+": original modular staff remains the receiving body")
            check(handle.component.start_ms==owner.start_ms and world.timeline.state==Recording.restore(index,cut.at).state,label+": source time and canonical prefix match the original")
            world.camera_focus=Play.Placement.contact(world.visual_actors[ACTOR].row);world.initial_focus=true;world.camera.size=3
            world.position_camera();world.grid_visible=false;world.wall_mode="hidden";world.update_wall_visibility()
            await frame();await frame();world.set_process(false)
            var shown:Image=view.get_texture().get_image();handle.root.hide();await frame();await frame()
            var count:int=changed(shown,view.get_texture().get_image())
            check(count>0,label+": "+cut.phase+" contributes actual native source pixels")
            shown.save_png(OUTPUT_PATH+"/"+label+"-"+cut.phase+".png")
            evidence.append({"seat":seat,"quarter":quarter,"phase":cut.phase,"at_ms":cut.at,"item_uuid":STAFF,"condition_uuid":OWNER,"changed_pixels":count})
            world.set_process(true)
        world.install_playback(Recording.restore(index,index.presentation_end_ms))
        if await settle(world):
            check(world.timeline.state==journal.snapshot() and not native.handles.has(component.id),label+": actual removal ends source and reaches independent canonical end")
            check(world.visual_actors[ACTOR].entries.any(func(entry):return entry.actor_layer.get("item_uuid")==SWORD and entry.node.is_visible_in_tree()),label+": plain replacement sword stays visible without the retired affected-staff effect")
        world.install_playback(Recording.restore(index,0.0))
        if await settle(world):check(not world.timeline.condition_owners.has(OWNER),label+": reverse seek has no future condition")
        world.install_playback(Recording.restore(index,cuts[0].at))
        if await settle(world,component.id):check(native.handles[component.id].component.start_ms==owner.start_ms,label+": loop restores the actual affected-item source clock")
        check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),label+": no source or publication error")
        native.close(world);check(native.handles.is_empty() and native.groups.is_empty(),label+": all private owners close")
        view.queue_free();await frame();await frame()
    check(var_to_bytes([index.initialization,index.groups,index.rows])==immutable,seat+": source facts and recordings remain immutable")
