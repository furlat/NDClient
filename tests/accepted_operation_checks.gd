extends SceneTree
## The exact accepted actions in original journals; metadata mutations below
## are private negative controls, never replacement recordings or outcomes.
const Operations=preload("res://presentation/operation_results.gd")
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Occurrences=preload("res://presentation/occurrences.gd")
const Authoring=preload("res://presentation/authoring.gd")
const Build=preload("res://tools/presentation_build/abilities.gd")
const Common=preload("res://tools/presentation_build/common.gd")
const Effects=preload("res://presentation/effect_package.gd")
const ROOT="res://tests/fixtures/schema16/accepted-operations"
const IDS={"arcane-recovery":"action.class.wizard.arcane_recovery","scroll-learning":"action.wizard.learn_scroll"}
var checks:int=0
var failures:Array=[]
var admitted:Dictionary={}
var unavailable:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("ACCEPTED_OPERATION_FAIL "+label)

func run()->void:
    var entries:Dictionary={};var paths:Dictionary={}
    for id in IDS.values():
        var path:String="res://authoring/abilities/actions/"+id+".tres"
        var entry:Resource=load(path)
        check(entry.effects.size()==1,id+" has one exact accepted operation source")
        entries[id]=entry;paths[id]=path
        var report:Dictionary=Common.report()
        Build._check_constructor(entry.effects[0],id,{entry.effects[0].clip:Effects.clip(entry.effects[0].clip)},report)
        check(report.errors.is_empty(),id+" typed constructor passes offline source contract: "+str(report.errors))
    var built:Dictionary=Build.documents({"actions":entries},{"actions":paths})
    for case_id in IDS:
        for seat in ["amber","blue"]:read_case(case_id,seat,built,entries[IDS[case_id]].effects[0].constructor_input)
    check(admitted.get("arcane-recovery:amber",0)==1 and admitted.get("arcane-recovery:blue",0)==0,"Only the original controlling view receives recovery after the real opposing actor's death")
    check(admitted.get("scroll-learning:amber",0)==1,"The controlled original book change admits one learning source")
    check(unavailable.get("scroll-learning:blue",0)==1,"The other view retains its own missing item/book witness instead of borrowing Amber")
    print(JSON.stringify({"checks":checks,"failures":failures,"admitted":admitted,"unavailable":unavailable,
        "scope":"Original accepted actions, operation-level own sheet witness, typed compiler dispatch and immutable negative controls; native framebuffer/approval remain separate gates."}))
    quit(0 if failures.is_empty() else 1)

func source_cache(built:Dictionary)->Dictionary:
    var cache:Dictionary={}
    for document in ["catalog/body_action_bindings.json","catalog/body_action_recipes.json"]:
        var data:Dictionary=Authoring.load_data(document,cache).duplicate(false)
        data.merge(built.docs[document],true);cache[document]=data
    return cache

