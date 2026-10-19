extends SceneTree
## Original server applications drive scope and construction, never fixture IDs.
const Results=preload("res://presentation/application_results.gd")
const Occurrences=preload("res://presentation/occurrences.gd")
const Delivery=preload("res://presentation/spell_delivery.gd")
const Build=preload("res://tools/presentation_build/abilities.gd")
const Records=preload("res://tools/presentation_build/ability_records.gd")
const Sources=preload("res://presentation/native_presentation_sources.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Adapter=preload("res://presentation/native_constructed_occurrence.gd")
const Warm=preload("res://presentation/native_source_startup.gd")
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Timeline=preload("res://presentation/timeline.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const ID="spell.circle_of_death"
const PATH="res://authoring/abilities/spells/spell.circle_of_death.tres"
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("APPLICATION_CONSTRUCTOR_FAIL "+label)
func run()->void:
    var directory:String=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--journal="):directory=arg.trim_prefix("--journal=")
    if directory.is_empty():printerr("Pass --journal=<actual Circle baseline amber journal>");quit(2);return
    var entry:Resource=load(PATH)
    var policy:Resource=load("res://authoring/abilities/contexts/hit_flash.tres")
    var built:Dictionary=Build.documents({"spells":{ID:entry},"contexts":{"hit_flash":policy}},{"spells":{ID:PATH}})
    var record:Resource=built.native.records[ID]
    check(entry.effects.size()==2 and entry.effects[0].scope=="cast" and entry.effects[1].scope=="application","One cast-wide source and one reusable actual-application template replace review actor aliases")
    var cue:Dictionary=Records.cue_from_effect(entry.effects[1],1)
    var restored:Resource=Records.effect_from_cue(cue,"test")
    check(restored.scope=="application" and restored.constructor_input==entry.effects[1].constructor_input and not restored.extra.has("constructor_input"),"Scope and constructor projection round-trip through explicit authored fields")
    var clips:Array=preload("res://presentation/native_spell_authoring.gd").effect_clips(record.selection)
    var receiver:Dictionary=clips.filter(func(clip):return clip.get("requires_constructor_input",false))[0]
    check(Warm.source_plan([receiver]).is_empty(),"Selection cannot warm a source by constructing its successful review application")
    var cache:Dictionary={}
    var admitted:Dictionary=Sources.admission(cache)
    var index:Resource=admitted.index.duplicate()
    index.spells=admitted.index.spells.duplicate();index.spells[ID]="actual typed Circle source"
    var loaded:Dictionary=admitted.loaded.duplicate();loaded[ID]=record
    cache[Sources.CACHE_KEY]=Sources.make_admission(index,loaded)
    var journal:RefCounted=Journal.new()
    var opened:Dictionary=journal.open(directory,true,false)
    check(opened.ok,"Open the original server journal")
    if not opened.ok:finish();return
    var names:Array=[]
    for name in DirAccess.get_files_at(directory):
        if name.ends_with(".json") and name.get_basename().is_valid_int():names.append(name)
    names.sort()
    var groups:Array=[];var timeline:RefCounted=Timeline.new();var duration:float=0.0
    var applications:Array=[];var expected_saves:Dictionary={};var expected_damage:Dictionary={}
    for sequence in names.size():
        var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(names[sequence]))
        var decoded:Dictionary=journal.decode_record(sequence,raw)
        check(decoded.ok,"Decode actual packet "+str(sequence))
        if not decoded.ok:finish();return
        var before:Dictionary=journal.state
        var folded:Dictionary=journal._consume_admitted(decoded.value,raw,true)
        check(folded.ok,"Fold actual packet "+str(sequence))
        if not folded.ok:finish();return
        if sequence==0:
            timeline.accept({"kind":"initialization","state":journal.state.duplicate(true),"sequence":0});continue
        var compiled:Dictionary=Compiler.compile_recorded(before,folded.normalized,cache,journal.state,folded.transitions)
        check(compiled.ok,"Compile actual packet "+str(sequence))
        if not compiled.ok:finish();return
        for native in folded.normalized.lineages:
            var lineage:Dictionary=Occurrences.group(native)
            var source_nodes:Dictionary={}
            for item in lineage.events:source_nodes[item.lineage_id]=item
            var source_graph:Dictionary={"nodes":source_nodes,"positions":{},"spell_facts":{}}
            var results:Dictionary=Results.index(lineage.events)
            for node in lineage.events:
                if node.get("fact")==null or node.fact.kind!="spell":continue
                if not Occurrences.application(node):
                    var alternate:Dictionary=record.selection.duplicate(true)
                    alternate.delivery.scope="application"
                    # Unscoped cues still inherit application ownership even
                    # beside an explicitly cast-scoped cue on the same spell.
                    alternate.staging.cues.append({"scope":"","role":"attached"})
                    var carrier:Dictionary=Delivery.for_occurrence(alternate,node,true)
                    check(carrier.staging.cues.size()==1 and carrier.staging.cues[0].scope=="cast" and Delivery.owns_delivery(node,{},carrier,true),"Explicit cast ownership survives inherited application delivery without promoting unscoped cues")
                    continue
                var observed:Dictionary=Results.project(node,entry.effects[1].constructor_input,results)
                if not observed.ready:continue
                var source:Variant=Occurrences.spell(node,source_graph).source_entity_uuid
                var current_inputs:Dictionary=Compiler._spell_actor_inputs(node,{},journal.state,source_graph)
                check(is_same(current_inputs[source],journal.state.actors[source]),"Sparse application borrows only its actual canonical source actor context")
                var hidden:Dictionary=journal.state.actors[source].duplicate();hidden.last_visual_position=null
                source_graph.positions[source]=[99,99]
                var hidden_inputs:Dictionary=Compiler._spell_actor_inputs(node,{}, {"actors":{source:hidden}},source_graph)
                check(hidden_inputs[source].last_visual_position==null,"A later movement or disclosed endpoint cannot grant visual admission to a hidden source")
                var explicit:Dictionary={source:hidden}
                check(is_same(Compiler._spell_actor_inputs(node,explicit,journal.state,source_graph),explicit),"Explicit pre-row captures retain priority over other source snapshots")
                expected_saves[observed.values.target_actor]=observed.values.save_succeeded
                expected_damage[observed.values.target_actor]=observed.evidence.applied_damage
                var absent:Dictionary=results.duplicate();absent.erase(Results.key(node))
                check(not Results.project(node,entry.effects[1].constructor_input,absent).ready,"An unrelated target or fixture cannot replace a missing application result")
        for group in compiled.value.groups:
            groups.append(group);duration+=group.duration_ms
            for component in group.components:
                if component.has("native_constructor_inputs"):applications.append(component)
    var ground:int=0;var flashes:int=0;var trace_effects:int=0
    for group in groups:
        for event in group.events:
            for component in event.components:
                if component.kind=="native_effect":trace_effects+=1
        for component in group.components:
            if component.get("kind")=="material_flash":flashes+=1
            if component.get("native_cue",{}).get("scope")=="cast":ground+=1
    check(ground==1 and applications.size()==4 and flashes==4,"The real four-recipient cast has one ground effect, four receiver occurrences and four unchanged damage flashes")
    check(trace_effects==5,"Application trace retains actual disclosed cast identity and all five compiled effects instead of dropping inherited-source application rows as invisible")
    var seen:Dictionary={};var saved:int=0;var damage:Array=[]
    var phase:Resource=load(Effects.choice(receiver).approaches[0].source_phase)
    var original:PackedByteArray=var_to_bytes(phase.to_clip())
    for component in applications:
        var operand:Dictionary=component.native_constructor_inputs[0]
        var value:Dictionary=operand.values
        check(value.target_actor==component.target_uuid and value.target_entity_uuid==component.target_uuid and value.application_id==component.application_id,"Actual application and recipient identity survive into construction")
        check(value.save_succeeded==expected_saves[value.target_actor] and component.native_constructor_evidence.applied_damage==expected_damage[value.target_actor] and value.damage_applied,"Save and positive damage come from that exact application")
        check(not component.get("ground_target",false),"Application receiver uses actual body placement rather than the cast area origin")
        seen[value.target_actor]=true;saved+=int(value.save_succeeded);damage.append(component.native_constructor_evidence.applied_damage)
        var private_clip:Dictionary=Adapter.clip_with_inputs(phase,component.native_constructor_inputs)
        var applied:Dictionary=private_clip.components[0].input.components[0].input.application
        check(applied.target_actor==value.target_actor and applied.application_id==value.application_id and applied.start_after_release_seconds==.375,"Public construction substitutes real operands before sampling and preserves authored art/timing")
        var warm_rows:Array=Warm.recording_plan([{"component":component,"start_ms":0.0,"end_ms":component.duration_ms}])
        check(warm_rows.size()==1 and warm_rows[0].clip.construction_inputs==component.native_constructor_inputs,"A received occurrence retains real constructor operands for native warm draws")
    damage.sort()
    check(seen.size()==4 and saved==1 and damage==[15,31,31,31],"Real save branches and damage amounts remain distinct across all four actors")
    check(var_to_bytes(phase.to_clip())==original,"Shared Factory phase and embedded art settings remain immutable across recipients")
    timeline.accept({"kind":"operation","groups":groups});timeline.advance(duration+1000.0)
    check(not timeline.busy() and Compare.difference(timeline.state,journal.state).is_empty(),"Presentation drains in native order to the exact independently folded canonical state")
    finish()
func finish()->void:
    print(JSON.stringify({"checks":checks,"failures":failures,"scope":"Actual server journal, application scope/operands, private source data and canonical order; native draw/first-use timing are separate gates"}))
    quit(0 if failures.is_empty() else 1)
