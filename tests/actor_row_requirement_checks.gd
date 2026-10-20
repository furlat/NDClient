extends SceneTree
## Current wire rows -> passive expectations and actual existing Studio owners.
## Metadata unit controls below are not fabricated gameplay recordings.
const Requirements=preload("res://presentation/requirements.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Recording=preload("res://studio/recording.gd")
const Trace=preload("res://presentation/event_trace.gd")
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("ACTOR_ROW_REQUIREMENT_FAIL "+label)
func _initialize()->void:run.call_deferred()
func run()->void:
    var schema:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Requirements.SCHEMA))
    var fields:Dictionary=schema["$defs"].ActorRows.properties.rows.items.discriminator.mapping
    var inventory:Array=Requirements.facts({})
    for field in fields:
        var expected:Dictionary=Requirements.actor_field(field)
        check(expected.actor_field==field and expected.source.ends_with("/"+field),"Canonical row has exact schema source: "+field)
        check(inventory.any(func(row):return row.kind=="actor_row:"+field),"Static inventory includes every canonical field: "+field)
        check(not expected.rendered,"Source classification never proves body/render output: "+field)
    check(Requirements.fact("actor_change").disposition=="ordered_rows" and Requirements.fact("actor_change").status=="unexercised","Container declares ordered rows without becoming state-only or rendered")
    check(Requirements.actor_field("future_field").status=="missing","Unknown future row remains unassessed")
    check(Requirements.actor_field("item_effects").status=="missing" and Requirements.actor_field("resolved_size").status=="missing","Dynamic item effects and size stay independent explicit gaps")
    metadata_controls()
    for name in ["hide","condition-owners","gallery","chromatic-orb"]:
        for seat in ["amber","blue"]:recorded(name,seat)
    recorded("divine-arm","party")
    var report={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"All current row definitions; explicit metadata identity/negative controls; original independent Hide/overlapping-condition/Gallery/Orb and actual party equipment journals. No source build, GPU witness or missing dynamic item-effect scenario claim."}
    FileAccess.open("res://generated/actor_row_requirement_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("ACTOR_ROW_REQUIREMENTS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

func metadata_controls()->void:
    var value={"actors":[{"actor_uuid":"first","rows":[
        {"field":"condition","condition_uuid":"held","member":null},
        {"field":"condition","condition_uuid":"held","member":{"condition_uuid":"held"}},
        {"field":"condition_duration","key":"held","duration":null},
        {"field":"item_effects","item_uuid":"item","effects":[{"effect_uuid":"effect"}]},
        {"field":"item_effect_duration","item_uuid":"item","key":"effect","duration":null},
        {"field":"item_state","item_uuid":"item","changes":{"is_lit":true}},
        {"field":"item_state","item_uuid":"item","changes":{"construction_geometry":null}}]},
        {"actor_uuid":"second","rows":[{"field":"condition","condition_uuid":"other","member":null}]}]}
    var original:PackedByteArray=var_to_bytes(value)
    var rows:Array=Requirements.actor_rows(value)
    var ids:Dictionary={}
    for row in rows:ids[row.id]=true
    check(rows.size()==8 and ids.size()==rows.size(),"Disjoint actors and repeated fields retain unique ordered row identities")
    check(rows[0].actor_index==0 and rows[0].row_index==0 and rows[1].row_index==1 and rows[-1].actor_uuid=="second" and rows[-1].actor_index==1,"Actual actor/row ordinals never collapse into one actor envelope")
    check(rows[0].phase=="removal" and rows[1].phase=="set" and rows[0].condition_uuid==rows[1].condition_uuid,"Remove/reapply metadata preserves both native rows of one UUID")
    check(rows[2].condition_uuid=="held" and rows[2].disposition=="state_only" and rows[2].status=="explicit_none","Duration update keeps the exact existing owner without inventing reapplication")
    check(rows[3].effect_uuids==["effect"] and rows[4].item_uuid=="item" and rows[4].effect_uuid=="effect" and rows[3].status=="missing" and rows[4].status=="missing","Actual dynamic item/effect identities remain missing rather than covered by intrinsic gear")
    check(rows[5].status=="explicit_none" and rows[6].status=="missing","Item accounting cannot certify a construction-geometry consumer")
    check(var_to_bytes(value)==original,"Requirement projection leaves metadata operands immutable")
    var item_only:Array=Requirements.actor_rows({"actors":[],"items":[{"item_uuid":"item","effects":[{"effect_uuid":"effect"}]}]})
    check(item_only.size()==1 and item_only[0].status=="missing" and item_only[0].item_uuid=="item" and item_only[0].effect_uuids==["effect"] and item_only[0].actor_uuid.is_empty() and item_only[0].actor_index==-1 and item_only[0].source.ends_with("/$defs/ItemRecord/properties/effects"),"Actual ItemRecord effect membership retains its exact schema source and cannot hide behind metadata ingress or invent a holder")
    check(Requirements.actor_rows({"actors":[],"items":[{"item_uuid":"item","effects":[]}]}).is_empty(),"An empty ItemRecord ingress does not manufacture a visual or possession requirement")
    # A trace carries row detail only after its original commit; no render or
    # future actor/item identity is made public by the container classification.
    var event={"id":"1:1","sequence":1,"event_uuid":"1","lineage_uuid":"1","source_index":1,"first_source_index":1,
        "parent_event":null,"parent_lineage":null,"kind":"actor_change","name":"actor_change","behavior_id":null,
        "actor_uuid":null,"target_uuid":null,"components":[],"status":"state_only","reasons":[],
        "committed":false,"completed":false,"parent_id":"","_log":null,"_end_ms":10.0,"_admit_ms":10.0,"_group_duration_ms":10.0,"_actor_rows":rows}
    var trace:Dictionary=Trace.create();Trace.activate(trace,[event],0.0)
    check(not Trace._public(trace.rows[event.id],true).has("actor_rows"),"Uncommitted public trace cannot disclose actual row identities")
    Trace.commit(trace,1,"1")
    var public:Dictionary=Trace._public(trace.rows[event.id],true)
    check(public.actor_rows.size()==rows.size() and public.actor_rows.all(func(row):return not row.rendered),"Committed detail exposes classified rows without fabricated render witnesses")

func recorded(name:String,seat:String)->void:
    var index:Dictionary=Fixtures.read(name,seat)
    check(index.ok,name+"/"+seat+" original Studio journal compiles")
    if not index.ok:return
    var original:PackedByteArray=var_to_bytes([index.initialization,index.groups])
    var native:Dictionary={}
    for value in Fixtures.fact_rows(name,"actor_change",seat):native[str(int(value.node.occurrence))]=value.fact
    var by_id:Dictionary={}
    for row in index.rows:by_id[row.id]=row
    var count:int=0;var equipment:int=0;var condition:int=0
    for row in index.rows:
        if row.kind!="event" or row.event.kind!="actor_change":continue
        var actual:Dictionary=native[row.event.event_uuid]
        var expected:int=0
        for actor in actual.actors:expected+=actor.rows.size()
        for item in actual.get("items",[]):
            if not item.get("effects",[]).is_empty():expected+=1
        check(row.get("actor_rows",[]).size()==expected,name+"/"+seat+" every original row has an assessment")
        check(not row.event.components.any(func(component):return component.kind=="fact:actor_change"),name+"/"+seat+" retired generic fact warning is replaced by actual per-row requirements")
        for requirement in row.actor_rows:
            count+=1
            if requirement.actor_index<0:
                var item:Dictionary=actual.items[requirement.row_index]
                check(requirement.item_uuid==item.item_uuid and requirement.effect_uuids==item.effects.map(func(effect):return str(effect.effect_uuid)) and requirement.status=="missing" and requirement.actor_uuid.is_empty(),name+"/"+seat+" disclosed record effects remain exact dynamic membership gaps without a fabricated holder")
                continue
            var actor:Dictionary=actual.actors[requirement.actor_index]
            var change:Dictionary=actor.rows[requirement.row_index]
            check(requirement.actor_uuid==actor.actor_uuid and requirement.actor_field==change.field and requirement.occurrence==row.event.event_uuid,name+"/"+seat+" row retains exact native actor/ordinal/occurrence")
            check(not requirement.rendered and requirement.availability=="not_examined",name+"/"+seat+" classification is not a render/source qualification")
            for linked in requirement.inspection_links:check(by_id.has(linked),name+"/"+seat+" inspection link resolves to a real existing row")
            if change.field=="condition":
                condition+=1
                check(requirement.condition_uuid==change.condition_uuid,name+"/"+seat+" actual condition UUID survives classification")
                check(requirement.phase in ["removal","application","update"] and (change.get("member")!=null or requirement.phase=="removal"),name+"/"+seat+" actual removal/application is not a fabricated state transition")
                var owner_rows:Array=requirement.inspection_links.filter(func(id):return by_id[id].kind=="condition")
                check(owner_rows.size()==1 and by_id[owner_rows[0]].owner.id==change.condition_uuid and by_id[owner_rows[0]].owner.actor_uuid==actor.actor_uuid,name+"/"+seat+" condition delegates to its exact actual lifetime")
            elif change.field in ["layer","active_weapon_set"]:
                equipment+=1
                check(requirement.visibility!="not_disclosed" and not requirement.inspection_links.is_empty(),name+"/"+seat+" actual equipment row links its enabled body")
                for linked in requirement.inspection_links:
                    if by_id[linked].kind=="body":check(by_id[linked].track.actor_uuid==actor.actor_uuid,name+"/"+seat+" another actor's body cannot qualify this row")
            elif change.field in Requirements.ACTOR_ACCOUNTING:
                check(requirement.disposition=="state_only" and requirement.status=="explicit_none",name+"/"+seat+" actual accounting does not demand a duplicate animation")
    var end:RefCounted=Recording.restore(index,index.presentation_end_ms)
    var looped:RefCounted=Recording.restore(index,index.presentation_end_ms)
    check(end.state==looped.state and var_to_bytes([index.initialization,index.groups])==original,name+"/"+seat+" indexing/seek leaves canonical replay and source cuts unchanged")
    check(count>0,name+"/"+seat+" actual row coverage is exercised")
    evidence.append({"case":name,"seat":seat,"rows":count,"equipment":equipment,"conditions":condition})
