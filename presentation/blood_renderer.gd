extends RefCounted
## Finite authored blood geometry. The display clock is the only age owner.
## Persistent fields belong to exact current tile residues; completed fields
## are retained and never rerasterized just because the camera or light moves.
const Blood=preload("res://presentation/blood.gd")
const Placement=preload("res://placement.gd")
const GridOrder=preload("res://grid_order.gd")
const Kernel=preload("res://presentation/blood_kernel.gdshader")
const Surface=preload("res://presentation/blood_surface.gdshader")
const Droplet=preload("res://presentation/blood_droplet.gdshader")
const Admission=preload("res://presentation/native_source_admission.gd")
static var _programs_prepared:int=0
static var _program_frame:int=-1
var resources_ready:bool=false
var resource_frame:int=-1
var deposits:Dictionary={}
var pending_deposits:Dictionary={}
# Passive exact after-value work only. Scene resources remain scene-owned.
var kernel_preparations:Array=[]
var kernel_jobs:Array=[]
const KERNEL_WORKERS=2
var _prepare_budget:Dictionary={"frame":-1,"used_usec":0,"limit_usec":2000}
var prepare_frame=-1
var prepare_allocations=0
var prepare_usec=0
var flights:Dictionary={}
# Blood lights itself from the light table (blood_receiving.gdshaderinc) over
# the former receiving page's ambient: CanvasModulate 0.18 after HDR conversion.
var ambient:float=Color(.18,.18,.18).linear_to_srgb().srgb_to_linear().r
var room_lights:bool=true
var source:Dictionary={}
var tiles_owner:Dictionary={}
var tiles_revision=-1
var tiles:Dictionary={}
var field_uploads=0
var last_sample_usec=0
var last_allocations=0
var peak_sample_usec=0
var visible_fields:Dictionary={}
# Screen visibility per deposit tile for one camera/viewport: key -> [tile, on_screen].
var _tile_view:Array=[]
var _tile_on_screen:Dictionary={}
var ready=true
var deposit_create_usec:int=0
var sample_phases:Dictionary={}

func _phase(name:String,started:int)->void:
    sample_phases[name]=sample_phases.get(name,0.0)+(Time.get_ticks_usec()-started)/1000.0

func prepare_resources(world:Node,budget:Dictionary={})->bool:
    if resources_ready:return true
    var frame:int=Engine.get_process_frames()
    if _programs_prepared<3:
        if _program_frame==frame or (not budget.is_empty() and budget.used_usec>=budget.limit_usec) or not Admission.begin_mutation():return false
        var started:int=Time.get_ticks_usec()
        _program_frame=frame
        [Kernel,Surface,Droplet][_programs_prepared].get_rid()
        _programs_prepared+=1
        if not budget.is_empty():budget.used_usec+=Time.get_ticks_usec()-started
        return false
    resources_ready=true
    return true

func _receiving(material:ShaderMaterial)->void:
    material.set_shader_parameter("blood_ambient",ambient)
    material.set_shader_parameter("blood_room_lights",room_lights)

func _entry(world:Node,id:String,mesh:Mesh,role:String,position:Array,height:float,layer:int,shader:Shader,parent:Node=null,registered:bool=true)->Dictionary:
    var node=MeshInstance3D.new();node.mesh=mesh;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var material=ShaderMaterial.new();material.shader=shader;node.material_override=material
    (world if parent==null else parent).add_child(node)
    var row={"id":id,"position":position,"base_height_steps":height,"kind":"effect","layer":1}
    var entry={"id":id,"node":node,"material":material,"placement":row,"role":role,"layer":layer}
    if registered:world.actor_entries.append(entry);world.draw_order_dirty=true
    return entry

