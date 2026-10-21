extends SceneTree
## Exact opt-in selection and unchanged gameplay operands. No constructors,
## native pixels, performance thresholds or artwork approval are claimed.
const Build=preload("res://tools/presentation_build/abilities.gd")
const Sources=preload("res://presentation/native_presentation_sources.gd")
const Spells=preload("res://presentation/native_spell_authoring.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Recording=preload("res://studio/recording.gd")
const Journal=preload("res://sdk/journal.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const Delivery=preload("res://presentation/spell_delivery.gd")
const Birth=preload("res://presentation/actor_birth_inputs.gd")
const Records=preload("res://tools/presentation_build/ability_records.gd")
const APPROACH="runtime-prepared-heavy-effects-20261020"
const ACID_PREPARATION="res://assets/vfx/extensions/followup-20261020/sources/7dd1897cdd5ee8a903b9/source_readiness.gd"
const CLIPS={
    "conjure_elemental":"high-level-22/summon-manifestation/air_elemental/admitted",
    "summon_dragon":"high-level-22/summon-manifestation/draconic_spirit/admitted",
    "planar_ally":"high-level-22/summon-manifestation/deva/admitted",
    "ice_storm":"assembled/ice_storm_native",
    "acid_arrow":"bg3-36/acid-arrow/delivery"}
const UNSELECTED={"conjure_animals":"assembled/conjure_animals_native",
    "conjure_fey":"assembled/conjure_fey_native","conjure_fiend":"assembled/conjure_fiend_native"}
const ORIGINALS={
    "conjure_elemental":{"path":"res://tests/fixtures/schema16/scenarios/actor-birth-air-elemental","actor":"615e48e0-09ab-4063-8157-bd1be68e2981"},
    "summon_dragon":{"path":"res://tests/fixtures/schema16/scenarios/actor-birth-draconic-spirit","actor":"92a47894-dfc0-4cd2-b482-e0c88ffb3853"},
    "planar_ally":{"path":"res://tests/fixtures/schema16/scenarios/actor-birth-deva","actor":"ec65bbc6-f89d-4c39-ae06-82aa3ae18904"},
    "acid_arrow":{"path":"res://tests/fixtures/schema16/production-condition-handover/spell.acid_arrow__baseline/20261019T141826.056415Z","journal":"journal","actor":""}}
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("HEAVY_EFFECT_SELECTION_FAIL ",label)
func run()->void:
    Effects.set_requested("native")
    var supplied:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/format/heavy-effects-20261020-choices.json"))
    check(supplied.get("approach")==APPROACH and supplied.get("version")=="runtime-heavy-effects-20261020-fa024e4e027bf708","Exact complete heavy successor and choice map are installed")
    var choices:Dictionary={}
    for row in supplied.get("choices",[]):choices[row.clip_id]=row
    var entries:Dictionary={};var paths:Dictionary={}
    for name in CLIPS:
        var id:String="spell."+name;var path:String="res://authoring/abilities/spells/"+id+".tres"
        var entry:Resource=load(path);entries[id]=entry;paths[id]=path
        check(entry.effects[0].clip==CLIPS[name] and entry.effects[0].approach==APPROACH,id+": only its exact existing default cue selects the delivered approach")
        check(entry.effects[0].immutable_preparation==(ACID_PREPARATION if name=="acid_arrow" else ""),id+": only Acid delivery opts into its isolated source coordinator")
        check(entry.effects.slice(1).all(func(cue):return cue.approach!=APPROACH) \
            and entry.variants.all(func(variant):return variant.effects.all(func(cue):return cue.approach!=APPROACH)),id+": unrelated phases and inactive alternatives are not activated")
    var context:Dictionary={"hit_flash":load("res://authoring/abilities/contexts/hit_flash.tres")}
    var built:Dictionary=Build.documents({"spells":entries,"contexts":context},{"spells":paths})
    var cache:Dictionary=source_cache(built,paths)
    for name in CLIPS:
        var id:String="spell."+name;var clip:Dictionary=Effects.clip(CLIPS[name])
        check(choices.has(CLIPS[name]),id+": selected source is one exact delivered choice")
        if not choices.has(CLIPS[name]):continue
        var selected:Dictionary=built.native.records[id].selection
        var rows:Array=Spells.phases(selected,{"prepare":0.0},500.0,300.0,0,true)
        # Keep the exact authored provenance and all renderer operands. A
        # Resource duplicate loses resource_path, which is unrelated to the
        # alternate source choice this isolated control compares.
        var baseline:Dictionary=selected.duplicate(true)
        baseline.staging.cues[0].erase("approach")
        baseline.staging.cues[0].erase("immutable_preparation")
        var baseline_rows:Array=Spells.phases(baseline,{"prepare":0.0},500.0,300.0,0,true)
        var original:PackedByteArray=var_to_bytes(clip)
        var first:Array=rows.filter(func(row):return int(row.native_cue.source_index)==0)
        check(first.size()==1,id+": ordinary phase compiler retains one default occurrence")
        if first.size()!=1:continue
        var occurrence:Dictionary=Effects.occurrence_clip(first[0])
        var physical:Dictionary=Effects.choice(occurrence)
        check(physical.approaches.size()==1 and physical.approaches[0].id==APPROACH \
            and physical.approaches[0].path==choices[CLIPS[name]].constructor \
            and physical.approaches[0].source_phase==choices[CLIPS[name]].phase,id+": compiled occurrence selects the exact supplied constructor and phase")
        var source_phase:Resource=load(physical.approaches[0].source_phase)
        check(float(physical.approaches[0].source_simulation_hz)==float(source_phase.to_clip().simulation_hz),id+": selected rate matches the actual source phase contract, never a common cadence")
        check(Compare.difference(without_selection(rows),without_selection(baseline_rows)).is_empty(),id+": approach selection changes no body/endpoint/owner/source-time/phase operands")
        var prepared:Array=Spells.effect_clips(selected).filter(func(value):return value.id==CLIPS[name])
        check(prepared.size()==1 and Effects.key(prepared[0])==Effects.key(occurrence),id+": selection preparation demands the actual selected physical source, not its prior default")
        check(Effects.resource_paths(occurrence).has(choices[CLIPS[name]].phase) \
            and (name!="acid_arrow" or ACID_PREPARATION in Effects.resource_paths(occurrence)),id+": selected phase and exact coordinator remain in the preparation closure")
        check(var_to_bytes(clip)==original,id+": private occurrence selection never modifies package defaults")
    preparation_identity_controls(built.native.records["spell.acid_arrow"].selection)
    var darkness:Resource=load("res://authoring/abilities/spells/spell.darkness.tres")
    check(darkness.effects.all(func(cue):return cue.approach!=APPROACH),"Unqualified Darkness is not opted into by this batch")
    for name in UNSELECTED:
        var entry:Resource=load("res://authoring/abilities/spells/spell."+name+".tres")
        var clip:Dictionary=Effects.clip(UNSELECTED[name])
        var cue:Dictionary=Records.cue_from_effect(entry.effects[0],0)
        check(not clip.is_empty() and clip.approaches.any(func(approach):return approach.id==APPROACH),name+": exact heavy source remains installed and available for later compatible ownership")
        check(entry.effects[0].constructor_input.get("kind")=="actor_birth" \
            and entry.effects[0].constructor_input.get("creature_ids")==Array(entry.summons) \
            and entry.effects[0].attachment=="recipient_ground" and entry.effects[0].clip!=clip.id,
            name+": neutral manifestation uses exactly its declared actual birth family")
        check(entry.variants.any(func(variant):return variant.when.is_empty() and not variant.dispatch_gap.is_empty() \
            and variant.effects.any(func(use):return use.clip==clip.id)),name+": the fixed review departure remains an inspectable unselected alternative")
        var control:Dictionary={"id":"spell."+name,"staging":{"cues":[cue]},"lifecycle":{}}
        var fact:Dictionary={"source_entity_uuid":"unit-caster","source_position":[3,7],"target_entity_uuid":null}
        var endpoint:Dictionary=Delivery.endpoints(fact,{"positions":{"unit-caster":[3,7]},"contacts":{}},{"tiles":{}},control)
        check(not endpoint.is_empty() and endpoint.ground_target and endpoint.to_position==[3,7] \
            and not Birth.packet({"actor_uuid":"unit-caster","target_uuid":null},{"actors":{}},true).ready,
            name+": labelled null-recipient control permits the caster ground anchor but cannot admit a summoned recipient without an actual birth binding")
    for name in ORIGINALS:
        for seat in ["amber","blue"]:actual_original(name,seat,cache)
    Effects.set_requested("")
    print("HEAVY_EFFECT_SELECTION ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Five supported typed and ordinary compiled source selections; four durable original families in both independent seats. Three Conjure families use explicit neutral actual-birth art while their old fixed-departure assemblies remain unselected; labelled endpoint controls forbid a fake recipient. IceStorm native output belongs to the separate selected-family gate. No native pixels/performance or human visual approval claimed."}))
    quit(0 if failures.is_empty() else 1)
