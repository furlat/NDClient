extends SceneTree
const Atlas=preload("res://presentation/native_light_atlas.gd")
class World extends Node3D:
    var entries: Array=[]
    var source_images: Dictionary={}
    var camera: Camera3D
    var presentation_errors: Array=[]
    var actor_revision:=0
    var actor_entries: Array=[]
    var fixture_entries: Array=[]
const Source=preload("res://environment.gdshader")
const ActorSource=preload("res://modular.gdshader")
const REFERENCE = 'shader_type canvas_item; render_mode blend_disabled; uniform float visible_source=1.0; void fragment(){vec4 c=texture(TEXTURE,UV); if(c.a<=0.0)discard; float grey=dot(c.rgb,vec3(.2126,.7152,.0722)); c.rgb=mix(mix(vec3(grey),c.rgb,.35)*.62,c.rgb,visible_source); COLOR=c; NORMAL=vec3(0,0,1);}'
var Reference: Shader
var checks:=0
var failures:Array=[]
var pixels:Dictionary={}
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("ATLAS_LIFECYCLE_FAIL ",label)
func _initialize()->void:run.call_deferred()
func floor_entry(world:Node3D,source:Image)->Dictionary:
    var mesh=QuadMesh.new();mesh.size=Vector2(2,2)
    var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_colors=true;multi.use_custom_data=true
    multi.mesh=mesh;multi.instance_count=2;multi.visible_instance_count=2
    var buffer=PackedFloat32Array();var packets={};var rows=[]
    for i in 2:
        var x=-1.1+i*2.2
        var data=PackedFloat32Array([1,0,0,x,0,1,0,0,0,0,1,0,1,1,1,1,1-i,0,0,0])
        buffer.append_array(data);packets[str(i)]={"data":data};rows.append({"id":str(i),"kind":"terrain","material":"stone","position":[i,0],"base_height_steps":0})
    multi.buffer=buffer
    var mat=ShaderMaterial.new();mat.shader=Source
    mat.set_shader_parameter("colour_texture",ImageTexture.create_from_image(source));mat.set_shader_parameter("colour_size",Vector2(64,64))
    mat.set_shader_parameter("colour_rect",Vector4(0,0,64,64));mat.set_shader_parameter("has_geometry",false)
    var node=MultiMeshInstance3D.new();node.multimesh=multi;node.material_override=mat;world.add_child(node)
    return {"node":node,"material":mat,"cell":Vector2(64,64),"record":{"path":"fixture","rect":[0,0,64,64]},"placement":rows[0],"role":"terrain","batch_rows":rows,"ground_buffer":buffer,"ground_packets":packets,"scenery_values":[1.0,0.0],"source_version":1,"ground_version":0}
func native_page(size:Vector2i)->SubViewport:
    var view=SubViewport.new();view.size=size;view.disable_3d=true;view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    view.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST;root.add_child(view)
    var ambient=CanvasModulate.new();ambient.color=Color(.18,.18,.18,1);view.add_child(ambient)
    return view
func capture(view:SubViewport)->Image:
    await process_frame;await RenderingServer.frame_post_draw
    return view.get_texture().get_image()
func pixel_oracle(atlas:RefCounted,world:World,source:Image,label:String)->void:
    if DisplayServer.get_name()=="headless":return
    var reference=native_page(Vector2i(world.get_viewport().get_visible_rect().size))
    for receiver in atlas.receivers:
        var entry:Dictionary=receiver.entry
        var transform:Transform3D=entry.node.global_transform
        if receiver.index>=0:
            var data:PackedFloat32Array=entry.ground_buffer;var i:int=receiver.index*20
            transform*=Transform3D(Basis(Vector3(data[i],data[i+4],data[i+8]),Vector3(data[i+1],data[i+5],data[i+9]),Vector3(data[i+2],data[i+6],data[i+10])),Vector3(data[i+3],data[i+7],data[i+11]))
        var origin=world.camera.unproject_position(transform*Vector3(-1,1,0))
        var right=world.camera.unproject_position(transform*Vector3(1,1,0))-origin
        var down=world.camera.unproject_position(transform*Vector3(-1,-1,0))-origin
        var sprite=Sprite2D.new();sprite.texture=ImageTexture.create_from_image(source);sprite.centered=false
        sprite.transform=Transform2D(right/64.0,down/64.0,origin)
        var material=ShaderMaterial.new();material.shader=Reference
        material.set_shader_parameter("visible_source",entry.scenery_values[receiver.index] if receiver.index>=0 else entry.get("scenery_value",1.0));sprite.material=material
        reference.add_child(sprite)
    var packed=await capture(atlas.viewport);var original=await capture(reference)
    packed.save_png("res://.captures/atlas-lifecycle/"+label+"-atlas.png");original.save_png("res://.captures/atlas-lifecycle/"+label+"-reference.png")
    for receiver in atlas.receivers:
        var errors=0;var alpha_errors=0;var maximum=0;var compared=0
        for y in receiver.crop.pixels.size.y:
            for x in receiver.crop.pixels.size.x:
                var actual=receiver.node.global_transform*(Vector2(x,y)+Vector2(.5,.5))
                if not Rect2(Vector2.ZERO,Vector2(original.get_size())).has_point(actual):continue
                var pixel=packed.get_pixel(receiver.position.x+x,receiver.position.y+y)
                var expected=original.get_pixelv(Vector2i(actual.floor()))
                var difference=maxi(maxi(abs(pixel.r8-expected.r8),abs(pixel.g8-expected.g8)),maxi(abs(pixel.b8-expected.b8),abs(pixel.a8-expected.a8)))
                maximum=maxi(maximum,difference);compared+=1
                if difference>0:errors+=1
                if pixel.a8!=expected.a8:alpha_errors+=1
        pixels[label+":"+receiver.id]={"compared":compared,"different_pixels":errors,"maximum_byte_error":maximum,"alpha_mismatches":alpha_errors}
        check(compared>0 and errors==0,"Independent full-source native RGBA after "+label+": "+receiver.id)
    reference.queue_free()
