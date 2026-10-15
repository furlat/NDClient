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
    var owner=Node3D.new();root.add_child(owner)
    var source=Factory.make(owner,clip.duplicate(true));var peer=Factory.make(owner,clip.duplicate(true))
    check(source.error.is_empty() and peer.error.is_empty(),"The actual imported native Web source constructs in both owners")
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
    Mask.update(source,[[-2,-1]])
    check(peer.area_mask.positions==[[7,9]] and peer.area_mask.origin==Vector2(7,9),"A suppression update does not alter another occurrence")
    Mask.update(source,[])
    check(source.area_mask.image.get_pixel(0,0).r==0,"No disclosed cells yields zero native coverage")
    Factory.close(source)
    check(is_instance_valid(peer.root) and peer.area_mask.materials.size()>0,"Retiring one masked source leaves its peer intact")
    Factory.close(peer);owner.free()
    var report={"checks":checks,"failed":failures.size(),"failures":failures,"scope":"Actual imported Web materials and shader inputs, preserved native values, exact disclosed-cell mask, suppression and occurrence ownership. Headless shader admission is not a framebuffer coverage claim."}
    FileAccess.open("res://.runtime/native-area-mask-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_AREA_MASK ",JSON.stringify({"checks":checks,"failed":failures.size(),"failures":failures}))
    quit(0 if failures.is_empty() else 1)
