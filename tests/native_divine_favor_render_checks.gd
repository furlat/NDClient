extends SceneTree
## Production Play/Studio path, real cast and UUID lifecycle; no positive rider
## is manufactured from the original held attack's Miss.
const Recording=preload("res://studio/recording.gd")
const RecordingMedia=preload("res://studio/recording_media.gd")
const Play=preload("res://play.gd")
const Journal=preload("res://sdk/journal.gd")
const Support=preload("res://tests/dynamic_weapon_support.gd")
const OWNER="cb23fb5c-34ed-4488-a2eb-a6632d4a45e4"
const ACTOR="7e2c178d-50ac-430b-862b-1efe0620d7c2"
const STAFF="fb2ced07-91a5-4c96-82c5-b8d377161d58"
const ROOT="res://tests/fixtures/schema16/weapon-enchantment-lifecycle/divine-favor"
const OUTPUT="res://.runtime/native-divine-favor"
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("NATIVE_DIVINE_FAVOR_FAIL ",label)
func frame()->void:await Support.frame(self)
func displayed_ready(world:Node,ids:Array)->bool:
    if world.timeline.state.is_empty() or world.world_prepare_epoch!=world.timeline.initialization_revision \
        or world.world_revision!=world.timeline.world_revision or world.actor_revision!=world.timeline.revision \
        or not world.component_renderer.ready:return false
    var native:RefCounted=world.component_renderer.native_spells
    for id in ids:
        var current:Array=world.displayed_components.filter(func(component):return component.id==id)
        var diagnostic:Dictionary=native.diagnostics.get(id,{})
        if current.size()!=1 or not native.handles.has(id) or not native.handles[id].root.is_visible_in_tree() \
            or diagnostic.get("status")!="rendered" or not diagnostic.get("input_bindings",{}).get("unavailable",{}).is_empty() \
            or not is_equal_approx(float(diagnostic.get("age_ms",-1.0)),float(current[0].age_ms)) \
            or not native.witnesses.any(func(witness):return witness.id==id):return false
    return true
func settle(world:Node,ids:Array=[])->bool:
    # At a paused published cut, playback_prepared() also asks the NEXT queued
    # operation to start. This probe observes only this cut's actual source;
    # advance() separately retains the strict preparation/publication gate.
    var ready:bool=false;var deadline:int=Time.get_ticks_msec()+45000
    while Time.get_ticks_msec()<deadline and not world.publication_failed and world.presentation_errors.is_empty() and world.media_issue.is_empty():
        # This existing callback also drives current source admission. Its
        # return additionally gates the next operation at an empty current.
        world.playback_prepared()
        if displayed_ready(world,ids):
            await frame()
            if displayed_ready(world,ids):ready=true;break
        await frame()
    check(ready,"Actual preparation/draw: "+str(ids if ready else {"display_ms":world.timeline.display_ms,"errors":world.presentation_errors,"media":world.media_issue,"readiness":media_wait(world)}))
    return ready
func next_group_cut(timeline:RefCounted,at:float)->float:
    # Follow the recording's actual chronological boundaries. A single jump
    # over all later groups asks current optical owners to prepare outcomes
    # whose equipment/condition membership has not been published yet.
    var group:Dictionary=timeline.current
    var start:float=timeline.group_start_ms
    if group.is_empty() and not timeline.queue.is_empty():
        group=timeline.queue[0]
        start=maxf(timeline.display_ms,float(group.preview_start_ms))
    return minf(at,start+float(group.duration_ms)) if not group.is_empty() else at
func media_wait(world:Node)->Dictionary:
    var media:Dictionary=world.media_warmup
    var missing:Array=[]
    for path in world.media_plan.get("required",{}):
        if not Play.MediaWarmup.ready(media,{path:true}):missing.append(path)
    var physical:Dictionary=Play.MediaWarmup.physical(media)
    var details:Array=[]
    for path in missing.slice(0,16):
        details.append({"path":path,"resident":physical.resident.get(path,{}),
            "queued":physical.queued.get(path),"failed":physical.failed.get(path)})
    return {"metadata":world.media_metadata_ready,"missing_count":missing.size(),"missing":details,
        "boot_ready":Play.MediaWarmup.boot_ready(media),"boot_waiting":media.boot_waiting.keys(),"native_startup":world.native_startup,
        "component_ready":world.component_renderer.ready,"component_inputs":world.component_renderer.readiness,
        "native_preparation":world.component_renderer.native_spells.preparation_state,
        "support_adoption":world.component_renderer.native_spells._support._adopt_result if world.component_renderer.native_spells._support!=null else {},
        "support_pending":[] if world.component_renderer.native_spells._support==null else world.component_renderer.native_spells._support._adopt_result.get("pending",[]).map(func(path):return {"path":path,"host_texture":world.textures.has(path),"native_lease":world.native_media_paths.has(path),"required_lease":world.media_plan.get("required",{}).has(path),"physical":physical.resident.get(path,{}),"failed":physical.failed.get(path),"queued":physical.queued.get(path)}),
        "native_failures":world.component_renderer.native_spells._prepare_failures,
        "native_required":world.component_renderer._native_prepare_components.map(func(component):return {"id":component.id,"kind":component.kind,"status":component.get("status"),"clip":component.get("native_clip",{}).get("id"),"handle":world.component_renderer.native_spells.handles.has(component.id)}),
        "native":world.component_renderer.native_spells.diagnostics,"budget":world.preparation_admission,
        "environment_ready":world._environment_sources_ready(),"pending_world_admitted":world.pending_world!=null and world.pending_world.admitted}
