extends SceneTree
## Actual schema16 membership/typed authoring, followed by labelled geometry
## and composition unit controls. Native output is a separate rendering gate.
const Conditions=preload("res://presentation/conditions.gd")
const Records=preload("res://tools/presentation_build/ability_records.gd")
const Fields=preload("res://tools/presentation_build/ability_fields.gd")
const Condition=preload("res://presentation/source/abilities/condition.gd")
const Journal=preload("res://sdk/journal.gd")
const Recording=preload("res://studio/recording.gd")
const Catalog=preload("res://source_catalog.gd")
const Sources=preload("res://presentation/sprite_sources.gd")
const Construction=preload("res://presentation/actor_construction.gd")
const Sockets=preload("res://presentation/surface_sockets.gd")
const Shadows=preload("res://presentation/canvas_shadows.gd")
const Surface=preload("res://presentation/entity_surface.gd")
const BASE="res://tests/fixtures/schema16/body-scale-enlarge"
const OWNER="8e2e8283-3753-479e-a9f3-86172ce4e59b"
const ACTOR="14b77167-753e-49d9-aba7-72e7cf26b835"
class World extends Sources:
    var visual_actors:Dictionary={}
    var character_light_profile:String="reference"
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("BODY_SCALE_FAIL ",label)
func run()->void:
    var entry:Resource=load("res://authoring/abilities/conditions/condition.spell.enlarge_reduce.tres")
    var record:Dictionary=Records.condition_recipe(entry)
    check(entry.look.steps[0].scale_by_size_change=={"enlarge":1.175,"reduce":.75},"Typed body adjustment preserves the exact authored two-factor map")
    check(not entry.unported.get("persistent",{}).has("bodyScale") and record.persistent.bodyScale=={"enlarge":1.175,"reduce":.75},"One typed home emits bodyScale without duplicate unported authoring")
    var roundtrip:Resource=Condition.new();Records.condition_from_recipe(roundtrip,record)
    var rebuilt:Dictionary=Records.condition_recipe(roundtrip)
    var differences:Array=Fields.differences(record,rebuilt,"",[])
    check(rebuilt==record,"Existing F move/emit round-trips the whole authored recipe unchanged: "+str(differences))
    var cache:Dictionary={}
    for seat in ["amber","blue"]:
        var journal=Journal.new();var opened:Dictionary=journal.open(ProjectSettings.globalize_path(BASE.path_join(seat)),true,false)
        check(opened.ok,"Original "+seat+" journal opens through the SDK")
        if not opened.ok:continue
        var replayed:Dictionary=journal.replay(8)
        check(replayed.ok,"Original "+seat+" operation folds without compatibility")
        if not replayed.ok:continue
        var state:Dictionary=journal.state
        var canonical:PackedByteArray=var_to_bytes(state)
        var member:Dictionary=state.actors[ACTOR].conditions.filter(func(value):return value.condition_uuid==OWNER)[0]
        check(member.state.size_change=="enlarge","Original "+seat+" actual condition UUID exposes Enlarge")
        var owners:Dictionary={};Conditions.observe(owners,state.actors,0.0,true)
        var samples:Array=Conditions.samples(owners,0.0,cache,{},false)
        var selected:Array=samples.filter(func(value):return value.kind=="condition" and value.condition_uuid==OWNER)
        check(selected.size()==1,"Actual "+seat+" owner has one shared condition sample")
        if selected.size()==1:
            var actual:Dictionary=Conditions.material(ACTOR,samples).body_scale
            check(is_equal_approx(actual.factor,1.175) and actual.owners.size()==1 and actual.owners[0].condition_uuid==OWNER and actual.owners[0].size_change=="enlarge","Actual "+seat+" selected UUID/state chooses the exact scale once")
            composition_controls(selected[0])
        check(var_to_bytes(state)==canonical,"Scale selection preserves original "+seat+" canonical state")
    geometry_controls()
    lifecycle_originals()
    var result:Dictionary={"checks":checks,"failures":failures,"scope":"Original both-seat Enlarge baseline and real Enlarge/Reduce apply/move/attack/removal/restored-move recordings, typed round-trip, selected UUID Studio rows, canonical restoration, labelled composition controls and source-model/socket/painter/caster algebra; no native pixel claim."}
    FileAccess.open("res://generated/body_scale_checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("BODY_SCALE_CHECKS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)

