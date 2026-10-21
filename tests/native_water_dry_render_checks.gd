extends "res://tests/native_vampiric_touch_render_checks.gd"
## Actual DRY source retirement; the genuine original has whole removal only.
const MEDIA=preload("res://studio/recording_media.gd")
const PREPARED=preload("res://tests/dynamic_weapon_support.gd")
const JOURNAL=preload("res://sdk/journal.gd")
const CLOCK=preload("res://presentation/native_spell_playback.gd")
const ROOT_PATH="res://tests/fixtures/schema16/scenarios/water-create-dry"
const OUTPUT_PATH="res://.runtime/native-water-dry"
const WATER="275a5049-1eb3-4e5a-99da-9804772ab69b"
const DESTROY="bg3-36/create-or-destroy-water/destroy"
const CREATE="bg3-36/create-or-destroy-water/create"
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute(OUTPUT_PATH)
    for seat in ["amber","blue"]:await actual_dry(seat)
    var result:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Both independent real13cell whole-DRY streams: existing water before retirement, native finite source identity/geometry/clock/pixels in4views, canonical mechanical absence, exact source ending/seek-loop/private cleanup. No native creation/partial-DRY/topology-extension/performance/art approval claim."}
    FileAccess.open(OUTPUT_PATH+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("NATIVE_WATER_DRY ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
func owned(world:Node,clip:String)->Array:
    return world.component_renderer.native_spells.handles.values().filter(func(handle):return handle.component.get("spatial_effect_uuid")==WATER and handle.component.get("native_clip",{}).get("id")==clip and handle.root.is_visible_in_tree())
func actual_dry(seat:String)->void:
    var directory:String=ROOT_PATH.path_join(seat)
    var journal:RefCounted=JOURNAL.new();var opened:Dictionary=journal.open(directory,true,true)
    var index:Dictionary=Recording.read(directory)
    check(opened.ok and index.ok,seat+": both original reducer and ordinary Studio index open")
    if not opened.ok or not index.ok:return
    var immutable:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
    var rows:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("spatial_removal",false) and row.component.spatial_effect_uuid==WATER)
    check(not rows.is_empty(),seat+": actual DRY row exposes its finite native source")
    if rows.is_empty():return
    var component:Dictionary=rows[0].component;var start:float=component.absolute_start_ms;var at:float=start+350.0
    index.media_preload=MEDIA.plan(index)
    var viewport:=SubViewport.new();viewport.size=Vector2i(800,600);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
    var world=Play.new();world.external_playback=true;world.external_clock=true;world.media_warmup.budget_bytes=0
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.media_warmup.encounter_override=index.media_preload
    world.native_startup_plan=Play.NativeStartup.recording_plan(index.rows)
    world.playback_end_ms=index.presentation_end_ms;world.component_renderer.audio.set_enabled(false);viewport.add_child(world)
    world.install_playback(Recording.restore(index,start-.01))
    if not await settle(world):viewport.queue_free();await frame();return
    check(world.timeline.state.senses.spatial_effects.has(WATER) and owned(world,CREATE).size()==1 and owned(world,DESTROY).is_empty(),seat+": actual pre-cut water has no predicted destruction")
    world.camera_focus=Play.Placement.contact({"position":[6,7],"base_height_steps":0.0});world.initial_focus=true;world.camera.size=7
    world.position_camera();world.grid_visible=false;world.wall_mode="hidden";world.update_wall_visibility()
    var plan:Dictionary={};var deadline:int=Time.get_ticks_msec()+45000
    while world.timeline.display_ms<at-.000001 and Time.get_ticks_msec()<deadline:
        await process_frame
        if not plan.is_empty() and not world.timeline.replay_plan_current(plan):world.timeline.replay_cancel_preparation();plan={}
        if plan.is_empty():plan=world.timeline.replay_plan(at)
        if world.timeline.replay_prepare(plan) and world.can_publish_replay_advance(plan):
            check(world.publish_replay_advance(plan),seat+": real DRY preparation publishes its ordered cut");plan={}
        await RenderingServer.frame_post_draw
        if not world.presentation_errors.is_empty() or not world.media_issue.is_empty():break
    check(is_equal_approx(world.timeline.display_ms,at),seat+": ordinary shared clock reaches actual post-DRY sample "+str({"actual":world.timeline.display_ms,"errors":world.presentation_errors,"media":world.media_issue}))
    if not is_equal_approx(world.timeline.display_ms,at) or not await PREPARED.settle(self,world,[component.id]):viewport.queue_free();await frame();return
    var native:RefCounted=world.component_renderer.native_spells
    var source_handles:Array=owned(world,DESTROY)
    var held:Array=owned(world,CREATE)
    var retirement:Dictionary={"destroy_count":source_handles.size(),"held_count":held.size(),
        "canonical_present":world.timeline.state.senses.spatial_effects.has(WATER),"handles":[]}
    for candidate in native.handles.values():
        if candidate.component.get("spatial_effect_uuid")!=WATER:continue
        retirement.handles.append({"id":candidate.component.id,"clip":candidate.component.get("native_clip",{}).get("id"),
            "root_visible":candidate.root.is_visible_in_tree(),"positions":candidate.component.get("resolved_area_positions",[]),
            "mask_positions":candidate.get("area_mask",{}).get("positions"),"diagnostic":native.diagnostics.get(candidate.component.id,{})})
    check(source_handles.size()==1,seat+": one finite optical retirement: "+str(retirement))
    check(not retirement.canonical_present,seat+": finite optical retirement does not resurrect mechanical water: "+str(retirement))
    check(held.all(func(candidate):return candidate.component.get("resolved_area_positions",[])==[] \
        and candidate.get("area_mask",{}).get("positions")==[]),seat+": retained immutable CREATE draws have no admitted cells after whole DRY: "+str(retirement))
    if source_handles.size()!=1:viewport.queue_free();await frame();return
    # Immutable coverage may remain allocated until this owner's finite close
    # interval ends. Empty admission must contribute no duplicate water pixels.
    world.set_process(false);await frame();await frame()
    var with_retained:Image=viewport.get_texture().get_image()
    for candidate in held:candidate.root.hide()
    await frame();await frame()
    var retained_pixels:int=changed(with_retained,viewport.get_texture().get_image())
    check(retained_pixels==0,seat+": hiding retained zero-cell CREATE draws changes no framebuffer pixels: "+str(retirement))
    for candidate in held:candidate.root.show()
    world.set_process(true)
    evidence.append({"seat":seat,"retirement":retirement,"retained_create_changed_pixels":retained_pixels})
    var handle:Dictionary=source_handles[0];var program:Node=handle.occurrence.input_receivers.set_surface_records[0]
    check(program.prepared and program.specification.form=="destroy" and program.records==handle.component.spatial_surface_records and program.records.all(func(record):return record.source_uuid==WATER),seat+": exact original program was constructed with actual owner/groups")
    check(handle.component.actor_uuid==null and handle.component.target_uuid==null and handle.component.native_constructor_evidence.event_uuid==("102" if seat=="amber" else "106"),seat+": no invented actor or other-seat occurrence ownership")
    check(is_equal_approx(program.last_seconds,CLOCK.source_time(handle.component.native_cue,.35)) and is_equal_approx(program.last_seconds,1.083333333333333),seat+": private source samples the authored clear clock plus actual elapsed retirement")
    var bindings:Dictionary=native.diagnostics[component.id].input_bindings
    check(bindings.unavailable.is_empty() and "surface_records" in bindings.supplied and handle.area_mask.positions==component.resolved_area_positions,seat+": actual immutable source input and exact retired-cell mask are admitted")
    var old:WeakRef=weakref(handle.root)
    for quarter in [0,1,2,3]:
        world.request_view(quarter);deadline=Time.get_ticks_msec()+45000
        while world.rotation_pending() and Time.get_ticks_msec()<deadline:await frame()
        check(not world.rotation_pending() and world.world_quarter==quarter,seat+": actual view publishes "+str(quarter))
        if not await PREPARED.settle(self,world,[component.id]):break
        world.set_process(false);await frame();await frame()
        var canonical:PackedByteArray=var_to_bytes(world.timeline.state)
        var shown:Image=viewport.get_texture().get_image();handle.root.hide();await frame();await frame()
        var hidden:Image=viewport.get_texture().get_image();var count:int=changed(shown,hidden)
        check(count>0,seat+": actual finite DRY source contributes pixels in view "+str(quarter))
        check(var_to_bytes(world.timeline.state)==canonical and is_equal_approx(program.last_seconds,1.083333333333333),seat+": camera/visibility probes preserve canonical absence and actual source age")
        shown.save_png(OUTPUT_PATH+"/"+seat+"-q"+str(quarter)+"-present.png");hidden.save_png(OUTPUT_PATH+"/"+seat+"-q"+str(quarter)+"-hidden.png")
        evidence.append({"seat":seat,"quarter":quarter,"owner_uuid":WATER,"event_uuid":component.source_event_uuid,"removed_positions":component.resolved_area_positions,"source_age_seconds":program.last_seconds,"changed_pixels":count})
        handle.root.show();world.set_process(true)
    world.install_playback(Recording.restore(index,start+1201.0))
    if await settle(world):check(owned(world,CREATE).is_empty() and owned(world,DESTROY).is_empty() and not world.timeline.state.senses.spatial_effects.has(WATER),seat+": finite source retires without changing actual absence")
    world.install_playback(Recording.restore(index,start-.01))
    if await settle(world):check(owned(world,DESTROY).is_empty() and world.timeline.state.senses.spatial_effects.has(WATER),seat+": reverse seek restores only the true pre-DRY prefix")
    world.install_playback(Recording.restore(index,at))
    if await settle(world,component.id):check(old.get_ref()==null and owned(world,DESTROY).size()==1,seat+": loop constructs one fresh private source without retained future texture/clock")
    world.install_playback(Recording.restore(index,index.presentation_end_ms))
    if await settle(world):check(world.timeline.state==journal.state,seat+": final canonical state equals its independent original")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty() and var_to_bytes([index.initialization,index.groups,index.rows])==immutable,seat+": production source has no error or original-data mutation")
    native.close(world);check(native.handles.is_empty() and native.groups.is_empty(),seat+": all private native owner surfaces close")
    viewport.queue_free();await frame();await frame()
