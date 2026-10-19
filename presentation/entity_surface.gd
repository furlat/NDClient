extends RefCounted
## Current displayed optical surfaces. Source measurements are shared between
## actors; transforms and source-over ownership belong to each recipient.
## Uses admitted CPU images, never texture readback or a playback disk loader.
const Geometry=preload("res://presentation/character_geometry.gd")
const SourceMaterial=preload("res://presentation/source_material.gd")
const Placement=preload("res://placement.gd")
const SOURCE_LIMIT=128
const ACTOR_LIMIT=32
const WORKER_LIMIT=2
const PENDING_LIMIT=128
const FRAME_LEAD=2
const BODY_SLOTS=["body","chest","head","helmet","hair","beard","neck","arms","hands","legs","shoes","feet","belt","cloak","backpack"]
var sources:Dictionary={}
var source_order:Array=[]
var packets:Dictionary={}
var packet_order:Array=[]
var source_builds:int=0
var packet_builds:int=0
var source_usec:int=0
var jobs:Dictionary={}
var pending:Dictionary={}
var pending_order:Array=[]
var discarded:int=0

static func required_paths(path:String,slot:String,cache:Dictionary,profile:String="")->Dictionary:
    var source:Dictionary=Geometry.record(path,slot,cache)
    if source.is_empty():return {}
    var root:String=Geometry._root(source)
    var result:Dictionary={path:true}
    for name in ["depth","support","normal_valid"]:result[root.path_join(source.files[name])]=true
    var normals:Dictionary=Geometry.normal_paths(path,slot,cache).value
    if normals.has(profile):result[normals[profile]]=true
    return result

## Only immutable admitted images and optical operands reach the worker. No
## scene node, shader/material, texture getter, disk loader or upload is used.
static func _measure_job(images:Dictionary,pose:Array,result:Dictionary)->void:
    var started:int=Time.get_ticks_usec()
    var points:Array=measure(images,pose[0],pose[1],pose[2],pose[3],pose[4],pose[5],pose[6],pose[7])
    for point in points:point.make_read_only()
    points.make_read_only()
    result.points=points;result.usec=Time.get_ticks_usec()-started

func poll()->void:
    for key in jobs.keys():
        var job:Dictionary=jobs[key]
        if not WorkerThreadPool.is_task_completed(job.task):continue
        WorkerThreadPool.wait_for_task_completion(job.task)
        sources[key]=job.result.points;source_order.append(key)
        source_builds+=1;source_usec+=int(job.result.usec)
        if source_order.size()>SOURCE_LIMIT:sources.erase(source_order.pop_front())
        jobs.erase(key)

func _request(key:Array,images:Dictionary,pose:Array,priority:bool)->void:
    if sources.has(key) or jobs.has(key):return
    if pending.has(key):
        if priority:pending_order.erase(key);pending_order.push_front(key)
        return
    if pending_order.size()>=PENDING_LIMIT:
        if not priority:return
        pending.erase(pending_order.pop_back());discarded+=1
    pending[key]={"images":images,"pose":pose}
    if priority:pending_order.push_front(key)
    else:pending_order.append(key)

func _start()->void:
    while jobs.size()<WORKER_LIMIT and not pending_order.is_empty():
        var key:Array=pending_order.pop_front();var request:Dictionary=pending[key];pending.erase(key)
        var result:Dictionary={}
        jobs[key]={"result":result,"task":WorkerThreadPool.add_task(_measure_job.bind(request.images,request.pose,result),false,"Disclosed optical source pose")}

static func _source_key(path:String,profile:String,images:Dictionary,pose:Array)->Array:
    return [path,profile,images.colour.get_instance_id(),images.depth.get_instance_id(),images.support.get_instance_id(),images.normal_valid.get_instance_id(),images.normal.get_instance_id(),pose]

