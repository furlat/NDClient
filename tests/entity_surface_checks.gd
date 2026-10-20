extends SceneTree
## Real worker measurements from admitted images, without textures or disk IO.
const Surface=preload("res://presentation/entity_surface.gd")
const Index=preload("res://presentation/resources/body_source_index.gd")
const Layer=preload("res://presentation/resources/body_source_layer.gd")
const Clip=preload("res://presentation/resources/body_source_clip.gd")
const NativeRenderer=preload("res://presentation/native_spell_renderer.gd")
class World extends Node3D:
    var visual_actors:Dictionary={}
    var source_images:Dictionary={}
    var catalog_cache:Dictionary={}
    var character_light_profile:String="reference"
    var camera:Node3D
    var timeline:RefCounted=preload("res://presentation/timeline.gd").new()
    var quarter:int=0
    var rig_config:Dictionary={"TILE_W":128,"FACING_CYCLE":["SW"]}
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("SURFACE_FAIL "+label)
func image(colour:Color)->Image:
    var value:Image=Image.create(4,2,false,Image.FORMAT_RGBA8);value.fill(colour);return value
func entry(world:World,marker:Node3D,slot:String)->Dictionary:
    var node:Node3D=Node3D.new();marker.add_child(node);node.basis=world.camera.basis
    return {"node":node,"actor_layer":{"slot":slot,"effect":{}},"role":"body","texture_path":"fixture:colour","pivot":Vector2(1,2),"geometry_ground_pixels":0.0,
        "source_parameters":{"frame_uv":Vector4(0,0,.5,1),"component_units":.1,"component_elevation":PI/6,"component_reconstruction_origin":Vector2(1,2),"component_depth_range":Vector2(-1,1)}}
func actor(world:World,id:String,position:Vector3)->void:
    var marker:Node3D=Node3D.new();marker.name=id;world.add_child(marker);marker.position=position
    world.visual_actors[id]={"valid":true,"row":{"position":[position.x,position.z],"base_height_steps":position.y/Surface.Placement.HEIGHT_UNIT,"visual_height":0.0},"entries":[entry(world,marker,"body"),entry(world,marker,"helmet")]}
func ready(surface:RefCounted,world:World,id:String)->Dictionary:
    var packet:Dictionary=surface.sample(world,id)
    var deadline:int=Time.get_ticks_msec()+4000
    while not packet.ready and Time.get_ticks_msec()<deadline:
        await process_frame;packet=surface.sample(world,id)
    return packet
