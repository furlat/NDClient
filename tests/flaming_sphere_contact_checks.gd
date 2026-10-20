extends "res://tests/support_spell_event_checks.gd"
## Actual accepted Ram -> own save/result -> one finite source. The damage
## source remains the original caster; the sphere is its optical/action source.
const Recording=preload("res://studio/recording.gd")
const ROOT_PATH="res://tests/fixtures/schema16/scenarios/flaming-sphere-lifecycle"
const ACTION="action.spell.flaming_sphere.ram"
const ACTION_PATH="res://authoring/abilities/actions/action.spell.flaming_sphere.ram.tres"
const CONTACT="bg3-36/flaming-sphere/native_sphere_ram"
const SPHERE="9a7daae4-573e-4248-82ca-19eb9430cf2c"
const OWNER="3e1d4d91-5553-4266-951d-0754ac3953c5"
const CASTER="ec1f2312-c161-48fd-b711-2d828582420e"
const TARGET="361a033a-73eb-4f4c-96bd-9380d7092591"
const SAVE="action.spell.flaming_sphere.ram.saving_throw"
func run()->void:
    var entry:Resource=load(ACTION_PATH)
    check(entry.effects.size()==1 and not entry.body.enabled,"The accepted action owns one finite source and no invented sphere casting body")
    if entry.effects.size()!=1:finish_contact();return
    var cue:Resource=entry.effects[0]
    check(cue.clip==CONTACT and cue.scope=="source" and cue.at=="event.start" and is_zero_approx(cue.delay) \
        and cue.source_end==.45 and cue.light_multiplier==0.0,"One original finite contact retains its duration and actual event clock, without a light")
    check(cue.extra.live_endpoints==[{"actor":"target","socket":"body_center"}] \
        and cue.extra.entity_geometry.actor=="target","No fixed review point replaces the actual recipient surface")
    var parent:Resource=load("res://authoring/abilities/spells/spell.flaming_sphere.tres")
    check(Array(parent.excluded_cues)==[2,3,4,5] and Array(parent.owner_cues)==[1],"Parent cast still excludes review Ram/end-turn/trail/light and preserves its actual body handover")
    var built:Dictionary=Build.documents({"actions":{ACTION:entry}},{"actions":{ACTION:ACTION_PATH}})
    var base:Dictionary={}
    var bindings:Dictionary=Compiler.Authoring.load_data("catalog/body_action_bindings.json",base).duplicate()
    bindings[ACTION]=built.docs["catalog/body_action_bindings.json"][ACTION]
    base["catalog/body_action_bindings.json"]=bindings
    for seat in ["amber","blue"]:actual_contact(seat,cue,base)
    finish_contact()
