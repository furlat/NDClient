extends "res://tests/native_vampiric_touch_render_checks.gd"
## Actual disclosed water/Wet owners through ordinary production replay.
## No native created/removal fact exists: only held-source output is qualified.
const NativeJournal=preload("res://sdk/journal.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const RecordingMedia=preload("res://studio/recording_media.gd")
const WATER_DIRECTORY="res://tests/fixtures/schema16/water-source-provider"
const WATER_UUID="939c2874-27d3-4b6e-9596-195cfbc4a1ea"
const WET_UUID="dede53e7-00f4-44ab-a4b1-e9a7bbf785e3"
const WET_KEY="unbound:dnd.spatial.environmental_conditions.Wet"
const WATER_CLIP="bg3-36/create-or-destroy-water/create"
const WET_CLIP="bg3-36/create-or-destroy-water/rain-wet"
const CELLS=[[4,7],[5,6],[5,7],[5,8],[6,5],[6,6],[6,7],[6,8],[6,9],[7,6],[7,7],[7,8],[8,7]]
const CAPTURES="res://.runtime/water-source-provider/native-captures"
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    DirAccess.make_dir_recursive_absolute(CAPTURES)
    for seat in ["amber","blue"]:await qualify_water_seat(seat)
    finish()
func qualify_water_seat(seat:String)->void:
    var directory:String=WATER_DIRECTORY.path_join(seat).path_join("journal")
    var index:Dictionary=Recording.read(directory)
    check(index.ok,seat+" complete original water journal compiles through production sources")
    if not index.ok:return
    var reference:RefCounted=NativeJournal.new()
    var opened:Dictionary=reference.open(directory,true)
    check(opened.ok,seat+" independent raw-journal reducer admits the original prefix")
    if not opened.ok:return
    var final_state:Dictionary=reference.state
    check(final_state.senses!=null and final_state.senses.spatial_effects.has(WATER_UUID),seat+" raw original discloses the exact water owner")
    if final_state.senses==null or not final_state.senses.spatial_effects.has(WATER_UUID):return
    check(final_state.senses.spatial_effects[WATER_UUID].positions==CELLS,seat+" independent13cell footprint oracle")
    var recipients:Array=final_state.actors.keys().filter(func(actor):return final_state.actors[actor].conditions.any(func(member):return member.condition_uuid==WET_UUID))
    check(recipients.size()==1,seat+" raw journal admits one distinct actual Wet recipient")
    if recipients.size()!=1:return
    var recipient:String=recipients[0]
    var member:Dictionary=final_state.actors[recipient].conditions.filter(func(value):return value.condition_uuid==WET_UUID)[0]
    check(member.behavior_id==null and member.state.semantic_key==WET_KEY,seat+" semantic source admission preserves null canonical behavior identity")
    var media:Dictionary=RecordingMedia.plan(index)
    check(media.errors.is_empty(),seat+" ordinary Studio media plan has no source-closure errors")
    if not media.errors.is_empty():return
    Play.Catalog.adopt_snapshot(index.cache,media.source_files)
    var view:=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;view.audio_listener_enable_3d=false;root.add_child(view)
    var world:Node=Play.new();world.external_playback=true;world.external_clock=true
    world.media_warmup.budget_bytes=0;world.media_warmup.encounter_override=media
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache)
    world.native_startup_plan=Play.NativeStartup.recording_plan(index.rows)
    var held:float=float(index.presentation_end_ms)+1100.0
    world.native_startup_requested_ms=held;world.playback_end_ms=held+9000.0
    world.component_renderer.audio.set_enabled(false);view.add_child(world)
    var old_owners:Array=[]
    # Actual initial state, forward seek, reverse seek and two fresh held epochs.
    for pass_number in 5:
        var at:float=[0.0,held,0.0,held,held+5000.0][pass_number]
        world.install_playback(Recording.restore(index,at))
        if not await settle(world,"condition:"+WET_UUID+":authored:0" if at>0.0 else ""):break
        for previous in old_owners:check(previous.get_ref()==null,seat+" replay replacement releases its previous private source owner")
        old_owners=[]
        check(world.timeline.display_ms==at,seat+" native preparation does not move the shared replay clock")
        var expected:Dictionary=index.initialization.state if at==0.0 else final_state
        check(Compare.difference(world.timeline.state,expected).is_empty(),seat+" independent original canonical prefix matches after seek/loop "+str(at))
        var native:RefCounted=world.component_renderer.native_spells
        if at==0.0:
            check(not world.timeline.state.senses.spatial_effects.has(WATER_UUID),seat+" initial prefix has no future water member")
            check(owned(native,WATER_UUID,WATER_CLIP).is_empty() and owned(native,WET_UUID,WET_CLIP).is_empty(),seat+" preparation cannot expose future water or Wet sources")
            continue
        var water:Array=owned(native,WATER_UUID,WATER_CLIP)
        var wet:Array=owned(native,WET_UUID,WET_CLIP)
        check(water.size()==1,seat+" exact actual spatial UUID owns one visible source")
        check(wet.size()==1,seat+" exact actual null-behavior Wet UUID owns one visible source")
        if water.size()!=1 or wet.size()!=1:
            missing_owner_diagnostic(world,index,seat,at,water,wet)
            break
        check_water_program(world,water[0],seat)
        check_wet_program(world,wet[0],recipient,seat)
        var canonical:PackedByteArray=var_to_bytes(world.timeline.state)
        if pass_number==1:
            for quarter in [0,1,2,3]:
                world.request_view(quarter)
                var deadline:int=Time.get_ticks_msec()+45000
                while world.rotation_pending() and Time.get_ticks_msec()<deadline:await frame()
                check(not world.rotation_pending() and world.quarter==quarter and world.world_quarter==quarter,seat+" actual camera quarter publishes "+str(quarter))
                if not await settle(world,"condition:"+WET_UUID+":authored:0"):break
                var actual_water:Array=owned(native,WATER_UUID,WATER_CLIP)
                var actual_wet:Array=owned(native,WET_UUID,WET_CLIP)
                check(actual_water.size()==1 and actual_wet.size()==1,seat+" both source owners survive actual view publication")
                if actual_water.size()!=1 or actual_wet.size()!=1:
                    missing_owner_diagnostic(world,index,seat,at,actual_water,actual_wet);break
                check(actual_water[0].root==water[0].root and actual_wet[0].root==wet[0].root,seat+" view change retains exact private source owners")
                await pixel_probe(world,view,actual_water[0],seat,"water",quarter,pass_number,6.0)
                await pixel_probe(world,view,actual_wet[0],seat,"wet",quarter,pass_number,4.0)
                check(var_to_bytes(world.timeline.state)==canonical,seat+" view/native visibility probes preserve the complete canonical state")
        else:
            await pixel_probe(world,view,water[0],seat,"water",world.quarter,pass_number,6.0)
            await pixel_probe(world,view,wet[0],seat,"wet",world.quarter,pass_number,4.0)
        old_owners=[weakref(water[0].root),weakref(wet[0].root)]
        check(var_to_bytes(world.timeline.state)==canonical,seat+" source output changes no condition, spatial cell or owner lifetime")
    var native:RefCounted=world.component_renderer.native_spells
    native.close(world)
    check(native.handles.is_empty() and native.groups.is_empty() and native.prepared_layers.is_empty(),seat+" explicit close releases private source owners and render passes")
    for previous in old_owners:check(previous.get_ref()==null,seat+" final private source is freed on close")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),seat+" full native replay reports no presentation/resource errors")
    var owner:WeakRef=weakref(world)
    view.queue_free();await frame();await frame()
    check(owner.get_ref()==null,seat+" viewport cleanup releases the ordinary Play owner")
