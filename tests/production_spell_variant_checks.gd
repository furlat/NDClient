extends SceneTree
## Production Resources and original independent journals, with no injected
## predicates, rewritten outcomes or fixture-owned source aliases.
const Recording=preload("res://studio/recording.gd")
const Journal=preload("res://sdk/journal.gd")
const Sources=preload("res://presentation/native_presentation_sources.gd")
const NativeSpells=preload("res://presentation/native_spell_authoring.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const CASES=[
    {"spell":"ray_of_sickness","folder":"ray-of-sickness","variant":"ray_of_sickness_hit_saved_native","saved":true,
        "clips":["bg3-36/ray-of-sickness/delivery","bg3-36/ray-of-sickness/impact"]},
    {"spell":"dissonant_whispers","folder":"dissonant-whispers","variant":"dissonant_whispers_saved_native","saved":false,
        "clips":["bg3-36/dissonant-whispers/voice"]},
    {"spell":"vicious_mockery","folder":"vicious-mockery","variant":"vicious_mockery_saved_native","saved":false,
        "clips":["bg3-36/vicious-mockery/voice"]},
    {"spell":"vicious_mockery","folder":"saved-head-programs","variant":"vicious_mockery_saved_native","saved":true,
        "clips":["bg3-36/vicious-mockery/voice","bg3-36/vicious-mockery/saved"]},
    {"spell":"dissonant_whispers","folder":"saved-head-programs","variant":"dissonant_whispers_saved_native","saved":false,
        "clips":["bg3-36/dissonant-whispers/voice"]},
    {"spell":"dissonant_whispers","journal":"res://tests/fixtures/schema16/option-identities/dissonant-whispers-saved-modular/", \
        "variant":"dissonant_whispers_saved_native","outcomes":[false,true,false]}]
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("PRODUCTION_SPELL_VARIANT_FAIL ",label)
func run()->void:
    for sample in CASES:
        for seat in ["amber","blue"]:inspect(sample,seat)
    miss_originals()
    elemental_originals()
    print("PRODUCTION_SPELL_VARIANTS ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Actual built production predicates and original single-target streams; no private authoring or native-output claim"}))
    quit(0 if failures.is_empty() else 1)
func inspect(sample:Dictionary,seat:String)->void:
    var identity:String="spell."+sample.spell
    var label:String=identity+" / "+seat
    var cache:Dictionary={}
    var record:Resource=Sources.find(identity,cache)
    check(record!=null,label+" actual built source is available")
    if record==null:return
    var alternatives:Array=record.variants.filter(func(row):return row.id==sample.variant)
    check(alternatives.size()==1,label+" one actual production outcome assignment")
    if alternatives.size()!=1:return
    var alternative:Dictionary=alternatives[0]
    check(alternative.when.save_succeeded==[true] and alternative.save_effect_id==identity+".saving_throw" and alternative.dispatch_gap.is_empty(),label+" exact disclosed save predicate is active")
    check(NativeSpells.owned_cues(alternative.selection).is_empty(),label+" finite saved feedback is not swallowed by base condition indices")
    check(NativeSpells.event_cues(alternative.selection).size()==2,label+" saved delivery/voice and receiver both survive their own ownership")
    if sample.spell=="ray_of_sickness":check(alternative.when.attack_outcome==["Hit","Crit"],label+" poison save cannot replace a missed attack")
    else:check(NativeSpells.owned_cues(record.selection)==[1,2],label+" baseline condition handover is retained")
    var immutable:PackedByteArray=var_to_bytes([record.recipe,record.selection,record.variants])
    var directory:String=str(sample.journal)+seat if sample.has("journal") else "res://tests/fixtures/schema16/root-target-save/"+sample.folder+"/"+seat+"/journal"
    var index:Dictionary=Recording.read(directory,{}, {},cache)
    check(index.get("ok",false),label+" complete original journal compiles")
    if not index.get("ok",false):return
    var found:int=0;var bodies:int=0
    for wrapped in index.groups:
        var group:Dictionary=wrapped.group
        for row in group.events:
            if row.kind!="spell" or row.get("behavior_id")!=identity:continue
            found+=1
            bodies+=group.actor_tracks.filter(func(track):return track.get("activity")=="cast" and track.get("actor_uuid")==row.actor_uuid).size()
            var saved:bool=sample.outcomes[found-1] if sample.has("outcomes") else sample.saved
            var expected:String=sample.variant if saved else ""
            check(row.get("native_variant",{}).get("id","")==expected,label+" original outcome selects the production branch")
            check(row.get("variant_dispatch_gaps",[]).is_empty(),label+" real null-application cast has no false missing-data warning")
            if saved:
                var proof:Dictionary=row.get("variant_evidence",{})
                check(proof.get("scope")=="target_cast" and proof.get("application_id")==null,label+" actual null application identity is preserved")
                check(proof.get("effect_id")==identity+".saving_throw" and proof.get("target_uuid")==row.target_uuid,label+" exact recipient/save evidence belongs to this cast")
            var clips:Array=[]
            for component in group.components:
                if str(component.get("source_event_uuid",""))!=str(row.event_uuid) or not component.get("native_spell",false):continue
                clips.append(component.native_clip.id)
                check(component.get("native_variant",{}).get("id","")==expected,label+" native component and trace use the same choice")
                check(not component.has("application_id"),label+" no artificial application UUID is introduced")
            clips.sort();var wanted:Array=sample.clips.duplicate() if sample.has("clips") else ["bg3-36/dissonant-whispers/voice"]
            if sample.has("outcomes") and saved:wanted.append("bg3-36/dissonant-whispers/saved")
            wanted.sort()
            check(clips==wanted,label+" exact finite phase list: "+str(clips))
            evidence.append({"spell":identity,"seat":seat,"event":row.event_uuid,"variant":expected,"clips":clips})
    var cast_count:int=sample.outcomes.size() if sample.has("outcomes") else 1
    check(found==cast_count and bodies==cast_count,label+" each actual target cast keeps one caster animation")
    var canonical:RefCounted=Journal.new()
    check(canonical.open(directory,false,true).ok,label+" independent canonical replay opens")
    var end:float=maxf(index.duration_ms,index.presentation_end_ms)+1.0
    var restored:RefCounted=Recording.restore(index,end)
    check(not restored.busy() and Compare.difference(restored.state,canonical.state).is_empty(),label+" ordered publication ends at the exact independent canonical value")
    check(var_to_bytes([record.recipe,record.selection,record.variants])==immutable,label+" production source remains shared and immutable")

