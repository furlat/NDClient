extends RefCounted
## Finite authored blood geometry. The display clock is the only age owner.
## Persistent fields belong to exact current tile residues; completed fields
## are retained and never rerasterized just because the camera or light moves.
## A field is one 64x64 slot of a shared atlas page. A changed field is drawn by
## a pooled 64x64 painter (the former per-tile target, so its RGBA16F additive
## sums are bit-identical) and copied unchanged into its slot in the same frame:
## painters are page children and draw first. An empty field is a slot clear,
## no painter. Stains stay their own ordered draws: one pooled MeshInstance3D
## per slot, the page's shared material.
const Blood=preload("res://presentation/blood.gd")
const Placement=preload("res://placement.gd")
const GridOrder=preload("res://grid_order.gd")
const Kernel=preload("res://presentation/blood_kernel.gdshader")
const Surface=preload("res://presentation/blood_surface.gdshader")
const Droplet=preload("res://presentation/blood_droplet.gdshader")
const FieldCopy=preload("res://presentation/blood_field_copy.gdshader")
const Admission=preload("res://presentation/native_source_admission.gd")
# One admission step per frame; the two-line field copy warms with the kernel
# so first blood still waits the same three frames.
const PROGRAMS=[[Kernel,FieldCopy],[Surface],[Droplet]]
const FIELD=64
const PAGE_SLOTS=8
const SLOTS_PER_PAGE=PAGE_SLOTS*PAGE_SLOTS
# GridOrder.key's owner-cell origin; a droplet bucket is its quarter-0 prefix.
const CELL_ORIGIN=Vector2(-0.489921,-0.489921)
const NO_REVEALS=[]
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
# Source references admitted by actual release/tile preparation, not new world owners.
var sources:Dictionary={}
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
var _draw_waits:Dictionary={}
var _next_draw_wait:int=0
var deposit_create_usec:int=0
var sample_phases:Dictionary={}
# Atlas pages and their shared stain materials; slot-indexed stain draws.
var _pages:Array=[]
var _page_materials:Array=[]
var _slot_entries:Array=[]
var _free_slots:PackedInt32Array=[]
var _slot_painter:PackedInt32Array=[]
var _slot_epoch:PackedInt32Array=[]
var _generation:int=0
# Per page, the slots cleared this frame (drawn before any copy).
var _page_clears:Array=[]
var _page_clear_data:Array=[]
# Pooled painters, their kernel MultiMeshes and per page their slot copies.
var _painters:Array=[]
var _painter_kernels:Array=[]
var _painter_copies:Array=[]
var _painting:bool=false
var _paint_callback:Callable
var _paint_epoch:int=0
var _painted:int=0
var _shown_copies:Array=[]
var _plane:PlaneMesh
var _kernel_quad:QuadMesh
var _slot_quad:QuadMesh
var _zero_field:ImageTexture
var _kernel_material:ShaderMaterial
var _copy_material:ShaderMaterial
# Droplet halves share one material; released halves wait hidden for reuse.
var _droplet_quad:QuadMesh
var _droplet_material:ShaderMaterial
var _flight_pool:Array=[]
# Per airborne release: its age-independent flight_plan(), kept while it flies.
var _flight_plans:Dictionary={}
var _written_room:Array=[]
var _pool_world:Node

func _phase(name:String,started:int)->void:
    sample_phases[name]=sample_phases.get(name,0.0)+(Time.get_ticks_usec()-started)/1000.0

func prepare_resources(world:Node,budget:Dictionary={})->bool:
    if resources_ready:return true
    var frame:int=Engine.get_process_frames()
    if _programs_prepared<PROGRAMS.size():
        if _program_frame==frame or (not budget.is_empty() and budget.used_usec>=budget.limit_usec) or not Admission.begin_mutation():return false
        var started:int=Time.get_ticks_usec()
        _program_frame=frame
        for program in PROGRAMS[_programs_prepared]:program.get_rid()
        _programs_prepared+=1
        if not budget.is_empty():budget.used_usec+=Time.get_ticks_usec()-started
        return false
    resources_ready=true
    return true

func _receiving(material:ShaderMaterial)->void:
    material.set_shader_parameter("blood_ambient",ambient)
    material.set_shader_parameter("blood_room_lights",room_lights)

static func _slot_origin(slot:int)->Vector2i:
    var local:int=slot%SLOTS_PER_PAGE
    return Vector2i(local%PAGE_SLOTS,local/PAGE_SLOTS)*FIELD

