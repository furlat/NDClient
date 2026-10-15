extends SceneTree
## PackedScene is the ownership boundary: sharing immutable source data must
## never let one occurrence's authored write change another occurrence.
const Variants=preload("res://presentation/native_source_variants.gd")
var checks:int=0
var failures:Array=[]
var owner:Node3D

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("CONSTANT_RESOURCE_FAIL ",label)

func pair(mode:String="",property:String="")->Array:
    var source=Node3D.new();source.name="Source"
    var geometry=MeshInstance3D.new();geometry.name="Mesh";source.add_child(geometry);geometry.owner=source
    var mesh=ArrayMesh.new();var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP])
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);geometry.mesh=mesh
    var curve=Curve.new();curve.add_point(Vector2(0,.25));curve.add_point(Vector2(1,.75))
    var curve_texture=CurveTexture.new();curve_texture.width=32;curve_texture.curve=curve
    var gradient=Gradient.new();gradient.set_color(0,Color.RED);gradient.set_color(1,Color.BLUE)
    var gradient_texture=GradientTexture1D.new();gradient_texture.width=16;gradient_texture.gradient=gradient
    var noise=NoiseTexture2D.new();noise.width=16;noise.height=16
    noise.noise=FastNoiseLite.new();noise.noise.seed=42;noise.color_ramp=Gradient.new()
    var material=ShaderMaterial.new();var shader=Shader.new()
    shader.code="shader_type spatial; uniform sampler2D curve_data; uniform sampler2D gradient_data; uniform sampler2D noise_data; uniform float clock=0.0; void fragment(){ ALBEDO=vec3(1.0); }"
    material.shader=shader;material.set_shader_parameter("curve_data",curve_texture)
    material.set_shader_parameter("gradient_data",gradient_texture);material.set_shader_parameter("noise_data",noise)
    material.set_shader_parameter("clock",0.0);geometry.material_override=material
    if mode=="embedded":mesh.surface_set_material(0,material)
    var animation=Animation.new();animation.length=1.0
    var track:int=animation.add_track(Animation.TYPE_METHOD if mode=="method" else Animation.TYPE_VALUE)
    var path:String="Mesh:position"
    if mode=="unresolved_animation":path="Missing:mesh:custom_aabb"
    elif mode in ["resource_key","nested_resource_key"]:path="Mesh:material_override"
    elif mode=="animated_curve":path="Mesh:material_override:shader_parameter/curve_data:curve:max_value"
    elif mode=="method":path="Mesh"
    animation.track_set_path(track,NodePath(path))
    var key_material=ShaderMaterial.new();key_material.shader=shader;key_material.set_shader_parameter("clock",0.0)
    if mode=="method":animation.track_insert_key(track,0,{"method":"hide","args":[]})
    elif mode=="resource_key":animation.track_insert_key(track,0,key_material)
    elif mode=="nested_resource_key":animation.track_insert_key(track,0,{"future":[{"material":key_material}]})
    elif mode=="animated_curve":
        animation.track_insert_key(track,0,1.0);animation.track_insert_key(track,1,2.0)
    else:
        animation.track_insert_key(track,0,Vector3.ZERO);animation.track_insert_key(track,1,Vector3.RIGHT)
    var library=AnimationLibrary.new();library.add_animation("motion",animation)
    var player=AnimationPlayer.new();player.name="Player";player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    source.add_child(player);player.owner=source;player.add_animation_library("",library)
    if mode=="unknown":
        var driver=Node3D.new();driver.name="Driver";var script=GDScript.new()
        script.source_code="extends Node3D\n";script.reload();driver.set_script(script)
        source.add_child(driver);driver.owner=source
    var resources:Dictionary={}
    for resource in [mesh,material,curve_texture,curve,gradient_texture,gradient,noise,noise.noise,noise.color_ramp,library,animation,key_material]:
        resource.resource_local_to_scene=true;resources[resource]=true
    var spec:Dictionary={"id":"phase","script":Variants.PREFIX+"recipient/clocked_source.gd"}
    var clip:Dictionary={"property_overrides":[]}
    if not property.is_empty():clip.property_overrides.append({"node":"phase/Mesh","property":property,"value":0})
    spec=Variants.component_spec(spec,clip)
    Variants._share_constant_noise(source,spec,resources)
    Variants._share_constant_data(source,spec,resources)
    var packed=PackedScene.new();check(packed.pack(source)==OK,mode+" source packs")
    var a:Node3D=packed.instantiate();var b:Node3D=packed.instantiate()
    owner.add_child(a);owner.add_child(b);source.free()
    return [a,b]

func resource(node:Node3D,name:String)->Resource:
    return node.get_node("Mesh").material_override.get_shader_parameter(name)

func release(nodes:Array)->void:
    for node in nodes:node.free()

