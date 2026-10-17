extends SceneTree
## First actual assembled actor frame from private resources, compared with the
## ordinary source constructor/binder. Sprites light themselves from the light
## table, so the oracle is the final lit framebuffer of two otherwise identical
## views: one adopting the worker's private layers, one built directly.
const Construction=preload("res://presentation/actor_construction.gd")
const Original=preload("res://presentation/actor_construction.gd")
const Resources=preload("res://presentation/actor_resources.gd")
const SourceMaterial=preload("res://presentation/source_material.gd")
const LightTable=preload("res://presentation/light_table.gd")
const AMBIENT:=0.30
const BODY="/fixture/actor-resource-body.png"
const NOISE="/fixture/actor-resource-noise.png"
class ActorOwner extends "res://presentation/sprite_sources.gd":
    var character_light_profile:String="original"
    func texture(path:String)->Texture2D:return textures.get(path)
    func _light_entry(entry:Dictionary)->void:SourceMaterial.set_parameter(entry,"authored_base_light",0.0)
var checks:int=0
var failures:Array=[]
var cases:Dictionary={}
var light_table=LightTable.new()

func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("ACTOR_RESOURCE_FAIL ",label)

func _initialize()->void:run.call_deferred()

func actor_image()->Image:
    var image=Image.create(192,128,false,Image.FORMAT_RGBA8)
    for facing in 2:
        for frame in 3:
            var x:int=frame*64;var y:int=facing*64
            image.fill_rect(Rect2i(x+18-frame*2,y+8+facing*2,28+frame*2,45),Color8(110+frame*30,185-facing*40,75+facing*60,210))
            image.fill_rect(Rect2i(x+26,y+12,12,31),Color8(210,90+frame*20,150,255))
    return image

func geometry(owner:ActorOwner,image:Image)->void:
    var body=Construction.CharacterGeometry.BodySources
    var index=body.Index.new();var category=body.Layer.new();var clip=body.Clip.new()
    var files:Dictionary={};var normals:Dictionary={}
    for field in ["depth","normal","support","normal_valid"]:
        files[field]=field
        var original=Image.create(192,128,false,Image.FORMAT_RGBA8)
        original.fill(Color(.5,.5,1,1) if field=="normal" else Color(1,1,1,1) if field=="normal_valid" else Color(.5,0,0,1))
        owner.textures["/fixture/geometry/"+field]=ImageTexture.create_from_image(original)
    for profile in ["original","gentle","reference"]:normals[profile]="/fixture/geometry/normal"
    var source={"_source_root":"/fixture/geometry","status":"complete","files":files,"cell_size":[64,64],
        "depth_range":[-8,16],"optical_camera":{"origin":[32,48],"elevation_degrees":45},"optical_ground_pixels":19.0}
    clip.descriptors={"body":{"geometry":source,"normal_paths":normals},"shadow":{}}
    category.clip_sources={"Idle":"fixture-clip"};category.headers[BODY]={"width":192,"height":128}
    index.source_owners[BODY]=["fixture-category","Idle"]
    owner.catalog_cache[body.KEY]={"index":index,"loaded":{"fixture-category":category,"fixture-clip":clip}}
    owner.textures[BODY]=ImageTexture.create_from_image(image);owner.source_images[BODY]=image
    var noise=Image.create(64,64,false,Image.FORMAT_RGBA8);noise.fill(Color(.3,.7,.2,1))
    owner.textures[NOISE]=ImageTexture.create_from_image(noise);owner.resources.noise=NOISE

# One 3D view per side, identical except for how its actor layers were built.
func make_side(image:Image)->Dictionary:
    var view=SubViewport.new();view.size=Vector2i(256,256);view.own_world_3d=true
    view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var owner=ActorOwner.new();view.add_child(owner)
    var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    camera.size=2.0;camera.position=Vector3(0,0,10);owner.add_child(camera);camera.current=true;owner.camera=camera
    owner.rig_config={"TILE_W":128};owner.quarter=0
    owner.source_depth=true;owner.source_normals=true
    geometry(owner,image)
    return {"view":view,"owner":owner}