func miss_originals()->void:
    for sample in [{"spell":"ray_of_sickness","folder":"typed-variants-miss","variant":"ray_of_sickness_miss_native","clips":["bg3-36/ray-of-sickness/miss"]},
        {"spell":"acid_arrow","folder":"projectile-variants/acid_arrow--dodge_seed_5","variant":"acid_arrow_miss_native","clips":["bg3-36/acid-arrow/miss-delivery","bg3-36/acid-arrow/miss-splash"]}]:
        for seat in ["amber","blue"]:
            var cache:Dictionary={}
            var record:Resource=Sources.find("spell."+sample.spell,cache)
            var index:Dictionary=Recording.read("res://tests/fixtures/schema16/"+sample.folder+"/"+seat+"/journal",{},{},cache)
            var label:String=sample.spell+" / "+seat+" original Miss"
            check(index.get("ok",false),label+" compiles through production")
            if not index.get("ok",false):continue
            var actual:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_variant",{}).get("id")==sample.variant)
            var clips:Array=actual.map(func(row):return row.component.native_clip.id);clips.sort()
            check(clips==sample.clips,label+" exact finite authored phase list")
            check(actual.all(func(row):return row.component.native_cue.live_endpoints[1].get("actor")=="target" and row.component.native_cue.live_endpoints[1].has("optical_miss")),label+" actual recipient registration replaces fixed review endpoints")
            check(actual.all(func(row):return row.component.actor_uuid!=row.component.target_uuid and row.component.to_position==[6,7]),label+" canonical target and original endpoint cell remain unchanged")
            for outcome in ["Hit","Crit"]:
                var selected:Dictionary=NativeSpells.selected(NativeSpells.source("spell."+sample.spell,cache),{"attack_outcome":outcome})
                check(selected.selection.get("variant",{}).get("id","")!=sample.variant,label+" "+outcome+" cannot select missed art")
            evidence.append({"spell":"spell."+sample.spell,"seat":seat,"variant":sample.variant,"clips":clips,"scope":"original missed delivery; actual renderer qualified separately"})

func elemental_originals()->void:
    # All legal selected facets are preserved in command evidence, while the
    # original replicated SpellFacts disclose no selected element. Never
    # substitute the fixed Fire/Thunder source from damage text or a title.
    for family in ["sorcerous_burst","chromatic_orb"]:
        var cache:Dictionary={};var source:Dictionary=NativeSpells.source("spell."+family,cache)
        var elements:Array=["acid","cold","fire","lightning","poison","thunder"]
        if family=="sorcerous_burst":elements.append("psychic")
        for element in elements:
            for seat in ["amber","blue"]:
                var folder:String="res://tests/fixtures/schema16/projectile-variants/"+family+"--"+element+"_original/"+seat+"/journal"
                var index:Dictionary=Recording.read(folder,{},{},cache)
                var label:String=family+" / "+element+" / "+seat
                check(index.get("ok",false),label+" original selected-facet journal compiles")
                if not index.get("ok",false):continue
                var found:int=0
                for wrapped in index.groups:
                    for event in wrapped.group.events:
                        if event.get("kind")!="spell" or event.get("behavior_id")!="spell."+family:continue
                        found+=1
                        check(event.get("effect_id")==null,label+" actual declaration has no element option identity")
                        check(event.get("native_variant",{}).is_empty(),label+" no fixed-element alternative is invented from its outcome")
                check(found==1,label+" exact accepted original declaration")
        var active:Array=source.variants.filter(func(variant):return not variant.when.get("damage_types",[]).is_empty())
        check(elements.all(func(element):return active.any(func(variant):return element.capitalize() in variant.when.damage_types)),family+" every declared element has an active typed predicate")
        for variant in active:
            var element:String=str(variant.when.damage_types[0])
            check(variant.dispatch_gap.is_empty() and variant.when.damage_types.size()==1,family+" active element has one exact public operand and no obsolete dispatch gap")
            for outcome in variant.when.get("attack_outcome",["Hit"]):
                var selected:Dictionary=NativeSpells.selected(source,{"behavior_id":"spell."+family,"damage_types":[element],"attack_outcome":outcome,"target_kind":"creature"})
                check(selected.selection.get("variant",{}).get("id")==variant.id,family+" exact declared "+element+"/"+outcome+" selects its authored source")
        check(NativeSpells.selected(source,{"behavior_id":"spell."+family,"attack_outcome":"Hit"}).selection.get("variant",{}).is_empty(),family+" missing chosen element cannot borrow a default palette")
