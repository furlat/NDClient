extends SceneTree
## Original independent journals prove mixed per-application saves. Private
## value controls below exercise absence/ambiguity; they are not wire replays.
const Results=preload("res://presentation/application_results.gd")
const Occurrences=preload("res://presentation/occurrences.gd")
const Journal=preload("res://sdk/journal.gd")
const EFFECT="spell.circle_of_death.saving_throw"
const BASE="res://tests/fixtures/schema16/circle-of-death/"
const ROOT_BASE="res://tests/fixtures/schema16/root-target-save/ray-of-sickness/"
const ROOT_EFFECT="spell.ray_of_sickness.saving_throw"
const EXPECTED={
    "e3f92f4a-a9ca-5d7b-9ce9-477567e6968a":{"target":"fdaef6f2-e48d-4d77-b5b2-7b7badfa0ce2","application":"67","application_lineage":"44","save":"48","save_lineage":"45","succeeded":false},
    "1b0663af-0e31-5010-8ffe-4376aaa1c867":{"target":"7edcd4f5-1daf-4454-a96d-be84140d87d5","application":"91","application_lineage":"68","save":"72","save_lineage":"69","succeeded":true},
    "dfac1a91-b4b3-56fa-b9b0-f50c6b702fc0":{"target":"3b0effbf-39d8-425c-ab0d-5e9c867b2c8c","application":"115","application_lineage":"92","save":"96","save_lineage":"93","succeeded":false},
    "e0f022bf-c128-5086-a2e9-a9a611975022":{"target":"b6553571-42cb-4148-ba09-307af3b67612","application":"139","application_lineage":"116","save":"120","save_lineage":"117","succeeded":false}}
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("APPLICATION_SAVE_CONTEXT_FAIL "+label)
func run()->void:
    for seat in ["amber","blue"]:
        original(seat)
        target_cast(seat)
    print(JSON.stringify({"checks":checks,"failures":failures,"scope":"Exact disclosed application/save context; no native or visual qualification"}))
    quit(0 if failures.is_empty() else 1)
func original(seat:String)->void:
    var directory:String=BASE+seat+"/journal"
    var journal:RefCounted=Journal.new();var opened:Dictionary=journal.open(directory,true,false)
    check(opened.ok,seat+" original Circle journal selects its recorded producer contract")
    if not opened.ok:return
    var raw_packet:PackedByteArray=FileAccess.get_file_as_bytes(directory+"/0000000000000008.json")
    var decoded:Dictionary=journal.decode_record(8,raw_packet)
    check(decoded.ok,seat+" original packet is admitted through the actual integer-preserving SDK reader")
    if not decoded.ok:return
    var packet:Dictionary=decoded.value
    var bytes:PackedByteArray=var_to_bytes(packet)
    var found:Dictionary={};var successes:int=0;var controls_done:bool=false
    for raw in packet.lineages:
        var group:Dictionary=Occurrences.group(raw)
        var results:Dictionary=Results.index(group.events)
        var results_bytes:PackedByteArray=var_to_bytes(results)
        for node in group.events:
            if node.get("fact")==null or node.fact.kind!="spell":continue
            var context:Dictionary=Results.save_context(node,results)
            if not Occurrences.application(node):
                check(not context.ready and context.reason=="application_result_identity_unavailable" and context.by_effect.is_empty(),seat+" cast-wide owner cannot borrow a recipient save")
                continue
            var id:String=Results.key(node)[1]
            check(EXPECTED.has(id),seat+" application retains its actual original identity")
            if not EXPECTED.has(id):continue
            var expected:Dictionary=EXPECTED[id]
            check(context.ready and context.reason=="" and context.by_effect.size()==1 and context.by_effect.has(EFFECT),seat+" exact effect has one disclosed application result")
            if not context.by_effect.has(EFFECT):continue
            var row:Dictionary=context.by_effect[EFFECT]
            check(row.ready and row.reason=="" and row.save_succeeded==expected.succeeded,seat+" actual successful/failed result remains distinct")
            check(row.evidence=={"cast_lineage":"41","application_id":id,"application_occurrence":expected.application,
                "application_lineage":expected.application_lineage,"target_uuid":expected.target,"effect_id":EFFECT,
                "save_occurrence":expected.save,"save_lineage":expected.save_lineage},seat+" complete native application/save evidence is retained")
            check(str(node.id)==expected.application and node.fact.target_entity_uuid==expected.target,seat+" source application matches the independent original expectation")
            successes+=int(row.save_succeeded);found[id]=true
            if not controls_done:controls(node,results);controls_done=true
        check(var_to_bytes(results)==results_bytes,seat+" indexed shared save facts remain immutable")
    check(found.size()==4 and successes==1,seat+" four actual applications retain one success and three failures")
    check(var_to_bytes(packet)==bytes,seat+" original packet remains byte-equivalent in memory")
