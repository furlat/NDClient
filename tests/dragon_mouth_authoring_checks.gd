extends SceneTree
## Actual installed authoring/constructor operands; no native output claim.
const Builder=preload("res://tools/presentation_build/abilities.gd")
const Common=preload("res://tools/presentation_build/common.gd")
const Constructed=preload("res://presentation/native_constructed_occurrence.gd")
const Conditions=preload("res://presentation/conditions.gd")
const Persistent=preload("res://presentation/native_persistent.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Catalog=preload("res://source_catalog.gd")
const CONDITION="res://authoring/abilities/conditions/condition.summon.draconic_breath_cadence.tres"
const RIG="res://authoring/characters/rigs/summon.draconic_spirit.violet-astral.tres"
var checks:int=0
var failures:Array=[]

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("DRAGON_MOUTH_AUTHORING_FAIL ",label)
func read(path:String)->Dictionary:
    if not FileAccess.file_exists(path):check(false,"Installed input exists: "+path);return {}
    var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
    if not data is Dictionary:check(false,"Installed input is an object: "+path);return {}
    return data

func run()->void:
    var condition:Resource=load(CONDITION)
    var overlay:Dictionary=read("res://dragon_overlay/index.json")
    if overlay.is_empty():finish();return
    var mouth:Dictionary=overlay.mouth
    var table:Dictionary=read(mouth.data)
    var receivers:Dictionary=read(mouth.receiver_inputs)
    if table.is_empty() or receivers.is_empty():finish();return
    var admission:Dictionary=Common.report()
    Builder._validate({"conditions":{condition.id:condition}},admission)
    check(admission.errors.is_empty(),"Actual authored mouth passes build admission: "+str(admission.errors))
    var built:Dictionary=Builder.documents({"conditions":{condition.id:condition}}).docs["catalog/condition_recipes.json"][condition.id]
    check(built.persistent.lifecycleGeometry==condition.lifecycle_geometry,"Build retains exact body/pixel-table registration")
    var selected:Array=built.persistent.lifecycleOptIns.map(func(row):return row.breath_type)
    selected.sort()
    check(selected==["Acid","Cold","Fire","Lightning","Poison"],"Only five actual playable palettes remain selected")
    var cold_cache:Dictionary={"catalog/condition_recipes.json":{}}
    Conditions.prepare_geometry_metadata({"behavior_id":"condition.absent","state":{}},cold_cache)
    var cold_snapshot:Dictionary=Catalog.source_snapshot(cold_cache)
    check(not cold_cache.has(mouth.data) and not cold_cache.has(mouth.receiver_inputs) \
        and not cold_snapshot.has(mouth.data) and not cold_snapshot.has(mouth.receiver_inputs),"No selected mouth condition admits or publishes Dragon metadata")
    for change in [{"rig":"other-rig"},{"layout":"new512"},{"table":"res://absent-mouth.json"},{"receiver_inputs":"res://absent-inputs.json"}]:
        var candidate:Resource=condition.duplicate(true)
        candidate.lifecycle_geometry.region.merge(change,true)
        var rejected:Dictionary=Common.report()
        Builder._validate({"conditions":{candidate.id:candidate}},rejected)
        check(not rejected.errors.is_empty(),"Build refuses unregistered optical route: "+str(change))
    var wrong_slot:Resource=condition.duplicate(true)
    wrong_slot.lifecycle_geometry.slots=["head"]
    var rejected:Dictionary=Common.report()
    Builder._validate({"conditions":{wrong_slot.id:wrong_slot}},rejected)
    check(not rejected.errors.is_empty(),"Body pixels cannot be relabelled as head")
    var clips:Dictionary={}
    for clip in read("res://assets/vfx/index.json").clips:clips[clip.clip_id]=clip
    var public_phases:Dictionary={}
    for selection in read(condition.lifecycle_opt_in).selections:
        for phase in selection.phases.values():public_phases[phase.clip_id]=phase
    var seen:Dictionary={}
    check(receivers.rows.size()==39,"All 39 delivered phase-specific operands are retained")
    for row in receivers.rows:
        check(not seen.has(row.clip_id),"One operand row for "+row.clip_id);seen[row.clip_id]=true
        if not clips.has(row.clip_id) or not public_phases.has(row.clip_id):check(false,"Installed public clip exists: "+row.clip_id);continue
        var source:Dictionary=public_phases[row.clip_id]
        var approaches:Array=clips[row.clip_id].approaches.filter(func(value):return value.get("path")==source.constructor and value.get("source_phase")==source.phase and value.get("condition_prepared",false))
        check(approaches.size()==1,"Exact installed public constructor/phase: "+row.clip_id)
        var phase:Resource=load(source.phase)
        var original:Dictionary=phase.to_clip()
        var before:PackedByteArray=var_to_bytes(original)
        var readiness:Array=original.components.filter(func(value):return value.id=="readiness")
        if readiness.size()!=1:check(false,"Actual readiness component exists: "+row.clip_id);continue
        var expected:Dictionary=readiness[0].input.adaptive_surface.duplicate(true)
        expected.settings.slot="body"
        check(row.native_constructor_inputs.size()==1 and row.native_constructor_inputs[0].component_path==["readiness"] \
            and row.native_constructor_inputs[0].input_field=="adaptive_surface" and row.native_constructor_inputs[0].values==expected,
            "Full source adaptive options change only the receiving slot: "+row.clip_id)
        var constructed:Dictionary=Constructed.clip_with_inputs(phase,row.native_constructor_inputs)
        check(constructed.components.filter(func(value):return value.id=="readiness")[0].input.adaptive_surface==expected,
            "Existing construction transport applies complete body operands: "+row.clip_id)
        check(var_to_bytes(phase.to_clip())==before,"Shared phase defaults remain immutable: "+row.clip_id)
    # Value-in/out runtime transport at the existing lifecycle boundary.
    # This is not a fabricated packet or a claim of rendered gameplay.
    for breath_type in selected:
        var canonical:Dictionary={"condition_uuid":"test-cadence","behavior_id":condition.id,"state":{"ready":true,"breath_type":breath_type}}
        var cache:Dictionary={"catalog/condition_recipes.json":{condition.id:built}}
        var selections:Array=Persistent.lifecycles(canonical,cache)
        var common:Dictionary={"id":"condition:test-cadence","actor_uuid":"dragon","condition_uuid":"test-cadence","condition":canonical,
            "recipe":built,"initial":false,"start_ms":0.0,"duration_ms":INF,"age_ms":0.0,"removal_age_ms":null}
        var before:Array=Persistent.lifecycle_samples(common,selections,cache)
        check(before.size()==1 and before[0].status=="missing" and not before[0].has("native_constructor_inputs"),breath_type+" stays unavailable before actual operand admission")
        Conditions.prepare_geometry_metadata(canonical,cache)
        var snapshot:Dictionary=Catalog.source_snapshot(cache)
        var adopted:Dictionary={}
        Catalog.adopt_snapshot(adopted,snapshot)
        for path in [mouth.data,mouth.receiver_inputs]:
            check(is_same(snapshot.get(path),cache.get(path)) and is_same(adopted.get(path),cache.get(path)),breath_type+" snapshots/adopts the exact immutable admitted metadata: "+path)
        var after:Array=Persistent.lifecycle_samples(common,selections,cache)
        check(after.size()==1 and after[0].status=="available",breath_type+" admits its operands after preparation in the same cache")
        if after.size()!=1:continue
        for phase_name in ["application","sustain","removal"]:
            var clip:Dictionary=after[0].lifecycle_phases[phase_name]
            var matches:Array=receivers.rows.filter(func(value):return value.clip_id==clip.id)
            check(matches.size()==1 and clip.get("construction_inputs")==matches[0].native_constructor_inputs,breath_type+" forwards exact "+phase_name+" operands")
        check(Effects.occurrence_clip(after[0]).get("construction_inputs")==after[0].lifecycle_phases.application.construction_inputs,breath_type+" application operands reach occurrence construction")
    var rig:Resource=load(RIG)
    var banks:int=0
    for clip in rig.clips:
        for art in clip.body_banks.values():
            var key:String=clip.name+"/"+str(art.path).get_file().get_basename()
            if not table.banks.has(key):check(false,"Exact displayed bank has mouth registration: "+key);continue
            var bank:Dictionary=table.banks[key]
            var registration:Dictionary=bank.layouts.selected768
            banks+=1
            check(registration.source_path=="res://assets/"+art.path,"Exact current768 source identity: "+key)
            check(Vector2i(int(registration.cell[0]),int(registration.cell[1]))==art.cell and bank.frames.size()==art.frames and registration.frame_uvs.size()==art.frames,"Exact current cell/frame registration: "+key)
            var surface:Resource=art.surface
            check(registration.geometry_metadata.optical_camera.origin==[surface.camera_origin.x,surface.camera_origin.y] \
                and registration.geometry_metadata.depth_range==[surface.depth_range.x,surface.depth_range.y] \
                and registration.geometry_metadata.optical_ground_pixels==surface.optical_ground_pixels,"Actual source optical registration: "+key)
            var file=FileAccess.open(registration.source_path,FileAccess.READ)
            if file==null:check(false,"Selected source bytes exist: "+key);continue
            file.big_endian=true;file.seek(16)
            var size:Vector2=Vector2(file.get_32(),file.get_32());file.close()
            check(size.x>0 and size.y>0,"Actual source image dimensions: "+key)
            for frame in art.rects.size():
                var rect:Rect2i=art.rects[frame]
                var uv:Array=registration.frame_uvs[frame]
                check(Vector4(float(uv[0]),float(uv[1]),float(uv[2]),float(uv[3])).is_equal_approx(Vector4(rect.position.x/size.x,rect.position.y/size.y,rect.size.x/size.x,rect.size.y/size.y)),"Exact displayed frame UV: "+key+"/"+str(frame))
    check(banks==120,"All 120 selected source banks retain their explicit registration")
    finish()

func finish()->void:
    print("DRAGON_MOUTH_AUTHORING ",JSON.stringify({"checks":checks,"failures":failures,"scope":"Installed selected768 source registration, build admission and exact phase operands. No geometry/render/performance or optional512 claim."}))
    quit(0 if failures.is_empty() else 1)
