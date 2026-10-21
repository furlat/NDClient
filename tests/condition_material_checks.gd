extends SceneTree
## Native shader/helper output against the unchanged Pygame operator's pixels.
## Generate oracle.json with tests/prepare_condition_material_oracle.py first.
const Conditions=preload("res://presentation/conditions.gd")
const Outline=preload("res://presentation/condition_outline.gd")
const Catalog=preload("res://source_catalog.gd")
const SourceMaterial=preload("res://presentation/source_material.gd")
class OutlineWorld extends Node3D:
    const Characters=preload("res://presentation/characters.gd")
    var visual_actors={}
    var rigs={}
    var actor_entries:Array=[]
    var draw_order_dirty=false
var checks=0
var failures:Array=[]
var evidence:Array=[]
var directory=""
var output="res://generated/condition_material_checks.json"
var cache={}
var resources={}
var textures={}

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("CONDITION_MATERIAL_FAIL ",label)
func load_image(path:String)->Image:
    return Image.load_from_file(directory.path_join(path))
func page(size:Vector2i)->SubViewport:
    var viewport=SubViewport.new();viewport.size=size;viewport.transparent_bg=true
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
    return viewport
func capture(view:SubViewport)->Image:
    await process_frame;await RenderingServer.frame_post_draw
    return view.get_texture().get_image()
func difference(actual:Image,expected:Image)->Dictionary:
    if actual.get_size()!=expected.get_size():return {"size_error":true,"changed":-1,"alpha":-1,"maximum":256}
    var result={"changed":0,"alpha":0,"maximum":0,"maximum_rgb":0,"maximum_alpha":0,"coverage":0,"channel_error_counts":{},"first":[]}
    var a=actual.get_data();var b=expected.get_data()
    for i in range(0,a.size(),4):
        var changed=false
        for c in 4:
            var error=absi(a[i+c]-b[i+c]);result.maximum=maxi(result.maximum,error)
            if c==3:result.maximum_alpha=maxi(result.maximum_alpha,error)
            else:result.maximum_rgb=maxi(result.maximum_rgb,error)
            if error>0:
                var key=str(c)+":"+str(error)
                result.channel_error_counts[key]=result.channel_error_counts.get(key,0)+1
            if error>0:changed=true
        if changed:
            result.changed+=1
            if result.first.size()<8:result.first.append({"x":(i/4)%actual.get_width(),"y":(i/4)/actual.get_width(),"actual":Array(a.slice(i,i+4)),"expected":Array(b.slice(i,i+4))})
        if a[i+3]!=b[i+3]:result.alpha+=1
        if (a[i+3]>0)!=(b[i+3]>0):result.coverage+=1
    return result
func sample_for(row:Dictionary,recipe:Dictionary)->Dictionary:
    return {"id":"condition:fixture","kind":"condition","actor_uuid":"fixture","condition_uuid":"fixture",
        "source":row.recipe_id,"recipe":recipe,"alpha":1.0,"age_ms":row.age_ms,"initial":row.get("initial",false)}

func material_case(row:Dictionary,source:Image)->void:
    var recipe:Dictionary=Catalog.read_file("catalog/condition_recipes.json",cache)[row.recipe_id].duplicate(true)
    if row.kind=="colour":recipe.persistent.erase("bodyRamp")
    elif row.has("texture_fps"):recipe.persistent.bodyRamp.textureFps=row.texture_fps
    var samples=[sample_for(row,recipe)]
    var state=Conditions.material("fixture",samples)
    var viewport=page(source.get_size());viewport.disable_3d=true
    var node=Sprite2D.new();node.centered=false;node.texture=ImageTexture.create_from_image(source)
    node.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    var shader=Shader.new()
    shader.code="shader_type canvas_item;render_mode unshaded,blend_disabled;\n#include \"res://presentation/character_material.gdshaderinc\"\nvoid fragment(){vec4 source=texture(TEXTURE,UV);COLOR=character_material(source,UV,source.rgb);}"
    var material=ShaderMaterial.new();material.shader=shader;node.material=material;viewport.add_child(node)
    Conditions.bind(material,state,textures,resources)
    var image=await capture(viewport)
    var expected=load_image(row.expected)
    var comparison=difference(image,expected)
    evidence.append({"name":row.name,"comparison":comparison})
    # The initial strict report is retained. Root accepted the demonstrated
    # final UNORM/native precision bound for film only; coverage stays exact.
    check(comparison.maximum<=1 and comparison.coverage==0 if row.kind=="film" else comparison.changed==0,
        row.name+" original Pygame operator: film≤1byte and exact coverage; colour exact")
    image.save_png(directory.path_join(row.name+"-actual.png"))
    if row.kind=="colour" and row.recipe_id=="condition.poisoned":
        var duplicate=samples[0].duplicate();duplicate.condition_uuid="second-owner"
        Conditions.bind(material,Conditions.material("fixture",[samples[0],duplicate]),textures,resources)
        check(difference(await capture(viewport),image).changed==0,"Two same-recipe owners apply the material once")
        var flash={"kind":"material_flash","actor_uuid":"fixture","age_ms":25.0,"duration_ms":150.0,"colors":[0xffeeaa,0xff7744]}
        Conditions.bind(material,Conditions.material("fixture",[samples[0],flash]),textures,resources)
        check(difference(await capture(viewport),image).changed>0,"Independent hit material visibly overlaps the active condition")
        Conditions.bind(material,Conditions.material("fixture",samples),textures,resources)
        check(difference(await capture(viewport),image).changed==0,"Flash expiry restores the still-active condition exactly")
        Conditions.bind(material,Conditions.material("fixture",[]),textures,resources)
        check(difference(await capture(viewport),source).changed==0,"Last condition removal restores original source bytes")
    viewport.free()

