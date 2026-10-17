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
const Baked=preload("res://presentation/baked_effect.gd")
const FIRST_BIT=1
const LAST_BIT=12
const HISTORY_STEP=1.0/60.0
var handles:Dictionary={}
var groups:Dictionary={}
var spare_layers:Array=[]
var prepared_layers:Dictionary={}
var diagnostics:Dictionary={}
var ready:bool=true
var preparation_revision:int=0
var issues:Array=[]
var witnesses:Array=[]
var required_images:Dictionary={}
var required_cpu_images:Dictionary={}
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
var _support_warm:bool=false

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

func prepare(compiled_groups:Array,cache:Dictionary,world:Node=null,prefetch_groups:Array=[],budget:Dictionary={},allow_optional:bool=true,optical_groups:Array=[])->Dictionary:
    var admission_started:int=Time.get_ticks_usec();var charged_before:int=budget.get("used_usec",0)
    var wanted:Dictionary={};var optional:Dictionary={};var clips:Array=[]
    for pair in [[compiled_groups,wanted],[prefetch_groups,optional]]:
        for group in pair[0]:
            for component in group.get("components",[]):
                if not accepts(component) or component.get("status")=="missing":continue
                pair[1][component.id]=component
    # A baked clip loads as one file on a worker; only native clips admit.
    var baked_pending:int=0
    for id in wanted:
        optional.erase(id)
        if handles.has(id):continue
        var bundle:Variant=Baked.ready_for(wanted[id].native_clip,0,true)
        if bundle==null:baked_pending+=1
        elif not bundle is Resource:clips.append(wanted[id].native_clip)
    var optical:Dictionary=wanted
    if not optical_groups.is_empty():
        optical={}
        for group in optical_groups:
            for component in group.get("components",[]):
                if accepts(component) and component.get("status")!="missing":optical[component.id]=component
    _required_ids=optical
    var started:int=Time.get_ticks_usec()
    var result:Dictionary
    if not clips.is_empty() and not budget.is_empty() and budget.used_usec>=budget.limit_usec:
        Factory.Admission.can_mutate() # Completion polling never constructs a source.
        result={"ready":false,"pending":clips.size(),"errors":[]}
    else:result=Factory.prepare(clips,_resource_cache)
    if not budget.is_empty():budget.used_usec+=Time.get_ticks_usec()-started
    if baked_pending>0:result.ready=false;result.pending+=baked_pending
    if world!=null:FrameProfile.end_phase(world.profile,"native_prepare_resources",started)
    if world==null:
        if not budget.is_empty():budget.used_usec+=maxi(0,Time.get_ticks_usec()-admission_started-(budget.used_usec-charged_before))
        return result
    _ensure(world)
    if not budget.is_empty():budget.used_usec+=maxi(0,Time.get_ticks_usec()-admission_started-(budget.used_usec-charged_before))
    # Epoch reset owns all resources/instances, including required-image pins.
    _required_ids=optical
    var appearance:Dictionary=_prepare_layers(world,wanted,budget,optional,allow_optional)
    _warm_passes()
    result.ready=result.ready and appearance.ready
    result.errors.append_array(appearance.errors)
    # Receiver membership is prepared before any effect can become due. Sync
    # only samples published transforms/materials; it never constructs proxies.
    var receivers:Dictionary={"ready":true,"pending":0}
    var receivers_started:int=Time.get_ticks_usec()
    if not wanted.is_empty() or not groups.is_empty():
        receivers=_support.prepare_membership(world.static_entries,world.visual_actors,budget)
    elif budget.is_empty() or budget.used_usec<budget.limit_usec:
        _support.prepare_membership(world.static_entries,world.visual_actors,budget)
    FrameProfile.end_phase(world.profile,"native_prepare_receivers",receivers_started)
    result.ready=result.ready and receivers.ready
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
    var prepared_optics:bool=world.source_lighting.prepare_native_handles(handles,budget)
    var support_images:Dictionary=_support.adopt(world) if not wanted.is_empty() or not groups.is_empty() else {"ready":true}
    result.ready=result.ready and result.pending==0 and result.errors.is_empty() and appearance.ready and receivers.ready and prepared_optics and support_images.ready
    if allow_optional and result.ready:
        for id in optional:
            if handles.has(id) or _prepare_failures.has(id):continue
            if not budget.is_empty() and budget.used_usec>=budget.limit_usec:break
            started=Time.get_ticks_usec()
            var bundle:Variant=Baked.ready_for(optional[id].native_clip)
            if bundle==null:continue
            if not bundle is Resource:
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
    # Footprint resources belong to the received cut, not per-frame sampling.
    # Keep each accepted shape even when several cuts share an occurrence ID.
    var mask_interests:Dictionary={}
    for pair in [[compiled_groups,true],[prefetch_groups,false]]:
        for group in pair[0]:
            for component in group.get("components",[]):
                if not accepts(component) or not component.get("spatial_owner",false) or component.get("status")=="missing":continue
                var positions:Array=component.get("resolved_area_positions",[])
                if not mask_interests.has(component.id):mask_interests[component.id]=[]
                if positions not in mask_interests[component.id]:mask_interests[component.id].append(positions)
                if not handles.has(component.id):continue
                var handle:Dictionary=handles[component.id]
                if AreaMask.prepared(handle,positions):continue
                if not budget.is_empty() and budget.used_usec>=budget.limit_usec:
                    if pair[1]:result.ready=false;result.pending+=1
                    continue
                started=Time.get_ticks_usec()
                var mask:Dictionary=AreaMask.prepare(handle,positions)
                if not budget.is_empty():budget.used_usec+=Time.get_ticks_usec()-started
                FrameProfile.end_phase(world.profile,"native_prepare_area",started)
                if pair[1] and not mask.ready:result.ready=false;result.errors.append_array(mask.errors)
    for id in handles:AreaMask.retain(handles[id],mask_interests.get(id,[]))
    started=Time.get_ticks_usec()
    _image_requirements(world)
    FrameProfile.end_phase(world.profile,"native_prepare_images",started)
    if not budget.is_empty():budget.used_usec+=maxi(0,Time.get_ticks_usec()-admission_started-(budget.used_usec-charged_before))
    return result