func missing_owner_diagnostic(world:Node,index:Dictionary,seat:String,at:float,water:Array,wet:Array)->void:
    var native:RefCounted=world.component_renderer.native_spells
    var handles:Array=[]
    for handle in native.handles.values():
        var component:Dictionary=handle.component
        handles.append({"id":component.id,"clip":component.get("native_clip",{}).get("id"),
            "visible":handle.root.is_visible_in_tree(),"status":component.get("status"),"reason":component.get("reason"),
            "condition_uuid":component.get("condition",{}).get("condition_uuid"),"condition":component.get("condition",{}),
            "native_inputs":component.get("native_inputs",{}),"membership_input":component.get("native_cue",{}).get("membership_input"),
            "diagnostic":native.diagnostics.get(component.id,{})})
    var samples:Array=world.timeline.component_samples(world.catalog_cache).filter(func(component):
        return component.get("condition",{}).get("condition_uuid")==WET_UUID or component.get("native_clip",{}).get("id")==WET_CLIP)
    var compiled:Array=index.rows.filter(func(row):
        return row.get("condition_uuid")==WET_UUID or row.get("component",{}).get("condition",{}).get("condition_uuid")==WET_UUID             or row.get("component",{}).get("native_clip",{}).get("id")==WET_CLIP)
    var diagnostic:Dictionary={"seat":seat,"at_ms":at,"water_visible_count":water.size(),"wet_visible_count":wet.size(),
        "wet_owner":world.timeline.condition_owners.get(WET_UUID,{}),"wet_samples":samples,"compiled_wet_rows":compiled,"handles":handles}
    evidence.append({"kind":"missing_owner_diagnostic","value":diagnostic})
    FileAccess.open("res://.runtime/water-source-provider/native-wet-missing-"+seat+".json",FileAccess.WRITE).store_string(JSON.stringify(diagnostic,"  ")+"\n")
    print("NATIVE_WATER_MISSING_OWNER ",JSON.stringify(diagnostic))