func source_cache(built:Dictionary,paths:Dictionary)->Dictionary:
    var cache:Dictionary={};var admitted:Dictionary=Sources.admission(cache)
    var index:Resource=admitted.index.duplicate(false);index.spells=admitted.index.spells.duplicate()
    var loaded:Dictionary=admitted.loaded.duplicate()
    for id in paths:index.spells[id]=paths[id];loaded[id]=built.native.records[id]
    cache[Sources.CACHE_KEY]=Sources.make_admission(index,loaded)
    return cache
func without_selection(rows:Array)->Array:
    var result:Array=rows.duplicate(true)
    for row in result:
        row.native_cue.erase("approach");row.native_cue.erase("immutable_preparation")
    return result
func preparation_identity_controls(selected:Dictionary)->void:
    var original:PackedByteArray=var_to_bytes(selected)
    var isolated:Dictionary=selected.staging.cues[0].duplicate(false)
    var root_prepared:Dictionary=isolated.duplicate(false);root_prepared.erase("immutable_preparation")
    var prior:Dictionary=root_prepared.duplicate(false);prior.erase("approach")
    var control:Dictionary=selected.duplicate(false);control.staging=selected.staging.duplicate(false)
    control.staging.cues=[isolated,root_prepared,prior,isolated.duplicate(false)]
    control.lifecycle={};control.excluded_cue_indices=[]
    var clips:Array=Spells.effect_clips(control)
    check(clips.size()==3 and clips.all(func(clip):return clip.id==CLIPS.acid_arrow),"Labelled preparation control retains distinct same-ID approach/coordinator sources and deduplicates only the exact repeated source")
    var keys:Dictionary={}
    for clip in clips:keys[Effects.key(clip)]=true
    check(keys.size()==3 and clips.filter(func(clip):return clip.get("immutable_preparation")==ACID_PREPARATION).size()==1 \
        and clips.filter(func(clip):return clip.get("approach_id")==APPROACH and not clip.has("immutable_preparation")).size()==1 \
        and clips.filter(func(clip):return not clip.has("approach_id")).size()==1,"Same clip ID cannot collapse isolated readiness, root readiness and original-default source identities")
    check(var_to_bytes(selected)==original,"Private preparation identity controls leave the production selection and source operands immutable")