func _construct(component:Dictionary)->String:
    var clip:Dictionary=component.native_clip.duplicate(false)
    if component.native_cue.has("opacity_uniform"):clip.opacity_uniform=component.native_cue.opacity_uniform
    var seed:int=Components.effect_seed(component)
    var bundle:Variant=Baked.ready_for(clip,seed)
    var handle=Baked.make(_owner,bundle,clip,0) if bundle is Resource else Factory.make(_owner,clip,0)
    # Factory already measures its constructor stages. Preserve that breakdown
    # in the live frame profile so an indivisible construction overrun is
    # attributable without adding another set of timers around its internals.
    var frame_phases:Dictionary=_owner.get_parent().profile.phases
    for phase in handle.get("construction_phases",{}):
        var name:String="native_construct_"+str(phase)
        frame_phases[name]=frame_phases.get(name,0.0)+handle.construction_phases[phase]
    if not handle.error.is_empty():
        var error:String=handle.error;_prepare_failures[component.id]=error;Factory.close(handle);return error
    for index in handle.emitters.size():
        handle.emitters[index].use_fixed_seed=true;handle.emitters[index].seed=seed+index
    handle.component=component;handle.sample_time=0.0;handle.requested_time=-1.0;handle.drawn_time=-1.0
    handle.group_key="";handle.started=false;handle.rendered_once=false;handle.warming=false;handle.endpoint_views={}
    handle.optical=_optical(component.get("optical",{}))
    handle.support_y=float(component.get("to_elevation_feet",0.0))/5.0*Sockets.Placement.HEIGHT_UNIT
    handles[component.id]=handle
    return ""

