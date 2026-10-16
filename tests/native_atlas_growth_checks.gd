extends "res://tests/native_atlas_lifecycle_checks.gd"
# Same published sparse receipt as Play, compared with the unchanged full
# planner. Mathematical sources deliberately cross a real 1024px shelf limit.
var cases: Dictionary={}

func pair_source()->Image:
    var source=Image.create(512,512,false,Image.FORMAT_RGBA8)
    source.fill(Color8(91,137,181,255))
    for y in 8:
        for x in 8:
            source.fill_rect(Rect2i(x*64+8,y*64+8,40,40),Color8(31+x*24,19+y*25,173,[1,63,194,255][(x+y)%4]))
    return source

func single(world:World,texture:Texture2D,index:int,cell:Vector2=Vector2(512,512),dynamic:bool=false)->Dictionary:
    var material=ShaderMaterial.new();material.shader=Source
    var node=MeshInstance3D.new();node.mesh=QuadMesh.new();node.mesh.size=Vector2(1.6,1.6)
    node.position=Vector3(-3.0+(index%4)*2.0,2.5-(index/4)*2.0,0)
    node.material_override=material;world.add_child(node)
    var entry={"node":node,"material":material,"cell":cell,"record":{"path":"large","rect":[0,0,512,512]},
        "placement":{"id":"single-"+str(index),"kind":"actor" if dynamic else "wall"},
        "role":"body" if dynamic else "wall","scenery_value":0.0 if index==1 else 1.0,"source_version":1}
    SourceMaterial.initialize(entry)
    SourceMaterial.apply(entry,{"colour_texture":texture,"colour_size":Vector2(512,512),"colour_rect":Vector4(0,0,512,512),
        "has_geometry":false,"wall_opacity":.28 if index==0 else 1.0,"wall_mask_enabled":false})
    return entry

func make_side(source:Image,cap:bool,normals:bool)->Dictionary:
    var view=SubViewport.new();view.size=Vector2i(480,400);view.own_world_3d=true
    view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=World.new();view.add_child(world)
    var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    camera.size=12.0;camera.position=Vector3(0,0,10);world.add_child(camera);camera.current=true;world.camera=camera
    var floor_source=Image.create(64,64,false,Image.FORMAT_RGBA8)
    floor_source.fill_rect(Rect2i(6,12,52,32),Color8(157,106,47,194))
    world.source_images={"fixture":floor_source,"large":source}
    var floor_row=floor_entry(world,floor_source);floor_row.node.position.y=4.5
    world.entries=[floor_row]
    var texture=ImageTexture.create_from_image(source)
    for index in 14:world.entries.append(single(world,texture,index))
    var atlas=Atlas.new();atlas.attach(world);atlas.set_light_cap(1.0 if cap else 0.0);atlas.set_normals_visible(normals)
    var light=PointLight2D.new();light.texture=atlas.white;light.texture_scale=750.0
    light.position=Vector2(190,150);light.height=56.0;light.energy=1.2;light.color=Color(1,.74,.36,1)
    atlas.viewport.add_child(light)
    return {"view":view,"world":world,"atlas":atlas,"texture":texture,"serial":0,"floor":floor_row}

func publish(side:Dictionary,full:bool,upserts:Array)->void:
    var base:int=side.serial;side.serial+=1
    var receipt={"base":base,"serial":side.serial,"full":full,"upserts":upserts,"removed":[]}
    side.atlas.sync(side.world,[side.serial],[side.serial],receipt,true)
    side.atlas.sync_output(side.world,[side.serial],true)

func positions(atlas:RefCounted)->Dictionary:
    var result={}
    for receiver in atlas.receivers:
        var id:String=receiver.entry.placement.id+":"+receiver.row_id
        result[id]=receiver.position
    return result

func transport(side:Dictionary,label:String)->void:
    check_transport(side.atlas,side.floor,label)
    var okay=true
    for entry in side.world.entries:
        if entry.has("batch_rows"):continue
        var receiver=row_receiver(side.atlas,entry)
        var origin=Vector2(receiver.position)/Vector2(side.atlas.viewport.size)
        var size=Vector2(receiver.crop.pixels.size)/Vector2(side.atlas.viewport.size)
        okay=okay and entry.received_material.get_shader_parameter("atlas_region")==Vector4(origin.x,origin.y,size.x,size.y)
    check(okay,label+" all retained/new singles use the resized normalized regions")

func first_draw(a:Dictionary,b:Dictionary,label:String)->void:
    # Read both sides of the FIRST completed draw after the same publication.
    # No settling retry, extra source sync, or recomputed address precedes it.
    await process_frame;await RenderingServer.frame_post_draw
    var received_a:Image=a.atlas.viewport.get_texture().get_image()
    var received_b:Image=b.atlas.viewport.get_texture().get_image()
    var different_cells=0
    var other={}
    for receiver in b.atlas.receivers:other[receiver.entry.placement.id+":"+receiver.row_id]=receiver
    for receiver in a.atlas.receivers:
        var expected:Dictionary=other[receiver.entry.placement.id+":"+receiver.row_id]
        if received_a.get_region(Rect2i(receiver.position,receiver.crop.pixels.size)).get_data()!=received_b.get_region(Rect2i(expected.position,expected.crop.pixels.size)).get_data():different_cells+=1
    var output_a:Image=a.view.get_texture().get_image();var output_b:Image=b.view.get_texture().get_image()
    var exact=output_a.get_data()==output_b.get_data()
    check(different_cells==0,label+" native received cells are byte-exact on first draw")
    check(exact,label+" final 3D framebuffer is byte-exact on first draw")
    check(output_a.get_used_rect().size.x>0,label+" framebuffer contains the actual source quads")
    cases[label]={"size":str(a.atlas.viewport.size),"receivers":a.atlas.receivers.size(),
        "different_cells":different_cells,"final_framebuffer_exact":exact,"phases":a.atlas.last_reconcile_phases.duplicate(true)}
    output_a.save_png("res://.captures/atlas-growth/"+label+"-delta.png")
    output_b.save_png("res://.captures/atlas-growth/"+label+"-full.png")

