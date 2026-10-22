extends "res://tests/native_vampiric_touch_render_checks.gd"
## One actual Fire cadence: false -> paid Multiattack ready -> accepted Breath
## false, through ordinary Play and the installed sparse mouth receiver.
const CASE="condition.summon.draconic_breath_cadence/multiattack_breath_readiness"
const CONDITION="condition.summon.draconic_breath_cadence"
const DEFAULT_INDEX="res://.runtime/dragon-mouth-client-20261022/recordings/index.json"
const OUTPUT="res://.runtime/dragon-mouth-client-20261022/native"
var caption:Label

func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("NATIVE_DRAGON_MOUTH_FAIL ",label)

func read_json(path:String)->Dictionary:
    if not FileAccess.file_exists(path):check(false,"Input exists: "+path);return {}
    var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
    if not value is Dictionary:check(false,"Input is an object: "+path);return {}
    return value

func readiness_interval(index:Dictionary)->Dictionary:
    var result:Dictionary={}
    for item in index.groups:
        for commit in item.group.commits:
            for actor_id in commit.delta.get("actors",{}):
                var actor:Variant=commit.delta.actors[actor_id]
                if actor==null:continue
                for member in actor.get("conditions",[]):
                    if member.get("behavior_id")!=CONDITION:continue
                    var state:Variant=member.get("state")
                    if not state is Dictionary or not state.get("ready") is bool:continue
                    var at:float=float(item.start_ms)+float(commit.at_ms)
                    if result.is_empty() and state.ready:
                        result={"actor":actor_id,"condition":member.condition_uuid,"breath":state.breath_type,
                            "ready_from":at,"ready_event":str(commit.get("event_uuid",""))}
                    elif not result.is_empty() and member.condition_uuid==result.condition and not state.ready:
                        result.ready_until=at;result.retired_event=str(commit.get("event_uuid",""));return result
    return result

func member(state:Dictionary,interval:Dictionary)->Dictionary:
    for value in state.get("actors",{}).get(interval.actor,{}).get("conditions",[]):
        if value.condition_uuid==interval.condition:return value
    return {}

func cadence(world:Node,interval:Dictionary)->Dictionary:
    for component in world.displayed_components:
        if component.get("condition_uuid")==interval.condition \
                and component.get("native_readiness_gate",{}).get("schema")=="vfxfactory.public_condition_readiness.v1":return component
    return {}

func advance(world:Node,at_ms:float)->bool:
    var plan:Dictionary=world.timeline.replay_plan(at_ms)
    var deadline:int=Time.get_ticks_msec()+45000
    while Time.get_ticks_msec()<deadline and world.presentation_errors.is_empty() and world.media_issue.is_empty():
        if world.timeline.replay_prepare(plan) and world.can_publish_replay_advance(plan):
            var published:bool=world.publish_replay_advance(plan)
            await frame()
            check(published,"Original replay boundary publishes at "+str(at_ms))
            return published
        await frame()
    check(false,"Original replay boundary did not publish: "+str(at_ms));return false