func _add_page(world:Node)->void:
    if _plane==null:
        _plane=PlaneMesh.new();_plane.size=Vector2.ONE
        _kernel_quad=QuadMesh.new();_kernel_quad.size=Vector2(2,2)
        _kernel_material=ShaderMaterial.new();_kernel_material.shader=Kernel
        _copy_material=ShaderMaterial.new();_copy_material.shader=FieldCopy
        _slot_quad=QuadMesh.new();_slot_quad.size=Vector2(FIELD,FIELD)
        _zero_field=ImageTexture.create_from_image(Image.create(FIELD,FIELD,false,Image.FORMAT_RGBA8))
    # Cleared once, then only clears and copies of changed slots draw into it.
    var page=SubViewport.new();page.size=Vector2i(PAGE_SLOTS,PAGE_SLOTS)*FIELD;page.disable_3d=true;page.transparent_bg=true;page.use_hdr_2d=true
    page.render_target_clear_mode=SubViewport.CLEAR_MODE_ONCE;page.render_target_update_mode=SubViewport.UPDATE_DISABLED;world.add_child(page)
    var clears=MultiMesh.new();clears.transform_format=MultiMesh.TRANSFORM_2D;clears.mesh=_slot_quad
    var cleared=MultiMeshInstance2D.new();cleared.multimesh=clears;cleared.texture=_zero_field;cleared.material=_copy_material;page.add_child(cleared)
    _page_clears.append(clears);_page_clear_data.append(PackedFloat32Array())
    var material=ShaderMaterial.new();material.shader=Surface;_receiving(material)
    material.set_shader_parameter("field_atlas",page.get_texture())
    if not _written_room.is_empty():_write_room(material)
    _pages.append(page);_page_materials.append(material)

func _slot(world:Node)->int:
    _own(world)
    if not _free_slots.is_empty():
        var reused:int=_free_slots[_free_slots.size()-1];_free_slots.resize(_free_slots.size()-1)
        return reused
    var slot:int=_slot_entries.size()
    if slot%SLOTS_PER_PAGE==0:_add_page(world)
    var material:ShaderMaterial=_page_materials[slot/SLOTS_PER_PAGE]
    var node=MeshInstance3D.new();node.mesh=_plane;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.material_override=material
    node.visible=false;node.set_instance_shader_parameter("field_origin",Vector2(_slot_origin(slot)));world.add_child(node)
    _slot_entries.append({"id":"","node":node,"material":material,"placement":{},"role":"covering","layer":1})
    _slot_painter.append(-1);_slot_epoch.append(-1)
    return slot

func _add_painter()->void:
    var painter=SubViewport.new();painter.size=Vector2i(FIELD,FIELD);painter.disable_3d=true;painter.transparent_bg=true;painter.use_hdr_2d=true
    painter.render_target_update_mode=SubViewport.UPDATE_DISABLED;_pages[0].add_child(painter)
    var multimesh=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_2D;multimesh.use_custom_data=true;multimesh.mesh=_kernel_quad
    var kernels=MultiMeshInstance2D.new();kernels.multimesh=multimesh;kernels.material=_kernel_material;painter.add_child(kernels)
    _painters.append(painter);_painter_kernels.append(multimesh);_painter_copies.append([])

