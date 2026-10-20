extends SceneTree
## Optical direction/source-contract checks, plus genuine independent owner
## journals. No native framebuffer, gameplay aim or target is synthesized.
const Placement=preload("res://presentation/spell_placement.gd")
const LivePose=preload("res://assets/vfx/conditions/live_pose.gd")
const Conditions=preload("res://presentation/conditions.gd")
const Build=preload("res://tools/presentation_build/abilities.gd")
const Authoring=preload("res://presentation/authoring.gd")
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const CONDITION="condition.spell.eyebite.casting"
const SOURCE="res://authoring/abilities/conditions/condition.spell.eyebite.casting.tres"
const CYCLE=["E","SE","S","SW","W","NW","N","NE"]
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("DISPLAY_FACING_AIM_FAIL "+label)
func run()->void:
    var resource:Resource=load(SOURCE)
    check(resource.aim_policy=="display_facing","The actual condition explicitly selects cosmetic displayed-facing aim")
    var built:Dictionary=Build.documents({"conditions":{CONDITION:resource}},{"conditions":{CONDITION:SOURCE}})
    var recipe:Dictionary=built.docs["catalog/condition_recipes.json"][CONDITION]
    check(recipe.persistent.nativeAim=="display_facing","Typed policy exports through the existing condition recipe")
    for phase in ["application","sustain","removal"]:
        var script:Script=load("res://assets/vfx/conditions/condition_eyebite_eye_persistent/"+phase+".gd")
        var declared:Node3D=script.make_component({})
        check(declared.parameters.live_pose.mode=="gaze",phase+" declares the supported gaze input contract")
        pure_controls(declared.parameters.live_pose,phase)
        declared.free()
    for seat in ["amber","blue"]:read_case(seat,recipe)
    print(JSON.stringify({"checks":checks,"failures":failures,"scope":"Actual delivered LivePose transform/orientation across 8 world facings and 4 camera quarters, typed policy and original independent Eyebite owner journals. No native pixels, game target or range claimed."}))
    quit(0 if failures.is_empty() else 1)

func pure_controls(specification:Dictionary,phase:String)->void:
    var before:PackedByteArray=var_to_bytes(specification)
    var camera:Camera3D=Camera3D.new();root.add_child(camera);camera.current=true
    for quarter in 4:
        camera.global_transform=Placement.Placement.camera_transform(Vector3.ZERO,quarter)
        for factor in [1.0,1.7]:
            var owner:Node3D=Node3D.new();root.add_child(owner)
            owner.global_transform=Transform3D(Basis(Vector3.UP,PI*.5).scaled(Vector3.ONE*factor),Vector3(4.0,2.0,7.0))
            var eye:Node3D=Node3D.new();eye.name="Eye";owner.add_child(eye)
            var live:RefCounted=LivePose.new()
            var parameters:Dictionary=specification.duplicate(false);parameters.nodes=["Eye"]
            live.configure(owner,parameters)
            var source:Vector3=owner.global_transform*Vector3(.21,.11,.17)
            for facing in CYCLE:
                var row:Dictionary={"id":"optical-actor","facing":facing}
                var frozen:PackedByteArray=var_to_bytes(row)
                var actual:Dictionary=Placement.display_facing_aim(row,CYCLE,source,specification,"display_facing")
                var label:String=phase+" q"+str(quarter)+" "+facing+" scale"+str(factor)
                check(actual.reason.is_empty() and actual.rows.size()==2,label+" supplies exactly two optical endpoints")
                var direction:Vector3=actual.direction
                check(Placement.Placement.facing(Vector2(direction.x,direction.z),CYCLE)==facing,label+" world direction inverts the existing renderer-facing mapping")
                check(is_equal_approx(direction.length(),1.0) and is_zero_approx(direction.y),label+" aim is a unit direction, not an action range or target")
                live.update(actual.rows)
                var offset:Array=specification.offset
                var expected_origin:Vector3=source+Vector3(offset[0],offset[1],offset[2])
                check(live.admitted and eye.global_position.is_equal_approx(expected_origin),label+" exact delivered WORLD offset is applied once after root placement")
                var expected:Vector3=camera.global_basis.z.lerp(direction,float(specification.camera_blend)).normalized()
                check(eye.global_basis.z.normalized().dot(expected)>.99999,label+" actual source look-at retains source camera blend and world-facing orientation")
                check(actual.rows.all(func(point):return point.actor_uuid==row.id and not point.has("target_uuid")) and var_to_bytes(row)==frozen,label+" points belong to the displayed actor without altering canonical actor/target data")
                var again:Dictionary=Placement.display_facing_aim(row,CYCLE,source,specification,"display_facing")
                check(again==actual,label+" a paused unchanged pose remains exact")
            live.update([])
            check(not live.admitted and not owner.visible,phase+" missing endpoints retire only the source's optical admission")
            owner.free()
    check(Placement.display_facing_aim({"id":"a","facing":"E"},CYCLE,Vector3.ZERO,specification,"").reason=="authored_endpoint_aim_not_bound",phase+" missing authored policy retains the explicit gap")
    check(Placement.display_facing_aim({"id":"a","facing":"unavailable"},CYCLE,Vector3.ZERO,specification,"display_facing").reason=="display_facing_not_available",phase+" unknown published facing is not guessed")
    check(not Placement.display_facing_aim({"id":"a","facing":"E"},CYCLE,Vector3.ZERO,{"mode":"attached"},"display_facing").reason.is_empty(),phase+" non-gaze sources cannot borrow the policy")
    check(var_to_bytes(specification)==before,phase+" source-owned offset/mode/material settings remain unchanged")
    camera.free()

