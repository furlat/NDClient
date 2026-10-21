extends "res://tests/native_finite_observed_render_checks.gd"
## Actual old flashed materials coexist with a restored current actor.
const Study=preload("res://tests/actor_history_material_transition_checks.gd")
const SurfaceSource=preload("res://presentation/native_material_surface.gd")
const HISTORY_CAPTURES="res://.runtime/history-material-transition-captures"
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("NATIVE_HISTORY_MATERIAL_TRANSITION_FAIL ",label)
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute(HISTORY_CAPTURES)
    for seat in ["amber","blue"]:await material_seat(seat)
    for source in Study.native_studies():
        var index:Dictionary=Recording.read(source.directory)
        check(index.ok,source.label+" unchanged native-hit original compiles")
        if not index.ok:continue
        var study:Dictionary=Study.native_transition(index,source)
        check(not study.is_empty(),source.label+" actual result and Blur owner define the native transition")
        if not study.is_empty():await material_record(index,study,source.actor,source.owner,source.label,source.retirement_recorded,true)
    finish()
func material_seat(seat:String)->void:
    var index:Dictionary=Fixtures.read("blur",seat)
    check(index.ok,seat+" unchanged original Blur journal compiles")
    if not index.ok:return
    var study:Dictionary=Study.transition(index)
    check(not study.is_empty(),seat+" actual recorded impact and Blur owner define the transition")
    if study.is_empty():return
    await material_record(index,study,Study.ACTOR,Study.OWNER,seat,true,false)

