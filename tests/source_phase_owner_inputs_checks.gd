extends SceneTree
## Explicit mapped sources plus genuine owner observations. Pixel/readiness
## qualification belongs to the companion native ordinary-Play harness.
const Effects=preload("res://presentation/effect_package.gd")
const Inputs=preload("res://presentation/native_inputs.gd")
const Records=preload("res://tools/presentation_build/ability_records.gd")
const Builder=preload("res://tools/presentation_build/abilities.gd")
const Items=preload("res://presentation/native_items.gd")
const Recording=preload("res://studio/recording.gd")
const Report=preload("res://studio/capability_report.gd")
const Studio=preload("res://studio/studio.gd")
const SOURCES={"aura":"production-review/aura-of-life/main_owner","deafness":"production-review/deafness/finite_application","item":"production-review/continual-flame/source-hold-loop"}
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("SOURCE_PHASE_OWNER_FAIL ",label)
static func uses()->Dictionary:
    var aura:Resource=load("res://authoring/abilities/conditions/condition.spell.aura_of_life.owner.tres")
    var deafness:Resource=load("res://authoring/abilities/spells/spell.blindness_deafness.tres")
    var items:Resource=load("res://authoring/abilities/contexts/item_attachments.tres")
    return {"aura":aura.effects[0],"deafness":deafness.variants.filter(func(row):return row.id=="control.deafened")[0].effects[0],"item":items.effects[0]}
func source_contracts()->void:
    var index:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Effects.INDEX))
    var before:PackedByteArray=var_to_bytes(index)
    var table:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Effects.SOURCE_TABLE))
    check(table.resources.size()==6,"Delivered standalone table retains exactly six sources outside the indexed clip inventory")
    for name in uses():
        var use:Resource=uses()[name];var cue:Dictionary=Records.cue_from_effect(use,0)
        var original:PackedByteArray=var_to_bytes(use.source_phase.to_clip())
        var clip:Dictionary=Effects.for_cue(cue)
        check(not clip.is_empty(),name+" exact delivered mapped source resolves")
        if clip.is_empty():continue
        check(clip.id==SOURCES[name] and clip.source_kind=="standalone_phase" and clip.source_phase==use.source_phase.resource_path,name+" actual standalone phase identity is explicit")
        check(Effects.clip(SOURCES[name]).is_empty() and not index.clips.any(func(row):return row.clip_id==SOURCES[name]),name+" does not fabricate an indexed clip or mutate the package registry")
        check(clip.inputs==use.source_inputs.keys() and clip.input_setters==use.source_inputs,name+" exact setter map is preserved through typed emission")
        check(Effects.choice(clip).approaches[0].seekable==use.source_seekable,name+" source seek claim remains the explicit qualified declaration")
        check(Effects.resource_paths(clip).has(use.source_phase.resource_path),name+" ordinary source dependency preparation includes the actual mapped phase")
        var back:Resource=Records.effect_from_cue(cue,"client")
        check(Records.cue_from_effect(back,0)==cue,name+" typed source mapping round-trips without private constructor facts")
        var component:Dictionary={"native_clip":clip,"native_cue":cue}
        var method:Dictionary=Report.native_method(component)
        check(method.source_kind=="standalone_phase" and method.source_phase==use.source_phase.resource_path and method.runtime_binding=="not_examined",name+" structured inspection distinguishes source presence from dynamic binding")
        check(Studio.effect_lines(component).any(func(line):return line.begins_with("Standalone PhaseResource:")),name+" human inspector does not call this an indexed package clip")
        var bad:Dictionary=cue.duplicate(true);bad.source_phase="res://authoring/abilities/spells/spell.aid.tres"
        check(Effects.for_cue(bad).is_empty(),name+" refuses an unlisted Resource instead of loading arbitrary authoring")
        bad=cue.duplicate(true);bad.source_inputs={}
        check(Effects.for_cue(bad).is_empty(),name+" requires explicit source input methods")
        check(var_to_bytes(use.source_phase.to_clip())==original,name+" resolving/inspection leaves immutable source art untouched")
    check(var_to_bytes(JSON.parse_string(FileAccess.get_file_as_string(Effects.INDEX)))==before,"Standalone resolution leaves installed index byte-value data unchanged")
    var context:Resource=load("res://authoring/abilities/contexts/item_attachments.tres")
    var document:Dictionary=Records.context_document(context,"item_attachments")
    check(document.nativeEffects.size()==3 and document.nativeEffects.map(func(cue):return cue.item_effect_behavior_id)==["condition.spell.continual_flame","condition.spell.magic_weapon","condition.class.paladin.sacred_weapon"],"Existing item attachment document carries all three exact membership-qualified global uses")
    var spell:Resource=load("res://authoring/abilities/spells/spell.continual_flame.tres")
    check(spell.excluded_cues==PackedInt32Array([0]),"Old finite cast review hands over to the actual item owner")
    var blind:Resource=load("res://authoring/abilities/spells/spell.blindness_deafness.tres")
    check(blind.effects[0].clip=="review/blindness_deafness/back/lifecycle" and uses().deafness.source_end==1.2,"Finite Deafness assignment preserves Blinded and its authored1.2s application")
