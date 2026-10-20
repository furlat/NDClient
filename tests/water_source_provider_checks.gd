extends SceneTree
## Real two-seat water after-values, independent geometry/owner controls.
## Headless source-input proof; actual native output is a separate GPU gate.
const Spatial=preload("res://presentation/spatial_inputs.gd")
const Persistent=preload("res://presentation/native_persistent.gd")
const Inputs=preload("res://presentation/native_inputs.gd")
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Timeline=preload("res://presentation/timeline.gd")
const Authoring=preload("res://presentation/authoring.gd")
const Build=preload("res://tools/presentation_build/abilities.gd")
const Records=preload("res://tools/presentation_build/ability_records.gd")
const Sources=preload("res://presentation/native_presentation_sources.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Constructed=preload("res://presentation/native_constructed_occurrence.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const ID="spatial_effect.material.water_surface"
const WATER="939c2874-27d3-4b6e-9596-195cfbc4a1ea"
const WET="dede53e7-00f4-44ab-a4b1-e9a7bbf785e3"
const CLIP="bg3-36/create-or-destroy-water/create"
const EXPECTED=[[4,7],[5,6],[5,7],[5,8],[6,5],[6,6],[6,7],[6,8],[6,9],[7,6],[7,7],[7,8],[8,7]]
class Receiver extends Node3D:
    var record_calls:int=0
    var suppression_calls:Array=[]
    func set_surface_records(_records:Array)->void:record_calls+=1
    func set_suppressed(value:bool)->void:suppression_calls.append(value)
class World extends Node:
    var timeline=Timeline.new()
    var visual_actors:Dictionary={}
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("WATER_SOURCE_FAIL ",label)
func run()->void:
    var path:String="res://authoring/abilities/conditions/"+ID+".tres"
    var source:Resource=load(path)
    var spell_path:String="res://authoring/abilities/spells/spell.create_or_destroy_water.tres"
    var spell:Resource=load(spell_path)
    var tele:Resource=load("res://authoring/abilities/spells/spell.telekinesis.tres")
    check(source.id==ID and source.effects.size()==1,"Typed actual spatial owner has one source")
    check(source.effects[0].constructor_input.cell_input=="surface_groups" and source.effects[0].constructor_input.component_path==["surface"],"Exact preconstruction interface is authored")
    check(source.effects[0].scope=="spatial" and source.effects[0].scale==1.0 and source.effects[0].orientation=="world","Disclosed cells retain their unscaled world frame")
    check(0 in spell.excluded_cues,"Finite cast does not duplicate the actual spatial source")
    check(1 in spell.excluded_cues and Array(spell.applies_conditions)==["unbound:dnd.spatial.environmental_conditions.Wet"],"Wet delegates to its exact disclosed semantic owner, no invented behavior ID")
    check(tele.effects[0].extra.authored_suppressed==false and tele.effects[0].extra.suppression_policy=="schema16_retired_antimagic","Telekinesis explicitly authors retired Antimagic false")
    var report:Dictionary={"errors":[],"warnings":[]}
    Build._check_constructor(source.effects[0],"water-source",{CLIP:Effects.clip(CLIP)},report)
    check(report.errors.is_empty(),"Existing offline spatial constructor contract accepts the source")
    var built:Dictionary=Build.documents({"conditions":{ID:source},"spells":{spell.id:spell}},
        {"conditions":{ID:path},"spells":{spell.id:spell_path}})
    for seat in ["amber","blue"]:read_seat(seat,built)
    geometry_controls()
    suppression_controls(tele)
    var output:Dictionary={"checks":checks,"failures":failures,"seats":evidence,"native_output_qualified":false,
        "wet_owner_binding":"separate_wet_semantic_owner_checks","destroy_retirement":"unqualified"}
    DirAccess.make_dir_recursive_absolute("res://.runtime/water-source-provider")
    var file:FileAccess=FileAccess.open("res://.runtime/water-source-provider/headless.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(output," ")+"\n")
    print("WATER_SOURCE_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
func source_cache(built:Dictionary)->Dictionary:
    var cache:Dictionary={}
    var recipes:Dictionary=Authoring.load_data("catalog/condition_recipes.json",cache).duplicate()
    recipes.merge(built.docs["catalog/condition_recipes.json"],true);cache["catalog/condition_recipes.json"]=recipes
    var admitted:Dictionary=Sources.admission(cache)
    var index:Resource=admitted.index.duplicate();index.spells=admitted.index.spells.duplicate()
    index.spells["spell.create_or_destroy_water"]="private actual typed water source"
    var loaded:Dictionary=admitted.loaded.duplicate();loaded["spell.create_or_destroy_water"]=built.native.records["spell.create_or_destroy_water"]
    cache[Sources.CACHE_KEY]=Sources.make_admission(index,loaded)
    return cache
func read_seat(seat:String,built:Dictionary)->void:
    var directory:String="res://tests/fixtures/schema16/water-source-provider/"+seat+"/journal"
    var journal:RefCounted=Journal.new();var opened:Dictionary=journal.open(directory,true,false)
    check(opened.ok,seat+" original journal opens")
    if not opened.ok:return
    var timeline:RefCounted=Timeline.new();var owners:Dictionary={};var cache:Dictionary=source_cache(built)
    var at:float=0.0;var seen:bool=false;var wet_seen:bool=false
    var files:PackedStringArray=DirAccess.get_files_at(directory);files.sort()
    for name in files:
        if not name.ends_with(".json") or name.get_basename().length()!=16 or not name.get_basename().is_valid_int():continue
        var sequence:int=int(name.get_basename());var bytes:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(name))
        var decoded:Dictionary=journal.decode_record(sequence,bytes);check(decoded.ok,seat+" original decode "+str(sequence))
        if not decoded.ok:return
        var before:Dictionary=journal.state
        var folded:Dictionary=journal._consume_admitted(decoded.value,bytes,true);check(folded.ok,seat+" original fold "+str(sequence))
        if not folded.ok:return
        if sequence==0:timeline.accept({"kind":"initialization","state":journal.state.duplicate(true),"sequence":0});continue
        var immutable:PackedByteArray=var_to_bytes(folded.normalized)
        var compiled:Dictionary=Compiler.compile_recorded(before,folded.normalized,cache,journal.state,folded.transitions)
        check(compiled.ok,seat+" actual compile "+str(sequence))
        if not compiled.ok:return
        timeline.accept({"kind":"operation","groups":compiled.value.groups})
        for group in compiled.value.groups:
            at+=float(group.duration_ms)
            check(not group.components.any(func(component):return component.get("native_clip",{}).get("id")==CLIP),seat+" cast owns no copied rain fixture")
        var effects:Dictionary=journal.state.senses.spatial_effects if journal.state.senses!=null else {}
        Persistent.observe_spatial(owners,effects,at)
        if effects.has(WATER):
            var effect:Dictionary=effects[WATER]
            check(effect.positions==EXPECTED and Spatial.content_id(effect)==ID,seat+" independent original13cell oracle")
            var rows:Array=Persistent.spatial_samples(owners,at+1000.0,cache)
            var water:Array=rows.filter(func(row):return row.get("spatial_effect_uuid")==WATER)
            check(water.size()==1,seat+" one actual owner produces one source")
            if water.size()==1:qualify(water[0],effect,owners,cache,seat);seen=true
        for actor in journal.state.actors.values():
            for member in actor.get("conditions",[]):
                if member.condition_uuid!=WET:continue
                wet_seen=true
                check(member.behavior_id==null and member.state.semantic_key=="unbound:dnd.spatial.environmental_conditions.Wet",seat+" actual Wet UUID has explicit null behavior and semantic key")
        check(var_to_bytes(folded.normalized)==immutable,seat+" original packet remains unchanged")
    check(seen and wet_seen,seat+" actual surface and distinct Wet owner were both disclosed")
    timeline.advance(at+1000.0)
    check(not timeline.busy() and Compare.difference(timeline.state,journal.state).is_empty(),seat+" original canonical ordering/drain remains exact")
func qualify(row:Dictionary,effect:Dictionary,owners:Dictionary,cache:Dictionary,seat:String)->void:
    check(row.get("status","available")=="available" and row.native_clip.id==CLIP,seat+" typed source is selected")
    check(row.actor_uuid==null and row.target_uuid==null and row.native_constructor_evidence.spatial_effect_uuid==WATER,seat+" spatial owner invents no actor identity")
    check(is_inf(float(row.duration_ms)) and row.resolved_area_positions==EXPECTED,seat+" no fabricated surface expiry or cells")
    check(not row.spatial_creation_observed and row.age_ms==4500.0,seat+" original sensory admission cannot fabricate rainfall creation")
    var phase:Resource=load(Effects.choice(row.native_clip).approaches[0].source_phase)
    var original:Dictionary=phase.to_clip();var private_clip:Dictionary=Constructed.clip_with_inputs(phase,row.native_constructor_inputs)
    var input:Dictionary=private_clip.components[0].input
    check(input.surface_groups==row.spatial_surface_records,"Actual preconstruction records are the declared readiness operand")
    check(input.surface_groups.size()==1 and input.surface_groups[0].source_uuid==WATER,"Only actual water UUID replaces review owner")
    var group:Dictionary=input.surface_groups[0]
    check(group.cells==EXPECTED.map(func(point):return [point[0]-row.position[0],point[1]-row.position[1]]),"Constructor preserves exact translated original cells")
    check(group.points.size()==160,"Retains original source160point density")
    check(group.points.all(func(point):return [int(floor(float(point[0])+0.5)),int(floor(float(point[1])+0.5))] in group.cells),"Every optical point lies in a disclosed cell")
    for key in original.components[0].input:
        if key=="surface_groups":continue
        check(input[key]==original.components[0].input[key],seat+" sealed source art unchanged "+str(key))
    check(phase.to_clip()==original,seat+" original Factory Resource unchanged")
    var first:Array=row.native_constructor_inputs
    var later:Array=Persistent.spatial_samples(owners,float(row.absolute_start_ms)+9000.0,cache)
    check(later.size()==1 and is_same(later[0].native_constructor_inputs,first),seat+" immutable coverage is reused beyond finite rain without rebuilding or expiring surface")
    var changed:Dictionary=effect.duplicate(true);changed.suppressions=[{"positions":[EXPECTED[0]]}]
    Persistent.observe_spatial(owners,{WATER:changed},float(row.absolute_start_ms)+500.0)
    var masked:Array=Persistent.spatial_samples(owners,float(row.absolute_start_ms)+1100.0,cache)
    check(masked.size()==1 and masked[0].resolved_area_positions.size()==12 and is_same(masked[0].native_constructor_inputs,first),seat+" suppression changes AreaMask admission without reconstructing coverage")
    Persistent.observe_spatial(owners,{WATER:effect},float(row.absolute_start_ms)+1200.0)
    var restored:Array=Persistent.spatial_samples(owners,float(row.absolute_start_ms)+1300.0,cache)
    check(restored.size()==1 and restored[0].resolved_area_positions==EXPECTED and is_same(restored[0].native_constructor_inputs,first),seat+" suppression recovery restores exact cells and source owner")
    var extension:Dictionary=effect.duplicate(true);extension.positions=effect.positions+[[99,99]]
    Persistent.observe_spatial(owners,{WATER:extension},float(row.absolute_start_ms)+1400.0)
    var extended:Array=Persistent.spatial_samples(owners,float(row.absolute_start_ms)+1500.0,cache)
    check(extended.size()==1 and extended[0].get("reason")=="spatial_source_topology_extension_not_bound",seat+" synthetic topology extension is explicit, not silently dropped")
    Persistent.observe_spatial(owners,{WATER:effect},float(row.absolute_start_ms)+1600.0)
    var initial:Dictionary={};Persistent.observe_spatial(initial,{WATER:effect},0.0,true)
    var initial_rows:Array=Persistent.spatial_samples(initial,0.0,cache)
    check(initial_rows.size()==1 and initial_rows[0].age_ms==3500.0 and initial_rows[0].start_ms==0.0,seat+" already-present owner skips birth rain without changing authoritative start")
    var late:Dictionary={};Persistent.observe_spatial(late,{WATER:effect},65000.0)
    var disclosed:Array=Persistent.spatial_samples(late,65000.0,cache)
    check(disclosed.size()==1 and not disclosed[0].spatial_creation_observed and disclosed[0].age_ms==3500.0,seat+" late first disclosure is held water, not a new rain action")
    Persistent.observe_spatial(late,{},65500.0)
    check(Persistent.spatial_samples(late,65500.0,cache).is_empty(),seat+" actual sensory loss releases the private source")
    Persistent.observe_spatial(late,{WATER:effect},66000.0)
    var readmitted:Array=Persistent.spatial_samples(late,66000.0,cache)
    check(readmitted.size()==1 and not readmitted[0].spatial_creation_observed and readmitted[0].age_ms==3500.0,seat+" remembered owner readmission cannot replay rainfall")
    # Synthetic owner controls only: the original above has no created row.
    var native_birth:Dictionary={"spatial_effect_uuid":WATER,"event_uuid":"synthetic-native-created-control","lineage_uuid":"synthetic-native-lineage", "operation":"created","interaction_operation":null,"positions":EXPECTED,"removed_positions":[]}
    var created:Dictionary={};Persistent.observe_spatial(created,{WATER:effect},1000.0,false,[native_birth])
    var birth:Array=Persistent.spatial_samples(created,1100.0,cache)
    check(birth.size()==1 and birth[0].spatial_creation_observed and birth[0].age_ms==100.0,seat+" explicitly synthetic native-created control opens source birth at that exact cut")
    var partial:Dictionary=effect.duplicate(true);partial.positions=EXPECTED.slice(1)
    var removed:Dictionary=native_birth.duplicate(true);removed.event_uuid="synthetic-partial-removal-control";removed.operation="updated";removed.positions=partial.positions;removed.removed_positions=[EXPECTED[0]]
    Persistent.observe_spatial(created,{WATER:partial},1500.0,false,[removed])
    var partial_rows:Array=Persistent.spatial_samples(created,1600.0,cache)
    check(partial_rows.size()==1 and partial_rows[0].resolved_area_positions==EXPECTED.slice(1) and is_same(partial_rows[0].native_constructor_inputs,birth[0].native_constructor_inputs),seat+" synthetic permanent partial removal retains immutable source and masks exact retired cell")
    var receiver:Receiver=Receiver.new();var world:World=World.new();var adapter:RefCounted=Inputs.new()
    var handle:Dictionary={"clip":{"inputs":["surface_records"]},"root":receiver,"occurrence":receiver}
    var bound:Dictionary=adapter.sync(world,handle,row,{})
    check(bound.unavailable.is_empty() and bound.supplied==["surface_records"] and receiver.record_calls==0,seat+" immutable setter is supplied before make, never illegally resent after preparation")
    var missing:Dictionary=row.duplicate();missing.erase("spatial_surface_records")
    check(adapter.sync(world,handle,missing,{}).unavailable.surface_records=="surface_immutable_coverage_not_bound",seat+" missing constructor records stay unavailable")
    adapter.clear();receiver.free();world.free()
    evidence.append({"seat":seat,"spatial_uuid":WATER,"cells":EXPECTED,"points":160,"wet_uuid":WET})
func geometry_controls()->void:
    var positions:Array=[]
    for x in 70:positions.append([x,0])
    var groups:Array=Spatial.surface_groups("synthetic-optical-control",positions,[0,0])
    check(groups.size()==3 and groups.map(func(group):return group.cells.size())==[32,32,6],"Independent70cell control respects exact source group capacity")
    check(groups.all(func(group):return group.source_uuid=="synthetic-optical-control" and group.points.size()==160),"Partition retains a single owner with source density per group")
    check(groups==Spatial.surface_groups("synthetic-optical-control",positions,[0,0]),"Optical coverage is deterministic")
    check(groups.map(func(group):return group.cells).reduce(func(all,cells):return all+cells,[])==positions,"Partition neither fills gaps nor drops cells")
func suppression_controls(tele:Resource)->void:
    var receiver:Receiver=Receiver.new();var world:World=World.new();var adapter:RefCounted=Inputs.new()
    var cue:Dictionary=Records.cue_from_effect(tele.effects[0],0)
    var component:Dictionary={"actor_uuid":null,"native_cue":cue}
    var handle:Dictionary={"clip":{"inputs":["suppressed"],"input_setters":{"suppressed":"set_suppressed"}},"root":receiver,"occurrence":receiver}
    var result:Dictionary=adapter.sync(world,handle,component,{})
    check(result.unavailable.is_empty() and "suppressed" in result.supplied and receiver.suppression_calls==[false],"Authored Telekinesis policy supplies literalfalse")
    adapter.sync(world,handle,component,{})
    check(receiver.suppression_calls==[false],"Unchanged literal is not republished each sample")
    var absent:Dictionary={"actor_uuid":null,"native_cue":{}}
    check(adapter.sync(world,handle,absent,{}).unavailable.suppressed=="provider_not_bound", "Unrelated source receives no global suppression default")
    adapter.clear();receiver.free();world.free()
