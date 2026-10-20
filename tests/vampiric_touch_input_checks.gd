extends SceneTree
## Original two-seat first cast plus private projection-boundary controls.
## These controls are not fabricated wire events or additional game scenarios.
const Results=preload("res://presentation/application_results.gd")
const Occurrences=preload("res://presentation/occurrences.gd")
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Build=preload("res://tools/presentation_build/abilities.gd")
const Records=preload("res://tools/presentation_build/ability_records.gd")
const Sources=preload("res://presentation/native_presentation_sources.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Adapter=preload("res://presentation/native_constructed_occurrence.gd")
const ID="spell.vampiric_touch"
const PATH="res://authoring/abilities/spells/spell.vampiric_touch.tres"
const IMPACT="bg3-36/vampiric-touch/vampiric_touch_native/impact"
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("VAMPIRIC_INPUT_FAIL ",label)
func graph_for(events:Array)->Dictionary:
    var graph:Dictionary={"nodes":{},"condition_cues":{}}
    for node in events:graph.nodes[node.lineage_id]=node
    graph.observed_results=Results.observed_index(events,graph)
    return graph
func cache_for(record:Resource)->Dictionary:
    var cache:Dictionary={}
    var admitted:Dictionary=Sources.admission(cache)
    var index:Resource=admitted.index.duplicate()
    index.spells=admitted.index.spells.duplicate();index.spells[ID]=PATH
    var loaded:Dictionary=admitted.loaded.duplicate();loaded[ID]=record
    cache[Sources.CACHE_KEY]=Sources.make_admission(index,loaded)
    return cache
func controls(events:Array,owner:Dictionary,result:Dictionary,descriptor:Dictionary)->void:
    for field in ["canceled_cast","miss","repeat","generic_damage","canceled_damage","zero","foreign_source","foreign_target","independent_lineage"]:
        var copied:Array=events.duplicate(true)
        var source:Dictionary=copied.filter(func(row):return row.id==owner.id)[0]
        var damage:Dictionary=copied.filter(func(row):return row.id==result.id)[0]
        match field:
            "canceled_cast":source.canceled=true
            "miss":source.fact.attack_outcome="Miss"
            "repeat":source.fact.behavior_id="action.spell.vampiric_touch.strike"
            "generic_damage":source.fact.kind="action"
            "canceled_damage":damage.canceled=true
            "zero":damage.fact.applied_damage=0
            "foreign_source":damage.fact.source_entity_uuid=null
            "foreign_target":damage.fact.target_entity_uuid=source.fact.source_entity_uuid
            "independent_lineage":damage.parent_lineage=null
        check(not Results.spell_strike(source,descriptor,graph_for(copied)).ready,"Private "+field+" cannot admit this first-cast impact")
    var critical:Dictionary=owner.duplicate(true);critical.fact.attack_outcome="Crit"
    var projected:Dictionary=Results.spell_strike(critical,descriptor,graph_for(events))
    check(projected.ready and projected.inputs.strike_input.outcome=="critical","Actual Crit enum maps to the source's critical treatment without changing the result")
func run()->void:
    var entry:Resource=load(PATH)
    var built:Dictionary=Build.documents({"spells":{ID:entry},"contexts":{"hit_flash":load("res://authoring/abilities/contexts/hit_flash.tres")}},{"spells":{ID:PATH}})
    var record:Resource=built.native.records[ID]
    var descriptor:Dictionary=entry.effects[1].constructor_input
    check(entry.effects[1].clip==IMPACT and entry.effects[1].scope=="recipient" and entry.effects[1].role=="impact","Only the native single-recipient first impact owns this constructor")
    for i in [0,2,3,4]:check(not entry.effects[i].unbound_constructor_inputs.is_empty(),"Unimplemented windup/healing/held/removal phase stays explicit: "+str(i))
    var cue:Dictionary=Records.cue_from_effect(entry.effects[1],1)
    check(cue.input_policies.size()==4 and cue.input_policies.keys().all(func(name):return name in ["owner_input","healing_input","condition_input","tick_input"]),"Only four exact impact-branch inputs are inapplicable")
    var clip:Dictionary=Effects.clip(IMPACT)
    var phase:Resource=load(Effects.choice(clip).approaches[0].source_phase)
    var sealed:PackedByteArray=var_to_bytes(phase.to_clip())
    for seat in ["amber","blue"]:
        var journal:RefCounted=Journal.new()
        var directory:String=Fixtures.journal("vampiric-touch",seat)
        check(journal.open(directory,true,false).ok,seat+" original journal opens")
        var files:PackedStringArray=DirAccess.get_files_at(directory);files.sort()
        var cache:Dictionary=cache_for(record)
        var projected_count:int=0;var components:Array=[]
        for file in files:
            if file.get_basename().length()!=16 or not file.get_basename().is_valid_int():continue
            var sequence:int=int(file.get_basename())
            var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(file))
            var decoded:Dictionary=journal.decode_record(sequence,raw)
            check(decoded.ok,seat+" actual decode "+str(sequence))
            if not decoded.ok:continue
            var before:Dictionary=journal.state
            var folded:Dictionary=journal._consume_admitted(decoded.value,raw,true)
            check(folded.ok,seat+" actual fold "+str(sequence))
            if not folded.ok or sequence==0:continue
            for native in folded.normalized.lineages:
                var lineage:Dictionary=Occurrences.group(native)
                var graph:Dictionary=graph_for(lineage.events)
                var original:PackedByteArray=var_to_bytes(lineage.events)
                for node in lineage.events:
                    if node.get("fact")==null or node.fact.get("behavior_id")!=ID:continue
                    var projected:Dictionary=Results.spell_strike(node,descriptor,graph)
                    check(projected.ready,seat+" real first cast projects: "+str(projected.get("reason")))
                    if not projected.ready:continue
                    projected_count+=1
                    var damage:Dictionary=lineage.events.filter(func(row):return str(row.id)==projected.evidence.result_occurrence)[0]
                    check(projected.values.source_actor_uuid==node.fact.source_entity_uuid and projected.values.recipient_uuid==node.fact.target_entity_uuid,"Actual source and recipient survive constructor projection")
                    check(projected.inputs.strike_input.damage_fact_uuid==str(damage.id) and projected.inputs.strike_input.attack_uuid==str(node.id),"Opaque source keys are exact local native occurrences")
                    check(projected.evidence.source_lineage==node.lineage_id and projected.evidence.result_lineage==damage.lineage_id and projected.evidence.applied_damage==damage.fact.applied_damage,"Exact native lineage and positive damage evidence are retained")
                    check(not projected.evidence.resolution.has("application_id"),"This single-target native result does not acquire a made-up multi-application UUID")
                    check(projected.values.owner.is_empty() and projected.values.condition.is_empty() and projected.values.tick.is_empty() and projected.values.healing.is_empty(),"Unused review success packets are cleared before construction")
                    var private_clip:Dictionary=Adapter.clip_with_inputs(phase,[{"component_path":descriptor.component_path,"input_field":"","values":projected.values}])
                    var input:Dictionary=private_clip.components[0].input
                    check(input.material==phase.to_clip().components[0].input.material and input.phase=="impact","Sealed source material and phase stay unchanged")
                    var source:Node3D=load(private_clip.components[0].script).new()
                    source.configure(input)
                    check(source.payload_admitted() and not source.owner_admitted() and not source.healing_admitted(),"Actual source admits first impact while unrelated owner/healing branches remain unavailable")
                    source.free()
                    controls(lineage.events,node,damage,descriptor)
                    evidence.append({"seat":seat,"projection":projected.evidence})
                check(var_to_bytes(lineage.events)==original,"Projection and private controls leave original rows unchanged")
            var compiled:Dictionary=Compiler.compile_recorded(before,folded.normalized,cache,journal.state,folded.transitions)
            check(compiled.ok,seat+" production compile "+str(sequence))
            if compiled.ok:
                for group in compiled.value.groups:
                    components.append_array(group.components.filter(func(row):return row.get("native_cue",{}).get("staged_clip")==IMPACT or row.get("native_clip",{}).get("id")==IMPACT))
        check(projected_count==1 and components.size()==1,seat+" one real first cast compiles exactly one impact")
        for component in components:
            check(component.status=="available" and component.native_constructor_inputs.size()==1,"Production compiler retains the ready constructor projection")
            check(component.native_inputs.strike_input==component.native_constructor_inputs[0].values.strike,"Production setter receives the same exact strike as construction")
            check(component.native_cue.input_policies==cue.input_policies,"Exact inapplicability remains visible separately from supplied strike")
    check(var_to_bytes(phase.to_clip())==sealed,"Neither recipient mutates shared Factory source/art settings")
    print("VAMPIRIC_TOUCH_INPUTS ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Real first-cast input/constructor path only; held/repeat/healing, pixels and visual acceptance remain unqualified."}))
    quit(0 if failures.is_empty() else 1)
