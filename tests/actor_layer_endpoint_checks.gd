extends SceneTree
## Real authored constructor intervals must agree before and at a spell's
## complete cut, even when subtracting its start loses a floating-point bit.
const Recording=preload("res://studio/recording.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Construction=preload("res://presentation/actor_construction.gd")
const Characters=preload("res://presentation/characters.gd")
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("ACTOR_LAYER_ENDPOINT_FAIL ",label)
func ids(components:Array)->Array:
    var result:Array=[]
    for component in components:
        if component.kind=="sprite_layer":result.append(component.id)
    result.sort();return result
func inspect(index:Dictionary,time:float,actor_id:String,expected_layers:int)->void:
    var timeline:RefCounted=Recording.restore(index,0)
    var plan:Dictionary=timeline.replay_plan(time)
    var seen:Dictionary={}
    timeline.replay_media_ready=func(_plan):return true
    timeline.world_ready=func(candidate):seen.candidate=candidate;return true
    check(timeline.replay_prepare(plan),"Real cumulative prefix prepares at "+str(time))
    check(seen.has("candidate"),"Actor constructor boundary is exposed at "+str(time))
    if not seen.has("candidate"):return
    var candidate:Dictionary=seen.candidate
    check(timeline.replay_publish(plan),"Prepared prefix publishes at "+str(time))
    var samples:Dictionary=timeline.actor_samples()
    var components:Array=timeline.component_samples(index.cache)
    check(ids(candidate.actor_layers)==ids(components),"Prepared and displayed transient-layer membership agree at "+str(time))
    check(ids(timeline.actor_layer_samples())==ids(components),"Passive initial constructor operands match displayed layers at "+str(time))
    var prepared_loadouts:Dictionary=Construction.loadouts(candidate.actor_samples,candidate.actor_layers)
    var displayed_loadouts:Dictionary=Construction.loadouts(samples,components)
    var prepared:Dictionary=Characters.structure(Construction.actor_with_loadout(candidate.state.actors[actor_id],prepared_loadouts),index.cache)
    var displayed:Dictionary=Characters.structure(Construction.actor_with_loadout(timeline.state.actors[actor_id],displayed_loadouts),index.cache)
    check(prepared.ok and displayed.ok,"Actual recorded outfit sources resolve at "+str(time))
    if not prepared.ok or not displayed.ok:return
    check(prepared.value.equipment_layers==displayed.value.equipment_layers,"Prepared and displayed constructor operands agree at "+str(time))
    check(displayed.value.equipment_layers.size()==expected_layers,"Exact authored layer count at "+str(time))
    evidence.append({"display_ms":time,"layer_count":displayed.value.equipment_layers.size(),
        "transient_ids":ids(components),"state_matches_restore":timeline.state==Recording.restore(index,time).state})
    check(timeline.state==Recording.restore(index,time).state,"Authoritative prefix remains unchanged at "+str(time))
func internal_edge(index:Dictionary,selected:Dictionary)->void:
    # Isolate the same recorded layer clock before a longer group tail. This
    # protects the internal constructor gate independently of group completion.
    var timeline=Recording.Timeline.new()
    timeline.state=index.initialization.state
    timeline.current=selected.group.duplicate()
    timeline.current.duration_ms=selected.group.duration_ms+250.0
    timeline.current.commits=[];timeline.current.actor_tracks=[]
    timeline.current.components=selected.group.components.filter(func(component):return component.kind=="sprite_layer")
    timeline.current.actor_structure_times=[selected.group.duration_ms]
    timeline.group_start_ms=selected.start_ms
    timeline.display_ms=selected.start_ms+selected.group.duration_ms-1000.0/144.0
    var before:float=timeline.display_ms
    var endpoint:float=selected.start_ms+selected.group.duration_ms
    var gate:Dictionary={"ready":false,"calls":0,"candidate":{}}
    timeline.media_ready=func(_group):return true
    timeline.world_ready=func(candidate):gate.calls+=1;gate.candidate=candidate;return gate.ready
    check(timeline.actor_layer_samples().size()==1,"Internal fixture starts with the actual hand-magic layer; caster aura is intentionally disabled")
    timeline.advance(endpoint-before)
    check(gate.calls==1 and timeline.waiting_for_world,"Exact internal endpoint requests constructor ownership before display")
    check(timeline.display_ms==before,"Unprepared internal endpoint retains previous displayed clock")
    if gate.calls>0:
        check(gate.candidate.actor_layers.is_empty(),"Exact internal candidate excludes expired layers")
        gate.ready=true;timeline.advance(endpoint-before)
        check(timeline.display_ms==endpoint and timeline.actor_layer_samples().is_empty(),"Prepared internal endpoint publishes exact layer removal")
    evidence.append({"fixture":"internal recorded-layer endpoint with longer presentation tail","display_ms":endpoint,"gate_calls":gate.calls})
func run()->void:
    var index:Dictionary=Fixtures.read("invisibility")
    check(index.ok,"Actual Invisibility/See Invisibility journal admitted")
    if index.ok:
        var selected:Dictionary={}
        for item in index.groups:
            if item.group.events.any(func(event):return event.get("behavior_id")=="spell.see_invisibility") and item.group.components.any(func(component):return component.kind=="sprite_layer"):selected=item;break
        check(not selected.is_empty(),"Actual See Invisibility cast has authored transient layers")
        if not selected.is_empty():
            var actor_id:String=""
            for component in selected.group.components:
                if component.kind=="sprite_layer":actor_id=component.actor_uuid;break
            var baseline:Dictionary=Characters.structure(index.initialization.state.actors[actor_id],index.cache,
                Characters.item_looks(index.initialization.state.actors[actor_id],index.initialization.state))
            check(baseline.ok,"Original recorded caster outfit resolves independently of cast layers")
            if not baseline.ok:quit(1);return
            var base_count:int=baseline.value.equipment_layers.size()
            check(selected.group.components.filter(func(component):return component.kind=="sprite_layer").size()==1,"See Invisibility uses its hand-magic layer; the user-disabled caster aura stays absent")
            var endpoint:float=selected.start_ms+selected.group.duration_ms
            inspect(index,endpoint-1000.0/144.0,actor_id,base_count+1)
            inspect(index,endpoint,actor_id,base_count)
            inspect(index,endpoint+1000.0/144.0,actor_id,base_count)
            internal_edge(index,selected)
    var report={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Actual See Invisibility authored hand-layer start/end, cumulative reducer constructor candidate vs displayed membership and exact Recording.restore state. Native seek/playback covered separately."}
    FileAccess.open("res://generated/actor_layer_endpoint_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("ACTOR_LAYER_ENDPOINT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
