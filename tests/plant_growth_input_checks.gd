extends SceneTree
## Actual two-seat cells drive source construction. No burn outcome is invented.
const Spatial=preload("res://presentation/spatial_inputs.gd")
const Persistent=preload("res://presentation/native_persistent.gd")
const Inputs=preload("res://presentation/native_inputs.gd")
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Timeline=preload("res://presentation/timeline.gd")
const Authoring=preload("res://presentation/authoring.gd")
const Build=preload("res://tools/presentation_build/abilities.gd")
const Sources=preload("res://presentation/native_presentation_sources.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Constructed=preload("res://presentation/native_constructed_occurrence.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const ID="spatial_effect.spell.plant_growth"
const CLIP="bg3-36/plant-growth/plant_growth_native"
class RemovalReceiver extends Node3D:
    var calls:Array=[]
    func set_removed_cells(cells:Array,seconds:float)->void:calls.append([cells,seconds])
class World extends Node:
    var timeline=Timeline.new()
    var visual_actors:Dictionary={}
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("PLANT_GROWTH_INPUT_FAIL ",label)
func run()->void:
    var path:String="res://authoring/abilities/conditions/"+ID+".tres"
    var entry:Resource=load(path)
    var spell_path:String="res://authoring/abilities/spells/spell.plant_growth.tres"
    var spell:Resource=load(spell_path)
    check(entry.id==ID and entry.effects.size()==1,"One typed spatial source owns the actual field")
    check(entry.effects[0].constructor_input.cell_input=="cells" and entry.effects[0].scope=="spatial","Declared constructed topology uses existing spatial-owner provider")
    check(entry.status=="partial","Binding is not user art approval or full removal qualification")
    var clip:Dictionary=Effects.clip(CLIP)
    check(clip.inputs==["removed_cells"],"The original sealed source declares its exact timed removal input")
    var report:Dictionary={"errors":[],"warnings":[]}
    Build._check_constructor(entry.effects[0],"plant-growth",{CLIP:clip},report)
    check(report.errors.is_empty(),"Source-cell contract is validated offline")
    check(0 in spell.excluded_cues and spell.owner_cues.is_empty(),"The old default spell probe cannot duplicate the actual spatial owner")
    var built:Dictionary=Build.documents({"conditions":{ID:entry},"spells":{spell.id:spell}},
        {"conditions":{ID:path},"spells":{spell.id:spell_path}})
    for seat in ["amber","blue"]:read_seat(seat,built)
    var occurrence:Node3D=Constructed.new()
    var receiver:RemovalReceiver=RemovalReceiver.new();occurrence.add_child(receiver)
    occurrence.handle={"root":receiver};occurrence.input_receivers={"set_removed_cells":[receiver]};occurrence.inputs_dirty=false
    occurrence.forward_arguments("set_removed_cells",[[[1,2]],.375])
    check(receiver.calls==[[[[1,2]],.375]],"Existing prepared receiver map forwards both authored setter arguments unchanged")
    occurrence.free()
    finish()
func source_cache(built:Dictionary)->Dictionary:
    var cache:Dictionary={}
    var recipes:Dictionary=Authoring.load_data("catalog/condition_recipes.json",cache).duplicate()
    recipes.merge(built.docs["catalog/condition_recipes.json"],true);cache["catalog/condition_recipes.json"]=recipes
    var admitted:Dictionary=Sources.admission(cache)
    var index:Resource=admitted.index.duplicate();index.spells=admitted.index.spells.duplicate()
    index.spells["spell.plant_growth"]="actual typed Plant Growth source"
    var loaded:Dictionary=admitted.loaded.duplicate();loaded["spell.plant_growth"]=built.native.records["spell.plant_growth"]
    cache[Sources.CACHE_KEY]=Sources.make_admission(index,loaded)
    return cache
func read_seat(seat:String,built:Dictionary)->void:
    var directory:String=Fixtures.journal("plant-growth",seat)
    var journal:RefCounted=Journal.new();var opened:Dictionary=journal.open(directory,true,false)
    check(opened.ok,seat+" opens unchanged current-schema journal")
    if not opened.ok:return
    var cache:Dictionary=source_cache(built)
    var timeline:RefCounted=Timeline.new();var owners:Dictionary={};var at:float=0.0;var seen:Dictionary={}
    var files:PackedStringArray=DirAccess.get_files_at(directory);files.sort()
    for file in files:
        if not file.ends_with(".json") or file.get_basename().length()!=16 or not file.get_basename().is_valid_int():continue
        var sequence:int=int(file.get_basename());var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(file))
        var decoded:Dictionary=journal.decode_record(sequence,raw);check(decoded.ok,seat+" decode "+str(sequence))
        if not decoded.ok:return
        var before:Dictionary=journal.state
        var folded:Dictionary=journal._consume_admitted(decoded.value,raw,true);check(folded.ok,seat+" reduce "+str(sequence))
        if not folded.ok:return
        if sequence==0:timeline.accept({"kind":"initialization","state":journal.state.duplicate(true),"sequence":0});continue
        var original:PackedByteArray=var_to_bytes(folded.normalized)
        var compiled:Dictionary=Compiler.compile_recorded(before,folded.normalized,cache,journal.state,folded.transitions)
        check(compiled.ok,seat+" compile "+str(sequence))
        if not compiled.ok:return
        timeline.accept({"kind":"operation","groups":compiled.value.groups})
        for group in compiled.value.groups:
            at+=float(group.duration_ms)
            check(not group.components.any(func(component):return component.get("native_clip",{}).get("id")==CLIP),seat+" cast does not own a second vegetation fixture")
        var effects:Dictionary=journal.state.senses.spatial_effects if journal.state.senses!=null else {}
        Persistent.observe_spatial(owners,effects,at)
        for row in Persistent.spatial_samples(owners,at+1000.0,cache):
            if row.get("spatial_content_id")!=ID:continue
            seen[row.spatial_effect_uuid]=true;qualify(row,effects[row.spatial_effect_uuid],owners,cache,seat)
        check(var_to_bytes(folded.normalized)==original,seat+" original packet remains immutable")
    check(seen.size()==1,seat+" one actual UUID owns one 49-cell source")
    var facts:Array=Fixtures.fact_rows("plant-growth","spatial_effect_state",seat)
    check(facts.size()==1 and facts[0].fact.operation=="created" and facts[0].fact.positions.size()==49,seat+" independent original fact proves 49 cells and no removal")
    timeline.advance(at+1000.0)
    check(not timeline.busy() and Compare.difference(timeline.state,journal.state).is_empty(),seat+" source preparation preserves exact authoritative ordering")