func _paint(slot:int,kernels:Array)->void:
    if not _painting:
        # One epoch per drawn frame, sealed when that draw begins: a copy lands
        # only in the frame its painter draws.
        for copy in _shown_copies:copy.visible=false
        for page in _page_clears.size():
            if not _page_clear_data[page].is_empty():_page_clear_data[page]=PackedFloat32Array();_page_clears[page].instance_count=0
        _shown_copies=[];_painted=0;_paint_epoch+=1;_painting=true
        _paint_callback=func():
            _painting=false
            _paint_callback=Callable()
        RenderingServer.frame_pre_draw.connect(_paint_callback,CONNECT_ONE_SHOT)
    var painter:int=_slot_painter[slot] if _slot_epoch[slot]==_paint_epoch else -1
    if kernels.is_empty() and painter<0:
        # Zero texels with no painter; a later copy this frame still wins.
        if painter==-2:return
        var page:int=slot/SLOTS_PER_PAGE;var origin:Vector2=Vector2(_slot_origin(slot))+Vector2(FIELD,FIELD)*.5
        var data:PackedFloat32Array=_page_clear_data[page];var at:int=data.size();data.resize(at+8)
        data[at]=1.;data[at+3]=origin.x;data[at+5]=1.;data[at+7]=origin.y
        _page_clears[page].instance_count=data.size()/8;_page_clears[page].buffer=data
        _slot_painter[slot]=-2;_slot_epoch[slot]=_paint_epoch
        _pages[page].render_target_update_mode=SubViewport.UPDATE_ONCE
        return
    if painter<0:
        painter=_painted;_painted+=1
        if painter==_painters.size():_add_painter()
        _slot_painter[slot]=painter;_slot_epoch[slot]=_paint_epoch
        var page:int=slot/SLOTS_PER_PAGE;var copies:Array=_painter_copies[painter]
        while copies.size()<=page:copies.append(null)
        if copies[page]==null:
            var sprite=Sprite2D.new();sprite.centered=false;sprite.texture=_painters[painter].get_texture();sprite.material=_copy_material
            _pages[page].add_child(sprite);copies[page]=sprite
        copies[page].position=Vector2(_slot_origin(slot));copies[page].visible=true;_shown_copies.append(copies[page])
        _pages[page].render_target_update_mode=SubViewport.UPDATE_ONCE
    # One buffer write: TRANSFORM_2D rows with origin, then the custom mass.
    var data:=PackedFloat32Array();data.resize(kernels.size()*12)
    for i in kernels.size():
        var transform:Transform2D=kernels[i].transform
        var fragment:bool=kernels[i].get("fragment",false)
        if fragment:
            transform.origin=(transform.origin+Vector2(.5,.5)+(transform.x+transform.y)*.5)*64.
            transform.x*=32.;transform.y*=32.
        else:
            transform.x*=sqrt(1.5)*64.;transform.y*=sqrt(1.5)*64.;transform.origin=(transform.origin+Vector2(.5,.5))*64.
        var at:int=i*12
        data[at]=transform.x.x;data[at+1]=transform.y.x;data[at+3]=transform.origin.x
        data[at+4]=transform.x.y;data[at+5]=transform.y.y;data[at+7]=transform.origin.y;data[at+8]=kernels[i].mass;data[at+9]=1. if fragment else 0.
    var multimesh:MultiMesh=_painter_kernels[painter]
    if multimesh.instance_count!=kernels.size():multimesh.instance_count=kernels.size()
    multimesh.buffer=data
    _painters[painter].render_target_update_mode=SubViewport.UPDATE_ONCE

func _deposit(world:Node,key:String,tile:Dictionary,registered:bool=true)->Dictionary:
    var phase:int=Time.get_ticks_usec()
    last_allocations+=1
    var slot:int=_slot(world)
    var entry:Dictionary=_slot_entries[slot]
    entry.id="blood:tile:"+key
    entry.placement={"id":entry.id,"position":tile.position,"base_height_steps":tile.get("elevation_steps",0),"kind":"effect","layer":1}
    entry.node.position=Placement.contact(entry.placement);entry.node.visible=false
    entry.node.set_instance_shader_parameter("tile_position",Vector2(tile.position[0],tile.position[1]))
    if registered:world.actor_entries.append(entry);world.draw_order_dirty=true
    # The empty field draws once, as the former per-tile target did.
    _paint(slot,[])
    deposit_create_usec+=Time.get_ticks_usec()-phase
    var handle={"entry":entry,"slot":slot,"generation":_generation,"drawn":[],"value":{},"phase":[],"updates":0,"ready":false,"kernel_cache":{},"registered":registered,"world_users":0}
    _await_draw(handle)
    return handle

func _await_draw(handle:Dictionary)->void:
    _cancel_draw(handle)
    var id:int=_next_draw_wait;_next_draw_wait+=1
    var completed:Callable=func():
        _draw_waits.erase(id)
        handle.erase("draw_callback");handle.erase("draw_wait")
        handle.ready=true
    handle.draw_callback=completed;handle.draw_wait=id
    _draw_waits[id]=handle
    RenderingServer.frame_post_draw.connect(completed,CONNECT_ONE_SHOT)

func _cancel_draw(handle:Dictionary)->void:
    var completed:Callable=handle.get("draw_callback",Callable())
    if completed.is_valid() and RenderingServer.frame_post_draw.is_connected(completed):
        RenderingServer.frame_post_draw.disconnect(completed)
    if handle.has("draw_wait"):_draw_waits.erase(handle.draw_wait)
    handle.erase("draw_callback");handle.erase("draw_wait")

func _release(world:Node,handle:Dictionary)->void:
    # The slot and its hidden draw return to the pool; nothing is freed.
    _cancel_draw(handle)
    if handle.get("slot",-1)<0 or handle.generation!=_generation:return
    if handle.registered and world!=null:world.actor_entries.erase(handle.entry);world.draw_order_dirty=true
    handle.registered=false;handle.entry.node.visible=false
    _free_slots.append(handle.slot);handle.slot=-1