func immutable_case()->void:
    var nodes:Array=pair();var a:Node3D=nodes[0];var b:Node3D=nodes[1]
    check(is_same(a.get_node("Mesh").mesh,b.get_node("Mesh").mesh),"Read-only material-free ArrayMesh is reused")
    for field in ["curve_data","gradient_data","noise_data"]:
        check(is_same(resource(a,field),resource(b,field)),"Read-only texture is reused: "+field)
    check(is_same(a.get_node("Player").get_animation("motion"),b.get_node("Player").get_animation("motion")),
        "Scalar/vector-only animation data is reused")
    check(not is_same(a.get_node("Mesh").material_override,b.get_node("Mesh").material_override),"Mutable shader parameters stay private")
    a.get_node("Mesh").material_override.set_shader_parameter("clock",3.0)
    check(b.get_node("Mesh").material_override.get_shader_parameter("clock")==0.0,"A material clock write cannot alter its peer")
    for node in nodes:node.get_node("Player").play("motion")
    a.get_node("Player").advance(.75);b.get_node("Player").advance(.25)
    check(is_equal_approx(a.get_node("Mesh").position.x,.75) and is_equal_approx(b.get_node("Mesh").position.x,.25),
        "Shared animation data still drives independent actual player clocks and node poses")
    release(nodes)

func override_cases()->void:
    var cases:Array=[
        {"property":"material_override:shader_parameter/noise_data:noise:seed","value":731,"field":"noise_data"},
        {"property":"material_override:shader_parameter/noise_data:color_ramp:colors","value":PackedColorArray([Color.GREEN,Color.WHITE]),"field":"noise_data"},
        {"property":"material_override:shader_parameter/curve_data:curve:max_value","value":2.0,"field":"curve_data"},
        {"property":"material_override:shader_parameter/gradient_data:gradient:colors","value":PackedColorArray([Color.GREEN,Color.WHITE]),"field":"gradient_data"},
        {"property":"mesh:custom_aabb","value":AABB(Vector3(-1,-1,-1),Vector3(3,3,3)),"field":"mesh"}]
    for item in cases:
        var nodes:Array=pair("override",item.property);var a:Node3D=nodes[0];var b:Node3D=nodes[1]
        var path=NodePath(item.property);var before:Variant=b.get_node("Mesh").get_indexed(path)
        a.get_node("Mesh").set_indexed(path,item.value)
        check(a.get_node("Mesh").get_indexed(path)==item.value,"Authored indexed override reaches its target: "+item.property)
        check(b.get_node("Mesh").get_indexed(path)==before,"Authored write leaves the second instance unchanged: "+item.property)
        var one:Resource=a.get_node("Mesh").mesh if item.field=="mesh" else resource(a,item.field)
        var two:Resource=b.get_node("Mesh").mesh if item.field=="mesh" else resource(b,item.field)
        check(not is_same(one,two),"Written resource owner stays private: "+item.property)
        release(nodes)
    var nodes:Array=pair("animated_curve")
    nodes[0].get_node("Player").play("motion");nodes[0].get_node("Player").advance(.75)
    check(is_equal_approx(resource(nodes[0],"curve_data").curve.max_value,1.75)
        and is_equal_approx(resource(nodes[1],"curve_data").curve.max_value,1.0),
        "Actual animation resource writes leave the unsampled peer unchanged")
    release(nodes)

func denied_cases()->void:
    for mode in ["method","unknown","unresolved_animation","unresolved_override","resource_key","nested_resource_key"]:
        var nodes:Array=pair(mode,"material_override:shader_parameter/missing:curve:max_value" if mode=="unresolved_override" else "")
        var a:Node3D=nodes[0];var b:Node3D=nodes[1]
        check(not is_same(a.get_node("Mesh").mesh,b.get_node("Mesh").mesh),mode+" retains private mesh ownership")
        resource(a,"curve_data").curve.set_point_value(0,.9)
        check(is_equal_approx(resource(b,"curve_data").curve.get_point_position(0).y,.25),mode+" cannot leak mutable curve contents")
        resource(a,"noise_data").noise.seed=999
        check(resource(b,"noise_data").noise.seed==42,mode+" cannot leak noise writes")
        if mode in ["resource_key","nested_resource_key"]:
            var value_a:Variant=a.get_node("Player").get_animation("motion").track_get_key_value(0,0)
            var value_b:Variant=b.get_node("Player").get_animation("motion").track_get_key_value(0,0)
            var material_a:ShaderMaterial=value_a if mode=="resource_key" else value_a.future[0].material
            var material_b:ShaderMaterial=value_b if mode=="resource_key" else value_b.future[0].material
            material_a.set_shader_parameter("clock",7.0)
            check(material_b.get_shader_parameter("clock")==0.0,mode+" keeps resources inside animation keys private")
        release(nodes)
    var nodes:Array=pair("embedded")
    check(not is_same(nodes[0].get_node("Mesh").mesh,nodes[1].get_node("Mesh").mesh),"Mesh with embedded mutable material remains private")
    nodes[0].get_node("Mesh").mesh.surface_get_material(0).set_shader_parameter("clock",9.0)
    check(nodes[1].get_node("Mesh").mesh.surface_get_material(0).get_shader_parameter("clock")==0.0,"Embedded material write cannot change a peer")
    release(nodes)

func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    owner=Node3D.new();owner.hide();root.add_child(owner)
    immutable_case();override_cases();denied_cases()
    owner.free()
    var report={"checks":checks,"failures":failures,"scope":"Real PackedScene peer ownership under immutable source admission; actual node/animation/indexed resource writes, allowed data reuse and unsafe authoring rejection. No pixel or performance claim."}
    FileAccess.open("res://.runtime/native-constant-resource-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("CONSTANT_RESOURCE_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