func _prepare_layers(world:Node,wanted:Dictionary,budget:Dictionary,optional:Dictionary={},allow_optional:bool=false)->Dictionary:
    var profiles:Dictionary={};var required:Dictionary={}
    for component in wanted.values():
        var key:String=_profile_key(component.get("finish_profile",{}))
        profiles[key]=component.get("finish_profile",{});required[key]=true
    for component in optional.values():
        var key:String=_profile_key(component.get("finish_profile",{}))
        if not profiles.has(key):profiles[key]=component.get("finish_profile",{})
    # Required profiles retain first claim on finite appearance passes. Future
    # accepted profiles may warm privately; they never block a current cue.
    for key in prepared_layers.keys():
        if profiles.has(key):continue
        spare_layers.append(prepared_layers[key]);prepared_layers.erase(key)
    var result:Dictionary={"ready":true,"pending":0,"errors":[]}
    for key in profiles:
        if groups.has(key) or prepared_layers.has(key):continue
        var needed:bool=required.has(key)
        if not needed and not allow_optional:continue
        if not budget.is_empty() and budget.used_usec>=budget.limit_usec:
            if needed:result.ready=false;result.pending+=1
            continue
        var started:int=Time.get_ticks_usec()
        var layer:Dictionary
        if spare_layers.is_empty():
            var bit:int=_free_bit()
            if bit<0:
                if needed:
                    result.ready=false;result.errors.append("Native spell appearance capacity exceeded by simultaneously required profiles")
                continue
            layer=Layer.make(world,1<<bit);layer.bit=bit;Layer.integrate(layer,_support)
        else:layer=spare_layers.pop_back();Layer.sync(layer,world)
        Layer.colours(layer,profiles[key],true);Layer.set_enabled(layer,false)
        prepared_layers[key]=layer
        if not budget.is_empty():budget.used_usec+=Time.get_ticks_usec()-started
        FrameProfile.end_phase(world.profile,"native_prepare_appearance",started)
    return result

## Passes not in use render once ahead of any spell (Layer.warm), and the
## shared receiver pass allocates its targets with one empty render.
func _warm_passes()->void:
    if not groups.is_empty():return
    for layer in spare_layers+prepared_layers.values():Layer.warm(layer)
    if _support!=null and not _support.enabled and not _support_warm:
        _support.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;_support_warm=true