func field_image(handle:Dictionary)->Image:
    # Test/oracle readback of one slot (synchronous GPU read).
    return _pages[handle.slot/SLOTS_PER_PAGE].get_texture().get_image().get_region(Rect2i(_slot_origin(handle.slot),Vector2i(FIELD,FIELD)))

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
            var handle:Dictionary=pending_deposits[key] if borrowed else _deposit(world,key,row.tile,false)
            if borrowed:handle.world_users=handle.get("world_users",0)+1
            handle.value=row.value;handle.phase=[];handle.coverage=row.coverage
            handle.kernel_cache=row.cache
            _style(handle,row.source)
            _upload(handle,row.kernels)
            handle.ready=false
            _await_draw(handle)
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
            old.entry.node.visible=false
            if old.registered:world.actor_entries.erase(old.entry);old.registered=false
            preparation.retired.append(old)
        if record.get("removed",false):deposits.erase(key);world.draw_order_dirty=true;continue
        if not handle.registered:world.actor_entries.append(handle.entry);handle.registered=true
        var residue_id:String=Blood.field_residue(key)
        sources[residue_id]=handle.kernel_cache.source
        if residue_id=="residue.blood":source=handle.kernel_cache.source
        deposits[key]=handle;world.draw_order_dirty=true
    preparation.handles={}

func release_world(preparation:Dictionary)->Array:
    # Private and retired fields return their slots to this renderer's pool;
    # no node is handed to external retirement.
    for record in preparation.handles.values():
        if record.get("removed",false):continue
        if record.borrowed:record.handle.world_users-=1
        else:preparation.retired.append(record.handle)
    for handle in preparation.retired:_release(null,handle)
    preparation.handles={};preparation.retired=[]
    return []

func _style(handle:Dictionary,asset:Dictionary)->void:
    if is_same(handle.get("style_source"),asset):return
    var region:Dictionary=asset.region
    var palette:Variant=region.get("palette")
    var node:MeshInstance3D=handle.entry.node
    node.set_instance_shader_parameter("fragment_primitive",region.get("primitive")=="fragments")
    node.set_instance_shader_parameter("authored_palette",palette!=null)
    for i in 3:
        var color:Color=Color.hex(int(palette[i])*256+255) if palette!=null else Color.BLACK
        node.set_instance_shader_parameter("palette"+str(i),Vector3(color.r,color.g,color.b))
    handle.style_source=asset

func _upload(handle:Dictionary,kernels:Array)->void:
    # The same cached kernel shapes in the same order are the same field: only
    # slots whose kernels changed repaint (a landing step moves few tiles).
    var drawn:Array=handle.drawn
    if drawn.size()==kernels.size():
        var same:bool=true
        for i in kernels.size():
            if not is_same(drawn[i],kernels[i]):same=false;break
        if same:return
    _paint(handle.slot,kernels);handle.drawn=kernels
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

func _prepare_kernels(key:String,reveal:Dictionary,pattern:String,group_id:String,budget:Dictionary,asset:Dictionary)->bool:
    for prepared in kernel_preparations:
        if prepared.key==key and is_same(prepared.source,asset) and prepared.value==reveal.after:
            prepared.groups[group_id]=true
            return prepared.task==-1 and prepared.output.has("cache")
    var input={"value":reveal.after,"position":reveal.position.duplicate(),"source":asset,"reveal":reveal,"pattern":pattern}
    var output:Dictionary={}
    kernel_preparations.append({"key":key,"value":reveal.after,"source":asset,"groups":{group_id:true},"input":input,"output":output,"task":-2})
    return false

func _adopt_kernel_cache(handle:Dictionary,key:String,value:Dictionary,prefer_landing:bool=false,asset:Dictionary={})->void:
    if is_same(handle.kernel_cache.get("value"),value) and is_same(handle.kernel_cache.get("source"),asset) and (not prefer_landing or handle.kernel_cache.has("landing")):return
    for prepared in kernel_preparations:
        if prepared.key==key and prepared.task==-1 and not prepared.groups.is_empty() and is_same(prepared.source,asset) and prepared.value==value and prepared.output.get("cache",{}).get("value")==value:
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
    if source.is_empty():source=Blood.Catalog.prepared_residue_asset(world.catalog_cache)
    if not source.is_empty():sources["residue.blood"]=source
    for group in groups:
        for component in group.get("components",[]):
            if component.kind!="residue_deposit" or component.get("status")=="missing":continue
            var asset:Dictionary=component.get("asset_metadata",{})
            if asset.is_empty():return false
            sources[str(component.get("residue_id","residue.blood"))]=asset
    for group in groups:
        for component in group.get("components",[]):
            if component.kind!="residue_deposit" or component.get("status")=="missing":continue
            var asset:Dictionary=sources[str(component.get("residue_id","residue.blood"))]
            for reveal in component.reveals:_prepare_kernels(Blood.field_key(reveal.position,str(component.get("residue_id","residue.blood"))),reveal,component.body_release.pattern,group.id,budget,asset)
    _start_kernel_jobs(budget)
    var complete=true
    for group in groups:
        for component in group.get("components",[]):
            if component.kind!="residue_deposit" or component.get("status")=="missing":continue
            var asset:Dictionary=sources[str(component.get("residue_id","residue.blood"))]
            for reveal in component.reveals:
                var key=Blood.field_key(reveal.position,str(component.get("residue_id","residue.blood")))
                var shapes_ready:bool=_prepare_kernels(key,reveal,component.body_release.pattern,group.id,budget,asset)
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
            _release(world,pending_deposits[key]);pending_deposits.erase(key)

