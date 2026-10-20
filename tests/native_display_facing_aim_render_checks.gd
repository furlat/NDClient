extends "res://tests/native_finite_observed_render_checks.gd"
## Actual casting UUID through Play; only its authored optical aim is cosmetic.
const AIM_ROOT="res://tests/fixtures/schema16/eyebite-aim"
const AIM_CONDITION="condition.spell.eyebite.casting"
const AIM_LIFECYCLE="condition_eyebite_eye_persistent"
const AIM_CAPTURES="res://.runtime/display-facing-aim-captures"

func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("NATIVE_DISPLAY_FACING_AIM_FAIL ",label)

func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute(AIM_CAPTURES)
    for seat in ["amber","blue"]:await aim_seat(seat)
    finish()

func aim_seat(seat:String)->void:
    var directory:String=AIM_ROOT.path_join(seat)
    var packet_path:String=directory.path_join("0000000000000008.json")
    var raw:PackedByteArray=FileAccess.get_file_as_bytes(packet_path)
    var packet:Dictionary=JSON.parse_string(raw.get_string_from_utf8());var casts:Array=[]
    for lineage in packet.lineages:
        for node in lineage.events:
            var fact:Variant=node.get("fact")
            if fact!=null and fact.get("behavior_id")=="spell.eyebite" and node.phase=="completion":casts.append(node)
    check(casts.size()==1,seat+" original packet discloses one completed Eyebite cast")
    if casts.size()!=1:return
    var cast:Dictionary={"occurrence":str(int(casts[0].occurrence)),"fact":casts[0].fact}
    var index:Dictionary=Recording.read(directory)
    check(index.ok,seat+" unchanged original recording compiles")
    if not index.ok:return
    var owners:Array=index.rows.filter(func(row):return row.kind=="condition" and row.owner.condition.behavior_id==AIM_CONDITION)
    check(owners.size()==1,seat+" one real condition span owns the maintained eye")
    if owners.size()!=1:return
    var span:Dictionary=owners[0];var owner:Dictionary=span.owner
    var owner_bytes:PackedByteArray=var_to_bytes(owner)
    var id:String="condition:"+str(owner.id)+":lifecycle:"+AIM_LIFECYCLE
    check(owner.id=="e94cc307-c32a-436f-8d99-5136e2ff8eaf" and owner.actor_uuid==cast.fact.source_entity_uuid \
        and not owner.initial and is_inf(owner.end_ms),seat+" recorded lifetime begins at actual admission and invents no removal")
    check(span.recipe.persistent.get("nativeAim")=="display_facing",seat+" actual condition authoring explicitly selects displayed-facing optical aim")
    finite_targeting(index,cast,seat)
    var before:float=maxf(0.0,float(owner.start_ms)-2.0)
    var during:float=float(owner.start_ms)+600.0
    check(during<float(span.end_ms) and during<index.presentation_end_ms,seat+" native observation lies inside the original casting lifetime")
    if during>=float(span.end_ms) or during>=index.presentation_end_ms:return
    var media:Dictionary=RecordingMedia.plan(index)
    check(media.errors.is_empty(),seat+" ordinary replay media closure resolves")
    if not media.errors.is_empty():return
    Play.Catalog.adopt_snapshot(index.cache,media.source_files)
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true
    world.media_warmup.budget_bytes=0;world.media_warmup.encounter_override=media
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.playback_end_ms=index.presentation_end_ms
    world.native_startup_plan=Play.NativeStartup.recording_plan(index.rows);world.native_startup_requested_ms=before
    world.component_renderer.audio.set_enabled(false);view.add_child(world)
    var previous:WeakRef;var pass_number:int=0
    for at in [before,during,before,during]:
        var restored:RefCounted=Recording.restore(index,at)
        var expected_state:PackedByteArray=var_to_bytes(restored.state)
        world.install_playback(restored)
        if not await settle(world,id if at==during else ""):break
        if previous!=null:check(previous.get_ref()==null,seat+" seek/loop frees the previous private eye occurrence")
        var native=world.component_renderer.native_spells
        check(var_to_bytes(world.timeline.state)==expected_state,seat+" preparation publishes exactly the independent restored prefix")
        if at==before:
            check(not world.timeline.condition_owners.has(owner.id),seat+" pre-admission prefix has no future casting condition")
            check(native.witnesses.all(func(witness):return witness.id!=id),seat+" future maintained eye has no pre-admission draw witness")
            if native.handles.has(id):check(not native.handles[id].root.is_visible_in_tree(),seat+" future preparation stays hidden")
            previous=null;continue
        var visual:Dictionary=world.visual_actors.get(owner.actor_uuid,{})
        check(not visual.is_empty(),seat+" the actual caster is displayed at the original condition cut")
        if visual.is_empty():break
        world.camera_focus=Play.Placement.contact(visual.row)+Vector3.UP*.6
        world.camera.size=4.2;world.initial_focus=true;world.position_camera();world.grid_visible=false
        var quarters:Array=[0,1,2,3,0] if pass_number==0 else [0]
        for quarter in quarters:
            world.request_view(quarter)
            var deadline:int=Time.get_ticks_msec()+15000
            while world.rotation_pending() and Time.get_ticks_msec()<deadline:await frame()
            check(not world.rotation_pending() and world.quarter==quarter and world.world_quarter==quarter,seat+" actual requested/published quarter agrees: "+str(quarter))
            if world.rotation_pending():break
            if not await settle(world,id):break
            var handle:Dictionary=inspect_eye(world,owner,during,id,seat+" q"+str(quarter))
            if handle.is_empty():continue
            var pixels:int=await eye_pixels(world,view,handle,seat,quarter,pass_number)
            evidence.append({"seat":seat,"pass":pass_number,"at_ms":at,"quarter":quarter,"published_quarter":world.world_quarter,
                "condition_uuid":owner.id,"actor_uuid":owner.actor_uuid,"actual_cast_occurrence":cast.occurrence,
                "source_phase":handle.owner_state.phase,"changed_pixels":pixels,
                "facing":world.visual_actors[owner.actor_uuid].row.facing,"endpoints":handle.occurrence.live_pose.last_endpoints})
            previous=weakref(handle.root)
        pass_number+=1
    var native=world.component_renderer.native_spells;native.close(world)
    check(native.handles.is_empty() and native.groups.is_empty() and native.prepared_layers.is_empty(),seat+" teardown releases all private eye owners and render passes")
    check(previous==null or previous.get_ref()==null,seat+" final private eye occurrence is freed on close")
    check(var_to_bytes(owner)==owner_bytes,seat+" canonical recorded condition owner is unchanged")
    check(FileAccess.get_file_as_bytes(packet_path)==raw,seat+" original admission/cast packet remains byte-identical")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),seat+" real views/seeking/looping introduce no presentation or media errors")
    view.queue_free();await frame();await frame()