func _deposit(world:Node,key:String,tile:Dictionary,parent:Node=null,registered:bool=true)->Dictionary:
    var phase:int=Time.get_ticks_usec()
    last_allocations+=1
    var field=SubViewport.new();field.size=Vector2i(64,64);field.disable_3d=true;field.transparent_bg=true;field.use_hdr_2d=true
    field.render_target_update_mode=SubViewport.UPDATE_ONCE;(world if parent==null else parent).add_child(field)
    var mesh=QuadMesh.new();mesh.size=Vector2(2,2)
    var multimesh=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_2D;multimesh.use_custom_data=true;multimesh.mesh=mesh
    var kernels=MultiMeshInstance2D.new();kernels.multimesh=multimesh
    kernels.material=ShaderMaterial.new();kernels.material.shader=Kernel;field.add_child(kernels)
    var plane=PlaneMesh.new();plane.size=Vector2.ONE
    var entry=_entry(world,"blood:tile:"+key,plane,"covering",tile.position,tile.get("elevation_steps",0),1,Surface,parent,registered)
    entry.node.position=Placement.contact(entry.placement)
    entry.material.set_shader_parameter("field_texture",field.get_texture())
    entry.material.set_shader_parameter("tile_position",Vector2(tile.position[0],tile.position[1]))
    deposit_create_usec+=Time.get_ticks_usec()-phase
    _receiving(entry.material)
    entry.node.visible=false
    var handle={"entry":entry,"field":field,"kernels":kernels,"value":{},"phase":[],"updates":0,"ready":false,"kernel_cache":{},"registered":registered,"world_users":0}
    RenderingServer.frame_post_draw.connect(func():handle.ready=true,CONNECT_ONE_SHOT)
    return handle

func world_values()->Dictionary:
    # Canonical residue values are immutable; the world worker borrows values,
    # never mutable native handles or kernel caches owned by this renderer.
    var values:Dictionary={}
    for key in deposits:values[key]={"value":deposits[key].value,"source":deposits[key].kernel_cache.get("source")}
    return values

func prepare_world(world:Node,owner:Node,rows:Dictionary,preparation:Dictionary,budget:Dictionary)->bool:
    if rows.is_empty():return true
    if rows.values().any(func(row):return not row.get("removed",false)) and not prepare_resources(world,budget):return false
    var complete:bool=true
    for key in rows:
        var row:Dictionary=rows[key]
        if row.get("removed",false):preparation.handles[key]={"removed":true};continue
        if deposits.has(key) and is_same(deposits[key].value,row.value) and is_same(deposits[key].kernel_cache.get("source"),row.source):continue
        if not preparation.handles.has(key):
            if budget.used_usec>=budget.limit_usec or not Admission.begin_mutation():return false
            var began:int=Time.get_ticks_usec()
            # A pending event field can be borrowed only before this tile has a
            # displayed residue. Changing an existing published field early
            # would expose a future after-value before the ordered world cue.
            var borrowed:bool=pending_deposits.has(key) and not tiles.has(key)
            var handle:Dictionary=pending_deposits[key] if borrowed else _deposit(world,key,row.tile,owner,false)
            if borrowed:handle.world_users=handle.get("world_users",0)+1
            handle.value=row.value;handle.phase=[];handle.coverage=row.coverage
            handle.kernel_cache=row.cache
            _upload(handle,row.kernels)
            handle.ready=false
            RenderingServer.frame_post_draw.connect(func():handle.ready=true,CONNECT_ONE_SHOT)
            preparation.handles[key]={"handle":handle,"borrowed":borrowed}
            budget.used_usec+=Time.get_ticks_usec()-began
        complete=complete and preparation.handles[key].handle.ready
    return complete

