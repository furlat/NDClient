extends RefCounted
## Current displayed optical surfaces. Source measurements are shared between
## actors; transforms and source-over ownership belong to each recipient.
## Uses admitted CPU images, never texture readback or a playback disk loader.
const Geometry=preload("res://presentation/character_geometry.gd")
const SourceMaterial=preload("res://presentation/source_material.gd")
const Characters=preload("res://presentation/characters.gd")
const Construction=preload("res://presentation/actor_construction.gd")
const Tracks=preload("res://presentation/tracks.gd")
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
var received_groups:Array=[]
var received_scope:Array=[]
var received_admission:Dictionary={}
var received_poses:Array=[]
var received_requested:Dictionary={}
var received_until_ms:float=INF
var received_scans:int=0

static func required_paths(path:String,slot:String,cache:Dictionary,profile:String="")->Dictionary:
    var source:Dictionary=Geometry.record(path,slot,cache)
    if source.is_empty():return {}
    profile=Geometry.effective_profile(source,profile)
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

## Native preparation already owns these received groups. Select only the next
## actual source transition per interested actor; this never samples a future
## Node/material or publishes a pose. Current measurements keep queue priority.
func prepare_received_tracks(world:Node,groups:Array,interests:Array)->void:
    poll()
    var admission:Dictionary=world.catalog_cache.get(Geometry.BodySources.KEY,{})
    if admission.is_empty():return
    var scope:Array=[world.character_light_profile,world.camera.global_basis,world.quarter,world.rig_config.TILE_W,interests,world.timeline.retained_directions.duplicate()]
    var same:bool=received_scope==scope and is_same(received_admission,admission) and received_groups.size()==groups.size() and world.timeline.display_ms<received_until_ms
    if same:
        for index in groups.size():
            if not is_same(received_groups[index],groups[index].get("actor_tracks")):same=false;break
    if not same:
        received_groups=groups.map(func(group):return group.get("actor_tracks"))
        received_scope=scope;received_admission=admission;received_poses=[];received_requested={};received_until_ms=INF;received_scans+=1
        var selected:Dictionary={}
        var directions:Dictionary=world.timeline.retained_directions.duplicate()
        var start:float=world.timeline.group_start_ms if not world.timeline.current.is_empty() else world.timeline.display_ms
        for group in groups:
            start=maxf(start,float(group.get("preview_start_ms",start)))
            var tracks:Array=group.get("actor_tracks",[])
            var cuts:Dictionary={}
            for track in tracks:
                for cut in [float(track.start_ms),float(track.start_ms)+float(track.duration_ms)]:
                    if not cuts.has(cut):cuts[cut]={}
                    cuts[cut][track.actor_uuid]=true
            var times:Array=cuts.keys();times.sort()
            for local in times:
                var at:float=start+float(local)
                if at<=world.timeline.display_ms+0.000001:continue
                var requests:Array=interests.filter(func(request):return cuts[local].has(request.actor) and not selected.has([request.actor,request.slots]))
                if requests.is_empty():continue
                var samples:Dictionary=Tracks.samples(tracks,float(local))
                for request in requests:
                    if not samples.has(request.actor):continue
                    var track:Dictionary=samples[request.actor]
                    selected[[request.actor,request.slots]]=true
                    received_until_ms=minf(received_until_ms,at)
                    _received_track(world,admission,track,group,directions,float(local),request)
            world.timeline._directions(tracks,INF,directions)
            start+=float(group.get("duration_ms",0.0))
    for source in received_poses:
        var packet:Dictionary=admitted_images(world,source.path,source.slot)
        if not packet.reason.is_empty():continue
        var size:Vector2=Vector2(packet.images.colour.get_width(),packet.images.colour.get_height())
        var p:Dictionary=source.parameters
        for frame in source.frames:
            var uv:Vector4=Construction.source_uv(source.rig,source.layout,frame,source.facing,size)
            var pose:Array=[uv,p.component_units,p.component_elevation,p.component_reconstruction_origin,p.component_depth_range,source.pivot,source.ground,world.camera.global_basis]
            var key:Array=_source_key(source.path,world.character_light_profile,packet.images,pose)
            if received_requested.has(key):continue
            _request(key,packet.images,pose,false)
            # Retry a rejected optional request when capacity becomes free;
            # never requeue an evicted result forever under the same owner.
            if sources.has(key) or jobs.has(key) or pending.has(key):received_requested[key]=true
    _start()