func advance(world:Node,at:float,ids:Array=[])->bool:
    var plan:Dictionary={};var deadline:int=Time.get_ticks_msec()+45000
    while world.timeline.display_ms<at-.000001 and Time.get_ticks_msec()<deadline:
        await process_frame
        if not plan.is_empty() and not world.timeline.replay_plan_current(plan):
            world.timeline.replay_cancel_preparation();plan={}
        if plan.is_empty():plan=world.timeline.replay_plan(next_group_cut(world.timeline,at))
        if world.timeline.replay_prepare(plan):
            if world.can_publish_replay_advance(plan):
                check(world.publish_replay_advance(plan),"Real ordered replay boundary publishes");plan={}
            else:world.timeline.replay_cancel_preparation();plan={}
        await RenderingServer.frame_post_draw
        if not world.presentation_errors.is_empty() or not world.media_issue.is_empty():break
    check(is_equal_approx(world.timeline.display_ms,at),"Shared clock reaches actual cut "+str(at)+str({"actual_ms":world.timeline.display_ms,
        "plan_current":world.timeline.replay_plan_current(plan),"plan_ms":plan.get("display_ms"),"segments":plan.get("segments",[]).size(),
        "waiting_media":world.timeline.waiting_for_media,"waiting_world":world.timeline.waiting_for_world,"queue":world.timeline.queue.size(),
        "current":world.timeline.current.get("id"),"errors":world.presentation_errors,"media":world.media_issue,
        "readiness":media_wait(world)} if not is_equal_approx(world.timeline.display_ms,at) else ""))
    return is_equal_approx(world.timeline.display_ms,at) and await settle(world,ids)
