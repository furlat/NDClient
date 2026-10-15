extends SceneTree
## Shared native uniforms must equal a full copy for every admitted frame delta.
const Atlas=preload("res://presentation/native_light_atlas.gd")
const Source=preload("res://modular.gdshader")
var checks=0
var failures:Array=[]
var atlas=Atlas.new()
var reference=Atlas.new()
var entry:Dictionary
var full_entry:Dictionary
var group:Dictionary
var full_group:Dictionary
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("ATLAS_FRAME_FAIL ",label)
func output()->ShaderMaterial:
    var material=ShaderMaterial.new();material.shader=Atlas.CappedModular;return material
func receiver(owner:Dictionary)->Dictionary:
    var material=ShaderMaterial.new();material.shader=Atlas.ModularReceiver
    return {"entry":owner,"material":material,"version":-1,"source_shader":null,"crop":{"uv":Vector4(0,0,1,1),"pixels":Rect2i(0,0,128,128)},"visibility":1.0,"join_mask":0}
func compare(label:String,expect_frame:bool)->void:
    atlas.last_reconcile_phases={}
    var full:bool=atlas._copy_parameters(group)
    atlas._copy_output_source(entry)
    # The reference deliberately invalidates its destination ownership and
    # receives the complete source state after the same real uniform changes.
    full_entry.material=entry.material;full_entry.source_version=entry.source_version
    full_entry.node.mesh.size=entry.node.mesh.size
    full_entry.erase("received_source_key");full_group.version=-1
    reference._copy_parameters(full_group);reference._copy_output_source(full_entry)
    check(full!=expect_frame,label+": receiver uses the required full/frame path")
    for pair in [[group.material,full_group.material],[entry.received_material,full_entry.received_material]]:
        for uniform in pair[0].shader.get_shader_uniform_list():
            check(pair[0].get_shader_parameter(uniform.name)==pair[1].get_shader_parameter(uniform.name),label+": complete destination equality "+str(uniform.name))
    if expect_frame:check(atlas.last_reconcile_phases.get("material_frame_copies",0)==2,label+": both receiving destinations accept the exact frame delta")
func frame_delta(skip:int=1)->void:
    var previous:int=entry.source_version;entry.source_version+=skip
    entry.source_frame_change={"base_version":entry.source_version-1,"version":entry.source_version,"source":entry.material,"shader":entry.material.shader}
    entry.material.set_shader_parameter("frame_uv",Vector4(float(entry.source_version)/16.0,.25,.0625,.125))
func run()->void:
    atlas.light_cap=1.0;reference.light_cap=1.0
    var material=ShaderMaterial.new();material.shader=Source
    material.set_shader_parameter("frame_uv",Vector4(0,0,.0625,.125))
    material.set_shader_parameter("source_tint",Color(.6,.8,.7,1))
    material.set_shader_parameter("condition_alpha",.55)
    material.set_shader_parameter("component_units",.125)
    material.set_shader_parameter("component_depth_range",Vector2(-16,64))
    material.set_shader_parameter("native_body_strength",.37)
    material.set_shader_parameter("effect_palette_enabled",false)
    var node=MeshInstance3D.new();node.mesh=QuadMesh.new();node.mesh.size=Vector2(2,2)
    entry={"node":node,"material":material,"source_version":1,"received_material":output(),"role":"body","placement":{"kind":"actor"}}
    var full_node=MeshInstance3D.new();full_node.mesh=QuadMesh.new();full_node.mesh.size=node.mesh.size
    full_entry=entry.duplicate();full_entry.node=full_node;full_entry.received_material=output()
    group=receiver(entry);full_group=receiver(full_entry)
    compare("Initial source",false)
    frame_delta();compare("Consecutive ordinary frame",true)
    frame_delta(2);entry.material.set_shader_parameter("condition_alpha",.9);compare("Missed version restores all state",false)
    frame_delta();compare("Frame after catch-up",true)
    entry.source_version+=1;entry.material.set_shader_parameter("component_units",.25);compare("Untagged geometry change",false)
    entry.source_version+=1;entry.material.set_shader_parameter("flash_strength",.8);compare("Clocked material change",false)
    frame_delta();entry.material.shader=Source.duplicate();compare("Source shader replacement",false)
    frame_delta();entry.received_material=output();group.material=receiver(entry).material;compare("Destination replacement",false)
    # A receiver unseen during the previous version must never accept a delta.
    group.version=-1;entry.erase("received_source_key");compare("New receiver at current frame",false)
    frame_delta();entry.material=entry.material.duplicate();compare("Source material replacement",false)
    frame_delta();compare("Next frame on replacement",true)
    frame_delta();entry.node.mesh.size=Vector2(3,2)
    atlas._copy_output_source(entry)
    check(entry.received_material.get_shader_parameter("source_quad_size")==entry.node.mesh.size,"Changed quad geometry forces complete output binding")
    node.free();full_node.free()
    var report={"checks":checks,"failures":failures,"scope":"Headless actual modular/receiving shader uniform parity against complete source copies. Native pixels and performance are separately qualified."}
    FileAccess.open("res://.runtime/native-atlas-frame-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_ATLAS_FRAME ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
