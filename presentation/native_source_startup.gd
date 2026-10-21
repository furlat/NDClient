extends RefCounted
## Native program preparation. Readiness belongs to the requested source set;
## retained program owners are shared, while every live occurrence stays private.
const Effects=preload("res://presentation/effect_package.gd")
const Authoring=preload("res://presentation/native_spell_authoring.gd")
const Profile=preload("res://frame_profile.gd")
const Baked=preload("res://presentation/baked_effect.gd")
const SOURCE_LAYER=1<<19
const SETTLE_FRAMES=4
static var _state:Dictionary={}
static var _frame:int=-1

static func _memory()->Dictionary:
    return {"static_mib":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0,
        "video_mib":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0}

## A clip warms once per playing approach kind (the Studio can switch kinds).
static func _key(clip:Dictionary)->String:
    return Effects.key(clip)

static func recording_plan(rows:Array)->Array:
    # These are already-compiled source occurrences, including disclosed
    # condition/spatial rows. No catalog-wide spell enumeration or new clock.
    var result:Array=[];var by_key:Dictionary={}
    for row in rows:
        var component:Dictionary=row.get("component",{})
        var clip:Dictionary={}
        if component.get("native_spell",false) and component.get("status")!="missing":
            clip=Effects.occurrence_clip(component)
        elif component.get("kind")=="material_flash" and component.get("native_hit",{}).get("definition",{}).get("status")=="available":
            clip=component.native_hit.get("clip",{}).duplicate(false)
        # An item source is hidden until its exact current holder packet is
        # supplied by the production renderer. An unbound private draw cannot
        # qualify its pipeline, so do not record a false startup witness.
        if component.get("native_item",false):continue
        if clip.is_empty() or (Effects.requires_construction(clip) and not clip.has("construction_inputs")):continue
        var key:String=_key(clip)
        if not by_key.has(key):
            # A condition lifecycle warms with the load: its first draw compiles
            # too much to happen while playing (see requested).
            var item={"key":key,"clip":clip,"intervals":[],"lifecycle":component.has("lifecycle_phases")}
            by_key[key]=item;result.append(item)
        var span=Vector2(float(row.start_ms),float(row.end_ms))
        if span not in by_key[key].intervals:by_key[key].intervals.append(span)
    result.sort_custom(func(a,b):return a.intervals[0].x<b.intervals[0].x)
    return result

static func source_plan(clips:Array,lifecycles:Array=[])->Array:
    var result:Array=[];var seen:Dictionary={}
    for clip in lifecycles+clips:
        if clip.is_empty() or (Effects.requires_construction(clip) and not clip.has("construction_inputs")):continue
        var key:String=_key(clip)
        if seen.has(key):continue
        seen[key]=true;result.append({"key":key,"clip":clip,"lifecycle":clip in lifecycles})
    return result

## Sources due at `at_ms` (within `horizon_ms`). Condition lifecycles are
## always due: they warm before play, never on a later private draw.
static func requested(plan:Array,at_ms:float,horizon_ms:float=0.0)->Array:
    return plan.filter(func(item):return item.get("lifecycle",false) or item.get("intervals",[]).any(func(span):return span.x<=at_ms+horizon_ms and span.y>at_ms))

static func _plan(cache:Dictionary)->Array:
    var result:Array=[];var seen:Dictionary={}
    var index:Resource=Authoring.Sources.admission(cache).index
    if index==null:return result
    var entries:Dictionary=index.spells
    for behavior in entries:
        for clip in Authoring.effect_clips(Authoring.selection(behavior,cache)):
            if Effects.requires_construction(clip):continue
            var identity:String=_key(clip)
            if not seen.has(identity):
                seen[identity]=true;result.append({"key":identity,"clip":clip})
    return result

