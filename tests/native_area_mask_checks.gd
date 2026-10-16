extends SceneTree
const Factory=preload("res://presentation/native_factory_source.gd")
const Mask=preload("res://presentation/native_area_mask.gd")
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("NATIVE_AREA_MASK_FAIL ",label)
func run()->void:
    var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://authoring/sandbox/projectiles.json"))
    var spell:Dictionary=manifest.spells.filter(func(value):return value.id=="web")[0]
    var clip:Dictionary=spell.clips.filter(func(value):return value.id=="spells/web/ground/lifecycle")[0]
    var cache:Dictionary={}
    var admission:Dictionary=Factory.prepare([clip],cache)
    var deadline:int=Time.get_ticks_msec()+20000
    while not admission.ready and admission.errors.is_empty() and Time.get_ticks_msec()<deadline:
        await process_frame
        admission=Factory.prepare([clip],cache)
    check(admission.ready,"Actual native source admitted through production preparation")
    if not admission.ready:print(admission);quit(1);return
    var owner=Node3D.new();root.add_child(owner)
    var source=Factory.make(owner,clip.duplicate(true));var peer=Factory.make(owner,clip.duplicate(true))
    check(source.error.is_empty() and peer.error.is_empty(),"The actual imported native Web source constructs in both owners")
    if not source.error.is_empty() or not peer.error.is_empty():
        print(source.error,peer.error);Factory.close(source);Factory.close(peer);owner.free();quit(1);return
    var preserved:Dictionary={}
    for piece in source.geometry:
        if piece.node is MeshInstance3D:
            var material:Material=piece.node.get_active_material(0)
            if material is ShaderMaterial:
                var values:Dictionary={}
                for uniform in material.shader.get_shader_uniform_list():values[uniform.name]=material.get_shader_parameter(uniform.name)
                preserved[material]=values
    var positions:Array=[[-2,-1],[-1,-1],[0,-1],[-2,0],[0,0],[-2,1],[-1,1],[0,1]]
    var configured=Mask.configure(source,positions)
    check(configured.ready,"Every admitted actual Web material accepts the disclosed-cell shader")
    if not configured.ready:print(configured)
    check(source.area_mask.materials.size()>0,"The actual Web has masked native materials")
    for material in source.area_mask.materials:
        var uniforms:Array=material.shader.get_shader_uniform_list().map(func(value):return value.name)
        for name in ["native_area_cells","native_area_origin","native_area_size"]:check(name in uniforms,"Native shader compiles its exact cell mask input: "+name)
        for name in preserved.get(material,{}):check(material.get_shader_parameter(name)==preserved[material][name],"Native material value is preserved: "+name)
    var state:Dictionary=source.area_mask
    check(state.origin==Vector2(-2,-1) and state.size==Vector2(3,3),"Negative world cells retain their exact centered-grid bounds")
    for y in 3:
        for x in 3:check((state.image.get_pixel(x,y).r>.5)==(x!=1 or y!=1),"Only disclosed unsuppressed Web cells admit native fragments: %d,%d"%[x,y])
    var texture:Texture2D=state.texture
    check(not Mask.update(source,positions).changed and state.texture==texture,"Unchanged disclosure performs no texture replacement")
    var peer_result=Mask.configure(peer,[[7,9]])
    check(peer_result.ready and peer.area_mask.texture!=texture,"Another source occurrence has a private spatial mask")
    var material:ShaderMaterial=state.materials[0]
    var old_bound:Texture2D=material.get_shader_parameter("native_area_cells")
    var pending=Mask.prepare(source,[[-2,-1]])
    check(pending.ready and state.texture==texture and material.get_shader_parameter("native_area_cells")==old_bound,
        "Preparing later suppression leaves the displayed mask and material unchanged")
    var absent=Mask.publish(source,[[99,99]])
    check(not absent.ready and state.texture==texture,"An unprepared cut is rejected without changing current coverage")
    var prepared_texture:Texture2D=state.prepared[0].texture
    Mask.publish(source,[[-2,-1]])
    check(state.texture==prepared_texture and material.get_shader_parameter("native_area_cells")==prepared_texture,
        "Publication adopts the exact prepared texture without allocating a replacement")
    check(peer.area_mask.positions==[[7,9]] and peer.area_mask.origin==Vector2(7,9),"A suppression update does not alter another occurrence")
    var future:Array=[[8,8]]
    var returning:Array=positions
    Mask.prepare(source,future)
    Mask.prepare(source,returning)
    Mask.publish(source,returning)
    check(Mask.prepared(source,future),"Publishing a returning shape preserves a later cue prepared earlier")
    var future_texture:Texture2D=state.prepared[0].texture
    Mask.retain(source,[future])
    check(state.prepared.size()==1 and state.texture!=future_texture,"Current coverage and named future interest have independent ownership")
    Mask.prepare(source,[[77,77]])
    Mask.retain(source,[future])
    check(not Mask.prepared(source,[[77,77]]) and Mask.prepared(source,future),"Cancelled shape releases only its own future interest")
    Mask.publish(source,future)
    check(state.texture==future_texture,"Later cue reuses its original prepared image after returning footprint")
    Mask.update(source,[])
    check(source.area_mask.image.get_pixel(0,0).r==0,"No disclosed cells yields zero native coverage")
    Factory.close(source)
    check(is_instance_valid(peer.root) and peer.area_mask.materials.size()>0,"Retiring one masked source leaves its peer intact")
    Factory.close(peer);owner.free()
    var report={"checks":checks,"failed":failures.size(),"failures":failures,"scope":"Actual imported Web materials and shader inputs, preserved native values, exact disclosed-cell mask, suppression and occurrence ownership. Headless shader admission is not a framebuffer coverage claim."}
    FileAccess.open("res://.runtime/native-area-mask-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_AREA_MASK ",JSON.stringify({"checks":checks,"failed":failures.size(),"failures":failures}))
    quit(0 if failures.is_empty() else 1)