func future_tracks(world:World,index:Resource,layer:Resource,descriptor:Dictionary)->void:
    # Small optical fixture, not additional game or wire evidence. Actual
    # received first-hit tracks are exercised by the native rendering gate.
    var rig:Dictionary={"cell_width":2,"cell_height":2,"origin_y_from_ground":0,"facing_rows":{"SW":0},
        "slot_order":["body","helmet"],"slot_categories":{"body":["part"],"helmet":["part"]},
        "clips":{"Idle":{"frames":2,"fps":2},"TakeDamage":{"frames":2,"fps":2,"loop":false}}}
    index.root_rig="other";index.creature_rigs={"fixture":"fixture-rig"};index.rigs={"fixture-rig":rig}
    index.layers={"fixture-rig":{"part":"fixture:layer"}}
    layer.paths_by_slot={"body":{"Idle":"fixture:colour","TakeDamage":"fixture:future"},"helmet":{"Idle":"fixture:colour","TakeDamage":"fixture:future"}}
    var future:Resource=Clip.new();var geometry:Dictionary=descriptor.duplicate(true)
    geometry.geometry.merge({"status":"exact","depth_range":[-1,1],"cell_size":[2,2],"optical_ground_pixels":0.0,
        "optical_camera":{"origin":[1,2],"elevation_degrees":30.0}},true)
    future.descriptors={"*":geometry};index.source_owners["fixture:future"]=["fixture:layer","TakeDamage"]
    layer.clip_sources.TakeDamage="fixture:future-clip"
    world.catalog_cache[Surface.Geometry.BodySources.KEY].loaded["fixture:future-clip"]=future
    var tracks:Array=[];var interests:Array=[]
    for id in ["knight_a","knight_b"]:
        tracks.append({"actor_uuid":id,"rig":"fixture-rig","clip":"TakeDamage","start_ms":500.0,"duration_ms":1000.0,"priority":30,
            "source_start_seconds":0.0,"source_end_seconds":1.0,"presentation_item_looks":{},
            "presentation_actor":{"uuid":id,"creature_content_ref":"core:creature:fixture@1","life_state":"alive",
                "appearance":{"visual_scale":Surface.Placement.PIXELS_PER_UNIT*.1,"visual_scale_x":1.0}}})
        interests.append({"actor":id,"slots":["body","helmet"],"reason":""})
    var lower:Dictionary=tracks[0].duplicate(true);lower.priority=10;lower.source_start_seconds=.5
    tracks.push_front(lower)
    var group:Dictionary={"id":"private-source-fixture","duration_ms":1500.0,"actor_tracks":tracks}
    world.timeline.current=group;world.timeline.state={"fixture_prefix":"before_hit"}
    var canonical:PackedByteArray=var_to_bytes(world.timeline.state)
    var producer:RefCounted=Surface.new()
    producer.prepare_received_tracks(world,[group],interests)
    check(producer.jobs.is_empty() and producer.pending.is_empty(),"Missing future media waits for the existing admission lane, without fallback images or disk work")
    check(producer.received_poses.size()==4 and producer.received_poses.all(func(row):return row.path=="fixture:future" and row.frames==[0,1]),"Only exact received TakeDamage source frames are selected for the two actual optical slot sets")
    check(producer.received_poses[0].frames[0]==0,"Existing Tracks.samples arbitration rejects an overlapping lower-priority source clock")
    var native:RefCounted=NativeRenderer.new();native.inputs.surfaces=producer
    native._image_requirements(world)
    var required:Dictionary=Surface.required_paths("fixture:future","body",world.catalog_cache,"reference")
    check(required.size()==5 and required.keys().all(func(path):return native.required_images.has(path) and native.required_cpu_images.has(path)),"Exact future colour, depth, support, valid-normal mask and selected normal enter the existing async media demand before their images exist")
    producer.prepare_received_tracks(world,[],[]);native._image_requirements(world)
    check(native.required_cpu_images.is_empty(),"Changing only future optical interests invalidates image ownership and retires their CPU demand")
    producer.prepare_received_tracks(world,[group],interests);native._image_requirements(world)
    check(required.keys().all(func(path):return native.required_cpu_images.has(path)),"Restored future source interest reuses the normal image owner without a loader or readiness gate")
    var scans:int=producer.received_scans
    world.source_images["fixture:future"]=world.source_images["fixture:colour"]
    var deadline:int=Time.get_ticks_msec()+4000
    while producer.source_builds<2 and Time.get_ticks_msec()<deadline:
        producer.prepare_received_tracks(world,[group],interests);await process_frame
    producer.poll()
    check(producer.source_builds==2 and producer.sources.size()==2,"Both actors and their overlapping slots share one worker result per exact future physical source frame")
    check(producer.received_scans==scans,"Unchanged received owner retries media without rescanning every track each frame")
    producer.prepare_received_tracks(world,[],[])
    check(producer.received_poses.is_empty() and producer.sources.size()==2,"An empty received owner retires only future interest and preserves shared completed optical measurements")
    producer.prepare_received_tracks(world,[group],interests)
    scans=producer.received_scans
    world.timeline.retained_directions.knight_a=[[0,0],[1,0]]
    producer.prepare_received_tracks(world,[group],interests)
    check(producer.received_scans==scans+1,"In-place retained direction publication invalidates the small preparation snapshot")
    check(world.timeline.display_ms==0.0 and var_to_bytes(world.timeline.state)==canonical and world.visual_actors.knight_a.entries[0].texture_path=="fixture:colour","Future optical work neither publishes a pose nor advances the canonical prefix/clock")
    var built:int=producer.source_builds
    for id in ["knight_a","knight_b"]:
        for shown in world.visual_actors[id].entries:shown.texture_path="fixture:future"
        var packet:Dictionary=producer.sample(world,id)
        check(packet.ready and producer.source_builds==built and producer.jobs.is_empty() and producer.pending.is_empty(),"The exact first displayed TakeDamage frame is immediately shared with zero new source work: "+id)
    check(producer.sources.size()<=Surface.SOURCE_LIMIT and producer.pending.size()<=Surface.PENDING_LIMIT,"Received preparation retains the existing finite cache/queue bounds")
    producer.clear()
    check(producer.received_groups.is_empty() and producer.received_poses.is_empty() and producer.jobs.is_empty(),"Epoch cleanup retires its future operands and joins only owned finite work")
    for id in ["knight_a","knight_b"]:
        for shown in world.visual_actors[id].entries:shown.texture_path="fixture:colour"
    world.source_images.erase("fixture:future")