func _active(world:Node,samples:Array)->Array:
    var result:Array=[];var ids={}
    for component in samples:
        if component.kind=="residue_deposit" and component.get("status")!="missing":result.append(component);ids[component.id]=true
    # A tile update may precede its parent DamageApplied completion. Retain the
    # previous contribution until the event-owned flight reaches that tile.
    if world.timeline.current!=null:
        for component in world.timeline.current.get("components",[]):
            if component.kind!="residue_deposit" or component.get("status")=="missing" or ids.has(component.id):continue
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
    if not source.is_empty():sources["residue.blood"]=source
    for cell in keys:
        var tile:Dictionary=owner.get(cell,{})
        for residue_id in sources:
            var key:String=Blood.field_id(str(cell),residue_id)
            if not Blood.residue(tile,residue_id).is_empty():tiles[key]=tile
            else:tiles.erase(key)

func sample(world:Node,samples:Array,changes:Dictionary={})->void:
    var began=Time.get_ticks_usec()
    sample_phases={}
    var stage_started:int=began
    ready=true;last_allocations=0
    if source.is_empty():source=Blood.Catalog.prepared_residue_asset(world.catalog_cache)
    _prune_pending(world)
    _phase("pending",stage_started);stage_started=Time.get_ticks_usec()
    var state:Dictionary=world.timeline.state
    sync_tiles(state.get("tiles",{}),world.timeline.world_revision,changes)
    _phase("tile_index",stage_started);stage_started=Time.get_ticks_usec()
    var active=_active(world,samples);var by_tile={};var live_flights={};var flown={}
    if sources.is_empty() and source.is_empty():
        ready=tiles.is_empty() and active.is_empty()
        return
    _room(world)
    for component in active:
        if component.get("status")=="missing":continue
        var residue_id:String=str(component.get("residue_id","residue.blood"))
        var asset:Dictionary=sources.get(residue_id,{})
        if asset.is_empty():ready=false;continue
        var age:float=component.age_ms/1000.
        var step:int=-1
        for reveal in component.reveals:
            var cell=Blood.field_key(reveal.position,residue_id)
            if not tiles.has(cell) or not Blood.affects_residue(Blood.residue(tiles[cell],residue_id),reveal,component.body_release.pattern,asset):continue
            if step<0:step=Blood.landing_step(asset,component.body_release.pattern,age)
            if not by_tile.has(cell):by_tile[cell]=[]
            var row=reveal.duplicate();row.pattern=component.body_release.pattern;row.age_seconds=age;row.id=component.id
            row.step=step;by_tile[cell].append(row)
        if age>=0:
            var flight_started:int=Time.get_ticks_usec()
            flown[component.id]=true
            _flight(world,component,age,live_flights,asset)
            _phase("flight",flight_started)
    _phase("active",stage_started);stage_started=Time.get_ticks_usec()
    var visible:Dictionary=world.scenery_visible_cells
    visible_fields={}
    # A tile's screen visibility changes only with the camera, the viewport or
    # the tile's own after-value; recompute it only then.
    var view:Array=[world.camera.global_transform,world.camera.size,world.get_viewport().get_visible_rect()]
    if view!=_tile_view:_tile_view=view;_tile_on_screen={}
    for key in tiles:
        var tile:Dictionary=tiles[key];var value=Blood.residue(tile,Blood.field_residue(key))
        var asset:Dictionary=sources.get(Blood.field_residue(key),{})
        if asset.is_empty():ready=false;continue
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
        var reveals:Array=by_tile.get(key,NO_REVEALS);var phase:Array=NO_REVEALS if reveals.is_empty() else reveals.map(func(row):return [row.id,row.step])
        if not is_same(handle.value,value) or handle.phase!=phase:
            var kernel_started:int=Time.get_ticks_usec()
            _adopt_kernel_cache(handle,key,value,not reveals.is_empty(),asset)
            var kernels=Blood.kernels(value,tile.position,reveals,asset,handle.kernel_cache)
            _phase("kernels",kernel_started)
            var upload_started:int=Time.get_ticks_usec()
            _style(handle,asset)
            _upload(handle,kernels);handle.value=value;handle.phase=phase
            handle.coverage=Blood.has_coverage(kernels)
            _phase("upload",upload_started)
        if handle.get("coverage",false) and handle.entry.node.visible:visible_fields[key]=true
        var entry:Dictionary=handle.entry
        # This renderer alone writes its stain draws; room values are shared.
        var height=tile.get("elevation_steps",0);var shown:float=1. if visible.has(Blood.field_cell(str(key))) else 0.
        if handle.get("written_height")!=height:
            entry.placement.base_height_steps=height;entry.node.position=Placement.contact(entry.placement);handle.written_height=height
        if handle.get("written_visibility")!=shown:entry.node.set_instance_shader_parameter("visibility",shown);handle.written_visibility=shown
    _phase("fields",stage_started);stage_started=Time.get_ticks_usec()
    for key in deposits.keys():
        if not tiles.has(key):deposits[key].entry.node.visible=false
    for key in flights.keys():
        if not live_flights.has(key):_erase_flight(world,key)
    for id in _flight_plans.keys():
        if not flown.has(id):_flight_plans.erase(id)
    _phase("retire",stage_started)
    last_sample_usec=Time.get_ticks_usec()-began
    peak_sample_usec=maxi(peak_sample_usec,last_sample_usec)

