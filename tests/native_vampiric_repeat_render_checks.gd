extends "res://tests/native_vampiric_touch_render_checks.gd"
## The actual granted repeat is its own finite result, beside the already
## owned hand/healing sources. No new spell cast or idle activity is invented.
const Media=preload("res://studio/recording_media.gd")
const Prepared=preload("res://tests/dynamic_weapon_support.gd")
const Journal=preload("res://sdk/journal.gd")
const Occurrences=preload("res://presentation/occurrences.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const ROOT_PATH="res://tests/fixtures/schema16/vampiric-positive"
const OUTPUT="res://.runtime/native-vampiric-repeat"
const ACTION="action.spell.vampiric_touch.strike"
const OWNER="aebf2ad6-b8cc-4717-82ae-d185ed446e45"
const CASTER="34430787-4e2a-465b-aa1a-076ea3a07199"
const TARGET="28afd8d7-0e9a-45e0-ac33-51ebeb02f251"
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute(OUTPUT)
    for seat in ["amber","blue"]:await repeat_seat(seat)
    var result:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Both unchanged positive Vampiric originals: actual accepted repeat Crit/24Necrotic and before-row condition UUID, actual source setters/recipient geometry, finite native pixels in four published views, reverse seek/loop and cleanup. Idle contribution activity, windup, performance and human art acceptance remain separate."}
    FileAccess.open(OUTPUT+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("NATIVE_VAMPIRIC_REPEAT ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
func repeat_seat(seat:String)->void:
    var directory:String=ROOT_PATH.path_join(seat)
    var journal:RefCounted=Journal.new();var opened:Dictionary=journal.open(directory,true,true)
    var index:Dictionary=Recording.read(directory)
    check(opened.ok and index.ok,seat+": original independent journal and ordinary Studio index open")
    if not opened.ok or not index.ok:return
    var decoded:Dictionary=journal.protocol.decode_server("PlayerOperation",FileAccess.get_file_as_bytes(directory.path_join("0000000000000019.json")))
    check(decoded.ok,seat+": original repeat packet decodes exact native integer identities")
    if not decoded.ok:return
    var actions:Array=[];var damage:Array=[]
    for native in decoded.value.lineages:
        for node in Occurrences.group(native).events:
            var fact:Variant=node.get("fact")
            if fact==null:continue
            if fact.get("behavior_id")==ACTION:actions.append(node)
            if fact.kind=="damage" and fact.get("stage")=="applied":damage.append(node)
    check(actions.size()==1 and damage.size()==1,seat+": original packet discloses one granted repeat and one applied damage result")
    if actions.size()!=1 or damage.size()!=1:return
    check(actions[0].fact.attack_outcome=="Crit" and actions[0].fact.source_entity_uuid==CASTER \
        and actions[0].fact.target_entity_uuid==TARGET and damage[0].fact.applied_damage==24 \
        and damage[0].fact.damage_type=="Necrotic",seat+": independent original Crit, recipient and24Necrotic are preserved")
    var rows:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_clip",{}).get("id")==IMPACT \
        and row.component.get("native_cue",{}).get("constructor_input",{}).get("behavior_id")==ACTION)
    check(rows.size()==1,seat+": one repeat owns exactly one finite contact beside the separate first-cast impact")
    if rows.size()!=1:return
    var row:Dictionary=rows[0];var component:Dictionary=row.component
    var source_evidence:Dictionary=component.get("native_constructor_evidence",{})
    check(component.status=="available" and component.source_event_uuid==str(damage[0].id) \
        and source_evidence.source_occurrence==str(actions[0].id) and source_evidence.source_lineage==str(actions[0].lineage_id) \
        and source_evidence.result_occurrence==str(damage[0].id) and source_evidence.result_lineage==str(damage[0].lineage_id),seat+": actual accepted action and its applied result retain distinct native ancestry")
    check(source_evidence.condition_uuid==OWNER and source_evidence.owner_activity_occurrence==str(actions[0].id) \
        and source_evidence.owner_activity_basis=="completed_granted_strike" and source_evidence.owner_cut=="source_actor_before_row",seat+": only this completed repeat witnesses its actual prior grant owner")
    var immutable:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
    var phase:Resource=load(Effects.choice(component.native_clip).approaches[0].source_phase)
    var sealed:PackedByteArray=var_to_bytes(phase.to_clip())
    var start:float=float(row.start_ms);var end:float=float(row.end_ms);var during:float=start+150.0
    check(is_finite(start) and is_finite(end) and is_equal_approx(end-start,440.0),seat+": actual finite repeat duration remains .44seconds")
    if not is_finite(start) or not is_finite(end):return
    var media:Dictionary=Media.plan(index)
    check(media.errors.is_empty(),seat+": original full media/source closure resolves")
    if not media.errors.is_empty():return
    Play.Catalog.adopt_snapshot(index.cache,media.source_files)
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true;world.media_warmup.budget_bytes=0
    world.media_warmup.encounter_override=media;world.catalog_cache=Play.Catalog.source_snapshot(index.cache)
    world.playback_end_ms=index.presentation_end_ms;world.native_startup_plan=Play.NativeStartup.recording_plan(index.rows)
    world.native_startup_requested_ms=maxf(0.0,start-2.0);world.component_renderer.audio.set_enabled(false);view.add_child(world)
    var native:RefCounted=world.component_renderer.native_spells
    var previous:WeakRef;var pass_index:int=0
    for at in [maxf(0.0,start-2.0),during,end+2.0,maxf(0.0,start-2.0),during]:
        world.install_playback(Recording.restore(index,at))
        var active:bool=is_equal_approx(at,during)
        var prepared:bool=await Prepared.settle(self,world,[component.id] if active else [])
        check(prepared,seat+": ordinary actual source/recipient prepares at "+str(at))
        if not prepared:break
        if previous!=null:check(previous.get_ref()==null,seat+": reverse seek releases the previous private finite repeat")
        if not active:
            check(not world.displayed_components.any(func(actual):return actual.id==component.id) \
                and native.witnesses.all(func(witness):return witness.id!=component.id or witness.get("status")!="rendered"),seat+": no repeat contact draws outside its actual interval")
            if native.handles.has(component.id):check(not native.handles[component.id].root.is_visible_in_tree(),seat+": retained preparation is hidden before/after the finite contact")
            previous=null;continue
        check(native.handles.has(component.id),seat+": actual result has a private finite source")
        if not native.handles.has(component.id):continue
        for quarter in ([0,1,2,3] if pass_index==0 else [0]):
            world.request_view(quarter)
            var deadline:int=Time.get_ticks_msec()+45000
            while world.rotation_pending() and Time.get_ticks_msec()<deadline:await frame()
            var published:bool=not world.rotation_pending() and world.quarter==quarter and world.world_quarter==quarter
            check(published,seat+": actual prepared camera and receiving quarter publish "+str(quarter))
            if not published:break
            prepared=await Prepared.settle(self,world,[component.id])
            check(prepared,seat+": repeat's actual source and measured endpoints prepare in view "+str(quarter))
            if not prepared:break
            var handle:Dictionary=native.handles[component.id]
            var programs:Array=handle.occurrence.input_receivers.get("set_strike_input",[])
            check(programs.size()==1,seat+": one actual sealed source consumes the repeated strike")
            if programs.size()!=1:continue
            var program:Node3D=programs[0]
            var owner:Dictionary=component.native_inputs.owner_input;var strike:Dictionary=component.native_inputs.strike_input
            check(program.strike==strike and program.retained_owner==owner and program.payload_admitted() \
                and program.owner_admitted() and not program.healing_admitted(),seat+": exact owner/critical result admits repeat contact without successful fixture healing")
            check(program.settings.owner_uuid==OWNER and owner.condition_uuid==OWNER \
                and program.settings.attack_uuid==str(actions[0].id) and strike.damage_fact_uuid==str(damage[0].id) \
                and strike.outcome=="critical" and strike.behavior_id==ACTION,seat+": exact granted-action/owner/result identities reach constructor and setters")
            check(world.timeline.state.actors[CASTER].conditions.any(func(member):return member.condition_uuid==OWNER) \
                and program.settings.condition.is_empty() and program.settings.tick.is_empty() \
                and program.settings.healing.is_empty() and program.settings.item_uuid.is_empty(),seat+": actual current owner is present and unrelated review outcomes/item remain empty")
            var geometry:Dictionary=program.recipient_surface()
            check(program.endpoints.size()==2 and program.endpoints[0].actor_uuid==CASTER \
                and program.endpoints[1].actor_uuid==TARGET and geometry.get("actor")==TARGET \
                and not geometry.get("points",[]).is_empty() and not program.contact().is_empty(),seat+": actual caster hand and enemy depth/normal geometry drive the contact")
            if program.endpoints.size()==2:check(program.endpoints[0].point.is_equal_approx(handle.endpoints.hand),seat+": source uses the actual measured caster hand")
            var bindings:Dictionary=native.diagnostics.get(component.id,{}).get("input_bindings",{})
            check(bindings.get("unavailable",{}).is_empty() and ["owner_input","strike_input"].all(func(channel):return channel in bindings.get("supplied",[])) \
                and bindings.get("not_applicable",{}).keys().all(func(channel):return channel in ["healing_input","condition_input","tick_input"]) \
                and bindings.get("not_applicable",{}).size()==3,seat+": actual owner/strike are supplied and only the three unused source phases are N/A")
            var observation:Dictionary=program.capture_observation()
            check(observation.smite.visible_meshes>0 and not observation.vampiric_touch.new_cast \
                and native.witnesses.any(func(witness):return witness.id==component.id and witness.status=="rendered"),seat+": original repeat draws native contact without declaring a new cast")
            world.camera_focus=Play.Placement.contact({"position":component.to_position,"base_height_steps":float(component.get("to_elevation_feet",0.0))/5.0})
            world.camera.size=4;world.initial_focus=true;world.position_camera();world.grid_visible=false
            await frame();await frame();world.set_process(false)
            var canonical:PackedByteArray=var_to_bytes(world.timeline.state)
            var shown:Image=view.get_texture().get_image();Effects.hide(handle);await frame();await frame()
            var hidden:Image=view.get_texture().get_image();var pixels:int=changed(shown,hidden)
            check(pixels>0,seat+": finite repeat independently contributes native framebuffer pixels in view "+str(quarter))
            check(var_to_bytes(world.timeline.state)==canonical and world.timeline.display_ms==at,seat+": source-hidden control cannot apply damage/healing or advance time")
            var label:String=seat+"-pass"+str(pass_index)+"-q"+str(quarter)
            check(shown.save_png(OUTPUT+"/"+label+"-present.png")==OK and hidden.save_png(OUTPUT+"/"+label+"-hidden.png")==OK,seat+": actual native source comparison saved")
            evidence.append({"seat":seat,"pass":pass_index,"at_ms":at,"quarter":world.quarter,"published_quarter":world.world_quarter,
                "changed_pixels":pixels,"owner":owner,"strike":strike,"evidence":source_evidence,"recipient_points":geometry.points.size()})
            handle.root.show();world.set_process(true);previous=weakref(handle.root)
        pass_index+=1
    world.install_playback(Recording.restore(index,index.presentation_end_ms))
    var ended:bool=await Prepared.settle(self,world)
    check(ended,seat+": actual final prefix prepares")
    check(Compare.difference(world.timeline.state,journal.state).is_empty() \
        and not world.timeline.state.actors[CASTER].conditions.any(func(member):return member.condition_uuid==OWNER),seat+": final actual removal and independent canonical fold are preserved")
    check(var_to_bytes(phase.to_clip())==sealed and var_to_bytes([index.initialization,index.groups,index.rows])==immutable,seat+": rendering/seek/loop preserve sealed materials and actual event clocks")
    native.close(world)
    check(native.handles.is_empty() and native.groups.is_empty() and native.prepared_layers.is_empty() \
        and (previous==null or previous.get_ref()==null),seat+": teardown releases private repeat and held source owners")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),seat+": no presentation/resource error is hidden")
    view.queue_free();await frame();await frame()