func material_record(index:Dictionary,study:Dictionary,actor:String,owner_id:String,seat:String,retirement_recorded:bool,native_hit:bool)->void:
    var owner:Dictionary=study.owner;var at:float=study.at_ms
    var original:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
    var media:Dictionary=RecordingMedia.plan(index)
    check(media.errors.is_empty(),seat+" ordinary recording media closure resolves")
    if not media.errors.is_empty():return
    Play.Catalog.adopt_snapshot(index.cache,media.source_files)
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true
    world.media_warmup.budget_bytes=0;world.media_warmup.encounter_override=media
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.playback_end_ms=index.presentation_end_ms
    world.native_startup_plan=Play.NativeStartup.recording_plan(index.rows);world.native_startup_requested_ms=at
    world.native_spell_hit_material=true
    world.component_renderer.audio.set_enabled(false);view.add_child(world)
    var previous:WeakRef;var pass_number:int=0
    for cut in [at,index.presentation_end_ms,at]:
        world.install_playback(Recording.restore(index,float(cut)))
        if not await settle(world):break
        if previous!=null:check(previous.get_ref()==null,seat+" changed replay epoch frees prior private history and treatment materials")
        var native=world.component_renderer.native_spells
        if cut!=at:
            var retained:bool=world.timeline.state.actors[actor].conditions.any(func(condition):return condition.condition_uuid==owner_id)
            check(retained!=retirement_recorded,seat+" terminal original preserves the actual removal or absence of removal")
            if retirement_recorded:
                check(native.handles.values().all(func(handle):return handle.component.get("condition_uuid")!=owner_id or not handle.root.is_visible_in_tree()),seat+" actual removal has no remaining history emission")
            previous=null;continue
        var visual:Dictionary=world.visual_actors[actor]
        world.camera_focus=Play.Placement.contact(visual.row)+Vector3.UP*.45
        world.camera.size=4;world.initial_focus=true;world.position_camera();world.grid_visible=false
        for quarter in ([0,1,2,3,0] if pass_number==0 else [0]):
            world.request_view(quarter)
            var deadline:int=Time.get_ticks_msec()+15000
            while world.rotation_pending() and Time.get_ticks_msec()<deadline:await frame()
            check(not world.rotation_pending() and world.quarter==quarter and world.world_quarter==quarter,seat+" actual published quarter "+str(quarter))
            if world.rotation_pending():break
            if not await settle(world):break
            var ids:Array=native.handles.keys().filter(func(id):return native.handles[id].component.get("condition_uuid")==owner_id and "actor_context" in native.handles[id].clip.get("inputs",[]))
            check(ids.size()==1,seat+" actual UUID owns exactly one history source")
            if ids.size()!=1:break
            var id:String=ids[0]
            if not await settle(world,id):break
            var handle:Dictionary=native.handles[id]
            var bindings:Dictionary=native.diagnostics[id].input_bindings
            check(bindings.unavailable.is_empty() and handle.clip.inputs.all(func(channel):return channel in bindings.supplied or bindings.get("not_applicable",{}).has(channel)),seat+" every requested history input is supplied or exact-source N/A")
            var helper:RefCounted=handle.occurrence.actor_history
            check(helper.admitted and handle.get("history_capture_range",{}).get("complete_window",false),seat+" actual compositor is seeded from the complete original window")
            var logical:Array=handle.get("history_captures",[])
            var snapshots:Array=helper.history.get("recipient",[])
            var completed:Dictionary=helper.capture_status()
            check(completed.error.is_empty() and completed.retained_captures>0 and completed.retained_captures<=int(helper.settings.get("maximum_live_captures",64)),seat+" source captures remain bounded without dropping a required predecessor")
            check(completed.captures.all(func(capture):return capture.ready and capture.requested_identity==capture.drawn_identity and capture.drawn_frame>=0),seat+" each exact requested capture has its own completed draw identity")
            var current_entries:Array=native.Inputs.actor_layers(world,actor).layers
            check(not current_entries.is_empty() and current_entries.all(func(entry):return is_zero_approx(float(entry.material.get_shader_parameter("flash_strength")))),seat+" actual published current body has restored its normal material")
            var treated:int=0;var normal:int=0
            for snapshot in snapshots:
                var sample_ms:float=float(owner.start_ms)+float(snapshot.seconds)*1000.0
                var captures:Array=logical.filter(func(capture):return is_equal_approx(float(capture.sample_ms),sample_ms))
                check(captures.size()==1,seat+" native history sample maps to one actual immutable prefix capture")
                if captures.size()!=1:continue
                var capture:Dictionary=captures[0]
                var expected:float=float(Play.Conditions.parameters(capture.departure.material,world.textures,world.resources).flash_strength)
                check(capture.rig==world.visual_actors[actor].row.rig and not snapshot.layers.is_empty(),seat+" old material belongs to the actual same-rig assembled outfit")
                for layer in snapshot.layers:
                    check(is_equal_approx(float(layer.material.get_shader_parameter("flash_strength")),expected),seat+" native captured material retains its own original treatment strength")
                    check(current_entries.all(func(entry):return layer.material!=entry.material),seat+" captured material is private rather than a mutable current-body alias")
                if native_hit and expected>0.0:
                    var retained:Dictionary=snapshot.get("capture",{})
                    var dependencies:Array=retained.get("dependencies",[])
                    check(dependencies.size()==1,seat+" historical native hit owns one exact immutable evaluated dependency")
                    if dependencies.size()==1:
                        var dependency:Dictionary=dependencies[0]
                        var flash:Dictionary=capture.departure.material.flash
                        check(dependency.identity.component_id==flash.id and dependency.identity.source_event_uuid==flash.source_event_uuid \
                            and dependency.identity.actor_uuid==actor and is_equal_approx(dependency.seconds,float(flash.age_ms)/1000.0),seat+" dependency retains real recipient/result and original absolute source seconds")
                        check(dependency.texture!=dependency.source_texture and dependency.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,seat+" completed dependency is private and frozen after its draw")
                        check(snapshot.layers.all(func(layer):return layer.material.get_shader_parameter("native_body_surface")==dependency.texture \
                            and bool(layer.material.get_shader_parameter("native_body_enabled"))),seat+" original body materials consume the frozen dependency instead of mutable current pixels")
                if expected>0.0:treated+=1
                else:normal+=1
            check(treated>0 and normal>0,seat+" actual native history retains flashed and restored materials simultaneously")
            check(native.witnesses.any(func(witness):return witness.id==id),seat+" actual history source has a native draw-frame witness")
            world.set_process(false);await frame();await frame()
            if native_hit:await dependency_control(handle,snapshots,seat)
            var canonical:PackedByteArray=var_to_bytes(world.timeline.state)
            var clock_before:Array=[handle.get("owner_state",{}).duplicate(true),handle.sample_time,helper.last_seconds]
            var occurrence_id:int=handle.occurrence.get_instance_id()
            var treatment_before:Array=snapshots.map(func(snapshot):return [snapshot.seconds,snapshot.layers.map(func(layer):return [layer.material.get_instance_id(),layer.material.get_shader_parameter("flash_strength")])])
            var present:Image=view.get_texture().get_image();Effects.hide(handle);await frame();await frame()
            var absent:Image=view.get_texture().get_image();var pixels:int=changed(present,absent)
            check(pixels>0,seat+" hiding only actual history changes framebuffer pixels q"+str(quarter))
            check(not helper.admitted and not handle.get("actor_context_bound",true),seat+" normal hide withdraws actor context and suspends the capture owner")
            # Effects.hide deliberately withdraws actor_context, so root.show
            # alone cannot restore its private owner/passes. Ordinary Play
            # supplies that same real current context without advancing time.
            world.set_process(true)
            if not await settle(world,id):break
            world.set_process(false);await frame();await frame()
            var restored:Image=view.get_texture().get_image();var drift:int=changed(present,restored)
            var treatment_after:Array=helper.history.get("recipient",[]).map(func(snapshot):return [snapshot.seconds,snapshot.layers.map(func(layer):return [layer.material.get_instance_id(),layer.material.get_shader_parameter("flash_strength")])])
            check(native.handles[id].root==handle.root and handle.occurrence.get_instance_id()==occurrence_id \
                and helper.admitted and handle.get("actor_context_bound",false),seat+" ordinary same-clock restoration re-admits the same private source/owner")
            check([handle.get("owner_state",{}),handle.sample_time,helper.last_seconds]==clock_before,seat+" restoration keeps the exact condition and source clocks")
            check(treatment_after==treatment_before,seat+" ordinary restoration preserves exact captured material identities and historical treatment uniforms")
            check(var_to_bytes(world.timeline.state)==canonical and is_equal_approx(world.timeline.display_ms,at),seat+" visibility/restore control leaves canonical state and playback clock unchanged")
            check(drift==0,seat+" same-owner restoration restores the exact paused framebuffer")
            var stem:String=HISTORY_CAPTURES.path_join(seat+"-q"+str(quarter)+"-pass"+str(pass_number))
            check(present.save_png(stem+"-present.png")==OK and absent.save_png(stem+"-hidden.png")==OK \
                and restored.save_png(stem+"-restored.png")==OK,seat+" actual history output/restore controls saved")
            evidence.append({"seat":seat,"at_ms":at,"quarter":quarter,"published_quarter":world.world_quarter,"native_treated_samples":treated,
                "native_normal_samples":normal,"changed_pixels":pixels,"restoration_changed_pixels":drift,
                "historical_uniforms_unchanged":treatment_after==treatment_before,"canonical_unchanged":var_to_bytes(world.timeline.state)==canonical,
                "flash_result":study.flash.component.source_event_uuid,"native_hit":native_hit,"retirement_recorded":retirement_recorded,"capture_status":completed,"equipment_transition":"not_recorded"})
            previous=weakref(handle.root);world.set_process(true)
        pass_number+=1
    var native=world.component_renderer.native_spells;native.close(world)
    check(native.handles.is_empty() and native.groups.is_empty() and native.prepared_layers.is_empty() and (previous==null or previous.get_ref()==null),seat+" teardown frees private historical layers, materials and passes")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),seat+" material overlap, actual views and seeking have no presentation errors")
    check(var_to_bytes([index.initialization,index.groups,index.rows])==original,seat+" original packet-derived inputs remain unchanged")
    view.queue_free();await frame();await frame()

