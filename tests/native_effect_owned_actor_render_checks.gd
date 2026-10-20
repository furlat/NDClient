extends "res://tests/native_vampiric_touch_render_checks.gd"
## Existing prepared native body, actual actor/condition ownership. This
## original has no sphere movement, Ram or authoritative terminal event.
const MEDIA=preload("res://studio/recording_media.gd")
const PREPARED=preload("res://tests/dynamic_weapon_support.gd")
const JOURNAL=preload("res://sdk/journal.gd")
const ROOT_PATH="res://tests/fixtures/schema16/effect-owned-actors/flaming-sphere"
const OUTPUT_PATH="res://.runtime/native-effect-owned-actor"
const ACTOR="f0dcbb26-c72b-4d7b-b8bd-2a87bc4ceff3"
const OWNER="83713b60-58b4-4e52-aa8c-5091374bd98f"
const SPATIAL="202889e7-0b76-491a-bbdf-6645cadbc624"
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute(OUTPUT_PATH)
    for seat in ["amber","blue"]:await actual_body(seat)
    var result:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Both original FlamingSphere birth/held aura streams: existing source-selected native body without2Dproxy, exact canonical ground/owner/clock, pixels all4views, independent spatial aura, canonical seek/loop and private cleanup. No actual movement/Ram/terminal, performance or visual approval claim."}
    FileAccess.open(OUTPUT_PATH+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("NATIVE_EFFECT_OWNED_ACTORS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
func actual_body(seat:String)->void:
    var directory:String=ROOT_PATH.path_join(seat)
    var journal:RefCounted=JOURNAL.new();var opened:Dictionary=journal.open(directory,true,true)
    var index:Dictionary=Recording.read(directory)
    check(opened.ok and index.ok,seat+": actual independent original and production index open")
    if not opened.ok or not index.ok:return
    var immutable:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
    var rows:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("lifecycle_key")=="condition_flaming_sphere_persistent")
    check(not rows.is_empty(),seat+": actual aura membership owns a source body track")
    if rows.is_empty():return
    var owner:Dictionary=rows[0].owner;var component:Dictionary=rows[0].component
    var at:float=owner.start_ms+800.0
    index.media_preload=MEDIA.plan(index)
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true;world.media_warmup.budget_bytes=0
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.media_warmup.encounter_override=index.media_preload
    world.native_startup_plan=Play.NativeStartup.recording_plan(index.rows)
    world.playback_end_ms=maxf(index.presentation_end_ms,at+1000.0);world.component_renderer.audio.set_enabled(false);view.add_child(world)
    world.install_playback(Recording.restore(index,at))
    var ready:bool=await PREPARED.settle(self,world,[component.id])
    check(ready,seat+": actual native body/source and ordinary media closure prepare")
    if not ready:view.queue_free();await frame();return
    var native:RefCounted=world.component_renderer.native_spells;var handle:Dictionary=native.handles[component.id]
    check(not world.visual_actors.has(ACTOR) and handle.component.actor_uuid==ACTOR and handle.component.condition_uuid==OWNER and handle.component.native_body_owner,seat+": actual effect-owned actor needs no fabricated modular sprite/body")
    check(handle.endpoints.effect_owned_ground.actor_uuid==ACTOR and handle.endpoints.ground==Vector3(6,0,7) and handle.lifecycle_phase=="sustain",seat+": exact source ground/UUID and actual owner age register")
    check(handle.occurrence.parameters.scene=="res://assets/vfx/conditions/condition_flaming_sphere_persistent/prepared.scn" and handle.occurrence.handle.geometry.size()==13,seat+": original supplied13layer prepared native body is unchanged")
    var bindings:Dictionary=native.diagnostics[component.id].input_bindings
    check(bindings.unavailable.is_empty() and "owner_state" in bindings.supplied and "root_path" in bindings.supplied and "body_state" not in bindings.supplied,seat+": actual prepared lifecycle uses only its own public owner/root contract, never a legacy fixture packet")
    check(world.timeline.state.senses.spatial_effects.has(SPATIAL) and world.timeline.state.actors[ACTOR].conditions.any(func(member):return member.condition_uuid==OWNER),seat+": independent spatial aura and actual body condition remain separate")
    world.camera_focus=Vector3(6,0,7);world.initial_focus=true;world.camera.size=3;world.position_camera()
    world.grid_visible=false;world.wall_mode="hidden";world.update_wall_visibility()
    var previous:WeakRef=weakref(handle.root)
    for quarter in [0,1,2,3]:
        world.request_view(quarter);var deadline:int=Time.get_ticks_msec()+45000
        while world.rotation_pending() and Time.get_ticks_msec()<deadline:await frame()
        check(not world.rotation_pending() and world.world_quarter==quarter,seat+": actual camera view publishes "+str(quarter))
        if not await PREPARED.settle(self,world,[component.id]):break
        check(native.handles[component.id].root==handle.root and handle.endpoints.ground==Vector3(6,0,7),seat+": camera retains same private source and true ground")
        world.set_process(false);await frame();await frame()
        var canonical:PackedByteArray=var_to_bytes(world.timeline.state)
        var shown:Image=view.get_texture().get_image();handle.root.hide();await frame();await frame()
        var hidden:Image=view.get_texture().get_image();var count:int=changed(shown,hidden)
        check(count>0,seat+": actual native sphere body contributes pixels in view "+str(quarter))
        check(var_to_bytes(world.timeline.state)==canonical and is_equal_approx(handle.owner_state.owner_age_seconds,.8),seat+": visual probe preserves canonical state and private owner time")
        shown.save_png(OUTPUT_PATH+"/"+seat+"-q"+str(quarter)+"-present.png");hidden.save_png(OUTPUT_PATH+"/"+seat+"-q"+str(quarter)+"-hidden.png")
        evidence.append({"seat":seat,"quarter":quarter,"actor_uuid":ACTOR,"condition_uuid":OWNER,"spatial_uuid":SPATIAL,"source":handle.clip.id,"source_age_seconds":handle.owner_state.owner_age_seconds,"changed_pixels":count})
        handle.root.show();world.set_process(true)
    world.install_playback(Recording.restore(index,maxf(0.0,owner.start_ms-.01)))
    if await settle(world):
        var prepared:Dictionary=native.handles.get(component.id,{})
        check(not world.timeline.condition_owners.has(OWNER) \
            and not world.displayed_components.any(func(sample):return sample.id==component.id) \
            and (prepared.is_empty() or not prepared.root.is_visible_in_tree()) \
            and not native.witnesses.any(func(witness):return witness.id==component.id),seat+": reverse seek cannot display or draw a future native body; hidden preparation is allowed")
    world.install_playback(Recording.restore(index,at))
    if await settle(world,component.id):check(previous.get_ref()==null and native.handles[component.id].component.condition_uuid==OWNER,seat+": loop frees old private body and restores the same actual owner")
    world.install_playback(Recording.restore(index,index.presentation_end_ms+1000.0))
    if await settle(world):check(world.timeline.state==journal.state and world.timeline.condition_owners.has(OWNER),seat+": independent final canonical owner remains admitted; no terminal is invented")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty() and var_to_bytes([index.initialization,index.groups,index.rows])==immutable,seat+": no source errors or immutable original mutation")
    native.close(world);check(native.handles.is_empty() and native.groups.is_empty(),seat+": private native body owners close")
    view.queue_free();await frame();await frame()