func qualify(row:Dictionary,effect:Dictionary,owners:Dictionary,cache:Dictionary,seat:String)->void:
    check(row.get("status","available")=="available" and row.native_clip.id==CLIP,seat+" source binding is available")
    check(row.actor_uuid==null and row.target_uuid==null and row.native_constructor_evidence.spatial_effect_uuid==row.spatial_effect_uuid,seat+" spatial owner retains its real UUID and invents no actor identity")
    check(row.resolved_area_positions==effect.positions and effect.positions.size()==49 and is_inf(float(row.duration_ms)),seat+" exact disclosed footprint and lifetime retained")
    var phase:Resource=load(Effects.choice(row.native_clip).approaches[0].source_phase)
    var original:Dictionary=phase.to_clip();var private_clip:Dictionary=Constructed.clip_with_inputs(phase,row.native_constructor_inputs)
    var input:Dictionary=private_clip.components[0].input
    var expected:Array=effect.positions.map(func(point):return [point[0]-row.position[0],point[1]-row.position[1]])
    check(input.cells==expected and input.observed_removals.is_empty(),seat+" constructor receives actual translated cells and no review burn")
    for key in original.components[0].input:
        if key in ["cells","observed_removals"]:continue
        check(input[key]==original.components[0].input[key],seat+" original sealed art setting unchanged: "+str(key))
    check(phase.to_clip()==original,seat+" immutable Factory phase untouched")
    var receiver:RemovalReceiver=RemovalReceiver.new();root.add_child(receiver)
    var world:World=World.new();var adapter:RefCounted=Inputs.new()
    var handle:Dictionary={"clip":row.native_clip,"root":receiver,"occurrence":receiver}
    var result:Dictionary=adapter.sync(world,handle,row,{})
    check(result.unavailable.is_empty() and "removed_cells" in result.supplied,seat+" timed removal channel is supplied from observed owner input")
    check(receiver.calls==[[[],float(row.age_ms)/1000.0]],seat+" no observed burn forwards an empty list at actual source age")
    adapter.sync(world,handle,row,{})
    check(receiver.calls.size()==1,seat+" unchanged empty observation is not republished each frame")
    var unknown:Dictionary=row.duplicate();unknown.erase("spatial_observed_removals")
    check(adapter.sync(world,handle,unknown,{}).unavailable.removed_cells=="spatial_retirement_observations_not_bound",seat+" unrelated sources cannot claim a missing retirement stream")
    adapter.clear();receiver.free();world.free()
    var owner:Dictionary=owners[row.spatial_effect_uuid]
    var initial:PackedByteArray=var_to_bytes(owner.source_effect)
    var suppressed:Dictionary=effect.duplicate(true);suppressed.suppressions=[{"positions":[effect.positions[0]]}]
    Persistent.observe_spatial(owners,{row.spatial_effect_uuid:suppressed},float(row.start_ms)+500.0)
    var next:Dictionary=Persistent.spatial_samples(owners,float(row.start_ms)+1000.0,cache)[0]
    check(next.resolved_area_positions.size()==48 and next.native_constructor_inputs==row.native_constructor_inputs and next.position==row.position,seat+" suppression changes only admission, not constructed topology/origin")
    check(next.spatial_observed_removals.is_empty(),seat+" temporary suppression does not fabricate irreversible burning")
    Persistent.observe_spatial(owners,{row.spatial_effect_uuid:effect},float(row.start_ms)+1500.0)
    check(Persistent.spatial_samples(owners,float(row.start_ms)+2000.0,cache)[0].resolved_area_positions==effect.positions,seat+" restoring visibility restores the actual cells")
    var larger:Dictionary=effect.duplicate(true);larger.positions.append([100,100])
    var missing:Dictionary=Spatial.construction(str(row.spatial_effect_uuid),larger,row.native_cue,owner.source_effect)
    check(not missing.ready and missing.reason=="spatial_source_topology_extension_not_bound",seat+" unconstructed future topology remains an explicit source gap")
    check(var_to_bytes(owner.source_effect)==initial,seat+" first source topology remains immutable")
    evidence.append({"seat":seat,"owner_uuid":row.spatial_effect_uuid,"cells":effect.positions,"constructor_cells":input.cells,"observed_removals":[]})
func finish()->void:
    var result:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual original two-seat 49-cell admission, source contract, one owner, independent topology/clock, no burn or visual acceptance claim"}
    print("PLANT_GROWTH_INPUT ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
