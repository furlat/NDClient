extends SceneTree
const Audience=preload("res://sdk/audience.gd")
const Reducer=preload("res://sdk/reducer.gd")
const Protocol=preload("res://sdk/protocol.gd")
var checks:int=0
var failures:Array=[]
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("SINGLE_AUDIENCE_FAIL ",label)
func event_for(seed:Dictionary,observer:String)->Dictionary:
    var event:Dictionary=seed.duplicate(true)
    event.observer_uuid=observer;event.initial=false
    for field in ["visible_cells_added","visible_cells_removed","seen_cells_added","entity_contacts_removed","object_contacts_removed","spatial_effects_removed"]:event[field]=[]
    for field in ["effective_light_levels_changed","hazardous_cells_changed","entity_contacts_changed","object_contacts_changed","spatial_effects_changed","light_sources_changed","light_sources_removed"]:event[field]={}
    for field in ["observer_position_changed","passive_perception_changed","visual_access_changed","sense_modes_changed","paths_dirty"]:event[field]=false
    return event
func fold(perception:Dictionary,previous:Dictionary,event:Dictionary,observer:String,audience:Dictionary,cursor:int)->Dictionary:
    var held:Dictionary=perception.duplicate(true)
    var prior:Dictionary=previous.duplicate(true)
    var context:Dictionary={}
    var observed:Dictionary=Audience._observe_retained(perception,audience,event,cursor,context)
    check(observed.ok,"Sensory edge admitted: "+str(cursor))
    if not observed.ok:return {}
    var expected:Dictionary=Audience._view_after(observed.value,observer,previous,event,{},false)
    var complete:Dictionary=Audience._view_retained(observed.value,observer)
    var actual:Dictionary=Audience._view_after(observed.value,observer,previous,event,context,true)
    check(actual==expected,"Retained projection equals existing incremental path: "+str(cursor))
    check(actual==complete,"Retained projection equals complete compositor: "+str(cursor))
    check(perception==held and previous==prior,"Prior member and composed owners remain immutable: "+str(cursor))
    if observed.value.members.size()==1 and not event.initial:
        var member:Dictionary=observed.value.members.values()[0]
        check(is_same(actual.visible,member.visible) and is_same(actual.seen,member.seen),"Single member owns canonical ordered cell arrays: "+str(cursor))
        check(is_same(actual.entities,member.entities) and is_same(actual.objects,member.objects),"Single member owns unchanged contact operands: "+str(cursor))
        check(not context.has("view"),"Single member has no redundant composed index: "+str(cursor))
        var private:Dictionary={"senses":actual}
        Reducer._senses_for_write(private,context)
        private.senses.entities["local-spatial-write"]={"visual":false}
        check(not member.entities.has("local-spatial-write"),"Local spatial/observation writes fork borrowed contact map: "+str(cursor))
    return {"perception":observed.value,"view":actual}
func _initialize()->void:
    var protocol=Protocol.new()
    var root:String="res://.runtime/player-runs/20261016T121313.010271Z/journal"
    var decoded:Dictionary=protocol.decode("InitializationResponse",FileAccess.get_file_as_bytes(root.path_join("0000000000000000.json")))
    if not decoded.ok:printerr(decoded.error);quit(1);return
    var initial:Dictionary=protocol.normalize("InitializationResponse",decoded.value)
    var reduced:Dictionary=Reducer.reduce_initialization(initial.initialization,initial.content_additions)
    if not reduced.ok:printerr(reduced.error);quit(1);return
    var state:Dictionary=reduced.value
    var next:Dictionary=protocol.decode("PlayerOperation",FileAccess.get_file_as_bytes(root.path_join("0000000000000006.json")))
    if not next.ok:printerr(next.error);quit(1);return
    var packet:Dictionary=protocol.normalize("PlayerOperation",next.value)
    var seed:Dictionary={}
    for lineage in packet.lineages:
        for node in lineage.events:
            if node.fact!=null and node.fact.kind=="sensory":seed=node.fact;break
        if not seed.is_empty():break
    check(not seed.is_empty(),"Actual recorded sensory fact supplies the contract")
    if seed.is_empty():quit(1);return
    var observer:String=state.observer_uuid
    var audience:Dictionary=state.audience
    var current:Dictionary={"perception":state.perception,"view":state.senses}
    var event:Dictionary=event_for(seed,observer)
    event.effective_light_levels_changed={"987654,987654":4};event.hazardous_cells_changed={"987654,987654":true}
    current=fold(current.perception,current.view,event,observer,audience,1)
    check(current.perception.members[observer].effective_light_levels.has("987654,987654") and not current.view.effective_light_levels.has("987654,987654"),"Nonvisible member light remains absent from composed view")
    check(current.perception.members[observer].hazardous_cells.has("987654,987654") and not current.view.hazardous_cells.has("987654,987654"),"Nonvisible member hazard remains absent from composed view")
    event=event_for(seed,observer);event.visible_cells_added=[[987654,987654],[-987654,987654]];event.seen_cells_added=event.visible_cells_added.duplicate(true)
    current=fold(current.perception,current.view,event,observer,audience,2)
    check(current.view.effective_light_levels.get("987654,987654")==4,"Visibility admission projects the retained raw member light")
    event=event_for(seed,observer);event.visible_cells_removed=[[987654,987654]]
    current=fold(current.perception,current.view,event,observer,audience,3)
    check(not current.view.effective_light_levels.has("987654,987654"),"Visibility retirement removes projected light")
    var other:String="projection-second-observer"
    var second_audience:Dictionary=audience.duplicate(true);second_audience.observers.append(other)
    event=event_for(seed,other);event.initial=true;event.passive_perception=10;event.visual_access=current.perception.members[observer].visual_access;event.observer_position=[987654,987654]
    event.visible_cells_added=[[987654,987654]];event.seen_cells_added=[[987654,987654]];event.effective_light_levels_changed={"987654,987654":2}
    current=fold(current.perception,current.view,event,observer,second_audience,4)
    check(current.perception.members.size()==2 and current.view.effective_light_levels.get("987654,987654")==2,"Single-to-multiple transition recreates exact compositor ownership")
    event=event_for(seed,observer);event.visible_cells_added=[[987654,987654]];event.effective_light_levels_changed={"987654,987654":4}
    current=fold(current.perception,current.view,event,observer,second_audience,5)
    check(current.view.effective_light_levels.get("987654,987654")==4,"Composed brightness winner remains exact after transition")
    var report:Dictionary={"checks":checks,"failures":failures,"scope":"Real initialized observer plus nonvisible light/hazard, ordering, visibility retirement, borrowed-contact write isolation and single-to-multiple compositor transition."}
    FileAccess.open("res://generated/sdk_single_audience_projection_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SDK_SINGLE_AUDIENCE_PROJECTION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
