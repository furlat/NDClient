extends SceneTree
## Unchanged two-seat DRY originals plus explicitly labelled projection
## controls. Partial retirement controls are not recorded partial outcomes.
const Recording=preload("res://studio/recording.gd")
const Journal=preload("res://sdk/journal.gd")
const Persistent=preload("res://presentation/native_persistent.gd")
const Records=preload("res://tools/presentation_build/ability_records.gd")
const Constructed=preload("res://presentation/native_constructed_occurrence.gd")
const Playback=preload("res://presentation/native_spell_playback.gd")
const Effects=preload("res://presentation/effect_package.gd")
const ROOT="res://tests/fixtures/schema16/scenarios/water-create-dry"
const OWNER="275a5049-1eb3-4e5a-99da-9804772ab69b"
const CLIP="bg3-36/create-or-destroy-water/destroy"
const ID="spatial_effect.material.water_surface"
const CELLS=[[4,7],[5,6],[5,7],[5,8],[6,5],[6,6],[6,7],[6,8],[6,9],[7,6],[7,7],[7,8],[8,7]]
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("WATER_DRY_PROVIDER_FAIL ",label)
func run()->void:
    var source:Resource=load("res://authoring/abilities/conditions/"+ID+".tres")
    var use:Resource=source.effects[1]
    var emitted:Dictionary=Records.cue_from_effect(use,1)
    var restored:Resource=Records.effect_from_cue(emitted,"private-roundtrip")
    check(is_equal_approx(emitted.source_start,.733333333333333) and restored.source_start==use.source_start,"Existing typed source_start survives cue emit/read round-trip")
    check(emitted.spatial_removal_when=={"interaction_operation":"dry"} and use.at=="spatial_removal","Only an explicitly authored actual DRY transition selects this finite source")
    var clip:Dictionary=Effects.clip(CLIP)
    var phase:Resource=load(Effects.choice(clip).approaches[0].source_phase)
    var sealed:PackedByteArray=var_to_bytes(phase.to_clip())
    check(phase.to_clip().components[0].input.form=="destroy" and is_equal_approx(phase.to_clip().components[0].input.clear_at_seconds,use.source_start),"The supplied source's actual clear clock is authored unchanged")
    for seat in ["amber","blue"]:original(seat,phase)
    check(var_to_bytes(phase.to_clip())==sealed,"All original projections leave the sealed Factory phase unchanged")
    print("WATER_DRY_PROVIDERS ",JSON.stringify({"checks":checks,"failures":failures,"scope":"Genuine whole-owner13cell DRY both seats, exact source subset/cause/clock and canonical seek/loop. Partial/no-DRY controls are labelled unit projections, not original outcome/native-output/creation/visual approval claims."}))
    quit(0 if failures.is_empty() else 1)
func changes(index:Dictionary)->Array:
    var result:Array=[]
    for item in index.groups:
        for commit in item.group.commits:
            for row in commit.get("spatial_rows",[]):result.append({"row":row,"at_ms":float(item.start_ms)+float(commit.at_ms),"sequence":item.group.operation_sequence})
    return result
func dry_samples(timeline:RefCounted,cache:Dictionary)->Array:
    return timeline.component_samples(cache).filter(func(sample):return sample.get("spatial_removal",false) and sample.get("spatial_effect_uuid")==OWNER)