func _write_room(material:ShaderMaterial)->void:
    material.set_shader_parameter("light_cap",_written_room[0]);material.set_shader_parameter("normals_visible",_written_room[1])
    material.set_shader_parameter("receiving_normal",_written_room[2])

func _room(world:Node)->void:
    # Light cap, Normals view and the receiving normal are room-wide: one write
    # per shared material when they change, never per stain or droplet.
    var normal=world.camera.global_basis.inverse()*Vector3.UP;normal.y=-normal.y
    var room:Array=[1. if world.light_cap_enabled else 0.,world.normals_visible,normal]
    if room==_written_room:return
    _written_room=room
    for material in _page_materials:_write_room(material)
    if _droplet_material!=null:_write_room(_droplet_material)

func visible_deposit(component:Dictionary)->bool:
    for reveal in component.reveals:
        if visible_fields.has(Blood.field_key(reveal.position,str(component.get("residue_id","residue.blood")))):return true
    return false

static func _tile_visible(world:Node,tile:Dictionary)->bool:
    var center=Vector3(tile.position[0],tile.get("elevation_steps",0)*Placement.HEIGHT_UNIT,tile.position[1])
    if world.camera.is_position_behind(center):return false
    var bounds=Rect2(world.camera.unproject_position(center+Vector3(-.5,0,-.5)),Vector2.ZERO)
    for dx in [-.5,.5]:
        for dz in [-.5,.5]:bounds=bounds.expand(world.camera.unproject_position(center+Vector3(dx,0,dz)))
    return bounds.intersects(world.get_viewport().get_visible_rect())