func read_case(case_id:String,seat:String,built:Dictionary,descriptor:Dictionary)->void:
    var directory:String=ROOT.path_join(case_id).path_join(seat)
    var journal:RefCounted=Journal.new();var opened:Dictionary=journal.open(directory,true,false)
    check(opened.ok,case_id+" "+seat+" original journal opens")
    if not opened.ok:return
    var cache:Dictionary=source_cache(built)
    var files:PackedStringArray=DirAccess.get_files_at(directory);files.sort()
    for file in files:
        if not file.ends_with(".json") or file.get_basename().length()!=16 or not file.get_basename().is_valid_int():continue
        var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(file))
        var decoded:Dictionary=journal.decode_record(int(file.get_basename()),raw)
        check(decoded.ok,case_id+" "+seat+" packet decodes "+file)
        if not decoded.ok:return
        var before:Dictionary=journal.state
        var folded:Dictionary=journal._consume_admitted(decoded.value,raw,true)
        check(folded.ok,case_id+" "+seat+" packet folds "+file)
        if not folded.ok:return
        if int(file.get_basename())==0:continue
        var original:PackedByteArray=var_to_bytes(folded.normalized)
        var prior:PackedByteArray=var_to_bytes(before)
        var sheets:Dictionary=Operations.sheets(before,folded.normalized)
        var compiled:Dictionary=Compiler.compile_recorded(before,folded.normalized,cache,journal.state,folded.transitions)
        check(compiled.ok,case_id+" "+seat+" complete original packet compiles")
        if not compiled.ok:return
        var components:Array=[]
        for group in compiled.value.groups:components.append_array(group.components)
        for native in folded.normalized.lineages:
            var lineage:Dictionary=Occurrences.group(native)
            var graph:Dictionary={"operation_sheets":sheets,"nodes":{}}
            for node in lineage.events:graph.nodes[node.lineage_id]=node
            for node in lineage.events:
                if node.get("fact")==null or node.fact.get("behavior_id")!=IDS[case_id] or node.fact.kind!="action" or node.phase!="completion" or node.canceled:continue
                var observed:Dictionary=Operations.project(node,descriptor,graph)
                var matching:Array=components.filter(func(row):return row.get("source_event_uuid")==str(node.id) and row.get("native_cue",{}).get("constructor_input",{}).get("kind")=="observed_operation")
                check(matching.size()==1,case_id+" "+seat+" owns exactly one finite typed source at its actual event")
                if matching.size()!=1:continue
                var component:Dictionary=matching[0]
                var key:String=case_id+":"+seat
                if not observed.ready:
                    unavailable[key]=int(unavailable.get(key,0))+1
                    check(component.status=="missing" and component.reason==observed.reason,seat+" unavailable disclosed operand stays explicit: "+str(observed.reason))
                    check(not component.has("native_constructor_inputs"),seat+" unavailable source cannot construct its review fixture")
                    continue
                admitted[key]=int(admitted.get(key,0))+1
                check(component.get("status")!="missing" and component.native_inputs==observed.inputs,seat+" actual operation packet reaches the ordinary native dispatcher")
                check(component.native_constructor_inputs==[{"component_path":["wizard_operation"],"input_field":"","values":observed.values}],seat+" private constructor receives exactly observed identities")
                check(component.ability_kind=="action" and component.ability_id==node.fact.behavior_id and not component.has("spell_id"),seat+" operation remains its real action domain")
                check(observed.values.operation_uuid==str(node.id) and observed.values.actor_uuid==node.fact.source_entity_uuid,seat+" source identities are actual native occurrence and actor")
                check(observed.values.state.is_empty() and observed.values.review_states.is_empty() and not observed.inputs.operation_state.has("restored_slot_ranks"),seat+" review acceptance and slot outcomes are cleared rather than invented")
                check(component.native_constructor_evidence.operation_lineage==node.lineage_id,seat+" original local lineage is retained independently from operation identity")
                if case_id=="scroll-learning":
                    var actual:Array=folded.normalized.hud.sheets.filter(func(row):return row.actor_uuid==node.fact.source_entity_uuid and row.changes.has("scribed_spell_ids"))
                    check(actual.size()==1 and observed.values.learned_spell_id in actual[0].changes.scribed_spell_ids,seat+" learned ID comes from this original own sheet patch")
                    var charges:Array=lineage.events.filter(func(row):return row.get("fact")!=null and row.fact.kind=="item_charge" and row.fact.source_entity_uuid==node.fact.source_entity_uuid)
                    check(observed.values.learned_spell_id=="spell.hold_person" and charges.size()==1 and observed.values.item_uuid==charges[0].fact.item_uuid,seat+" genuine consumed Hold Person scroll identity replaces the Fire Bolt review fixture")
                    check(node.fact.get("source_item_uuid")==null and observed.evidence.item_identity=="descendant_consumed_charge" \
                        and observed.evidence.item_charge_occurrences==[str(charges[0].id)] and observed.evidence.item_charge_lineages==[str(charges[0].lineage_id)],seat+" last-charge retirement preserves the exact native charge ancestry without inventing an ActionFact field")
                    check(observed.evidence.sheet_witness.scope=="operation_hud" and not observed.evidence.has("sheet_occurrence"),seat+" aggregated sheet disclosure is never relabeled as a descendant event")
                controls(node,descriptor,sheets,graph)
        check(var_to_bytes(before)==prior and var_to_bytes(folded.normalized)==original,seat+" projection/compiler preserve the immutable prior cut and original packet")
        check(FileAccess.get_file_as_bytes(directory.path_join(file))==raw,seat+" original raw journal bytes stay unchanged")

