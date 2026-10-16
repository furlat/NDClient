extends SceneTree
## Material-only fixture for shape ownership; actual Web is tested separately.
const Mask=preload("res://presentation/native_area_mask.gd")
var checks=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr(label)
func source()->Dictionary:
    var node=MeshInstance3D.new();node.mesh=QuadMesh.new()
    var shader=Shader.new();shader.code="shader_type spatial; void fragment(){ALBEDO=vec3(1.0);}"
    var material=ShaderMaterial.new();material.shader=shader;node.material_override=material
    return {"geometry":[{"node":node,"path":"fixture"}]}
func run()->void:
    var handle=source();var peer=source()
    var material:ShaderMaterial=handle.geometry[0].node.material_override
    var a:Array=[[0,0],[1,0]];var b:Array=[[0,0]];var later:Array=[[8,8]]
    check(Mask.prepare(handle,a).ready and Mask.publish(handle,a).ready,"Initial prepared footprint publishes")
    var original:Texture2D=material.get_shader_parameter("native_area_cells")
    check(Mask.prepare(handle,later).ready and Mask.prepare(handle,b).ready,"Optional later footprint may be prepared before newly required cut")
    check(material.get_shader_parameter("native_area_cells")==original,"Neither preparation changes current coverage")
    check(Mask.publish(handle,b).ready and Mask.prepared(handle,later),"Publishing required shape preserves earlier-prepared future shape")
    Mask.prepare(handle,a)
    check(Mask.publish(handle,a).ready and Mask.prepared(handle,later),"Returning to a previous shape preserves later cue interest")
    var current:Texture2D=material.get_shader_parameter("native_area_cells")
    Mask.prepare(handle,[[77,77]])
    Mask.retain(handle,[later])
    check(not Mask.prepared(handle,[[77,77]]) and Mask.prepared(handle,later),"Interest cancellation removes only unowned pending shape")
    check(material.get_shader_parameter("native_area_cells")==current,"Pending retirement cannot change displayed shape")
    Mask.prepare(peer,[[-3,-3]]);Mask.publish(peer,[[-3,-3]])
    var peer_texture:Texture2D=peer.geometry[0].node.material_override.get_shader_parameter("native_area_cells")
    check(Mask.publish(handle,later).ready,"Future cue remains publishable without another preparation")
    var shown:Texture2D=material.get_shader_parameter("native_area_cells")
    check(not Mask.publish(handle,later).changed and material.get_shader_parameter("native_area_cells")==shown,"Repeated publication reuses its admitted image")
    check(not Mask.publish(handle,[[99,99]]).ready and material.get_shader_parameter("native_area_cells")==shown,"Missing shape fails before changing displayed coverage")
    check(peer.geometry[0].node.material_override.get_shader_parameter("native_area_cells")==peer_texture,"Another occurrence owns independent coverage")
    handle.geometry[0].node.free();peer.geometry[0].node.free()
    print("NATIVE_AREA_MASK_OWNERSHIP ",JSON.stringify({"checks":checks,"failures":failures,"scope":"Headless material-only shape ownership and out-of-order preparation; no real-source or rendered-coverage claim."}))
    quit(0 if failures.is_empty() else 1)
