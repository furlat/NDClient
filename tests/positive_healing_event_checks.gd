extends "res://tests/support_spell_event_checks.gd"
## Original injured/zero-heal journals and the ordinary compiler. Inputs are
## checked without constructing GPU geometry; native output has its own gate.
const RESTORATION=["high-level-22/power-word-heal/full_restoration","high-level-22/power-word-heal/restoration_cross"]
const POSITIVE="res://tests/fixtures/schema16/scenarios/power-word-heal-restoration"
const ZERO="res://tests/fixtures/schema16/scenarios/power-word-heal"
func run()->void:
    var path:String="res://authoring/abilities/spells/spell.power_word_heal.tres"
    var entry:Resource=load(path)
    var built:Dictionary=Build.documents({"spells":{"spell.power_word_heal":entry},"contexts":{"hit_flash":load("res://authoring/abilities/contexts/hit_flash.tres")}},{"spells":{"spell.power_word_heal":path}})
    for cue_index in [1,2]:
        var cue:Resource=entry.effects[cue_index]
        check(cue.constructor_input.kind=="observed_event" and cue.constructor_input.outcome=="heal" and cue.constructor_input.geometry_actor=="target",str(cue_index)+" requires an actual positive recipient heal")
        check(cue.at=="cast" and cue.scope=="recipient" and cue.endpoint_actor_uuids,str(cue_index)+" finite result starts from the observed event clock and exact recipient")
    check(entry.status=="partial" and entry.owner_ids.is_empty() and entry.applies_conditions.is_empty(),"Finite restoration claims neither persistent ownership nor fixture conditions")
    for seat in ["amber","blue"]:
        await healing_seat(POSITIVE,seat,true,entry,built,{"spell.power_word_heal":path})
        await healing_seat(ZERO,seat,false,entry,built,{"spell.power_word_heal":path})
    print("POSITIVE_HEALING_EVENTS ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual positive/zero healing, exact finite source admission, committed condition removals and canonical replay parity. GPU output and acceptance are separate."}))
    quit(0 if failures.is_empty() else 1)
