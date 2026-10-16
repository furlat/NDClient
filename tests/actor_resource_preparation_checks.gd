extends "res://tests/native_atlas_growth_checks.gd"
## First actual assembled actor frame from private resources, compared with the
## ordinary source constructor/binder; independent received-cell/output oracle.
const Construction=preload("res://presentation/actor_construction.gd")
const Original=preload("res://presentation/actor_construction.gd")
const Resources=preload("res://presentation/actor_resources.gd")
const BODY="/fixture/actor-resource-body.png"
const NOISE="/fixture/actor-resource-noise.png"
class ActorOwner extends "res://presentation/sprite_sources.gd":
    var textures:Dictionary={}
    var resources:Dictionary={}
    var character_light_profile:String="original"
    func texture(path:String)->Texture2D:return textures.get(path)
    func _light_entry(entry:Dictionary)->void:SourceMaterial.set_parameter(entry,"authored_base_light",0.0)

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

func actor_owner(side:Dictionary,image:Image)->ActorOwner:
    var owner=ActorOwner.new();side.world.add_child(owner);owner.camera=side.world.camera
    owner.rig_config={"TILE_W":128};owner.quarter=0
    owner.source_depth=true;owner.source_normals=true
    geometry(owner,image)
    return owner

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
        SourceMaterial.set_parameter(entry,"current_visibility",1.0);entry.scenery_value=1.0
        result.append(entry)
    return result

func compare_source(a:Dictionary,b:Dictionary,label:String)->void:
    check(a.source_parameters==b.source_parameters,label+" exact full source ledger")
    check(a.cell==b.cell and a.pivot==b.pivot and a.scale==b.scale and a.screen_rect==b.screen_rect,label+" exact authored quad placement")
    check(a.node.mesh.size==b.node.mesh.size and a.node.mesh.center_offset==b.node.mesh.center_offset and a.node.custom_aabb==b.node.custom_aabb,label+" exact native mesh and expanded optical bounds")
    check(a.geometry_binding==b.geometry_binding and a.geometry_paths==b.geometry_paths and a.geometry_status==b.geometry_status,label+" exact optical source provenance")

func first_draw(a:Dictionary,b:Dictionary,label:String)->void:
    # Multiple modular layers intentionally share placement.id. The native
    # pair key must retain actual layer identity, not overwrite one body layer
    # with another while comparing received cells.
    await process_frame;await RenderingServer.frame_post_draw
    var received_a:Image=a.atlas.viewport.get_texture().get_image()
    var received_b:Image=b.atlas.viewport.get_texture().get_image()
    var other:Dictionary={};var differences:int=0;var painted_actor_cells:int=0
    for receiver in b.atlas.receivers:
        other[receiver.entry.get("id",receiver.entry.placement.id)+":"+receiver.row_id]=receiver
    for receiver in a.atlas.receivers:
        var key:String=receiver.entry.get("id",receiver.entry.placement.id)+":"+receiver.row_id
        var expected:Dictionary=other[key]
        var actual:Image=received_a.get_region(Rect2i(receiver.position,receiver.crop.pixels.size))
        if actual.get_data()!=received_b.get_region(Rect2i(expected.position,expected.crop.pixels.size)).get_data():differences+=1
        if receiver.dynamic and actual.get_used_rect().has_area():painted_actor_cells+=1
    var image_a:Image=a.view.get_texture().get_image();var image_b:Image=b.view.get_texture().get_image()
    var exact:bool=image_a.get_data()==image_b.get_data()
    check(differences==0,label+" every layer's native received cell is byte-exact on first draw")
    check(exact,label+" assembled final framebuffer is byte-exact on first draw")
    check(painted_actor_cells==(2 if a.atlas.normals_visible else 3),label+" every intended visible actor layer paints received pixels")
    cases[label]={"different_cells":differences,"final_framebuffer_exact":exact,"painted_actor_cells":painted_actor_cells}
    image_a.save_png("res://.captures/atlas-growth/"+label+"-private.png")
    image_b.save_png("res://.captures/atlas-growth/"+label+"-original.png")

