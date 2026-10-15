extends RefCounted
## Native phases consume the existing component clock. Each world owns its
## instances, receiver depth and appearance passes; no rules or event scheduler.
const AreaMask=preload("res://presentation/native_area_mask.gd")
const FrameProfile=preload("res://frame_profile.gd")
const Factory=preload("res://presentation/native_factory_source.gd")
const Layer=preload("res://presentation/native_effect_layer.gd")
const Support=preload("res://presentation/native_scene_support.gd")
const Playback=preload("res://presentation/native_spell_playback.gd")
const Sockets=preload("res://presentation/spell_placement.gd")
const Components=preload("res://presentation/components.gd")
const FIRST_BIT=1
const LAST_BIT=12
const HISTORY_STEP=1.0/60.0
var handles:Dictionary={}
var groups:Dictionary={}
var spare_layers:Array=[]
var diagnostics:Dictionary={}
var ready:bool=true
var issues:Array=[]
var witnesses:Array=[]
var required_images:Dictionary={}
var _owner:Node3D
var _support:RefCounted
var _epoch:int=-1
var _camera_mask:int=0
var _resource_cache:Dictionary={}
var _image_key:Array=[]
var _path_requirements:Dictionary={}
var _queued_key:Array=[]
var _queued_cache:Dictionary={}
var _required_ids:Dictionary={}
var _prepare_failures:Dictionary={}

