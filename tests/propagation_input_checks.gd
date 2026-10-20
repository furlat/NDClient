extends SceneTree
## Original independent journals, exact native edges and clock boundaries.
## No GPU construction, source simulation or fabricated propagation recording.
const Propagation=preload("res://presentation/propagation_inputs.gd")
const Occurrences=preload("res://presentation/occurrences.gd")
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Timeline=preload("res://presentation/timeline.gd")
const Authoring=preload("res://presentation/authoring.gd")
const Sources=preload("res://presentation/native_presentation_sources.gd")
const Build=preload("res://tools/presentation_build/abilities.gd")
const Common=preload("res://tools/presentation_build/common.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Constructed=preload("res://presentation/native_constructed_occurrence.gd")
const Inputs=preload("res://presentation/native_inputs.gd")
const Playback=preload("res://presentation/native_spell_playback.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const PATH="res://authoring/abilities/spells/spell.chain_lightning.tres"
const ID="spell.chain_lightning"
class Receiver extends Node3D:
    var links:Array=[]
    var density_calls:int=0
    func set_link_edges(value:Array)->void:links=value
    func set_density_field(_value:Variant)->void:density_calls+=1
class World extends Node:
    var timeline=Timeline.new()
    var visual_actors:Dictionary={}
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("PROPAGATION_INPUT_FAIL "+label)

func run()->void:
    var entry:Resource=load(PATH)
    check(entry.native_staging and entry.effect_scope=="application" and entry.status=="partial","Actual single-link staging is enabled without claiming all Chain Lightning variants complete")
    check(entry.effects[0].clip=="live-electric/chain_live_single" and entry.effects[0].scope=="application","Single-link constructor replaces the unrelated two-target review fixture")
    check(entry.variants.all(func(variant):return variant.status=="partial" and variant.effects.all(func(effect):return not effect.unbound_constructor_inputs.is_empty())),"Alternate branches/hops remain explicit unqualified sources")
    var report:Dictionary=Common.report()
    var clip:Dictionary=Effects.clip(entry.effects[0].clip)
    Build._check_constructor(entry.effects[0],ID,{clip.id:clip},report)
    check(report.errors.is_empty(),"Offline source, capacity, launch/speed and exact disabled-density policy checks pass")
    var exact:Resource=entry.effects[0].duplicate(true);exact.approach=Effects.choice(clip).approaches[0].id
    report=Common.report();Build._check_constructor(exact,ID,{clip.id:clip},report)
    check(report.errors.is_empty(),"Explicit selection of the existing production source retains its exact constructor contract")
    var study:Resource=entry.effects[0].duplicate(true);study.approach="runtime-prepared-followup-20261020"
    check(clip.approaches.any(func(approach):return approach.id==study.approach),"New complete package retains the separate unselected Chain Lightning study")
    report=Common.report();Build._check_constructor(study,ID,{clip.id:clip},report)
    check(not report.errors.is_empty(),"Opting into the incompatible study still requires its real constructor adaptation")
    var invalid:Resource=entry.effects[0].duplicate(true);invalid.clip="live-electric/chain_live_hops"
    report=Common.report();Build._check_constructor(invalid,ID,{invalid.clip:Effects.clip(invalid.clip)},report)
    check(not report.errors.is_empty(),"An input opt-out cannot silently spread to another Factory clip")
    var phase:Resource=load(Effects.choice(clip).approaches[0].source_phase)
    var component:Dictionary=phase.to_clip().components[0]
    component.input.density_mask=true
    report=Common.report();Build._check_input_policies(entry.effects[0],component,ID,report)
    check(not report.errors.is_empty(),"A density-consuming source cannot be admitted by the disabled policy")
    var built:Dictionary=Build.documents({"spells":{ID:entry},"contexts":{"hit_flash":load("res://authoring/abilities/contexts/hit_flash.tres")}},{"spells":{ID:PATH}})
    var count:int=0
    for example in {"chain-lightning":1,"chain-lightning-three":3}:
        for seat in ["amber","blue"]:count+=read_seat(Fixtures.journal(example,seat),example+"/"+seat,built,entry,1 if example=="chain-lightning" else 3)
    check(count==8,"Both independent seats qualify the original single link and all three actual branches")
    # Same original native stream, deliberately later authored HP/number
    # callback. Branches depend on optical contact, not publication delay.
    var delayed:Resource=entry.duplicate(true);delayed.number_frame=2.0
    var later:Dictionary=Build.documents({"spells":{ID:delayed},"contexts":{"hit_flash":load("res://authoring/abilities/contexts/hit_flash.tres")}},{"spells":{ID:PATH}})
    check(read_seat(Fixtures.journal("chain-lightning-three","amber"),"late-number-boundary",later,delayed,3)==3,"An independently authored later damage number cannot postpone the next branch")
    finish()

func source_cache(built:Dictionary)->Dictionary:
    var cache:Dictionary={}
    var admitted:Dictionary=Sources.admission(cache)
    var index:Resource=admitted.index.duplicate()
    index.spells=admitted.index.spells.duplicate();index.spells[ID]=PATH
    var loaded:Dictionary=admitted.loaded.duplicate();loaded[ID]=built.native.records[ID]
    cache[Sources.CACHE_KEY]=Sources.make_admission(index,loaded)
    return cache

func read_seat(path:String,seat:String,built:Dictionary,entry:Resource,expected_links:int)->int:
    var journal:RefCounted=Journal.new()
    var opened:Dictionary=journal.open(path,true,false)
    check(opened.ok,seat+" opens authentic current-schema journal")
    if not opened.ok:return 0
    var cache:Dictionary=source_cache(built)
    var timeline:RefCounted=Timeline.new();var duration:float=0.0;var count:int=0
    var files:PackedStringArray=DirAccess.get_files_at(path);files.sort()
    for file in files:
        if not file.ends_with(".json") or file.get_basename().length()!=16 or not file.get_basename().is_valid_int():continue
        var sequence:int=int(file.get_basename());var raw:PackedByteArray=FileAccess.get_file_as_bytes(path.path_join(file))
        var decoded:Dictionary=journal.decode_record(sequence,raw)
        check(decoded.ok,seat+" decode "+str(sequence))
        if not decoded.ok:return count
        var before:Dictionary=journal.state
        var folded:Dictionary=journal._consume_admitted(decoded.value,raw,true)
        check(folded.ok,seat+" fold "+str(sequence))
        if not folded.ok:return count
        if sequence==0:
            timeline.accept({"kind":"initialization","state":journal.state.duplicate(true),"sequence":0});continue
        var unchanged:PackedByteArray=var_to_bytes(folded.normalized)
        var compiled:Dictionary=Compiler.compile_recorded(before,folded.normalized,cache,journal.state,folded.transitions)
        check(compiled.ok,seat+" compile "+str(sequence))
        if not compiled.ok:return count
        timeline.accept({"kind":"operation","groups":compiled.value.groups})
        for group in compiled.value.groups:duration+=float(group.duration_ms)
        for original in folded.normalized.lineages:
            var lineage:Dictionary=Occurrences.group(original);var graph:Dictionary={"nodes":{},"application_indices":{}}
            var memberships:Dictionary={}
            for node in lineage.events:
                graph.nodes[node.lineage_id]=node
                if Occurrences.application(node):
                    var owner:String=str(node.resolution_record.lineage);var member:String=str(node.resolution_record.application_id)
                    if not memberships.has(owner):memberships[owner]=[]
                    if member not in memberships[owner]:memberships[owner].append(member)
                    graph.application_indices[member]=memberships[owner].find(member)
            for node in lineage.events:
                if node.get("fact")==null or node.fact.get("propagation")==null:continue
                var actual:Dictionary=Propagation.project(node,entry.effects[0].constructor_input,graph)
                check(actual.ready,seat+" actual application supplies exact directed link")
                if not actual.ready:continue
                var groups:Array=compiled.value.groups.filter(func(group):return group.components.any(func(row):return row.has("native_propagation")))
                check(groups.size()==1,seat+" compiler has one delivery group")
                if groups.size()!=1:continue
                var group:Dictionary=groups[0]
                var rows:Array=group.components.filter(func(row):return row.has("native_propagation"))
                check(rows.size()==expected_links and group.actor_tracks.filter(func(track):return track.get("activity")=="cast").size()==1,seat+" each actual edge owns a source, original caster body plays once")
                var own:Array=rows.filter(func(row):return row.source_event_uuid==node.id)
                check(own.size()==1,seat+" actual application owns exactly its own native source")
                if own.size()!=1:continue
                var row:Dictionary=own[0]
                check(row.status=="available" and row.native_propagation==node.fact.propagation,seat+" actual source/target/height/application evidence survives compilation")
                check(row.actor_uuid==actual.link.source.uuid and row.target_uuid==actual.link.target.uuid and row.source_event_uuid==node.id,seat+" delivery owns this seat's actual actor endpoints and occurrence")
                var contact:float=float(row.start_ms)+float(row.native_cue.contact)*1000.0
                var cast:Dictionary=group.actor_tracks.filter(func(track):return track.get("activity")=="cast")[0]
                var release:float=float(cast.contact_ms)
                if not actual.primary:
                    var predecessor:Array=rows.filter(func(candidate):return candidate.source_event_uuid==actual.predecessor.id)
                    check(predecessor.size()==1,seat+" secondary owns an actual primary predecessor")
                    if predecessor.size()!=1:continue
                    release=float(predecessor[0].start_ms)+float(predecessor[0].native_cue.contact)*1000.0
                    check(row.native_cue.source_socket=="body_center" and not row.cast_recipe.enabled and is_zero_approx(float(row.native_cue.launch)),seat+" branch starts at actual primary body, with no victim cast/charge")
                check(is_equal_approx(float(row.start_ms)+float(row.native_cue.launch)*1000.0,release) \
                    and is_equal_approx(contact-release,Propagation.travel_ms(actual.link,entry.effects[0].constructor_input)),seat+" native travel maps exactly once after the actual predecessor contact")
                check(row.native_rule_caster_uuid==cast.actor_uuid and row.native_constructor_evidence.rule_caster_uuid==cast.actor_uuid,seat+" optical source is not mistaken for the authoritative damage caster")
                var damage:Array=group.actor_tracks.filter(func(track):return track.get("activity")=="hit" and track.actor_uuid==row.target_uuid)
                check(damage.size()==1 and is_equal_approx(float(damage[0].start_ms),contact),seat+" recipient damage animation starts at link arrival")
                constructor(row,seat)
                routing(row,seat)
                negative(node,entry.effects[0].constructor_input,graph,seat)
                count+=1
        check(var_to_bytes(folded.normalized)==unchanged,seat+" source selection and compilation do not mutate original packets")
    timeline.advance(duration+1000.0)
    check(not timeline.busy() and Compare.difference(timeline.state,journal.state).is_empty(),seat+" presentation drains to the exact canonical fold with no holds/reordering")
    return count

func constructor(row:Dictionary,seat:String)->void:
    var phase:Resource=load(Effects.choice(row.native_clip).approaches[0].source_phase)
    var original:Dictionary=phase.to_clip()
    var prepared:Dictionary=Constructed.clip_with_inputs(phase,row.native_constructor_inputs)
    check(prepared.components[0].input.edges==row.native_inputs.link_edges and prepared.components[0].input.endpoint_count==2,seat+" private source contains only the actual edge/endpoints")
    check(prepared.components[0].input.charge_coil==(row.actor_uuid==row.native_rule_caster_uuid),seat+" only the original caster has a charge coil")
    for field in original.components[0].input:
        if field in ["edges","endpoint_count"]:continue
        check(prepared.components[0].input[field]==original.components[0].input[field],seat+" source art and settings remain unchanged: "+field)
    check(original==phase.to_clip(),seat+" sealed Factory phase is immutable")

func routing(row:Dictionary,seat:String)->void:
    var receiver:Receiver=Receiver.new();var world:World=World.new()
    var inputs:RefCounted=Inputs.new()
    var clip:Dictionary=row.native_clip.duplicate();clip.inputs=["link_edges","density_field"]
    var handle:Dictionary={"clip":clip,"occurrence":receiver,"root":receiver}
    var result:Dictionary=inputs.sync(world,handle,row,{})
    check(result.unavailable.is_empty() and result.supplied==["link_edges"] and receiver.links==row.native_inputs.link_edges,seat+" real directed link uses the production setter path")
    check(result.not_applicable=={"density_field":"selected_factory_density_mask_disabled"} and receiver.density_calls==0,seat+" source-disabled density is explicit inapplicable, never supplied empty or called")
    var missing:Dictionary=row.duplicate();missing.native_cue=row.native_cue.duplicate();missing.native_cue.erase("input_policies")
    result=inputs.sync(world,handle,missing,{})
    check(result.unavailable.get("density_field")=="provider_not_bound",seat+" declared density remains missing without explicit qualified policy")
    var rows:Array=[{"point":Vector3(1.2,1.1,2.0)},{"point":Vector3(4.8,1.6,2.2)}]
    var transform:=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*1.7),Vector3(7,0,9))
    var source_contact:float=Propagation.optical_contact(row,rows,transform)
    var expected:float=.28+maxf(.045,(transform.affine_inverse()*rows[0].point).distance_to(transform.affine_inverse()*rows[1].point)/26.0)
    check(is_equal_approx(source_contact,expected),seat+" native arrival uses the actual receiving local-frame socket distance")
    var cue:Dictionary=row.native_cue.duplicate();var unchanged:PackedByteArray=var_to_bytes(row.native_cue)
    cue.source_contact=source_contact
    check(is_equal_approx(Playback.source_time(cue,float(cue.launch)),.28) and is_equal_approx(Playback.source_time(cue,float(cue.contact)),source_contact),seat+" source launch and exact optical arrival map onto existing compiler markers once")
    check(Playback.source_time(cue,float(cue.contact)-.0001)<source_contact and Playback.source_time(cue,float(cue.contact)+.0001)>source_contact,seat+" source crosses contact continuously without restart or duplicated delay")
    check(var_to_bytes(row.native_cue)==unchanged,seat+" local clock adaptation does not mutate shared component/cue data")
    inputs.clear();world.free();receiver.free()

