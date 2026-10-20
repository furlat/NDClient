extends "res://tests/native_vampiric_touch_render_checks.gd"
## Original accepted Ram through ordinary Play. Body/motion remain independent;
## no timed review contact, extra light, damage or failed-save flag is invented.
const Media=preload("res://studio/recording_media.gd")
const Prepared=preload("res://tests/dynamic_weapon_support.gd")
const Journal=preload("res://sdk/journal.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const ROOT_PATH="res://tests/fixtures/schema16/scenarios/flaming-sphere-lifecycle"
const CONTACT="bg3-36/flaming-sphere/native_sphere_ram"
const SPHERE="9a7daae4-573e-4248-82ca-19eb9430cf2c"
const OWNER="3e1d4d91-5553-4266-951d-0754ac3953c5"
const CASTER="ec1f2312-c161-48fd-b711-2d828582420e"
const TARGET="361a033a-73eb-4f4c-96bd-9380d7092591"
const OUTPUT="res://.runtime/native-flaming-sphere-contact"
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute(OUTPUT)
    for seat in ["amber","blue"]:await ram_seat(seat)
    var result:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Both original accepted Ram actions: exact real source aura/action/save/applied result, measured recipient geometry, isolated finite native pixels in all four views, ordinary seek/loop and teardown. Saved-half/end-turn/trail output, performance and human art acceptance remain unqualified."}
    FileAccess.open(OUTPUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("NATIVE_FLAMING_SPHERE_CONTACT ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
func ram_seat(seat:String)->void:
    var directory:String=ROOT_PATH.path_join(seat)
    var original:RefCounted=Journal.new();var opened:Dictionary=original.open(directory,true,true)
    var index:Dictionary=Recording.read(directory)
    check(opened.ok and index.ok,seat+": independent original and ordinary Studio recording compile")
    if not opened.ok or not index.ok:return
    var immutable:PackedByteArray=var_to_bytes([index.groups,index.rows])
    var rows:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_clip",{}).get("id")==CONTACT)
    check(rows.size()==1,seat+": one actual Ram produces one finite contact, without reusing later aura damage")
    if rows.size()!=1:return
    var row:Dictionary=rows[0];var component:Dictionary=row.component
    check(component.status=="available" and component.source_event_uuid=="163" and component.actor_uuid==SPHERE \
        and component.target_uuid==TARGET and component.native_constructor_evidence.damage_source_uuid==CASTER,seat+": actual accepted-source identity stays distinct from original-caster damage attribution")
    var start:float=float(row.start_ms);var at:float=start+150.0
    check(is_finite(start) and is_finite(float(row.end_ms)) and is_equal_approx(float(row.end_ms)-start,450.0),seat+": original finite source duration has no fabricated lease")
    if not is_finite(start) or not is_finite(float(row.end_ms)):return
    index.media_preload=Media.plan(index)
    check(index.media_preload.errors.is_empty(),seat+": ordinary full source closure is available")
    if not index.media_preload.errors.is_empty():return
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true;world.media_warmup.budget_bytes=0
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.media_warmup.encounter_override=index.media_preload
    world.native_startup_plan=Play.NativeStartup.recording_plan(index.rows);world.native_startup_requested_ms=at
    world.playback_end_ms=index.presentation_end_ms;world.component_renderer.audio.set_enabled(false);view.add_child(world)
    var native:RefCounted=world.component_renderer.native_spells
    var last_root:WeakRef
    for sample_at in [maxf(0.0,start-.01),at,float(row.end_ms)+.01,maxf(0.0,start-.01),at]:
        world.install_playback(Recording.restore(index,sample_at))
        var active:bool=is_equal_approx(sample_at,at)
        var ready:bool=await Prepared.settle(self,world,[component.id] if active else [])
        check(ready,seat+": ordinary published native source prepares at "+str(sample_at))
        if not ready:break
        check(is_equal_approx(world.timeline.display_ms,sample_at),seat+": preparation never changes the displayed canonical clock")
        if not active:
            check(not world.displayed_components.any(func(actual):return actual.id==component.id) \
                and native.witnesses.all(func(witness):return witness.id!=component.id or witness.get("status")!="rendered"),seat+": no Ram body is displayed before/after its actual finite result")
            if native.handles.has(component.id):check(not native.handles[component.id].root.is_visible_in_tree(),seat+": a prepared future/retired Ram source is hidden")
            continue
        check(native.handles.has(component.id),seat+": actual finite contact owns a native instance")
        if not native.handles.has(component.id):continue
        var handle:Dictionary=native.handles[component.id]
        var programs:Array=handle.occurrence.input_receivers.get("set_contact_event",[])
        check(programs.size()==1,seat+": one sealed source receives the actual contact packet")
        if programs.size()!=1:continue
        var program:Node3D=programs[0]
        check(program.specification.owner_uuid==OWNER and program.specification.source_uuid==SPHERE \
            and program.event==component.native_inputs.contact_event and program.event.damage_component_uuid=="163" \
            and program.event.outcome=="failed_save" and program.event.applied,seat+": constructor and setter agree on actual owner/result and observed failed save")
        check(not program.event.has("retained_caster_dc") and not program.event.has("native_slot_damage_dice") \
            and program.endpoints.size()==1 and program.endpoints[0].actor_uuid==TARGET \
            and not program.surface.get("points",[]).is_empty(),seat+": actual recipient endpoints/surface replace every successful review input")
        var bindings:Dictionary=native.diagnostics.get(component.id,{}).get("input_bindings",{})
        check(bindings.get("unavailable",{}).is_empty() \
            and ["contact_event","recipient_geometry","targets"].all(func(name):return name in bindings.get("supplied",[])),seat+": all three declared source inputs are actually supplied")
        check(program.capture_observation().visible_contact and native.witnesses.any(func(witness):return witness.id==component.id \
            and witness.status=="rendered"),seat+": accepted contact submits its own finite native geometry")
        check(not world.visual_actors.has(SPHERE) and world.timeline.state.actors[SPHERE].conditions.any(func(member):return member.condition_uuid==OWNER),seat+": real native body ownership remains separate; no sphere sprite or fake condition is created")
        for quarter in (range(4) if last_root==null else [world.quarter]):
            world.request_view(quarter)
            var deadline:int=Time.get_ticks_msec()+45000
            while world.rotation_pending() and Time.get_ticks_msec()<deadline:await frame()
            var published:bool=not world.rotation_pending() and world.quarter==quarter and world.world_quarter==quarter
            check(published,seat+": actual prepared camera/receiving view publishes quarter "+str(quarter))
            if not published:break
            var prepared:bool=await Prepared.settle(self,world,[component.id])
            check(prepared,seat+": actual recipient source prepares in view "+str(quarter))
            if not prepared:break
            handle=native.handles[component.id]
            world.camera_focus=Play.Placement.contact({"position":component.to_position,"base_height_steps":float(component.get("to_elevation_feet",0.0))/5.0})
            world.camera.size=4;world.initial_focus=true;world.position_camera();world.grid_visible=false
            await frame();await frame();world.set_process(false)
            var canonical:PackedByteArray=var_to_bytes(world.timeline.state)
            var shown:Image=view.get_texture().get_image();Effects.hide(handle);await frame();await frame()
            var hidden:Image=view.get_texture().get_image();var count:int=changed(shown,hidden)
            check(count>0,seat+": actual finite Ram contributes independent framebuffer pixels in view "+str(quarter))
            check(var_to_bytes(world.timeline.state)==canonical and world.timeline.display_ms==sample_at,seat+": optical comparison cannot apply damage or publish state")
            evidence.append({"seat":seat,"quarter":world.quarter,"published_quarter":world.world_quarter,"at_ms":sample_at,"changed_pixels":count,"event":program.event.duplicate(true),"evidence":component.native_constructor_evidence})
            shown.save_png(OUTPUT+"/"+seat+"-q"+str(quarter)+"-present.png");hidden.save_png(OUTPUT+"/"+seat+"-q"+str(quarter)+"-hidden.png")
            handle.root.show();world.set_process(true)
        last_root=weakref(handle.root)
    world.install_playback(Recording.restore(index,index.presentation_end_ms))
    var ended:bool=await Prepared.settle(self,world)
    check(ended,seat+": actual final prefix prepares")
    check(Compare.difference(world.timeline.state,original.state).is_empty(),seat+": independent canonical final state is unchanged by contact/seek/loop")
    check(var_to_bytes([index.groups,index.rows])==immutable,seat+": source/event clocks remain immutable across native epochs")
    native.close(world)
    check(native.handles.is_empty() and native.groups.is_empty() and native.prepared_layers.is_empty() \
        and (last_root==null or last_root.get_ref()==null),seat+": explicit teardown releases finite contact and native body owners")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),seat+": no production presentation/source error is hidden")
    view.queue_free();await frame();await frame()