func source_inputs(owner:ActorOwner)->Dictionary:
    var rig={"cell_width":64,"cell_height":64,"origin_y_from_ground":19,"facing_rows":{"SW":0,"NE":1},
        "clips":{"Idle":{"fps":8,"frames":3}}}
    var row={"id":"assembled-actor","kind":"actor","rig":"fixture","position":[0,0],"base_height_steps":0,"scale":1.0,"scale_x":1.0}
    var selected:Dictionary={}
    for index in 3:
        var layer={"slot":"shadow" if index==0 else "body","alpha":.3 if index==0 else .8,"tint":0xaaaaaa if index==0 else 0xffffff if index==1 else 0x74aaff,
            "paths":{"Idle":BODY},"effect":{} if index<2 else {"palette":{"colors":[0xffffff,0x4488aa],"noiseSheet":"noise","gamma":1.2}}}
        selected[index]={"layer":layer,"frame":0,"binding":Construction.prepare_binding(rig,layer,BODY,owner.catalog_cache,true,true,"original",1.0,1.0)}
    return {row.id:{"row":row,"rig":rig,"layers":selected,"scale":1.0,"facing":"SW","quarter":0,"light_parameters":{"authored_base_light":0.0}}}

func reference_actor(owner:ActorOwner,input:Dictionary)->Array:
    var result:Array=[]
    var conditions:Dictionary=Construction.Conditions.parameters(Construction.Conditions.material(input.row.id,[]),owner.textures,owner.resources)
    conditions.make_read_only()
    for index in input.layers:
        var selected:Dictionary=input.layers[index]
        var entry:Dictionary=Original.layer(owner,input.row,input.rig,selected.layer,index)
        SourceMaterial.apply(entry,conditions);entry.bound_condition_parameters=conditions
        Original.bind_source(owner,entry,input.rig,BODY,0,"SW",conditions)
        result.append(entry)
    return result

func compare_source(a:Dictionary,b:Dictionary,label:String)->void:
    check(a.source_parameters==b.source_parameters,label+" exact full source ledger")
    check(a.cell==b.cell and a.pivot==b.pivot and a.scale==b.scale and a.screen_rect==b.screen_rect,label+" exact authored quad placement")
    check(a.node.mesh.size==b.node.mesh.size and a.node.mesh.center_offset==b.node.mesh.center_offset and a.node.custom_aabb==b.node.custom_aabb,label+" exact native mesh and expanded optical bounds")
    check(a.geometry_binding==b.geometry_binding and a.geometry_paths==b.geometry_paths and a.geometry_status==b.geometry_status,label+" exact optical source provenance")
    check(a.material.shader==b.material.shader and a.node.material_override==a.material,label+" adopted node displays its own lit source material")

# The receiving globals as play.gd publishes them, and one warm light.
func publish_receiving(cap:bool,normals:bool,cookie:ImageTexture)->void:
    var capped:float=1.0 if cap else 0.0
    var hdr:bool=capped>0.0 and not normals
    var ambient:=Color(AMBIENT,AMBIENT,AMBIENT)
    RenderingServer.global_shader_parameter_set(&"light_ambient",ambient.linear_to_srgb().srgb_to_linear().r if hdr else ambient.r)
    RenderingServer.global_shader_parameter_set(&"light_cap",capped)
    RenderingServer.global_shader_parameter_set(&"light_normals",normals)
    var source:Dictionary={"id":"fixture-light","enabled":true,"texture":cookie,"screen_position":Vector2(110,96),
        "height":40.0,"energy":1.6,"color":Color(1,.74,.36,1),"texture_scale":300.0/cookie.get_width(),
        "cookie_scale":Vector2.ONE,"offset":Vector2.ZERO}
    var image:Image=cookie.get_image()
    light_table.publish([source],func(texture:Texture2D)->Image:return image if texture==cookie else null)
    check(light_table.count==1 and light_table.issues.is_empty(),"Fixture light enters the light table")