func publish_world(world:Node,preparation:Dictionary)->void:
    for key in preparation.handles:
        var record:Dictionary=preparation.handles[key]
        var handle:Dictionary=record.get("handle",{})
        if record.get("borrowed",false):handle.world_users-=1
        if not handle.is_empty() and pending_deposits.has(key) and is_same(pending_deposits[key],handle):pending_deposits.erase(key)
        if deposits.has(key) and not is_same(deposits[key],handle):
            var old:Dictionary=deposits[key]
            old.entry.node.visible=false;old.field.render_target_update_mode=SubViewport.UPDATE_DISABLED
            world.actor_entries.erase(old.entry);preparation.retired.append(old)
        if record.get("removed",false):deposits.erase(key);world.draw_order_dirty=true;continue
        if handle.entry.node.get_parent()!=world:handle.entry.node.reparent(world)
        if handle.field.get_parent()!=world:handle.field.reparent(world)
        if not handle.registered:world.actor_entries.append(handle.entry);handle.registered=true
        source=handle.kernel_cache.source
        deposits[key]=handle;world.draw_order_dirty=true
    preparation.handles={}

func release_world(preparation:Dictionary)->Array:
    var held:Array=[]
    for record in preparation.handles.values():
        if record.get("removed",false):continue
        if record.borrowed:record.handle.world_users-=1
        else:preparation.retired.append(record.handle)
    for handle in preparation.retired:
        handle.entry.retire_external=true
        held.append(handle.entry)
        held.append({"node":handle.field,"retire_external":true})
    preparation.handles={};preparation.retired=[]
    return held

func _upload(handle:Dictionary,kernels:Array)->void:
    var multimesh:MultiMesh=handle.kernels.multimesh
    multimesh.instance_count=kernels.size()
    for i in kernels.size():
        var transform:Transform2D=kernels[i].transform
        transform.x*=sqrt(1.5)*64.;transform.y*=sqrt(1.5)*64.;transform.origin=(transform.origin+Vector2(.5,.5))*64.
        multimesh.set_instance_transform_2d(i,transform)
        multimesh.set_instance_custom_data(i,Color(kernels[i].mass,0,0,0))
    handle.field.render_target_update_mode=SubViewport.UPDATE_ONCE
    handle.updates+=1;field_uploads+=1

static func _warm_kernels(input:Dictionary,output:Dictionary)->void:
    var cache:Dictionary={}
    Blood.kernels(input.value,input.position,[],input.source,cache)
    var active:Dictionary=input.reveal.duplicate()
    active.pattern=input.pattern;active.age_seconds=-INF
    Blood.kernels(input.value,input.position,[active],input.source,cache)
    Blood.prepare_landing(cache,input.reveal,input.pattern)
    output.cache=cache

static func _warm_kernel_batch(inputs:Array,control:Dictionary)->void:
    for input in inputs:
        control.mutex.lock()
        var cancelled:bool=control.cancelled
        control.mutex.unlock()
        if cancelled:return
        _warm_kernels(input.value,input.output)

func _poll_kernel_preparations()->void:
    for job in kernel_jobs.duplicate():
        if not WorkerThreadPool.is_task_completed(job.task):continue
        WorkerThreadPool.wait_for_task_completion(job.task)
        for prepared in job.rows:prepared.task=-1 if prepared.output.has("cache") else -2
        kernel_jobs.erase(job)

func _start_kernel_jobs(budget:Dictionary)->void:
    if budget.used_usec>=budget.limit_usec:return
    var available:int=KERNEL_WORKERS-kernel_jobs.size()
    if available<=0:return
    var pending:Array=kernel_preparations.filter(func(prepared):return prepared.task==-2 and not prepared.groups.is_empty())
    if pending.is_empty():return
    # Partition the received closure, not individual frame-sized tile prefixes.
    # Each worker owns private outputs; only completion permits cache adoption.
    var size:int=ceili(float(pending.size())/available)
    for offset in range(0,pending.size(),size):
        var rows:Array=pending.slice(offset,mini(offset+size,pending.size()))
        var inputs:Array=[]
        for prepared in rows:inputs.append({"value":prepared.input,"output":prepared.output})
        var control={"mutex":Mutex.new(),"cancelled":false}
        var task:int=WorkerThreadPool.add_task(_warm_kernel_batch.bind(inputs,control),false,"Prepare exact received blood shapes")
        for prepared in rows:prepared.task=task
        kernel_jobs.append({"task":task,"rows":rows,"control":control})