func _received_track(world:Node,admission:Dictionary,track:Dictionary,group:Dictionary,directions:Dictionary,local:float,request:Dictionary)->void:
    var actor:Dictionary=track.get("presentation_actor",{}).duplicate(false)
    if actor.is_empty():return
    actor.presentation_layers=track.get("effect_layers",[])
    if track.has("visual_loadout"):actor.visual_loadout=track.visual_loadout
    var structure:Dictionary=Characters.structure(actor,world.catalog_cache,track.get("presentation_item_looks",{}))
    if not structure.ok:return
    var rig:Dictionary=admission.index.rigs.get(track.rig,{})
    if not rig.clips.has(track.clip):return
    var local_directions:Dictionary=directions.duplicate()
    world.timeline._directions(group.get("actor_tracks",[]),local,local_directions)
    var facing:String="SW"
    var path:Array=local_directions.get(track.actor_uuid,[])
    var cycle:Array=world.rig_config.FACING_CYCLE
    if path.size()==2:facing=Placement.facing(Vector2(path[1][0]-path[0][0],path[1][1]-path[0][1]),cycle)
    facing=cycle[posmod(cycle.find(facing)+world.quarter*2,8)]
    for layer in structure.value.equipment_layers:
        if layer.slot not in request.slots or layer.slot in track.get("hidden_slots",[]) or not layer.get("effect",{}).is_empty():continue
        var source:Resource=Geometry.BodySources.prepared_layer(layer.source_path,world.catalog_cache)
        if source==null:continue
        var banks:Dictionary=source.bank_paths_by_slot.get(layer.slot,{})
        var path_name:String=banks[track.clip].get(facing,"") if banks.has(track.clip) else source.paths_by_slot.get(layer.slot,{}).get(track.clip,"")
        if path_name.is_empty():continue
        var scale:float=128.0/float(world.rig_config.TILE_W)*float(actor.appearance.visual_scale)
        var binding:Dictionary=Geometry.prepare_binding(path_name,layer.slot,world.catalog_cache,true,true,world.character_light_profile,scale,float(actor.appearance.visual_scale_x))
        if not binding.parameters.get("has_component_geometry",false):continue
        # Library-only companions explicitly retain unknown ground registration.
        # Normals may render without supplying a world-space optical surface.
        if binding.ground==null:continue
        var layout:Dictionary=Geometry.BodySources.descriptor(path_name,layer.slot,world.catalog_cache).get("source_layout",{})
        received_poses.append({"actor":request.actor,"clip":track.clip,"path":path_name,"slot":layer.slot,"rig":rig,"facing":facing,
            "frames":initial_frames(track,rig,local),"layout":layout,"parameters":Geometry.parameters_for_facing(binding,facing),"pivot":Construction.layer_shape(rig,scale,layout).pivot,"ground":binding.ground})

## The exact authored starting frame and at most the next two crossed frames.
## Reverse/keyed/looping tracks use their own source range, never extra clips.
static func initial_frames(track:Dictionary,rig:Dictionary,local:float=-1.0)->Array:
    var clip:Dictionary=rig.clips[track.clip]
    var fraction:float=clampf((local-float(track.start_ms))/maxf(.000001,float(track.duration_ms)),0.0,1.0) if local>=0.0 else 0.0
    var sampled_track:Dictionary=Tracks.samples([track],local).get(track.actor_uuid,track) if local>=0.0 else track
    var values:Array=[float(sampled_track.get("source_seconds",track.get("source_start_seconds",0.0)))]
    for key in track.get("source_time_keys",[]):
        if float(key[0])>fraction:values.append(float(key[1]))
    values.append(float(track.get("source_end_seconds",values[0])))
    var length:float=maxf(float(clip.frames)/float(clip.fps),.001)
    var loop:bool=Tracks.character_loops(rig,track.clip)
    var sampled:float=Tracks.sample_seconds(values[0],length,loop)
    var result:Array=[mini(int(sampled*clip.fps),int(clip.frames)-1)]
    for index in range(1,values.size()):
        var first:int=floori(float(values[index-1])*float(clip.fps))
        var last:int=floori(float(values[index])*float(clip.fps))
        var direction:int=1 if last>=first else -1
        var frame:int=first
        while frame!=last:
            frame+=direction
            var selected:int=posmod(frame,int(clip.frames)) if loop else clampi(frame,0,int(clip.frames)-1)
            if selected not in result:result.append(selected)
            if result.size()>FRAME_LEAD:return result
    return result

static func admitted_images(world:Node,path:String,slot:String)->Dictionary:
    var source:Dictionary=Geometry.record(path,slot,world.catalog_cache)
    if source.is_empty():return {"reason":"source_geometry_not_registered"}
    var normals:Dictionary=Geometry.normal_paths(path,slot,world.catalog_cache).value
    var profile:String=Geometry.effective_profile(source,world.character_light_profile)
    if not normals.has(profile):return {"reason":"normal_profile_not_registered"}
    var root:String=Geometry._root(source)
    var paths:Dictionary={"colour":path,"depth":root.path_join(source.files.depth),"support":root.path_join(source.files.support),"normal_valid":root.path_join(source.files.normal_valid),"normal":normals[profile]}
    var images:Dictionary={}
    var missing:Dictionary={}
    for name in paths:
        if not world.source_images.has(paths[name]):missing[name]=paths[name]
        else:images[name]=world.source_images[paths[name]]
    if not missing.is_empty():return {"reason":"source_"+str(missing.keys()[0])+"_not_prepared","missing_paths":missing,"paths":paths}
    return {"reason":"","images":images}