func run()->void:
    root.title="NDClient · Dragon mouth native check"
    root.unfocusable=true;root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute(OUTPUT)
    caption=Label.new();caption.text="Checking actual recorded Dragon mouth readiness";caption.position=Vector2(12,12)
    var path:String=DEFAULT_INDEX
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--index="):path=argument.trim_prefix("--index=")
    var library:Dictionary=read_json(path)
    var package:Dictionary=read_json("res://assets/vfx/index.json")
    var selected:Array=library.get("cases",[]).filter(func(row):return row.id==CASE)
    check(selected.size()==1,"Exact newly recorded legal Multiattack/Breath case exists")
    if selected.size()!=1:finish();return
    var recorded:Dictionary=selected[0]
    check(recorded.get("status")=="recorded" and recorded.get("engine",library.get("engine",{})).get("player_schema_version")==18,"Actual case retains current producer schema and successful capture")
    var directory:String=recorded.get("journals",{}).get("amber","")
    var index:Dictionary=Recording.read(directory)
    check(index.ok,"Unchanged Amber original compiles through production")
    if not index.ok:evidence.append({"recording_error":index});finish();return
    var interval:Dictionary=readiness_interval(index)
    check(interval.has("ready_until") and interval.get("breath")=="Fire","Original commits contain Fire ready=true followed by ready=false on the same condition")
    if not interval.has("ready_until"):finish();return
    var length:float=float(interval.ready_until)-float(interval.ready_from)
    check(length>0.0,"Actual ready state has a nonzero recorded display interval")
    if length<=0.0:finish();return
    # Inside the original post-Multiattack/pre-Breath interval, never a made-up
    # condition state, publication revision or independent native source clock.
    var ready_at:float=float(interval.ready_until)-minf(100.0,length*.5)
    var retired_at:float=float(interval.ready_until)+.001
    var restored:RefCounted=Recording.restore(index,ready_at)
    check(member(restored.state,interval).get("state",{}).get("ready",false),"Selected ordinary timeline time really contains ready=true")
    var condition_source:Resource=load("res://authoring/abilities/conditions/"+CONDITION+".tres")
    var region:Dictionary=condition_source.lifecycle_geometry.region
    check(index.cache.has(region.table) and index.cache.has(region.receiver_inputs),"Original compilation admits mouth and constructor documents before scene construction")
    if not index.cache.has(region.table) or not index.cache.has(region.receiver_inputs):finish();return
    var table_before:PackedByteArray=var_to_bytes(index.cache[region.table])
    var receivers_before:PackedByteArray=var_to_bytes(index.cache[region.receiver_inputs])
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var display:=TextureRect.new();display.texture=view.get_texture();display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;display.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    root.add_child(display);root.add_child(caption)
    var world=Play.new();world.external_playback=true;world.external_clock=true;world.media_warmup.budget_bytes=0
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.playback_end_ms=index.presentation_end_ms
    world.component_renderer.audio.set_enabled(false);view.add_child(world)
    world.install_playback(Recording.restore(index,0.0))
    if not await settle(world):await close_world(world,view,display);finish();return
    check(not member(world.timeline.state,interval).get("state",{}).get("ready",true),"Initial actual condition is publicly not ready")
    var initial_component:Dictionary=cadence(world,interval)
    var native=world.component_renderer.native_spells
    var initial_owner:Node= native.handles.get(initial_component.get("id",""),{}).get("occurrence")
    if not await advance(world,ready_at):await close_world(world,view,display);finish();return
    if not await settle(world):await close_world(world,view,display);finish();return
    check(member(world.timeline.state,interval).get("state",{}).get("ready",false),"Actual Multiattack publishes public ready=true")
    var component:Dictionary=cadence(world,interval)
    check(not component.is_empty(),"Current condition owns a public native cadence component")
    if component.is_empty():await close_world(world,view,display);finish();return
    # Rear poses are deliberately unavailable. Rotate the actual viewer until
    # an authored exposed pose is displayed; no alternative pixels are supplied.
    var mouth:Dictionary={}
    for quarter in [0,1,2,3]:
        world.request_view(quarter)
        var deadline:int=Time.get_ticks_msec()+45000
        while world.rotation_pending() and Time.get_ticks_msec()<deadline:await frame()
        if not await settle(world):break
        component=cadence(world,interval)
        if component.is_empty():continue
        mouth=native.inputs.geometry_sample(world,component,"entity_geometry")
        deadline=Time.get_ticks_msec()+10000
        while mouth.get("pending",false) and Time.get_ticks_msec()<deadline:
            await frame();mouth=native.inputs.geometry_sample(world,component,"entity_geometry")
        if mouth.get("ready",false):break
    check(mouth.get("ready",false) and mouth.get("points",[]).size()>=2,"A genuinely displayed exposed Dragon pose supplies sparse mouth geometry")
    if not mouth.get("ready",false):await close_world(world,view,display);finish();return
    if not await settle(world,component.id):await close_world(world,view,display);finish();return
    check(native.handles.has(component.id),"Ordinary native preparation owns the public cadence")
    if not native.handles.has(component.id):await close_world(world,view,display);finish();return
    var handle:Dictionary=native.handles[component.id]
    check(initial_owner!=null and handle.occurrence==initial_owner,"Initial false and actual ready publication reuse the same native owner")
    var programs:Array=handle.occurrence.input_receivers.get("set_event_state",[])
    check(programs.size()==1,"One actual public readiness source receives the condition publication")
    if programs.size()!=1:await close_world(world,view,display);finish();return
    var program:Node3D=programs[0]
    check(program.parameters.adaptive_surface.settings.slot=="body","Actual constructor uses the full delivered body receiving configuration")
    check(program.event_admitted and program.receiving.admitted_geometry and program.handle.root.visible,"Actual Fire source admits the currently published ready mouth")
    var received:Dictionary=program.receiving.current_surface
    check(received.actor==interval.actor and received.region_id=="mouth" and received.points.all(func(point):return point.slot=="body") \
        and program.event_state.mouth_surface_revision==received.region_revision,"Actual public source consumes this actor's exact mouth revision and body points")
    var canonical:PackedByteArray=var_to_bytes(world.timeline.state)
    var component_before:PackedByteArray=var_to_bytes(component)
    world.camera_focus=mouth.optical_anchor;world.camera.size=1.2;world.initial_focus=true;world.position_camera();world.grid_visible=false
    caption.text="Recorded Fire readiness · close view of actual mouth pixels"
    await frame();await frame();world.set_process(false)
    var present:Image=view.get_texture().get_image()
    Effects.hide(handle);await frame();await frame()
    var absent:Image=view.get_texture().get_image()
    var changed_pixels:int=changed(present,absent)
    var jaw:Vector2=world.camera.unproject_position(mouth.optical_anchor)
    var jaw_rect:=Rect2i(Vector2i(jaw)-Vector2i(96,96),Vector2i(192,192)).intersection(Rect2i(Vector2i.ZERO,view.size))
    var mouth_pixels:int=changed(present.get_region(jaw_rect),absent.get_region(jaw_rect)) if jaw_rect.has_area() else 0
    check(changed_pixels>0 and mouth_pixels>0,"The exact readiness source contributes framebuffer pixels at the authored jaw")
    check(present.save_png(OUTPUT+"/fire-present.png")==OK and absent.save_png(OUTPUT+"/fire-hidden.png")==OK,"Native source-present and source-hidden images are saved")
    check(var_to_bytes(world.timeline.state)==canonical and var_to_bytes(component)==component_before,"Camera framing and effect isolation preserve the original canonical state and component")
    check(var_to_bytes(world.catalog_cache[region.table])==table_before and var_to_bytes(world.catalog_cache[region.receiver_inputs])==receivers_before,"Actual native construction and sampling preserve admitted mouth and full adaptive documents")
    handle.root.show();world.set_process(true)
    caption.text="Checking accepted Breath retires the same readiness owner"
    if await advance(world,retired_at) and await settle(world):
        check(not member(world.timeline.state,interval).get("state",{}).get("ready",true),"Accepted original Breath publishes ready=false")
        check(native.handles.has(component.id) and native.handles[component.id].occurrence==initial_owner,"Accepted Breath keeps the same condition/native owner")
        check(not program.event_admitted and not program.publication_ready and not program.handle.root.visible,"Public ready=false retires actual visible readiness")
    evidence.append({"case":CASE,"seat":"amber","journal":directory,"engine":recorded.get("engine",library.engine),
        "factory_version":package.get("version",""),"interval":interval,"ready_at_ms":ready_at,"retired_at_ms":retired_at,
        "quarter":world.quarter,"mouth_points":mouth.points.size(),"changed_pixels":changed_pixels,"jaw_changed_pixels":mouth_pixels,
        "source_present":OUTPUT+"/fire-present.png","source_hidden":OUTPUT+"/fire-hidden.png"})
    await close_world(world,view,display);finish()

func close_world(world:Node,view:SubViewport,display:TextureRect)->void:
    var native=world.component_renderer.native_spells
    native.close(world)
    check(native.handles.is_empty() and native.groups.is_empty() and native.inputs.mouth_surfaces.is_empty(),"Teardown releases native and sparse mouth owners")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),"Original readiness replay has no presentation or media errors")
    display.queue_free();view.queue_free();await frame();await frame()

func finish()->void:
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Actual current producer Fire cadence false→Multiattack ready→Breath false through Play, sparse mouth receiver, source-isolated jaw framebuffer and teardown. Other palettes, finite breath VFX, performance targets and human art approval are not qualified."}
    DirAccess.make_dir_recursive_absolute(OUTPUT)
    FileAccess.open(OUTPUT+"/checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_DRAGON_MOUTH ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