func _prepare_kernels(key:String,reveal:Dictionary,pattern:String,group_id:String,budget:Dictionary)->bool:
    for prepared in kernel_preparations:
        if prepared.key==key and is_same(prepared.source,source) and prepared.value==reveal.after:
            prepared.groups[group_id]=true
            return prepared.task==-1 and prepared.output.has("cache")
    var input={"value":reveal.after,"position":reveal.position.duplicate(),"source":source,"reveal":reveal,"pattern":pattern}
    var output:Dictionary={}
    kernel_preparations.append({"key":key,"value":reveal.after,"source":source,"groups":{group_id:true},"input":input,"output":output,"task":-2})
    return false

func _adopt_kernel_cache(handle:Dictionary,key:String,value:Dictionary,prefer_landing:bool=false)->void:
    if is_same(handle.kernel_cache.get("value"),value) and (not prefer_landing or handle.kernel_cache.has("landing")):return
    for prepared in kernel_preparations:
        if prepared.key==key and prepared.task==-1 and not prepared.groups.is_empty() and is_same(prepared.source,source) and prepared.value==value and prepared.output.get("cache",{}).get("value")==value:
            handle.kernel_cache=prepared.output.cache
            # After-values may be copied during admission. Verify equality once
            # at field adoption, then keep the existing identity-only hot path.
            handle.kernel_cache.value=value
            return

func prepare(world:Node,groups:Array,budget:Dictionary={})->bool:
    if budget.is_empty():
        budget=_prepare_budget
        if budget.frame!=Engine.get_process_frames():budget.frame=Engine.get_process_frames();budget.used_usec=0
    var began=Time.get_ticks_usec()
    _poll_kernel_preparations()
    var charged_before:int=budget.get("used_usec",0)
    var frame=Engine.get_process_frames()
    if prepare_frame!=frame:prepare_frame=frame;prepare_allocations=0;prepare_usec=0
    if not prepare_resources(world,budget):
        prepare_usec+=Time.get_ticks_usec()-began
        if not budget.is_empty():budget.used_usec+=maxi(0,Time.get_ticks_usec()-began-(budget.used_usec-charged_before))
        return false
    if source.is_empty():source=Blood.Catalog.prepared_asset("particles.region.blood",world.catalog_cache)
    if source.is_empty():
        # A real release carries its worker-admitted source. No source loading
        # may be hidden in the scene preparation or sampling path.
        for group in groups:
            for component in group.get("components",[]):
                if component.kind=="residue_deposit":source=component.get("asset_metadata",{});break
            if not source.is_empty():break
    if source.is_empty():
        for group in groups:
            if group.get("components",[]).any(func(component):return component.kind=="residue_deposit"):return false
        return true
    for group in groups:
        for component in group.get("components",[]):
            if component.kind!="residue_deposit":continue
            for reveal in component.reveals:_prepare_kernels(Blood.key(reveal.position),reveal,component.body_release.pattern,group.id,budget)
    _start_kernel_jobs(budget)
    var complete=true
    for group in groups:
        for component in group.get("components",[]):
            if component.kind!="residue_deposit":continue
            for reveal in component.reveals:
                var key=Blood.key(reveal.position)
                var shapes_ready:bool=_prepare_kernels(key,reveal,component.body_release.pattern,group.id,budget)
                complete=complete and shapes_ready
                if deposits.has(key):continue
                if not pending_deposits.has(key):
                    if budget.used_usec>=budget.limit_usec:complete=false;continue
                    var allocation_started:int=Time.get_ticks_usec()
                    var tile={"position":reveal.position,"elevation_steps":reveal.elevation_steps}
                    pending_deposits[key]=_deposit(world,key,tile)
                    pending_deposits[key].groups={}
                    prepare_allocations+=1
                    if not budget.is_empty():budget.used_usec+=Time.get_ticks_usec()-allocation_started
                var handle:Dictionary=pending_deposits[key]
                handle.groups[group.id]=true
                complete=complete and handle.ready
    prepare_usec+=Time.get_ticks_usec()-began
    if not budget.is_empty():budget.used_usec+=maxi(0,Time.get_ticks_usec()-began-(budget.used_usec-charged_before))
    return complete

