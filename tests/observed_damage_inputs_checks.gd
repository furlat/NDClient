extends SceneTree
## Original applied-result occurrences feed finite native outcome programs.
## No synthetic game sequence or inferred passive/rider activation.
const Results=preload("res://presentation/application_results.gd")
const Occurrences=preload("res://presentation/occurrences.gd")
const Protocol=preload("res://sdk/protocol.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
var checks:int=0
var failures:Array=[]
var outcomes:int=0
var seats:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("OBSERVED_DAMAGE_FAIL ",label)

func descendants(owner:Dictionary,events:Array,nodes:Dictionary)->Array:
    var result:Array=[]
    for event in events:
        if event.get("canceled",false) or event.get("fact")==null:continue
        var fact:Dictionary=event.fact
        if fact.kind!="damage" or fact.get("stage")!="applied" or int(fact.applied_damage)<=0 or fact.get("source_entity_uuid")!=owner.fact.source_entity_uuid:continue
        var parent:Variant=event.parent_lineage
        while parent!=null:
            if str(parent)==owner.lineage_id:result.append(event);break
            parent=nodes.get(str(parent),{}).get("parent_lineage")
    return result

func controls(owner:Dictionary,actual:Dictionary,events:Array)->void:
    # Negative controls change only a private copy of one real observation.
    for field in ["canceled","stage","applied_damage","source_entity_uuid"]:
        var copied:Array=events.duplicate(true)
        var changed:Dictionary=copied.filter(func(row):return row.id==actual.id)[0]
        if field=="canceled":changed.canceled=true
        elif field=="stage":changed.fact.stage="taken";changed.fact.erase("applied_damage")
        elif field=="applied_damage":changed.fact.applied_damage=0
        else:changed.fact.source_entity_uuid=null
        var graph:Dictionary={"nodes":{},"condition_cues":{}}
        for node in copied:graph.nodes[node.lineage_id]=node
        graph.observed_results=Results.observed_index(copied,graph)
        check(not Results.observed(owner,{"outcome":"damage","geometry_actor":"target"},graph).any(func(row):return row.node.id==actual.id),"Private "+field+" control cannot admit that damage result")

func run()->void:
    var protocol:RefCounted=Protocol.new()
    var controlled:bool=false
    for seat in ["amber","blue"]:
        seats[seat]=0
        for case_id in ["gallery","melee","oa-jump-late-lethal"]:
            var directory:String=Fixtures.journal(case_id,seat)
            var files:PackedStringArray=DirAccess.get_files_at(directory);files.sort()
            for file in files:
                if file.get_basename().length()!=16 or not file.get_basename().is_valid_int() or int(file.get_basename())==0:continue
                var packet:Dictionary=protocol.normalize("PlayerOperation",JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(file))))
                for source in packet.lineages:
                    var lineage:Dictionary=Occurrences.group(source)
                    var graph:Dictionary={"nodes":{},"condition_cues":{}}
                    for node in lineage.events:graph.nodes[node.lineage_id]=node
                    var original:PackedByteArray=var_to_bytes(lineage.events)
                    graph.observed_results=Results.observed_index(lineage.events,graph)
                    for owner in lineage.events:
                        if owner.get("canceled",false) or owner.get("fact")==null or not owner.fact.has("source_entity_uuid") or owner.fact.source_entity_uuid==null:continue
                        if owner.fact.kind not in ["action","attack","spell"] or not owner.fact.has("behavior_id") or graph.nodes[owner.lineage_id].id!=owner.id:continue
                        var expected:Array=descendants(owner,lineage.events,graph.nodes)
                        if expected.is_empty():continue
                        var rows:Array=Results.observed(owner,{"outcome":"damage","geometry_actor":"target"},graph)
                        check(rows.map(func(row):return row.node.id)==expected.map(func(node):return node.id),seat+" exact native descendant result occurrences")
                        for row in rows:
                            var fact:Dictionary=row.node.fact
                            check(row.event.actual_damage==fact.applied_damage and row.event.damage_type==fact.damage_type,"Exact committed amount/type, no sum or rule recomputation")
                            check(row.event.damage_component_uuid==str(row.node.id) and row.event.uuid==str(row.node.id),"Opaque component/event identity is the real applied occurrence")
                            check(row.event.source_entity_uuid==fact.source_entity_uuid and row.event.target_entity_uuid==fact.target_entity_uuid,"Source and recipient retain their disclosed identities")
                            check(row.values.geometry_actor==fact.target_entity_uuid and row.values.owner_uuid==str(owner.id),"Constructor binds actual receiving actor and native owner")
                            check(row.values.event.is_empty() and row.values.lease.is_empty() and not row.values.plan_only,"Constructor clears review fixture outcomes before the real setter packet")
                            check(row.evidence.result_lineage==row.node.lineage_id and row.evidence.source_lineage==owner.lineage_id,"Actual native result/owner lineage remains inspectable")
                            check(row.evidence.source_condition_uuid==fact.get("source_condition_uuid") and row.evidence.effect_id==fact.get("effect_id"),"No passive/condition/component attribution is invented")
                            outcomes+=1;seats[seat]+=1
                            if not controlled:
                                controls(owner,row.node,lineage.events);controlled=true
                        for damage_type in ["Radiant","Fire","Cold","Piercing"]:
                            var filtered:Array=Results.observed(owner,{"outcome":"damage","geometry_actor":"target","damage_type":damage_type},graph)
                            check(filtered.map(func(row):return row.node.id)==expected.filter(func(node):return node.fact.damage_type==damage_type).map(func(node):return node.id),"Declared damage type selects only exact real results: "+damage_type)
                    check(var_to_bytes(lineage.events)==original,"Projection leaves original native rows unchanged")
    check(seats.values().all(func(count):return count>0),"Both original factions independently exercise positive applied results")
    check(controlled,"A real applied result supports all negative controls with its original ancestor path")
    print("OBSERVED_DAMAGE_INPUTS ",JSON.stringify({"checks":checks,"failures":failures,"outcomes":outcomes,"seats":seats,
        "scope":"Original native applied-result ancestry and exact finite constructor/setter operands; no passive attribution, visual approval or all-sources qualification."}))
    quit(0 if failures.is_empty() else 1)