func composition_controls(original:Dictionary)->void:
    var before:PackedByteArray=var_to_bytes(original)
    var duplicate:Dictionary=original.duplicate(true);duplicate.condition_uuid="composition-control-duplicate";duplicate.condition.condition_uuid=duplicate.condition_uuid
    check(is_equal_approx(Conditions.material(ACTOR,[original,duplicate]).body_scale.factor,1.175),"Unit: duplicate owners of one recipe do not apply scale twice")
    var unknown:Dictionary=original.duplicate(true);unknown.condition.state.size_change=null
    check(Conditions.material(ACTOR,[unknown]).body_scale=={"factor":1.0,"owners":[]},"Unit: absent public selector is neutral without a fake owner witness")
    unknown.condition.state.size_change="unknown"
    check(Conditions.material(ACTOR,[unknown]).body_scale.owners.is_empty(),"Unit: unmatched public selector does not infer Enlarge from its behavior name")
    var reduce:Dictionary=original.duplicate(true);reduce.condition.state.size_change="reduce"
    check(is_equal_approx(Conditions.material(ACTOR,[reduce]).body_scale.factor,.75),"Unit authoring control: Reduce selects .75; this is not a recorded Reduce outcome")
    var fading:Dictionary=original.duplicate(true);fading.alpha=.5
    check(is_equal_approx(Conditions.material(ACTOR,[fading]).body_scale.factor,1.0875),"Unit: only the existing owner opacity envelope interpolates scale to neutral")
    var independent:Dictionary=reduce.duplicate(true);independent.condition_uuid="composition-control-independent";independent.condition.condition_uuid=independent.condition_uuid
    independent.recipe.erase("definitionRef")
    check(is_equal_approx(Conditions.material(ACTOR,[original,independent]).body_scale.factor,1.175*.75),"Unit: distinct selected recipe factors compose through existing selection")
    var different:Dictionary=original.duplicate(true);different.actor_uuid="another-actor"
    check(Conditions.material(ACTOR,[different]).body_scale.owners.is_empty(),"Unit: another actor's member never scales this actor")
    check(Conditions.material(ACTOR,[]).body_scale=={"factor":1.0,"owners":[]},"Unit: no owner restores exact neutral transform operands")
    check(var_to_bytes(original)==before,"Composition controls do not mutate the actual recorded member/sample")