func controls(node:Dictionary,results:Dictionary)->void:
    var identity:Array=Results.key(node)
    var source:Dictionary=results[identity].saves[0]
    var operand:Dictionary=node.duplicate(true)
    operand.canceled=true
    absent(Results.save_context(operand,results),"application_save_canceled","Private canceled application cannot select an outcome")
    operand=node.duplicate(true);operand.fact.target_entity_uuid=null
    absent(Results.save_context(operand,results),"application_result_target_unavailable","Private undisclosed recipient cannot borrow a save")
    operand=node.duplicate(true);operand.resolution_record.lineage="other-cast"
    absent(Results.save_context(operand,results),"save_effect_unavailable","Foreign cast identity cannot borrow the real application")
    operand=node.duplicate(true);operand.resolution_record.application_id="other-application"
    absent(Results.save_context(operand,results),"save_effect_unavailable","Foreign application cannot borrow another application of the same cast")
    operand=node.duplicate(true);operand.fact.target_entity_uuid="other-recipient"
    absent(Results.save_context(operand,results),"save_effect_unavailable","Foreign recipient cannot consume an otherwise matching application")
    absent(Results.save_context(node,{}),"save_effect_unavailable","Undisclosed application results remain unavailable")
    for missing in [null,""]:
        var unknown:Dictionary=source.duplicate(true);unknown.fact.effect_id=missing
        absent(project_rows(node,identity,[unknown]),"save_effect_unavailable","Null/empty effect has no authored selector identity")
    var outcome:Dictionary=source.duplicate(true);outcome.fact.succeeded=null
    var unavailable:Dictionary=project_rows(node,identity,[outcome])
    check(not unavailable.ready and not unavailable.by_effect[EFFECT].ready and unavailable.by_effect[EFFECT].reason=="save_outcome_unavailable" \
        and not unavailable.by_effect[EFFECT].has("save_succeeded"),"Null outcome remains unavailable, never false")
    for conflicting in [false,true]:
        var duplicate:Dictionary=source.duplicate(true)
        if conflicting:duplicate.fact.succeeded=not source.fact.succeeded
        var ambiguous:Dictionary=project_rows(node,identity,[source,duplicate])
        check(not ambiguous.ready and ambiguous.by_effect[EFFECT].reason=="save_result_ambiguous" \
            and not ambiguous.by_effect[EFFECT].has("save_succeeded") and ambiguous.by_effect[EFFECT].evidence.save_occurrences.size()==2,
            "Identical/conflicting duplicate saves cannot choose an arbitrary result")
    var second:Dictionary=source.duplicate(true);second.fact.effect_id="private-independent-effect";second.fact.succeeded=not source.fact.succeeded
    var separate:Dictionary=project_rows(node,identity,[source,second])
    check(separate.ready and separate.by_effect.size()==2 and separate.by_effect[EFFECT].save_succeeded==source.fact.succeeded \
        and separate.by_effect[second.fact.effect_id].save_succeeded==second.fact.succeeded,"Distinct exact effects on one application do not overwrite or borrow each other")
    var canceled:Dictionary={"id":"private-save","lineage_id":"private-lineage","fact":source.fact,
        "resolution_record":node.resolution_record,"canceled":true}
    check(Results.index([canceled]).is_empty(),"Existing result index excludes canceled saving throws")
    absent(Results.save_context(node,Results.index([canceled])),"save_effect_unavailable","Canceled save cannot supply a live application")
    var no_damage:Dictionary=results.duplicate();no_damage[identity]={"saves":[source],"damage":[]}
    check(Results.save_context(node,no_damage).by_effect[EFFECT].save_succeeded==source.fact.succeeded,"Save selection does not require damage or infer a damage outcome")
