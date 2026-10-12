extends SceneTree
const Atlas=preload("res://presentation/native_light_atlas.gd")
const Sources=preload("res://presentation/sprite_sources.gd")
const GroundData=preload("res://presentation/ground_data.gd")
const Placement=preload("res://placement.gd")
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
var world_generation:=0
var world_revision:=0
var scenery_revision:=0
var publication_serial:=0
var publication_changes:Dictionary={}
# Same published-world/style stamp fields used by Play. Source animation and
# highlight updates deliberately do not advance these scene revisions.
func sync_scene(atlas:RefCounted,world:World,changed:bool=false,restyle:bool=false,delta:Dictionary={})->void:
    if changed:
        world_generation+=1
        publication_changes={"base":delta.get("base",publication_serial),"serial":publication_serial+1,
            "full":delta.get("full",true),"upserts":delta.get("upserts",world.entries),"removed":delta.get("removed",[])}
        publication_serial+=1
    if changed or restyle:world_revision+=1
    if restyle:scenery_revision+=1
    atlas.sync(world,[world_generation,world_revision,0,"solid",scenery_revision,true,true],
        [world_generation,0,scenery_revision,"solid"],publication_changes)
    atlas.sync_output(world,[world_generation,0,scenery_revision,"solid",atlas.revision])
func sparse(upserts:Array=[],removed:Array=[])->Dictionary:
    return {"full":false,"upserts":upserts,"removed":removed}
func floor_receipt(entry:Dictionary,changed:Array=[],removed:Array=[])->void:
    # Same producer contract as prepared immutable rows. Empty changed IDs may
    # still replace/reorder a buffer; copied atlas UV bytes are never trusted.
    var indices={}
    for index in entry.batch_rows.size():indices[entry.batch_rows[index].id]=index
    entry.ground_indices=indices
    entry.geometry_changes={"base_version":entry.ground_version-1,"version":entry.ground_version,"changed":changed,"removed":removed}
func prepared_floor(entry:Dictionary,stale_ids:Array)->void:
    # Exercise actual producer preparation/publication. The copied old address
    # is deliberately stale in both records, as an in-flight worker may return.
    var packets={};var visibility={}
    for row in entry.batch_rows:
        var packet:Dictionary=entry.ground_packets[row.id].duplicate(true)
        packet.row=row;packet.y=Placement.project(Vector2(row.position[0],row.position[1]),0,0).y
        # Retained production packets already include bounds from their native
        # transform; the minimal mathematical source fixture must supply them.
        packet.bounds=entry.node.multimesh.get_instance_transform(entry.ground_indices[row.id])*entry.node.multimesh.mesh.get_aabb()
        if row.id in stale_ids:
            for channel in [17,18,19]:packet.data[channel]=0
        packets[row.id]=packet
        if entry.scenery_values[entry.ground_indices[row.id]]==1.0:visibility[row.id]=true
    var previous={"packets":packets,"receiver_bounds":entry.node.multimesh.mesh.get_aabb(),
        "capacity":entry.node.multimesh.instance_count,"ground_version":entry.ground_version}
    var prepared=GroundData.prepare(entry.batch_rows,previous,0,Basis.IDENTITY,visibility)
    # Production reserves instances in blocks of 256. This mathematical fixture
    # intentionally allocates exactly two; discard only unused capacity padding,
    # retaining every visible row and its full 20-float packet unchanged.
    prepared.buffer.resize(entry.node.multimesh.instance_count*20)
    var publisher=Sources.new();entry.pivot=Vector2(32,32);entry.scale=1.0
    publisher._ground_publish(entry,prepared);publisher.free()
func row_receiver(atlas:RefCounted,entry:Dictionary,row_id:String="source")->Dictionary:
    var wanted=str(entry.node.get_instance_id())+":"+row_id
    for receiver in atlas.receivers:
        if receiver.id==wanted:return receiver
    return {}