func _prune_pending(world:Node)->void:
    var ids={}
    if world.timeline.current!=null and not world.timeline.current.is_empty():ids[world.timeline.current.id]=true
    for group in world.timeline.queue:ids[group.id]=true
    _poll_kernel_preparations()
    for prepared in kernel_preparations.duplicate():
        for id in prepared.groups.keys():
            if not ids.has(id):prepared.groups.erase(id)
        if prepared.task<0 and prepared.groups.is_empty():kernel_preparations.erase(prepared)
    for job in kernel_jobs:
        if job.rows.all(func(prepared):return prepared.groups.is_empty()):
            job.control.mutex.lock();job.control.cancelled=true;job.control.mutex.unlock()
    for key in pending_deposits.keys():
        var keep=false
        for id in pending_deposits[key].groups:
            if ids.has(id):keep=true;break
        if not keep and pending_deposits[key].get("world_users",0)==0:
            _free_deposit(world,pending_deposits[key]);pending_deposits.erase(key)

func _active(world:Node,samples:Array)->Array:
    var result:Array=[];var ids={}
    for component in samples:
        if component.kind=="residue_deposit":result.append(component);ids[component.id]=true
    # A tile update may precede its parent DamageApplied completion. Retain the
    # previous contribution until the event-owned flight reaches that tile.
    if world.timeline.current!=null:
        for component in world.timeline.current.get("components",[]):
            if component.kind!="residue_deposit" or ids.has(component.id):continue
            var copy=component.duplicate();copy.age_ms=world.timeline.display_ms-world.timeline.group_start_ms-component.start_ms
            if copy.age_ms<0:result.append(copy)
    return result

func publish_tile_index(owner:Dictionary,revision:int,index:Dictionary)->void:
    # Classification belongs to the same prepared canonical tile after-values
    # as the private fields. Publication only adopts/applies those exact rows.
    if index.full:
        index.retired=tiles
        tiles=index.updates
    else:
        for key in index.removed:tiles.erase(key)
        tiles.merge(index.updates,true)
    tiles_owner=owner;tiles_revision=revision

func sync_tiles(owner:Dictionary,revision:int,changes:Dictionary={})->void:
    if tiles_revision==revision and is_same(tiles_owner,owner):return
    # The displayed world already unions every changed canonical tile. Reuse
    # that exact ledger only when no publication or snapshot owner was missed.
    var sparse=is_same(tiles_owner,owner) and not changes.get("full",true) \
        and changes.get("base_revision",-1)==tiles_revision and changes.get("revision",-2)==revision
    var keys:Array=changes.get("tiles",{}).keys() if sparse else owner.keys()
    if not sparse:tiles={}
    tiles_owner=owner;tiles_revision=revision
    for key in keys:
        var tile:Dictionary=owner.get(key,{})
        if not Blood.residue(tile).is_empty():tiles[key]=tile
        else:tiles.erase(key)

