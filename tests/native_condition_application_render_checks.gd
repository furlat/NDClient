extends "res://tests/native_vampiric_touch_render_checks.gd"
## Exact finite application through the actual size-owner recordings. This
## changes no body scale or package marker art and asserts no visual approval.
const MEDIA=preload("res://studio/recording_media.gd")
const PREPARED=preload("res://tests/dynamic_weapon_support.gd")
const JOURNAL=preload("res://sdk/journal.gd")
const CONDITIONS=preload("res://presentation/conditions.gd")
const CASES_PATH="res://tests/fixtures/schema16/body-scale/cases.json"
const OUTPUT_PATH="res://.runtime/native-condition-application"
const CONDITION_ID="condition.spell.enlarge_reduce"
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    Effects.set_requested("native")
    DirAccess.make_dir_recursive_absolute(OUTPUT_PATH)
    var cases:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CASES_PATH))
    for case in cases.cases:
        var mode:String="reduce" if case.id.ends_with("reduce_lifecycle") else "enlarge"
        for view in case.perspectives:await actual(view,mode)
    var result:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual Enlarge/Reduce applications in both original faction recordings: finite native ground source/direction, one selected owner and unchanged size operation, pixels, source retirement, canonical seek/loop and cleanup. No extra art, performance or visual-approval claim."}
    FileAccess.open(OUTPUT_PATH+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("NATIVE_CONDITION_APPLICATIONS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
func actual(perspective:Dictionary,mode:String)->void:
    var label:String=mode+"-"+str(perspective.id)
    var expected:RefCounted=JOURNAL.new();var opened:Dictionary=expected.open(perspective.journal,true,true)
    var index:Dictionary=Recording.read(perspective.journal)
    check(opened.ok and index.ok,label+": actual original and production index open")
    if not opened.ok or not index.ok:return
    var immutable:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
    index.media_preload=MEDIA.plan(index)
    var rows:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("condition",{}).get("behavior_id")==CONDITION_ID and row.component.get("condition_authored",false))
    check(not rows.is_empty(),label+": actual application has a native source track")
    if rows.is_empty():return
    var row:Dictionary=rows[0];var owner:Dictionary=row.owner;var component:Dictionary=row.component
    var at:float=owner.start_ms+240.0
    var viewport:=SubViewport.new();viewport.size=Vector2i(800,600);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
    var world=Play.new();world.external_playback=true;world.external_clock=true;world.media_warmup.budget_bytes=0
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.media_warmup.encounter_override=index.media_preload
    world.playback_end_ms=index.presentation_end_ms;world.component_renderer.audio.set_enabled(false);viewport.add_child(world)
    world.install_playback(Recording.restore(index,at))
    var ready:bool=await PREPARED.settle(self,world,[component.id])
    check(ready,label+": actual finite source and required original media prepare")
    if not ready:viewport.queue_free();await frame();return
    world.camera_focus=Play.Placement.contact(world.visual_actors[owner.actor_uuid].row);world.initial_focus=true;world.camera.size=3
    world.position_camera();world.grid_visible=false;world.wall_mode="hidden";world.update_wall_visibility();await frame();await frame()
    var native:RefCounted=world.component_renderer.native_spells;var handle:Dictionary=native.handles[component.id]
    var source:Node=handle.inner.components.application
    var observation:Dictionary=source.capture_observation()
    check(observation.direction==(-1.0 if mode=="reduce" else 1.0) and observation.selected_native_ground_layers==2 and not observation.applies_size_change and not observation.enclosing_geometry,label+": exact native program retains its two original ground layers and actual direction")
    check(handle.component.condition_uuid==owner.id and handle.component.start_ms==owner.start_ms and is_equal_approx(handle.component.duration_ms,720.0) and is_equal_approx(source.materials[0].get_shader_parameter("application_clock"),.24),label+": private finite source samples actual owner age, not a held review pose")
    check(is_equal_approx(CONDITIONS.material(owner.actor_uuid,world.timeline.component_samples(index.cache)).body_scale.factor,.75 if mode=="reduce" else 1.175),label+": existing physical size applies once alongside the finite source")
    world.set_process(false);await frame();await frame()
    var canonical:PackedByteArray=var_to_bytes(world.timeline.state)
    var shown:Image=viewport.get_texture().get_image();handle.root.hide();await frame();await frame()
    var hidden:Image=viewport.get_texture().get_image();var count:int=changed(shown,hidden)
    check(count>0,label+": actual selected source contributes native framebuffer pixels")
    check(var_to_bytes(world.timeline.state)==canonical,label+": optical source control cannot alter actual membership")
    shown.save_png(OUTPUT_PATH+"/"+label+"-present.png");hidden.save_png(OUTPUT_PATH+"/"+label+"-hidden.png")
    var previous:WeakRef=weakref(handle.root);world.set_process(true)
    world.install_playback(Recording.restore(index,owner.start_ms+800.0))
    if await settle(world):check(world.timeline.condition_owners.has(owner.id) and not native.handles.has(component.id),label+": finite source ends while its actual condition continues")
    world.install_playback(Recording.restore(index,maxf(0.0,owner.start_ms-.01)))
    if await settle(world):check(not world.timeline.condition_owners.has(owner.id) and not native.handles.has(component.id),label+": reverse seek cannot manufacture an application before admission")
    world.install_playback(Recording.restore(index,at))
    if await settle(world,component.id):
        check(previous.get_ref()==null and native.handles[component.id].component.condition_uuid==owner.id,label+": loop reconstructs the same actual UUID with a fresh private source")
        check(is_equal_approx(native.handles[component.id].inner.components.application.materials[0].get_shader_parameter("application_clock"),.24),label+": loop restores the exact finite clock")
    world.install_playback(Recording.restore(index,index.presentation_end_ms))
    if await settle(world):check(world.timeline.state==expected.state and not native.handles.has(component.id),label+": original removal and independent canonical endpoint are preserved")
    check(var_to_bytes([index.initialization,index.groups,index.rows])==immutable and world.presentation_errors.is_empty() and world.media_issue.is_empty(),label+": original immutable evidence is intact and no production source error")
    evidence.append({"mode":mode,"seat":perspective.id,"condition_uuid":owner.id,"source":component.native_clip.id,"source_age_seconds":.24,"changed_pixels":count})
    native.close(world);check(native.handles.is_empty() and native.groups.is_empty(),label+": private source ownership closes")
    viewport.queue_free();await frame();await frame()