func actual_original(name:String,seat:String,cache:Dictionary)->void:
    var label:String=name+"/"+seat;var directory:String=ORIGINALS[name].path.path_join(seat).path_join(ORIGINALS[name].get("journal",""))
    var journal:RefCounted=Journal.new();var opened:Dictionary=journal.open(directory,true,true)
    var index:Dictionary=Recording.read(directory,{}, {},cache)
    check(opened.ok and index.ok,label+": independent original and normal Recording compiler open")
    if not opened.ok or not index.ok:return
    var immutable:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
    var rows:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_clip",{}).get("id")==CLIPS[name] \
        and int(row.component.get("native_cue",{}).get("source_index",-1))==0)
    check(rows.size()==1,label+": actual event still owns exactly one original default source")
    if rows.size()!=1:return
    var component:Dictionary=rows[0].component
    var source:Dictionary=Effects.choice(Effects.occurrence_clip(component))
    check(component.get("status","available")=="available" and source.approaches.size()==1 and source.approaches[0].id==APPROACH,label+": real factual occurrence reaches the exact selected approach")
    if not ORIGINALS[name].actor.is_empty():
        check(component.native_actor_birth.actor_uuid==ORIGINALS[name].actor \
            and component.actor_uuid!=component.target_uuid and component.target_uuid==ORIGINALS[name].actor \
            and not component.native_constructor_inputs.is_empty(),label+": actual born actor/constructor evidence remains distinct from the rule caster")
    else:
        check(component.native_cue.immutable_preparation==ACID_PREPARATION \
            and component.native_cue.delivery_timing and component.native_cue.live_endpoints.size()==4,label+": actual Acid hand/target/delivery operands survive isolated immutable preparation")
    var final:RefCounted=Recording.restore(index,index.presentation_end_ms+1000.0)
    var difference:String=Compare.difference(final.state,journal.state)
    check(difference.is_empty(),label+": selected source does not alter the independent canonical drain: "+difference)
    var looped:RefCounted=Recording.restore(index,float(rows[0].start_ms)+100.0)
    check(looped.component_samples(index.cache).any(func(sample):return sample.id==component.id \
        and Effects.choice(Effects.occurrence_clip(sample)).approaches[0].id==APPROACH),label+": seek/loop reconstructs the same exact source selection")
    check(var_to_bytes([index.initialization,index.groups,index.rows])==immutable,label+": source selection and seek leave original records/cuts unchanged")
    evidence.append({"spell_id":"spell."+name,"seat":seat,"component_id":component.id,"source_event_uuid":component.source_event_uuid,
        "approach":APPROACH,"rendered":false,"visual_approval":false})