func project_rows(node:Dictionary,identity:Array,rows:Array)->Dictionary:
    return Results.save_context(node,{identity:{"saves":rows,"damage":[]}})
func absent(context:Dictionary,reason:String,label:String)->void:
    check(not context.ready and context.reason==reason and context.by_effect.is_empty(),label)

func target_cast(seat:String)->void:
    var directory:String=ROOT_BASE+seat+"/journal"
    var journal:RefCounted=Journal.new();var opened:Dictionary=journal.open(directory,true,false)
    check(opened.ok,seat+" original Ray journal selects its recorded producer contract")
    if not opened.ok:return
    var path:String=directory+"/0000000000000008.json"
    var decoded:Dictionary=journal.decode_record(8,FileAccess.get_file_as_bytes(path))
    check(decoded.ok,seat+" original target-bearing Ray cast uses the real SDK reader")
    if not decoded.ok:return
    var packet:Dictionary=decoded.value
    var original_bytes:PackedByteArray=var_to_bytes(packet)
    var found:bool=false
    for raw in packet.lineages:
        var group:Dictionary=Occurrences.group(raw)
        var owners:Dictionary={}
        for event in group.events:owners[event.lineage_id]=event
        var results:Dictionary=Results.index(group.events,owners)
        check(results==Results.index(group.events),seat+" an existing native owner map and standalone indexing agree")
        for node in group.events:
            if node.get("fact")==null or node.fact.get("kind")!="spell" or node.fact.get("behavior_id")!="spell.ray_of_sickness":continue
            found=true
            check(str(node.id)=="67" and str(node.lineage_id)=="41" and node.phase=="completion" \
                and node.fact.attack_outcome=="Hit",seat+" actual root cast is the original completed Hit")
            check(not Occurrences.application(node) and Results.key(node).is_empty() \
                and Results.scope_key(node)==["41",null],seat+" real null application remains null, not a forged constructor identity")
            var context:Dictionary=Results.save_context(node,results)
            check(context.ready and context.by_effect.has(ROOT_EFFECT),seat+" actual target cast consumes its own disclosed save")
            if not context.by_effect.has(ROOT_EFFECT):continue
            var row:Dictionary=context.by_effect[ROOT_EFFECT]
            check(row.ready and row.save_succeeded==true and row.evidence=={
                "cast_lineage":"41","application_id":null,"application_occurrence":"67","application_lineage":"41",
                "target_uuid":"b6d87955-ade7-482d-8775-3829f91d7071","effect_id":ROOT_EFFECT,
                "scope":"target_cast","save_occurrence":"65","save_lineage":"62"},
                seat+" original target-cast evidence preserves exact native identities and successful outcome")
            var indexed:Dictionary=results[Results.scope_key(node)].saves[0]
            check(indexed.owner_occurrence=="67" and indexed.owner_lineage=="41",seat+" save belongs to its actual nearest native owner")
            check(Results.project(node,{"save_effect_id":ROOT_EFFECT,"damage_type":"Poison"},results).reason=="application_result_identity_unavailable",
                seat+" application-only constructors cannot acquire a synthetic root application")
            target_controls(node,group.events,results)
    check(found,seat+" original Ray target-cast witness was exercised")
    check(var_to_bytes(packet)==original_bytes,seat+" root-save projection leaves original packets unchanged")