func original(seat:String,phase:Resource)->void:
    var directory:String=ROOT.path_join(seat)
    var expected:RefCounted=Journal.new();var opened:Dictionary=expected.open(directory,true,true)
    var index:Dictionary=Recording.read(directory)
    check(opened.ok and index.ok,seat+": independent actual journal and current Studio open")
    if not opened.ok or not index.ok:return
    var immutable:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
    var dry:Array=changes(index).filter(func(entry):return entry.row.interaction_operation=="dry" and entry.row.spatial_effect_uuid==OWNER)
    check(dry.size()==1,seat+": exactly one actual native DRY occurrence")
    if dry.size()!=1:return
    var entry:Dictionary=dry[0]
    check(entry.sequence==9 and entry.row.operation=="removed" and entry.row.removed_positions==CELLS,seat+": independent13cell whole-owner native removal oracle")
    # The original version_rows place this event in99/103.87/91 are the
    # enclosing group roots, not the native event's own lineage.
    check(entry.row.event_uuid==("102" if seat=="amber" else "106") and entry.row.lineage_uuid==("99" if seat=="amber" else "103"),seat+": source cause retains this seat's own native occurrence and lineage")
    var before:RefCounted=Recording.restore(index,entry.at_ms-.01)
    check(before.state.senses.spatial_effects.has(OWNER) and dry_samples(before,index.cache).is_empty(),seat+": existing water cannot predict a future DRY source")
    var at:float=entry.at_ms+350.0
    var during:RefCounted=Recording.restore(index,at)
    var samples:Array=dry_samples(during,index.cache)
    check(samples.size()==1 and not during.state.senses.spatial_effects.has(OWNER),seat+": actual mechanical retirement and one finite optical tail are distinct")
    if samples.size()!=1:return
    var sample:Dictionary=samples[0]
    check(sample.actor_uuid==null and sample.target_uuid==null and sample.resolved_area_positions==CELLS and sample.spatial_effect_uuid==OWNER,seat+": exact removed cells/owner, no fabricated actor or remaining coverage")
    check(sample.source_event_uuid==entry.row.event_uuid and sample.native_constructor_evidence.lineage_uuid==entry.row.lineage_uuid and sample.start_ms==entry.at_ms and is_equal_approx(sample.duration_ms,1200.0),seat+": finite source belongs to actual native cause and cut")
    check(is_equal_approx(Playback.source_time(sample.native_cue,0.0),.733333333333333) and is_equal_approx(Playback.source_time(sample.native_cue,.35),1.083333333333333),seat+": source starts at its supplied clear clock with no pre-cut prediction")
    var private:Dictionary=Constructed.clip_with_inputs(phase,sample.native_constructor_inputs)
    var original_input:Dictionary=phase.to_clip().components[0].input
    var input:Dictionary=private.components[0].input
    check(input.surface_groups==sample.spatial_surface_records and input.surface_groups.all(func(group):return group.source_uuid==OWNER),seat+": every fixture owner/group is replaced before construction")
    var mapped:Array=[]
    for group in input.surface_groups:
        for cell in group.cells:mapped.append([cell[0]+sample.position[0],cell[1]+sample.position[1]])
    check(mapped==CELLS and input.surface_groups[0].points.size()==160,seat+": unchanged source density samples only the exact retired cells")
    for key in original_input:
        if key!="surface_groups":check(input[key]==original_input[key],seat+": sealed source art/clock setting unchanged "+str(key))
    var rows:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("spatial_removal",false))
    check(not rows.is_empty() and rows.all(func(row):return row.component.spatial_effect_uuid==OWNER and row.label.begins_with("Removal") and row.source_start_ms==entry.at_ms and row.end_ms<=entry.at_ms+1200.00001 and row.source_event_uuid==entry.row.event_uuid),seat+": Studio exposes finite actual removal spans/cause")
    private_controls(before.spatial_effect_owners[OWNER],entry,index.cache,seat)
    var after:RefCounted=Recording.restore(index,entry.at_ms+1201.0)
    check(dry_samples(after,index.cache).is_empty(),seat+": exact finite tail ends without resurrecting water")
    var looped:RefCounted=Recording.restore(index,at)
    check(dry_samples(looped,index.cache).size()==1 and dry_samples(looped,index.cache)[0].id==sample.id,seat+": loop retains actual event identity without future source residue")
    var final:RefCounted=Recording.restore(index,index.presentation_end_ms+2000.0)
    check(final.state==expected.state,seat+": final canonical endpoint equals its independent original reducer")
    check(var_to_bytes([index.initialization,index.groups,index.rows])==immutable,seat+": source preparation/controls never modify original facts")
func private_controls(original:Dictionary,entry:Dictionary,cache:Dictionary,seat:String)->void:
    var hidden:Dictionary=original.duplicate(true);var hidden_owners:Dictionary={OWNER:hidden}
    Persistent.observe_spatial(hidden_owners,{},entry.at_ms,false)
    check(not Persistent.spatial_samples(hidden_owners,entry.at_ms+200.0,cache).any(func(sample):return sample.get("spatial_removal",false)),seat+": labelled sight-loss control cannot invent DRY")
    var owner:Dictionary=original.duplicate(true);var owners:Dictionary={OWNER:owner}
    var partial:Dictionary=entry.row.duplicate();partial.operation="footprint_changed";partial.removed_positions=CELLS.slice(0,5)
    var current:Dictionary=owner.effect.duplicate();current.positions=CELLS.slice(5)
    Persistent.observe_spatial(owners,{OWNER:current},entry.at_ms,false,[partial])
    var samples:Array=Persistent.spatial_samples(owners,entry.at_ms+200.0,cache)
    var tails:Array=samples.filter(func(sample):return sample.get("spatial_removal",false))
    var held:Array=samples.filter(func(sample):return not sample.get("spatial_removal",false))
    check(tails.size()==1 and held.size()==1 and tails[0].resolved_area_positions==CELLS.slice(0,5) and held[0].resolved_area_positions==CELLS.slice(5),seat+": labelled partial control leaves still-live cells under the original hold only")
    Persistent.observe_spatial(owners,{OWNER:current},entry.at_ms,false,[partial])
    check(Persistent.spatial_samples(owners,entry.at_ms+201.0,cache).filter(func(sample):return sample.get("spatial_removal",false)).size()==1,seat+": duplicate actual-row publication cannot duplicate finite contact")
    var late:Array=Persistent.spatial_samples(owners,entry.at_ms+1201.0,cache)
    check(late.size()==1 and late[0].resolved_area_positions==CELLS.slice(5) and owner.native_removal_sources[1].active.is_empty(),seat+": finite control ends/releases active cache without clearing the surviving owner")