func run()->void:
    root.position=Vector2i(-16000,-16000);root.unfocusable=true
    Reference=Shader.new();Reference.code=REFERENCE
    var view=SubViewport.new();view.size=Vector2i(320,240);view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=World.new();view.add_child(world)
    var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=7.5;camera.position=Vector3(0,0,10);world.add_child(camera);world.camera=camera
    DirAccess.make_dir_recursive_absolute("res://.captures/atlas-lifecycle")
    var source=Image.create(64,64,false,Image.FORMAT_RGBA8)
    for y in range(12,44):
        for x in range(6,58):source.set_pixel(x,y,Color8(74+x,81+y,153,[1,63,194,255][(x-6)/13]))
    world.source_images.fixture=source
    var entry=floor_entry(world,source);world.entries=[entry]
    var atlas=Atlas.new();atlas.attach(world);atlas.sync(world)
    check(atlas.errors.is_empty(),"Prepared original source accepted")
    check(atlas.receivers.size()==2 and atlas.groups.size()==2,"Mixed current and remembered floor instances use two shared native source materials")
    check(atlas.receivers[0].crop.pixels==Rect2i(6,12,52,32),"Crop preserves every nonzero source alpha including 1/255")
    check(atlas.packed_pixels==2*52*32,"Allocation is exact static colour bbox rather than full64-square cells")
    check(atlas.receivers[0].node.texture==atlas.receivers[1].node.texture,"Floor receivers share white texture; binary memory style is a material group")
    check(entry.material==entry.node.material_override or entry.node.material_override==entry.received_material,"Received override keeps original source material owned by entry")
    check(entry.node.material_override==entry.received_material and entry.received_material!=entry.material,"Only output override changes; source material remains distinct")
    check(atlas.receivers[0].node.material.get_shader_parameter("receiver_visibility")==1.0 and atlas.receivers[1].node.material.get_shader_parameter("receiver_visibility")==0.0,"Mixed current and remembered instances remain distinct")
    var repacks=atlas.repack_count;world.actor_revision+=20;atlas.sync(world)
    check(atlas.repack_count==repacks,"Actor revisions cannot repack unchanged receiver membership")
    check(atlas.last_reconcile_phases.get("projected_receivers",0)==0,"Unchanged receiver admission does not reproject the whole static map")
    var unchanged_transform=atlas.receivers[1].node.transform
    entry.ground_packets["0"].data[3]+=.25;entry.ground_buffer[3]+=.25;entry.ground_version+=1
    atlas.sync(world)
    check(atlas.last_reconcile_phases.projected_receivers==1 and atlas.receivers[1].node.transform==unchanged_transform,"Exact changed floor transform projects only its receiver, even with unchanged row IDs")
    entry.ground_packets["0"].data[3]-=.25;entry.ground_buffer[3]-=.25;entry.ground_version+=1;atlas.sync(world)
    check(atlas.last_reconcile_phases.projected_receivers==1,"Restored native floor transform is detected independently of source colour")
    var before=entry.ground_buffer.duplicate()
    for i in 2:
        entry.ground_buffer[i*20+17]=0;entry.ground_buffer[i*20+18]=0
        entry.ground_packets[str(i)].data[17]=0;entry.ground_packets[str(i)].data[18]=0
    entry.ground_version+=1;atlas.sync(world)
    check(entry.ground_buffer==before,"Same-membership floor publication restores every native atlas address")
    check(atlas.repack_count==repacks,"Replacing floor packet does not repack stable source cells")
    check(atlas.last_reconcile_phases.projected_receivers==0,"Same transform floor buffer publication restores addresses without reprojection")
    entry.material.set_shader_parameter("highlighted",true);atlas.sync(world)
    check(atlas.groups.values().all(func(g):return g.material.get_shader_parameter("highlighted")==true),"Independent highlight updates receiving without source-version change")
    entry.material.set_shader_parameter("highlighted",false);atlas.sync(world)
    entry.material.set_shader_parameter("source_tint",Color(.5,.75,1,1));entry.source_version+=1;atlas.sync(world)
    check(atlas.groups.values().all(func(g):return g.material.get_shader_parameter("source_tint")==Color(.5,.75,1,1)),"Versioned source tint updates receiving")
    entry.material.set_shader_parameter("source_tint",Color.WHITE);entry.source_version+=1;atlas.sync(world)
    check(entry.ground_packets["0"].data[17]==before[17],"Retained packet stores addresses for later visibility-only uploads")
    entry.material.set_shader_parameter("current_visibility",0.0);entry.source_version+=1;atlas.sync(world)
    check(atlas.receivers[0].node.material.get_shader_parameter("receiver_visibility")==1.0,"Parameter recopy cannot overwrite per-instance current visibility")
    await pixel_oracle(atlas,world,source,"initial")
    # Explicit native source mutations, not invented gameplay: these exercise
    # sparse publication independently of current packet delivery mechanics.
    # An existing later nonfloor source makes insertion before it non-vacuous:
    # full repacking would relocate it when the floor batch grows.
    var marker=MeshInstance3D.new();marker.mesh=QuadMesh.new();marker.mesh.size=Vector2(2,2);marker.position=Vector3(0,2.1,0);world.add_child(marker)
    var marker_material:ShaderMaterial=entry.material.duplicate();marker.material_override=marker_material
    var marker_entry={"node":marker,"material":marker_material,"cell":Vector2(64,64),"record":entry.record,"role":"body","placement":{"id":"marker","kind":"object","position":[0,2],"base_height_steps":0},"scenery_value":1.0,"source_version":1}
    world.entries.append(marker_entry);atlas.sync(world)
    var retained_positions={}
    for receiver in atlas.receivers:retained_positions[receiver.id]=receiver.position
    var extra_data=PackedFloat32Array([1,0,0,3.3,0,1,0,0,0,0,1,0,1,1,1,1,1,0,0,0])
    entry.batch_rows.append({"id":"extra","kind":"terrain","material":"stone","position":[2,0],"base_height_steps":0})
    entry.ground_packets.extra={"data":extra_data};entry.scenery_values.append(1.0)
    entry.ground_buffer.append_array(extra_data);entry.node.multimesh.instance_count=3
    entry.node.multimesh.buffer=entry.ground_buffer;entry.node.multimesh.visible_instance_count=3
    entry.ground_version+=1;atlas.sync(world)
    check(atlas.receivers.size()==4,"Adding one disclosed source cell creates exactly one receiver")
    var stable=true
    for receiver in atlas.receivers:
        if retained_positions.has(receiver.id) and receiver.position!=retained_positions[receiver.id]:stable=false
    check(stable,"Sparse floor insertion preserves preceding floor and later nonfloor native atlas addresses")
    pixels.append_kept_positions=stable
    check(atlas.receivers[0].group.join_mask==1 and atlas.receivers[1].group.join_mask==5 and atlas.receivers[2].group.join_mask==4,"New ground neighbour changes both affected original join masks")
    await pixel_oracle(atlas,world,source,"addition")
    entry.batch_rows.pop_back();entry.ground_packets.erase("extra");entry.scenery_values.pop_back()
    entry.ground_buffer.resize(40);entry.node.multimesh.instance_count=2;entry.node.multimesh.buffer=entry.ground_buffer;entry.node.multimesh.visible_instance_count=2
    entry.ground_version+=1;atlas.sync(world)
    check(atlas.receivers.size()==3 and atlas.receivers[1].group.join_mask==4,"Removing source cell retires it and restores exposed neighbour")
    await pixel_oracle(atlas,world,source,"removal")
    world.entries.pop_back();marker.queue_free();atlas.sync(world)
    var refill=entry.ground_buffer.duplicate()
    entry.ground_buffer.fill(0)
    entry.ground_buffer=refill
    for i in 2:
        for channel in [17,18,19]:
            entry.ground_buffer[i*20+channel]=0;entry.ground_packets[str(i)].data[channel]=0
    entry.ground_version+=1;atlas.sync(world)
    check(entry.ground_buffer==refill,"Same-ID refill restores exact native addresses after sparse add/remove")
    await pixel_oracle(atlas,world,source,"refill")
    var replaced=entry.duplicate();replaced.scenery_values=[0.0,1.0];replaced.source_version+=1
    world.entries[0]=replaced;entry=replaced;atlas.sync(world)
    check(atlas.receivers.all(func(r):return is_same(r.entry,replaced)),"Replacement entry wrapper adopts current source/scenery owner around retained native node")
    check(atlas.receivers[0].visibility==0.0 and atlas.receivers[1].visibility==1.0,"Replacement owner uses its exact current-memory values")
    entry.erase("received_material");atlas.sync(world)
    check(entry.received_material.get_shader_parameter("atlas_cell_size")==Vector2(52,32)/Vector2(atlas.viewport.size),"Recreated floor output restores current cell normalization without membership changes")
    await pixel_oracle(atlas,world,source,"replacement")
    before=entry.ground_buffer.duplicate();repacks=atlas.repack_count
    var published=[1,0,"solid",0,true,true]
    var styles=[1,0,0,"solid"]
    atlas.sync(world,published,styles)
    var fast_pack=atlas.repack_count
    for i in 10:atlas.sync(world,published,styles)
    check(atlas.repack_count==fast_pack,"Idle published scene retains exact atlas layout")
    var projection_errors=0
    for settings in [Vector3(0.125,0.25,7.5),Vector3(-0.75,0.375,6.25),Vector3(0.0,0.0,12.5)]:
        camera.position=Vector3(settings.x,settings.y,10);camera.size=settings.z
        atlas.sync(world,published,styles)
        for receiver in atlas.receivers:
            for point in [Vector2(.5,.5),Vector2(25.5,15.5),Vector2(51.5,31.5)]:
                var full=point+Vector2(receiver.crop.pixels.position)
                var reference=camera.unproject_position(Vector3(-1.1+receiver.index*2.2+(full.x-32)/32.0,(32-full.y)/32.0,0))
                var projected=receiver.node.global_transform*point
                if projected.distance_to(reference)>.0001:projection_errors+=1
    check(projection_errors==0,"Native parent pan/zoom preserves independent original3D camera projection at source pixels")
    check(atlas.repack_count==fast_pack,"Pan and fractional zoom never repack source cells")
    # A shadow presentation handle is not a source receiver and has no cell.
    var shadow=MeshInstance3D.new();shadow.mesh=QuadMesh.new();world.add_child(shadow)
    world.actor_entries=[{"node":shadow,"generated_shadow":true}]
    atlas.sync(world,published,styles)
    check(atlas.errors.is_empty(),"Generated-shadow handle does not enter source receiver admission")
    shadow.queue_free();world.actor_entries=[]
    var old_rects=atlas.receivers.map(func(r):return [r.id,r.position])
    var old_view_size=atlas.viewport.size
    var large=MeshInstance3D.new();large.mesh=QuadMesh.new();var material=ShaderMaterial.new();material.shader=ActorSource;large.material_override=material;world.add_child(large)
    var extra={"node":large,"material":material,"cell":Vector2(9000,128),"placement":{"kind":"actor"},"role":"body","source_version":0}
    world.entries.append(extra);atlas.sync(world)
    check(not atlas.errors.is_empty(),"Oversized allocation fails explicitly")
    check(atlas.receivers.map(func(r):return [r.id,r.position])==old_rects and atlas.viewport.size==old_view_size and atlas.repack_count==repacks,"Rejected pack leaves prior atlas layout and viewport unchanged")
    check(large.material_override==material and entry.ground_buffer==before,"Rejected pack does not publish partial source overrides or addresses")
    world.entries.pop_back();large.queue_free();atlas.errors.clear();world.presentation_errors.clear()
    view.size=Vector2i(320,1200);camera.position=Vector3(0,0,10);camera.size=37.5;atlas.sync(world)
    check(atlas.viewport.size.y>=1200,"Window growth enlarges native receiving culling coverage")
    check(atlas.errors.is_empty(),"Viewport growth has a valid transactional layout")
    await pixel_oracle(atlas,world,source,"resize")
    atlas.close()
    check(entry.node.material_override==entry.material,"Closing atlas restores original source material")
    check(entry.ground_buffer[17]==0.0 and entry.ground_buffer[18]==0.0,"Closing clears owned atlas addresses while preserving source instance data")
    check(atlas.receivers.is_empty() and atlas.groups.is_empty() and atlas.viewport==null,"Closing releases receiver and shared material ownership")
    await process_frame
    var report={"renderer":RenderingServer.get_current_rendering_method(),"checks":checks,"failures":failures,"pixels":pixels,"scope":"Mathematical source fixture; original alpha bytes1/63/194/255; native cropped vs independent full-source receiver; lifecycle/transaction/viewport/packet publication. No gameplay expectation fabricated."}
    var f=FileAccess.open("res://generated/native_atlas_lifecycle_checks.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
    print("ATLAS_LIFECYCLE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