func healing_seat(directory:String,seat:String,positive:bool,entry:Resource,built:Dictionary,paths:Dictionary)->void:
    var label:String=("positive/" if positive else "zero/")+seat
    directory=directory.path_join(seat)
    var journal:RefCounted=Journal.new();check(journal.open(directory,true,false).ok,label+" opens unchanged original journal")
    var cache:Dictionary=source_cache(built,paths)
    var timeline:RefCounted=Timeline.new();var duration:float=0.0
    var cast_count:int=0;var healed:int=0;var projected_count:int=0
    var components:Array=[];var actual_removals:Array=[]
    var files:PackedStringArray=DirAccess.get_files_at(directory);files.sort()
    for file in files:
        if file.get_basename().length()!=16 or not file.get_basename().is_valid_int():continue
        var sequence:int=int(file.get_basename());var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(file))
        var decoded:Dictionary=journal.decode_record(sequence,raw)
        check(decoded.ok,label+" decode "+str(sequence));if not decoded.ok:return
        var before:Dictionary=journal.state
        var folded:Dictionary=journal._consume_admitted(decoded.value,raw,true)
        check(folded.ok,label+" fold "+str(sequence));if not folded.ok:return
        if sequence==0:
            timeline.accept({"kind":"initialization","state":journal.state.duplicate(true),"sequence":0});continue
        var immutable:PackedByteArray=var_to_bytes(folded.normalized)
        var operation_heals:Dictionary={}
        var native_index:int=0
        for native in folded.normalized.lineages:
            var lineage:Dictionary=Occurrences.group(native)
            var graph:Dictionary=graph_for(lineage.events)
            var event_index:int=0
            var removed_members:Dictionary={}
            for captured in folded.transitions.lineages[native_index].events:
                var changed:Dictionary=lineage.events[event_index];event_index+=1
                for change in captured.get("condition_rows",[]):
                    if change.before!=null and change.after==null:
                        if not graph.condition_cues.has(changed.id):graph.condition_cues[changed.id]=[]
                        graph.condition_cues[changed.id].append({"actor_uuid":change.actor_uuid,"condition":change.before,"phase":"removal"})
                        removed_members[change.before.condition_uuid]={"actor_uuid":change.actor_uuid,"condition_uuid":change.before.condition_uuid,"behavior_id":change.before.behavior_id,"removal_occurrence":changed.id}
            graph.observed_results=Results.observed_index(lineage.events,graph)
            native_index+=1
            for node in lineage.events:
                if node.get("fact")==null:continue
                if node.fact.kind=="heal" and int(node.fact.actual_healing)>0:
                    operation_heals[str(node.id)]=node.fact;healed+=int(node.fact.actual_healing)
                if node.fact.get("behavior_id")!="spell.power_word_heal":continue
                cast_count+=1
                var removals:Array=Results.observed(node,{"outcome":"removal","geometry_actor":"target"},graph)
                for removal in removals:
                    for condition_uuid in removal.event.removed_condition_uuids:
                        check(removed_members.has(condition_uuid),label+" removal names a genuinely captured before-value membership")
                        if removed_members.has(condition_uuid):
                            var member:Dictionary=removed_members[condition_uuid]
                            check(member.actor_uuid==removal.target_uuid,label+" every actual descendant removal retains its own disclosed actor, including the former Hold Person caster")
                            if member.behavior_id in ["condition.paralyzed","condition.spell.hold_person"]:
                                check(member.actor_uuid==node.fact.target_entity_uuid,label+" cured paralysis and Hold Person membership belong to the actual PWH patient")
                            actual_removals.append(member)
                var observed:Array=Results.observed(node,entry.effects[1].constructor_input,graph)
                check(observed.size()==(1 if positive else 0),label+" zero healing cannot emit restoration and positive healing has one actual result")
                for projection in observed:
                    projected_count+=1
                    var fact:Dictionary=projection.node.fact
                    check(projection.event.heal_fact==fact and projection.event.actual_healing==fact.actual_healing \
                        and projection.event.blocked==fact.was_blocked,label+" exact public HealFact is supplied alongside compatible flat fields")
                    check(projection.event.uuid==str(projection.node.id) and projection.event.source_entity_uuid==fact.source_entity_uuid \
                        and projection.event.target_entity_uuid==fact.target_entity_uuid,label+" actual result occurrence/source/recipient identities survive projection")
                    check(projection.values.source_entity_uuid==node.fact.source_entity_uuid and projection.values.recipient_entity_uuid==fact.target_entity_uuid \
                        and projection.values.geometry_actor==fact.target_entity_uuid,label+" original caster remains source and real patient owns geometry")
                    check(projection.values.lease.is_empty() and projection.values.event.is_empty(),label+" Factory successful review packets are cleared")
                    for cue_index in [1,2]:
                        var cue:Resource=entry.effects[cue_index]
                        var clip:Dictionary=Effects.clip(cue.clip)
                        var phase:Resource=load(Effects.choice(clip).approaches[0].source_phase)
                        var sealed:PackedByteArray=var_to_bytes(phase.to_clip())
                        var private:Dictionary=Adapter.clip_with_inputs(phase,[{"component_path":cue.constructor_input.component_path,"input_field":"","values":projection.values}])
                        var source:Node3D=load(private.components[0].script).new();source.settings=private.components[0].input;source.event_input=projection.event;source.lease={}
                        check(source.event_admitted() and source.phase_admitted() and not source.owner_admitted(),label+" sealed "+cue.clip+" admits only finite actual healing")
                        check(source.settings.mode=="instant" and source.settings.event.is_empty() and source.settings.lease.is_empty(),label+" finite restoration never borrows a held lease/review event")
                        var control:Dictionary=projection.event.duplicate(true);control.heal_fact.was_blocked=true;source.event_input=control
                        check(not source.phase_admitted(),label+" private blocked-heal negative control cannot admit restoration")
                        control=projection.event.duplicate(true);control.heal_fact.actual_healing=0;source.event_input=control
                        check(not source.phase_admitted(),label+" private zero-heal negative control cannot admit restoration")
                        control=projection.event.duplicate(true);control.heal_fact.target_entity_uuid=node.fact.source_entity_uuid;source.event_input=control
                        check(not source.phase_admitted(),label+" another recipient's heal cannot admit this source")
                        source.free();check(var_to_bytes(phase.to_clip())==sealed,label+" original sealed source remains immutable")
                    var foreign:Dictionary=node.duplicate(true);foreign.fact.source_entity_uuid=projection.node.fact.target_entity_uuid
                    check(Results.observed(foreign,entry.effects[1].constructor_input,graph).is_empty(),label+" a foreign caster cannot claim this actual heal")
                    evidence.append({"seat":seat,"sequence":sequence,"source_occurrence":node.id,"result_occurrence":projection.node.id,"source_lineage":node.lineage_id,"result_lineage":projection.node.lineage_id,"heal_fact":fact})
        var compiled:Dictionary=Compiler.compile_recorded(before,folded.normalized,cache,journal.state,folded.transitions)
        check(compiled.ok,label+" production compile "+str(sequence));if not compiled.ok:return
        timeline.accept({"kind":"operation","groups":compiled.value.groups})
        for group in compiled.value.groups:
            duration+=float(group.duration_ms)
            for component in group.components:
                if component.get("native_clip",{}).get("id") not in RESTORATION:continue
                components.append(component)
                check(component.status=="available" and not component.get("persistent_owner",false),label+" actual restoration component is available and finite")
                var fact:Dictionary=operation_heals.get(str(component.source_event_uuid),{})
                check(not fact.is_empty() and component.native_inputs.event_input.heal_fact==fact,label+" compiled source belongs to this exact native positive heal")
                var commits:Array=group.commits.filter(func(commit):return str(commit.get("event_uuid",""))==str(component.source_event_uuid))
                check(commits.size()==1 and is_equal_approx(component.start_ms,commits[0].at_ms),label+" restoration begins at the actual healing commit, with no second cast delay")
                check(is_equal_approx(component.duration_ms,1700.0 if component.native_clip.id==RESTORATION[0] else 850.0),label+" exact original finite source duration is retained")
        check(var_to_bytes(folded.normalized)==immutable,label+" original packets are not rewritten by compilation")
    check(cast_count==1 and projected_count==(1 if positive else 0),label+" exactly one real cast and expected actual result")
    check(healed>0 if positive else healed==0,label+" actual positive/zero healing distinction")
    check(components.size()==(2 if positive else 0),label+" each result owns exactly two finite restoration sources, none for zero")
    if positive:
        check(actual_removals.any(func(row):return row.behavior_id=="condition.paralyzed"),label+" real Power Word Heal removes the disclosed paralysis membership")
        check(actual_removals.all(func(row):return not row.condition_uuid.is_empty() and not row.actor_uuid.is_empty()),label+" removals retain actual condition/recipient identities")
        evidence.append({"seat":seat,"removed_conditions":actual_removals})
    timeline.advance(duration+1000.0)
    check(not timeline.busy() and Compare.difference(timeline.state,journal.state).is_empty(),label+" ordinary replay drains to exact independent reducer state without clock holds")