func target_controls(owner:Dictionary,events:Array,results:Dictionary)->void:
    var original:PackedByteArray=var_to_bytes(events)
    var save:Dictionary=events.filter(func(node):return str(node.id)=="65")[0]
    var identity:Array=Results.scope_key(owner)
    var indexed:Dictionary=results[identity].saves[0]
    var opposite:Dictionary=indexed.duplicate(true);opposite.fact.succeeded=false
    check(project_rows(owner,identity,[opposite]).by_effect[ROOT_EFFECT].save_succeeded==false,
        "Private root value control preserves a disclosed false independently from the original true")
    var canceled:Array=events.duplicate(true)
    canceled.filter(func(node):return node.id==save.id)[0].canceled=true
    absent(Results.save_context(owner,Results.index(canceled)),"save_effect_unavailable","Private canceled root save cannot select")
    var unresolved:Dictionary=owner.duplicate(true);unresolved.phase="request"
    absent(Results.save_context(unresolved,results),"application_result_identity_unavailable","Private unresolved target cast cannot select")
    var no_target:Dictionary=owner.duplicate(true);no_target.fact.target_entity_uuid=null
    absent(Results.save_context(no_target,results),"application_result_identity_unavailable","Private targetless carrier cannot borrow a target save")
    var other_owner:Dictionary=owner.duplicate(true);other_owner.id="private-other-owner"
    absent(Results.save_context(other_owner,results),"save_effect_unavailable","Matching resolution and target cannot replace exact native owner identity")
    var other_cast:Dictionary=owner.duplicate(true);other_cast.resolution_record.lineage="private-other-cast"
    absent(Results.save_context(other_cast,results),"save_effect_unavailable","Private foreign cast cannot borrow a root result")
    var other_target:Dictionary=owner.duplicate(true);other_target.fact.target_entity_uuid="private-other-target"
    absent(Results.save_context(other_target,results),"save_effect_unavailable","Private foreign target cannot borrow a root result")
    # Private metadata controls keep the original save/resolution but interpose
    # a nearer boundary. These are not recorded game sequences or new facts.
    for kind in ["spell","action","attack"]:
        for stopped in [false,true]:
            var copied:Array=events.duplicate(true)
            var boundary:Dictionary=owner.duplicate(true)
            boundary.id="private-nested-owner";boundary.lineage_id="private-nested-lineage"
            boundary.parent_lineage=owner.lineage_id;boundary.canceled=stopped;boundary.fact.kind=kind
            copied.append(boundary)
            copied.filter(func(node):return node.id==save.id)[0].parent_lineage=boundary.lineage_id
            var projected:Dictionary=Results.index(copied)
            absent(Results.save_context(owner,projected),"save_effect_unavailable",
                "Private nearer "+kind+" boundary cannot leak its save to the outer cast; canceled="+str(stopped))
            var actual:Dictionary=projected[identity].saves[0]
            check(actual.owner_occurrence==("" if stopped else boundary.id),
                "Private save retains only its actual nearest uncanceled "+kind+" owner")
    var blocked:Array=events.duplicate(true)
    blocked.filter(func(node):return node.id==owner.id)[0].canceled=true
    absent(Results.save_context(owner,Results.index(blocked)),"save_effect_unavailable","Private canceled ancestor cannot lend its descendant result")
    var foreign:Dictionary=indexed.duplicate(true);foreign.fact.effect_id="private-concentration-effect"
    var separated:Dictionary=project_rows(owner,identity,[foreign])
    check(separated.ready and not separated.by_effect.has(ROOT_EFFECT) and separated.by_effect.has(foreign.fact.effect_id),
        "Private independent effect remains separately keyed, never a Ray save")
    check(var_to_bytes(events)==original,"Private owner-boundary controls leave actual original events unchanged")
