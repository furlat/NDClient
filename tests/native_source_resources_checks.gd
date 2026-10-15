extends SceneTree
const Programs=preload("res://assets/native_effects/sandbox/projectiles/factory/core/native_source_resources.gd")
const Resources=preload("res://assets/native_effects/sandbox/projectiles/factory/core/resource_graph.gd")
const Factory=preload("res://presentation/native_factory_source.gd")
const ICE="res://assets/native_effects/sandbox/projectiles/library/lelu/pack_lelu_godot_patreons_community_pack_3_d/VFX/Scenes/VFX_IceHit_T1.tscn"
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr(label)
func run()->void:
    var shader=Shader.new()
    shader.code="shader_type spatial; uniform sampler2D source_image; uniform float gain=1.0; void fragment(){ALBEDO=texture(source_image,UV).rgb*gain+vec3(TIME*0.01); }"
    var image=Image.create(2,2,false,Image.FORMAT_RGBA8);image.fill(Color.RED)
    var image_b=Image.create(2,2,false,Image.FORMAT_RGBA8);image_b.fill(Color.BLUE)
    var texture=ImageTexture.create_from_image(image)
    var texture_b=ImageTexture.create_from_image(image_b)
    shader.set_default_texture_parameter("source_image",texture)
    var a=ShaderMaterial.new();a.shader=shader;a.set_shader_parameter("gain",.25)
    var b=ShaderMaterial.new();b.shader=shader;b.set_shader_parameter("gain",.75)
    b.set_shader_parameter("source_image",texture_b)
    var original_code:String=shader.code
    check(Programs.apply_clock(a,"source_clock",true),"First private material is clocked")
    check(Programs.apply_clock(b,"source_clock",true),"Second private material is clocked")
    check(is_same(a.shader,b.shader),"Identical immutable translated programs are shared")
    check(not is_same(a,b),"Material owners remain distinct")
    check(a.get_shader_parameter("source_image")==texture,"Default source texture becomes private material binding")
    check(b.get_shader_parameter("source_image")==texture_b,"Explicit instance texture survives translation")
    a.set_shader_parameter("source_clock",.3);b.set_shader_parameter("source_clock",.9)
    check(a.get_shader_parameter("source_clock")==.3 and b.get_shader_parameter("source_clock")==.9,"Per-occurrence source clocks remain independent")
    check(a.get_shader_parameter("gain")==.25 and b.get_shader_parameter("gain")==.75,"Per-occurrence uniform values remain independent")
    check(shader.code==original_code,"Original program is unchanged")
    check(not Programs.apply_clock(a,"source_clock",true),"Already clocked program is not transformed twice")
    var graph=VisualShader.new()
    var colour=VisualShaderNodeColorConstant.new();colour.constant=Color.CORAL
    graph.add_node(VisualShader.TYPE_FRAGMENT,colour,Vector2.ZERO,2)
    var source=ShaderMaterial.new();source.shader=graph
    var ordinary:ShaderMaterial=Resources.clone_value(source,{})
    var clock_only:ShaderMaterial=Resources.clone_value(source,{"share_shader_programs":true})
    check(not is_same(ordinary.shader,graph),"Unproven/recoloring adapter keeps a private mutable graph")
    check(is_same(clock_only.shader,graph) and not is_same(clock_only,source),"Explicit clock-only policy shares program but owns material")
    ordinary.shader.get_node(VisualShader.TYPE_FRAGMENT,2).constant=Color.GREEN
    check(colour.constant==Color.CORAL,"Recoloring private graph cannot poison the source")
    var scene:PackedScene=load(ICE)
    var full:Node3D=scene.instantiate()
    var original:GPUParticles3D=full.get_node("debirs")
    var leaf:GPUParticles3D=Programs.particle_leaf(scene,NodePath("debirs"))
    check(leaf!=null,"Exact authored debris leaf can be constructed without siblings")
    if leaf!=null:
        for field in original.get_property_list():
            if not int(field.usage)&PROPERTY_USAGE_STORAGE or str(field.name) in ["name","owner","unique_name_in_owner"]:continue
            check(original.get(field.name)==leaf.get(field.name),"Debris authored property preserved: "+str(field.name))
        check(leaf.get_child_count()==0,"Leaf introduces no extra scene graph")
        leaf.free()
    full.free()
    var code_a="shader_type spatial; void fragment(){ALBEDO=vec3(.1234);}"
    var code_b="shader_type spatial; void fragment(){ALBEDO=vec3(.5678);}"
    Programs.last_compile_frame=-1
    var first:int=Programs.prepare({code_a:true,code_b:true})
    check(first==1,"One new program is prepared per frame")
    check(Programs.prepare({code_a:true,code_b:true})==1,"Repeated readiness queries cannot multiply the frame budget")
    check(Programs.prepare({code_a:true})==0,"Optional pending program cannot gate an unrelated required set")
    var previous_frame:int=Engine.get_process_frames()
    while Engine.get_process_frames()==previous_frame:await process_frame
    check(Programs.prepare({code_a:true,code_b:true})==0,"Following frame completes the remaining program")
    previous_frame=Engine.get_process_frames()
    while Engine.get_process_frames()==previous_frame:await process_frame
    check(Programs.reserve_discovery(),"A new scene descriptor may be discovered in its own frame")
    check(not Programs.reserve_discovery(),"Repeated callers cannot multiply descriptor discovery")
    var code_c="shader_type spatial; void fragment(){ALBEDO=vec3(.9012);}"
    check(Programs.prepare({code_c:true})==1,"Descriptor discovery and program compilation share one frame budget")
    check(Factory.resource_paths({"components":[{"input":{"scene":"res://example.tscn","fragment_scene":ICE}}]}).has(ICE),"Declared secondary particle scene belongs to threaded resource preparation")
    var input={"settings":{},"scene":"example"}
    var spec={"script":"res://assets/native_effects/sandbox/projectiles/factory/components/recipient/chill_hand.gd","input":input}
    check(not Factory._constructor_input(spec).get("share_shader_programs",false),"Chill recoloring is excluded from immutable graph policy")
    check(not input.has("share_shader_programs"),"Factory leaves admitted input unchanged")
    var result={"checks":checks,"passed":checks-failures.size(),"failures":failures}
    FileAccess.open("res://generated/native_source_resources_checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("NATIVE_SOURCE_RESOURCES_CHECKS ",JSON.stringify(result))
    quit(0 if failures.is_empty() else 1)