func sample(world:Node,samples:Array,changes:Dictionary={})->void:
    var began=Time.get_ticks_usec()
    sample_phases={}
    var stage_started:int=began
    ready=true;last_allocations=0
    if source.is_empty():source=Blood.Catalog.prepared_asset("particles.region.blood",world.catalog_cache)
    _prune_pending(world)
    _phase("pending",stage_started);stage_started=Time.get_ticks_usec()
    var state:Dictionary=world.timeline.state
    sync_tiles(state.get("tiles",{}),world.timeline.world_revision,changes)
    _phase("tile_index",stage_started);stage_started=Time.get_ticks_usec()
    var active=_active(world,samples);var by_tile={};var live_flights={}
    if source.is_empty():
        ready=tiles.is_empty() and active.is_empty()
        return
    for component in active:
        var age:float=component.age_ms/1000.
        var step:int=-1
        for reveal in component.reveals:
            var cell=Blood.key(reveal.position)
            if not tiles.has(cell) or not Blood.affects_residue(Blood.residue(tiles[cell]),reveal,component.body_release.pattern,source):continue
            if step<0:step=Blood.landing_step(source,component.body_release.pattern,age)
            if not by_tile.has(cell):by_tile[cell]=[]
            var row=reveal.duplicate();row.pattern=component.body_release.pattern;row.age_seconds=age;row.id=component.id
            row.step=step;by_tile[cell].append(row)
        if age>=0:
            var flight_started:int=Time.get_ticks_usec()
            _flight(world,component,age,live_flights)
            _phase("flight",flight_started)
    _phase("active",stage_started);stage_started=Time.get_ticks_usec()
    var visible:Dictionary=world.scenery_visible_cells
    visible_fields={}
    # A tile's screen visibility changes only with the camera, the viewport or
    # the tile's own after-value; recompute it only then.
    var view:Array=[world.camera.global_transform,world.camera.size,world.get_viewport().get_visible_rect()]
    if view!=_tile_view:_tile_view=view;_tile_on_screen={}
    for key in tiles:
        var tile:Dictionary=tiles[key];var value=Blood.residue(tile)
        var known:Array=_tile_on_screen.get(key,[])
        var on_screen:bool=known[1] if not known.is_empty() and is_same(known[0],tile) else _tile_visible(world,tile)
        if known.is_empty() or not is_same(known[0],tile):_tile_on_screen[key]=[tile,on_screen]
        if not on_screen and not deposits.has(key):continue
        if not deposits.has(key):
            if pending_deposits.has(key):
                deposits[key]=pending_deposits[key];pending_deposits.erase(key)
            else:
                # Initial, dirty and remembered tile after-values all receive
                # private fields in WorldPreparation before publication.
                ready=false;continue
        var handle:Dictionary=deposits[key]
        handle.entry.node.visible=on_screen and handle.ready
        if not on_screen:continue
        ready=ready and handle.ready
        var reveals:Array=by_tile.get(key,[]);var phase=reveals.map(func(row):return [row.id,row.step])
        if not is_same(handle.value,value) or handle.phase!=phase:
            var kernel_started:int=Time.get_ticks_usec()
            _adopt_kernel_cache(handle,key,value,not reveals.is_empty())
            var kernels=Blood.kernels(value,tile.position,reveals,source,handle.kernel_cache)
            _phase("kernels",kernel_started)
            var upload_started:int=Time.get_ticks_usec()
            _upload(handle,kernels);handle.value=value;handle.phase=phase
            handle.coverage=Blood.has_coverage(kernels)
            _phase("upload",upload_started)
        if handle.get("coverage",false) and handle.entry.node.visible:visible_fields[key]=true
        var entry:Dictionary=handle.entry
        # This renderer alone writes its deposit nodes and materials.
        var written:Array=[tile.get("elevation_steps",0),1. if visible.has(key) else 0.,1. if world.light_cap_enabled else 0.,world.normals_visible]
        if handle.get("written",[])!=written:
            entry.placement.base_height_steps=written[0];entry.node.position=Placement.contact(entry.placement)
            entry.material.set_shader_parameter("visibility",written[1])
            entry.material.set_shader_parameter("light_cap",written[2])
            entry.material.set_shader_parameter("normals_visible",written[3])
            handle.written=written
    _phase("fields",stage_started);stage_started=Time.get_ticks_usec()
    for key in deposits.keys():
        if not tiles.has(key):deposits[key].entry.node.visible=false
    for key in flights.keys():
        if not live_flights.has(key):_erase_flight(world,key)
    var normal=world.camera.global_basis.inverse()*Vector3.UP;normal.y=-normal.y
    for handle in deposits.values():
        if handle.get("written_normal")!=normal:handle.entry.material.set_shader_parameter("receiving_normal",normal);handle.written_normal=normal
    _phase("receiving_normal",stage_started)
    last_sample_usec=Time.get_ticks_usec()-began
    peak_sample_usec=maxi(peak_sample_usec,last_sample_usec)