func run()->void:
    var world:World=World.new();root.add_child(world)
    world.camera=Node3D.new();world.add_child(world.camera);world.camera.basis=Basis.from_euler(Vector3(-PI/6,PI/4,0))
    var index:Resource=Index.new();var layer:Resource=Layer.new();var clip:Resource=Clip.new()
    index.source_owners={"fixture:colour":["fixture:layer","Idle"]};layer.clip_sources={"Idle":"fixture:clip"}
    var descriptor:Dictionary={"geometry":{"_source_root":"fixture:","files":{"depth":"depth","support":"support","normal_valid":"normal_valid"}},"normal_paths":{"reference":"fixture:normal","gentle":"fixture:unused-normal","original":"fixture:other-normal"}}
    clip.descriptors={"*":descriptor}
    world.catalog_cache["__body_source_admission"]={"index":index,"loaded":{"fixture:layer":layer,"fixture:clip":clip}}
    var colour:Image=image(Color.WHITE);colour.set_pixel(1,0,Color.TRANSPARENT)
    var support:Image=image(Color.WHITE);support.set_pixel(0,1,Color.BLACK)
    var valid:Image=image(Color.WHITE);valid.set_pixel(1,1,Color.BLACK)
    world.source_images={"fixture:colour":colour,"fixture:/depth":image(Color(32.0/255,0,0,1)),"fixture:/support":support,"fixture:/normal_valid":valid,"fixture:normal":image(Color(.5,.5,1,1))}
    # Use actual joined path values, independent of platform path spelling.
    for field in ["depth","support","normal_valid"]:
        world.source_images["fixture:".path_join(field)]=world.source_images["fixture:/"+field]
    var required:Dictionary=Surface.required_paths("fixture:colour","body",world.catalog_cache,"reference")
    check(required.size()==5 and required.has("fixture:normal") and not required.has("fixture:unused-normal"),"Only the selected optical normal and its exact masks are admitted")
    actor(world,"knight_a",Vector3.ZERO);actor(world,"knight_b",Vector3(10,2,-4))
    var producer:RefCounted=Surface.new()
    var first:Dictionary=producer.sample(world,"knight_a")
    check(not first.ready and first.reason=="surface_source_preparing" and producer.source_builds==0,"A cold sample requests worker preparation without scanning or returning a fake ready packet")
    check(producer.jobs.size()<=Surface.WORKER_LIMIT,"Only two finite source measurements may run at once")
    var a:Dictionary=await ready(producer,world,"knight_a")
    check(a.ready and a.points.size()==1,"Opaque colour, depth alpha, support and normal-valid masks jointly determine actual optical points")
    check(a.points[0].slot=="helmet","Source-over ownership chooses the visible top layer once")
    var built:int=producer.source_builds
    var b:Dictionary=await ready(producer,world,"knight_b")
    check(b.ready and producer.source_builds==built,"Two knights share one immutable physical source-pose measurement")
    check((b.points[0].position-a.points[0].position).is_equal_approx(Vector3(10,2,-4)),"Recipient transforms remain private although source points are shared")
    check(not is_same(a.points,b.points),"Recipient packets do not share mutable point ownership")
    var packet_builds:int=producer.packet_builds
    var same:Dictionary=producer.sample(world,"knight_a")
    check(producer.packet_builds==packet_builds and is_same(same.points,a.points),"An unchanged frame borrows its composed packet without another point walk")
    var node:Node3D=world.visual_actors.knight_a.entries[1].node;node.position.x+=1
    var moved:Dictionary=producer.sample(world,"knight_a")
    check(moved.ready and producer.source_builds==built and producer.packet_builds==packet_builds+1,"Transform changes rebuild only the recipient packet, without optical rescanning")
    check(is_equal_approx(moved.points[0].position.x,a.points[0].position.x+1),"A changed layer transform is reflected immediately")
    var images:Dictionary={"colour":colour,"depth":world.source_images["fixture:".path_join("depth")],"support":support,"normal_valid":valid,"normal":world.source_images["fixture:normal"]}
    var pose:Array=[Vector4(0,0,.5,1),.1,PI/6,Vector2(1,2),Vector2(-1,1),Vector2(1,2),0.0,world.camera.basis]
    var key:Array=Surface._source_key("fixture:colour","reference",images,pose)
    var next_pose:Array=pose.duplicate();next_pose[7]=Basis.from_euler(Vector3(-PI/6,3*PI/4,0))
    check(key!=Surface._source_key("fixture:colour","reference",images,next_pose),"Camera rotation belongs to the measured normal/reconstruction operands")
    var replaced:Dictionary=images.duplicate();replaced.colour=colour.duplicate()
    check(key!=Surface._source_key("fixture:colour","reference",replaced,pose),"A revised admitted image cannot reuse a stale source pose")
    check(producer.sources.values().all(func(points):return points.is_read_only() and points.all(func(point):return point.is_read_only())),"Worker results are published as immutable shared source arrays")
    var bounded:RefCounted=Surface.new()
    bounded._request(["wanted"],images,pose,true)
    bounded._request(["optional"],images,pose,false)
    bounded._request(["wanted"],images,pose,false)
    check(bounded.pending_order==[["wanted"],["optional"]],"Optional lookahead cannot promote itself or displace a required current pose")
    bounded.pending.clear();bounded.pending_order.clear()
    for i in Surface.PENDING_LIMIT+20:bounded._request([i],images,pose,false)
    check(bounded.pending.size()==Surface.PENDING_LIMIT and bounded.pending_order.size()==Surface.PENDING_LIMIT,"Unstarted lead work has a finite queue bound")
    bounded._request([999],images,pose,true)
    check(bounded.pending.size()==Surface.PENDING_LIMIT and bounded.pending_order[0]==[999],"Current poses displace optional lead work without growing the queue")
    for i in Surface.SOURCE_LIMIT+4:
        bounded._request([i+2000],images,pose,true);bounded._start()
        while not bounded.jobs.is_empty():await process_frame;bounded.poll()
    check(bounded.sources.size()<=Surface.SOURCE_LIMIT,"Completed physical pose cache has a finite owner bound")
    check(world.source_images.size()==5,"Preparation consumes admitted CPU images without allocating or uploading textures")
    var absent:Dictionary=producer.sample(world,"knight_a",["weapon"])
    check(not absent.ready and absent.points.is_empty(),"An absent authored weapon cannot fall back to the displayed body points")
    var body_only:Dictionary=producer.sample(world,"knight_b",["body"])
    var helmet_only:Dictionary=producer.sample(world,"knight_b",["helmet"])
    check(body_only.ready and helmet_only.ready and body_only.gpu_geometry_key!=helmet_only.gpu_geometry_key,"Recipient slot ownership participates in upload identity even when two layers share a physical source pose")
    await future_tracks(world,index,layer,descriptor)
    bounded.clear();producer.clear();world.free()
    print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