func read_case(seat:String,recipe:Dictionary)->void:
    var directory:String="res://tests/fixtures/schema16/eyebite-aim/"+seat
    var journal:RefCounted=Journal.new()
    var opened:Dictionary=journal.open(directory,true,false)
    check(opened.ok,seat+" original journal opens")
    if not opened.ok:return
    var cache:Dictionary={};var recipes:Dictionary=Authoring.load_data("catalog/condition_recipes.json",cache).duplicate(false)
    recipes[CONDITION]=recipe;cache["catalog/condition_recipes.json"]=recipes
    var owners:Dictionary={};var found:int=0
    var files:PackedStringArray=DirAccess.get_files_at(directory);files.sort()
    for file in files:
        if not file.ends_with(".json") or not file.get_basename().is_valid_int():continue
        var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(file))
        var sequence:int=int(file.get_basename())
        var decoded:Dictionary=journal.decode_record(sequence,raw)
        check(decoded.ok,seat+" native packet decodes "+str(sequence))
        if not decoded.ok:return
        var previous:Dictionary=journal.state
        var folded:Dictionary=journal._consume_admitted(decoded.value,raw,true)
        check(folded.ok,seat+" native packet reduces "+str(sequence))
        if not folded.ok:return
        if sequence==0:
            Conditions.observe(owners,journal.state.actors,0.0,true);continue
        var original:PackedByteArray=var_to_bytes(folded.normalized)
        var compiled:Dictionary=Compiler.compile_recorded(previous,folded.normalized,cache,journal.state,folded.transitions)
        check(compiled.ok,seat+" actual effects and owner clocks compile "+str(sequence))
        if not compiled.ok:return
        for group in compiled.value.groups:
            for commit in group.commits:
                Conditions.observe(owners,commit.delta.get("actors",{}),float(commit.at_ms),false,commit.get("condition_rows",[]))
        check(var_to_bytes(folded.normalized)==original and FileAccess.get_file_as_bytes(directory.path_join(file))==raw,seat+" authoring adds no target, facing fact or packet mutation")
    for owner in owners.values():
        if owner.condition.behavior_id!=CONDITION:continue
        found+=1
        check(owner.id=="e94cc307-c32a-436f-8d99-5136e2ff8eaf" and owner.actor_uuid=="d1d87568-cff5-48b5-966b-2540ab6d3aac",seat+" actual casting UUID and recipient own the maintained eye")
        var samples:Array=Conditions.native_samples({owner.id:owner},float(owner.start_ms)+500.0,cache)
        var eyes:Array=samples.filter(func(sample):return sample.get("lifecycle_key")=="condition_eyebite_eye_persistent")
        check(eyes.size()==1,seat+" one existing UUID lifecycle owns the eye, without a duplicate cast owner")
        if eyes.size()!=1:continue
        check(eyes[0].native_cue.aim_policy=="display_facing" and eyes[0].condition_uuid==owner.id,seat+" the actual matched lifecycle receives the authored optical policy")
        check(eyes[0].native_cue.attachment=="recipient_ground" and eyes[0].native_cue.offset==[0.0,0.0,0.0],seat+" policy preserves approved source registration and offset")
    check(found==1,seat+" exactly one original casting owner was studied")