func growth_case(source:Image,label:String,cap:bool,normals:bool)->void:
    var a=make_side(source,cap,normals);var b=make_side(source,cap,normals)
    publish(a,true,a.world.entries);publish(b,true,b.world.entries)
    check(a.atlas.viewport.size==Vector2i(8192,1024),label+" initial real layout fits 1024px height")
    await first_draw(a,b,label+"-initial")
    var old_positions=positions(a.atlas);var old_buffer:PackedFloat32Array=a.floor.node.multimesh.buffer
    var old_packets:Array=[a.floor.ground_packets["0"].data.duplicate(),a.floor.ground_packets["1"].data.duplicate()]
    var old_nodes={}
    for receiver in a.atlas.receivers:old_nodes[receiver.id]=Atlas.receiver_handle(receiver)
    var token:Array=a.atlas.floor_address_token(a.floor)
    var add_a=[];var add_b=[]
    for index in range(14,16):
        add_a.append(single(a.world,a.texture,index));add_b.append(single(b.world,b.texture,index))
    a.world.entries.append_array(add_a);b.world.entries.append_array(add_b)
    publish(a,false,add_a);publish(b,true,b.world.entries)
    check(a.atlas.errors.is_empty() and b.atlas.errors.is_empty(),label+" both planners accept the appended sources")
    check(a.atlas.last_reconcile_phases.get("layout_mode","")=="delta_growth",label+" actual sparse admission crosses the height boundary")
    check(b.atlas.last_reconcile_phases.get("layout_mode","")=="append",label+" independent complete planner uses its original append path")
    check(a.atlas.viewport.size==Vector2i(8192,2048) and a.atlas.viewport.size==b.atlas.viewport.size,label+" same bounded height doubling")
    check(positions(a.atlas)==positions(b.atlas) and a.atlas.shelf_cursor==b.atlas.shelf_cursor and a.atlas.packed_pixels==b.atlas.packed_pixels,label+" exact old/new cell positions, shelf cursor and area")
    var retained=true
    var next_positions=positions(a.atlas)
    for id in old_positions:retained=retained and old_positions[id]==next_positions[id]
    for receiver in a.atlas.receivers:
        if old_nodes.has(receiver.id):retained=retained and Atlas.receiver_handle(receiver)==old_nodes[receiver.id]
    check(retained,label+" old pixel reservations and native receiver nodes stay retained")
    check(old_buffer==a.floor.node.multimesh.buffer and old_packets==[a.floor.ground_packets["0"].data,a.floor.ground_packets["1"].data],label+" retained integer floor addresses stay unchanged in native and source packets")
    check(a.atlas.floor_address_token(a.floor)!=token,label+" growth invalidates earlier prepared-address token")
    transport(a,label);transport(b,label+" reference")
    await first_draw(a,b,label+"-growth")
    # A valid tall reservation would need 4096, followed by an invalid source.
    # Neither sparse planning nor the original fallback may publish that resize.
    var size_before:Vector2i=a.atlas.viewport.size;var cursor_before:Vector3i=a.atlas.shelf_cursor
    var positions_before=positions(a.atlas);var repack_before:int=a.atlas.repack_count
    var output_before=a.floor.received_material;var buffer_before:PackedFloat32Array=a.floor.node.multimesh.buffer
    var tall=single(a.world,a.texture,16,Vector2(512,2048),true)
    var invalid=single(a.world,a.texture,17,Vector2(9000,128),true)
    tall.node.visible=false;invalid.node.visible=false;a.world.entries.append_array([tall,invalid])
    publish(a,false,[tall,invalid])
    check(not a.atlas.errors.is_empty() and a.atlas.last_reconcile_phases.get("delta_fallback","")=="oversized_cell",label+" rejected reservation records the original sparse cause after full fallback")
    check(a.atlas.viewport.size==size_before and a.atlas.shelf_cursor==cursor_before and a.atlas.repack_count==repack_before and positions(a.atlas)==positions_before,label+" rejection preserves committed dimensions, reservations and packing counter")
    check(a.floor.received_material==output_before and a.floor.node.multimesh.buffer==buffer_before and not tall.has("received_material") and not invalid.has("received_material"),label+" rejection publishes no output or floor-buffer mutation")
    a.world.entries.pop_back();a.world.entries.pop_back();tall.node.queue_free();invalid.node.queue_free()
    a.atlas.close();b.atlas.close();a.view.queue_free();b.view.queue_free();await process_frame

func run()->void:
    root.position=Vector2i(-16000,-16000);root.unfocusable=true
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.captures/atlas-growth"))
    var source=pair_source()
    await growth_case(source,"ldr",false,false)
    await growth_case(source,"capped",true,false)
    await growth_case(source,"normals",true,true)
    var report={"renderer":RenderingServer.get_current_rendering_method(),"checks":checks,"failures":failures,"cases":cases,
        "scope":"Real append-height boundary; sparse receipt versus original full planner; first native cell/final framebuffer byte parity; retained floor/single normalized bindings; native cap, memory, wall opacity and Normals modes; failed candidate that would otherwise grow again stays transactional. Mathematical source fixture, not a gameplay latency measurement."}
    var file=FileAccess.open("res://generated/native_atlas_growth_checks.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  "));file.close()
    print("ATLAS_GROWTH ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