func finish_contact()->void:
    var result:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Both independent original accepted Ram actions, exact source condition and native save/applied-result ancestry, real source admission, finite compiler clocks and canonical seek/loop. Native pixels, saved-half/end-turn contact, trails and visual approval are separate."}
    FileAccess.open("res://.runtime/flaming-sphere-contact-checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("FLAMING_SPHERE_CONTACT ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
func contact_graph(events:Array,actors:Dictionary)->Dictionary:
    var graph:Dictionary=graph_for(events)
    graph.actor_inputs={}
    for node in events:graph.actor_inputs[node.id]=actors
    graph.application_results=Results.index(events,graph.nodes)
    return graph
func actual_contact(seat:String,cue:Resource,cache:Dictionary)->void:
    var directory:String=ROOT_PATH.path_join(seat)
    var journal:RefCounted=Journal.new()
    check(journal.open(directory,true,false).ok,seat+": unchanged original journal opens")
    var observations:Array=[]
    var files:PackedStringArray=DirAccess.get_files_at(directory);files.sort()
    for file in files:
        if file.get_basename().length()!=16 or not file.get_basename().is_valid_int():continue
        var sequence:int=int(file.get_basename());var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(file))
        var decoded:Dictionary=journal.decode_record(sequence,raw)
        check(decoded.ok,seat+": exact packet decodes "+str(sequence));if not decoded.ok:return
        var actors:Dictionary=journal.state.get("actors",{})
        var folded:Dictionary=journal._consume_admitted(decoded.value,raw,true)
        check(folded.ok,seat+": exact packet folds "+str(sequence));if not folded.ok:return
        if sequence!=7:continue
        var immutable:PackedByteArray=var_to_bytes(folded.normalized)
        for native in folded.normalized.lineages:
            var lineage:Dictionary=Occurrences.group(native)
            var graph:Dictionary=contact_graph(lineage.events,actors)
            var casts:Array=lineage.events.filter(func(node):return node.get("fact")!=null and node.fact.get("behavior_id")==ACTION)
            check(casts.size()==1,seat+": one actual accepted Ram is disclosed")
            if casts.size()!=1:continue
            var cast:Dictionary=casts[0]
            observations=Results.observed(cast,cue.constructor_input,graph)
            check(observations.size()==1,seat+": exact descendant positive Fire admits one contact despite its different original-caster damage source")
            if observations.size()!=1:continue
            var observed:Dictionary=observations[0]
            check(str(cast.id)=="165" and str(cast.lineage_id)=="141" and observed.node.id=="163" \
                and observed.node.fact.applied_damage==5 and observed.node.fact.source_entity_uuid==CASTER \
                and observed.target_uuid==TARGET and cast.fact.source_entity_uuid==SPHERE,seat+": independently recorded action/result/source identities and five Fire are unchanged")
            var event:Dictionary=observed.inputs.contact_event
            check(event=={"owner_uuid":OWNER,"source_uuid":SPHERE,"damage_component_uuid":"163", \
                "trigger":"sphere_ram","outcome":"failed_save","applied":true,"recipient_uuid":TARGET},seat+": packet contains actual condition/result identities and failed save only")
            check(observed.evidence.damage_source_uuid==CASTER and observed.evidence.source_uuid==SPHERE \
                and observed.evidence.save.save_occurrence=="147" and observed.evidence.save.effect_id==SAVE,seat+": optical source never replaces factual damage attribution")
            source_contract(cue,observed,seat)
            negative_controls(cast,lineage.events,actors,cue.constructor_input,graph,seat)
            evidence.append({"seat":seat,"source_occurrence":cast.id,"source_lineage":cast.lineage_id,
                "contact":event,"damage_source_uuid":observed.evidence.damage_source_uuid,"save":observed.evidence.save})
        check(var_to_bytes(folded.normalized)==immutable and FileAccess.get_file_as_bytes(directory.path_join(file))==raw,seat+": projection never mutates original packets")
    var index:Dictionary=Recording.read(directory,{}, {},cache)
    check(index.ok,seat+": ordinary Studio compilation succeeds with the current typed action")
    if not index.ok:return
    var immutable:PackedByteArray=var_to_bytes([index.groups,index.rows])
    var rows:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_clip",{}).get("id")==CONTACT)
    check(rows.size()==1,seat+": one Ram yields exactly one finite contact; later eight-Fire aura damage cannot duplicate it")
    if rows.size()!=1 or observations.size()!=1:return
    var row:Dictionary=rows[0];var component:Dictionary=row.component
    check(component.status=="available" and component.source_event_uuid=="163" and component.actor_uuid==SPHERE \
        and component.target_uuid==TARGET and component.ability_id==ACTION and not component.get("persistent_owner",false),seat+": component belongs to the actual applied result and source/recipient action")
    check(is_equal_approx(float(component.duration_ms),450.0) and component.native_inputs.contact_event==observations[0].event,seat+": compiler retains exact finite source and factual packet")
    for item in index.groups:
        if not item.group.components.any(func(actual):return actual.id==component.id):continue
        var hurt:Array=item.group.actor_tracks.filter(func(track):return track.source_event_uuid=="163" and track.activity=="hit")
        var commits:Array=item.group.commits.filter(func(commit):return str(commit.get("event_uuid",""))=="163")
        check(hurt.size()==1 and is_equal_approx(component.start_ms,hurt[0].start_ms) \
            and commits.size()==1 and component.start_ms<=commits[0].at_ms,seat+": native contact and hurt share the actual result clock without reordering its HP commit")
        check(not item.group.actor_tracks.any(func(track):return track.actor_uuid==SPHERE and track.activity=="cast"),seat+": accepted Ram adds no nonexistent sphere sprite casting clip")
    var start:float=float(row.start_ms);var end:float=float(row.end_ms)
    check(is_finite(start) and is_finite(end) and end>start,seat+": actual finite source interval is usable")
    if not is_finite(start) or not is_finite(end):return
    for at in [start-.01,start+150.0,end+.01,start-.01,start+150.0]:
        var restored:RefCounted=Recording.restore(index,maxf(0.0,at))
        var active:Array=restored.component_samples(index.cache).filter(func(actual):return actual.id==component.id)
        check(active.size()==(1 if at>start and at<end else 0),seat+": seek/loop cannot replay contact outside its actual finite interval")
    var ended:RefCounted=Recording.restore(index,index.presentation_end_ms)
    check(Compare.difference(ended.state,journal.state).is_empty(),seat+": full presentation drains to the independent unchanged canonical fold")
    check(var_to_bytes([index.groups,index.rows])==immutable,seat+": seeks never alter compiled source/event ownership")