## Radial fixture cookie at the size the light table copies (RGBA8, COOKIE_SIZE²).
func cookie_texture()->ImageTexture:
    var size:int=LightTable.COOKIE_SIZE;var half:float=size*.5
    var image=Image.create(size,size,false,Image.FORMAT_RGBA8)
    for y in size:
        for x in size:
            var d:float=Vector2(x+.5-half,y+.5-half).length()/half
            image.set_pixel(x,y,Color(1,1,1,clampf(1.0-d,0.0,1.0)))
    return ImageTexture.create_from_image(image)

func first_draw(a:Dictionary,b:Dictionary,label:String)->void:
    await process_frame;await RenderingServer.frame_post_draw
    await process_frame;await RenderingServer.frame_post_draw
    var image_a:Image=a.view.get_texture().get_image();var image_b:Image=b.view.get_texture().get_image()
    var exact:bool=image_a.get_data()==image_b.get_data()
    var painted:int=0
    for y in image_a.get_height():
        for x in image_a.get_width():
            if image_a.get_pixel(x,y).a8>0:painted+=1
    check(exact,label+" assembled final framebuffer is byte-exact on first draw")
    check(painted>200,label+" the private actor paints visible lit pixels")
    cases[label]={"final_framebuffer_exact":exact,"painted_pixels":painted}
    image_a.save_png("res://.captures/actor-resource/"+label+"-private.png")
    image_b.save_png("res://.captures/actor-resource/"+label+"-original.png")

func actor_case(cap:bool,normals:bool,late:bool,cookie:ImageTexture)->void:
    var label:String="actor-private-"+("normals" if normals else "capped" if cap else "ldr")+("-late" if late else "-resident")
    publish_receiving(cap,normals,cookie)
    var image:Image=actor_image();var a:Dictionary=make_side(image);var b:Dictionary=make_side(image)
    var host_a:ActorOwner=a.owner;var host_b:ActorOwner=b.owner
    # Both independent owners deliberately share the same admitted originals.
    host_b.textures=host_a.textures.duplicate();host_b.resources=host_a.resources.duplicate()
    var inputs:Dictionary=source_inputs(host_a);var input:Dictionary=inputs.values()[0]
    var texture_refs:Dictionary=host_a.textures.duplicate()
    if late:
        for path in texture_refs:texture_refs[path]=null
    var output:Dictionary={};var before:int=host_a.get_child_count()
    var task:int=WorkerThreadPool.add_task(Resources.build_private.bind(inputs,texture_refs,host_a.resources.duplicate(),Construction.source_parameter_names(),output),false,"Actor first-frame private resources")
    while not WorkerThreadPool.is_task_completed(task):await process_frame
    WorkerThreadPool.wait_for_task_completion(task)
    check(output.get("complete",false) and output.error=="" and output.draw_count==3,label+" finite resource task completes before residency")
    check(host_a.get_child_count()==before and host_a.entries.is_empty(),label+" worker publishes no attached Node or membership")
    if late:
        var missing:Dictionary={}
        check(not Construction.complete_private_layer(output.rows[input.row.id][2],missing),label+" exact missing texture operands cannot falsely admit")
    var original:Array=reference_actor(host_b,input)
    var adopted:Array=[];var total_pending:int=0
    for index in output.rows[input.row.id]:
        var packet:Dictionary=output.rows[input.row.id][index]
        var node:MeshInstance3D=packet.entry.node
        check(node!=null and not node.is_inside_tree() and node.material_override==packet.entry.material and node.mesh==packet.mesh,
            label+" worker builds the finished layer node outside any tree")
        total_pending+=packet.pending_textures.size()
        check(Construction.complete_private_layer(packet,host_a.textures),label+" actual selected texture closure completes")
        var entry:Dictionary=Construction.adopt_private_layer(host_a,packet)
        check(entry.node==node and node.get_parent()==host_a,label+" scene adoption only attaches the worker node")
        compare_source(entry,original[index],label+" layer "+str(index))
        entry.node.position=Vector3(-.1,.2,1);original[index].node.position=entry.node.position
        adopted.append(entry)
    check((total_pending>0)==late,label+" pending texture quantities match actual residency")
    check(adopted[2].source_parameters.effect_has_noise,label+" late palette noise retains its authored enabled state")
    check(host_a.actor_entries==adopted and host_a.entries==adopted,label+" adoption registers each layer once in canonical order")
    if DisplayServer.get_name()!="headless":await first_draw(a,b,label+"-idle")
    var actual:Dictionary=Construction.Conditions.material(input.row.id,[]);actual.alpha=.36;actual.brightness=.8
    var changed:Dictionary=Construction.Conditions.parameters(actual,host_a.textures,host_a.resources);changed.make_read_only()
    for index in adopted.size():
        Construction.bind_source(host_a,adopted[index],input.rig,BODY,2,"NE",changed)
        Original.bind_source(host_b,original[index],input.rig,BODY,2,"NE",changed)
        compare_source(adopted[index],original[index],label+" current hidden+UV "+str(index))
    if DisplayServer.get_name()!="headless":await first_draw(a,b,label+"-current-hidden-uv")
    a.view.queue_free();b.view.queue_free();await process_frame

