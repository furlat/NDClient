extends SceneTree
## Independent real surface disclosure/ordering plus public setter routing.
## No native drawing or removal/suppression gameplay scenario is fabricated.
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
const Records=preload("res://tools/presentation_build/ability_records.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const OWNER_CLIPS={
    "spatial_effect.spell.acid_surface":"bg3-36/chromatic-orb/acid/observed-surface",
    "spatial_effect.material.ice":"high-level-22/freezing-sphere/launch_observed_ice",
    "spatial_effect.material.fire":"bg3-36/chromatic-orb/fire/observed-surface",
    "spatial_effect.material.electrified_water":"bg3-36/chromatic-orb/lightning/observed-surface",
    "spatial_effect.spell.simple_toxin":"bg3-36/chromatic-orb/poison/observed-surface"}
class SurfaceReceiver extends Node3D:
    var owner_state:Dictionary={}
    var owner_calls:int=0
    var targets:Array=[]
    var partition:Dictionary={}
    func set_owner_state(value:Dictionary)->void:owner_state=value;owner_calls+=1
    func set_targets(value:Array)->void:targets=value
    func set_surface_partition(value:Dictionary)->void:partition=value
class World extends Node:
    var timeline=Timeline.new()
    var visual_actors:Dictionary={}
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("SPATIAL_INPUT_FAIL "+label)

func run()->void:
    for identity in OWNER_CLIPS:
        var path:String="res://authoring/environment/surfaces/"+identity+".tres"
        var entry:Resource=load(path)
        check(entry!=null and entry.id==identity and entry.lasting!=null and entry.native_staging,identity+" has its canonical typed spatial source")
        if entry==null or entry.lasting==null:finish();return
        var cue:Dictionary=Records.cue_from_effect(entry.lasting,0)
        var clip:Dictionary=Effects.for_cue(cue,identity,"attached")
        var channels:Array=["surface_partition","owner_state","targets"]
        check(entry.lasting.clip==OWNER_CLIPS[identity] and clip.inputs.size()==channels.size() and channels.all(func(channel):return channel in clip.inputs),identity+" binds its delivered current-owner partition interface")
        var report:Dictionary={"errors":[],"warnings":[]}
        Build._check_constructor(entry.lasting,"ground/"+identity,{entry.lasting.clip:clip},report)
        check(report.errors.is_empty(),identity+" actual production constructor passes offline admission")
        check(not cue.area_mask and cue.constructor_input.cell_input=="partitioned_surface",identity+" native full-owner topology owns its footprint without a second flat mask")
        check(entry.status=="partial",identity+" source presence does not claim native visual approval")
    var orb:Resource=load("res://authoring/abilities/spells/spell.chromatic_orb.tres")
    check(orb.effects.all(func(use):return not use.clip.ends_with("/observed-surface")),"Default cast no longer owns surface review topology")
    check(orb.variants.all(func(variant):return variant.effects.all(func(use):return not use.clip.ends_with("/observed-surface"))),"All Orb element/outcome variants hand over surface ownership")
    var built:Dictionary={}
    var directory:String="res://tests/fixtures/schema16/scenarios/chromatic-orb"
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--recording="):directory=argument.trim_prefix("--recording=")
    var seats:int=0;var total:int=0
    for seat in ["amber","blue"]:
        var path:String=directory.path_join(seat)
        if DirAccess.dir_exists_absolute(path.path_join("journal")):path=path.path_join("journal")
        check(DirAccess.dir_exists_absolute(path),seat+" original journal exists")
        if not DirAccess.dir_exists_absolute(path):continue
        seats+=1;total+=read_seat(path,seat,built)
    check(seats==2 and total==2,"Both actual seats independently own their disclosed Acid surface")
    finish()

func source_cache(_built:Dictionary)->Dictionary:
    return {}