static func status(request:Dictionary={})->Dictionary:
    var plan:Array=request.get("plan",_state.get("plan",[]))
    var required:Array=request.get("required",plan)
    var done:Dictionary=_state.get("done",{})
    var failures:Dictionary=_state.get("failures",{})
    var errors:Array=[];var pending:int=0;var completed:int=0;var background_errors:Array=[]
    for item in required:
        var key:String=_key(item.clip)
        # A condition lifecycle only warms ahead of need: if it cannot build,
        # loading goes on (its failure stays in background_errors) instead of
        # holding the game on the loading notice.
        if failures.has(key) and item.get("lifecycle",false):continue
        if failures.has(key):errors.append(failures[key])
        if not done.has(key):pending+=1
    for item in plan:
        var key:String=_key(item.clip)
        if done.has(key):completed+=1
        if failures.has(key):background_errors.append(failures[key])
    return {"ready":pending==0 and errors.is_empty(),"errors":errors,"pending":pending,
        "completed":completed,"total":plan.size(),"background_pending":plan.size()-completed,
        "background_errors":background_errors,"required_total":required.size(),
        "elapsed_ms":_state.get("elapsed_ms",0.0) if _state.get("ready",true) else (Time.get_ticks_usec()-_state.started)/1000.0,
        "memory_before":_state.get("memory_before",{}),"memory_after":_state.get("memory_after",{}),
        "pipeline_before":_state.get("pipeline_before",{}),"pipeline_after":_state.get("pipeline_after",{}),
        "construction_ms":_state.get("construction_ms",[]),"resource_worker_ms":_state.get("resource_worker_ms",[]),
        "retained_material_variants":_state.get("material_owners",[]).size()}

static func _drawn(active:Dictionary)->void:active.drawn=true

## Recording-only scalar ownership at the existing frame-context boundary.
static func profile_state()->Dictionary:
    var active:Dictionary=_state.get("active",{})
    var viewport:Variant=_state.get("viewport")
    var viewport_valid:bool=is_instance_valid(viewport)
    return {"active_key":str(active.get("key","")),"settle_frame":int(active.get("settle",-1)),
        "drawn":bool(active.get("drawn",false)),"ages_remaining":active.get("ages",[]).size(),
        "private_viewport_valid":viewport_valid,"private_viewport_update_mode":int(viewport.render_target_update_mode) if viewport_valid else -1,
        "admission_loading_path":Effects.Admission.loading_path,"admission_material_job_active":not Effects.Admission._material_job.is_empty(),
        "admission_settling":Effects.Admission.settling}

static func _materials(material:Material,result:Dictionary)->void:
    if material==null or result.has(material):return
    result[material]=true
    _materials(material.next_pass,result)

static func _retain_program_owners(handle:Dictionary)->void:
    var materials:Dictionary={}
    for piece in handle.geometry:
        _materials(piece.node.material_override,materials)
        _materials(piece.node.material_overlay,materials)
        if piece.node is MeshInstance3D and piece.node.mesh!=null:
            for surface in piece.node.mesh.get_surface_count():_materials(piece.node.get_active_material(surface),materials)
        if piece.node is GPUParticles3D:
            _materials(piece.node.process_material,materials)
            for draw_pass in piece.node.draw_passes:
                var mesh:Mesh=piece.node.get_draw_pass_mesh(draw_pass)
                if mesh!=null:
                    for surface in mesh.get_surface_count():_materials(mesh.surface_get_material(surface),materials)
    for material in materials:
        # Keep each sampled native feature variant alive after disposing its
        # nodes. A shallow material copy owns its mutable fields, sharing only
        # the unchanged program/textures; no live occurrence receives this copy.
        var owner:Material=material.duplicate(false)
        owner.get_rid()
        _state.material_owners.append(owner)

static func _owner(world:Node3D)->Node3D:
    var viewport=SubViewport.new()
    viewport.name="NativeSourceStartup"
    viewport.size=Vector2i(64,64);viewport.own_world_3d=true
    viewport.transparent_bg=true;viewport.msaa_3d=Viewport.MSAA_DISABLED
    viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
    world.get_tree().root.add_child(viewport)
    var camera=Camera3D.new();viewport.add_child(camera)
    camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=128
    camera.near=.01;camera.far=2048;camera.cull_mask=SOURCE_LAYER
    camera.basis=Basis.from_euler(Vector3(-atan(sqrt(.5)),PI/4,0));camera.position=camera.basis.z*512
    var environment:Environment=world.get_world_3d().environment
    camera.environment=environment.duplicate() if environment!=null else Environment.new()
    camera.environment.background_mode=Environment.BG_COLOR;camera.environment.background_color=Color.BLACK
    var result=Node3D.new();viewport.add_child(result)
    _state.viewport=viewport
    return result

