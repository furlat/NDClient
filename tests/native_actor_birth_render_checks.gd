extends "res://tests/native_vampiric_touch_render_checks.gd"
## Three real actor births, independently reduced from both original seats.
## Ordinary Play owns publication, source setters and native rendering. The
## authored creature rigs are stand-ins; visible bodies do not qualify final art.
const Journal=preload("res://sdk/journal.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const Sockets=preload("res://presentation/spell_placement.gd")
const CASES={
    "air-elemental":{"actor":"615e48e0-09ab-4063-8157-bd1be68e2981","form":"air_elemental","namespace":"content.srd_5_1_cc"},
    "deva":{"actor":"ec65bbc6-f89d-4c39-ae06-82aa3ae18904","form":"deva","namespace":"content.srd_5_1_cc"},
    "draconic-spirit":{"actor":"92a47894-dfc0-4cd2-b482-e0c88ffb3853","form":"draconic_spirit","namespace":"content.srd_5_2_cc"}}

func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute("res://.runtime/actor-birth-captures")
    for name in CASES:
        for seat in ["amber","blue"]:await birth_seat(name,seat)
    finish()

func birth_seat(name:String,seat:String)->void:
    var label:String=name+"/"+seat
    var directory:String="res://tests/fixtures/schema16/scenarios/actor-birth-"+name+"/"+seat
    var journal:RefCounted=Journal.new()
    var opened:Dictionary=journal.open(directory,true,true)
    check(opened.ok,label+" independent original seat reduces through its actual admission")
    if not opened.ok:return
    var reference:Dictionary=journal.state
    var identity:String=CASES[name].actor
    check(reference.actors.has(identity),label+" original canonical journal actually admits the expected actor")
    if not reference.actors.has(identity):return
    var creature:String="creature.spell."+str(CASES[name].form)
    check(reference.actors[identity].get("creature_content_ref")==str(CASES[name].namespace)+":creature:"+creature+"@1",label+" independent original body supplies the exact native creature identity")
    var index:Dictionary=Recording.read(directory)
    check(index.ok,label+" original recording compiles through production")
    if not index.ok:return
    var rows:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_actor_birth",{}).get("actor_uuid")==identity)
    check(rows.size()==1,label+" exactly one actual actor admission owns a manifestation")
    if rows.size()!=1:return
    var row:Dictionary=rows[0];var component:Dictionary=row.component
    check(component.status=="available" and component.actor_uuid!=identity and component.target_uuid==identity,label+" original caster and receiving born actor remain distinct")
    var original:PackedByteArray=var_to_bytes(component)
    var phase:Resource=load(Effects.choice(component.native_clip).approaches[0].source_phase)
    var sealed:PackedByteArray=var_to_bytes(phase.to_clip())
    var start:float=float(row.start_ms);var during:float=start+900.0
    check(during<float(row.end_ms),label+" requested sample lies inside the full original birth window")
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true;world.media_warmup.budget_bytes=0
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.playback_end_ms=index.presentation_end_ms
    world.component_renderer.audio.set_enabled(false);view.add_child(world)
    var previous:WeakRef
    var canonical:PackedByteArray=PackedByteArray()
    for pass_index in 2:
        var rewind:float=maxf(0.0,start-2.0)
        world.install_playback(Recording.restore(index,rewind))
        if not await settle(world):await close_birth(world,view,label);return
        if previous!=null:check(previous.get_ref()==null,label+" reverse seek frees the preceding native occurrence")
        check(not world.timeline.state.actors.has(identity) or not world.timeline.state.actors[identity].present,label+" reverse seek restores actual pre-admission canonical actor membership")
        var before_native=world.component_renderer.native_spells
        check(before_native.witnesses.all(func(witness):return witness.id!=component.id),label+" prepared future source has no pre-admission draw witness")
        if before_native.handles.has(component.id):
            check(not before_native.handles[component.id].root.is_visible_in_tree(),label+" future source remains optically hidden before original admission")
        world.install_playback(Recording.restore(index,during))
        if not await settle(world,component.id):await close_birth(world,view,label);return
        check(world.timeline.state.actors.has(identity) and world.timeline.state.actors[identity].present,label+" original admission is now actually published")
        if not world.timeline.state.actors.has(identity):await close_birth(world,view,label);return
        check(Compare.difference(world.timeline.state.actors[identity],reference.actors[identity]).is_empty(),label+" displayed born actor equals this seat's independent original canonical fold")
        if pass_index==0:canonical=var_to_bytes(world.timeline.state)
        else:check(var_to_bytes(world.timeline.state)==canonical,label+" looping restores exactly the same canonical source/actor prefix")
        var native=world.component_renderer.native_spells
        check(native.handles.has(component.id),label+" ordinary native preparation constructs the actual manifestation")
        if not native.handles.has(component.id):await close_birth(world,view,label);return
        var handle:Dictionary=native.handles[component.id]
        var programs:Array=handle.occurrence.input_receivers.get("set_owner_state",[])
        check(programs.size()==1,label+" one sealed manifestation receives the actual owner state")
        if programs.size()!=1:await close_birth(world,view,label);return
        var program:Node3D=programs[0]
        check(program.specification.owner_uuid==identity and program.specification.birth_event_uuid==component.native_actor_birth.birth_occurrence,label+" constructor receives actual actor and local native birth identities")
        check(program.specification.form==creature and component.native_actor_birth.creature_id==creature \
            and program.specification.review_states.is_empty(),label+" exact original native creature identity retains no fixture review lifecycle")
        check(program.specification.initial_state=={"owner_uuid":identity,"birth_admitted":false,"observed":false,"suppressed":false},label+" private construction starts optically inactive")
        check(program.supplied_state=={"owner_uuid":identity,"birth_admitted":true,"observed":true,"suppressed":false},label+" actual published and displayed born actor admits the source")
        check(not program.supplied_state.has("terminal_event_uuid"),label+" no undisclosed terminal UUID is fabricated")
        var bindings:Dictionary=native.diagnostics.get(component.id,{}).get("input_bindings",{})
        var requested:Array=component.native_clip.inputs;var supplied:Array=bindings.get("supplied",[])
        check("owner_state" in requested and "owner_state" in supplied and bindings.get("unavailable",{}).is_empty() \
            and requested.all(func(channel):return channel in supplied) and supplied.all(func(channel):return channel in requested),label+" all and only actual declared native inputs are supplied")
        check(Sockets.displayed(world.visual_actors.get(identity,{})),label+" ordinary actor renderer displays the authored creature stand-in")
        var quarters:Array=[0,1,2,3] if pass_index==0 else [0]
        for quarter in quarters:
            world.request_view(quarter)
            var deadline:int=Time.get_ticks_msec()+45000
            while world.rotation_pending() and Time.get_ticks_msec()<deadline:await frame()
            check(world.quarter==quarter and world.world_quarter==quarter and not world.rotation_pending(),label+" actual view publishes quarter "+str(quarter))
            if not await settle(world,component.id):await close_birth(world,view,label);return
            check(native.handles.has(component.id) and native.handles[component.id].occurrence==handle.occurrence,label+" camera quarter preserves the actual birth occurrence owner")
            if not world.visual_actors.has(identity):
                check(false,label+" born actor has no actual visual row: "+str(world.timeline.state.actors[identity]));continue
            var visual:Dictionary=world.visual_actors[identity]
            var ground:Vector3=Play.Placement.contact(visual.row)
            check(program.endpoints.size()==1 and program.endpoints[0].actor_uuid==identity and program.endpoints[0].socket=="ground",label+" one actual born-actor ground endpoint is supplied")
            if program.endpoints.size()==1:
                check(program.endpoints[0].point.is_equal_approx(ground),label+" manifestation uses the renderer's actual born-actor ground registration")
            var observation:Dictionary=program.capture_observation().summon_manifestation
            check(observation.owner_uuid==identity and observation.birth_event_uuid==component.native_actor_birth.birth_occurrence \
                and observation.body_is_separate and not observation.body_binding_available,label+" native source never substitutes an invented actor body")
            var visible:Array=program.pieces.filter(func(piece):return piece.root.is_visible_in_tree())
            check(not visible.is_empty() and visible.all(func(piece):return piece.definition.kind=="birth"),label+" actual source submits birth geometry, no terminal artwork")
            check(visible.all(func(piece):return piece.root.global_position.is_equal_approx(ground)),label+" native birth composition is centered on actual ground in every quarter")
            world.camera_focus=ground;world.camera.size=6;world.initial_focus=true;world.position_camera();world.grid_visible=false
            await frame();await frame();world.set_process(false)
            var present:Image=view.get_texture().get_image()
            Effects.hide(handle);await frame();await frame()
            var absent:Image=view.get_texture().get_image()
            var pixels:int=changed(present,absent)
            check(pixels>0,label+" exact actual birth source contributes framebuffer pixels, quarter "+str(quarter))
            var stem:String="res://.runtime/actor-birth-captures/"+name+"-"+seat+"-"+str(pass_index)+"-q"+str(quarter)
            check(present.save_png(stem+"-present.png")==OK and absent.save_png(stem+"-absent.png")==OK,label+" original source-present/hidden captures saved")
            check(var_to_bytes(world.timeline.state)==canonical and var_to_bytes(component)==original \
                and var_to_bytes(phase.to_clip())==sealed,label+" rotation/drawing/hiding preserve canonical state, occurrence operands and sealed source preset")
            evidence.append({"case":name,"seat":seat,"pass":pass_index,"quarter":quarter,"at_ms":during,
                "actor_uuid":identity,"birth_occurrence":component.native_actor_birth.birth_occurrence,"ground":[ground.x,ground.y,ground.z],
                "changed_pixels":pixels,"source_observation":observation,"capture":stem+"-present.png"})
            handle.root.show();world.set_process(true)
        previous=weakref(handle.root)
    await close_birth(world,view,label)
    check(previous==null or previous.get_ref()==null,label+" final native birth owner is released after teardown")

func close_birth(world:Node,view:SubViewport,label:String)->void:
    var native=world.component_renderer.native_spells
    native.close(world)
    check(native.handles.is_empty() and native.groups.is_empty() and native.prepared_layers.is_empty(),label+" teardown releases source handles and native render owners")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),label+" original birth replay has no presentation/resource errors")
    view.queue_free();await frame();await frame()

func finish()->void:
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Three actual born-actor arrival VFX selections, both original seats, ordinary Play stand-in body/ground/input/source/native framebuffer, four views and reverse seek/replay cleanup. Intended creature bodies, terminal/despawn, other summon forms, performance and human art acceptance remain unqualified."}
    FileAccess.open("res://.runtime/native-actor-birth-render-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_ACTOR_BIRTH ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