## The selected/received capability can call this in its existing preparation
## lane before its first effect. Sampling has the same nonblocking request path.
func prepare(world:Node,actors:Array,slots:Array=BODY_SLOTS,priority:bool=true)->void:
    for actor in actors:_capture(world,str(actor),slots,priority)

func _capture(world:Node,actor:String,slots:Array,priority:bool=true)->Dictionary:
    poll()
    var result:Dictionary={"selected":[],"revision":[],"pose_key":[],"origin":Vector3.ZERO,"reason":"actor_not_displayed"}
    var visual:Dictionary=world.visual_actors.get(actor,{})
    if visual.is_empty() or not visual.get("valid",false):return result
    var row:Dictionary=visual.get("row",{})
    if row.is_empty():return result
    result.origin=Placement.contact(row)+Vector3.UP*float(row.get("visual_height",0.0))*Placement.HEIGHT_UNIT
    var lead:Array=[]
    for index in range(visual.entries.size()-1,-1,-1):
        var entry:Dictionary=visual.entries[index]
        var slot:String=entry.actor_layer.slot
        if slot not in slots or entry.role=="shadow" or not entry.node.is_visible_in_tree():continue
        if not entry.actor_layer.get("effect",{}).is_empty():continue
        var frame:Vector4=SourceMaterial.value(entry,"frame_uv")
        var source:Dictionary=Geometry.record(entry.texture_path,slot,world.catalog_cache)
        if source.is_empty():result.reason="source_geometry_not_registered";return result
        var normals:Dictionary=Geometry.normal_paths(entry.texture_path,slot,world.catalog_cache).value
        if not normals.has(world.character_light_profile):result.reason="normal_profile_not_registered";return result
        var root:String=Geometry._root(source)
        var paths:Dictionary={"colour":entry.texture_path,"depth":root.path_join(source.files.depth),"support":root.path_join(source.files.support),"normal_valid":root.path_join(source.files.normal_valid),"normal":normals[world.character_light_profile]}
        var images:Dictionary={}
        for name in paths:
            if not world.source_images.has(paths[name]):result.reason="source_"+name+"_not_prepared";return result
            images[name]=world.source_images[paths[name]]
        var pose:Array=[frame,SourceMaterial.value(entry,"component_units"),SourceMaterial.value(entry,"component_elevation"),SourceMaterial.value(entry,"component_reconstruction_origin"),SourceMaterial.value(entry,"component_depth_range"),entry.pivot,float(entry.get("geometry_ground_pixels",19.0)),world.camera.global_basis]
        var key:Array=_source_key(entry.texture_path,world.character_light_profile,images,pose)
        _request(key,images,pose,priority)
        result.selected.append({"entry":entry,"key":key,"slot":slot})
        result.pose_key.append(key)
        result.revision.append([key,slot,entry.node.global_basis,entry.node.global_position-result.origin])
        # The current sheet row owns its facing. Adjacent source frames are
        # preparation candidates only; they do not advance any actor clock.
        var columns:int=maxi(1,roundi(1.0/frame.z))
        var column:int=roundi(frame.x/frame.z)
        for step in mini(FRAME_LEAD,columns-1):
            var next_pose:Array=pose.duplicate();var next_frame:Vector4=frame
            next_frame.x=((column+step+1)%columns)*frame.z;next_pose[0]=next_frame
            lead.append({"key":_source_key(entry.texture_path,world.character_light_profile,images,next_pose),"images":images,"pose":next_pose})
    for candidate in lead:_request(candidate.key,candidate.images,candidate.pose,false)
    _start()
    result.reason="" if result.selected.all(func(row):return sources.has(row.key)) else "surface_source_preparing"
    return result