static func step(world:Node3D,cache:Dictionary,request:Dictionary={},budget:Dictionary={})->Dictionary:
    var started:int=Time.get_ticks_usec()
    var result:Dictionary=_step(world,cache,request,budget)
    if not budget.is_empty():budget.used_usec+=Time.get_ticks_usec()-started
    return result

static func _step(world:Node3D,cache:Dictionary,request:Dictionary,budget:Dictionary)->Dictionary:
    # The ordinary client retains full-catalog startup. Studio explicitly
    # supplies its recorded sources, including an empty plan before admission.
    if request.is_empty():
        request={"plan":_state.get("catalog_plan",[]),"optional":true}
        if request.plan.is_empty():request.plan=_plan(cache)
    if request.plan.is_empty():
        if _state.has("resources"):Effects.retain_source_preparation(_state.resources,[])
        return status(request)
    if _state.is_empty():
        _state={"plan":[],"known":{},"done":{},"failures":{},"resources":{},"completed":0,"active":{},"owner":null,"errors":[],
            "ready":true,"started":Time.get_ticks_usec(),"elapsed_ms":0.0,"construction_ms":[],
            "resource_worker_ms":[],"last_worker_profile":{},"material_owners":[],"memory_before":_memory(),"pipeline_before":Profile.pipeline_compilations()}
    if not request.has("required"):_state.catalog_plan=request.plan
    for item in request.plan:
        # Keys name the playing approach kind; a newly requested kind warms again.
        if not _state.known.has(_key(item.clip)):
            _state.known[_key(item.clip)]=true;_state.plan.append(item);_state.ready=false
            # Every recording in the plan starts loading on a worker now,
            # ahead of the background catalog, not when the warm-up reaches it.
            if Effects.choice(item.clip).kind=="recorded":Baked.request(item.clip,true)
    if _state.ready:return status(request)
    var required:Array=request.get("required",request.plan)
    var optional:bool=request.get("optional",true)
    var eligible:Array=required.duplicate()
    if optional:
        eligible.append_array(request.get("priority",[]))
        eligible.append_array(request.plan)
    # Only the first currently eligible source can advance resource discovery.
    # A changed priority abandons its predecessor even before budget admission.
    var resource_interest:Array=[]
    for candidate in eligible:
        if not _state.done.has(_key(candidate.clip)) and not _state.failures.has(_key(candidate.clip)):
            resource_interest.append(candidate.clip);break
    Effects.retain_source_preparation(_state.resources,resource_interest)
    if eligible.is_empty():return status(request)
    if not budget.is_empty() and budget.used_usec>=budget.limit_usec:return status(request)
    if _frame==Engine.get_process_frames():return status(request)
    # The private viewport exists as soon as there is work, in its own frame,
    # never in the frame of a source's first construction.
    if not is_instance_valid(_state.owner):
        _state.owner=_owner(world);_frame=Engine.get_process_frames()
        return status(request)
    # An optional source may finish its existing draw before a new request;
    # no second mutable source constructor runs alongside it.
    if not _state.active.is_empty():
        if not optional and status(request).ready:return status(request)
        if _state.active.has("settle"):
            # Instancing queued this source's pipeline compiles on worker
            # threads. Its first private draw waits for them a few frames later
            # instead of blocking the frame that constructed it.
            if Engine.get_process_frames()<_state.active.settle:return status(request)
            _state.active.erase("settle")
            _frame=Engine.get_process_frames()
            _state.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
            RenderingServer.frame_post_draw.connect(_drawn.bind(_state.active),CONNECT_ONE_SHOT)
            return status(request)
        if not _state.active.drawn:return status(request)
        _frame=Engine.get_process_frames()
        var retained_started:int=Time.get_ticks_usec()
        _retain_program_owners(_state.active.handle)
        Profile.end_phase(world.profile,"native_startup_retain_programs",retained_started)
        if not _state.active.ages.is_empty():
            var age:float=_state.active.ages.pop_front()
            var sample_started:int=Time.get_ticks_usec()
            Effects.sample(_state.active.handle,age)
            Profile.end_phase(world.profile,"native_startup_sample",sample_started)
            _state.active.drawn=false
            _state.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
            RenderingServer.frame_post_draw.connect(_drawn.bind(_state.active),CONNECT_ONE_SHOT)
            return status(request)
        var close_started:int=Time.get_ticks_usec()
        Effects.close(_state.active.handle)
        Profile.end_phase(world.profile,"native_startup_close",close_started)
        _state.done[_state.active.key]=true
        _state.active={};_state.completed+=1
    var item:Dictionary={}
    for candidate in eligible:
        if not _state.done.has(_key(candidate.clip)) and not _state.failures.has(_key(candidate.clip)):item=candidate;break
    if item.is_empty():
        if _state.plan.all(func(entry):return _state.done.has(_key(entry.clip))):
            if is_instance_valid(_state.get("viewport")):_state.viewport.free()
            _state.owner=null;_state.ready=true
            _state.elapsed_ms=(Time.get_ticks_usec()-_state.started)/1000.0
            _state.memory_after=_memory();_state.pipeline_after=Profile.pipeline_compilations()
        return status(request)
    _frame=Engine.get_process_frames()
    # A recording is one file loaded on a worker; a live approach loads its
    # files and compiles its warm materials on workers. Its private warm draw
    # then compiles the pipelines it draws with, ahead of play.
    var item_key:String=_key(item.clip)
    var resources_started:int=Time.get_ticks_usec()
    var loaded:Dictionary=Effects.prepare([item.clip],_state.resources,required.any(func(entry):return _key(entry.clip)==item_key))
    Profile.end_phase(world.profile,"native_startup_resources",resources_started)
    var worker:Dictionary=Effects.Admission.material_profile
    if not is_same(worker,_state.last_worker_profile):
        _state.last_worker_profile=worker
        if not worker.is_empty():_state.resource_worker_ms.append(worker.worker_ms)
    if not loaded.errors.is_empty():
        _state.failures[item_key]="; ".join(loaded.errors)
        return status(request)
    if not loaded.ready:return status(request)
    if not is_instance_valid(_state.owner):_state.owner=_owner(world)
    var construct_started:int=Time.get_ticks_usec()
    var handle:Dictionary=Effects.make(_state.owner,item.clip.duplicate(false),SOURCE_LAYER)
    Profile.end_phase(world.profile,"native_startup_construct",construct_started)
    _state.construction_ms.append({"source":item.clip.id,"kind":handle.get("effect_kind",""),"ms":(Time.get_ticks_usec()-construct_started)/1000.0,"phases":handle.get("construction_phases",{})})
    if not handle.error.is_empty():
        _state.failures[item_key]=handle.error;Effects.close(handle)
        return status(request)
    # Private native draws admit lazy source pipelines. Actual occurrence
    # transforms, clocks, materials and renderer readiness remain independent.
    handle.root.scale=Vector3.ONE*.18
    for node in handle.root.find_children("*","",true,false):
        if node is Node3D and not node is VisualInstance3D:node.show()
    for piece in handle.geometry:
        if piece.layer_enabled:piece.node.show()
    handle.root.show()
    var ages:Array=[]
    for age in [.2,.7]:
        var bounded:float=minf(age,maxf(0.0,float(item.clip.get("seconds",age))))
        if bounded>0 and bounded not in ages:ages.append(bounded)
    _state.active={"key":item_key,"handle":handle,"drawn":false,"ages":ages,"settle":Engine.get_process_frames()+SETTLE_FRAMES}
    return status(request)

static func reset()->void:
    # Explicit source reload only. Seeking or replacing a Play host does not
    # release the process-owned native program prototypes.
    if not _state.is_empty():
        Effects.Admission.cancel_source_cache(_state.resources)
        if not _state.active.is_empty():Effects.close(_state.active.handle)
        if is_instance_valid(_state.get("viewport")):_state.viewport.free()
    _state={};_frame=-1