func finite_targeting(index:Dictionary,cast:Dictionary,label:String)->void:
    var rows:Array=index.rows.filter(func(row):
        var component:Dictionary=row.get("component",{})
        var clip:String=str(component.get("native_clip",{}).get("id",""))
        return not component.get("persistent_owner",false) and clip.begins_with("live/eyebite/") and clip.ends_with("/eye"))
    check(rows.size()==1,label+" the actual finite caster-to-target eye clip remains separate")
    for row in rows:
        var component:Dictionary=row.component;var cue:Dictionary=component.native_cue
        check(component.actor_uuid==cast.fact.source_entity_uuid and component.target_uuid==cast.fact.target_entity_uuid \
            and str(component.source_event_uuid)==cast.occurrence,label+" finite clip retains this seat's actual cast and target identities")
        check(cue.get("live_endpoints",[])==[{"actor":"caster","socket":"ground"},{"actor":"target","socket":"body_center"}] \
            and not cue.has("aim_policy"),label+" finite authored target endpoints cannot borrow cosmetic maintained-eye aim")

func inspect_eye(world:Node,owner:Dictionary,at:float,id:String,label:String)->Dictionary:
    var native=world.component_renderer.native_spells
    check(native.handles.has(id),label+" one existing casting UUID owns a native eye")
    if not native.handles.has(id):return {}
    var handle:Dictionary=native.handles[id]
    check(world.timeline.condition_owners.has(owner.id) and world.timeline.condition_owners[owner.id].start_ms==owner.start_ms \
        and native.handles.keys().filter(func(key):return key.begins_with("condition:"+str(owner.id)+":lifecycle:")).size()==1,label+" original UUID/start own exactly one lifecycle occurrence")
    var state:Dictionary=handle.get("owner_state",{})
    check(state.get("phase")=="sustain" and handle.get("lifecycle_phase")=="sustain" \
        and is_equal_approx(float(state.get("owner_age_seconds",-1)),(at-float(owner.start_ms))/1000.0),label+" real 600ms owner age selects the actual sustain phase")
    var bindings:Dictionary=native.diagnostics.get(id,{}).get("input_bindings",{})
    var requested:Array=handle.clip.inputs;var supplied:Array=bindings.get("supplied",[])
    check(bindings.get("unavailable",{}).is_empty() and requested.all(func(channel):return channel in supplied),label+" every requested source input is supplied without inventing a target")
    check(requested.has("root_path") and requested.has("owner_state") and requested.has("live_endpoints"),label+" actual source declares placement, owner state and optical endpoints")
    var program:Node3D=handle.occurrence;var live:RefCounted=program.live_pose
    check(program.construction_error.is_empty() and program.context==state and live!=null and live.admitted,label+" actual delivered source admits the original owner state and live optical inputs")
    if live==null:return {}
    var endpoints:Array=live.last_endpoints
    check(endpoints.size()==2 and endpoints.all(func(point):return point.actor_uuid==owner.actor_uuid and not point.has("target_uuid")),label+" optical pair belongs to the displayed caster rather than a fabricated gameplay target")
    if endpoints.size()!=2:return {}
    var row:Dictionary=world.visual_actors[owner.actor_uuid].row
    var cycle:Array=world.rig_config.FACING_CYCLE
    var angle:float=float(posmod(cycle.find(str(row.facing))-cycle.find("E"),8))*TAU/8.0-PI/4.0
    var direction:Vector3=Vector3(cos(angle),0,sin(angle))
    var settings:Dictionary=program.parameters.live_pose;var offset:Array=settings.offset
    var origin:Vector3=handle.endpoints.to+Vector3(offset[0],offset[1],offset[2])
    check(settings.mode=="gaze" and is_equal_approx(float(settings.camera_blend),.32),label+" delivered source mode and camera blend remain unchanged")
    check(endpoints[0].point.is_equal_approx(handle.endpoints.to) and endpoints[1].point.is_equal_approx(origin+direction) \
        and str(endpoints[1].get("optical_aim"))=="display_facing",label+" actual world-facing endpoint equation applies source offset once, without a second camera rotation")
    check(live.entries.size()==1,label+" actual source owns one maintained eye geometry")
    for entry in live.entries:
        var expected:Vector3=world.camera.global_basis.z.lerp(direction,float(settings.camera_blend)).normalized()
        check(entry.node.is_visible_in_tree() and entry.node.global_position.is_equal_approx(origin) \
            and entry.node.global_basis.z.normalized().dot(expected)>.99999,label+" actual placed eye uses source world origin and source-authored camera blend")
    check(native.witnesses.any(func(witness):return witness.id==id),label+" admitted source has an actual native post-draw witness")
    return handle