func dependency_control(handle:Dictionary,snapshots:Array,label:String)->void:
    var held:Array=[]
    for snapshot in snapshots:
        for dependency in snapshot.get("capture",{}).get("dependencies",[]):held.append(dependency)
    check(not held.is_empty(),label+" original native hit has a completed immutable texture to inspect")
    if held.is_empty():return
    var dependency:Dictionary=held[0]
    var source:Dictionary={}
    var provider:RefCounted
    for private_source in handle.get("history_sources",{}).values():
        if not private_source.has("departure_native_hits"):continue
        for record in private_source.departure_native_hits.records.values():
            if record.has("surface") and record.surface.viewport.get_texture()==dependency.source_texture:
                source=record;provider=private_source.departure_native_hits;break
        if not source.is_empty():break
    check(not source.is_empty(),label+" frozen dependency identifies its actual private original source owner")
    if source.is_empty():return
    var frozen:Image=dependency.texture.get_image()
    SurfaceSource.sample(source.surface,dependency.seconds,source.clock)
    await frame();await frame()
    check(frozen.get_data()==dependency.source_texture.get_image().get_data(),label+" frozen native dependency equals the unchanged selected source rendered at its original absolute age")
    SurfaceSource.sample(source.surface,dependency.seconds+.137,source.clock)
    await frame();await frame()
    check(frozen.get_data()==dependency.texture.get_image().get_data(),label+" later original-source sampling cannot mutate historical evaluated pixels")
    provider.close()
    await frame();await frame()
    check(frozen.get_data()==dependency.texture.get_image().get_data(),label+" original source retirement cannot mutate its independently owned historical pixels")
    for private_source in handle.get("history_sources",{}).values():
        if private_source.get("departure_native_hits")==provider:private_source.erase("departure_native_hits")

func finish()->void:
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Original Blur opportunity-attack and four native Fire Bolt/Magic Missile result originals retained by immutable same-rig capture materials while current body is restored; actual source inputs, all four published views, isolated native pixels, actual removal/recast where recorded (Magic Missile retirement remains unrecorded), seek/loop and teardown. Equipment transitions, live frame cost and user art approval remain unqualified."}
    FileAccess.open("res://.runtime/native-actor-history-material-transition-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_HISTORY_MATERIAL_TRANSITION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