func pixels(world:Node,view:SubViewport,handle:Dictionary,label:String)->void:
    world.set_process(false);await frame();await frame()
    var canonical:PackedByteArray=var_to_bytes(world.timeline.state)
    var present:Image=view.get_texture().get_image();handle.root.hide();await frame();await frame()
    var hidden:Image=view.get_texture().get_image();var count:int=Support.changed(present,hidden)
    check(count>0,label+": actual selected source contributes framebuffer pixels")
    check(canonical==var_to_bytes(world.timeline.state),label+": optical comparison cannot publish condition/result data")
    present.save_png(OUTPUT+"/"+label+"-present.png");hidden.save_png(OUTPUT+"/"+label+"-hidden.png")
    evidence.append({"cut":label,"display_ms":world.timeline.display_ms,"changed_pixels":count,"source":handle.clip.id})
    handle.root.show();world.set_process(true)
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute(OUTPUT)
    var seats:Array=["amber","blue"]
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--seat="):seats=[argument.trim_prefix("--seat=")]
    for seat in seats:await actual_seat(seat)
    var result:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Both original factions, finite cast windup with actual constructor owner/equipped surface, prepared application/hold/removal under one real UUID, actual missed attack, exact canonical end, reverse seek/loop/cleanup and source-specific pixels. No positive Radiant rider, additional variant, performance or visual-approval claim."}
    FileAccess.open(OUTPUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("NATIVE_DIVINE_FAVOR ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
func actual_seat(seat:String)->void:
    var directory:String=ROOT.path_join(seat).path_join("journal")
    var journal:RefCounted=Journal.new();var opened:Dictionary=journal.open(directory,true)
    var index:Dictionary=Recording.read(directory)
    check(opened.ok and index.ok,seat+": independent original and current production index open")
    if not opened.ok or not index.ok:return
    var immutable:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
    index.media_preload=RecordingMedia.plan(index)
    var finite:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).has("native_condition_application"))
    var held:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("lifecycle_key")=="condition_divine_favor_persistent")
    check(finite.size()==1 and not held.is_empty(),seat+": one finite cast plus actual existing condition lifecycle")
    if finite.size()!=1 or held.is_empty():return
    var cast:Dictionary=finite[0];var owner:Dictionary=held[0].owner
    var hold:Dictionary=held[0].component;var windup:float=cast.start_ms+minf(200.0,(cast.end_ms-cast.start_ms)*.35)
    var application:float=owner.start_ms+100.0
    var sustain:float=maxf(owner.start_ms+float(hold.lifecycle_phases.application.seconds)*1000.0+50.0,(owner.start_ms+owner.end_ms)*.5)
    var removal:float=owner.end_ms+float(hold.lifecycle_phases.removal.seconds)*500.0
    check(owner.id==OWNER and owner.actor_uuid==ACTOR and sustain<owner.end_ms,seat+": actual UUID has a genuine sustained interval")
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true;world.media_warmup.budget_bytes=0
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.media_warmup.encounter_override=index.media_preload
    world.playback_end_ms=index.presentation_end_ms;world.component_renderer.audio.set_enabled(false)
    view.add_child(world);world.install_playback(Recording.restore(index,windup))
    if not await settle(world,[cast.component.id]):view.queue_free();await frame();return
    world.camera_focus=Play.Placement.contact(world.visual_actors[ACTOR].row);world.initial_focus=true;world.camera.size=3
    world.position_camera();world.grid_visible=false;world.wall_mode="hidden";world.update_wall_visibility();await frame();await frame()
    var native:RefCounted=world.component_renderer.native_spells
    var handle:Dictionary=native.handles[cast.component.id]
    var source:Node=handle.inner.components.weapon_blessing
    var binding:Dictionary=source.ownership.state
    check(source.ownership.owner_uuid==ACTOR and source.ownership.effect_uuid==OWNER \
        and source.settings.ownership.binding.is_empty() and source.hit_input.is_empty(),seat+": constructor has real actor/effect identity and no fixture packet or hit")
    check(binding.item_uuid==STAFF and binding.holder_uuid==ACTOR and binding.owner_kind=="caster" \
        and binding.effect_uuid==OWNER and binding.equipment_slot=="MELEE_MAIN" \
        and binding.contribution_active and binding.decoration_admitted and source.ownership.visible(),seat+": real current equipped staff and actual optical surface admit the finite phase")
    var inputs:Dictionary=native.diagnostics[cast.component.id].input_bindings
    check(inputs.not_applicable.get("hit_input")=="selected_weapon_blessing_phase_does_not_consume_hit" \
        and "hit_input" not in inputs.supplied and inputs.unavailable.is_empty(),seat+": unused hit input is explicitly N/A, never fake-supplied")
    check(world.visual_actors[ACTOR].entries.any(func(entry):return entry.actor_layer.get("item_uuid")==STAFF and entry.node.is_visible_in_tree()) \
        and source.measurement.get("cells",0)>0,seat+": original authored cast retains actual staff pixels and measured surface")
    await pixels(world,view,handle,seat+"-windup")
    var previous:WeakRef
    for cut in [{"at":application,"phase":"application"},{"at":sustain,"phase":"sustain"},{"at":removal,"phase":"removal"}]:
        if not await advance(world,cut.at,[hold.id]):continue
        var actual:Dictionary=native.handles[hold.id]
        if previous!=null:check(previous.get_ref()==actual.root,seat+": application/hold/removal retain the same private occurrence")
        previous=weakref(actual.root)
        check(actual.lifecycle_phase==cut.phase and actual.component.condition_uuid==OWNER,seat+": actual owner clock selects "+cut.phase)
        check(actual.occurrence.receiving.admitted_geometry and actual.occurrence.receiving.weapon_binding.effect_uuid==OWNER \
            and actual.occurrence.receiving.weapon_binding.item_uuid==STAFF,seat+": prepared "+cut.phase+" uses actual owner/current weapon geometry")
        await pixels(world,view,actual,seat+"-"+cut.phase)
    if await advance(world,index.presentation_end_ms):
        check(world.timeline.state==journal.snapshot(),seat+": end equals independent original canonical reducer")
        check(native.witnesses.all(func(value):return not value.id.begins_with(hold.id)),seat+": actual removal ends the held draw")
    var old:WeakRef=previous
    world.install_playback(Recording.restore(index,0.0))
    if await settle(world):check(not world.timeline.condition_owners.has(OWNER),seat+": reverse seek before application has no future held condition")
    world.install_playback(Recording.restore(index,sustain))
    if await settle(world,[hold.id]):
        check(old==null or old.get_ref()==null,seat+": seek retires prior private source owners")
        check(world.timeline.condition_owners[OWNER].start_ms==owner.start_ms,seat+": loop restores the original condition clock")
        await pixels(world,view,native.handles[hold.id],seat+"-loop-held")
    check(index.rows.all(func(row):return row.get("component",{}).get("native_cue",{}).get("staged_clip")!="bg3-36/divine-favor/divine_favor_native/hit"),seat+": original missed attack never creates a Radiant contact")
    check(var_to_bytes([index.initialization,index.groups,index.rows])==immutable,seat+": rendering leaves immutable source/event facts unchanged")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),seat+": no production presentation errors")
    native.close(world);check(native.handles.is_empty() and native.groups.is_empty(),seat+": private native owners close")
    view.queue_free();await frame();await frame()
