extends SceneTree
## Real server spell inventory -> production Studio index and shared state/owners.
## Source/data coverage only; native pixels are qualified by the family fixtures.
const Library=preload("res://studio/case_library.gd")
const Recording=preload("res://studio/recording.gd")
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Conditions=preload("res://presentation/conditions.gd")
const Persistent=preload("res://presentation/native_persistent.gd")
const EXPECTED=["acid_splash","chill_touch","eldritch_blast","fire_bolt","fireball","guiding_bolt","ice_knife","magic_missile","poison_spray","produce_flame","ray_of_frost","scorching_ray","sleep","web","bane","command","mage_armor","sanctuary","shield","shocking_grasp","burning_hands","thunderwave","cure_wounds","healing_word","guidance","resistance","light","thaumaturgy","shield_of_faith","true_strike"]
const EVENT_ROLES={
    "acid_splash":{"cast":1,"flight":1,"impact":1},"chill_touch":{"strike":1},
    "eldritch_blast":{"cast":1,"flight":2,"impact":2},"fire_bolt":{"cast":1,"flight":1,"impact":1},
    "fireball":{"cast":1,"flight":1,"area":1},"guiding_bolt":{"cast":1,"flight":1,"impact":1},
    "ice_knife":{"cast":1,"flight":1,"area":1},"magic_missile":{"cast":1,"flight":3,"impact":3},
    "poison_spray":{"cast":1,"spray":1},"produce_flame":{"flight":1,"impact":1},
    "ray_of_frost":{"cast":1,"flight":2,"impact":1},"scorching_ray":{"cast":1,"flight":3,"impact":3},
    "sleep":{"cast":1,"flight":1,"area":1},"web":{"cast":1,"flight":1},
    "bane":{},"command":{"attached":1},"mage_armor":{},"sanctuary":{},"shield":{"attached":3},
    "shocking_grasp":{"cast":1,"attached":1},"burning_hands":{"attached":1},"thunderwave":{"attached":1},
    "cure_wounds":{"attached":1},"healing_word":{"attached":1},"guidance":{},"resistance":{},
    "light":{},"thaumaturgy":{"attached":1},"shield_of_faith":{},"true_strike":{"attached":1}}