func visible_deposit(component:Dictionary)->bool:
    for reveal in component.reveals:
        if visible_fields.has(Blood.key(reveal.position)):return true
    return false

static func _tile_visible(world:Node,tile:Dictionary)->bool:
    var center=Vector3(tile.position[0],tile.get("elevation_steps",0)*Placement.HEIGHT_UNIT,tile.position[1])
    if world.camera.is_position_behind(center):return false
    var bounds=Rect2(world.camera.unproject_position(center+Vector3(-.5,0,-.5)),Vector2.ZERO)
    for dx in [-.5,.5]:
        for dz in [-.5,.5]:bounds=bounds.expand(world.camera.unproject_position(center+Vector3(dx,0,dz)))
    return bounds.intersects(world.get_viewport().get_visible_rect())

func _flight(world:Node,component:Dictionary,age:float,live:Dictionary)->void:
    var buckets={};var zoom:float=world.camera.unproject_position(world.camera.global_basis.x).distance_to(world.camera.unproject_position(Vector3.ZERO))/Placement.PIXELS_PER_UNIT
    var pixel_unit=1.0/Placement.PIXELS_PER_UNIT
    var basis:Basis=world.camera.basis
    var scale:float=maxf(.001,zoom)
    var snap:float=float(source.snapPx)*zoom
    var tail_min:float=source.tailMinPx;var tail_max:float=source.tailMaxPx
    var colors:Array=[Color.hex(int(source.colors[0])*256+255),Color.hex(int(source.colors[1])*256+255)]
    var actor:Dictionary=world.visual_actors.get(component.actor_uuid,{})
    var actor_prefix:Array=GridOrder.key(actor.row,"body",0,0).slice(0,5) if not actor.is_empty() else []
    for particle in Blood.particles(component,source,age):
        var row={"position":[particle.position.x,particle.position.y],"base_height_steps":particle.support_height,"kind":"effect"}
        var prefix=GridOrder.key(row,"native_effect",100,0).slice(0,5)
        var key=component.id+":"+str(prefix)
        if not buckets.has(key):
            # Within the recipient's painter cell, use its exact contact key
            # so the two pre-blend halves surround every assembled body layer.
            buckets[key]={"row":actor.row.duplicate() if prefix==actor_prefix else row,"pieces":[]}
        var point=Vector3(particle.position.x,particle.height*Placement.HEIGHT_UNIT,particle.position.y)
        var previous=Vector3(particle.previous.x,particle.previous_height*Placement.HEIGHT_UNIT,particle.previous.y)
        var screen=world.camera.unproject_position(point);var old=world.camera.unproject_position(previous)
        var direction=(screen-old).normalized();if direction.is_zero_approx():direction=Vector2.RIGHT
        var tangent=(basis.x*direction.x-basis.y*direction.y).normalized()
        var across=basis.z.cross(tangent)
        var length_px=clampf(screen.distance_to(old)/scale,tail_min,tail_max)
        var snapped=Vector2(Blood.even_round(screen.x/snap),Blood.even_round(screen.y/snap))*snap
        point+=basis.x*(snapped.x-screen.x)/scale*pixel_unit-basis.y*(snapped.y-screen.y)/scale*pixel_unit
        # Original physical-blood vocabulary: body rectangle plus bright edge.
        var size:float=particle.size
        var width:float=2.+length_px;var height:float=size-(-size)
        var center:Vector3=point+tangent*(-length_px+2.)*.5*pixel_unit
        var pieces:Array=buckets[key].pieces
        pieces.append({"transform":Transform3D(Basis(tangent*width*pixel_unit,across*height*pixel_unit,basis.z),center),"color":colors[0]})
        var edge:float=-size+maxf(1.,size*.6)
        width=2.;height=edge-(-size)
        center=point-across*(-size+edge)*.5*pixel_unit
        pieces.append({"transform":Transform3D(Basis(tangent*width*pixel_unit,across*height*pixel_unit,basis.z),center),"color":colors[1]})
    for bucket_key in buckets:
        var bucket:Dictionary=buckets[bucket_key]
        var plane=Vector3(basis.z.x,0,basis.z.z).normalized()
        var foot=Placement.contact(actor.row) if not actor.is_empty() else Vector3.ZERO
        for half in ["back","front"]:
            var key=bucket_key+":"+half
            live[key]=true
            if not flights.has(key):
                last_allocations+=1
                var mesh=QuadMesh.new();mesh.size=Vector2.ONE
                var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_colors=true;multi.mesh=mesh
                var node=MultiMeshInstance3D.new();node.multimesh=multi;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
                var material=ShaderMaterial.new();material.shader=Droplet;_receiving(material);node.material_override=material;world.add_child(node)
                var row:Dictionary=bucket.row.duplicate();row.id=key
                var entry={"id":key,"node":node,"material":material,"placement":row,"role":"native_effect","layer":-10 if half=="back" else 100}
                world.actor_entries.append(entry);world.draw_order_dirty=true;flights[key]=entry
            var entry:Dictionary=flights[key];var multi:MultiMesh=entry.node.multimesh
            entry.placement=bucket.row.duplicate();entry.placement.id=key
            entry.node.visible=true
            multi.instance_count=bucket.pieces.size()
            for i in bucket.pieces.size():multi.set_instance_transform(i,bucket.pieces[i].transform);multi.set_instance_color(i,bucket.pieces[i].color)
            entry.material.set_shader_parameter("partition",not actor.is_empty())
            entry.material.set_shader_parameter("back",half=="back")
            entry.material.set_shader_parameter("plane_origin",foot);entry.material.set_shader_parameter("plane_normal",plane)
            entry.material.set_shader_parameter("light_cap",1. if world.light_cap_enabled else 0.)
            entry.material.set_shader_parameter("normals_visible",world.normals_visible)