func owned(native:RefCounted,identity:String,clip:String,visible_only:bool=true)->Array:
    return native.handles.values().filter(func(handle):
        var component:Dictionary=handle.component
        var actual:String=str(component.get("spatial_effect_uuid",component.get("condition",{}).get("condition_uuid","")))
        return actual==identity and component.get("native_clip",{}).get("id")==clip and (not visible_only or handle.root.is_visible_in_tree()))
func check_water_program(world:Node,handle:Dictionary,seat:String)->void:
    var component:Dictionary=handle.component
    check(component.actor_uuid==null and component.target_uuid==null and component.spatial_effect_uuid==WATER_UUID,seat+" water constructor invents no character endpoint")
    check(component.resolved_area_positions==CELLS and is_inf(float(component.duration_ms)),seat+" native surface uses exact cells and no invented expiry")
    check(not component.spatial_creation_observed and float(component.age_ms)>=3500.0,seat+" original disclosure cannot replay creation rain")
    var programs:Array=handle.occurrence.input_receivers.get("set_surface_records",[])
    check(programs.size()==1,seat+" original source constructor owns one immutable coverage receiver")
    if programs.size()!=1:return
    var program:Node=programs[0]
    check(program.prepared and program.groups.size()==1 and program.records.size()==1,seat+" actual original native program constructed one disclosed group")
    check(program.records==component.spatial_surface_records and program.records[0].source_uuid==WATER_UUID,seat+" renderer uses the exact constructor-admitted source records")
    var actual_cells:Array=program.records[0].cells.map(func(cell):return [cell[0]+component.position[0],cell[1]+component.position[1]])
    check(actual_cells==CELLS and program.records[0].points.size()==160,seat+" native source maps13real cells and160optical samples to the original footprint")
    check(float(program.last_seconds)>=3500.0/1000.0 and program.groups.all(func(group):return not group.drops.visible),seat+" held source contributes puddle without fabricated rainfall")
    var bindings:Dictionary=world.component_renderer.native_spells.diagnostics.get(component.id,{}).get("input_bindings",{})
    check(bindings.get("unavailable",{}).is_empty() and "surface_records" in bindings.get("supplied",[]),seat+" actual required immutable coverage channel resolves")
    check(handle.area_mask.positions==CELLS,seat+" actual renderer AreaMask matches disclosed source cells")