func geometry_controls()->void:
    var world:=World.new();root.add_child(world)
    world.camera=Camera3D.new();world.add_child(world.camera)
    world.camera.transform=Sources.Placement.camera_transform(Vector3.ZERO,0)
    var rig:Dictionary=Catalog.read_file("catalog/rigs.json",{}).get("neuroclient.modular",{})
    check(not rig.is_empty(),"Geometry control uses the actual modular rig registration")
    if rig.is_empty():world.free();return
    world.rigs={"neuroclient.modular":rig}
    world.rig_config={"TILE_W":128.0}
    var row:Dictionary={"id":ACTOR,"kind":"actor","rig":"neuroclient.modular","position":[4,6],"base_height_steps":1.0,"scale":1.0,"scale_x":1.0,"visual_height":0.0}
    var shape:Dictionary=Construction.layer_shape(rig,1.0)
    var node:=MeshInstance3D.new();world.add_child(node)
    node.mesh=Construction.QuadShapes.mesh(shape.mesh_size,shape.mesh_center)
    node.basis=world.camera.basis;node.position=Sources.Placement.contact(row)
    var units:float=1.0/Sources.Placement.PIXELS_PER_UNIT
    var entry:Dictionary={"id":"body-scale-geometry-control","node":node,"role":"body","placement":row,"actor_layer":{"slot":"body","effect":{}},"pivot":shape.pivot,"scale":1.0,"cell":shape.cell,
        "body_scale":1.0,"source_version":1,"geometry_cell_size":shape.cell,"geometry_ground_pixels":19.0,
        "source_parameters":{"has_component_geometry":true,"sheet":null,"frame_uv":Vector4(0,0,1,1),"component_depth":null,"component_support":null,
            "component_depth_range":Vector2(-1,1),"component_units":units,"component_reconstruction_origin":Vector2(64,96),"component_elevation":PI/4}}
    # The caster snapshot admits real parameter types; no GPU texture/render
    # is claimed by this geometry-only control.
    var depth:Image=Image.create(1,1,false,Image.FORMAT_RGBA8)
    entry.source_parameters.sheet=depth;entry.source_parameters.component_depth=depth;entry.source_parameters.component_support=depth
    world.visual_actors[ACTOR]={"row":row,"valid":true,"entries":[entry]}
    var pixel:Vector2=shape.pivot+Vector2(9,-30)
    var foot:Vector3=Sources.Placement.contact(row)
    var neutral:Vector3=Sockets.painted_point(world,row,pixel)
    world.update_bounds(entry);var original_bounds:Rect2=entry.screen_rect
    var original:Dictionary=Shadows._snapshots([entry],world.camera)[0]
    var ground:float=19.0*units
    var shadow_shapes:=Shadows.new()
    var neutral_shape:Dictionary=shadow_shapes._caster_shape(original,ground)
    var caster:Vector3=Shadows._caster_point(original,pixel.x,pixel.y,.3,ground)
    for factor in [1.175,.75]:
        node.basis=world.camera.basis.scaled_local(Vector3.ONE*factor);entry.body_scale=factor
        var projected:Vector3=Sockets.painted_point(world,row,pixel)
        check(projected.is_equal_approx(foot+(neutral-foot)*factor),"Unit: source socket scales once about the actual feet, factor="+str(factor))
        var requested:Dictionary=row.duplicate();requested.position=[8,3];requested.base_height_steps=2.0
        check(Sockets.painted_point(world,requested,pixel).is_equal_approx(projected+Sources.Placement.contact(requested)-foot),"Unit: socket retains the caller's frozen event contact/elevation")
        row.visual_height=.6;node.position=foot+Vector3.UP*.6*Sources.Placement.HEIGHT_UNIT
        var frozen:Dictionary=requested.duplicate();frozen.visual_height=.2
        check(Sockets.painted_point(world,frozen,pixel).is_equal_approx(projected+Sources.Placement.contact(frozen)-foot+Vector3.UP*.2*Sources.Placement.HEIGHT_UNIT),"Unit: a frozen endpoint retains its own lift instead of borrowing the later displayed lift")
        row.visual_height=0.0;node.position=foot
        var picked:Vector3=node.global_transform.affine_inverse()*projected
        var source_local:Vector3=Vector3(pixel.x-shape.pivot.x,shape.pivot.y-pixel.y,0.0)*units
        check(picked.is_equal_approx(source_local),"Unit: the picking inverse recovers the original source pixel under either scale")
        world.update_bounds(entry)
        check(entry.screen_rect.size.is_equal_approx(original_bounds.size*factor),"Unit: painter bounds follow the actual scaled quad")
        var snapshot:Dictionary=Shadows._snapshots([entry],world.camera,[original])[0]
        check(snapshot.model.is_equal_approx(Basis.from_scale(Vector3.ONE*factor)),"Unit: shadow adapter captures the displayed model scale without source changes")
        var scaled:Vector3=Shadows._caster_point(snapshot,pixel.x,pixel.y,.3,ground)
        var support:Vector3=Vector3.UP*ground
        check(scaled.is_equal_approx(support+(caster-support)*factor),"Unit: caster and footprint scale once around their established support plane")
        var caster_shape:Dictionary=shadow_shapes._caster_shape(snapshot,ground)
        check(caster_shape.local_bounds==neutral_shape.bounds and caster_shape.local_points==neutral_shape.local_points,"Unit: native caster culling box remains in unscaled source space")
        var native_model:Transform3D=Transform3D(snapshot.model,support-snapshot.model*support)
        for i in caster_shape.local_points.size():
            var local_point:Vector3=caster_shape.local_points[i]
            check(caster_shape.local_bounds.has_point(local_point) and (native_model*caster_shape.local_bounds).has_point(caster_shape.points[i]) \
                and (native_model*local_point).is_equal_approx(caster_shape.points[i]),"Unit: source corner "+str(i)+" remains inside once-transformed caster culling bounds, factor="+str(factor))
        check(entry.source_parameters.component_units==units,"Unit: physical source geometry is not rescaled/redecoded")
    node.basis=world.camera.basis;entry.body_scale=1.0;world.update_bounds(entry)
    check(Sockets.painted_point(world,row,pixel)==neutral and entry.screen_rect==original_bounds,"Unit: removal restores exact neutral socket/painter operands")
    check(Shadows._snapshots([entry],world.camera)[0].model==Basis.IDENTITY,"Unit: neutral caster keeps the original identity model")
    world.free()