func check_transport(atlas:RefCounted,entry:Dictionary,label:String)->void:
    var output:ShaderMaterial=entry.received_material
    var matches=output.get_shader_parameter("received")==atlas.viewport.get_texture()
    matches=matches and output.get_shader_parameter("use_instance_atlas")==true
    matches=matches and entry.node.material_override==output
    var native:PackedFloat32Array=entry.node.multimesh.buffer
    for receiver in atlas.receivers:
        if not is_same(receiver.entry,entry) or receiver.index<0:continue
        matches=matches and output.get_shader_parameter("source_crop")==receiver.crop.uv
        matches=matches and output.get_shader_parameter("atlas_cell_size")==Vector2(receiver.crop.pixels.size)/Vector2(atlas.viewport.size)
        var offset:int=receiver.index*20
        var packet:PackedFloat32Array=entry.ground_packets[entry.batch_rows[receiver.index].id].data
        var pixel:Vector2i=receiver.position
        var expected=Vector3(pixel.x%1024,pixel.y%1024,pixel.x/1024+8*(pixel.y/1024))
        matches=matches and Vector3(native[offset+17],native[offset+18],native[offset+19])==expected
        matches=matches and Vector3(packet[17],packet[18],packet[19])==expected
    if atlas.light_cap>0.0 and not atlas.normals_visible:
        matches=matches and output.get_shader_parameter("use_instance_visibility")==true
    check(matches,label+" restores output texture/crop/cell and every native/retained packet address")
func set_visibility(entry:Dictionary,values:Array)->void:
    entry.scenery_values=values
    for index in values.size():
        entry.ground_buffer[index*20+16]=values[index]
        entry.ground_packets[entry.batch_rows[index].id].data[16]=values[index]
    entry.node.multimesh.buffer=entry.ground_buffer
