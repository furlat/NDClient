extends SceneTree
## Original two-seat casts through the production compiler, with in-memory
## typed sources. No GPU construction, fixture outcomes or lease admission.
const Results=preload("res://presentation/application_results.gd")
const Occurrences=preload("res://presentation/occurrences.gd")
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Timeline=preload("res://presentation/timeline.gd")
const Spells=preload("res://presentation/native_spell_authoring.gd")
const Delivery=preload("res://presentation/spell_delivery.gd")
const Sources=preload("res://presentation/native_presentation_sources.gd")
const Build=preload("res://tools/presentation_build/abilities.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Adapter=preload("res://presentation/native_constructed_occurrence.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const CASES={"aura_of_life":"aura-of-life","foresight":"foresight","power_word_heal":"power-word-heal"}
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("SUPPORT_SPELL_EVENT_FAIL ",label)
func source_cache(built:Dictionary,paths:Dictionary)->Dictionary:
    var cache:Dictionary={}
    var admitted:Dictionary=Sources.admission(cache)
    var index:Resource=admitted.index.duplicate()
    index.spells=admitted.index.spells.duplicate();index.conditions=admitted.index.conditions.duplicate()
    var loaded:Dictionary=admitted.loaded.duplicate()
    for owner in index.conditions.keys():
        if paths.has(index.conditions[owner]):index.conditions.erase(owner)
    for id in paths:index.spells[id]=paths[id];loaded[id]=built.native.records[id]
    index.conditions.merge(built.native.conditions,true)
    cache[Sources.CACHE_KEY]=Sources.make_admission(index,loaded)
    return cache
func graph_for(events:Array)->Dictionary:
    var graph:Dictionary={"nodes":{},"condition_cues":{}}
    for node in events:graph.nodes[node.lineage_id]=node
    graph.observed_results=Results.observed_index(events,graph)
    return graph
func run()->void:
    var entries:Dictionary={};var paths:Dictionary={}
    for name in CASES:
        var id:String="spell."+name;var path:String="res://authoring/abilities/spells/"+id+".tres"
        entries[id]=load(path);paths[id]=path
        check(entries[id].effects[0].constructor_input.kind=="observed_event",id+" binds its finite observed cast")
        check(entries[id].effects[0].constructor_input.recipient_role==("target" if name=="power_word_heal" else "caster"),id+" has an explicit real recipient role")
        check(entries[id].status=="partial",id+" does not claim the whole family complete")
    var built:Dictionary=Build.documents({"spells":entries,"contexts":{"hit_flash":load("res://authoring/abilities/contexts/hit_flash.tres")}},{"spells":paths})
    var cache:Dictionary=source_cache(built,paths)
    check(Spells.condition("condition.spell.aura_of_life.owner",cache).id=="aura_of_life","Real Aura owner resolves to its authored spell")
    check(Spells.condition("condition.spell.aura_of_life.benefit",cache).id=="aura_of_life","Real Aura benefit resolves to its authored spell")
    check(Spells.condition("condition.spell.pass_without_trace.bonus",cache).get("id")!="aura_of_life","Pass Without Trace is never an Aura owner alias")
    check(Array(entries["spell.aura_of_life"].owner_ids)==["condition.spell.aura_of_life.benefit","condition.spell.aura_of_life.owner"] \
        and Array(entries["spell.aura_of_life"].applies_conditions)==["condition.spell.aura_of_life.benefit","condition.spell.aura_of_life.owner"],"Aura owner and applied references name only its actually disclosed owner/benefit, without legacy membership or Pass Without Trace aliases")
    for name in ["aura_of_life","foresight"]:
        var selected:Dictionary=built.native.records["spell."+name].selection
        check(0 not in selected.lifecycle.cue_ids and 0 not in Spells.owned_cues(selected),name+" finite preparation is not handed to a condition lifetime")
        check(Spells.condition_phases(selected).all(func(phase):return phase.native_cue.source_index!=0),name+" held phases cannot replay the casting preparation")
    var count:int=0
    for name in CASES:
        for seat in ["amber","blue"]:count+=read_seat(name,seat,entries["spell."+name],built,paths)
    check(count==6,"Exactly three actual casts qualify in each independent seat")
    print("SUPPORT_SPELL_EVENTS ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Finite input/constructor/production clock only; retained leases, healing restoration, pixels and user acceptance remain unqualified."}))
    quit(0 if failures.is_empty() else 1)