func sample(world:Node,actor:String,slots:Array=BODY_SLOTS)->Dictionary:
    var captured:Dictionary=_capture(world,actor,slots)
    var result:Dictionary={"actor":actor,"actor_uuid":actor,"entity_uuid":actor,"points":[],"origin":Vector3.ZERO,"pose_key":[],"gpu_geometry_key":[],"ready":false,"reason":"actor_not_displayed"}
    result.reason=captured.reason;result.origin=captured.origin;result.pose_key=captured.pose_key
    if not captured.reason.is_empty():return result
    var selected:Array=captured.selected;var revision:Array=captured.revision;var origin:Vector3=captured.origin
    var owner_key:Array=[actor,slots]
    var world_key:Array=[revision,origin]
    if packets.has(owner_key) and packets[owner_key].revision==world_key:return packets[owner_key].packet.duplicate(false)
    var owned:Dictionary={}
    for description in selected:
        var transform:Transform3D=description.entry.node.global_transform
        var normal_basis:Basis=transform.basis.inverse().transposed()
        for point in sources[description.key]:
            if owned.has(point.pixel):continue
            owned[point.pixel]=true
            result.points.append({"position":transform*point.local,"normal":(normal_basis*point.normal).normalized(),"uv":point.uv,"pixel":point.pixel,"slot":description.slot})
    result.gpu_geometry_key=revision
    result.ready=not result.points.is_empty();result.reason="" if result.ready else "no_admitted_optical_points"
    packet_builds+=1
    if not packets.has(owner_key):packet_order.append(owner_key)
    packets[owner_key]={"revision":world_key,"packet":result}
    if packet_order.size()>ACTOR_LIMIT:packets.erase(packet_order.pop_front())
    return result.duplicate(false)

static func measure(images:Dictionary,frame:Vector4,units:float,elevation:float,origin:Vector2,depth_range:Vector2,pivot:Vector2,ground:float,camera_basis:Basis)->Array:
    var result:Array=[]
    var colour:Image=images.colour
    var offset:Vector2i=Vector2i(roundi(frame.x*colour.get_width()),roundi(frame.y*colour.get_height()))
    var size:Vector2i=Vector2i(roundi(frame.z*colour.get_width()),roundi(frame.w*colour.get_height()))
    var toward:Vector3=camera_basis.z
    var horizontal:Vector3=Vector3(toward.x,0,toward.z).normalized()
    var normal_basis:Basis=camera_basis.inverse()*Basis(camera_basis.x,Vector3(0,cos(elevation),0)-horizontal*sin(elevation),horizontal*cos(elevation)+Vector3(0,sin(elevation),0))
    for y in size.y:
        for x in size.x:
            var pixel:Vector2i=Vector2i(x,y);var sheet_pixel:Vector2i=pixel+offset
            if colour.get_pixelv(sheet_pixel).a<.99:continue
            var depth:Color=images.depth.get_pixelv(sheet_pixel)
            var normal:Color=images.normal.get_pixelv(sheet_pixel)
            if depth.a<.5 or normal.a<.5 or images.support.get_pixelv(sheet_pixel).r<.5 or images.normal_valid.get_pixelv(sheet_pixel).r<.5:continue
            var centre:Vector2=Vector2(x+.5,y+.5)
            var decoded:float=depth_range.x+(depth.r*255.0-32.0)*(depth_range.y-depth_range.x)/192.0
            var height:float=((origin.y-centre.y)*cos(elevation)+decoded*sin(elevation)-ground)*units
            var painted:Vector3=Vector3(centre.x-pivot.x,pivot.y-centre.y,0)*units
            var ray:float=(height-(camera_basis*painted).y)/toward.y
            var direction:Vector3=Vector3(normal.r,normal.g,normal.b)*2.0-Vector3.ONE
            result.append({"local":painted+Vector3(0,0,ray),"normal":(normal_basis*direction.normalized()).normalized(),"uv":centre/Vector2(size),"pixel":pixel})
    return result

func clear()->void:
    # Explicit world teardown may join its two finite source jobs. A playing
    # frame only polls completed jobs, never waits for outstanding work.
    for job in jobs.values():WorkerThreadPool.wait_for_task_completion(job.task)
    jobs.clear();pending.clear();pending_order.clear()
    sources.clear();source_order.clear();packets.clear();packet_order.clear()