func sample(world:Node,components:Array,frame_seconds:float)->void:
    var sample_started:int=Time.get_ticks_usec()
    ready=true;issues.clear();witnesses.clear()
    if not is_instance_valid(_owner) or _epoch!=world.timeline.initialization_revision:
        for component in components:
            if accepts(component):ready=false;_pending(component,"native_spell_owner_not_prepared")
        return
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
    # Publication activates prepared private passes. Recolouring/material and
    # viewport construction happen only in prepare, never at the first sample.
    for key in groups.keys():
        if not group_profiles.has(key):
            Layer.set_enabled(groups[key],false)
            prepared_layers[key]=groups[key];groups.erase(key)
    for key in group_profiles:
        if groups.has(key):continue
        if not prepared_layers.has(key):continue
        var layer:Dictionary=prepared_layers[key];prepared_layers.erase(key)
        Layer.set_enabled(layer,true);groups[key]=layer
    if _support!=null:_support.set_enabled(not groups.is_empty())
    FrameProfile.end_phase(world.profile,"native_sample_groups",sample_phase)
    sample_phase=Time.get_ticks_usec()
    var retained=_queued_ids(world)
    for id in active:retained[id]=true
    for id in handles.keys():
        if not retained.has(id):Factory.close(handles[id]);handles.erase(id);diagnostics.erase(id);preparation_revision+=1
        elif not active.has(id):handles[id].root.hide()
    FrameProfile.end_phase(world.profile,"native_sample_retention",sample_phase)
    sample_phase=Time.get_ticks_usec()
    for id in active:
        var component:Dictionary=active[id]
        if component.get("status")=="missing":continue
        var key=_profile_key(component.get("finish_profile",{}))
        if not groups.has(key):ready=false;_pending(component,"native_spell_appearance_not_prepared");continue
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
        if age+0.000001<float(handle.sample_time) and not handle.get("baked",false):
            # Normal replay seeks use a fresh presentation epoch. An explicit
            # backwards sample still clears its own particles/trails honestly.
            Factory.close(handle);handles.erase(id);preparation_revision+=1
            ready=false;_pending(component,"native_spell_source_reset_pending");continue
        Factory.set_layer(handle,int(groups[key].layer_mask))
        handle.group_key=key
        handle.optical=_optical(component.get("optical",{}))
        if component.get("spatial_owner",false):
            var mask=AreaMask.publish(handle,component.get("resolved_area_positions",[]))
            if not mask.ready:
                handle.root.hide();ready=false;_missing(component,"; ".join(mask.errors));continue
        # The bounded pass is only for a cold/seek history. Ordinary live
        # samples must follow the requested component clock at any frame rate.
        var expected_step:float=maxf(HISTORY_STEP,frame_seconds*maxf(1.0,float(world.playback_speed)))
        # A baked clip draws any age directly; only a simulation has history.
        if handle.get("baked",false):handle.warming=false
        elif not handle.started and age>expected_step+0.000001:handle.warming=true
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
        if handle.get("baked",false) and not handle.has("emission_stop_set"):
            Baked.stop_emission(handle,_emission_stop(cue));handle.emission_stop_set=true
        Factory.sample(handle,Playback.source_time(cue,sample_time),native_advance,sample_time-float(cue.launch))
        if cue.has("origin_path"):
            var anchor=handle.root.get_node_or_null(cue.origin_path)
            if anchor==null:
                handle.root.hide();_missing(component,"native_spell_origin_missing");continue
            handle.root.global_position+=Playback.transform(cue,sample_time,points.hand,1.0).origin-anchor.global_position
        Playback.controls(handle,cue,sample_time)
        if handle.get("baked",false) and handle.bundle.moving:
            # Path history for trailing particles and trails: frames a jump
            # skipped use the cue's placement, shifted like the current root.
            var placed:Vector3=Playback.transform(cue,sample_time,points.hand,1.0).origin
            var shift:Vector3=handle.root.global_position-placed
            var hand:Vector3=points.hand
            Baked.follow(handle,cue,sample_time,func(time:float)->Transform3D:return Playback.transform(cue,time,hand,1.0).translated(shift))
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
    if not world.source_lighting.native_preparation_ready:
        ready=false
        for id in active:_pending(active[id],"native_spell_optical_resources_not_prepared")
    FrameProfile.end_phase(world.profile,"native_sample_lights",sample_phase)
    sample_phase=Time.get_ticks_usec()
    _image_requirements(world)
    FrameProfile.end_phase(world.profile,"native_sample_images",sample_phase)
    FrameProfile.end_phase(world.profile,"native_spell_sample",sample_started)

## Source time after which no new particle life starts (Playback.controls
## stops a simulation's emitters at these cue times).
static func _emission_stop(cue:Dictionary)->float:
    var stop:float=INF
    if cue.role=="flight" and cue.get("stop_emission_at_contact",false):
        stop=minf(stop,float(cue.contact) if cue.has("lifecycle") else Playback.source_time(cue,float(cue.contact)))
    if cue.has("emission_stop"):
        stop=minf(stop,float(cue.emission_stop) if cue.has("lifecycle") else Playback.source_time(cue,float(cue.emission_stop)))
    return stop

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

## A rotation prepares its target quarter's floor receivers before it publishes.
func prepare_receivers(static_entries:Array,budget:Dictionary)->bool:
    return _support==null or _support.prepare_floors(static_entries,budget).ready

func prepare_boundary(candidate:Node3D,jobs:Array,state:Dictionary,budget:Dictionary)->bool:
    if groups.is_empty() and _required_ids.is_empty():return true
    return _support==null or _support.prepare_boundary(candidate,jobs,state,budget)

func publish_boundary(state:Dictionary)->void:
    if _support!=null:_support.publish_boundary(state)