func spatial_page()->Dictionary:
    var viewport=page(Vector2i(128,128));viewport.own_world_3d=true
    var owner=OutlineWorld.new();viewport.add_child(owner)
    var camera=Camera3D.new();owner.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    camera.size=2;camera.position=Vector3(0,0,3);camera.current=true;camera.cull_mask=1
    return {"view":viewport,"world":owner}
func outline_case(row:Dictionary)->void:
    var scene=spatial_page();var owner:OutlineWorld=scene.world
    owner.rigs={"fixture":{"cell_width":128,"cell_height":128}}
    var parts:Array=[]
    var source_shader=Shader.new();source_shader.code="shader_type spatial;uniform sampler2D sheet;uniform vec4 frame_uv;void fragment(){ALBEDO=vec3(1.); }"
    for i in 2:
        var node=MeshInstance3D.new();node.mesh=QuadMesh.new();node.mesh.size=Vector2(2,2);node.layers=2;owner.add_child(node)
        var material=ShaderMaterial.new();material.shader=source_shader
        node.material_override=material
        var part:Dictionary={"id":"fixture:part:"+str(i),"node":node,"material":material,"role":"actor","texture_path":"part"+str(i),"actor_layer":{"slot":"body" if i==0 else "chest","alpha":1.0}}
        SourceMaterial.initialize(part)
        SourceMaterial.apply(part,{"sheet":ImageTexture.create_from_image(load_image("part"+str(i)+".png")),"frame_uv":Vector4(0,0,1,1)})
        parts.append(part)
    owner.visual_actors={"fixture":{"row":{"id":"fixture","rig":"fixture"},"entries":parts}}
    var recipe=Catalog.read_file("catalog/condition_recipes.json",cache)[row.recipe_id]
    var state=Conditions.material("fixture",[sample_for(row,recipe)])
    var helper=Outline.new()
    # The ordinary renderer prepares its assembled-alpha owner before sampling.
    # Wait on that exact existing draw boundary, not on an invented timer/pose.
    var ready:bool=false;var deadline:int=Time.get_ticks_msec()+10000
    while not ready and Time.get_ticks_msec()<deadline:
        ready=helper.prepare(owner,"fixture").ready
        if not ready:await capture(scene.view)
    check(ready and helper.sample(owner,"fixture",state),row.name+" actual outline owner is prepared before its authored sample")
    if not ready:
        helper.close(owner);scene.view.free();return
    var image=await capture(scene.view)
    var reference=spatial_page()
    var quad=MeshInstance3D.new();quad.mesh=QuadMesh.new();quad.mesh.size=Vector2(2,2);reference.world.add_child(quad)
    var shader=Shader.new();shader.code="shader_type spatial;render_mode unshaded,cull_disabled,depth_test_disabled;uniform sampler2D sheet:source_color,filter_nearest;void fragment(){vec4 c=texture(sheet,UV);ALBEDO=c.rgb;ALPHA=c.a;}"
    var material=ShaderMaterial.new();material.shader=shader
    material.set_shader_parameter("sheet",ImageTexture.create_from_image(load_image(row.expected)));quad.material_override=material
    var expected=await capture(reference.view)
    var comparison=difference(image,expected)
    check(comparison.maximum_rgb<=1 and comparison.alpha==0 and comparison.coverage==0,
        row.name+" assembled original Pygame contour/pulse: exact alpha/mask, native RGB≤1byte")
    evidence.append({"name":row.name,"comparison":comparison})
    image.save_png(directory.path_join(row.name+"-actual.png"));expected.save_png(directory.path_join(row.name+"-native-reference.png"))
    helper.close(owner);scene.view.free();reference.view.free()

func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--oracle="):directory=argument.trim_prefix("--oracle=")
        elif argument.begins_with("--output="):output=argument.trim_prefix("--output=")
    if directory.is_empty():push_error("Explicit --oracle=<generated fixture directory> required");quit(2);return
    var oracle=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("oracle.json")))
    if oracle==null:push_error("Cannot read original operator oracle");quit(2);return
    resources=Catalog.read_file("catalog/resources.json",cache)
    var film_path:String=resources["class.material.film"]
    textures[film_path]=ImageTexture.create_from_image(Image.load_from_file(Catalog.media_path(film_path)))
    var source=load_image("source.png")
    for row in oracle.cases:
        if row.kind=="outline":await outline_case(row)
        else:await material_case(row,source)
    var report={"checks":checks,"failures":failures,"evidence":evidence,"oracle":directory,"original_source":oracle.source,
        "renderer":RenderingServer.get_current_rendering_method(),"scope":"Original Pygame function bodies; native material function before lighting, and production assembled outline helper through matched native output. Exact source colours; demonstrated≤1byte film UNORM/native RGBA bound with exact coverage; outline alpha/mask exact and native RGB≤1byte. Per-channel error distributions retained. Cap/Normals/full-scene lighting remain separate integration gates."}
    FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("CONDITION_MATERIAL ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