func _flight(world:Node,component:Dictionary,age:float,live:Dictionary,asset:Dictionary)->void:
    var buckets={};var cells={};var zoom:float=world.camera.unproject_position(world.camera.global_basis.x).distance_to(world.camera.unproject_position(Vector3.ZERO))/Placement.PIXELS_PER_UNIT
    var pixel_unit=1.0/Placement.PIXELS_PER_UNIT
    var basis:Basis=world.camera.basis
    var scale:float=maxf(.001,zoom)
    var snap:float=float(asset.snapPx)*zoom
    var tail_min:float=asset.tailMinPx;var tail_max:float=asset.tailMaxPx
    var colors:Array=[Color.hex(int(asset.colors[0])*256+255),Color.hex(int(asset.colors[1])*256+255)]
    var fragment_primitive:bool=asset.region.get("primitive")=="fragments"
    var actor:Dictionary=world.visual_actors.get(component.actor_uuid,{})
    var actor_prefix:Array=GridOrder.key(actor.row,"body",0,0).slice(0,5) if not actor.is_empty() else []
    var plan:Array=_flight_plans.get(component.id,[])
    if plan.is_empty() or not is_same(plan[0],component.body_release) or not is_same(plan[1],component.position) or plan[2]!=component.elevation_steps \
            or plan[3]!=component.get("flight_enabled",true) or not is_same(plan[4],asset):
        plan=[component.body_release,component.position,component.elevation_steps,component.get("flight_enabled",true),asset,Blood.flight_plan(component,asset)]
        _flight_plans[component.id]=plan
    for particle in Blood.particles(component,asset,age,plan[5]):
        # GridOrder.key's quarter-0 prefix is [1,x+y,x-y,support,2] of the
        # particle's owner cell: the cell and support height (with its type,
        # as str() tells them apart) select the bucket. The key itself is
        # built once per bucket, from its first particle, exactly as before.
        var support=particle.support_height
        var owner:Vector2=(particle.position-CELL_ORIGIN).round()
        var cell:=Vector4(owner.x,owner.y,support,typeof(support))
        var bucket:Dictionary=cells.get(cell,{})
        if bucket.is_empty():
            var row={"position":[particle.position.x,particle.position.y],"base_height_steps":support,"kind":"effect"}
            var prefix=GridOrder.key(row,"native_effect",100,0).slice(0,5)
            var key=component.id+":"+str(prefix)
            if not buckets.has(key):
                # Within the recipient's painter cell, use its exact contact key
                # so the two pre-blend halves surround every assembled body layer.
                buckets[key]={"row":actor.row.duplicate() if prefix==actor_prefix else row,"pieces":PackedFloat32Array()}
            bucket=buckets[key];cells[cell]=bucket
        var point=Vector3(particle.position.x,particle.height*Placement.HEIGHT_UNIT,particle.position.y)
        var previous=Vector3(particle.previous.x,particle.previous_height*Placement.HEIGHT_UNIT,particle.previous.y)
        var screen=world.camera.unproject_position(point);var old=world.camera.unproject_position(previous)
        var direction=(screen-old).normalized();if direction.is_zero_approx():direction=Vector2.RIGHT
        var tangent=(basis.x*direction.x-basis.y*direction.y).normalized()
        var across=basis.z.cross(tangent)
        var length_px=clampf(screen.distance_to(old)/scale,tail_min,tail_max)
        var snapped=Vector2(Blood.even_round(screen.x/snap),Blood.even_round(screen.y/snap))*snap
        var fragment_origin:Vector3=point
        point+=basis.x*(snapped.x-screen.x)/scale*pixel_unit-basis.y*(snapped.y-screen.y)/scale*pixel_unit
        # Original physical-blood vocabulary: body rectangle plus bright edge.
        var size:float=particle.size
        var width:float=2.+length_px;var height:float=size-(-size)
        var center:Vector3=point+tangent*(-length_px+2.)*.5*pixel_unit
        var pieces:PackedFloat32Array=bucket.pieces
        if fragment_primitive:
            var polygon:PackedVector2Array=particle.fragment
            var indices:PackedInt32Array=Geometry2D.triangulate_polygon(polygon)
            for at in range(0,indices.size(),3):
                var a:Vector2=polygon[indices[at]];var b:Vector2=polygon[indices[at+1]];var c:Vector2=polygon[indices[at+2]]
                var x:=Vector3(b.x-a.x,0.,b.y-a.y);var y:=Vector3(c.x-a.x,0.,c.y-a.y)
                _piece(pieces,x,y,Vector3.UP,fragment_origin+Vector3(a.x,0.,a.y)+(x+y)*.5,colors[0],true,true)
        else:
            _piece(pieces,tangent*width*pixel_unit,across*height*pixel_unit,basis.z,center,colors[0])
        var edge:float=-size+maxf(1.,size*.6)
        width=2.;height=edge-(-size)
        center=point-across*(-size+edge)*.5*pixel_unit
        _piece(pieces,tangent*width*pixel_unit,across*height*pixel_unit,basis.z,center,colors[1],fragment_primitive)
    var partition:bool=not actor.is_empty()
    var plane=Vector3(basis.z.x,0,basis.z.z).normalized()
    var foot=Placement.contact(actor.row) if partition else Vector3.ZERO
    for bucket_key in buckets:
        var bucket:Dictionary=buckets[bucket_key]
        var count:int=bucket.pieces.size()/(20 if fragment_primitive else 16)
        for half in ["back","front"]:
            var key=bucket_key+":"+half
            live[key]=true
            if not flights.has(key):flights[key]=_flight_entry(world,key,half=="back")
            var entry:Dictionary=flights[key];var multi:MultiMesh=entry.node.multimesh
            entry.placement=bucket.row.duplicate();entry.placement.id=key
            entry.node.visible=true
            if multi.use_custom_data!=fragment_primitive:
                multi.instance_count=0;multi.use_custom_data=fragment_primitive
                entry.node.set_instance_shader_parameter("polygon_flight",fragment_primitive)
            if multi.instance_count!=count:multi.instance_count=count
            multi.buffer=bucket.pieces
            if entry.get("written_partition")!=partition:entry.node.set_instance_shader_parameter("partition",partition);entry.written_partition=partition
            if entry.get("written_foot")!=foot:entry.node.set_instance_shader_parameter("plane_origin",foot);entry.written_foot=foot
            if entry.get("written_plane")!=plane:entry.node.set_instance_shader_parameter("plane_normal",plane);entry.written_plane=plane

