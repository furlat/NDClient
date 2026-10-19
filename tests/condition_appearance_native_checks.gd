extends "res://tests/schema16_studio_replay_checks.gd"
## Real recorded Fly actions, production body sampling, ordered outfit changes,
## independent factions, seek/loop and all four camera views.
const Appearance=preload("res://presentation/condition_appearance.gd")
const Characters=preload("res://presentation/characters.gd")
var wing_samples:int=0
var moving_wing_samples:int=0
var ordinary_samples:int=0
var rotated:bool=false
var cameras:Array=[]
var observed_studio:Control
var last_clock:float=-1.0
var stalled_since:int=0
var stall_reported:bool=false
var appearance_frames:Array=[]
var failure_reported:bool=false

func play_once(studio:Control,label:String)->void:
    observed_studio=studio
    process_frame.connect(observe_preparation)
    await super.play_once(studio,label)
    process_frame.disconnect(observe_preparation)
    observed_studio=null

func observe_preparation()->void:
    var world:Node=observed_studio.world
    if world.timeline.display_ms>4950 and not failure_reported:
        var timeline:RefCounted=world.timeline
        appearance_frames.append({"clock":timeline.display_ms,"group":timeline.current.get("id",""),"start":timeline.group_start_ms,
            "next_start":timeline.queue[0].get("preview_start_ms") if not timeline.queue.is_empty() else null,
            "owners":timeline.condition_owners.values().map(func(owner):return {"id":owner.id,"end":owner.end_ms,"appearance_end":float(owner.end_ms)+Appearance.removal_ms(owner.condition)}),
            "pending":world.pending_world!=null,"prepared_owner":world.prepared_actor_owner!=null,"plan":observed_studio.replay_plan.get("boundary")})
        if appearance_frames.size()>8:appearance_frames.pop_front()
        if world.publication_failed:
            failure_reported=true;print("APPEARANCE_PUBLICATION_FAILURE ",JSON.stringify(appearance_frames))
    if world.timeline.display_ms!=last_clock:
        last_clock=world.timeline.display_ms;stalled_since=Time.get_ticks_msec();stall_reported=false
    if stall_reported or Time.get_ticks_msec()-stalled_since<1500 or world.pending_world==null:return
    stall_reported=true
    var pending:Node=world.pending_world
    print("APPEARANCE_PREPARATION_STALL ",JSON.stringify({"at_ms":last_clock,"phase":pending.phase,"actor":pending.blocked_actor,"source":pending.blocked_source,"media":world.media_gate,"actor_resource_pending":pending.actor_resource_task>=0}))

func verify_prefix(studio:Control,label:String,allow_atomic_yield:bool=false)->void:
    super.verify_prefix(studio,label,allow_atomic_yield)
    var world:Node=studio.world
    var appearance_rows:Array=studio.index.rows.filter(func(row):return row.kind=="condition_appearance")
    check(not appearance_rows.is_empty() and appearance_rows.all(func(row):return row.component.layer.category=="Bag8" and row.trace_track_id.begins_with("condition:")),label+": Studio exposes actual outfit/opacity ownership beside body/VFX tracks")
    check(not studio.index.rows.any(func(row):return row.kind=="requirement" and row.get("reason")=="condition_appearanceLayers_not_implemented"),label+": implemented appearance does not remain a stale missing requirement")
    var expected:Array=Appearance.components(world.timeline.condition_owners,world.timeline.display_ms,world.catalog_cache)
    for actor in world.visual_actors:
        var visual:Dictionary=world.visual_actors[actor]
        var wings:Array=visual.entries.filter(func(entry):return entry.actor_layer.get("effect",{}).get("kind")=="condition_appearance")
        var requested:Array=expected.filter(func(row):return row.actor_uuid==actor)
        check(wings.size()==requested.size(),label+": actual disclosed outfit has exactly the ordered appearance membership")
        var canonical:Dictionary=world.timeline.state.actors.get(actor,{})
        if canonical.is_empty():continue
        var core:Dictionary=canonical.duplicate(false);core.presentation_layers=[]
        var gear:Dictionary=Characters.structure(core,world.catalog_cache,Characters.item_looks(core,world.timeline.state))
        if gear.ok:
            var wanted:Array=gear.value.equipment_layers.filter(func(layer):return layer.get("equipment",false)).map(func(layer):return [layer.slot,layer.item_uuid])
            var actual:Array=visual.entries.filter(func(entry):return entry.actor_layer.get("equipment",false)).map(func(entry):return [entry.actor_layer.slot,entry.actor_layer.item_uuid])
            check(actual==wanted,label+": displayed gear follows current authoritative equipment")
        if wings.is_empty():ordinary_samples+=1;continue
        var body:Array=visual.entries.filter(func(entry):return entry.actor_layer.slot=="body" and entry.node.visible)
        if body.is_empty():continue
        var pose:Vector4=body[0].material.get_shader_parameter("frame_uv")
        for entry in wings:
            if not entry.node.visible:continue
            var uv:Vector4=entry.material.get_shader_parameter("frame_uv")
            check(is_equal_approx(uv.x/uv.z,pose.x/pose.z) and is_equal_approx(uv.y/uv.w,pose.y/pose.w),label+": wings inherit actual body frame and camera-facing row")
            check(not world.displayed_components.any(func(row):return row.get("id")==entry.actor_layer.effect.component_id),label+": appearance has no independent body source track")
            if float(entry.material.get_shader_parameter("layer_alpha"))<=1.0/255.0:continue
            wing_samples+=1
            if world.displayed_samples.get(actor,{}).get("activity")=="move":moving_wing_samples+=1

func save_capture(studio:Control,label:String)->void:
    await super.save_capture(studio,label)
    if rotated:return
    var visible_wings:Array=[]
    for visual in studio.world.visual_actors.values():
        visible_wings.append_array(visual.entries.filter(func(entry):return entry.node.visible and entry.actor_layer.get("effect",{}).get("kind")=="condition_appearance" and float(entry.material.get_shader_parameter("layer_alpha"))>.1))
    if visible_wings.is_empty():return
    rotated=true
    for quarter in range(4):
        studio.world.request_view(quarter)
        var deadline:int=Time.get_ticks_msec()+10000
        while (studio.world.rotation_pending() or studio.world.quarter!=quarter) and Time.get_ticks_msec()<deadline:await process_frame
        check(studio.world.quarter==quarter and not studio.world.rotation_pending(),"Native Fly camera quarter "+str(quarter)+" is ready")
        await process_frame
        verify_prefix(studio,"Fly camera "+str(quarter))
        cameras.append(quarter)
        await super.save_capture(studio,label+"-q"+str(quarter))

func finish(studio:Control)->void:
    check(wing_samples>0,"Real recorded Fly produces visible prepared wings")
    check(moving_wing_samples>0,"Real recorded movement samples the same flying outfit")
    check(ordinary_samples>0,"Recorded initial/removal cuts retain ordinary outfits")
    check(cameras==[0,1,2,3],"Actual wing outfit checked across all four camera views")
    evidence.append({"appearance":{"wing_samples":wing_samples,"moving_wing_samples":moving_wing_samples,"ordinary_samples":ordinary_samples,"cameras":cameras}})
    report_path="res://.runtime/condition-appearance-native.json"
    await super.finish(studio)