func negative(node:Dictionary,binding:Dictionary,graph:Dictionary,seat:String)->void:
    var original:PackedByteArray=var_to_bytes(graph)
    var missing:Dictionary=node.duplicate(true);missing.fact.erase("propagation")
    check(Propagation.project(missing,binding,graph).reason=="propagation_link_not_disclosed",seat+" missing public link remains missing")
    missing=node.duplicate(true);missing.fact.propagation.application_id="other-application"
    check(Propagation.project(missing,binding,graph).reason=="propagation_application_identity_mismatch",seat+" foreign application identity cannot be borrowed")
    missing=node.duplicate(true);missing.fact.propagation.source.uuid=node.fact.propagation.target.uuid
    check(not Propagation.project(missing,binding,graph).ready,seat+" an unrelated source cannot be silently treated as a propagation predecessor")
    missing=node.duplicate(true);missing.canceled=true
    check(not Propagation.project(missing,binding,graph).ready,seat+" canceled applications do not acquire a beam")
    var other:Dictionary=graph.duplicate(true);other.nodes.erase(str(node.resolution_record.lineage))
    check(Propagation.project(node,binding,other).reason=="propagation_cast_not_disclosed",seat+" another view cannot provide an undisclosed cast")
    other=graph.duplicate(true);other.application_indices.erase(str(node.resolution_record.application_id))
    check(Propagation.project(node,binding,other).reason=="propagation_membership_not_disclosed",seat+" application ordering comes from actual membership, not event appearance order")
    var actual:Dictionary=Propagation.project(node,binding,graph)
    if not actual.primary:
        other=graph.duplicate(true);other.nodes.erase(actual.predecessor.lineage_id)
        check(Propagation.project(node,binding,other).reason=="propagation_predecessor_not_disclosed",seat+" an undisclosed predecessor cannot be borrowed from another view")
        other=graph.duplicate(true);other.nodes["duplicate-negative-boundary"]=actual.predecessor.duplicate(true)
        check(Propagation.project(node,binding,other).reason=="propagation_predecessor_not_disclosed",seat+" ambiguous predecessor evidence stays a named gap")
    check(var_to_bytes(graph)==original,seat+" factual projector borrows native evidence without changing it")

func finish()->void:
    print(JSON.stringify({"checks":checks,"failures":failures,"scope":"Original independent Chain Lightning single and three-recipient journals, actual predecessor clocks, immutable source/ownership/input-policy checks; no GPU/other-variant/visual-approval claim"}))
    quit(0 if failures.is_empty() else 1)