func read_seat(directory:String,seat:String,built:Dictionary)->int:
    var journal:RefCounted=Journal.new()
    var opened:Dictionary=journal.open(directory,true,false)
    check(opened.ok,seat+" opens the current schema")
    if not opened.ok:return 0
    var cache:Dictionary=source_cache(built)
    var timeline:RefCounted=Timeline.new()
    var owners:Dictionary={};var duration:float=0.0;var final_rows:Array=[]
    var files:PackedStringArray=DirAccess.get_files_at(directory);files.sort()
    var recorded_owners:Dictionary={}
    for filename in files:
        if not filename.ends_with(".json") or filename.get_basename().length()!=16 or not filename.get_basename().is_valid_int():continue
        var sequence:int=int(filename.get_basename())
        var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(filename))
        var decoded:Dictionary=journal.decode_record(sequence,raw)
        check(decoded.ok,seat+" decode "+str(sequence))
        if not decoded.ok:return 0
        var before:Dictionary=journal.state
        var folded:Dictionary=journal._consume_admitted(decoded.value,raw,true)
        check(folded.ok,seat+" reduce "+str(sequence))
        if not folded.ok:return 0
        if sequence==0:
            timeline.accept({"kind":"initialization","state":journal.state.duplicate(true),"sequence":0});continue
        var untouched:PackedByteArray=var_to_bytes(folded.normalized)
        var compiled:Dictionary=Compiler.compile_recorded(before,folded.normalized,cache,journal.state,folded.transitions)
        check(compiled.ok,seat+" compile "+str(sequence))
        if not compiled.ok:return 0
        timeline.accept({"kind":"operation","groups":compiled.value.groups})
        for group in compiled.value.groups:
            duration+=float(group.duration_ms)
            check(not group.components.any(func(component):return component.get("native_clip",{}).get("id","").ends_with("/observed-surface")),seat+" finite cast does not duplicate the spatial owner's surface")
            for requirement in group.get("native_requirements",[]):
                if requirement.get("spatial_owner",false) and requirement.has("native_constructor_inputs"):
                    check(requirement.native_constructor_evidence.spatial_effect_uuid==requirement.spatial_effect_uuid,seat+" compiler prepares the actual owner, not a cast-only fixture")
        var effects:Dictionary=journal.state.senses.spatial_effects if journal.state.senses!=null else {}
        Persistent.observe_spatial(owners,effects,duration,false,[],journal.state.tiles)
        final_rows=Persistent.spatial_samples(owners,duration,cache)
        for row in final_rows:
            if not OWNER_CLIPS.has(row.get("spatial_content_id","")):continue
            recorded_owners[row.spatial_effect_uuid]=true
            var effect:Dictionary=effects[row.spatial_effect_uuid]
            check(row.native_clip.id==OWNER_CLIPS[Spatial.content_id(effect)] and row.spatial_content_id==Spatial.content_id(effect),seat+" exact content selects its own supplied material")
            check(row.actor_uuid==null and row.target_uuid==null and not row.has("condition") and row.ground_target,seat+" an independent spatial owner needs no invented caster or condition fact")
            check(row.resolved_area_positions==effect.positions and is_inf(float(row.duration_ms)),seat+" actual disclosed cells own membership with no guessed expiry")
            constructor(row,seat)
            routing(row,journal.state,seat)
            boundaries(row,effect,journal.state,cache,seat)
        check(var_to_bytes(folded.normalized)==untouched,seat+" native preparation leaves original packet unchanged")
    timeline.advance(duration+1000.0)
    check(not timeline.busy() and Compare.difference(timeline.state,journal.state).is_empty(),seat+" surface preparation neither holds nor reorders authoritative state")
    var later:Array=Persistent.spatial_samples(owners,duration+7000.0,cache)
    check(not later.is_empty() and later.all(func(row):return is_inf(float(row.duration_ms))),seat+" source clip length and former three-second fixture do not retire the still-disclosed owner")
    return recorded_owners.size()

func constructor(row:Dictionary,seat:String)->void:
    var phase:Resource=load(Effects.choice(Effects.occurrence_clip(row)).approaches[0].source_phase)
    var original:PackedByteArray=var_to_bytes(phase.to_clip())
    var operands:Array=row.native_constructor_inputs
    check(operands.size()==1 and operands[0].values=={"surface_uuid":str(row.spatial_effect_uuid)},seat+" public constructor receives only the actual surface UUID")
    check(operands[0].component_path==["surface"] and row.native_clip.source_kind=="standalone_phase",seat+" liquid public wrapper owns its virtual ground/film fan-out")
    var partition:Dictionary=row.spatial_surface_partition
    check(partition.owner_uuid==row.spatial_effect_uuid and partition.capacity==128 and partition.draw_count==row.resolved_area_positions.size(),seat+" actual admitted footprint owns the bounded disjoint source packet")
    check(var_to_bytes(phase.to_clip())==original,seat+" operand inspection leaves the complete delivered Resource untouched")

