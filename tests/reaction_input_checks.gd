extends SceneTree
## Original independent schema16 seats qualify observed reaction semantics.
## No source is constructed or drawn: the absent incoming presentation path
## is an explicit gap, not a substitute Fireball or a GPU qualification.
const Reactions=preload("res://presentation/reaction_inputs.gd")
const Occurrences=preload("res://presentation/occurrences.gd")
const Trace=preload("res://presentation/event_trace.gd")
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Timeline=preload("res://presentation/timeline.gd")
const Authoring=preload("res://presentation/authoring.gd")
const Build=preload("res://tools/presentation_build/abilities.gd")
const Constructed=preload("res://presentation/native_constructed_occurrence.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Actions=preload("res://presentation/native_action_authoring.gd")
const Spells=preload("res://presentation/native_spell_authoring.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const PATH="res://authoring/abilities/actions/reaction.spell.counterspell.tres"
const ID="reaction.spell.counterspell"
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("REACTION_INPUT_FAIL "+label)

func run()->void:
    var directory:String="res://tests/fixtures/schema16/scenarios/counterspell"
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--recording="):directory=argument.trim_prefix("--recording=")
    var entry:Resource=load(PATH)
    check(entry!=null and entry.effects.size()==2,"Actual reaction source declares both exact Factory outcomes")
    if entry==null:finish();return
    check(entry.kind=="reaction" and entry.id==ID and entry.status=="partial","A typed reaction remains a reaction with explicit unqualified presentation")
    var spell:Resource=load("res://authoring/abilities/spells/spell.counterspell.tres")
    check(spell.effects[0].unbound_constructor_inputs==PackedStringArray(["reaction_occurrence_not_a_spell_declaration"]) \
        and spell.variants[0].effects[0].unbound_constructor_inputs==spell.effects[0].unbound_constructor_inputs,"Spell-owned review references cannot construct an observed native reaction")
    var spell_docs:Dictionary=Build.documents({"spells":{spell.id:spell}},{"spells":{spell.id:"res://authoring/abilities/spells/spell.counterspell.tres"}})
    check(Spells.effect_clips(spell_docs.native.records[spell.id].selection).is_empty(),"Alternate spell prewarming cannot construct a Counterspell review fixture")
    var built:Dictionary=Build.documents({"actions":{ID:entry}},{"actions":{ID:PATH}})
    var binding:Dictionary=built.docs["catalog/body_action_bindings.json"][ID]
    check(binding.effect_cues.map(func(cue):return cue.constructor_input.succeeded)==[true,false],"Outcome selection is authored as explicit observed booleans")
    check(Actions.effect_clips(ID,{"catalog/body_action_bindings.json":{ID:binding}}).is_empty(),"Unqualified incoming paths cannot warm successful Factory review fixtures")
    var seats:int=0;var reactions:int=0
    for seat in ["amber","blue"]:
        var path:String=directory.path_join(seat)
        if DirAccess.dir_exists_absolute(path.path_join("journal")):path=path.path_join("journal")
        check(DirAccess.dir_exists_absolute(path),"Original independent "+seat+" journal exists")
        if not DirAccess.dir_exists_absolute(path):continue
        seats+=1
        reactions+=read_seat(path,seat,entry,built,binding)
    check(seats==2 and reactions==2,"Both original seats independently disclose and reduce the actual successful reaction")
    finish()

func read_seat(directory:String,seat:String,entry:Resource,built:Dictionary,binding:Dictionary)->int:
    var journal:RefCounted=Journal.new()
    var opened:Dictionary=journal.open(directory,true,false)
    check(opened.ok,seat+" opens under the current schema")
    if not opened.ok:return 0
    var cache:Dictionary={}
    for field in ["catalog/body_action_bindings.json","catalog/body_action_recipes.json"]:
        var original:Dictionary=Authoring.load_data(field,cache)
        var updated:Dictionary=original.duplicate()
        updated[ID]=built.docs[field][ID]
        cache[field]=updated
    var timeline:RefCounted=Timeline.new()
    var files:PackedStringArray=DirAccess.get_files_at(directory);files.sort()
    var count:int=0;var duration:float=0.0
    for filename in files:
        if not filename.ends_with(".json") or filename.get_basename().length()!=16 or not filename.get_basename().is_valid_int():continue
        var sequence:int=int(filename.get_basename())
        var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(filename))
        var decoded:Dictionary=journal.decode_record(sequence,raw)
        check(decoded.ok,seat+" decode "+str(sequence))
        if not decoded.ok:return count
        var before:Dictionary=journal.state
        var folded:Dictionary=journal._consume_admitted(decoded.value,raw,true)
        check(folded.ok,seat+" reduce "+str(sequence))
        if not folded.ok:return count
        if sequence==0:
            timeline.accept({"kind":"initialization","state":journal.state.duplicate(true),"sequence":0});continue
        var immutable:PackedByteArray=var_to_bytes(folded.normalized)
        var compiled:Dictionary=Compiler.compile_recorded(before,folded.normalized,cache,journal.state,folded.transitions)
        check(compiled.ok,seat+" compile "+str(sequence))
        if not compiled.ok:return count
        timeline.accept({"kind":"operation","groups":compiled.value.groups})
        for group in compiled.value.groups:duration+=float(group.duration_ms)
        for source in folded.normalized.lineages:
            var lineage:Dictionary=Occurrences.group(source)
            var graph={"nodes":{},"version_index":Trace._version_index(lineage.version_rows)}
            for node in lineage.events:graph.nodes[node.lineage_id]=node
            for node in lineage.events:
                if node.get("fact")==null or node.fact.get("reaction")==null:continue
                count+=1
                factual(node,graph,seat)
                var rows:Array=[]
                for group in compiled.value.groups:
                    for component in group.components:
                        if component.get("source_event_uuid")==node.id and component.get("native_cue",{}).get("constructor_input",{}).get("kind")=="reaction_observation":rows.append(component)
                check(rows.size()==1,seat+" compiles only the actual outcome, not both success/failure tracks")
                if rows.size()!=1:continue
                var row:Dictionary=rows[0]
                check(row.ability_kind=="action" and row.ability_id==node.fact.behavior_id and not row.has("spell_id"),seat+" actual ActionFact is not a pretend spell declaration")
                check(row.native_clip.id==entry.effects[0].clip and row.native_reaction_observation.succeeded==node.fact.reaction.succeeded,seat+" actual reaction outcome selects the exact supplied success art")
                check(row.status=="missing" and row.native_input_gaps==["reaction_incoming_presentation_path_unavailable"] and row.native_inputs.is_empty(),seat+" semantic readiness cannot falsely qualify absent renderer geometry")
                check(row.actor_uuid==node.fact.source_entity_uuid and row.target_uuid==node.fact.target_entity_uuid,seat+" source/endpoint ownership comes only from this seat's action")
                constructor(row,seat)
        check(var_to_bytes(folded.normalized)==immutable,seat+" compiler and projection preserve the unchanged original packet")
    timeline.advance(duration+1000.0)
    check(not timeline.busy() and Compare.difference(timeline.state,journal.state).is_empty(),seat+" missing art neither holds nor reorders the canonical fold")
    return count

func factual(node:Dictionary,graph:Dictionary,seat:String)->void:
    var immutable:PackedByteArray=var_to_bytes(graph)
    var actual:Dictionary=Reactions.observe(node,graph)
    check(actual.ready,seat+" ActionReaction has native evidence")
    if not actual.ready:return
    var observed:Dictionary=actual.observation
    var evidence:Dictionary=actual.evidence
    check(observed.reaction_uuid==str(node.id) and observed.triggered_event_uuid==str(node.parent_event) \
        and observed.triggered_lineage_uuid==str(node.fact.reaction.triggered_lineage),seat+" Factory aliases retain actual reaction, earlier triggering version and lineage separately")
    check(observed.triggered_event_uuid!=actual.triggered.id and evidence.triggered_terminal_occurrence==actual.triggered.id,seat+" canceled terminal occurrence never replaces the version which triggered the reaction")
    check(observed.succeeded==node.fact.reaction.succeeded and evidence.automatic==node.fact.reaction.automatic,seat+" success and automatic/check mode are copied from ActionReaction")
    check(evidence.effective_handlers.size()==1 and evidence.effective_handlers[0].source_entity_uuid==node.fact.source_entity_uuid,seat+" exact native cancellation attribution corroborates this reaction owner")
    var matching={"trigger_kind":"spell","succeeded":true}
    var projected:Dictionary=Reactions.project(node,matching,graph)
    check(projected.ready and projected.applies and projected.evidence.incoming_behavior_id==actual.triggered.fact.behavior_id,seat+" native triggered spell supplies its own actual identity")
    check(not Reactions.project(node,{"trigger_kind":"spell","succeeded":false},graph).applies,seat+" other authored outcome does not add an irrelevant track")
    var missing:Dictionary=node.duplicate(true);missing.fact.erase("reaction")
    check(Reactions.observe(missing,graph).reason=="reaction_completion_not_observed",seat+" a canceled spell alone never means Counterspell occurred")
    missing=node.duplicate(true);missing.canceled=true
    check(not Reactions.observe(missing,graph).ready,seat+" canceled reaction cannot produce a committed outcome")
    missing=node.duplicate(true);missing.fact.reaction.triggered_lineage=null
    check(Reactions.observe(missing,graph).reason=="reaction_triggered_lineage_not_disclosed",seat+" undisclosed trigger lineage remains missing")
    var private_graph:Dictionary=graph.duplicate(true);private_graph.nodes.erase(str(node.fact.reaction.triggered_lineage))
    check(Reactions.observe(node,private_graph).reason=="reaction_triggered_fact_not_disclosed",seat+" no other seat's disclosed cast can replace an absent own-view trigger")
    private_graph=graph.duplicate(true);private_graph.version_index.lineages[str(node.fact.reaction.triggered_lineage)]=[]
    check(Reactions.observe(node,private_graph).reason=="reaction_triggering_occurrence_not_in_triggered_lineage",seat+" native parent must be present in this lineage's actual version rows")
    missing=node.duplicate(true);missing.fact.target_entity_uuid=node.fact.source_entity_uuid
    check(Reactions.project(missing,matching,graph).reason=="reaction_incoming_caster_endpoint_not_bound",seat+" incoming-caster endpoint cannot borrow the reaction caster")
    # Mutation checks are negative boundaries, not additional recorded cases.
    # In particular there is no claimed recorded failed Counterspell here.
    missing=node.duplicate(true);missing.fact.reaction.succeeded=false
    check(not Reactions.observe(missing,graph).observation.succeeded,seat+" cancellation metadata cannot override an explicitly different observed outcome")
    missing=node.duplicate(true);missing.fact.behavior_id="reaction.test.name_independence"
    check(Reactions.observe(missing,graph).observation==observed,seat+" generic producer consumes native reaction fields rather than a behavior-name switch")
    check(var_to_bytes(graph)==immutable,seat+" observation reads native facts, versions and attributions without mutation")

func constructor(row:Dictionary,seat:String)->void:
    var phase:Resource=load(Effects.choice(row.native_clip).approaches[0].source_phase)
    var original:Dictionary=phase.to_clip()
    var private_clip:Dictionary=Constructed.clip_with_inputs(phase,row.native_constructor_inputs)
    var observation:Dictionary=private_clip.components[0].input.observation
    check(observation.reaction_uuid==row.source_event_uuid and observation.triggered_event_uuid==row.native_input_evidence.triggering_occurrence \
        and observation.triggered_lineage_uuid==row.native_input_evidence.triggered_lineage,seat+" exact public constructor member accepts seat-local native aliases before make")
    check(phase.to_clip()==original,seat+" shared delivered Factory resource is immutable")
    check(private_clip.components[0].input.incoming==original.components[0].input.incoming,seat+" unresolved Factory Fireball donor is neither silently rewritten nor instantiated")

func finish()->void:
    print(JSON.stringify({"checks":checks,"failures":failures,"scope":"Independent original schema16 reactions, compiler ownership/order and private constructor aliases; incoming renderer path/source clock and native drawing remain gaps"}))
    quit(0 if failures.is_empty() else 1)