func actor_case(cap:bool,normals:bool,late:bool)->void:
    var label:String="actor-private-"+("normals" if normals else "capped" if cap else "ldr")+("-late" if late else "-resident")
    var a:Dictionary=make_side(pair_source(),cap,normals);var b:Dictionary=make_side(pair_source(),cap,normals)
    publish(a,true,a.world.entries);publish(b,true,b.world.entries)
    var image:Image=actor_image();var host_a:ActorOwner=actor_owner(a,image);var host_b:ActorOwner=actor_owner(b,image)
    # Both independent owners deliberately share the same admitted originals.
    host_b.textures=host_a.textures.duplicate();host_b.resources=host_a.resources.duplicate()
    var inputs:Dictionary=source_inputs(host_a);var input:Dictionary=inputs.values()[0]
    var texture_refs:Dictionary=host_a.textures.duplicate()
    if late:
        for path in texture_refs:texture_refs[path]=null
    var output:Dictionary={};var before:int=host_a.get_child_count()
    var task:int=WorkerThreadPool.add_task(Resources.build_private.bind(inputs,texture_refs,host_a.resources.duplicate(),Construction.source_parameter_names(),a.atlas.actor_resource_options(a.world),output),false,"Actor first-frame private resources")
    while not WorkerThreadPool.is_task_completed(task):await process_frame
    WorkerThreadPool.wait_for_task_completion(task)
    check(output.get("complete",false) and output.error=="" and output.draw_count==3,label+" finite resource task completes before residency")
    check(host_a.get_child_count()==before and host_a.entries.is_empty() and a.atlas.dynamic_receivers.is_empty(),label+" worker publishes no Node or atlas membership")
    if late:
        var missing:Dictionary={}
        check(not Construction.complete_private_layer(output.rows[input.row.id][2],missing),label+" exact missing texture operands cannot falsely admit")
    var original:Array=reference_actor(host_b,input)
    var adopted:Array=[];var total_pending:int=0;var bindings:Dictionary={};var jobs:Array=[]
    for index in output.rows[input.row.id]:
        var packet:Dictionary=output.rows[input.row.id][index]
        check(packet.atlas.has("capture") and not packet.atlas.capture.has("entry")
            and not packet.atlas.capture.proof.has("entry") and packet.atlas.capture.rows==[input.row],
            label+" resource worker completes passive capture without a native identity")
        total_pending+=packet.pending_textures.size()
        check(Construction.complete_private_layer(packet,host_a.textures),label+" actual selected texture closure completes")
        var entry:Dictionary=Construction.adopt_private_layer(host_a,packet)
        var prepared:Dictionary=a.atlas.adopt_private_actor_binding(entry,packet.atlas,a.world,packet.filled_textures)
        SourceMaterial.acknowledge(entry)
        check(prepared.specs.is_empty() and prepared.receivers.is_empty() and prepared.material_only,label+" actor packet contains only private materials")
        check(a.atlas.adopt_source_binding(prepared),label+" exact dynamic material owner admitted")
        bindings[entry.node.get_instance_id()]=prepared
        jobs.append({"entry":entry,"prepared":prepared,"rows":[entry.placement],"packet":{}})
        compare_source(entry,original[index],label+" layer "+str(index))
        entry.node.position=Vector3(-.3,.5,1);original[index].node.position=entry.node.position
        adopted.append(entry)
    check((total_pending>0)==late,label+" pending texture quantities match actual residency")
    check(adopted[2].source_parameters.effect_has_noise,label+" late palette noise retains its authored enabled state")
    a.world.entries.append_array(adopted);a.world.actor_entries=adopted
    b.world.entries.append_array(original);b.world.actor_entries=original
    var private_groups:Dictionary={}
    for index in output.rows[input.row.id]:
        private_groups[index]=output.rows[input.row.id][index].atlas.groups.values()[0].material
    var prefix:Dictionary=Atlas.Delta.begin_candidate(a.atlas,jobs,{},a.world)
    while not Atlas.Delta.capture_candidate(a.atlas,prefix,a.world):pass
    check(bindings.values().all(func(value):return not value.has("capture")),
        label+" real identity admission transfers each completed capture once")
    var plan_task:int=WorkerThreadPool.add_task(Atlas.Delta.compute_candidate.bind(prefix),false,"Actual private actor source prefix")
    while not WorkerThreadPool.is_task_completed(plan_task):await process_frame
    WorkerThreadPool.wait_for_task_completion(plan_task)
    check(not prefix.has("error") and prefix.get("complete",false),label+" exact private actor plan completes")
    check(Atlas.Delta.reserve_candidate_capacity(a.atlas,prefix),label+" exact private actor plan capacity is admitted")
    while not Atlas.Delta.prepare_candidate_binding(a.atlas,prefix,bindings):pass
    check(not prefix.has("error") and prefix.get("bound",false),label+" receiving Nodes and output install finish before publication")
    prefix.admitted=true;a.atlas.prepared_delta=prefix
    var delivery:Array=[]
    for index in adopted.size():
        var entry:Dictionary=adopted[index]
        var group:Dictionary=bindings[entry.node.get_instance_id()].groups.values()[0]
        delivery.append({"layer":index,"source_version":entry.source_version,"change_base":entry.source_change_base,
            "group_version":group.version,"source_material":group.get("source_material")==entry.material,
            "source_shader":group.source_shader==entry.material.shader,"target_material":group.get("target_material")==group.material,
            "target_shader":group.get("target_shader")==group.material.shader,
            "binding_revision":group.get("binding_revision",-1)==entry.source_binding_revision})
    publish(a,false,adopted);publish(b,true,b.world.entries)
    if a.atlas.last_reconcile_phases.get("material_full_copies",0)!=0:
        var copies:Dictionary={}
        for key in ["material_full_copies","material_receiver_full_dynamic","material_receiver_full_static",
            "material_output_full_dynamic","material_output_full_static","material_frame_copies","material_sample_versions"]:
            copies[key]=a.atlas.last_reconcile_phases.get(key,0)
        print("ACTOR_FIRST_PUBLICATION_DIAGNOSTIC ",JSON.stringify({"label":label,"copies":copies,"delivery_before_publish":delivery}))
    check(a.atlas.last_reconcile_phases.get("material_full_copies",0)==0,
        label+" first published sample consumes the completed worker delivery without a full receiving copy")
    for index in adopted.size():
        check(row_receiver(a.atlas,adopted[index]).group.material==private_groups[index],label+" retains exact worker receiving material "+str(index))
    check(a.atlas.last_reconcile_phases.get("prepared_prefix_specs",0)>=3
        and a.atlas.last_reconcile_phases.get("delta_fallback","").is_empty(),
        label+" first actual atlas uses the completed private prefix without fallback")
    if DisplayServer.get_name()!="headless":await first_draw(a,b,label+"-idle")
    var actual:Dictionary=Construction.Conditions.material(input.row.id,[]);actual.alpha=.36;actual.brightness=.8
    var changed:Dictionary=Construction.Conditions.parameters(actual,host_a.textures,host_a.resources);changed.make_read_only()
    for index in adopted.size():
        Construction.bind_source(host_a,adopted[index],input.rig,BODY,2,"NE",changed)
        Original.bind_source(host_b,original[index],input.rig,BODY,2,"NE",changed)
        compare_source(adopted[index],original[index],label+" current hidden+UV "+str(index))
    publish(a,false,adopted);publish(b,true,b.world.entries)
    check(a.atlas.last_reconcile_phases.get("material_full_copies",0)==0,label+" first real nonneutral/UV sample uses operand deltas rather than reinitializing")
    if DisplayServer.get_name()!="headless":await first_draw(a,b,label+"-current-hidden-uv")
    a.atlas.close();b.atlas.close();a.view.queue_free();b.view.queue_free();await process_frame