func routing(row:Dictionary,state:Dictionary,seat:String)->void:
    var receiver:SurfaceReceiver=SurfaceReceiver.new();root.add_child(receiver)
    var world:World=World.new();world.timeline.state=state
    var inputs:RefCounted=Inputs.new()
    var anchor:Vector3=Vector3(row.position[0],0,row.position[1])
    var points={"from":anchor,"hand":anchor,"to":anchor,"ground":anchor,"caster_ground":anchor}
    var handle={"clip":row.native_clip,"occurrence":receiver,"root":receiver}
    var result:Dictionary=inputs.sync(world,handle,row,points)
    check(result.unavailable.is_empty() and result.supplied.size()==3 and receiver.owner_state.present and receiver.owner_state.observed and not receiver.owner_state.suppressed,seat+" production native-input boundary forwards all three actual public channels")
    check(receiver.targets==[{"point":anchor,"cue_point":"source"}],seat+" ground endpoint belongs to the actual spatial anchor")
    check(receiver.partition==row.spatial_surface_partition,seat+" native setter receives the exact public-helper partition packet")
    inputs.sync(world,handle,row,points)
    check(receiver.owner_calls==1,seat+" unchanged presence is not republished every frame")
    world.timeline.state={"senses":{"spatial_effects":{}}}
    result=inputs.sync(world,handle,row,points)
    check(not receiver.owner_state.present and receiver.owner_calls==2 and result.unavailable.is_empty(),seat+" absent current-view membership sends false instead of retaining review presence")
    inputs.clear();world.free();receiver.free()

func boundaries(row:Dictionary,effect:Dictionary,state:Dictionary,cache:Dictionary,seat:String)->void:
    var original:PackedByteArray=var_to_bytes(effect)
    var partial:Dictionary=effect.duplicate(true)
    partial.suppressions=[{"positions":[effect.positions[0]]}]
    var cells:Array=Spatial.admitted_cells(partial)
    check(cells.size()==effect.positions.size()-1 and not cells.has(effect.positions[0]),seat+" suppression subtracts only actual supplied cells")
    var full:Dictionary=effect.duplicate(true);full.suppressions=[{"positions":effect.positions}]
    var hidden_state={"senses":{"spatial_effects":{row.spatial_effect_uuid:full}}}
    check(not Spatial.presence(row,hidden_state).value,seat+" full suppression hides this owner without creating other membership")
    var unknown:Dictionary=row.duplicate();unknown.spatial_effect_uuid="not-disclosed"
    check(not Spatial.presence(unknown,state).value,seat+" another surface's matching kind cannot supply a missing UUID")
    unknown=row.duplicate();unknown.spatial_content_id="not-this-source"
    check(Spatial.presence(unknown,state).reason=="surface_spatial_content_not_bound",seat+" another kind cannot reuse the actual owner's source")
    var ordinary:Dictionary=row.duplicate();ordinary.erase("spatial_owner")
    check(Spatial.presence(ordinary,state).reason=="surface_spatial_owner_not_bound",seat+" cast-only review cues cannot claim independent surface ownership")
    var large:Array=[]
    for index in 300:large.append([index,0])
    var planned:Dictionary=Spatial.surface_partitions(str(row.spatial_effect_uuid),large,[0,0],row.native_cue.constructor_input)
    var drawn:Dictionary={};var duplicates:int=0
    for part in planned.partitions:
        for index in int(part.count):
            if part.draw_flags[index]<.5:continue
            var point:Vector2=part.points[index]
            if drawn.has(point):duplicates+=1
            drawn[point]=true
    check(planned.error.is_empty() and planned.partitions.size()>1 and drawn.size()==300 and duplicates==0,seat+" independent300cell control retains every draw exactly once with native neighbor support")
    var owners:Dictionary={}
    Persistent.observe_spatial(owners,{row.spatial_effect_uuid:effect},0.0,false,[],state.tiles)
    Persistent.observe_spatial(owners,{},600.0)
    check(Persistent.spatial_samples(owners,600.0,cache).is_empty(),seat+" explicit departure retires the same owner at its publication boundary")
    check(var_to_bytes(effect)==original,seat+" boundary checks preserve the original observed effect")

func finish()->void:
    print(JSON.stringify({"checks":checks,"failures":failures,"scope":"Five exact source contracts and independent actual Acid journals; setter/constructor/order checks, with negative suppression/capacity/departure boundaries; no claim of native pixels or recorded removal variants"}))
    quit(0 if failures.is_empty() else 1)
