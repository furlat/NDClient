extends SceneTree
## Original independent journals plus explicitly private value-contract controls.
## Web proves transport; only the actual Plant Growth burn proves that outcome.
const Support=preload("res://tests/spatial_transition_support.gd")
const Spatial=preload("res://presentation/spatial_inputs.gd")
const Persistent=preload("res://presentation/native_persistent.gd")
const Inputs=preload("res://presentation/native_inputs.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Recording=preload("res://studio/recording.gd")
const Journal=preload("res://sdk/journal.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
class Receiver extends Node3D:
    var calls:Array=[]
    func set_removed_cells(cells:Array,seconds:float)->void:calls.append([cells,seconds])
class World extends Node:
    var timeline=preload("res://presentation/timeline.gd").new()
    var visual_actors:Dictionary={}
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("SPATIAL_TRANSITION_FAIL ",label)
func run()->void:
    for seat in ["amber","blue"]:
        actual(Support.WEB,seat,false)
        actual(Support.BURN,seat,true)
    contracts()
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Actual original two-seat Web and Plant Growth native spatial transitions, immutable ordered transport, exact source-relative removed cells, visibility/suppression separation, source-owned retention and independent seek/loop. Value controls are not recorded gameplay; no native framebuffer or reactive-liquid qualification."}
    DirAccess.make_dir_recursive_absolute("res://.runtime/spatial-transitions-20261020")
    FileAccess.open("res://.runtime/spatial-transitions-20261020/input-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SPATIAL_TRANSITION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

func actual(directory:String,seat:String,plant:bool)->void:
    var cache:Dictionary=Support.source_cache() if plant else {}
    var index:Dictionary=Support.read(directory,seat,cache)
    check(index.ok,seat+" original "+directory.get_file()+" compiles")
    if not index.ok:return
    var journal:RefCounted=Journal.new();var opened:Dictionary=journal.open(directory.path_join(seat),true)
    check(opened.ok,seat+" independently folds original "+directory.get_file())
    if not opened.ok:return
    var immutable:PackedByteArray=var_to_bytes([index.initialization,index.groups])
    var rows:Array=Support.changes(index)
    for entry in index.groups:
        for requirement in entry.group.get("native_requirements",[]):
            if requirement.has("spatial_observed_removals"):
                check(requirement.spatial_observed_removals.is_empty(),seat+" early topology preparation cannot latch an operation-local retirement clock")
    var creations:Array=rows.filter(func(row):return row.row.operation=="created")
    var removals:Array=rows.filter(func(row):return not row.row.removed_positions.is_empty())
    check(not creations.is_empty() and not removals.is_empty(),seat+" real original has explicit creation and permanent removal")
    if creations.is_empty() or removals.is_empty():return
    var identity:String=creations[0].row.spatial_effect_uuid
    var actual_removals:Array=removals.filter(func(row):return row.row.spatial_effect_uuid==identity)
    check(not actual_removals.is_empty(),seat+" removal refers to the original exact owner")
    for entry in actual_removals:
        var row:Dictionary=entry.row
        check(row.event_uuid==str(entry.commit.event_uuid) and not row.lineage_uuid.is_empty(),seat+" row retains native occurrence/lineage separately")
        var raw:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(seat).path_join("%016d.json"%int(entry.sequence))))
        var originals:Array=[]
        for group in raw.get("lineages",[]):
            for node in group.events:
                if str(int(node.occurrence))==row.event_uuid:originals.append(node)
        check(originals.size()==1 and originals[0].fact.spatial_effect_uuid==identity \
            and originals[0].fact.get("operation")==row.operation \
            and Compare.difference(originals[0].fact.get("removed_positions",[]),row.removed_positions).is_empty() \
            and originals[0].fact.get("interaction_operation")==row.interaction_operation,seat+" immutable packet independently proves exact operation/interaction/cells")
        var before:RefCounted=Recording.restore(index,maxf(0.0,float(entry.at_ms)-.001))
        var after:RefCounted=Recording.restore(index,float(entry.at_ms))
        check(after.spatial_effect_owners.has(identity),seat+" ordered cut retains the pre-cut owner after final sensory removal")
        if not after.spatial_effect_owners.has(identity):continue
        var owner:Dictionary=after.spatial_effect_owners[identity]
        check(owner.spatial_observations.any(func(observed):return observed.event_uuid==row.event_uuid and observed.at_ms==entry.at_ms),seat+" actual owner receives this event at its exact published clock")
        check(not before.spatial_effect_owners.get(identity,{}).get("spatial_observations",[]).any(func(observed):return observed.event_uuid==row.event_uuid),seat+" earlier replay prefix cannot borrow a future transition")
        if row.operation=="removed":
            check(owner.physical_end_ms==entry.at_ms and not after.state.senses.spatial_effects.has(identity),seat+" mechanical end is separate from absent final sensory membership")
        if plant:
            check(row.interaction_operation=="ignite",seat+" Plant Growth removal is an actual native fire interaction")
            check(owner.spatial_removals.any(func(observed):return observed.event_uuid==row.event_uuid \
                and is_equal_approx(float(observed.source_seconds),(float(entry.at_ms)-float(owner.start_ms))/1000.0)),seat+" local removal age comes from the original application and commit")
            var samples:Array=after.component_samples(cache).filter(func(sample):return sample.get("spatial_effect_uuid")==identity)
            check(samples.size()==1 and samples[0].spatial_observed_removals==owner.spatial_removals,seat+" source receives exactly the observed owner stream")
            if samples.size()==1:routing(samples[0],seat)
            var held:RefCounted=Recording.restore(index,float(entry.at_ms)+350.0)
            var held_samples:Array=held.component_samples(cache).filter(func(sample):return sample.get("spatial_effect_uuid")==identity)
            check(held_samples.size()==1 and row.removed_positions.all(func(cell):return cell in held_samples[0].resolved_area_positions),seat+" only actual retired cells remain during the sealed0.70second dissolve")
            var ended:RefCounted=Recording.restore(index,float(entry.at_ms)+701.0)
            var ended_samples:Array=ended.component_samples(cache).filter(func(sample):return sample.get("spatial_effect_uuid")==identity)
            check(ended_samples.all(func(sample):return row.removed_positions.all(func(cell):return cell not in sample.resolved_area_positions)),seat+" source retirement leaves no removed cell after its authored interval")
        evidence.append({"seat":seat,"case":directory,"owner_uuid":identity,"sequence":entry.sequence,"event_uuid":row.event_uuid,
            "lineage_uuid":row.lineage_uuid,"operation":row.operation,"interaction_operation":row.interaction_operation,
            "removed_positions":row.removed_positions,"at_ms":entry.at_ms})
    var final:RefCounted=Recording.restore(index,index.presentation_end_ms+1000.0)
    check(Compare.difference(final.state,journal.state).is_empty(),seat+" exact canonical final state agrees with independent journal reduction")
    var looped:RefCounted=Recording.restore(index,float(actual_removals[0].at_ms))
    check(looped.spatial_effect_owners[identity].spatial_removals==Recording.restore(index,float(actual_removals[0].at_ms)).spatial_effect_owners[identity].spatial_removals,seat+" loop reconstructs the same actual private removal clock")
    check(var_to_bytes([index.initialization,index.groups])==immutable,seat+" inspection and source sampling preserve original compiled cuts")

func routing(row:Dictionary,seat:String)->void:
    for clip in Support.CLIPS:
        var receiver:Receiver=Receiver.new();root.add_child(receiver)
        var world:World=World.new();var inputs:RefCounted=Inputs.new()
        var handle:Dictionary={"clip":Effects.clip(clip),"occurrence":receiver,"root":receiver}
        var bound:Dictionary=inputs.sync(world,handle,row,{})
        check(bound.unavailable.is_empty() and "removed_cells" in bound.supplied,seat+" both compatible source clips receive the declared removal channel: "+clip)
        check(receiver.calls==row.spatial_observed_removals.map(func(observed):return [observed.cells,float(observed.source_seconds)]),seat+" original two-argument setter gets exact local cells and source age")
        inputs.sync(world,handle,row,{})
        check(receiver.calls.size()==row.spatial_observed_removals.size(),seat+" unchanged immutable removal stream is not resent per frame")
        inputs.clear();world.free();receiver.free()

func contracts()->void:
    # Explicit private value controls, not claimed original Plant Growth events.
    var journal:RefCounted=Journal.new();check(journal.open(Fixtures.journal("plant-growth"),true).ok,"Value controls use original observed Plant Growth topology")
    var effects:Dictionary=journal.state.senses.spatial_effects
    var identity:String=effects.keys()[0];var effect:Dictionary=effects[identity]
    var owners:Dictionary={};Persistent.observe_spatial(owners,effects,100.0)
    var cached:Dictionary=owners[identity].duplicate(true)
    Persistent.observe_spatial(owners,{},300.0)
    check(owners[identity].spatial_observations.is_empty() and owners[identity].spatial_removals.is_empty() and is_inf(float(owners[identity].physical_end_ms)),"Subjective loss has no fabricated mechanical removal")
    check(Spatial.presentation_cells(owners[identity],350.0,700.0).is_empty(),"A retained invisible owner cannot retain unseen cells as a removal tail")
    Persistent.observe_spatial(owners,effects,400.0)
    var node:Dictionary={"id":"private-contract","lineage_id":"private-lineage","fact":{"kind":"spatial_effect_state",
        "spatial_effect_uuid":identity,"operation":"footprint_changed","interaction_operation":"ignite",
        "positions":effect.positions.slice(1),"removed_positions":[effect.positions[0]]}}
    var original:PackedByteArray=var_to_bytes(node)
    var rows:Array=Spatial.observed_rows(node)
    var partial:Dictionary=effect.duplicate();partial.positions=effect.positions.slice(1)
    Persistent.observe_spatial(owners,{identity:partial},800.0,false,rows)
    var observed:Array=owners[identity].spatial_observations
    var local:Array=owners[identity].spatial_removals
    check(observed.size()==1 and local.size()==1 and is_equal_approx(local[0].source_seconds,.7),"One explicit removal row uses the original owner age across disclosure loss/restoration")
    check(Spatial.presentation_cells(owners[identity],1149.0,700.0)==effect.positions.slice(1)+[effect.positions[0]],"Only the exact removed cell joins current cells during source retention")
    check(Spatial.presentation_cells(owners[identity],1500.0,700.0)==partial.positions,"Exact end of the declared source interval removes the retired cell")
    Persistent.observe_spatial(owners,{identity:partial},800.0,false,rows)
    check(owners[identity].spatial_observations.size()==1,"Repeated observation of one native occurrence is idempotent")
    check(cached.spatial_observations.is_empty() and cached.source_effect==effect and var_to_bytes(node)==original,"Earlier owner snapshot, original source topology and event values remain immutable")
    var canceled:Dictionary=node.duplicate();canceled.canceled=true
    check(Spatial.observed_rows(canceled).is_empty(),"Canceled native changes cannot create observed retirement")
    var unrelated:Dictionary=node.duplicate();unrelated.fact={"kind":"actor_change"}
    check(Spatial.observed_rows(unrelated).is_empty(),"Unrelated rows never imply spatial operations")
    var history:Dictionary={};var tracked:Dictionary={}
    Recording._observe_spatial_history(history,tracked,effects,100.0,"initial",true)
    var removed:Dictionary=rows[0].duplicate();removed.operation="removed";removed.event_uuid="private-final";removed.removed_positions=effect.positions
    Recording._observe_spatial_history(history,tracked,{},1800.0,"private-final",false,[removed])
    check(tracked[identity].physical_end_ms==1800.0 and history[identity].keys.back().owner.spatial_observations.back().event_uuid=="private-final","Studio retains an actual row before final absent membership, with distinct physical clock")
    Persistent.observe_spatial(tracked,effects,1900.0)
    check(tracked[identity].physical_end_ms==1800.0 and tracked[identity].end_ms==1800.0 and not tracked[identity].observed,"Cached sensory metadata cannot reopen a physically removed UUID")
    check(Spatial.presentation_cells(tracked[identity],2500.0,700.0).is_empty(),"Cached metadata grants no cells after the exact physical removal tail")
    check(local.size()==1,"A later owner observation cannot mutate a previously returned source-input array")