func cancellation_case()->void:
    var side:Dictionary=make_side(pair_source(),true,false);var owner:ActorOwner=actor_owner(side,actor_image())
    var inputs:Dictionary=source_inputs(owner);var output:Dictionary={}
    var task:int=WorkerThreadPool.add_task(Resources.build_private.bind(inputs,owner.textures.duplicate(),owner.resources.duplicate(),Construction.source_parameter_names(),side.atlas.actor_resource_options(side.world),output),false,"Canceled private actor resources")
    while not WorkerThreadPool.is_task_completed(task):await process_frame
    WorkerThreadPool.wait_for_task_completion(task)
    var source:WeakRef=weakref(output.rows["assembled-actor"][1].entry.material)
    var received:WeakRef=weakref(output.rows["assembled-actor"][1].atlas.output.received_material)
    check(source.get_ref()!=null and received.get_ref()!=null and owner.entries.is_empty(),"Canceled worker owns hidden resources without any actor Node")
    output.clear();inputs.clear();await process_frame
    check(source.get_ref()==null and received.get_ref()==null,"Cancellation releases source/receiving packet without a dictionary cycle")
    side.atlas.close();side.view.queue_free();await process_frame

func run()->void:
    root.position=Vector2i(-16000,-16000);root.unfocusable=true
    DirAccess.make_dir_recursive_absolute("res://.captures/atlas-growth")
    for mode in [[false,false],[true,false],[true,true]]:
        for late in [false,true]:await actor_case(mode[0],mode[1],late)
    await cancellation_case()
    var report={"checks":checks,"failures":failures,"cases":cases,"renderer":RenderingServer.get_current_rendering_method(),
        "scope":"Assembled private actor resource packet versus ordinary constructor; first received/final framebuffer, current Hidden+UV, late body/companion/noise closure and no-node cancellation. No gameplay latency claim."}
    FileAccess.open("res://generated/actor_resource_preparation_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("ACTOR_RESOURCE_PREPARATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
