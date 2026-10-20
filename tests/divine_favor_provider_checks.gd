extends SceneTree
## Real independent journals; mutated negative controls are not recordings.
const Results=preload("res://presentation/application_results.gd")
const Recording=preload("res://studio/recording.gd")
const Journal=preload("res://sdk/journal.gd")
const Occurrences=preload("res://presentation/occurrences.gd")
const Build=preload("res://tools/presentation_build/abilities.gd")
const Common=preload("res://tools/presentation_build/common.gd")
const Sources=preload("res://presentation/native_presentation_sources.gd")
const Spells=preload("res://presentation/native_spell_authoring.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Adapter=preload("res://presentation/native_constructed_occurrence.gd")
const ROOT="res://tests/fixtures/schema16/weapon-enchantment-lifecycle/divine-favor"
const ID="spell.divine_favor"
const CONDITION="condition.spell.divine_favor"
const OWNER="cb23fb5c-34ed-4488-a2eb-a6632d4a45e4"
const ACTOR="7e2c178d-50ac-430b-862b-1efe0620d7c2"
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("DIVINE_FAVOR_PROVIDER_FAIL ",label)
func cache_for(record:Resource)->Dictionary:
    var cache:Dictionary={};var admitted:Dictionary=Sources.admission(cache)
    var index:Resource=admitted.index.duplicate();index.spells=admitted.index.spells.duplicate()
    index.spells[ID]="res://authoring/abilities/spells/spell.divine_favor.tres"
    var loaded:Dictionary=admitted.loaded.duplicate();loaded[ID]=record
    cache[Sources.CACHE_KEY]=Sources.make_admission(index,loaded);return cache
func run()->void:
    var entry:Resource=load("res://authoring/abilities/spells/spell.divine_favor.tres")
    var use:Resource=entry.effects[0];var clip:Dictionary=Effects.clip(use.clip)
    var report:Dictionary=Common.report()
    Build._check_constructor(use,ID,{clip.id:clip},report)
    check(report.errors.is_empty(),"Actual non-hit source branch has an offline-qualified input policy: "+str(report.errors))
    var invalid:Resource=use.duplicate(true);invalid.clip="bg3-36/divine-favor/divine_favor_native/hit"
    report=Common.report();Build._check_constructor(invalid,ID,{invalid.clip:Effects.clip(invalid.clip)},report)
    check(not report.errors.is_empty(),"Same input waiver is refused on the actual hit phase")
    check(entry.body.hidden_slots.is_empty(),"Actual authored cast preserves the real equipped item surface")
    check(Array(entry.owner_cues)==[1,2,3] and Array(entry.excluded_cues)==[4],"Application/hold/retirement have one existing lifecycle; fixed-delay hit is excluded")
    var built:Dictionary=Build.documents({"spells":{ID:entry},"contexts":{"hit_flash":load("res://authoring/abilities/contexts/hit_flash.tres")}},
        {"spells":{ID:"res://authoring/abilities/spells/spell.divine_favor.tres"}})
    var record:Resource=built.native.records[ID]
    check(Spells.event_cues(record.selection).size()==1 and Spells.owned_cues(record.selection)==[1,2,3],"Only the finite windup remains cast-owned")
    for seat in ["amber","blue"]:actual_seat(seat,entry,record)
    print("DIVINE_FAVOR_PROVIDER ",JSON.stringify({"checks":checks,"failures":failures,"scope":"Actual descendant condition identity, phase-specific required inputs, constructor fixture removal, one existing held lifecycle, exact canonical/ordered retirement and original miss negative. Native pixels and positive attributed Radiant contact are separate gates."}))
    quit(0 if failures.is_empty() else 1)
func actual_seat(seat:String,entry:Resource,record:Resource)->void:
    var directory:String=ROOT.path_join(seat).path_join("journal")
    var journal:RefCounted=Journal.new();check(journal.open(directory,true,false).ok,seat+": independent original opens")
    var files:PackedStringArray=DirAccess.get_files_at(directory);files.sort()
    var cast_count:int=0;var missed:bool=false;var radiant:bool=false
    var phase:Resource=load(Effects.choice(Effects.clip(entry.effects[0].clip)).approaches[0].source_phase)
    var sealed:PackedByteArray=var_to_bytes(phase.to_clip())
    for file in files:
        if file.get_basename().length()!=16 or not file.get_basename().is_valid_int():continue
        var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(file))
        var decoded:Dictionary=journal.decode_record(int(file.get_basename()),raw)
        check(decoded.ok,seat+": decode actual packet "+file)
        if not decoded.ok:return
        var folded:Dictionary=journal._consume_admitted(decoded.value,raw,true)
        check(folded.ok,seat+": independent canonical fold "+file)
        if not folded.ok:return
        if int(file.get_basename())==0:continue
        for actual in folded.normalized.lineages:
            var lineage:Dictionary=Occurrences.group(actual)
            for node in lineage.events:
                if node.fact==null:continue
                if node.fact.kind=="attack" and int(file.get_basename())==7:missed=node.fact.attack_outcome=="Miss"
                if node.fact.kind=="damage" and node.fact.get("damage_type")=="Radiant" and int(node.fact.get("applied_damage",0))>0:radiant=true
                if node.fact.kind!="spell" or node.fact.get("behavior_id")!=ID:continue
                cast_count+=1
                var graph:Dictionary={"nodes":{},"condition_cues":{}}
                for child in lineage.events:
                    graph.nodes[child.lineage_id]=child
                    if child.fact==null or child.fact.kind!="actor_change":continue
                    for actor in child.fact.actors:
                        for row in actor.rows:
                            if row.field=="condition" and row.get("member",{}).get("behavior_id")==CONDITION:
                                graph.condition_cues[child.id]=[{"phase":"application","actor_uuid":actor.actor_uuid,"condition":row.member}]
                graph.observed_results=Results.observed_index(lineage.events,graph)
                var projected:Dictionary=Results.condition_application(node,entry.effects[0].constructor_input,graph)
                check(projected.ready,seat+": actual cast finds its unique native descendant condition")
                if not projected.ready:continue
                check(projected.condition.condition_uuid==OWNER and projected.condition.state.affected_item_uuid==null \
                    and projected.evidence.actor_uuid==ACTOR and projected.evidence.application_occurrence=="22",seat+": actual actor-owned benefit is not an item-owned enchantment")
                var private:Dictionary=Adapter.clip_with_inputs(phase,[{"component_path":["weapon_blessing"],"input_field":"","values":projected.values}])
                var input:Dictionary=private.components[0].input
                check(input.ownership=={"owner_kind":"caster","owner_uuid":ACTOR,"effect_uuid":OWNER,"binding":{}} \
                    and input.hit.is_empty(),seat+": private construction removes every fixture owner/binding/hit")
                check(input.material==phase.to_clip().components[0].input.material and input.phase=="windup",seat+": source artwork and actual selected phase stay unchanged")
                var foreign:Dictionary=node.duplicate(true);foreign.fact.source_entity_uuid="negative-control-actor"
                check(not Results.condition_application(foreign,entry.effects[0].constructor_input,graph).ready,seat+": another actor cannot borrow the real member")
                var canceled:Dictionary=node.duplicate(false);canceled.canceled=true
                check(not Results.condition_application(canceled,entry.effects[0].constructor_input,graph).ready,seat+": canceled cast cannot acquire it")
                check(not Results.condition_application(node,entry.effects[0].constructor_input,{"observed_results":{}}).ready,seat+": missing native descendant stays unavailable")
                var duplicate:Dictionary=graph.duplicate(true)
                duplicate.observed_results[node.id].append(projected_row(graph.observed_results[node.id]))
                check(not Results.condition_application(node,entry.effects[0].constructor_input,duplicate).ready,seat+": ambiguous same-owner admissions stay unavailable")
                for boundary in ["action","spell","canceled","same_cast_application"]:
                    var controlled:Dictionary=graph.duplicate(true)
                    var application:Dictionary=projected_row(controlled.observed_results[node.id])
                    application.node.parent_lineage="private-owner-boundary"
                    var intermediary:Dictionary={"lineage_id":"private-owner-boundary","parent_lineage":node.lineage_id,
                        "canceled":boundary=="canceled","fact":null,"resolution_record":{}}
                    if boundary!="canceled":
                        intermediary.fact=node.fact.duplicate();intermediary.fact.kind="action" if boundary=="action" else "spell"
                        if boundary=="same_cast_application":intermediary.resolution_record={"lineage":node.lineage_id,"application_id":"private-application-boundary"}
                    controlled.nodes[intermediary.lineage_id]=intermediary
                    check(Results.condition_application(node,entry.effects[0].constructor_input,controlled).ready==(boundary=="same_cast_application"),seat+": exact cast ownership across labelled "+boundary+" control")
    check(cast_count==1 and missed and not radiant,seat+": one original cast and real held Miss provide no fabricated positive Radiant contact")
    var index:Dictionary=Recording.read(directory,{},{},cache_for(record))
    check(index.ok,seat+": ordinary Recording compiles current typed production data")
    if not index.ok:return
    var finite:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).has("native_condition_application"))
    check(finite.size()==1,seat+": exactly one finite caster windup, no staged later hit")
    if finite.size()==1:
        var component:Dictionary=finite[0].component
        check(component.status=="available" and component.condition_uuid==OWNER \
            and component.native_constructor_evidence.application_occurrence=="22",seat+": compiler forwards actual condition identity and constructor evidence")
        check(not component.get("persistent_owner",false) and component.native_cue.input_policies.has("hit_input"),seat+": finite phase neither acquires the hold clock nor requires unused hit data")
    check(index.rows.all(func(row):return row.get("component",{}).get("native_cue",{}).get("staged_clip")!="bg3-36/divine-favor/divine_favor_native/hit"),seat+": no cast-scheduled contact survives")
    var end:RefCounted=Recording.restore(index,index.presentation_end_ms+1.0)
    check(end.state==journal.snapshot(),seat+": final ordinary replay exactly equals the independent audience reducer")
    check(var_to_bytes(phase.to_clip())==sealed,seat+": constructor projection never mutates the sealed source")
func projected_row(rows:Array)->Dictionary:
    return rows.filter(func(row):return row.kind=="condition_application" and row.condition.behavior_id==CONDITION)[0]