func aura_originals()->void:
    for seat in ["amber","blue"]:
        var label:String="Aura/"+seat
        var index:Dictionary=Recording.read("res://tests/fixtures/schema16/scenarios/aura-of-life/"+seat)
        check(index.ok,label+" independent genuine original compiles")
        if not index.ok:continue
        var rows:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_clip",{}).get("id")==SOURCES.aura)
        check(rows.size()==1,label+" exact main owner has one independently owned field")
        if rows.size()!=1:continue
        var component:Dictionary=rows[0].component
        var before:PackedByteArray=var_to_bytes(component)
        var actual:Dictionary=Inputs.owner_packet(component,true)
        check(actual.ready,label+" actual main condition supplies complete ownership/state")
        if not actual.ready:continue
        check(actual.binding.owner_uuid=="db914941-815c-4847-8891-cff1db4bc8ce" and actual.binding.condition_id=="condition.spell.aura_of_life.owner",label+" owner is the actual main UUID, not the recipient benefit")
        check(actual.binding.source_entity_uuid==component.actor_uuid and actual.binding.recipient_entity_uuid==component.actor_uuid,label+" source and self recipient are the actual caster")
        check(actual.value.condition_state==component.condition.state and actual.value.observed and actual.value.present,label+" exact native state is supplied without a dummy body/spatial UUID")
        check(not actual.binding.has("spatial_effect_uuid") and not actual.value.has("removal_at_seconds"),label+" live owner does not invent radius publication, expiry or removal")
        if seat=="blue":check(actual.value.condition_state.duration==null,label+" hidden duration remains null")
        var wrong:Dictionary=component.duplicate(true);wrong.condition_uuid="wrong-main-owner"
        check(not Inputs.owner_packet(wrong,true).ready,label+" rejects mismatched ownership")
        wrong=component.duplicate(true);wrong.condition.state=null
        check(not Inputs.owner_packet(wrong,true).ready,label+" missing actual state refuses source admission")
        check(not Inputs.owner_packet(component,false).value.observed,label+" observation withdrawal is explicit at unchanged owner age")
        var retired:Dictionary=component.duplicate(true);retired.removal_age_ms=100.0;retired.duration_ms=8750.0
        var removed:Dictionary=Inputs.owner_packet(retired,true)
        check(not removed.value.present and removed.value.removal_at_seconds==8.75,label+" explicit client removal control uses the actual owner clock, not the4.4s inspection domain")
        check(var_to_bytes(component)==before,label+" packets and negative controls do not mutate original facts")
        evidence.append({"family":"aura","seat":seat,"owner":actual.binding,"state":actual.value,"source_kind":component.native_clip.source_kind})
func run()->void:
    source_contracts();aura_originals()
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Exact delivered standalone PhaseResource admission/typed emission/inspection and independently recorded Aura main-owner state. Readiness, head/item optical output, source raster, seek/loop and teardown are separate native qualification; no art/performance acceptance."}
    FileAccess.open("res://.runtime/source-phase-owner-input-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SOURCE_PHASE_OWNER_INPUTS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