func actor_bindings_needed()->bool:
    return _support!=null and (not groups.is_empty() or not _required_ids.is_empty())

func actor_binding_owner()->RefCounted:
    return _support if actor_bindings_needed() else null

func prepare_actor_binding(path:String,slot:String,world:Node)->Dictionary:
    # Reuse the existing optical owner. A future clip contributes only its
    # already-resident solid mask; it creates neither a proxy nor a pose.
    if not actor_bindings_needed():return {"ready":true}
    var paths:Dictionary=Support.required_paths(path,slot,world.catalog_cache)
    if paths.is_empty():return {"ready":true}
    var mask:Texture2D=world.textures.get(paths.solid)
    if mask==null:return {"ready":false,"mask_path":paths.solid}
    return {"ready":true,"owner":_support,"path":path,"mask_path":paths.solid,"mask":mask}

func publish_actor_binding(value:Dictionary)->void:
    if value.has("mask") and is_same(value.owner,_support):_support.solid_masks[value.path]=value.mask

func sync(world:Node)->void:
    if _support==null:return
    if groups.is_empty():return
    var started:int=Time.get_ticks_usec()
    _support.sync(world.static_entries,world.visual_actors,world.camera)
    if not _support.ready:
        ready=false
        for issue in _support.issues:
            if issue not in issues:issues.append(issue)
    FrameProfile.end_phase(world.profile,"native_support_sync",started)
    for phase in ["camera","floor","actors","retirement"]:
        var name:String="native_support_"+str(phase)
        world.profile.phases[name]=world.profile.phases.get(name,0.0)+_support.last_sync_phases[phase]
    started=Time.get_ticks_usec()
    for layer in groups.values():Layer.sync(layer,world)
    FrameProfile.end_phase(world.profile,"native_pass_sync",started)

func _free_bit()->int:
    for bit in range(FIRST_BIT,LAST_BIT+1):
        var used=false
        for layer in groups.values():
            if layer.bit==bit:used=true;break
        if not used:
            for layer in prepared_layers.values():
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
    handles.clear();diagnostics.clear();witnesses.clear();issues.clear();required_images.clear();required_cpu_images.clear()
    for layer in groups.values():Layer.close(layer)
    for layer in spare_layers:Layer.close(layer)
    for layer in prepared_layers.values():Layer.close(layer)
    groups.clear();spare_layers.clear();prepared_layers.clear()
    if _support!=null:_support.close();_support=null
    _support_warm=false
    if is_instance_valid(_owner):_owner.free()
    _owner=null
    if world!=null and is_instance_valid(world.camera) and _epoch>=0:
        world.camera.cull_mask=_camera_mask
        world.source_lighting.sample_handles({})
    _image_key=[];_path_requirements.clear();_queued_key=[];_queued_cache.clear()
    _epoch=-1;ready=true;_required_ids.clear();_prepare_failures.clear();preparation_revision+=1

func _image_requirements(world:Node)->void:
    # Optical inputs depend on outfit paths and selected clips, not every source
    # occurrence. Gather each actor/clip once before resolving delivery metadata.
    var actor_clips:Dictionary={}
    for handle_id in _required_ids:
        var component:Dictionary=_required_ids[handle_id]
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
    for input in inputs:key.append([input[0],input[1],inputs[input],Support.socket_samples_ready(input[0],input[1],world.catalog_cache)])
    if key==_image_key:return
    _image_key=key
    var wanted:Dictionary={}
    var cpu:Dictionary={}
    for input in inputs:
        if not _path_requirements.has(input):_path_requirements[input]=Support.required_paths(input[0],input[1],world.catalog_cache)
        var paths:Dictionary=_path_requirements[input]
        if inputs[input]:
            for value in paths.values():wanted[value]=true
            cpu.merge(Support.cpu_required_paths(input[0],input[1],world.catalog_cache))
        elif not paths.is_empty():wanted[paths.solid]=true
    required_images=wanted
    required_cpu_images=cpu