static func _piece(pieces:PackedFloat32Array,x:Vector3,y:Vector3,z:Vector3,origin:Vector3,color:Color,custom:bool=false,fragment:bool=false)->void:
    # MultiMesh TRANSFORM_3D + colour layout: basis rows with origin, then RGBA.
    var i:int=pieces.size();pieces.resize(i+(20 if custom else 16))
    pieces[i]=x.x;pieces[i+1]=y.x;pieces[i+2]=z.x;pieces[i+3]=origin.x
    pieces[i+4]=x.y;pieces[i+5]=y.y;pieces[i+6]=z.y;pieces[i+7]=origin.y
    pieces[i+8]=x.z;pieces[i+9]=y.z;pieces[i+10]=z.z;pieces[i+11]=origin.z
    pieces[i+12]=color.r;pieces[i+13]=color.g;pieces[i+14]=color.b;pieces[i+15]=color.a
    if custom:pieces[i+16]=1. if fragment else 0.

func _flight_entry(world:Node,key:String,back:bool)->Dictionary:
    _own(world)
    var entry:Dictionary
    if _flight_pool.is_empty():
        last_allocations+=1
        if _droplet_material==null:
            _droplet_quad=QuadMesh.new();_droplet_quad.size=Vector2.ONE
            _droplet_material=ShaderMaterial.new();_droplet_material.shader=Droplet;_receiving(_droplet_material)
            if not _written_room.is_empty():_write_room(_droplet_material)
        var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_colors=true;multi.mesh=_droplet_quad
        var node=MultiMeshInstance3D.new();node.multimesh=multi;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        node.material_override=_droplet_material;world.add_child(node)
        entry={"node":node,"material":_droplet_material,"role":"native_effect"}
    else:entry=_flight_pool.pop_back()
    entry.id=key;entry.layer=-10 if back else 100
    if entry.get("written_back")!=back:entry.node.set_instance_shader_parameter("back",back);entry.written_back=back
    world.actor_entries.append(entry);world.draw_order_dirty=true
    return entry

func _erase_flight(world:Node,key:String)->void:
    var entry:Dictionary=flights[key];world.actor_entries.erase(entry);entry.node.visible=false;flights.erase(key);world.draw_order_dirty=true
    _flight_pool.append(entry)

func close(world:Node)->void:
    # An epoch reset releases every displayed and pending field, droplet and
    # prepared shape. Pooled draws, painters and pages stay hidden under the
    # world for reuse (the world owns their lifetime), so a candidate that
    # already prepared private fields for the new epoch can still publish them.
    for job in kernel_jobs:
        job.control.mutex.lock();job.control.cancelled=true;job.control.mutex.unlock()
    for job in kernel_jobs:WorkerThreadPool.wait_for_task_completion(job.task)
    kernel_jobs.clear()
    kernel_preparations.clear()
    for key in flights.keys():_erase_flight(world,key)
    for handle in deposits.values():_release(world,handle)
    for handle in pending_deposits.values():_release(world,handle)
    deposits.clear();pending_deposits.clear();_flight_plans={}
    tiles_owner={};tiles={};source={};sources={};tiles_revision=-1;_tile_view=[];_tile_on_screen={}
    resources_ready=false;resource_frame=-1

func _own(world:Node)->void:
    # Pools live under one world; a renderer reused for another drops them and
    # turns any handle still held elsewhere inert.
    if is_same(_pool_world,world):return
    _cancel_pending_draws()
    if is_instance_valid(_pool_world) and _pool_world.tree_exiting.is_connected(_cancel_pending_draws):
        _pool_world.tree_exiting.disconnect(_cancel_pending_draws)
    world.tree_exiting.connect(_cancel_pending_draws,CONNECT_ONE_SHOT)
    for entry in _flight_pool+_slot_entries:
        if is_instance_valid(entry.node):entry.node.queue_free()
    for page in _pages:
        if is_instance_valid(page):page.queue_free()
    _flight_pool=[];_slot_entries=[];_pages=[];_page_materials=[];_page_clears=[];_page_clear_data=[];_painters=[];_painter_kernels=[];_painter_copies=[];_shown_copies=[]
    _free_slots=PackedInt32Array();_slot_painter=PackedInt32Array();_slot_epoch=PackedInt32Array();_generation+=1
    _droplet_material=null;_written_room=[];_pool_world=world

func _cancel_paint()->void:
    if _paint_callback.is_valid() and RenderingServer.frame_pre_draw.is_connected(_paint_callback):
        RenderingServer.frame_pre_draw.disconnect(_paint_callback)
    _paint_callback=Callable();_painting=false

func _cancel_pending_draws()->void:
    # These leases belong to the physical pool world, including private fields
    # a new epoch has prepared. An ordinary epoch close preserves those fields;
    # replacing or exiting their world retires every remaining draw lease.
    _cancel_paint()
    for handle in _draw_waits.values():_cancel_draw(handle)