func read_seat(name:String,seat:String,entry:Resource,built:Dictionary,paths:Dictionary)->int:
    var id:String="spell."+name;var label:String=name+"/"+seat
    var directory:String="res://tests/fixtures/schema16/scenarios/"+CASES[name]+"/"+seat
    var journal:RefCounted=Journal.new()
    check(journal.open(directory,true,false).ok,label+" opens unchanged journal")
    var cache:Dictionary=source_cache(built,paths)
    var timeline:RefCounted=Timeline.new();var duration:float=0.0
    var cue:Resource=entry.effects[0];var descriptor:Dictionary=cue.constructor_input
    var clip:Dictionary=Effects.clip(cue.clip)
    var phase:Resource=load(Effects.choice(clip).approaches[0].source_phase)
    var sealed:PackedByteArray=var_to_bytes(phase.to_clip())
    var files:PackedStringArray=DirAccess.get_files_at(directory);files.sort()
    var count:int=0;var components:Array=[];var real_owners:Array=[]
    for file in files:
        if file.get_basename().length()!=16 or not file.get_basename().is_valid_int():continue
        var sequence:int=int(file.get_basename());var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(file))
        var decoded:Dictionary=journal.decode_record(sequence,raw)
        check(decoded.ok,label+" decode "+str(sequence))
        if not decoded.ok:return count
        var before:Dictionary=journal.state
        var folded:Dictionary=journal._consume_admitted(decoded.value,raw,true)
        check(folded.ok,label+" fold "+str(sequence))
        if not folded.ok:return count
        if sequence==0:
            timeline.accept({"kind":"initialization","state":journal.state.duplicate(true),"sequence":0});continue
        var unchanged:PackedByteArray=var_to_bytes(folded.normalized)
        for native in folded.normalized.lineages:
            var lineage:Dictionary=Occurrences.group(native);var graph:Dictionary=graph_for(lineage.events)
            for node in lineage.events:
                if node.get("fact")==null:continue
                if node.fact.kind=="actor_change":
                    for actor in node.fact.actors:
                        for row in actor.rows:
                            if row.field=="condition" and row.get("member")!=null:real_owners.append(row.member.behavior_id)
                if node.fact.get("behavior_id")!=id:continue
                var observed:Array=Results.observed(node,descriptor,graph)
                check(observed.size()==1,label+" original cast supplies one event")
                if observed.size()!=1:continue
                count+=1
                var projection:Dictionary=observed[0]
                var recipient:String=str(node.fact.target_entity_uuid) if descriptor.recipient_role=="target" else str(node.fact.source_entity_uuid)
                check(projection.target_uuid==recipient and projection.event.target_entity_uuid==recipient,label+" authored role resolves to the exact disclosed actor")
                check(projection.event.uuid==str(node.id) and projection.evidence.source_lineage==str(node.lineage_id),label+" exact local occurrence and lineage remain separate")
                check(projection.values.lease.is_empty() and projection.values.event.is_empty(),label+" constructor never retains successful review packets")
                check(not projection.event.has("actual_healing") and not projection.event.has("heal_fact"),label+" cast admission does not invent healing")
                var private_clip:Dictionary=Adapter.clip_with_inputs(phase,[{"component_path":descriptor.component_path,"input_field":"","values":projection.values}])
                var input:Dictionary=private_clip.components[0].input
                var source:Node3D=load(private_clip.components[0].script).new()
                source.settings=input;source.event_input=projection.event;source.lease={}
                check(source.phase_admitted() and not source.owner_admitted(),label+" real sealed source admits the finite event with no held lease")
                check(input.material==phase.to_clip().components[0].input.material and input.mode=="windup",label+" original material and finite mode stay unchanged")
                check(input.get("parent_owner_uuid","").is_empty(),label+" private finite input clears the unused review parent without changing the source preset")
                check(input.geometry_actor==node.fact.source_entity_uuid,label+" measured source surface belongs to the actual caster")
                if name=="power_word_heal":
                    check(input.voice_recipient_actor==node.fact.target_entity_uuid,label+" spoken path points to the actual patient")
                    check(Results.observed(node,{"outcome":"heal","geometry_actor":"target"},graph).is_empty(),label+" original zero healing cannot admit restoration")
                source.event_input=projection.event.duplicate();source.event_input.canceled=true
                check(not source.phase_admitted(),label+" canceled public event cannot admit artwork")
                source.event_input=projection.event.duplicate();source.event_input.source_entity_uuid=recipient if recipient!=node.fact.source_entity_uuid else "not-the-caster"
                check(not source.phase_admitted(),label+" another source cannot supply this cast")
                source.free()
                var undisclosed:Dictionary=node.duplicate(true);undisclosed.fact.target_entity_uuid=null
                var strict:Dictionary=descriptor.duplicate();strict.recipient_role="target"
                check(Results.observed(undisclosed,strict,graph).is_empty(),label+" target role never falls back to self when undisclosed")
                var positions:Dictionary={};positions[node.fact.source_entity_uuid]=[3,7]
                var endpoint_graph:Dictionary={"positions":positions,"contacts":{}}
                var selected:Dictionary=built.native.records[id].selection
                var actual_points:Dictionary=Delivery.endpoints(undisclosed.fact,endpoint_graph,{"tiles":{}},selected)
                check(actual_points.is_empty() if name=="power_word_heal" else not actual_points.is_empty(),label+" actual event-owned cues alone decide whether a real recipient is required")
                var legacy:Dictionary=descriptor.duplicate();legacy.erase("recipient_role")
                check(Results.observed(node,legacy,graph)[0].target_uuid==node.fact.source_entity_uuid,label+" old observed action constructors retain the caster default")
                evidence.append({"spell":id,"seat":seat,"source_occurrence":node.id,"source_lineage":node.lineage_id,"recipient_uuid":recipient})
        var compiled:Dictionary=Compiler.compile_recorded(before,folded.normalized,cache,journal.state,folded.transitions)
        check(compiled.ok,label+" production compile "+str(sequence))
        if not compiled.ok:return count
        timeline.accept({"kind":"operation","groups":compiled.value.groups})
        for group in compiled.value.groups:
            duration+=float(group.duration_ms)
            components.append_array(group.components.filter(func(row):return row.get("native_clip",{}).get("id")==cue.clip))
        check(var_to_bytes(folded.normalized)==unchanged,label+" compilation never rewrites original public rows")
    check(count==1 and components.size()==1,label+" exactly one finite casting source, no condition replay")
    for component in components:
        check(component.status=="available" and not component.get("persistent_owner",false),label+" finite cue is ready and cast-owned")
        check(component.native_inputs.lease_input.is_empty() and component.native_inputs.event_input.uuid==str(component.source_event_uuid),label+" setter and construction use the same actual occurrence")
        check(is_equal_approx(component.duration_ms,cue.source_end*1000.0),label+" authored finite duration is unchanged")
    if name=="aura_of_life":
        check("condition.spell.aura_of_life.owner" in real_owners and "condition.spell.aura_of_life.benefit" in real_owners,label+" real admitted owner and member exercise corrected handover")
        check("condition.spell.pass_without_trace.bonus" not in real_owners,label+" real Aura cast does not gain the former unrelated alias")
    timeline.advance(duration+1000.0)
    check(not timeline.busy() and Compare.difference(timeline.state,journal.state).is_empty(),label+" unchanged reducer prefix drains without clock holds")
    check(var_to_bytes(phase.to_clip())==sealed,label+" all construction leaves the sealed source immutable")
    return count