func lifecycle_originals()->void:
    var cases:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/schema16/body-scale/cases.json"))
    for case in cases.cases:
        var mode:String="reduce" if case.id.ends_with("reduce_lifecycle") else "enlarge"
        var expected:float=.75 if mode=="reduce" else 1.175
        for view in case.perspectives:
            var index:Dictionary=Recording.read(view.journal)
            var label:String=mode+"/"+view.id
            check(index.ok,"Actual lifecycle "+label+" compiles through the ordinary Recording reader")
            if not index.ok:continue
            var lives:Array=index.rows.filter(func(row):return row.kind=="condition" and row.get("owner",{}).get("condition",{}).get("behavior_id")=="condition.spell.enlarge_reduce")
            check(lives.size()==1,"Actual lifecycle "+label+" retains one authoritative size owner")
            if lives.size()!=1:continue
            var owner:Dictionary=lives[0].owner
            check(owner.condition.state.size_change==mode and is_finite(float(owner.end_ms)) and float(owner.end_ms)>float(owner.start_ms),"Actual lifecycle "+label+" has genuine selector, admission and removal")
            var middle:float=minf(float(owner.end_ms)-.001,float(owner.start_ms)+200.0)
            var timeline:RefCounted=Recording.restore(index,middle)
            var active:Dictionary=Conditions.material(owner.actor_uuid,timeline.component_samples(index.cache)).body_scale
            check(is_equal_approx(active.factor,expected) and active.owners.any(func(value):return value.condition_uuid==owner.id and value.size_change==mode),"Actual lifecycle "+label+" selects its original UUID/factor during replay")
            var rows:Array=index.rows.filter(func(row):return row.kind=="condition_material" and row.get("mechanism")=="bodyScale" and row.owner.id==owner.id)
            check(not rows.is_empty() and rows.all(func(row):return row.operations.bodyScale.condition_uuid==owner.id and row.operations.bodyScale.size_change==mode and row.status!="missing"),"Studio exposes exact selected "+label+" UUID/state/factor without an unimplemented placeholder")
            check(index.rows.any(func(row):return row.kind=="condition_restore" and row.mechanism=="bodyScale" and row.owner.id==owner.id),"Studio retains actual "+label+" size restoration")
            var final:RefCounted=Recording.restore(index,index.presentation_end_ms)
            check(Conditions.material(owner.actor_uuid,final.component_samples(index.cache)).body_scale=={"factor":1.0,"owners":[]},"Actual "+label+" removal returns to the exact neutral scale")
            var journal=Journal.new();var opened:Dictionary=journal.open(ProjectSettings.globalize_path(view.journal),true,false)
            check(opened.ok,"Independent SDK "+label+" original prefix opens")
            if opened.ok:
                var files:PackedStringArray=DirAccess.get_files_at(view.journal)
                var count:int=0
                for file in files:
                    if file.ends_with(".json") and file.get_basename().length()==16 and file.get_basename().is_valid_int():count+=1
                var folded:Dictionary=journal.replay(count-1)
                check(folded.ok and final.state==journal.state,"Scale playback preserves the exact independent canonical "+label+" endpoint")
            var looped:RefCounted=Recording.restore(index,middle)
            check(Conditions.material(owner.actor_uuid,looped.component_samples(index.cache)).body_scale==active,"Seek/loop reconstructs the same actual "+label+" owner/factor")
