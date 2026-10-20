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
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const OWNER_CLIPS={
    "spatial_effect.spell.acid_surface":"bg3-36/chromatic-orb/acid/observed-surface",
    "spatial_effect.material.ice":"bg3-36/chromatic-orb/cold/observed-surface",
    "spatial_effect.material.fire":"bg3-36/chromatic-orb/fire/observed-surface",
    "spatial_effect.material.electrified_water":"bg3-36/chromatic-orb/lightning/observed-surface",
    "spatial_effect.spell.simple_toxin":"bg3-36/chromatic-orb/poison/observed-surface"}
class SurfaceReceiver extends Node3D:
    var presence:bool=false
    var presence_calls:int=0
    var targets:Array=[]
    var cells:Array=[]
    func set_surface_presence(value:bool)->void:presence=value;presence_calls+=1
    func set_targets(value:Array)->void:targets=value
    func set_admitted_cells(value:Array)->void:cells=value
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
    var entries:Dictionary={};var paths:Dictionary={}
    for identity in OWNER_CLIPS:
        var path:String="res://authoring/abilities/conditions/"+identity+".tres"
        var entry:Resource=load(path)
        check(entry!=null and entry.id==identity and entry.effects.size()==1,identity+" has one exact typed spatial source")
        if entry==null:finish();return
        entries[identity]=entry;paths[identity]=path
        var clip:Dictionary=Effects.clip(OWNER_CLIPS[identity])
        check(entry.effects[0].clip==clip.id and clip.inputs.size()==3 and ["admitted_cells","surface_presence","targets"].all(func(channel):return channel in clip.inputs),identity+" binds the supplied source with its declared channels")
        var phase:Resource=load(Effects.choice(clip).approaches[0].source_phase)
        check(phase.to_clip().components[0].input.observed_surface_kind==identity,identity+" is the sealed source's explicit surface kind, not a name-based visual match")
        check(entry.status=="partial",identity+" source presence does not claim native visual approval")
    var orb:Resource=load("res://authoring/abilities/spells/spell.chromatic_orb.tres")
    check(orb.effects.all(func(use):return not use.clip.ends_with("/observed-surface")),"Default cast no longer owns surface review topology")
    check(orb.variants.all(func(variant):return variant.effects.all(func(use):return not use.clip.ends_with("/observed-surface"))),"All Orb element/outcome variants hand over surface ownership")
    var built:Dictionary=Build.documents({"conditions":entries,"spells":{orb.id:orb}},{"conditions":paths,"spells":{orb.id:"res://authoring/abilities/spells/spell.chromatic_orb.tres"}})
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

func source_cache(built:Dictionary)->Dictionary:
    var cache:Dictionary={}
    var recipes:Dictionary=Authoring.load_data("catalog/condition_recipes.json",cache).duplicate()
    recipes.merge(built.docs["catalog/condition_recipes.json"],true)
    cache["catalog/condition_recipes.json"]=recipes
    var admitted:Dictionary=Sources.admission(cache)
    var index:Resource=admitted.index.duplicate()
    index.spells=admitted.index.spells.duplicate();index.spells["spell.chromatic_orb"]="actual typed Orb source"
    var loaded:Dictionary=admitted.loaded.duplicate()
    loaded["spell.chromatic_orb"]=built.native.records["spell.chromatic_orb"]
    cache[Sources.CACHE_KEY]=Sources.make_admission(index,loaded)
    return cache

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
        Persistent.observe_spatial(owners,effects,duration)
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
    var phase:Resource=load(Effects.choice(row.native_clip).approaches[0].source_phase)
    var original:Dictionary=phase.to_clip()
    var neutral:Dictionary=Constructed.clip_with_inputs(phase,row.native_constructor_inputs)
    var input:Dictionary=neutral.components[0].input
    check(not input.surface_admitted and input.admitted_cells.is_empty() and is_inf(float(input.retire_at_seconds)),seat+" constructor cannot admit review cells, review presence or fixed retirement")
    for field in original.components[0].input:
        if field in ["surface_admitted","admitted_cells","retire_at_seconds"]:continue
        check(input[field]==original.components[0].input[field],seat+" sealed source setting unchanged: "+str(field))
    check(phase.to_clip()==original,seat+" private constructor leaves delivered Resource untouched")

func routing(row:Dictionary,state:Dictionary,seat:String)->void:
    var receiver:SurfaceReceiver=SurfaceReceiver.new();root.add_child(receiver)
    var world:World=World.new();world.timeline.state=state
    var inputs:RefCounted=Inputs.new()
    var anchor:Vector3=Vector3(row.position[0],0,row.position[1])
    var points={"from":anchor,"hand":anchor,"to":anchor,"ground":anchor,"caster_ground":anchor}
    var handle={"clip":row.native_clip,"occurrence":receiver,"root":receiver}
    var result:Dictionary=inputs.sync(world,handle,row,points)
    check(result.unavailable.is_empty() and result.supplied.size()==3 and receiver.presence,seat+" production native-input boundary forwards all three actual public channels")
    check(receiver.targets==[{"point":anchor,"cue_point":"source"}],seat+" ground endpoint belongs to the actual spatial anchor")
    var expected:Array=[]
    for point in row.resolved_area_positions:expected.append([float(point[0])-anchor.x,float(point[1])-anchor.z])
    check(receiver.cells==expected,seat+" existing cell adapter maps actual world cells once into source-local coordinates")
    inputs.sync(world,handle,row,points)
    check(receiver.presence_calls==1,seat+" unchanged presence is not republished every frame")
    world.timeline.state={"senses":{"spatial_effects":{}}}
    result=inputs.sync(world,handle,row,points)
    check(not receiver.presence and receiver.presence_calls==2 and result.unavailable.is_empty(),seat+" absent current-view membership sends false instead of retaining review presence")
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
    var large:Dictionary=effect.duplicate(true);large.positions=[]
    for index in 33:large.positions.append([index,0])
    check(Spatial.construction(str(row.spatial_effect_uuid),large,row.native_cue).reason=="spatial_source_cell_capacity_exceeded",seat+" sealed source's 32-cell capacity stays an explicit gap instead of asserting or clipping authoritative cells")
    var owners:Dictionary={row.spatial_effect_uuid:{"id":row.spatial_effect_uuid,"effect":effect,"start_ms":0.0,"end_ms":INF,"initial":false}}
    Persistent.observe_spatial(owners,{},600.0)
    check(Persistent.spatial_samples(owners,600.0,cache).is_empty(),seat+" explicit departure retires the same owner at its publication boundary")
    check(var_to_bytes(effect)==original,seat+" boundary checks preserve the original observed effect")

func finish()->void:
    print(JSON.stringify({"checks":checks,"failures":failures,"scope":"Five exact source contracts and independent actual Acid journals; setter/constructor/order checks, with negative suppression/capacity/departure boundaries; no claim of native pixels or recorded removal variants"}))
    quit(0 if failures.is_empty() else 1)