func check_wet_program(world:Node,handle:Dictionary,recipient:String,seat:String)->void:
    var component:Dictionary=handle.component
    check(component.condition.condition_uuid==WET_UUID and component.condition.behavior_id==null and component.condition.state.semantic_key==WET_KEY,seat+" native Wet selection preserves exact original member identity")
    check(component.actor_uuid==recipient and component.target_uuid==recipient and is_inf(float(component.duration_ms)),seat+" actual recipient owns the held source with no fabricated removal")
    var programs:Array=handle.occurrence.input_receivers.get("set_wet_presence",[])
    check(programs.size()==1,seat+" original runoff program receives declared Wet membership")
    if programs.size()!=1:return
    var program:Node=programs[0]
    check(program.wet_present and not program.geometry.get("points",[]).is_empty(),seat+" actual held membership and current measured body geometry admit runoff")
    var observation:Dictionary=program.capture_observation()
    check(observation.wet_presence_supplied and not observation.owns_rounds and not observation.owns_reveal,seat+" source has no invented rule clock or reveal authority")
    var bindings:Dictionary=world.component_renderer.native_spells.diagnostics.get(component.id,{}).get("input_bindings",{})
    check(bindings.get("unavailable",{}).is_empty() and handle.clip.inputs.all(func(channel):return channel in bindings.get("supplied",[])),seat+" every actually declared Wet input resolves")
func pixel_probe(world:Node,view:SubViewport,handle:Dictionary,seat:String,kind:String,quarter:int,pass_number:int,size:float)->void:
    var position:Array=[6,7]
    if kind=="wet":position=world.timeline.state.actors[handle.component.actor_uuid].last_visual_position
    world.camera_focus=Play.Placement.contact({"position":position,"base_height_steps":float(handle.component.get("elevation_feet",0.0))/5.0})
    world.camera.size=size;world.initial_focus=true;world.position_camera();world.grid_visible=false
    await frame();await frame();world.set_process(false)
    var state:PackedByteArray=var_to_bytes(world.timeline.state)
    var shown:Image=view.get_texture().get_image()
    Effects.hide(handle);await frame();await frame()
    var hidden:Image=view.get_texture().get_image()
    var pixels:int=changed(shown,hidden)
    check(pixels>0,seat+" original native "+kind+" contributes framebuffer pixels q"+str(quarter)+" pass"+str(pass_number))
    handle.root.show();await frame();await frame()
    var restored:Image=view.get_texture().get_image()
    check(changed(restored,hidden)>0 and handle.root.is_visible_in_tree(),seat+" same private "+kind+" source restores visible output")
    check(var_to_bytes(world.timeline.state)==state,seat+" "+kind+" draw probe changes no canonical fact")
    var name:String=seat+"-"+kind+"-q"+str(quarter)+"-pass"+str(pass_number)
    shown.save_png(CAPTURES.path_join(name+".png"))
    evidence.append({"seat":seat,"kind":kind,"quarter":quarter,"published_quarter":world.world_quarter,"pass":pass_number,
        "owner_uuid":WATER_UUID if kind=="water" else WET_UUID,"clip":handle.clip.id,"changed_pixels":pixels,
        "source_age_seconds":handle.age,"display_ms":world.timeline.display_ms,"capture":CAPTURES.path_join(name+".png")})
    world.set_process(true)
func finish()->void:
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Original independent Amber/Blue water surface and null-behavior Wet owners through ordinary production Play/Recording, actual required inputs, immutable constructor coverage, measured body geometry, source-hidden/restored pixels in actual camera quarters, canonical reverse-seek/loop and teardown. No native creation/rainfall or Wet/water removal facts exist in this original; these branches, performance and user visual approval remain unqualified."}
    FileAccess.open("res://.runtime/water-source-provider/native-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
    print("NATIVE_WATER_SOURCE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
