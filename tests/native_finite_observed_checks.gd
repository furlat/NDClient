extends "res://tests/support_spell_event_checks.gd"
## Exact original finite results. Private negative controls are not recordings.
const FINITE_ROOT="res://tests/fixtures/schema16/finite-observed"
const FINITE_CASES={"vitriolic-sphere":"spell.vitriolic_sphere","divine-word":"spell.divine_word"}
const CONTACT="high-level-22/vitriolic-sphere/native_target_initial"
const PROCLAMATION="review/divine_word/back/proclamation"
const DUPLICATE_CONTACT="high-level-22/vitriolic-sphere/native_target2_initial"
func run()->void:
    var entries:Dictionary={};var paths:Dictionary={}
    for id in FINITE_CASES.values():
        var path:String="res://authoring/abilities/spells/"+id+".tres"
        entries[id]=load(path);paths[id]=path
        check(entries[id].status=="partial",id+" preserves its other missing phase inputs")
    var built:Dictionary=Build.documents({"spells":entries,"contexts":{"hit_flash":load("res://authoring/abilities/contexts/hit_flash.tres")}}, {"spells":paths})
    for name in FINITE_CASES:
        var entry:Resource=entries[FINITE_CASES[name]]
        var cue:Resource=finite_cue(entry,name)
        if cue==null:continue
        check(cue.constructor_input.kind=="observed_event" and cue.constructor_input.projection==("applied_contact" if name=="vitriolic-sphere" else "cast_completion"),name+" selects an explicit finite observed projection")
        check(cue.scope=="cast" and cue.at==("cast" if name=="vitriolic-sphere" else "release") and is_zero_approx(cue.delay),name+" root cast owns one factual fanout and preserves its explicit zero-delay source/result marker")
        if name=="vitriolic-sphere":
            check(cue.attachment=="recipient_ground" and cue.extra.entity_geometry.actor=="target" \
                and cue.extra.live_endpoints[0].actor=="target" and cue.constructor_input.damage_type=="Acid",name+" one source fans out by actual applied recipient")
            check(entry.owner_kind=="condition" and Array(entry.owner_ids)==["condition.spell.vitriolic_sphere.residue"] \
                and Array(entry.owner_cues)==[3,6] and 5 in entry.excluded_cues,name+" actual condition UUID lifecycles own held residue; duplicate review recipient is excluded")
        for seat in ["amber","blue"]:read_finite_seat(name,seat,entry,cue,built,paths)
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Independent original two-seat public facts, private projection/admission controls, exact result clocks and canonical replay parity. Native pixels, delayed residue ticks, Divine recipient tiers and human approval are separate."}
    FileAccess.open("res://.runtime/native-finite-observed-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("FINITE_OBSERVED_INPUTS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func finite_cue(entry:Resource,name:String)->Resource:
    var wanted:String=CONTACT if name=="vitriolic-sphere" else PROCLAMATION
    var found:Array=entry.effects.filter(func(cue):return cue.clip==wanted)
    check(found.size()==1,name+" retains exactly one actual finite source preset")
    return found[0] if found.size()==1 else null
func read_finite_seat(name:String,seat:String,entry:Resource,cue:Resource,built:Dictionary,paths:Dictionary)->void:
    var label:String=name+"/"+seat
    var directory:String=FINITE_ROOT.path_join(name).path_join(seat)
    var journal:RefCounted=Journal.new();check(journal.open(directory,true,false).ok,label+" opens complete unchanged journal")
    var cache:Dictionary=source_cache(built,paths)
    var timeline:RefCounted=Timeline.new();var duration:float=0.0
    var casts:int=0;var projected:int=0;var all_components:Array=[];var residue_members:Dictionary={}
    var files:PackedStringArray=DirAccess.get_files_at(directory);files.sort()
    check(files.size()==9,label+" preserves all nine original packets, not just a final snapshot")
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
        var actual_results:Dictionary={}
        for native in folded.normalized.lineages:
            var lineage:Dictionary=Occurrences.group(native)
            var graph:Dictionary=graph_for(lineage.events)
            for node in lineage.events:
                if node.get("fact")==null:continue
                if node.fact.kind=="actor_change":
                    for actor in node.fact.actors:
                        for row in actor.rows:
                            if row.field=="condition" and row.get("member")!=null and row.member.behavior_id=="condition.spell.vitriolic_sphere.residue":residue_members[actor.actor_uuid]=row.condition_uuid
                if node.fact.get("behavior_id")!=FINITE_CASES[name]:continue
                casts+=1
                var observations:Array=Results.observed(node,cue.constructor_input,graph)
                check(observations.size()==(4 if name=="vitriolic-sphere" else 1),label+" only exact actual finite outcomes are projected")
                var recipients:Array=[]
                for projection in observations:
                    projected+=1;recipients.append(projection.target_uuid)
                    actual_results[str(projection.node.id)]=projection
                    check(projection.evidence.source_occurrence==str(node.id) and projection.evidence.source_lineage==str(node.lineage_id) \
                        and projection.evidence.result_occurrence==str(projection.node.id) and projection.evidence.result_lineage==str(projection.node.lineage_id),label+" exact cast and own result native identities/ancestry survive")
                    if name=="vitriolic-sphere":check_contact(node,projection,label)
                    else:check_proclamation(node,projection,label)
                    check_source(name,cue,projection,label)
                    evidence.append({"case":name,"seat":seat,"sequence":sequence,"cast_occurrence":node.id,"result_occurrence":projection.node.id,
                        "cast_lineage":node.lineage_id,"result_lineage":projection.node.lineage_id,"recipient_uuid":projection.target_uuid,"projection":projection.values})
                if name=="vitriolic-sphere":
                    var unique:Dictionary={}
                    for recipient in recipients:unique[recipient]=true
                    check(recipients.size()==4 and unique.size()==4,label+" four independent actual recipients, including the caster hit by its area")
                negative_controls(name,node,lineage.events,cue.constructor_input,graph,label)
        var compiled:Dictionary=Compiler.compile_recorded(before,folded.normalized,cache,journal.state,folded.transitions)
        check(compiled.ok,label+" ordinary compiler "+str(sequence));if not compiled.ok:return
        timeline.accept({"kind":"operation","groups":compiled.value.groups})
        for group in compiled.value.groups:
            duration+=float(group.duration_ms)
            for component in group.components:
                var clip_id:String=str(component.get("native_clip",{}).get("id",""))
                if clip_id==DUPLICATE_CONTACT:check(component.status=="missing",label+" fixed review target2 is never admitted as an extra actual contact")
                if clip_id!=cue.clip:continue
                all_components.append(component)
                check(component.status=="available" and not component.get("persistent_owner",false),label+" finite actual event is available without a held owner")
                var projection:Dictionary=actual_results.get(str(component.source_event_uuid),{})
                check(not projection.is_empty(),label+" component belongs to this exact original result")
                if projection.is_empty():continue
                check(component.actor_uuid==projection.values.get("original_caster_uuid",projection.values.get("owner",{}).get("source_entity_uuid","")) \
                    and component.target_uuid==projection.target_uuid,label+" compiler preserves actual source/recipient roles")
                var supplied:Dictionary=component.native_inputs
                check(supplied.get("native_state",{})==projection.values.state if name=="vitriolic-sphere" else supplied.get("observation",{})==projection.values.observation,label+" setter receives the exact constructor's real finite packet")
                var commits:Array=group.commits.filter(func(commit):return str(commit.get("event_uuid",""))==str(component.source_event_uuid))
                if name=="vitriolic-sphere":
                    var tracks:Array=group.actor_tracks.filter(func(track):return str(track.source_event_uuid)==str(component.source_event_uuid) and track.activity=="hit")
                    check(tracks.size()==1 and is_equal_approx(component.start_ms,tracks[0].start_ms),label+" contact starts at its own actual damage response clock")
                    check(commits.size()==1 and component.start_ms<=commits[0].at_ms,label+" actual result retains its independent authored HP commit after contact")
                else:
                    var tracks:Array=group.actor_tracks.filter(func(track):return str(track.source_event_uuid)==str(component.source_event_uuid) and track.activity=="cast")
                    check(tracks.size()==1 and is_equal_approx(component.start_ms,tracks[0].contact_ms),label+" proclamation preserves the real casting body's authored release clock")
                check(is_equal_approx(component.duration_ms,cue.source_end*1000.0),label+" preserved original finite source duration")
        check(var_to_bytes(folded.normalized)==immutable and FileAccess.get_file_as_bytes(directory.path_join(file))==raw,label+" compilation leaves original native packets untouched")
    check(casts==1 and projected==(4 if name=="vitriolic-sphere" else 1) and all_components.size()==projected,label+" one actual cast yields exactly the real finite source count")
    if name=="vitriolic-sphere":
        check(residue_members.size()==4,label+" actual held residues keep four independent real condition UUIDs")
        check(all_components.all(func(component):return not component.get("persistent_owner",false) and component.native_inputs.native_state.get("condition_uuid","").is_empty()),label+" initial contact never borrows a held residue owner")
        evidence.append({"case":name,"seat":seat,"independent_residue_members":residue_members})
    timeline.advance(duration+1000.0)
    check(not timeline.busy() and Compare.difference(timeline.state,journal.state).is_empty(),label+" unchanged independent reducer drains without playback holds")
    for actor in residue_members:
        var uuid:String=residue_members[actor]
        check(timeline.condition_owners.has(uuid) and timeline.condition_owners[uuid].actor_uuid==actor,label+" ordinary lifecycle preserves this exact independent real residue UUID/actor")
func check_contact(cast:Dictionary,projection:Dictionary,label:String)->void:
    var actual:Dictionary=projection.node.fact;var values:Dictionary=projection.values;var state:Dictionary=values.state
    check(actual.kind=="damage" and actual.stage=="applied" and actual.damage_type=="Acid" and actual.applied_damage==29,label+" original initial contact is exactly 29 applied Acid")
    check(values.source_owner_uuid==str(cast.id) and values.original_caster_uuid==cast.fact.source_entity_uuid \
        and values.recipient_uuid==actual.target_entity_uuid and projection.target_uuid==actual.target_entity_uuid,label+" finite constructor is owned by actual cast and actual applied recipient")
    check(state.source_owner_uuid==values.source_owner_uuid and state.original_caster_uuid==values.original_caster_uuid \
        and state.recipient_uuid==values.recipient_uuid and state.event_uuid==str(projection.node.id) and state.damage_applied,label+" constructor state retains exact result occurrence and positive damage")
    check(values.get("condition_uuid","").is_empty() and values.get("condition_id","").is_empty() \
        and state.get("condition_uuid","").is_empty() and state.get("condition_id","").is_empty(),label+" neither review nor manufactured condition identity is retained")
    if state.has("saved"):check(state.saved==false,label+" optional save is the actual disclosed failed save, never a new roll")
func check_proclamation(cast:Dictionary,projection:Dictionary,label:String)->void:
    var owner:Dictionary=projection.values.owner;var observation:Dictionary=projection.values.observation
    for field in ["event_uuid","cast_uuid"]:check(owner[field]==str(cast.id) and observation[field]==owner[field],label+" proclamation "+field+" is the real completed cast occurrence")
    check(owner.source_entity_uuid==cast.fact.source_entity_uuid and owner.target_entity_uuid==cast.fact.target_entity_uuid \
        and projection.target_uuid==cast.fact.target_entity_uuid,label+" proclamation preserves disclosed caster and real target even though artwork anchors at caster")
    check(observation.source_entity_uuid==owner.source_entity_uuid and observation.target_entity_uuid==owner.target_entity_uuid \
        and observation.admitted and not observation.canceled and observation.phase=="completion",label+" only actual completed proclamation is admitted")
    check(not observation.has("outcome") and not observation.has("affected") and observation.get("condition",{}).is_empty() \
        and owner.get("condition_uuid","").is_empty() and owner.get("condition_id","").is_empty(),label+" generic Divine Word membership never invents a recipient HP tier or condition outcome")
func source_input(clip:Dictionary,path:Array)->Dictionary:
    var components:Array=clip.components;var input:Dictionary={}
    for part in path:
        var found:Array=components.filter(func(component):return component.id==part)
        if found.size()!=1:return {}
        input=found[0].input;components=input.get("components",[])
    return input
func check_source(name:String,cue:Resource,projection:Dictionary,label:String)->void:
    var phase:Resource=load(Effects.choice(Effects.clip(cue.clip)).approaches[0].source_phase)
    var immutable:PackedByteArray=var_to_bytes(phase.to_clip())
    var private:Dictionary=Adapter.clip_with_inputs(phase,[{"component_path":cue.constructor_input.component_path,"input_field":"","values":projection.values}])
    var input:Dictionary=source_input(private,cue.constructor_input.component_path)
    check(not input.is_empty(),label+" real typed component path resolves inside the sealed source")
    if input.is_empty():return
    var script:String="res://assets/vfx/sources/caacf9ad16e726919e2f/recipient_corrosion.gd" if name=="vitriolic-sphere" else "res://assets/vfx/sources/edb4416ff06538073fee/divine_word_source_v196.gd"
    var program:Node3D=load(script).new()
    if name=="vitriolic-sphere":
        program.specification=input
        check(program.set_native_state(input.state),label+" actual initial packet satisfies sealed native admission")
        var bad:Dictionary=input.state.duplicate(true);bad.damage_applied=false
        check(not program.set_native_state(bad),label+" sealed source rejects non-applied damage")
        bad=input.state.duplicate(true);bad.recipient_uuid="different-recipient"
        check(not program.set_native_state(bad),label+" sealed source rejects another recipient")
        bad=input.state.duplicate(true);bad.source_owner_uuid="different-cast"
        check(not program.set_native_state(bad),label+" sealed source rejects another cast ancestry")
    else:
        program.settings=input;program.observation=input.observation
        check(program.admitted(),label+" actual completion satisfies sealed proclamation admission")
        var bad:Dictionary=input.observation.duplicate(true);bad.phase="request";program.observation=bad
        check(not program.admitted(),label+" sealed source rejects a requested but uncompleted proclamation")
        bad=input.observation.duplicate(true);bad.canceled=true;program.observation=bad
        check(not program.admitted(),label+" sealed source rejects canceled proclamation")
        bad=input.observation.duplicate(true);bad.target_entity_uuid="other-recipient";program.observation=bad
        check(not program.admitted(),label+" sealed source rejects another actual target")
    program.free()
    check(var_to_bytes(phase.to_clip())==immutable,label+" private construction preserves shared sealed art/material/preset")
func negative_controls(name:String,cast:Dictionary,events:Array,descriptor:Dictionary,graph:Dictionary,label:String)->void:
    var canceled:Dictionary=cast.duplicate(true);canceled.canceled=true
    check(Results.observed(canceled,descriptor,graph).is_empty(),label+" canceled source cannot admit finite output")
    var requested:Dictionary=cast.duplicate(true);requested.phase="request"
    check(Results.observed(requested,descriptor,graph).is_empty(),label+" requested source cannot stand in for completion")
    var foreign:Dictionary=cast.duplicate(true);foreign.fact.source_entity_uuid="different-caster"
    if name=="vitriolic-sphere":
        check(Results.observed(foreign,descriptor,graph).is_empty(),label+" foreign caster cannot claim actual applied descendants")
        var detached:Dictionary=graph.duplicate();detached.observed_results={}
        check(Results.observed(cast,descriptor,detached).is_empty(),label+" no actual descendant ancestry means no finite contact")
        for control in ["zero","foreign","undisclosed","request","unapplied"]:
            var changed:Array=events.duplicate(true)
            var actual:Array=changed.filter(func(node):return node.get("fact")!=null and node.fact.kind=="damage" and node.fact.get("stage")=="applied")
            check(actual.size()==4,label+" negative control starts from the four original applied facts")
            if actual.size()!=4:continue
            match control:
                "zero":actual[0].fact.applied_damage=0
                "foreign":actual[0].fact.source_entity_uuid="different-caster"
                "undisclosed":actual[0].fact.target_entity_uuid=null
                "request":actual[0].phase="request"
                "unapplied":actual[0].fact.stage="requested"
            var changed_graph:Dictionary=graph_for(changed)
            check(Results.observed(cast,descriptor,changed_graph).size()==3,label+" private "+control+" control cannot admit that recipient; other real contacts survive")
    else:
        var undisclosed:Dictionary=cast.duplicate(true);undisclosed.fact.target_entity_uuid=null
        check(Results.observed(undisclosed,descriptor,graph).is_empty(),label+" undisclosed target is not replaced by caster or guessed recipient")