func render_timings()->Dictionary:
    # Last completed native viewport timestamps can lag the sampled CPU frame.
    # Keep these separate from the root viewport and the Canvas light atlas.
    var passes:Array=[]
    for group in groups.values():
        var rid:RID=group.viewport.get_viewport_rid()
        passes.append({"layer":group.layer_mask,"cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(rid),
            "gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(rid)})
    var support:Dictionary={}
    if _support!=null and is_instance_valid(_support.viewport) and _support.enabled:
        var rid:RID=_support.viewport.get_viewport_rid()
        support={"cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(rid),
            "gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(rid)}
    return {"passes":passes,"support":support}

static func accepts(component:Dictionary)->bool:
    return component.get("kind")=="native_effect" and component.get("native_spell",false)

func _ensure(world:Node)->void:
    if _epoch!=world.timeline.initialization_revision:
        close(world)
        _epoch=world.timeline.initialization_revision
    if not is_instance_valid(_owner):
        _owner=Node3D.new();_owner.name="NativeSpellInstances";world.add_child(_owner)
        _camera_mask=world.camera.cull_mask
        # Hide every reserved spell/depth layer from the player's ordinary pass.
        var mask:int=Support.LAYER|Support.DEPTH_LAYER
        for bit in range(FIRST_BIT,LAST_BIT+1):mask|=1<<bit
        world.camera.cull_mask &= ~mask
        # The shared renderer exists before interactive playback, like the
        # ordinary light atlas. Its first allocation must not happen on impact.
        _support=Support.new();_support.attach_shared(world)
        _support.set_enabled(false)
        var layer=Layer.make(world,1<<FIRST_BIT);layer.bit=FIRST_BIT
        Layer.integrate(layer,_support)
        Layer.colours(layer,{},false)
        Layer.set_enabled(layer,false)
        spare_layers.append(layer)

func prepare(compiled_groups:Array,cache:Dictionary,world:Node=null,prefetch_groups:Array=[],budget:Dictionary={},allow_optional:bool=true)->Dictionary:
    var admission_started:int=Time.get_ticks_usec();var charged_before:int=budget.get("used_usec",0)
    var wanted:Dictionary={};var optional:Dictionary={};var clips:Array=[]
    for pair in [[compiled_groups,wanted],[prefetch_groups,optional]]:
        for group in pair[0]:
            for component in group.get("components",[]):
                if not accepts(component) or component.get("status")=="missing":continue
                pair[1][component.id]=component
    for id in wanted:
        optional.erase(id)
        if not handles.has(id):clips.append(wanted[id].native_clip)
    _required_ids=wanted
    var started:int=Time.get_ticks_usec()
    var result:Dictionary
    if not clips.is_empty() and not budget.is_empty() and budget.used_usec>=budget.limit_usec:
        Factory.Admission.can_mutate() # Completion polling never constructs a source.
        result={"ready":false,"pending":clips.size(),"errors":[]}
    else:result=Factory.prepare(clips,_resource_cache)
    if not budget.is_empty():budget.used_usec+=Time.get_ticks_usec()-started
    if world!=null:FrameProfile.end_phase(world.profile,"native_prepare_resources",started)
    if world==null:
        if not budget.is_empty():budget.used_usec+=maxi(0,Time.get_ticks_usec()-admission_started-(budget.used_usec-charged_before))
        return result
    _ensure(world)
    if not budget.is_empty():budget.used_usec+=maxi(0,Time.get_ticks_usec()-admission_started-(budget.used_usec-charged_before))
    # Epoch reset owns all resources/instances, including required-image pins.
    _required_ids=wanted
    if result.ready:
        for id in wanted:
            if handles.has(id):continue
            if _prepare_failures.has(id):result.errors.append(_prepare_failures[id]);continue
            if not budget.is_empty() and budget.used_usec>=budget.limit_usec:continue
            started=Time.get_ticks_usec()
            var error=_construct(wanted[id])
            if not budget.is_empty():budget.used_usec+=Time.get_ticks_usec()-started
            FrameProfile.end_phase(world.profile,"native_prepare_construct",started)
            if not error.is_empty():result.errors.append(error)
    result.pending=wanted.keys().filter(func(id):return not handles.has(id)).size()
    result.ready=result.ready and result.pending==0 and result.errors.is_empty()
    if allow_optional and result.ready:
        for id in optional:
            if handles.has(id) or _prepare_failures.has(id):continue
            if not budget.is_empty() and budget.used_usec>=budget.limit_usec:break
            started=Time.get_ticks_usec()
            var loading=Factory.prepare([optional[id].native_clip],_resource_cache)
            if not budget.is_empty():budget.used_usec+=Time.get_ticks_usec()-started
            FrameProfile.end_phase(world.profile,"native_prepare_resources",started)
            if not loading.errors.is_empty():_prepare_failures[id]=str(loading.errors);continue
            if not loading.ready:continue
            if not budget.is_empty() and budget.used_usec>=budget.limit_usec:break
            started=Time.get_ticks_usec()
            _construct(optional[id])
            if not budget.is_empty():budget.used_usec+=Time.get_ticks_usec()-started
            FrameProfile.end_phase(world.profile,"native_prepare_construct",started)
    started=Time.get_ticks_usec()
    _image_requirements(world)
    FrameProfile.end_phase(world.profile,"native_prepare_images",started)
    if not budget.is_empty():budget.used_usec+=maxi(0,Time.get_ticks_usec()-admission_started-(budget.used_usec-charged_before))
    return result

func _construct(component:Dictionary)->String:
    var clip:Dictionary=component.native_clip.duplicate(true)
    if component.native_cue.has("opacity_uniform"):clip.opacity_uniform=component.native_cue.opacity_uniform
    var handle=Factory.make(_owner,clip,0)
    if not handle.error.is_empty():
        var error:String=handle.error;_prepare_failures[component.id]=error;Factory.close(handle);return error
    var seed:int=Components.effect_seed(component)
    for index in handle.emitters.size():
        handle.emitters[index].use_fixed_seed=true;handle.emitters[index].seed=seed+index
    handle.component=component;handle.sample_time=0.0;handle.requested_time=-1.0;handle.drawn_time=-1.0
    handle.group_key="";handle.started=false;handle.rendered_once=false;handle.warming=false;handle.endpoint_views={}
    handle.optical=_optical(component.get("optical",{}))
    handle.support_y=float(component.get("to_elevation_feet",0.0))/5.0*Sockets.Placement.HEIGHT_UNIT
    handles[component.id]=handle
    return ""

func sample(world:Node,components:Array,frame_seconds:float)->void:
    var sample_started:int=Time.get_ticks_usec()
    _ensure(world)
    ready=true;issues.clear();witnesses.clear()
    var frustum:Array[Plane]=world.camera.get_frustum()
    FrameProfile.end_phase(world.profile,"native_sample_setup",sample_started)
    var sample_phase:int=Time.get_ticks_usec()
    var active:Dictionary={}
    var group_profiles:Dictionary={}
    for component in components:
        if not accepts(component):continue
        active[component.id]=component
        if component.get("status")=="missing":
            _missing(component,component.get("reason","native_spell_source_missing"));continue
        group_profiles[_profile_key(component.get("finish_profile",{}))]=component.get("finish_profile",{})
    # Retire obsolete appearance passes before assigning their finite layer bits.
    for key in groups.keys():
        if not group_profiles.has(key):
            Layer.set_enabled(groups[key],false)
            spare_layers.append(groups[key]);groups.erase(key)
    for key in group_profiles:
        if groups.has(key):continue
        if _support==null:
            _support=Support.new();_support.attach_shared(world)
        var layer:Dictionary
        if spare_layers.is_empty():
            var bit=_free_bit()
            if bit<0:continue
            layer=Layer.make(world,1<<bit);layer.bit=bit
            Layer.integrate(layer,_support)
        else:
            layer=spare_layers.pop_back()
            Layer.sync(layer,world)
        Layer.colours(layer,group_profiles[key],true)
        Layer.set_enabled(layer,true)
        groups[key]=layer
    if _support!=null:_support.set_enabled(not groups.is_empty())
    FrameProfile.end_phase(world.profile,"native_sample_groups",sample_phase)
    sample_phase=Time.get_ticks_usec()
    var retained=_queued_ids(world)
    for id in active:retained[id]=true
    for id in handles.keys():
        if not retained.has(id):Factory.close(handles[id]);handles.erase(id);diagnostics.erase(id)
        elif not active.has(id):handles[id].root.hide()
    FrameProfile.end_phase(world.profile,"native_sample_retention",sample_phase)
    sample_phase=Time.get_ticks_usec()
    for id in active:
        var component:Dictionary=active[id]
        if component.get("status")=="missing":continue
        var key=_profile_key(component.get("finish_profile",{}))
        if not groups.has(key):_missing(component,"native_spell_appearance_capacity");continue
        if not handles.has(id):
            ready=false;_pending(component,"native_spell_source_not_prepared");continue
        var handle:Dictionary=handles[id]
        handle.component=component
        var cue:Dictionary=component.native_cue.duplicate(false)
        var age:float=maxf(0,float(component.age_ms)/1000.0)
        var points=Sockets.endpoints(world,component,handle.endpoint_views.get(world.quarter,{}),age<float(cue.launch))
        if not points.ready:
            handle.root.hide()
            if points.get("unavailable",false):_pending(component,points.reason)
            elif points.get("pending",false):ready=false;_pending(component,points.reason)
            else:_missing(component,points.reason)
            continue
        handle.endpoint_views[world.quarter]=points.fixed
        handle.endpoints=points
        cue.merge({"from":points.from,"to":points.to,"ground":points.ground,"caster_ground":points.caster_ground},true)
        if not cue.get("bend",Vector2.ZERO) is Vector2:
            cue.bend=Vector2(cue.bend[0],cue.bend[1])
        if age+0.000001<float(handle.sample_time):
            # Normal replay seeks use a fresh presentation epoch. An explicit
            # backwards sample still clears its own particles/trails honestly.
            Factory.close(handle);handles.erase(id)
            ready=false;_pending(component,"native_spell_source_reset_pending");continue
        Factory.set_layer(handle,int(groups[key].layer_mask))
        handle.group_key=key
        handle.optical=_optical(component.get("optical",{}))
        if component.get("spatial_owner",false):
            var mask=AreaMask.update(handle,component.get("resolved_area_positions",[]))
            if not mask.ready:
                handle.root.hide();_missing(component,"; ".join(mask.errors));continue
        # The bounded pass is only for a cold/seek history. Ordinary live
        # samples must follow the requested component clock at any frame rate.
        var expected_step:float=maxf(HISTORY_STEP,frame_seconds*maxf(1.0,float(world.playback_speed)))
        if not handle.started and age>expected_step+0.000001:handle.warming=true
        elif handle.started and not handle.warming and age-float(handle.requested_time)>expected_step*2.0+0.000001:handle.warming=true
        var sample_time:float=minf(age,float(handle.sample_time)+maxf(HISTORY_STEP,expected_step*2.0)) if handle.warming else age
        if component.get("persistent_owner",false) and float(handle.sample_time)>=float(component.lifecycle.get("enter_end_seconds",0)):
            # Once the authored opening is reconstructed, a held pose has no
            # unbounded visual history. Jump to the actual owner age/close.
            sample_time=age
        handle.root.show()
        handle.root.global_transform=Playback.transform(cue,sample_time,points.hand,1.0)
        Factory.view(handle,world.camera)
        var native_advance:float=frame_seconds if frame_seconds>0 else _owner.get_process_delta_time() if handle.warming else 0.0
        Factory.sample(handle,Playback.source_time(cue,sample_time),native_advance,sample_time-float(cue.launch))
        if cue.has("origin_path"):
            var anchor=handle.root.get_node_or_null(cue.origin_path)
            if anchor==null:
                handle.root.hide();_missing(component,"native_spell_origin_missing");continue
            handle.root.global_position+=Playback.transform(cue,sample_time,points.hand,1.0).origin-anchor.global_position
        Playback.controls(handle,cue,sample_time)
        handle.sample_time=sample_time;handle.requested_time=age;handle.started=true
        handle.attachment_support=points.surfaces
        handle.cue=cue
        handle.support_y=lerpf(points.caster_ground.y,points.ground.y,clampf((sample_time-float(cue.launch))/maxf(.001,float(cue.contact)-float(cue.launch)),0,1)) if cue.role=="flight" else points.caster_ground.y if cue.role=="cast" else points.ground.y
        var caught_up:bool=is_equal_approx(sample_time,age)
        if caught_up:handle.warming=false
        var drawn:bool=handle.rendered_once
        var submitted_bounds:bool=submitted_geometry(handle,frustum,int(groups[key].layer_mask))
        diagnostics[id]={"id":id,"status":"rendered" if drawn else "prepared", "reason":"" if caught_up else "native_spell_history_preparing", "age_ms":sample_time*1000.0,"requested_age_ms":age*1000.0,"source_age":handle.age,"group":key,"layer":groups[key].layer_mask,"attachment_support":points.surfaces,"submitted_bounds":submitted_bounds}
        if not caught_up:ready=false
        if drawn and caught_up and submitted_bounds:witnesses.append({"id":id,"source_event_uuid":component.get("source_event_uuid",""),"status":"rendered","age_ms":float(handle.drawn_time)*1000.0,"frame":handle.get("drawn_frame",Engine.get_process_frames())})
        if float(handle.drawn_time)!=sample_time:
            var sampled_root:WeakRef=weakref(handle.root)
            RenderingServer.frame_post_draw.connect(func():
                var submitted:Node3D=sampled_root.get_ref()
                if submitted!=null and handles.has(id) and handles[id].root==submitted:
                    handles[id].drawn_time=sample_time
                    if caught_up:
                        handles[id].rendered_once=true
                        handles[id].drawn_frame=Engine.get_process_frames(),CONNECT_ONE_SHOT)
    FrameProfile.end_phase(world.profile,"native_sample_sources",sample_phase)
    sample_phase=Time.get_ticks_usec()
    # The existing native2D atlas owns all room/effect light accumulation.
    var light_handles:Dictionary={}
    for id in active:
        if handles.has(id) and handles[id].root.is_visible_in_tree():light_handles[id]=handles[id]
    world.source_lighting.sample_handles(light_handles)
    FrameProfile.end_phase(world.profile,"native_sample_lights",sample_phase)
    sample_phase=Time.get_ticks_usec()
    _image_requirements(world)
    FrameProfile.end_phase(world.profile,"native_sample_images",sample_phase)
    FrameProfile.end_phase(world.profile,"native_spell_sample",sample_started)

static func submitted_geometry(handle:Dictionary,frustum:Array[Plane],layer_mask:int)->bool:
    # Conservative submission evidence, matching ordinary component bounds:
    # this does not prove nonzero fragments or visibility through occluders.
    for piece in handle.geometry:
        var node:GeometryInstance3D=piece.node
        if not is_instance_valid(node) or not node.is_visible_in_tree() or (node.layers&layer_mask)==0:continue
        var bounds:AABB=node.custom_aabb
        if bounds==AABB():
            # GPUParticles3D.get_aabb() is empty; its authored visibility bounds
            # cover particles still alive after emission has stopped as well.
            bounds=node.visibility_aabb if node is GPUParticles3D else node.get_aabb()
        if bounds.size.is_zero_approx():continue
        bounds=node.global_transform*bounds.grow(node.extra_cull_margin)
        var center:Vector3=bounds.get_center()
        var half:Vector3=bounds.size*.5
        var intersects:bool=true
        for plane in frustum:
            # Reject only when the entire box is outside a plane. A large
            # effect can cross the frustum with none of its corners inside.
            if plane.distance_to(center)>plane.normal.abs().dot(half):
                intersects=false;break
        if intersects:return true
    return false

func sync(world:Node)->void:
    if _support==null:return
    if groups.is_empty():
        var preparation_started:int=Time.get_ticks_usec()
        _support.prepare_hidden(world.static_entries,world.visual_actors)
        FrameProfile.end_phase(world.profile,"native_support_prepare",preparation_started)
        return
    var started:int=Time.get_ticks_usec()
    var adoption=_support.adopt(world)
    FrameProfile.end_phase(world.profile,"native_support_adopt",started)
    if not adoption.ready:
        ready=false
        for path in adoption.pending:
            var issue="Native receiver support not prepared: "+str(path)
            if issue not in issues:issues.append(issue)
    started=Time.get_ticks_usec()
    _support.sync(world.static_entries,world.visual_actors,world.camera)
    FrameProfile.end_phase(world.profile,"native_support_sync",started)
    started=Time.get_ticks_usec()
    for layer in groups.values():Layer.sync(layer,world)
    FrameProfile.end_phase(world.profile,"native_pass_sync",started)

func _free_bit()->int:
    for bit in range(FIRST_BIT,LAST_BIT+1):
        var used=false
        for layer in groups.values():
            if layer.bit==bit:used=true;break
        if not used:
            for layer in spare_layers:
                if layer.bit==bit:used=true;break
        if not used:return bit
    return -1

static func _profile_key(profile:Dictionary)->String:
    # Only shader inputs select compatibility; provenance labels do not allocate
    # another render pass, and independent optical settings stay on each handle.
    var parameters:Dictionary=profile.get("parameters",{})
    return var_to_str([profile.get("ramp",[]),parameters.get("ramp_floor",0.0),parameters.get("ramp_ceiling",1.0),parameters.get("ramp_uses_luma",false)])

static func _optical(value:Dictionary)->Dictionary:
    var result=value.duplicate(false)
    if result.has("color") and not result.color is Color:result.color=Color(result.color)
    return result

func _queued_ids(world:Node)->Dictionary:
    # This set only decides which constructed instances may be retired. Before
    # any native instance exists, world commits cannot require a retention scan
    # of every future group and its disclosed condition/area after-values.
    if handles.is_empty():return {}
    var key:Array=[world.timeline.revision,world.timeline.current.get("id",""),world.timeline.queue.size(),world.timeline.condition_owners.keys(),world.timeline.spatial_effect_owners.keys(),handles.keys()]
    if key==_queued_key:return _queued_cache.duplicate()
    _queued_key=key
    var result:Dictionary={}
    var owners:Dictionary={}
    var remaining:Dictionary={}
    for id in handles:
        var component:Dictionary=handles[id].component
        var owner_id:Variant=component.get("condition_uuid",component.get("spatial_effect_uuid"))
        if world.timeline.condition_owners.has(owner_id) or world.timeline.spatial_effect_owners.has(owner_id):
            result[id]=true
            continue
        remaining[id]=true
        if owner_id!=null:
            if not owners.has(owner_id):owners[owner_id]=[]
            owners[owner_id].append(id)
    # Retention only decides the fate of constructed instances. Most are in
    # the current/nearby groups, so stop when each has an actual owner. A stale
    # instance still requires the complete future scan before it may be freed.
    for queued in [[world.timeline.current],world.timeline.queue]:
        for group in queued:
            if remaining.is_empty():break
            for component in group.get("components",[]):
                if remaining.has(component.id) and accepts(component):
                    result[component.id]=true;remaining.erase(component.id)
            if remaining.is_empty():break
            for commit in group.get("commits",[]):
                for actor in commit.delta.get("actors",{}).values():
                    for condition in actor.get("conditions",[]):
                        _retain_owned(condition.condition_uuid,owners,remaining,result)
                for id in commit.delta.get("set",{}).get("senses",{}).get("spatial_effects",{}):
                    _retain_owned(id,owners,remaining,result)
                if remaining.is_empty():break
    _queued_cache=result
    return result.duplicate()

static func _retain_owned(owner_id:Variant,owners:Dictionary,remaining:Dictionary,result:Dictionary)->void:
    if not owners.has(owner_id):return
    for id in owners[owner_id]:
        result[id]=true;remaining.erase(id)
    owners.erase(owner_id)

func _missing(component:Dictionary,reason:String)->void:
    diagnostics[component.id]={"id":component.id,"status":"missing","reason":reason}
    var issue=str(component.id)+": "+reason
    if issue not in issues:issues.append(issue)

func _pending(component:Dictionary,reason:String)->void:
    diagnostics[component.id]={"id":component.id,"status":"pending","reason":reason}

func close(world:Node=null)->void:
    for handle in handles.values():Factory.close(handle)
    handles.clear();diagnostics.clear();witnesses.clear();issues.clear();required_images.clear()
    for layer in groups.values():Layer.close(layer)
    for layer in spare_layers:Layer.close(layer)
    groups.clear();spare_layers.clear()
    if _support!=null:_support.close();_support=null
    if is_instance_valid(_owner):_owner.free()
    _owner=null
    if world!=null and is_instance_valid(world.camera) and _epoch>=0:
        world.camera.cull_mask=_camera_mask
        world.source_lighting.sample_handles({})
    _image_key=[];_path_requirements.clear();_queued_key=[];_queued_cache.clear()
    _epoch=-1;ready=true;_required_ids.clear();_prepare_failures.clear()

func _image_requirements(world:Node)->void:
    # Optical inputs depend on outfit paths and selected clips, not every source
    # occurrence. Gather each actor/clip once before resolving delivery metadata.
    var actor_clips:Dictionary={}
    for handle_id in _required_ids:
        if not handles.has(handle_id):continue
        var component:Dictionary=handles[handle_id].component
        for id in [component.actor_uuid,component.target_uuid]:
            if not actor_clips.has(id):actor_clips[id]={"Idle":true}
            if id==component.actor_uuid:actor_clips[id][component.cast_recipe.get("actionClip","")]=true
            var playback:Node=world.playbacks.get(id)
            if playback!=null:actor_clips[id][playback.clip]=true
    var key:Array=[]
    var inputs:Dictionary={}
    if not _required_ids.is_empty():
        for id in world.visual_actors:
            var visual:Dictionary=world.visual_actors[id]
            for entry in visual.entries:
                if entry.role=="shadow" or not entry.actor_layer.get("effect",{}).is_empty():continue
                var slot:String=entry.actor_layer.slot
                var path:String=entry.get("texture_path","")
                if not path.is_empty():inputs[[path,slot]]=inputs.get([path,slot],false)
                for clip in actor_clips.get(id,{}):
                    path=entry.actor_layer.paths.get(clip,"")
                    if not path.is_empty():inputs[[path,slot]]=true
    for input in inputs:key.append([input[0],input[1],inputs[input]])
    if key==_image_key:return
    _image_key=key
    var wanted:Dictionary={}
    for input in inputs:
        if not _path_requirements.has(input):_path_requirements[input]=Support.required_paths(input[0],input[1],world.catalog_cache)
        var paths:Dictionary=_path_requirements[input]
        if inputs[input]:
            for value in paths.values():wanted[value]=true
        elif not paths.is_empty():wanted[paths.solid]=true
    required_images=wanted