func reverse_floor(entry:Dictionary)->void:
    entry.batch_rows.reverse();entry.scenery_values.reverse()
    entry.placement=entry.batch_rows[0]
    var buffer=PackedFloat32Array()
    for row in entry.batch_rows:buffer.append_array(entry.ground_packets[row.id].data)
    entry.ground_buffer=buffer;entry.node.multimesh.buffer=buffer;entry.ground_version+=1
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
    return {"node":node,"material":mat,"cell":Vector2(64,64),"record":{"path":"fixture","rect":[0,0,64,64]},"placement":rows[0],"role":"terrain","batch_rows":rows,"ground_buffer":buffer,"ground_packets":packets,"ground_indices":{"0":0,"1":1},"scenery_values":[1.0,0.0],"source_version":1,"ground_version":0}
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
    var one_to_one=true
    for receiver in atlas.receivers:
        var basis:Transform2D=receiver.node.global_transform
        one_to_one=one_to_one and is_equal_approx(basis.x.length(),1.0) and is_equal_approx(basis.y.length(),1.0)
    check(one_to_one,"Independent texel oracle uses one screen pixel per source pixel: "+label)
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
    # Both targets are sampled at the FIRST completed draw after publication;
    # there is no extra atlas sync or settled-frame retry to hide stale cells.
    await process_frame;await RenderingServer.frame_post_draw
    var packed=atlas.viewport.get_texture().get_image();var original=reference.get_texture().get_image()
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
    var atlas=Atlas.new();atlas.attach(world);sync_scene(atlas,world,true)
    check(atlas.errors.is_empty(),"Prepared original source accepted")
    check(atlas.receivers.size()==2 and atlas.groups.size()==2,"Mixed current and remembered floor instances use two shared native source materials")
    check(row_receiver(atlas,entry,"0").crop.pixels==Rect2i(6,12,52,32),"Crop preserves every nonzero source alpha including 1/255")
    check(atlas.packed_pixels==2*52*32,"Allocation is exact static colour bbox rather than full64-square cells")
    check(row_receiver(atlas,entry,"0").node.texture==row_receiver(atlas,entry,"1").node.texture,"Floor receivers share white texture; binary memory style is a material group")
    check(entry.material==entry.node.material_override or entry.node.material_override==entry.received_material,"Received override keeps original source material owned by entry")
    check(entry.node.material_override==entry.received_material and entry.received_material!=entry.material,"Only output override changes; source material remains distinct")
    check(row_receiver(atlas,entry,"0").node.material.get_shader_parameter("receiver_visibility")==1.0 and row_receiver(atlas,entry,"1").node.material.get_shader_parameter("receiver_visibility")==0.0,"Mixed current and remembered instances remain distinct")
    var repacks=atlas.repack_count;world.actor_revision+=20;sync_scene(atlas,world)
    check(atlas.repack_count==repacks,"Actor revisions cannot repack unchanged receiver membership")
    check(atlas.last_reconcile_phases.get("projected_receivers",0)==0,"Unchanged receiver admission does not reproject the whole static map")
    var unchanged_transform=row_receiver(atlas,entry,"1").node.transform
    entry.ground_packets["0"].data[3]+=.25;entry.ground_buffer[3]+=.25;entry.ground_version+=1
    entry.node.multimesh.buffer=entry.ground_buffer;sync_scene(atlas,world,true)
    check(atlas.last_reconcile_phases.projected_receivers==1 and row_receiver(atlas,entry,"1").node.transform==unchanged_transform,"Exact changed floor transform projects only its receiver, even with unchanged row IDs")
    entry.ground_packets["0"].data[3]-=.25;entry.ground_buffer[3]-=.25;entry.ground_version+=1;entry.node.multimesh.buffer=entry.ground_buffer;sync_scene(atlas,world,true)
    check(atlas.last_reconcile_phases.projected_receivers==1,"Restored native floor transform is detected independently of source colour")
    var before=entry.ground_buffer.duplicate()
    for i in 2:
        entry.ground_buffer[i*20+17]=0;entry.ground_buffer[i*20+18]=0
        entry.ground_packets[str(i)].data[17]=0;entry.ground_packets[str(i)].data[18]=0
    entry.ground_version+=1;entry.node.multimesh.buffer=entry.ground_buffer;sync_scene(atlas,world,true)
    check(entry.ground_buffer==before,"Same-membership floor publication restores every native atlas address")
    check(atlas.repack_count==repacks,"Replacing floor packet does not repack stable source cells")
    check(atlas.last_reconcile_phases.projected_receivers==0,"Same transform floor buffer publication restores addresses without reprojection")
    prepared_floor(entry,["0"]);sync_scene(atlas,world,true,false,sparse([entry]))
    check(entry.ground_buffer==before,"Certified coherent worker data still repairs stale addresses against current atlas")
    check(atlas.last_reconcile_phases.address_packet_reads==1 and atlas.last_reconcile_phases.address_packet_reads_skipped==1,"Coherent unchanged row avoids duplicate packet access while stale row is repaired")
    check_transport(atlas,entry,"Prepared stale-address repair")
    await pixel_oracle(atlas,world,source,"prepared-address-repair")
    # A direct packet-only mutation breaks the producer coherence guarantee.
    # Its native buffer remains correct and must not hide the stale packet.
    entry.ground_packets["0"].data[17]=0;entry.ground_version+=1;floor_receipt(entry)
    sync_scene(atlas,world,true,false,sparse([entry]))
    check(atlas.last_reconcile_phases.address_packet_reads_skipped==0,"Direct update cannot reuse the previous prepared-buffer coherence version")
    check_transport(atlas,entry,"Independent packet-only address repair")
    await pixel_oracle(atlas,world,source,"direct-packet-address-repair")
    entry.material.set_shader_parameter("highlighted",true);sync_scene(atlas,world)
    check(atlas.groups.values().all(func(g):return g.material.get_shader_parameter("highlighted")==true),"Independent highlight updates receiving without source-version change")
    entry.material.set_shader_parameter("highlighted",false);sync_scene(atlas,world)
    entry.material.set_shader_parameter("source_tint",Color(.5,.75,1,1));entry.source_version+=1;sync_scene(atlas,world)
    check(atlas.groups.values().all(func(g):return g.material.get_shader_parameter("source_tint")==Color(.5,.75,1,1)),"Versioned source tint updates receiving")
    entry.material.set_shader_parameter("source_tint",Color.WHITE);entry.source_version+=1;sync_scene(atlas,world)
    check(entry.ground_packets["0"].data[17]==before[17],"Retained packet stores addresses for later visibility-only uploads")
    entry.material.set_shader_parameter("current_visibility",0.0);entry.source_version+=1;sync_scene(atlas,world)
    check(row_receiver(atlas,entry,"0").node.material.get_shader_parameter("receiver_visibility")==1.0,"Parameter recopy cannot overwrite per-instance current visibility")
    await pixel_oracle(atlas,world,source,"initial")
    # Sight-only after-values keep the same source material, row IDs and native
    # floor packets. The style stamp must still update the receiving result.
    set_visibility(entry,[0.0,1.0])
    sync_scene(atlas,world,false,true)
    check(row_receiver(atlas,entry,"0").visibility==0.0 and row_receiver(atlas,entry,"1").visibility==1.0,"Style-only publication updates retained current/memory receivers")
    await pixel_oracle(atlas,world,source,"style-only")
    set_visibility(entry,[1.0,0.0]);sync_scene(atlas,world,false,true)
    # Explicit native source mutations, not invented gameplay: these exercise
    # sparse publication independently of current packet delivery mechanics.
    # An existing later unbatched source makes insertion before it non-vacuous:
    # full repacking would relocate it when the floor batch grows.
    var marker=MeshInstance3D.new();marker.mesh=QuadMesh.new();marker.mesh.size=Vector2(2,2);marker.position=Vector3(0,2.1,0);world.add_child(marker)
    var marker_material:ShaderMaterial=entry.material.duplicate();marker.material_override=marker_material
    var marker_entry={"node":marker,"material":marker_material,"cell":Vector2(64,64),"record":entry.record,"role":"terrain","placement":{"id":"marker","kind":"terrain","material":"stone","position":[0,2],"base_height_steps":1},"scenery_value":1.0,"source_version":1}
    world.entries.append(marker_entry);sync_scene(atlas,world,true,false,sparse([marker_entry]))
    var retained_positions={}
    for receiver in atlas.receivers:retained_positions[receiver.id]=receiver.position
    var extra_data=PackedFloat32Array([1,0,0,3.3,0,1,0,0,0,0,1,0,1,1,1,1,1,0,0,0])
    entry.batch_rows.append({"id":"extra","kind":"terrain","material":"stone","position":[2,0],"base_height_steps":0})
    entry.ground_packets.extra={"data":extra_data};entry.scenery_values.append(1.0)
    entry.ground_buffer.append_array(extra_data);entry.node.multimesh.instance_count=3
    entry.node.multimesh.buffer=entry.ground_buffer;entry.node.multimesh.visible_instance_count=3
    entry.ground_version+=1;entry.node.multimesh.buffer=entry.ground_buffer;floor_receipt(entry,["extra"])
    sync_scene(atlas,world,true,false,sparse([entry]))
    check(atlas.receivers.size()==4,"Adding one disclosed source cell creates exactly one receiver")
    var stable=true
    for receiver in atlas.receivers:
        if retained_positions.has(receiver.id) and receiver.position!=retained_positions[receiver.id]:stable=false
    check(stable,"Sparse floor insertion preserves preceding floor and later unbatched native atlas addresses")
    pixels.append_kept_positions=stable
    check(row_receiver(atlas,entry,"0").group.join_mask==1 and row_receiver(atlas,entry,"1").group.join_mask==5 and row_receiver(atlas,entry,"extra").group.join_mask==4,"New ground neighbour changes both affected original join masks")
    check_transport(atlas,entry,"Sparse addition")
    await pixel_oracle(atlas,world,source,"addition")
    entry.batch_rows.pop_back();entry.ground_packets.erase("extra");entry.scenery_values.pop_back()
    entry.ground_buffer.resize(40);entry.node.multimesh.instance_count=2;entry.node.multimesh.buffer=entry.ground_buffer;entry.node.multimesh.visible_instance_count=2
    entry.ground_version+=1;entry.node.multimesh.buffer=entry.ground_buffer;floor_receipt(entry,[],["extra"])
    sync_scene(atlas,world,true,false,sparse([entry]))
    check(atlas.receivers.size()==3 and row_receiver(atlas,entry,"1").group.join_mask==4,"Removing source cell retires it and restores exposed neighbour")
    check_transport(atlas,entry,"Sparse removal")
    await pixel_oracle(atlas,world,source,"removal")
    # Named individual-terrain fixture: the same receiver becomes the disclosed
    # neighbour of the retained batch, then changes elevation without changing ID.
    marker_entry.placement={"id":"marker","kind":"terrain","material":"stone","position":[2,0],"base_height_steps":1}
    marker.position.y+=.25
    sync_scene(atlas,world,true,false,sparse([marker_entry]))
    check(row_receiver(atlas,entry,"1").group.join_mask==5 and row_receiver(atlas,marker_entry).group.join_mask==0,"Higher individual support covers adjacent lower floor but keeps its own exposed return")
    await pixel_oracle(atlas,world,source,"higher-neighbour")
    marker_entry.placement=marker_entry.placement.duplicate();marker_entry.placement.base_height_steps=-1
    marker.position.y-=.5;sync_scene(atlas,world,true,false,sparse([marker_entry]))
    check(row_receiver(atlas,entry,"1").group.join_mask==4 and row_receiver(atlas,marker_entry).group.join_mask==4,"Same-ID lower support exposes retained neighbour and uses its current height")
    await pixel_oracle(atlas,world,source,"lower-neighbour")
    # Two original supports can share a cell. Removing the taller owner must
    # retain the lower owner and recompute its neighbours, not erase the cell.
    var higher=MeshInstance3D.new();higher.mesh=marker.mesh;higher.position=Vector3(0,-2.1,0);world.add_child(higher)
    var higher_material:ShaderMaterial=marker_material.duplicate();higher.material_override=higher_material
    var higher_entry={"node":higher,"material":higher_material,"cell":Vector2(64,64),"record":entry.record,"role":"terrain",
        "placement":{"id":"higher","kind":"terrain","material":"stone","position":[2,0],"base_height_steps":1},"scenery_value":1.0,"source_version":1}
    world.entries.append(higher_entry);sync_scene(atlas,world,true,false,sparse([higher_entry]))
    check(row_receiver(atlas,entry,"1").group.join_mask==5,"Maximum of two admitted support owners closes the retained neighbour")
    await pixel_oracle(atlas,world,source,"shared-support")
    var higher_id=higher.get_instance_id();world.entries.pop_back();higher.queue_free()
    sync_scene(atlas,world,true,false,sparse([],[higher_id]))
    check(row_receiver(atlas,entry,"1").group.join_mask==4 and not row_receiver(atlas,marker_entry).is_empty(),"Removing only maximum support retains lower owner and exposes its neighbour")
    await pixel_oracle(atlas,world,source,"shared-support-removed")
    marker_entry.placement={"id":"marker","kind":"terrain","material":"stone","position":[-1,0],"base_height_steps":1}
    sync_scene(atlas,world,true,false,sparse([marker_entry]))
    check(row_receiver(atlas,entry,"0").group.join_mask==5 and row_receiver(atlas,entry,"1").group.join_mask==4,"Moved support invalidates both its old and new incident cells")
    await pixel_oracle(atlas,world,source,"moved-support")
    # Full fallback can recycle one retired standalone receiver into a new floor
    # instance. Its former row identity must not address the new floor buffer.
    world.entries.pop_back();marker.visible=false
    var crossing_data=PackedFloat32Array([1,0,0,3.3,0,1,0,0,0,0,1,0,1,1,1,1,1,0,0,0])
    entry.batch_rows.append({"id":"cross-kind","kind":"terrain","material":"stone","position":[2,0],"base_height_steps":0})
    entry.ground_packets["cross-kind"]={"data":crossing_data};entry.scenery_values.append(1.0)
    entry.ground_buffer.append_array(crossing_data);entry.node.multimesh.instance_count=3
    entry.node.multimesh.buffer=entry.ground_buffer;entry.node.multimesh.visible_instance_count=3
    entry.ground_version+=1;floor_receipt(entry,["cross-kind"])
    sync_scene(atlas,world,true)
    check(atlas.errors.is_empty() and row_receiver(atlas,entry,"cross-kind").index==2,"Full fallback replaces standalone source with the exact new floor instance")
    check_transport(atlas,entry,"Standalone-to-floor full fallback")
    await pixel_oracle(atlas,world,source,"standalone-to-floor")
    entry.batch_rows.pop_back();entry.ground_packets.erase("cross-kind");entry.scenery_values.pop_back()
    entry.ground_buffer.resize(40);entry.node.multimesh.instance_count=2
    entry.node.multimesh.buffer=entry.ground_buffer;entry.node.multimesh.visible_instance_count=2
    entry.ground_version+=1;floor_receipt(entry,[],["cross-kind"])
    world.entries.append(marker_entry);marker.visible=true;sync_scene(atlas,world,true)
    check(atlas.errors.is_empty() and row_receiver(atlas,marker_entry).index==-1,"Full fallback replaces removed floor instance with standalone source")
    check(marker.material_override==marker_entry.received_material and marker_entry.received_material.get_shader_parameter("use_instance_atlas")==false,"Floor-to-standalone fallback restores the source output transport")
    check_transport(atlas,entry,"Floor-to-standalone full fallback")
    await pixel_oracle(atlas,world,source,"floor-to-standalone")
    var removed_marker=marker.get_instance_id()
    world.entries.pop_back();marker.queue_free();sync_scene(atlas,world,true,false,sparse([],[removed_marker]))
    var refill=entry.ground_buffer.duplicate()
    entry.ground_buffer.fill(0)
    entry.ground_buffer=refill
    for i in 2:
        for channel in [17,18,19]:
            entry.ground_buffer[i*20+channel]=0;entry.ground_packets[str(i)].data[channel]=0
    entry.ground_version+=1;entry.node.multimesh.buffer=entry.ground_buffer;floor_receipt(entry)
    sync_scene(atlas,world,true,false,sparse([entry]))
    check(entry.ground_buffer==refill,"Same-ID refill restores exact native addresses after sparse add/remove")
    check_transport(atlas,entry,"Same-ID refill")
    await pixel_oracle(atlas,world,source,"refill")
    var original_positions={}
    for receiver in atlas.receivers:original_positions[entry.batch_rows[receiver.index].id]=receiver.position
    reverse_floor(entry);floor_receipt(entry);sync_scene(atlas,world,true,false,sparse([entry]))
    var reordered=true
    for receiver in atlas.receivers:
        reordered=reordered and receiver.position==original_positions[entry.batch_rows[receiver.index].id]
    check(reordered and entry.placement.id=="1","Floor reorder updates representative/index while retaining each tile's atlas cell")
    check_transport(atlas,entry,"Same-ID reorder")
    await pixel_oracle(atlas,world,source,"reorder")
    reverse_floor(entry);floor_receipt(entry);sync_scene(atlas,world,true,false,sparse([entry]))
    check_transport(atlas,entry,"Restored floor order")
    # A missing producer receipt invalidates the sparse proof. Full admission
    # must recover a transform absent from the supplied upsert list.
    var before_missed=row_receiver(atlas,entry,"0").node.transform
    entry.ground_packets["0"].data[3]+=.125;entry.ground_buffer[3]+=.125;entry.ground_version+=1
    entry.node.multimesh.buffer=entry.ground_buffer;floor_receipt(entry)
    var missed=sparse();missed.base=publication_serial-1
    sync_scene(atlas,world,true,false,missed)
    check(row_receiver(atlas,entry,"0").node.transform!=before_missed,"Missed publication serial recovers undisclosed delta through full source fallback")
    check_transport(atlas,entry,"Missed publication fallback")
    await pixel_oracle(atlas,world,source,"missed-publication")
    entry.ground_packets["0"].data[3]-=.125;entry.ground_buffer[3]-=.125;entry.ground_version+=1
    entry.node.multimesh.buffer=entry.ground_buffer;entry.erase("geometry_changes")
    sync_scene(atlas,world,true)
    var replaced=entry.duplicate();replaced.source_version+=1
    world.entries[0]=replaced;entry=replaced;set_visibility(entry,[0.0,1.0]);sync_scene(atlas,world,true,true,sparse([entry],[entry.node.get_instance_id()]))
    check(atlas.receivers.all(func(r):return is_same(r.entry,replaced)),"Replacement entry wrapper adopts current source/scenery owner around retained native node")
    check(row_receiver(atlas,entry,"0").visibility==0.0 and row_receiver(atlas,entry,"1").visibility==1.0,"Replacement owner uses its exact current-memory values")
    entry.erase("received_material");sync_scene(atlas,world,true,false,sparse([entry]))
    check(entry.received_material.get_shader_parameter("atlas_cell_size")==Vector2(52,32)/Vector2(atlas.viewport.size),"Recreated floor output restores current cell normalization without membership changes")
    check_transport(atlas,entry,"Recreated LDR floor output")
    await pixel_oracle(atlas,world,source,"replacement")
    var old_output:ShaderMaterial=entry.received_material
    var original_ldr=await capture(view)
    atlas.set_light_cap(1.0);sync_scene(atlas,world)
    check(atlas.viewport.use_hdr_2d and entry.received_material.get_shader_parameter("light_cap")==1.0,"Cap enables HDR receiving on retained floor sources")
    check_transport(atlas,entry,"Cap output")
    entry.erase("received_material");sync_scene(atlas,world,true,false,sparse([entry]))
    check(entry.received_material!=old_output,"Material recreation installs a distinct output while source membership stays unchanged")
    check_transport(atlas,entry,"Recreated capped floor output")
    atlas.set_normals_visible(true);sync_scene(atlas,world)
    check(not atlas.viewport.use_hdr_2d,"Normals keeps native LDR while cap preference remains enabled")
    check_transport(atlas,entry,"Normals output")
    var normals=await capture(view)
    atlas.set_light_cap(0.0);sync_scene(atlas,world)
    check(normals.get_data()==(await capture(view)).get_data(),"Normals framebuffer is byte-exact when cap preference toggles")
    atlas.set_light_cap(1.0);atlas.set_normals_visible(false);sync_scene(atlas,world)
    check(atlas.viewport.use_hdr_2d,"Leaving Normals restores capped HDR receiving")
    check_transport(atlas,entry,"Restored capped output")
    atlas.set_light_cap(0.0);sync_scene(atlas,world)
    check(not atlas.viewport.use_hdr_2d and original_ldr.get_data()==(await capture(view)).get_data(),"Cap/Normals roundtrip restores original final LDR framebuffer byte-exactly")
    check_transport(atlas,entry,"Restored LDR output")
    await pixel_oracle(atlas,world,source,"cap-restoration")
    before=entry.ground_buffer.duplicate();repacks=atlas.repack_count
    sync_scene(atlas,world)
    var fast_pack=atlas.repack_count
    for i in 10:sync_scene(atlas,world)
    check(atlas.repack_count==fast_pack,"Idle published scene retains exact atlas layout")
    var projection_errors=0
    for settings in [Vector3(0.125,0.25,7.5),Vector3(-0.75,0.375,6.25),Vector3(0.0,0.0,12.5)]:
        camera.position=Vector3(settings.x,settings.y,10);camera.size=settings.z
        sync_scene(atlas,world)
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
    sync_scene(atlas,world)
    check(atlas.errors.is_empty(),"Generated-shadow handle does not enter source receiver admission")
    shadow.queue_free();world.actor_entries=[]
    # The preceding pan/zoom proof deliberately minifies. This source-texel
    # oracle needs 1:1 sampling: a minified reference cannot contain every source
    # texel independently. Reset BEFORE the failure and first recovery draw.
    camera.position=Vector3(0,0,10);camera.size=7.5;sync_scene(atlas,world)
    var before_failed_pack=await capture(view)
    var old_rects=atlas.receivers.map(func(r):return [r.id,r.position])
    var old_view_size=atlas.viewport.size
    var large=MeshInstance3D.new();large.mesh=QuadMesh.new();var material=ShaderMaterial.new();material.shader=ActorSource;large.material_override=material;world.add_child(large)
    var extra={"node":large,"material":material,"cell":Vector2(9000,128),"placement":{"kind":"actor"},"role":"body","source_version":0}
    world.entries.append(extra);sync_scene(atlas,world,true,false,sparse([extra]))
    check(not atlas.errors.is_empty(),"Oversized allocation fails explicitly")
    check(atlas.receivers.map(func(r):return [r.id,r.position])==old_rects and atlas.viewport.size==old_view_size and atlas.repack_count==repacks,"Rejected pack leaves prior atlas layout and viewport unchanged")
    check(large.material_override==material and entry.ground_buffer==before,"Rejected pack does not publish partial source overrides or addresses")
    var rejected_id=large.get_instance_id()
    world.entries.pop_back();large.queue_free();atlas.errors.clear();world.presentation_errors.clear()
    sync_scene(atlas,world,true,false,sparse([],[rejected_id]))
    check(atlas.errors.is_empty() and atlas.receivers.size()==2,"Valid sparse publication recovers after rejected pack without poisoned caches")
    check_transport(atlas,entry,"Sparse retry after rejected pack")
    await pixel_oracle(atlas,world,source,"failed-pack-recovery")
    check(before_failed_pack.get_data()==view.get_texture().get_image().get_data(),"First recovered publication restores exact prior final framebuffer")
    view.size=Vector2i(320,1200);camera.position=Vector3(0,0,10);camera.size=37.5;sync_scene(atlas,world,true)
    check(atlas.viewport.size.y>=1200,"Window growth enlarges native receiving culling coverage")
    check(atlas.errors.is_empty(),"Viewport growth has a valid transactional layout")
    await pixel_oracle(atlas,world,source,"resize")
    atlas.close()
    check(entry.node.material_override==entry.material,"Closing atlas restores original source material")
    check(entry.ground_buffer[17]==0.0 and entry.ground_buffer[18]==0.0,"Closing clears owned atlas addresses while preserving source instance data")
    check(atlas.receivers.is_empty() and atlas.groups.is_empty() and atlas.viewport==null,"Closing releases receiver and shared material ownership")
    await process_frame
    var report={"renderer":RenderingServer.get_current_rendering_method(),"checks":checks,"failures":failures,"pixels":pixels,"scope":"Mathematical source fixture; original alpha bytes1/63/194/255; native cropped vs independent full-source receiver; production-shaped admission/style/serial receipts; sparse upsert/remove; skipped-serial full fallback; first-publication pixels; support elevation/movement/neighbour and duplicate-owner changes; same-ID packet refill/reorder and output recreation; actual prepared-buffer coherence with stale addresses; independent direct packet mismatch; cap/Normals binding restoration; standalone/floor recycling in full fallback; rejected-pack sparse retry; lifecycle/transaction/viewport. Independent LDR source pixel oracle unchanged. No gameplay expectation fabricated."}
    var f=FileAccess.open("res://generated/native_atlas_lifecycle_checks.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
    print("ATLAS_LIFECYCLE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