# Recorded lifecycles whose spells have no native effect authoring yet.
const RECORDED_ONLY=["aid","bless","false_life","sacred_flame"]
# Further real recordings of an included spell, with their own delivery slots.
const EXTRA_CASES={"native-spell-shield-ranged":{"attached":1},"native-spell-shield-walk":{"attached":1}}
const OWNED=["bane","command","mage_armor","sanctuary","shield","guidance","resistance","light","shield_of_faith","web"]
# Bane's condition plays two package lifecycles: its body orbit and its marker.
const LIFECYCLES={"bane":2}
var checks:=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("SPELL_BATCH_FAIL ",label)
func inspect_case(item:Dictionary,descriptor:Dictionary)->void:
    var row={"spell_id":item.spell_id,"perspectives":[],"facts":descriptor.facts,"condition_lifecycle":descriptor.get("condition_lifecycle",{})}
    var native_total=0
    for perspective in item.perspectives:
        var label=item.spell_id+" / "+perspective.id
        var index=Recording.read(perspective.journal)
        check(index.ok,label+": complete original journal builds Studio index")
        if not index.ok:
            row.perspectives.append({"id":perspective.id,"error":index.get("error",index)})
            continue
        var canonical=Journal.new()
        var admitted=canonical.open(perspective.journal,true,true)
        check(admitted.ok,label+": independent public journal replay")
        if not admitted.ok:continue
        var state:Dictionary=index.initialization.state.duplicate(true)
        var owners={};var spatial={};var events={};var sources={};var instances={};var roles={};var native_count=0
        Conditions.observe(owners,state.actors,0.0,true)
        Persistent.observe_spatial(spatial,state.senses.get("spatial_effects",{}),0.0,true)
        for wrapped in index.groups:
            var group:Dictionary=wrapped.group
            for event in group.events:events[event.event_uuid]=true
            var previous=-1.0
            for commit in group.commits:
                check(commit.at_ms>=previous,label+": actual commits preserve chronological order")
                previous=commit.at_ms
                Compiler.apply_delta(state,commit.delta)
                var at:float=wrapped.start_ms+commit.at_ms
                Conditions.observe(owners,state.actors,at)
                Persistent.observe_spatial(spatial,state.senses.get("spatial_effects",{}),at)
                var sampled=Conditions.samples(owners.duplicate(true),at+.001,index.cache)
                sampled.append_array(Persistent.spatial_samples(spatial.duplicate(true),at+.001,index.cache))
                for component in sampled:
                    if not component.get("native_spell",false) or component.spell_id!=item.spell_id:continue
                    native_count+=1;instances[component.id]=true;sources[component.source_id]=true
                    check(component.get("persistent_owner",false),label+": sustained native sample has an actual condition/spatial owner")
                    check(component.status=="available",label+": persistent source is available")
            for component in group.components:
                if not component.get("native_spell",false) or component.spell_id!=item.spell_id:continue
                native_count+=1;sources[component.source_id]=true
                roles[component.native_cue.role]=int(roles.get(component.native_cue.role,0))+1
                check(events.has(component.source_event_uuid),label+": native phase refers to a real event in this recording")
                check(component.status=="available" and component.duration_ms>0,label+": finite native phase is available")
        check(state==canonical.state,label+": Studio commits reproduce complete canonical after-values")
        if perspective.id=="amber":
            for event in descriptor.events:check(events.has(event.event_uuid),label+": inventory event belongs to the indexed recording")
        check(native_count>0,label+": selected spell exposes native components through the production pipeline")
        check(roles==EXTRA_CASES.get(item.id,EVENT_ROLES[item.spell_id]),label+": exact authored phase slots for the recorded deliveries; got "+JSON.stringify(roles))
        check(instances.size()==LIFECYCLES.get(item.spell_id,1 if item.spell_id in OWNED else 0),label+": exact disclosed persistent instance count")
        native_total+=native_count
        row.perspectives.append({"id":perspective.id,"operations":index.operations,"native_samples":native_count,
            "sources":sources.keys(),"roles":roles,"persistent_instances":instances.keys(),"rows":index.rows.size(),"duration_ms":index.duration_ms})
    check(native_total>0,item.spell_id+": native capability is usable in the selected real case")
    evidence.append(row)
    print("SPELL_BATCH_CASE ",JSON.stringify(row))
func run()->void:
    var inventory:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://generated/studio_spell_case_inventory.json"))
    check(inventory.get("failures",[]).is_empty(),"All capture commands and per-spell evidence succeeded")
    var listed=Library.read().filter(func(item):return item.has("spell_id"))
    check(listed.size()==EXPECTED.size()+RECORDED_ONLY.size()+EXTRA_CASES.size(),"Every recorded spell case is selectable")
    var seen={}
    for item in listed:
        check(not seen.has(item.id) and (item.id=="native-spell-"+item.spell_id or EXTRA_CASES.has(item.id)),"Unique spell case: "+item.id)
        seen[item.id]=true
        check(item.perspectives.size()==2,item.id+": both independent real audiences are selectable")
        var found=inventory.cases.filter(func(row):return row.id==item.id)
        check(found.size()==1,item.id+": one concrete descriptor")
        if found.size()!=1:continue
        if item.spell_id in RECORDED_ONLY:
            check(not found[0].get("native_effects_authored",true) and not found[0].get("lifecycle",[]).is_empty(),item.id+": recorded lifecycle, explicitly without native authoring")
            continue
        check(item.spell_id in EXPECTED and found[0].get("native_effects_authored",false),item.id+": included natively authored spell")
        inspect_case(item,found[0])
    for spell in EXPECTED+RECORDED_ONLY:
        check(seen.has("native-spell-"+spell),"Lifecycle case recorded: "+spell)
    var report={"checks":checks,"failures":failures,"cases":evidence,
        "scope":"Real SDK lifecycle recordings (30 natively authored spells plus further Shield cases), two independently admitted audiences, actual Studio source/owner indexing and canonical commit parity. No native rendering or artistic approval claim."}
    FileAccess.open("res://generated/studio_spell_batch_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_SPELL_BATCH ",checks," / ",failures.size())
    quit(0 if failures.is_empty() else 1)