func source_contract(cue:Resource,observed:Dictionary,label:String)->void:
    var clip:Dictionary=Effects.clip(cue.clip)
    var phase:Resource=load(Effects.choice(clip).approaches[0].source_phase)
    var immutable:PackedByteArray=var_to_bytes(phase.to_clip())
    var private:Dictionary=Adapter.clip_with_inputs(phase,[{"component_path":["effect"],"input_field":"","values":observed.values}])
    var input:Dictionary=private.components[0].input
    var program:Node3D=load(private.components[0].script).new();program.specification=input
    check(program.set_contact_event(observed.event) and program.event==observed.event,label+": exact sealed source admits the actual accepted result")
    check(input.owner_uuid==OWNER and input.source_uuid==SPHERE and input.event==observed.event \
        and not input.event.has("retained_caster_dc") and not input.event.has("native_slot_damage_dice"),label+": every successful fixture identity/unused flag is replaced rather than affirmed")
    var foreign:Dictionary=observed.event.duplicate();foreign.owner_uuid="different-owner"
    check(not program.set_contact_event(foreign) and program.event.is_empty(),label+": sealed source rejects a different owner")
    check(var_to_bytes(phase.to_clip())==immutable,label+": immutable Factory source remains unchanged")
    program.free()
func negative_controls(cast:Dictionary,events:Array,actors:Dictionary,descriptor:Dictionary,graph:Dictionary,label:String)->void:
    var absent:Dictionary=graph.duplicate();absent.actor_inputs={}
    check(Results.observed(cast,descriptor,absent).is_empty(),label+": absent current source membership cannot borrow the fixture aura")
    var wrong_owner:Dictionary=descriptor.duplicate();wrong_owner.owner_condition_id="condition.other"
    check(Results.observed(cast,wrong_owner,graph).is_empty(),label+": unrelated condition cannot own the contact")
    var wrong_save:Dictionary=descriptor.duplicate();wrong_save.save_effect_id="action.other.saving_throw"
    check(Results.observed(cast,wrong_save,graph).is_empty(),label+": unrelated save cannot invent failed-save/half-damage treatment")
    var canceled:Dictionary=cast.duplicate(true);canceled.canceled=true
    check(Results.observed(canceled,descriptor,graph).is_empty(),label+": canceled accepted action cannot display contact")
    for control in ["zero","unapplied","foreign_target","independent_cast","ambiguous_save"]:
        var changed:Array=events.duplicate(true)
        var damage:Dictionary=changed.filter(func(node):return node.id=="163")[0]
        match control:
            "zero":damage.fact.applied_damage=0
            "unapplied":damage.fact.stage="requested"
            "foreign_target":damage.fact.target_entity_uuid="another-recipient"
            "independent_cast":
                changed.filter(func(node):return node.lineage_id==damage.parent_lineage)[0].fact={"kind":"spell","behavior_id":"spell.other","source_entity_uuid":CASTER}
            "ambiguous_save":changed.append(changed.filter(func(node):return node.id=="147")[0].duplicate(true))
        var altered:Dictionary=contact_graph(changed,actors)
        check(Results.observed(cast,descriptor,altered).is_empty(),label+": labelled private "+control+" control cannot borrow the original result")