func controls(node:Dictionary,descriptor:Dictionary,sheets:Dictionary,graph:Dictionary)->void:
    for field in ["canceled","phase","kind","source","application"]:
        var changed:Dictionary=node.duplicate(true)
        if field=="canceled":changed.canceled=true
        elif field=="phase":changed.phase="declaration"
        elif field=="kind":changed.fact.kind="spell"
        elif field=="source":changed.fact.source_entity_uuid=null
        else:changed.resolution_record={"application_id":"private-negative"}
        check(not Operations.project(changed,descriptor,graph).ready,"Private "+field+" value control cannot create an accepted operation")
    if descriptor.operation!="scribe":return
    var no_item:Dictionary=node.duplicate(true);no_item.fact.source_item_uuid=null
    check(Operations.project(no_item,descriptor,{"operation_sheets":sheets}).reason=="operation_source_item_not_disclosed","Private absent source item and charge cannot borrow a cached scroll")
    check(not Operations.project(node,descriptor,{}).ready,"No own operation sheet cannot borrow another view's book")
    for field in ["known_before","added","accepted","other_behavior"]:
        var changed:Dictionary=sheets.duplicate(true);var witness:Dictionary=changed[str(node.fact.source_entity_uuid)]
        if field=="known_before":witness.known_before=false
        elif field=="added":witness.added=["private-one","private-two"]
        elif field=="accepted":witness.accepted[str(node.fact.behavior_id)]=[str(node.id),"private-second"]
        else:witness.accepted["private.other_action"]=["private-second"]
        var control:Dictionary=graph.duplicate();control.operation_sheets=changed
        check(not Operations.project(node,descriptor,control).ready,"Private ambiguous "+field+" cannot select an invented learned spell")
    var charges:Array=graph.nodes.values().filter(func(row):return row.get("fact")!=null and row.fact.kind=="item_charge")
    check(charges.size()==1,"Original learned scroll has one actual native consumed-item observation")
    if charges.size()!=1:return
    for field in ["source","parent","canceled","resource_change","ambiguous","nested_action","canceled_ancestor"]:
        var control:Dictionary=graph.duplicate(true)
        var charge:Dictionary=control.nodes[str(charges[0].lineage_id)]
        if field=="source":charge.fact.source_entity_uuid="private-other-actor"
        elif field=="parent":charge.parent_lineage=null
        elif field=="canceled":charge.canceled=true
        elif field=="resource_change":charge.fact.resource_change="recover"
        elif field=="ambiguous":
            var other:Dictionary=charge.duplicate(true);other.id="private-second";other.lineage_id="private-second";other.fact.item_uuid="private-other-item"
            control.nodes[other.lineage_id]=other
        else:
            control.nodes["private-ancestor"]={"id":"private-ancestor","lineage_id":"private-ancestor",
                "parent_lineage":node.lineage_id,"canceled":field=="canceled_ancestor",
                "fact":{"kind":"action"} if field=="nested_action" else null}
            charge.parent_lineage="private-ancestor"
        check(not Operations.project(node,descriptor,control).ready,"Private charge "+field+" cannot supply the exact learned scroll identity")