func _erase_flight(world:Node,key:String)->void:
    var entry:Dictionary=flights[key];world.actor_entries.erase(entry);entry.node.queue_free();flights.erase(key);world.draw_order_dirty=true

func _free_deposit(world:Node,handle:Dictionary)->void:
    world.actor_entries.erase(handle.entry)
    handle.entry.material.set_shader_parameter("field_texture",null);handle.entry.node.queue_free();handle.field.queue_free()
    world.draw_order_dirty=true

func _erase_deposit(world:Node,key:String)->void:
    _free_deposit(world,deposits[key]);deposits.erase(key)

func close(world:Node)->void:
    for job in kernel_jobs:
        job.control.mutex.lock();job.control.cancelled=true;job.control.mutex.unlock()
    for job in kernel_jobs:WorkerThreadPool.wait_for_task_completion(job.task)
    kernel_jobs.clear()
    kernel_preparations.clear()
    for key in flights.keys():_erase_flight(world,key)
    for key in deposits.keys():_erase_deposit(world,key)
    for handle in pending_deposits.values():_free_deposit(world,handle)
    pending_deposits.clear()
    tiles_owner={};tiles={};source={};tiles_revision=-1;_tile_view=[];_tile_on_screen={}
    resources_ready=false;resource_frame=-1
