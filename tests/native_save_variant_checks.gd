extends SceneTree
## Actual original saves select per-application alternatives. Test-only typed
## predicates inherit the existing artwork/recipe; no production assignment,
## new source art, synthetic journal or renderer qualification is implied.
const Build=preload("res://tools/presentation_build/abilities.gd")
const Common=preload("res://tools/presentation_build/common.gd")
const SpellVariant=preload("res://presentation/source/abilities/spell_variant.gd")
const NativeSpells=preload("res://presentation/native_spell_authoring.gd")
const Sources=preload("res://presentation/native_presentation_sources.gd")
const Requirements=preload("res://presentation/requirements.gd")
const Results=preload("res://presentation/application_results.gd")
const Occurrences=preload("res://presentation/occurrences.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Journal=preload("res://sdk/journal.gd")
const Timeline=preload("res://presentation/timeline.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const ID="spell.circle_of_death"
const PATH="res://authoring/abilities/spells/spell.circle_of_death.tres"
const SAVE="spell.circle_of_death.saving_throw"
# Independent frozen-journal witnesses, identical public outcomes in each seat.
const EXPECTED={
    "fdaef6f2-e48d-4d77-b5b2-7b7badfa0ce2":{"succeeded":false,"save":"48","application":"67"},
    "7edcd4f5-1daf-4454-a96d-be84140d87d5":{"succeeded":true,"save":"72","application":"91"},
    "3b0effbf-39d8-425c-ab0d-5e9c867b2c8c":{"succeeded":false,"save":"96","application":"115"},
    "b6553571-42cb-4148-ba09-307af3b67612":{"succeeded":false,"save":"120","application":"139"}}
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("NATIVE_SAVE_VARIANT_FAIL ",label)
func source_cache(record:Resource)->Dictionary:
    var cache:Dictionary={};var admitted:Dictionary=Sources.admission(cache)
    var index:Resource=admitted.index.duplicate();index.spells=admitted.index.spells.duplicate();index.spells[ID]=PATH
    var loaded:Dictionary=admitted.loaded.duplicate();loaded[ID]=record
    cache[Sources.CACHE_KEY]=Sources.make_admission(index,loaded)
    return cache
func variant(id:String,succeeded:bool)->Resource:
    var value:Resource=SpellVariant.new();value.id=id;value.kind="outcome"
    value.when={"save_succeeded":[succeeded]};value.save_effect_id=SAVE;value.status="partial"
    # Empty effects/recipe deliberately inherit the existing cast/recipient art.
    return value
func run()->void:
    var original:Resource=load(PATH)
    var original_bytes:PackedByteArray=var_to_bytes([original.effects.map(func(row):return [row.clip,row.scope,row.constructor_input,row.extra]),original.variants.map(func(row):return [row.id,row.when])])
    var entry:Resource=original.duplicate(true)
    entry.variants.assign([variant("test.save_success",true),variant("test.save_failure",false)])
    var report:Dictionary=Common.report();Build._check_variants(entry,ID,report)
    check(report.errors.is_empty(),"Exact saving-throw effect plus disjoint boolean predicates pass offline checks")
    var invalid:Resource=entry.duplicate(true);invalid.variants[0].save_effect_id=""
    report=Common.report();Build._check_variants(invalid,ID,report)
    check(not report.errors.is_empty(),"save_succeeded without its exact save_effect_id is rejected offline")
    invalid=entry.duplicate(true);invalid.variants[1].save_effect_id="unrelated.saving_throw"
    report=Common.report();Build._check_variants(invalid,ID,report)
    check(not report.errors.is_empty(),"Opposite booleans on different saving-throw effects are not falsely treated as mutually exclusive")
    var output:Dictionary=Build.documents({"spells":{ID:entry},"contexts":{"hit_flash":load("res://authoring/abilities/contexts/hit_flash.tres")}},{"spells":{ID:PATH}})
    var record:Resource=output.native.records[ID]
    for choice in record.variants:
        check(choice.inherits_recipe and is_same(choice.recipe,record.recipe) and is_same(choice.requirements,record.requirements),"Private save predicate borrows the existing source recipe/requirements: "+str(choice.id))
        check(choice.selection.staging.cues==record.selection.staging.cues,"No new art/effect list is introduced by the save predicate: "+str(choice.id))
    for seat in ["amber","blue"]:read_seat(record,seat)
    check(var_to_bytes([original.effects.map(func(row):return [row.clip,row.scope,row.constructor_input,row.extra]),original.variants.map(func(row):return [row.id,row.when])])==original_bytes,"No preexisting typed source or production assignment is mutated")
    print("NATIVE_SAVE_VARIANT ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,"scope":"Original independent CircleDeath four-application saves, exact effect/context, application-private selection/components/trace/requirements, one caster and unchanged canonical drain; explicit test authoring only, no new art/native output/approval claim."}))
    quit(0 if failures.is_empty() else 1)
func read_seat(record:Resource,seat:String)->void:
    var directory:String="res://tests/fixtures/schema16/circle-of-death/"+seat+"/journal"
    var journal:RefCounted=Journal.new();var opened:Dictionary=journal.open(directory,true,false)
    check(opened.ok,seat+" opens the complete unchanged original stream")
    if not opened.ok:return
    var cache:Dictionary=source_cache(record);var source:Dictionary=NativeSpells.source(ID,cache)
    var immutable:PackedByteArray=var_to_bytes([record.selection,record.recipe,record.requirements,record.variants])
    var timeline:RefCounted=Timeline.new();var duration:float=0.0;var all_groups:Array=[]
    var applications:int=0;var successes:int=0;var declarations:int=0;var native_owners:Dictionary={};var cast_tracks:Array=[]
    var files:PackedStringArray=DirAccess.get_files_at(directory);files.sort()
    for file in files:
        if not file.ends_with(".json") or file.get_basename().length()!=16 or not file.get_basename().is_valid_int():continue
        var sequence:int=int(file.get_basename());var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(file))
        var decoded:Dictionary=journal.decode_record(sequence,raw);check(decoded.ok,seat+" decode "+file)
        if not decoded.ok:return
        var before:Dictionary=journal.state;var folded:Dictionary=journal._consume_admitted(decoded.value,raw,true)
        check(folded.ok,seat+" independent canonical fold "+file)
        if not folded.ok:return
        if sequence==0:
            timeline.accept({"kind":"initialization","state":journal.state.duplicate(true),"sequence":0});continue
        var packet_bytes:PackedByteArray=var_to_bytes(folded.normalized)
        var compiled:Dictionary=Compiler.compile_recorded(before,folded.normalized,cache,journal.state,folded.transitions)
        check(compiled.ok,seat+" ordinary compiler "+file)
        if not compiled.ok:return
        timeline.accept({"kind":"operation","groups":compiled.value.groups})
        for group in compiled.value.groups:
            duration+=float(group.duration_ms);all_groups.append(group)
            cast_tracks.append_array(group.actor_tracks.filter(func(track):return track.get("activity")=="cast"))
            for component in group.components:
                if component.get("native_spell",false):native_owners[str(component.native_cast_id)]=true
        for at in folded.normalized.lineages.size():
            var lineage:Dictionary=Occurrences.group(folded.normalized.lineages[at])
            var group:Dictionary=compiled.value.groups[at]
            var graph:Dictionary={"nodes":{},"spell_facts":{}}
            for node in lineage.events:graph.nodes[node.lineage_id]=node
            var results:Dictionary=Results.index(lineage.events)
            var original_saves:Dictionary={}
            for node in lineage.events:
                if node.get("fact")==null or node.fact.kind!="saving_throw" or node.fact.effect_id!=SAVE:continue
                var target:String=str(node.fact.target_entity_uuid)
                check(EXPECTED.has(target) and str(node.id)==EXPECTED[target].save and node.fact.succeeded==EXPECTED[target].succeeded,seat+" exact independent original save witness "+target)
                original_saves[target]=node
            for node in lineage.events:
                if node.get("fact")==null or node.fact.kind!="spell":continue
                var fact:Dictionary=Occurrences.spell(node,graph)
                if fact.get("behavior_id")!=ID:continue
                var context:Dictionary=Results.save_context(node,results)
                var choice:Dictionary=NativeSpells.selected(source,fact,context if Occurrences.application(node) else {"applicable":false})
                var trace:Array=group.events.filter(func(row):return str(row.event_uuid)==str(node.id))
                check(trace.size()==1,seat+" one diagnostic row for the actual spell occurrence "+str(node.id))
                if not Occurrences.application(node):
                    declarations+=1
                    check(not context.ready and is_same(choice.selection,record.selection),seat+" declaration has no application identity and stays on the baseline")
                    check(choice.get("variant_dispatch_gaps",[]).is_empty(),seat+" save outcome is inapplicable to a declaration, not a missing provider")
                    if trace.size()==1:
                        check(trace[0].get("native_variant",{}).is_empty(),seat+" declaration never borrows a recipient save variant")
                        check(trace[0].get("variant_dispatch_gaps",[]).is_empty(),seat+" declaration has no false missing-save warning")
                    continue
                var target:String=str(fact.target_entity_uuid)
                check(EXPECTED.has(target) and str(node.id)==EXPECTED[target].application,seat+" exact original application identity "+target)
                if not EXPECTED.has(target):continue
                applications+=1;var expected:Dictionary=EXPECTED[target];successes+=int(expected.succeeded)
                check(original_saves.has(target),seat+" application has its own exact-effect original save")
                check(context.ready and context.by_effect.has(SAVE) and context.by_effect[SAVE].ready,seat+" actual application exposes its exact save context "+str(node.id))
                if not context.by_effect.has(SAVE):continue
                var saved:Dictionary=context.by_effect[SAVE]
                check(saved.save_succeeded==expected.succeeded,seat+" true/false outcome comes from this application's original save")
                var independent:Dictionary={"cast_lineage":str(node.resolution_record.lineage),"application_id":str(node.resolution_record.application_id),
                    "application_occurrence":str(node.id),"application_lineage":str(node.lineage_id),"target_uuid":target,"effect_id":SAVE,
                    "save_occurrence":str(original_saves[target].id),"save_lineage":str(original_saves[target].lineage_id)}
                check(saved.evidence==independent,seat+" exact save/source/application/target provenance matches independent original nodes")
                var expected_id:String="test.save_success" if expected.succeeded else "test.save_failure"
                check(choice.selection.get("variant",{}).get("id","")==expected_id,seat+" exact application-private save branch "+str(node.id))
                check(is_same(choice.recipe,record.recipe) and is_same(choice.recipe.cast,record.recipe.cast),seat+" save outcome never rebuilds or replaces the original caster recipe")
                var rows:Array=group.components.filter(func(component):return str(component.get("source_event_uuid",""))==str(node.id) and component.get("native_spell",false))
                check(rows.size()==1,seat+" one real recipient source for this save application")
                for component in rows:
                    check(component.native_variant.id==expected_id and component.native_variant.when.save_succeeded==[expected.succeeded] and component.native_variant.save_effect_id==SAVE,seat+" compiled component keeps its own exact selected save predicate/effect")
                    check(component.target_uuid==target and component.application_id==str(node.resolution_record.application_id),seat+" selected component retains actual target/application identity")
                    if trace.size()==1:
                        check(trace[0].native_variant==component.native_variant,seat+" trace and native component use the same cached choice")
                        check(trace[0].variant_evidence==saved.evidence,seat+" trace retains the same exact original save evidence as selection")
                var required:Array=Requirements._prepared_recipe(choice.recipe,record.requirement_source,"spell",ID,cache)
                check(required==record.requirements,seat+" requirement values come from this selected admitted recipe")
                for index in required.size():check(is_same(required[index],record.requirements[index]),seat+" prepared requirement row is borrowed from the exact immutable owner "+str(index))
                if trace.size()==1:check(trace[0].get("variant_dispatch_gaps",[]).is_empty(),seat+" known selected save does not report an unknown-branch gap")
                controls(source,fact,context,seat+" application "+str(node.id))
                evidence.append({"seat":seat,"sequence":sequence,"application":str(node.id),"target":target,"save_occurrence":expected.save,"save_succeeded":expected.succeeded,"variant":expected_id,"projection_evidence":saved.evidence})
        check(var_to_bytes(folded.normalized)==packet_bytes,seat+" selector/compiler preserve every original normalized fact "+file)
    check(applications==4 and successes==1 and declarations==1,seat+" four original applications retain exactly one success and three failures")
    check(cast_tracks.size()==1 and native_owners.size()==1,seat+" all four save branches share one actual caster body/native cast owner")
    timeline.advance(duration+1000.0)
    check(not timeline.busy() and Compare.difference(timeline.state,journal.state).is_empty(),seat+" presentation drains to the exact independently folded canonical state in original order")
    check(var_to_bytes([record.selection,record.recipe,record.requirements,record.variants])==immutable,seat+" all outcomes/diagnostics/requirements leave the shared source unchanged")
func missing_choice(choice:Dictionary,reason:String,label:String)->void:
    check(not choice.get("variant_dispatch_gaps",[]).is_empty(),label+" retains an explicit save-dispatch gap")
    var exact:Array=choice.get("variant_dispatch_gaps",[]).filter(func(row):return row.get("reason")==reason and row.get("effect_id")==SAVE and row.get("variant_id") in ["test.save_success","test.save_failure"])
    check(exact.size()==2,label+" names the actual missing/ambiguous context for both exact-effect candidates: "+reason)
func controls(source:Dictionary,fact:Dictionary,context:Dictionary,label:String)->void:
    # Selector-only controls, never passed off as original journal outcomes.
    var unknown:Dictionary=NativeSpells.selected(source,fact,{"ready":false,"reason":"application_result_identity_unavailable","by_effect":{}})
    check(is_same(unknown.selection,source.selection),label+" unknown context retains baseline")
    missing_choice(unknown,"application_result_identity_unavailable",label+" explicit unknown-context control")
    var absent:Dictionary=context.duplicate(true);absent.by_effect["unrelated.saving_throw"]=absent.by_effect[SAVE];absent.by_effect.erase(SAVE)
    var missing:Dictionary=NativeSpells.selected(source,fact,absent)
    check(is_same(missing.selection,source.selection),label+" missing exact save effect cannot borrow another result")
    missing_choice(missing,"save_effect_unavailable",label+" explicit missing-effect control")
    var ambiguous:Dictionary=context.duplicate(true)
    ambiguous.by_effect[SAVE]={"ready":false,"reason":"save_result_ambiguous"}
    var unresolved:Dictionary=NativeSpells.selected(source,fact,ambiguous)
    check(is_same(unresolved.selection,source.selection),label+" ambiguous exact save cannot choose success or failure")
    missing_choice(unresolved,"save_result_ambiguous",label+" explicit ambiguous-context control")
