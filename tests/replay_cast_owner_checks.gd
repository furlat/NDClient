extends SceneTree
## Real mid-cast replay restores need the active authored outfit before they
## publish, including after a retained hidden renderer is reset for another seek.
const Play=preload("res://play.gd")
const Recording=preload("res://studio/recording.gd")
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("REPLAY_CAST_OWNER_FAIL ",label)
func settle(world:Node)->bool:
    var deadline:int=Time.get_ticks_msec()+30000
    while not world.playback_prepared() and world.presentation_errors.is_empty() and world.media_issue.is_empty() and Time.get_ticks_msec()<deadline:
        await process_frame
    return world.playback_prepared() and world.presentation_errors.is_empty() and world.media_issue.is_empty()
func inspect(world:Node,index:Dictionary,time:float,actor_id:String,expected_count:int,initial:bool)->bool:
    var restored:RefCounted=Recording.restore(index,time)
    world.native_startup_requested_ms=time
    if initial:world.install_playback(restored)
    else:check(world.try_reset_hidden_playback(restored),"Hidden replay accepts requested cast cut "+str(time))
    var ready:bool=await settle(world)
    check(ready,"Native renderer prepares exact requested cast cut "+str(time))
    check(world.timeline.display_ms==time and world.timeline.state==Recording.restore(index,time).state,
        "Native cast restore displays the exact authoritative prefix "+str(time))
    var actor:Dictionary=world.visual_actors.get(actor_id,{})
    check(not actor.is_empty(),"Disclosed caster owns native rendering at "+str(time))
    if not actor.is_empty():
        check(actor.row.equipment_layers.size()==expected_count,"Native outfit has authored layer count at "+str(time))
        var transient:Array=actor.row.equipment_layers.filter(func(layer):return not layer.get("effect",{}).is_empty())
        check(transient.size()==expected_count-7,"Only active authored cast layers are published at "+str(time))
    check(not world.publication_failed and not world.native_light_atlas.output_admission_failed,
        "Cast seek never publishes an unprepared actor or receiving material "+str(time))
    evidence.append({"display_ms":time,"layer_count":actor.get("row",{}).get("equipment_layers",[]).size(),
        "errors":world.presentation_errors.duplicate(),"ready":ready})
    return ready
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1440,430)
    var index:Dictionary=Recording.read("res://.runtime/studio-cases/invisibility-seed3-v2/amber/journal")
    check(index.ok,"Actual Invisibility/See Invisibility journal admitted")
    if not index.ok:finish();return
    var selected:Dictionary={}
    for item in index.groups:
        if int(item.group.operation_sequence)==6 and item.group.components.any(func(component):return component.kind=="sprite_layer"):selected=item;break
    check(not selected.is_empty(),"Actual See Invisibility cast has authored layer intervals")
    if selected.is_empty():finish();return
    var actor_id:String=""
    for component in selected.group.components:
        if component.kind=="sprite_layer":actor_id=component.actor_uuid;break
    var view=SubViewport.new();view.size=root.size;view.own_world_3d=true
    view.audio_listener_enable_3d=false;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(view)
    var world=Play.new();world.external_playback=true
    world.component_renderer.audio.set_enabled(false)
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache)
    world.native_startup_plan=Play.NativeStartup.recording_plan(index.rows)
    view.add_child(world)
    var middle:float=selected.start_ms+selected.group.duration_ms*.5
    var endpoint:float=selected.start_ms+selected.group.duration_ms
    if await inspect(world,index,middle,actor_id,9,true):
        for point in [{"at":0.0,"layers":7},{"at":middle,"layers":9},{"at":endpoint,"layers":7},{"at":middle,"layers":9}]:
            if not await inspect(world,index,point.at,actor_id,point.layers,false):break
    view.queue_free();await process_frame;await process_frame
    finish()
func finish()->void:
    var report={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Actual See Invisibility native mid-cast initial construction, hidden retained seeks to zero, middle and exact endpoint, repeat mid-cast, exact reducer prefixes and active actor/receiving ownership. No performance claim."}
    FileAccess.open("res://generated/replay_cast_owner_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("REPLAY_CAST_OWNER ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