func eye_pixels(world:Node,view:SubViewport,handle:Dictionary,seat:String,quarter:int,pass_number:int)->int:
    world.set_process(false);await frame();await frame()
    var canonical:PackedByteArray=var_to_bytes(world.timeline.state)
    var present:Image=view.get_texture().get_image()
    Effects.hide(handle);await frame();await frame()
    var hidden:Image=view.get_texture().get_image();var pixels:int=changed(present,hidden)
    var label:String=seat+" q"+str(quarter)+" pass"+str(pass_number)
    check(pixels>0,label+" hiding only the actual maintained eye changes framebuffer pixels")
    handle.root.show();await frame();await frame()
    check(changed(present,view.get_texture().get_image())==0,label+" restoring the same owner restores the exact paused frame")
    check(var_to_bytes(world.timeline.state)==canonical,label+" optical visibility probe leaves canonical state unchanged")
    var stem:String=AIM_CAPTURES.path_join(seat+"-q"+str(quarter)+"-pass"+str(pass_number))
    check(present.save_png(stem+"-present.png")==OK and hidden.save_png(stem+"-hidden.png")==OK,label+" isolated actual native output captures saved")
    world.set_process(true)
    return pixels

func finish()->void:
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Both unchanged original Eyebite journals, actual casting UUID sustain, declared optical policy and supplied native inputs, actual published four quarters and return, source endpoint/origin/orientation equations, isolated native pixels, seeking/looping/teardown. Finite caster-to-target clips retain actual targeting. Performance, a missing recorded removal and human visual approval are not claimed."}
    FileAccess.open("res://.runtime/native-display-facing-aim-render-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_DISPLAY_FACING_AIM ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