func _capture(world:Node,actor:String,slots:Array,priority:bool=true)->Dictionary:
    poll()
    var result:Dictionary={"selected":[],"revision":[],"pose_key":[],"origin":Vector3.ZERO,"pending":false,"reason":"actor_not_displayed"}
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
        var packet:Dictionary=admitted_images(world,entry.texture_path,slot)
        if not packet.reason.is_empty():result.reason=packet.reason;return result
        if not entry.has("geometry_ground_pixels"):
            result.reason="source_optical_ground_not_registered";return result
        var images:Dictionary=packet.images
        var pose:Array=[frame,SourceMaterial.value(entry,"component_units"),SourceMaterial.value(entry,"component_elevation"),SourceMaterial.value(entry,"component_reconstruction_origin"),SourceMaterial.value(entry,"component_depth_range"),entry.pivot,float(entry.geometry_ground_pixels),world.camera.global_basis]
        var key:Array=_source_key(entry.texture_path,world.character_light_profile,images,pose)
        _request(key,images,pose,priority)
        result.selected.append({"entry":entry,"key":key,"slot":slot})
        result.pose_key.append(key)
        result.revision.append([key,slot,entry.node.global_basis,entry.node.global_position-result.origin])
        # The current sheet row owns its facing. Adjacent source frames are
        # preparation candidates only; they do not advance any actor clock.
        var layout:Dictionary=entry.get("source_layout",{})
        if not layout.is_empty():
            var count:int=layout.frame_rects.size()
            var bound:Array=entry.bound_frame_key
            for step in mini(FRAME_LEAD,count-1):
                var next:int=int(bound[1])+step+1
                if not entry.get("source_frame_loop",false) and next>=count:break
                next=posmod(next,count)
                var next_pose:Array=pose.duplicate()
                next_pose[0]=Construction.source_uv(world.rigs[row.rig],layout,next,str(bound[2]),Vector2(images.colour.get_width(),images.colour.get_height()))
                lead.append({"key":_source_key(entry.texture_path,world.character_light_profile,images,next_pose),"images":images,"pose":next_pose})
        else:
            var columns:int=maxi(1,roundi(1.0/frame.z))
            var column:int=roundi(frame.x/frame.z)
            for step in mini(FRAME_LEAD,columns-1):
                var next_pose:Array=pose.duplicate();var next_frame:Vector4=frame
                next_frame.x=((column+step+1)%columns)*frame.z;next_pose[0]=next_frame
                lead.append({"key":_source_key(entry.texture_path,world.character_light_profile,images,next_pose),"images":images,"pose":next_pose})
    for candidate in lead:_request(candidate.key,candidate.images,candidate.pose,false)
    _start()
    var prepared:bool=result.selected.all(func(row):return sources.has(row.key))
    # Only an exact source pose already owned by this measurement queue is
    # pending. Missing actor/source/registration remains a real unavailable.
    result.pending=not prepared and result.selected.all(func(row):return sources.has(row.key) or jobs.has(row.key) or pending.has(row.key))
    result.reason="" if prepared else "surface_source_preparing"
    return result

func sample(world:Node,actor:String,slots:Array=BODY_SLOTS,region:Dictionary={})->Dictionary:
    var captured:Dictionary=_capture(world,actor,slots)
    var result:Dictionary={"actor":actor,"actor_uuid":actor,"entity_uuid":actor,"points":[],"origin":Vector3.ZERO,"pose_key":[],"gpu_geometry_key":[],"ready":false,"pending":false,"reason":"actor_not_displayed"}
    result.reason=captured.reason;result.pending=captured.pending;result.origin=captured.origin;result.pose_key=captured.pose_key
    if not captured.reason.is_empty():return result
    var selected:Array=captured.selected;var revision:Array=captured.revision;var origin:Vector3=captured.origin
    var owner_key:Array=[actor,slots,region.get("socket",""),region.get("radius",0.0)]
    var world_key:Array=[revision,origin]
    if not region.is_empty():world_key.append(region.point)
    if packets.has(owner_key) and packets[owner_key].revision==world_key:return packets[owner_key].packet.duplicate(false)
    var owned:Dictionary={};var centre:=Vector3.ZERO
    for description in selected:
        var transform:Transform3D=description.entry.node.global_transform
        var normal_basis:Basis=transform.basis.inverse().transposed()
        for point in sources[description.key]:
            if owned.has(point.pixel):continue
            owned[point.pixel]=true
            var position:Vector3=transform*point.local
            if not region.is_empty() and position.distance_squared_to(region.point)>float(region.radius)*float(region.radius):continue
            result.points.append({"position":position,"normal":(normal_basis*point.normal).normalized(),"uv":point.uv,"pixel":point.pixel,"slot":description.slot})
            centre+=position
    result.gpu_geometry_key=revision if region.is_empty() else [revision,region]
    result.ready=not result.points.is_empty();result.reason="" if result.ready else "no_admitted_optical_points"
    if result.ready:result.optical_anchor=centre/float(result.points.size())
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
    received_groups.clear();received_scope.clear();received_admission={};received_poses.clear();received_requested.clear();received_until_ms=INF