func cancellation_case()->void:
    var side:Dictionary=make_side(actor_image());var owner:ActorOwner=side.owner
    var inputs:Dictionary=source_inputs(owner);var output:Dictionary={}
    var task:int=WorkerThreadPool.add_task(Resources.build_private.bind(inputs,owner.textures.duplicate(),owner.resources.duplicate(),Construction.source_parameter_names(),output),false,"Canceled private actor resources")
    while not WorkerThreadPool.is_task_completed(task):await process_frame
    WorkerThreadPool.wait_for_task_completion(task)
    var packet:Dictionary=output.rows["assembled-actor"][1]
    var source:WeakRef=weakref(packet.entry.material)
    var mesh:WeakRef=weakref(packet.mesh)
    var nodes:Array=[]
    for value in output.rows["assembled-actor"].values():nodes.append(value.entry.node)
    check(source.get_ref()!=null and mesh.get_ref()!=null and owner.entries.is_empty() and nodes.all(func(node):return not node.is_inside_tree()),
        "Canceled worker owns hidden resources without any attached actor Node")
    # The canceling owner frees the detached worker nodes it never adopted.
    packet={};output.clear();inputs.clear()
    for node in nodes:node.free()
    nodes.clear()
    await process_frame
    check(source.get_ref()==null and mesh.get_ref()==null,"Cancellation releases source material and mesh without a dictionary cycle")
    side.view.queue_free();await process_frame

func run()->void:
    root.position=Vector2i(-16000,-16000);root.unfocusable=true
    DirAccess.make_dir_recursive_absolute("res://.captures/actor-resource")
    var cookie:ImageTexture=cookie_texture()
    for mode in [[false,false],[true,false],[true,true]]:
        for late in [false,true]:await actor_case(mode[0],mode[1],late,cookie)
    await cancellation_case()
    var report={"checks":checks,"failures":failures,"cases":cases,"renderer":RenderingServer.get_current_rendering_method(),
        "scope":"Assembled private actor resource packet versus ordinary constructor; worker-built detached layer nodes, first lit final framebuffer in LDR/capped/Normals, current Hidden+UV, late body/companion/noise closure and no-cycle cancellation. No gameplay latency claim."}
    FileAccess.open("res://generated/actor_resource_preparation_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("ACTOR_RESOURCE_PREPARATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
