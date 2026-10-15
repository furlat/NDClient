extends RefCounted
const NativePreview=preload("res://presentation/native_effect_preview.gd")
const Placement=preload("res://placement.gd")
const RegisteredMedia=preload("res://presentation/registered_media.gd")
const MediaShader=preload("res://presentation/registered_media.gdshader")
const AudioPresenter=preload("res://presentation/audio_presenter.gd")
const NativeSources=preload("res://presentation/native_effects.gd")
const Conditions=preload("res://presentation/conditions.gd")
const Components=preload("res://presentation/components.gd")
const ConditionOutline=preload("res://presentation/condition_outline.gd")
const BoltShader=preload("res://presentation/geometry_projectile.gdshader")
const BloodRenderer=preload("res://presentation/blood_renderer.gd")
const NativeSpells=preload("res://presentation/native_spell_renderer.gd")
const NativeHits=preload("res://presentation/native_spell_hits.gd")
const SpellPlacement=preload("res://presentation/spell_placement.gd")
const FrameProfile=preload("res://frame_profile.gd")
const NativeChannels=preload("res://presentation/native_spell_channels.gd")
const NativeAuthoring=preload("res://presentation/native_spell_authoring.gd")
const Choices=preload("res://sdk/choices.gd")
const Catalog=preload("res://source_catalog.gd")
var native_spells=NativeSpells.new()
var native_hits=NativeHits.new()
var blood=BloodRenderer.new()
var outlines=ConditionOutline.new()
var audio=AudioPresenter.new()
var handles: Dictionary={}
var numbers: Dictionary={}
var media_handles: Dictionary={}
var epoch=-1
var ready=true
var readiness:Dictionary={}
var prepared_groups: Dictionary={}
var pending_evidence: Array=[]
var _native_prepare_key:Array=[]
var _native_prepare_groups:Array=[]
var _native_optical_groups:Array=[]
var _native_prepare_components:Array=[]
var _native_prepare_records:Array=[]
const NATIVE_PREFETCH_MS=4000.0
const NATIVE_CONSTRUCTION_USEC=2000
var _native_budget:Dictionary={"frame":-1,"used_usec":0,"limit_usec":NATIVE_CONSTRUCTION_USEC}
var _optional_components:Array=[]
var _optional_blood_groups:Array=[]
var _optional_owner:Array=[]

var _choice_ids:Array=[]
var _choice_job:Dictionary={}
var _choice_resource_cache:Dictionary={}
var choice_preparation:Dictionary={"ready":true,"behaviors":[],"pending":0,"errors":[]}

func request_choice_resources(choices:Dictionary,cache:Dictionary)->void:
    var ids:Array=[]
    for action in Choices.all_actions(choices):
        var id:String=action.get("behavior_id","")
        if not id.is_empty() and id not in ids:ids.append(id)
    ids.sort()
    if ids==_choice_ids:return
    _choice_ids=ids
    if _choice_job.is_empty() or int(_choice_job.get("task",-1))<0:_start_choice_resources(cache)

func _start_choice_resources(cache:Dictionary)->void:
    # Only immutable authoring/metadata crosses this worker boundary. It never
    # receives actor coordinates, constructs nodes, or simulates an outcome.
    _choice_job={"ids":_choice_ids.duplicate(),"cache":Catalog.source_snapshot(cache),"clips":[],"cursor":0,"task":-1}
    _choice_job.task=WorkerThreadPool.add_task(_resolve_choice_resources.bind(_choice_job),false,"Disclosed native spell resources")
    choice_preparation={"ready":false,"behaviors":_choice_ids.duplicate(),"pending":_choice_ids.size(),"errors":[]}

static func _resolve_choice_resources(job:Dictionary)->void:
    var seen:Dictionary={}
    for id in job.ids:
        var selected:Dictionary=NativeAuthoring.selection(id,job.cache)
        for clip in selected.get("clips",[]):
            if not seen.has(clip.id):job.clips.append(clip);seen[clip.id]=true

func prepare_choice_resources(world:Node,admission:Dictionary={})->void:
    var budget:Dictionary=_native_budget if admission.is_empty() else admission
    if _choice_job.is_empty():return
    if _choice_job.task>=0:
        if not WorkerThreadPool.is_task_completed(_choice_job.task):return
        WorkerThreadPool.wait_for_task_completion(_choice_job.task);_choice_job.task=-1
        if _choice_job.ids!=_choice_ids:_start_choice_resources(world.catalog_cache);return
        world.catalog_cache.merge(_choice_job.cache,false)
    if budget.frame!=Engine.get_process_frames():
        budget.frame=Engine.get_process_frames();budget.used_usec=0
    while _choice_job.cursor<_choice_job.clips.size() and budget.used_usec<budget.limit_usec:
        var started:int=Time.get_ticks_usec()
        var result=NativeSpells.Factory.prepare([_choice_job.clips[_choice_job.cursor]],_choice_resource_cache)
        budget.used_usec+=Time.get_ticks_usec()-started
        for error in result.errors:
            if error not in choice_preparation.errors:choice_preparation.errors.append(error)
        if not result.ready and result.errors.is_empty():break
        _choice_job.cursor+=1
    choice_preparation.pending=_choice_job.clips.size()-_choice_job.cursor
    choice_preparation.ready=choice_preparation.pending==0 and choice_preparation.errors.is_empty()

func _notification(what:int)->void:
    if what==NOTIFICATION_PREDELETE and not _choice_job.is_empty() and _choice_job.get("task",-1)>=0:
        WorkerThreadPool.wait_for_task_completion(_choice_job.task)

func _native_closure(groups:Array,world:Node,cache:Dictionary)->Dictionary:
    # Movement/world commits change the canonical revision without changing
    # these resources. Compare the actual owner values (including suppression,
    # removal clocks and spatial footprints), not just UUIDs or global revision.
    # Deep snapshots prevent a later in-place owner update changing an old key.
    var start:float=world.timeline.group_start_ms
    if world.timeline.current.is_empty() and groups.any(func(group):return group.has("id")):start=world.timeline.display_ms
    var key:Array=[start,world.timeline.condition_owners.duplicate(true),world.timeline.spatial_effect_owners.duplicate(true)]
    for group in groups:key.append(group.id if group.has("id") else group.get("components",[]).map(func(item):return item.id))
    for record in _native_prepare_records:
        if record.key==key:return record
    var owners:Dictionary={};var areas:Dictionary={}
    for id in world.timeline.condition_owners:owners[id]=world.timeline.condition_owners[id].duplicate()
    for id in world.timeline.spatial_effect_owners:areas[id]=world.timeline.spatial_effect_owners[id].duplicate()
    var persistent:Array=Conditions.native_samples(owners,world.timeline.display_ms,cache)
    persistent.append_array(Conditions.NativePersistent.spatial_samples(areas,world.timeline.display_ms,cache))
    var at:float=start
    for group in groups:
        at=maxf(at,float(group.get("preview_start_ms",at)))
        for commit in group.get("commits",[]):
            Conditions.observe(owners,commit.delta.get("actors",{}),at+commit.at_ms)
            if commit.delta.get("set",{}).has("senses"):
                Conditions.NativePersistent.observe_spatial(areas,commit.delta.set.senses.get("spatial_effects",{}),at+commit.at_ms)
            persistent.append_array(Conditions.native_samples(owners,at+commit.at_ms,cache))
            persistent.append_array(Conditions.NativePersistent.spatial_samples(areas,at+commit.at_ms,cache))
        at+=group.get("duration_ms",0.0)
    var native_groups=groups.duplicate();native_groups.append({"components":persistent})
    var components:Array=[]
    for group in native_groups:components.append_array(group.get("components",[]))
    var record={"key":key,"groups":native_groups,"components":components}
    _native_prepare_records.append(record)
    if _native_prepare_records.size()>4:_native_prepare_records.pop_front()
    return record

func _native_prefetch(groups:Array,world:Node)->Array:
    # Future reduced groups are already authoritative. This horizon admits
    # preparation only: it never activates a cue or advances a commit.
    var result=groups.duplicate()
    var at:float=world.timeline.group_start_ms+float(world.timeline.current.get("duration_ms",0.0))
    at=maxf(at,world.timeline.display_ms)
    for group in world.timeline.queue:
        at=maxf(at,float(group.get("preview_start_ms",at)))
        if at-world.timeline.display_ms>NATIVE_PREFETCH_MS:break
        if not result.any(func(item):return item.get("id")==group.id):result.append(group)
        at+=float(group.duration_ms)
    return result

func ensure_epoch(world: Node) -> void:
    if epoch!=world.timeline.initialization_revision:
        close(world);epoch=world.timeline.initialization_revision

static func due_groups(groups:Array,world:Node,through_ms:float)->Array:
    if is_inf(through_ms):return groups
    var result:Array=[]
    var start:float=world.timeline.group_start_ms if not world.timeline.current.is_empty() else world.timeline.display_ms
    for group in groups:
        start=maxf(start,float(group.get("preview_start_ms",start)))
        var components:Array=[]
        for component in group.get("components",[]):
            var at:float=float(component.get("absolute_start_ms",start+float(component.get("start_ms",0.0))))
            if group.get("preparation_always_due",false) or at<=through_ms+0.000001:components.append(component)
        # Preserve the original group owner for blood preparation/retirement.
        # Only this preparation view is narrowed; timeline records stay intact.
        result.append({"id":group.get("id",""),"components":components})
        start+=float(group.get("duration_ms",0.0))
    return result

func prepare(groups: Array,cache: Dictionary,world: Node=null,admission:Dictionary={},allow_optional:bool=true,through_ms:float=INF) -> Dictionary:
    var budget:Dictionary=_native_budget if admission.is_empty() else admission
    if budget.frame!=Engine.get_process_frames():budget.frame=Engine.get_process_frames();budget.used_usec=0
    var charged_before:int=budget.used_usec
    var prepare_started:int=Time.get_ticks_usec()
    if world!=null:ensure_epoch(world)
    var stage_started:int=Time.get_ticks_usec()
    var sources: Array=[]
    for group in groups:
        if group.is_empty() or is_same(prepared_groups.get(group.get("id")),group):continue
        audio.prepare(group.get("components",[]))
        for component in group.get("components",[]):
            if component.kind=="native_effect" and not component.get("native_spell",false) and component.status=="available" and component.source_id not in sources:sources.append(component.source_id)
    var result:Dictionary
    if not sources.is_empty() and budget.used_usec>=budget.limit_usec:
        NativeSources.Admission.can_mutate() # Poll an existing load; admit no new work.
        result={"ready":false,"pending":sources.size(),"errors":[]}
    else:result=NativeSources.prepare(sources,cache)
    budget.used_usec+=Time.get_ticks_usec()-stage_started
    if result.ready:
        for group in groups:
            if not group.is_empty():prepared_groups[group.id]=group
        while prepared_groups.size()>32:prepared_groups.erase(prepared_groups.keys()[0])
    if world!=null:
        FrameProfile.end_phase(world.profile,"component_prepare_static",stage_started)
        stage_started=Time.get_ticks_usec()
        var deposit_before:int=blood.deposit_create_usec
        var page_before:int=blood.light_page_create_usec
        var blood_groups:Array=due_groups(groups,world,through_ms)
        var blood_due:bool=is_inf(through_ms) or blood_groups.any(func(group):return group.components.any(func(component):return component.get("kind")=="residue_deposit"))
        var blood_ready:bool=not blood_due or blood.prepare(world,blood_groups,budget)
        # Already received injuries may allocate hidden receiving fields during
        # the preceding animation. Their completion never gates this group;
        # Blood.prepare shares its two-field frame budget with required work.
        _optional_blood_groups=_native_prefetch(groups,world)
        readiness={"blood":blood_ready,"legacy_sources":result.ready}
        result.ready=blood_ready and result.ready
        world.profile.phases["blood_deposit_create"]=world.profile.phases.get("blood_deposit_create",0.0)+(blood.deposit_create_usec-deposit_before)/1000.0
        world.profile.phases["blood_light_page_create"]=world.profile.phases.get("blood_light_page_create",0.0)+(blood.light_page_create_usec-page_before)/1000.0
        FrameProfile.end_phase(world.profile,"component_prepare_blood",stage_started)
        stage_started=Time.get_ticks_usec()
        var required_groups:Array=groups.filter(func(group):return not group.is_empty())
        if not world.timeline.current.is_empty() and not required_groups.any(func(item):return item.get("id")==world.timeline.current.id):required_groups.push_front(world.timeline.current)
        var retained_components:Array=world.timeline.retained_components.map(func(item):return item.component)
        if not retained_components.is_empty():required_groups.append({"components":retained_components,"preparation_always_due":true})
        var required=_native_closure(required_groups,world,cache)
        var future=_native_closure(_native_prefetch(required_groups,world),world,cache)
        var due:Array=due_groups(required.groups,world,through_ms)
        var due_components:Array=[]
        for group in due:due_components.append_array(group.components)
        _native_prepare_key=required.key;_native_prepare_groups=due;_native_prepare_components=due_components;_native_optical_groups=required.groups
        var required_ids:Dictionary={}
        for component in due_components:required_ids[component.id]=true
        var optional:Array=[];var seen:Dictionary={}
        for component in future.components:
            if required_ids.has(component.id) or seen.has(component.id):continue
            if not component.get("native_spell",false) and component.get("native_hit",{}).is_empty():continue
            optional.append(component);seen[component.id]=true
        _optional_components=optional
        _optional_owner=[world.timeline.initialization_revision,world.timeline.revision,world.timeline.group_start_ms,world.timeline.current,world.timeline.queue.duplicate()]
        budget.used_usec+=Time.get_ticks_usec()-stage_started
        FrameProfile.end_phase(world.profile,"component_prepare_persistent",stage_started)
        stage_started=Time.get_ticks_usec()
        # Required owners always get the shared frame budget first. Optional
        # queries have independent readiness and cannot pause current playback.
        var native=native_spells.prepare(due,cache,world,[{"components":optional}],budget,false,required.groups)
        FrameProfile.end_phase(world.profile,"component_prepare_sources",stage_started)
        stage_started=Time.get_ticks_usec()
        var hits=native_hits.prepare(world,due_components,cache,optional,budget,false)
        readiness.native_sources=native.ready;readiness.native_hits=hits.ready
        FrameProfile.end_phase(world.profile,"component_prepare_hits",stage_started)
        result.ready=result.ready and native.ready and hits.ready
        if result.ready:
            # Do not reserve a later class cue ahead of required spell loads.
            # Only an active missing presenter can construct in sample() below.
            # Legacy first-visible presenters are required atomic work: the
            # existing owner constructs after Timeline admission. Charge them
            # below, but never drop an admitted effect to fit optional work.
            var current:Dictionary=world.timeline.current
            if current.is_empty() and not groups.is_empty():current=groups[0]
            var current_age:float=maxf(0.0,world.timeline.display_ms-world.timeline.group_start_ms)
            var needs_native_constructor:bool=current.get("components",[]).any(func(component):return component.get("kind")=="native_effect" and not component.get("native_spell",false) and component.get("status")=="available" and not handles.has(component.id) and current_age>=float(component.get("start_ms",0.0)) and current_age<float(component.get("start_ms",0.0))+float(component.get("duration_ms",0.0)))
            if needs_native_constructor:result.ready=NativeSources.Admission.begin_mutation()
        budget.used_usec+=maxi(0,Time.get_ticks_usec()-prepare_started-(budget.used_usec-charged_before))
        if result.ready and allow_optional:prepare_optional(world,cache,budget)
        result.errors.append_array(native.errors)
        for issue in hits.issues:
            if issue.get("status")=="missing":result.errors.append(str(issue))
    budget.used_usec+=maxi(0,Time.get_ticks_usec()-prepare_started-(budget.used_usec-charged_before))
    if world!=null:FrameProfile.end_phase(world.profile,"component_prepare",prepare_started)
    return result

func prepare_optional(world:Node,cache:Dictionary,admission:Dictionary={})->void:
    var budget:Dictionary=_native_budget if admission.is_empty() else admission
    if budget.frame!=Engine.get_process_frames():budget.frame=Engine.get_process_frames();budget.used_usec=0
    if budget.used_usec>=budget.limit_usec:return
    if _optional_owner.is_empty() or _optional_owner!=[world.timeline.initialization_revision,world.timeline.revision,world.timeline.group_start_ms,world.timeline.current,world.timeline.queue]:return
    var started:int=Time.get_ticks_usec();var charged_before:int=budget.used_usec
    if not _optional_blood_groups.is_empty():blood.prepare(world,_optional_blood_groups,budget)
    if not _optional_components.is_empty() and budget.used_usec<budget.limit_usec:
        native_spells.prepare(_native_prepare_groups,cache,world,[{"components":_optional_components}],budget,true,_native_optical_groups)
        native_hits.prepare(world,_native_prepare_components,cache,_optional_components,budget)
    budget.used_usec+=maxi(0,Time.get_ticks_usec()-started-(budget.used_usec-charged_before))
    FrameProfile.end_phase(world.profile,"component_prepare_prefetch",started)

func decorate(world:Node,samples:Array)->void:
    native_hits.decorate(world,samples,world.native_spell_hit_material)

func capture_native_channels(world:Node)->void:
    # Called after the native atlas has received/projected this frame's lights.
    # Play acknowledges this evidence only on frame_post_draw.
    for component in world.displayed_components:
        if component.get("native_spell",false):
            var native:Dictionary=native_spells.diagnostics.get(component.id,{})
            if not is_equal_approx(float(native.get("age_ms",-1)),float(component.age_ms)):continue
            for light in component.get("native_lights",[]):
                var id="native-effect/"+str(component.id)+"/"+str(light.path)
                if world.source_lighting.effect_was_submitted(id):
                    _witness(world,{"id":NativeChannels.light_id(component.id,light.path)},true)
        elif component.has("native_hit"):
            if not world.native_spell_hit_material:
                pending_evidence.append({"trace_track_id":component.id+":native_material","display_ms":world.timeline.display_ms,"inactive":true,"reason":"colour_treatment_selected"})
                continue
            var selected:Dictionary=Conditions.material(component.actor_uuid,world.displayed_components).get("flash",{})
            if selected.get("id")==component.id and selected.get("native_surface")!=null:
                _witness(world,{"id":component.id+":native_material"},_actor_visible(world,component.actor_uuid))

func sample(world: Node, samples: Array,frame_seconds: float=1.0/60.0,budget:Dictionary={}) -> void:
    ensure_epoch(world)
    ready=true
    var blood_started:int=Time.get_ticks_usec()
    blood.sample(world,samples,world.world_changes)
    FrameProfile.end_phase(world.profile,"blood_sample",blood_started)
    for phase in blood.sample_phases:
        world.profile.phases["blood_"+phase]=world.profile.phases.get("blood_"+phase,0.0)+blood.sample_phases[phase]
    ready=blood.ready
    native_spells.sample(world,samples,frame_seconds)
    ready=ready and native_spells.ready and native_hits.ready
    for issue in native_spells.issues+native_hits.issues.filter(func(row):return row.get("status")=="missing"):
        if issue not in world.presentation_errors:world.presentation_errors.append(issue)
    for witness in native_spells.witnesses:
        if witness.status=="rendered":pending_evidence.append({"trace_track_id":witness.id,"display_ms":world.timeline.display_ms,"visible":true})
    var live_media={}
    var sounds: Array=[]
    var alive={}
    var live_numbers={}
    for actor_id in world.visual_actors:
        if not outlines.sample(world,actor_id,Conditions.material(actor_id,samples)):ready=false
    for actor_id in outlines.owners.keys():
        if not world.visual_actors.has(actor_id):outlines.erase(world,actor_id)
    for component in samples:
        if component.get("native_spell",false):continue
        if component.kind=="residue_deposit":
            _witness(world,component,blood.visible_deposit(component));continue
        if component.get("status")=="missing": continue
        if component.kind=="audio":
            sounds.append(_audio_attachment(world,component));continue
        var actor: Dictionary=world.visual_actors.get(component.get("actor_uuid"),{})
        var fixed_ground=component.get("attachment")=="ground" and component.get("position")!=null
        var fixed_impact=component.get("attachment")=="impact" and component.get("impact",{}).get("status")=="available"
        if actor.is_empty() and not fixed_ground and not fixed_impact: continue
        var row: Dictionary=actor.get("row",{})
        if fixed_impact and actor.is_empty():row={"id":component.id,"position":component.impact.position,"base_height_steps":component.impact.elevation_feet/5.0,"kind":"effect","facing":"SW"}
        if fixed_ground:
            row={"id":component.id,"position":component.position,"base_height_steps":component.get("elevation_feet",0)/5.0,"kind":"effect","facing":"SW"}
            var tile: Dictionary=world.timeline.presentation_state().tiles.get("%d,%d" % component.position,{})
            if tile.is_empty(): continue
        var origin=Placement.contact(row)
        if component.kind=="native_effect":
            alive[component.id]=true
            if not handles.has(component.id):
                if not NativeSources.Admission.can_mutate():
                    ready=false;continue
                var construction_started:int=Time.get_ticks_usec()
                if not budget.is_empty():budget["required_legacy_constructors"]=budget.get("required_legacy_constructors",0)+1
                var presenter=NativePreview.new(); world.add_child(presenter)
                var issue=presenter.configure(component.source_id,world.catalog_cache,Components.effect_seed(component),component.get("palette",[]))
                if not issue.is_empty():
                    world.presentation_errors.append(issue); presenter.queue_free()
                    if not budget.is_empty():budget.used_usec+=Time.get_ticks_usec()-construction_started
                    continue
                issue=presenter.bind_receiving(world.source_lighting)
                if not issue.is_empty():
                    world.presentation_errors.append(issue);presenter.close();presenter.queue_free()
                    if not budget.is_empty():budget.used_usec+=Time.get_ticks_usec()-construction_started
                    continue
                var placement=row.duplicate(); placement.id=component.id
                var draws=presenter.draw_entries(component.id,placement,-10,100)
                world.actor_entries.append_array(draws)
                handles[component.id]={"node":presenter,"draws":draws,"placement":placement,"component":component}
                world.draw_order_dirty=true
                if not budget.is_empty():budget.used_usec+=Time.get_ticks_usec()-construction_started
            var handle: Dictionary=handles[component.id]
            handle.placement.position=row.position
            handle.placement.base_height_steps=row.base_height_steps
            var attach: String=component.get("attachment","body")
            if attach=="projectile":
                var fraction=clampf(component.age_ms/maxf(.001,component.duration_ms),0,1)
                var a=component.from_position;var b=component.to_position
                var point=[lerpf(a[0],b[0],fraction),lerpf(a[1],b[1],fraction)]
                var height=lerpf(component.from_elevation_feet,component.to_elevation_feet,fraction)/5.0
                handle.placement.position=point;handle.placement.base_height_steps=height
                origin=_projectile_point(world,component,fraction)
            elif attach=="target_body":
                var target: Dictionary=world.visual_actors.get(component.get("target_uuid"),{})
                if not target.is_empty():
                    handle.placement.position=target.row.position;handle.placement.base_height_steps=target.row.base_height_steps
                    origin=_socket(world,target.row,"body_center")
            elif attach=="ground" and component.get("position")!=null:
                handle.placement.position=component.position
                origin=Placement.contact(handle.placement)
            elif attach=="impact":origin=component.impact.world_anchor
            elif attach=="body":origin+=Vector3.UP*row.get("visual_height",0.0)*Placement.HEIGHT_UNIT
            elif attach in ["body_center","head","face","hand"]:origin=_socket(world,row,attach)
            var opacity: float=component.get("alpha",1)
            var fade=minf(1,component.age_ms/component.fade_in_ms) if component.get("fade_in_ms",0)>0 else 1.0
            if component.get("fade_out_ms",0)>0:fade=minf(fade,(component.duration_ms-component.age_ms)/component.fade_out_ms)
            if component.get("fade_curve")=="smoothstep":fade=smoothstep(0,1,fade)
            handle.node.set_opacity(opacity*clampf(fade,0,1))
            var age: float=NativeSources.source_age_ms(component,component.age_ms)
            var source_scale: float=component.get("scale",1)
            if component.has("condition_uuid"):source_scale*=row.scale*128.0/float(world.rig_config.TILE_W)
            if handle.node.record.get("actor_partition",false):
                var partition_error=handle.node.bind_actor_partition(Placement.contact(row),world.camera.global_basis,origin,source_scale)
                if not partition_error.is_empty():
                    ready=false
                    if partition_error not in world.presentation_errors:world.presentation_errors.append(partition_error)
                    continue
            var context=_receiving_context(world,handle.node.record,component,origin,source_scale)
            if component.has("weapon_pose"):
                var weapon=NativeSources.weapon_context(component,row,world.rigs[row.rig],world.rig_config.FACING_CYCLE,world.quarter)
                if not weapon.error.is_empty():
                    ready=false
                    if weapon.error not in world.presentation_errors:world.presentation_errors.append(weapon.error)
                    continue
                context.merge(weapon.context)
            context.native_frame_seconds=frame_seconds
            context.native_continuous=not world.timeline.paused and not world.timeline.waiting_for_media and not world.timeline.waiting_for_world
            var history: Array=[]
            if attach=="projectile":
                if handle.get("history_quarter",-1)!=world.quarter:
                    handle.anchor=_projectile_point(world,component,0)
                    handle.history=[]
                    var duration: float=component.duration_ms/1000.0
                    for index in ceili(duration*60)+1:
                        var at=minf(index/60.0,duration)
                        var point=_projectile_point(world,component,at/maxf(.001,duration))
                        handle.history.append({"age_seconds":at,"transform":Transform3D(Basis.IDENTITY,(point-handle.anchor)/source_scale)})
                    handle.history_quarter=world.quarter
                history=handle.history
                context.native_transform=Transform3D(Basis.IDENTITY,(origin-handle.anchor)/source_scale)
                origin=handle.anchor
            var result=handle.node.sample(age/1000.0,world.camera.global_basis,origin,source_scale,history,context)
            ready=ready and result.ready
            _witness(world,component,handle.node.sampled_age>=0 and handle.draws.any(func(draw):return _entry_visible(world,draw)))
            if not result.get("error","").is_empty() and result.error not in world.presentation_errors: world.presentation_errors.append(result.error)
        elif component.kind=="registered_media":
            if not row.has("rig"): continue
            var canonical: Dictionary=world.timeline.presentation_state().actors.get(component.actor_uuid,{})
            if canonical.get("life_state","alive") not in component.layer.get("lifeStates",["alive","dying","stable","dead"]): continue
            var facing=_facing(world,row)
            if component.metadata.has("world_basis"):
                var basis_row=row.duplicate();basis_row.facing=component.metadata.world_basis;facing=_facing(world,basis_row)
            var phases:Array=component.get("media_samples",[{"part_id":"sustain","media":component.media,"source_age_ms":component.get("source_age_ms",component.age_ms),"alpha":component.alpha}])
            var origin_point=origin
            if component.attachment=="body":origin_point+=Vector3.UP*row.get("visual_height",0.0)*Placement.HEIGHT_UNIT
            elif component.attachment in ["head","face","hand"]:
                if not _has_socket(world,row,component.attachment):continue
                origin_point=_socket(world,row,component.attachment)
            var unit=128.0/float(world.rig_config.TILE_W)*row.scale/Placement.PIXELS_PER_UNIT
            if component.attachment in ["head","face","hand"]: origin_point+=world.camera.basis.y*float(component.metadata.get("actor_top_clearance_px",0))*unit
            origin_point+=(world.camera.basis.x*float(component.layer.get("offsetX",0))*row.get("scale_x",1.0)-world.camera.basis.y*float(component.layer.get("offsetY",0)))*unit
            var scale=float(component.metadata.get("scale",.5))
            var drawn=false
            for phase in phases:
                if phase.media.status!="available":
                    ready=false
                    var issue="Missing condition phase registration: "+str(phase.media.get("asset_id",""))
                    if issue not in world.presentation_errors:world.presentation_errors.append(issue)
                    continue
                var parts=RegisteredMedia.sample(phase.media,phase.source_age_ms,facing)
                var definition:Dictionary=phase.media.definition
                for i in parts.size():
                    var part: Dictionary=parts[i]
                    var id: String=component.id+":"+str(phase.part_id)+":"+str(i);live_media[id]=true
                    if not world.textures.has(part.file): ready=false;continue
                    if not media_handles.has(id):
                        var node=MeshInstance3D.new();node.mesh=QuadMesh.new();node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
                        var material=ShaderMaterial.new();material.shader=MediaShader;node.material_override=material;world.add_child(node)
                        var entry={"id":id,"node":node,"material":material,"placement":row,"role":"native_effect","layer":-10 if component.layer.get("drawOrder")=="behind_body" else 101}
                        media_handles[id]=entry;world.actor_entries.append(entry);world.draw_order_dirty=true
                    var entry: Dictionary=media_handles[id]
                    entry.placement=row
                    var rect: Array=part.rect
                    var texture: Texture2D=world.textures[part.file]
                    entry.material.set_shader_parameter("sheet",texture)
                    entry.material.set_shader_parameter("frame_uv",Vector4(rect[0]/texture.get_width(),rect[1]/texture.get_height(),rect[2]/texture.get_width(),rect[3]/texture.get_height()))
                    entry.material.set_shader_parameter("opacity",phase.alpha)
                    entry.node.mesh.size=Vector2(rect[2],rect[3])*unit*scale
                    var center=Vector2(part.offset[0]+rect[2]*.5-definition.anchor.x*definition.frame.width,part.offset[1]+rect[3]*.5-definition.anchor.y*definition.frame.height)
                    entry.node.basis=world.camera.basis
                    entry.node.position=origin_point+(world.camera.basis.x*center.x-world.camera.basis.y*center.y)*unit*scale
                    entry.screen_rect=Rect2(world.camera.unproject_position(entry.node.position),Vector2(rect[2],rect[3]))
                    if _entry_visible(world,entry):drawn=true
            _witness(world,component,drawn)
        elif component.kind=="geometry_projectile":
            live_media[component.id]=true
            if not media_handles.has(component.id):
                var node=MeshInstance3D.new();node.mesh=QuadMesh.new();node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
                var material=ShaderMaterial.new();material.shader=BoltShader;node.material_override=material;world.add_child(node)
                var entry={"id":component.id,"node":node,"material":material,"placement":row.duplicate(),"role":"native_effect","layer":100}
                media_handles[component.id]=entry;world.actor_entries.append(entry);world.draw_order_dirty=true
            var entry: Dictionary=media_handles[component.id]
            var a=_projectile_point(world,component,0);var b=_projectile_point(world,component,1)
            var fraction=clampf(component.age_ms/maxf(.001,component.duration_ms),0,1)
            var point=a.lerp(b,fraction);var forward=(b-a).normalized()
            var x=forward.dot(world.camera.basis.x);var y=forward.dot(world.camera.basis.y)
            var tangent=(world.camera.basis.x*x+world.camera.basis.y*y).normalized()
            if tangent.is_zero_approx():tangent=world.camera.basis.x
            var unit=128.0/float(world.rig_config.TILE_W)/Placement.PIXELS_PER_UNIT
            var length_px=minf(component.style.maximumLengthPx,Vector2((b-a).dot(world.camera.basis.x),(b-a).dot(world.camera.basis.y)).length()/unit*component.style.distanceLengthRatio)
            var extent=Vector2(length_px+component.style.headRadiusPx*2+2,maxf(component.style.headRadiusPx*2,component.style.strokeWidthPx)+2)
            entry.node.mesh.size=extent*unit
            entry.node.basis=Basis(tangent,world.camera.basis.z.cross(tangent),world.camera.basis.z)
            entry.node.position=point-tangent*(extent.x*.5-component.style.headRadiusPx-1)*unit
            entry.placement.position=[lerpf(component.from_position[0],component.to_position[0],fraction),lerpf(component.from_position[1],component.to_position[1],fraction)]
            entry.placement.base_height_steps=lerpf(component.from_elevation_feet,component.to_elevation_feet,fraction)/5.0
            entry.material.set_shader_parameter("extent",extent);entry.material.set_shader_parameter("length_px",length_px)
            for field in [["stroke_width","strokeWidthPx"],["stroke_alpha","strokeAlpha"],["head_radius","headRadiusPx"],["head_alpha","headAlpha"]]:entry.material.set_shader_parameter(field[0],component.style[field[1]])
            entry.material.set_shader_parameter("stroke_colour",Color.hex(int(component.colors.secondary)*256+255));entry.material.set_shader_parameter("head_colour",Color.hex(int(component.colors.primary)*256+255))
            _witness(world,component,_entry_visible(world,entry))
        elif component.kind in ["damage_number","feedback_text"]:
            live_numbers[component.id]=true
            if not numbers.has(component.id):
                var label=Label3D.new();label.text=component.text;label.font_size=component.style.fontSizePx
                label.pixel_size=128.0/float(world.rig_config.TILE_W)/Placement.PIXELS_PER_UNIT
                var font=SystemFont.new();font.font_names=PackedStringArray([component.style.fontFamily]);font.font_weight=700;label.font=font
                label.outline_size=component.style.strokeWidthPx;label.outline_modulate=Color.hex(int(component.style.strokeColor)*256+255)
                label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true;label.modulate=Color.hex(int(component.color)*256+255)
                # Feedback is a foreground overlay; depth-disabled sprites still
                # participate in the transparent pass and can otherwise cover it.
                label.render_priority=127;label.outline_render_priority=126
                world.add_child(label);numbers[component.id]=label
            var progress=clampf(component.age_ms/maxf(.001,component.duration_ms),0,1)
            var rig: Dictionary=world.rigs[row.rig]
            var lift=(component.style.anchorLiftPx-rig.origin_y_from_ground)*row.scale+component.style.risePx*progress+component.style.fontSizePx*.5
            numbers[component.id].position=origin+world.camera.basis.y*lift*numbers[component.id].pixel_size
            numbers[component.id].modulate.a=clampf((1-progress)/maxf(.001,1.0-component.style.fadeStartFraction),0,1)
            _witness(world,component,not world.camera.is_position_behind(numbers[component.id].global_position) and world.get_viewport().get_visible_rect().has_point(world.camera.unproject_position(numbers[component.id].global_position)))
        elif component.kind=="material_flash": _witness(world,component,_actor_visible(world,component.actor_uuid))
    for id in handles.keys():
        if not alive.has(id): _release(world,id)
    for id in numbers.keys():
        if not live_numbers.has(id): numbers[id].queue_free(); numbers.erase(id)
    for id in media_handles.keys():
        if not live_media.has(id):
            world.actor_entries.erase(media_handles[id]);media_handles[id].node.queue_free();media_handles.erase(id);world.draw_order_dirty=true
    audio.prepare(sounds)
    audio.sample(world,sounds,world.timeline.display_ms,world.playback_speed,world.timeline.paused or world.timeline.waiting_for_media or world.timeline.waiting_for_world,epoch)
    for voice in audio.voices.values():
        if voice.started and not voice.paused:_witness(world,voice.row,true)
    for id in world.visual_actors:
        if _actor_visible(world,id):_condition_witnesses(world,id,samples)

static func _audio_attachment(world: Node, component: Dictionary) -> Dictionary:
    var sound=component.duplicate()
    var attachment:String=component.get("attachment","body")
    if attachment=="ui":return sound
    if attachment=="screen" and component.has("screen_position"):return sound
    if component.has("world_position"):return sound
    if attachment=="impact" and component.get("impact",{}).get("status")=="available":
        sound.world_position=component.impact.world_anchor;return sound
    if attachment in ["ground","world"] and component.get("position")!=null:
        sound.world_position=Placement.contact({"position":component.position,"base_height_steps":component.get("elevation_feet",0)/5.0});return sound
    var actor_id:String=component.get("target_uuid",component.get("actor_uuid","")) if attachment=="target_body" else component.get("actor_uuid","")
    var actor:Dictionary=world.visual_actors.get(actor_id,{})
    if actor.is_empty():
        var track:Dictionary=component.get("source_track",{})
        var disclosed=Components.AudioCues.disclosed_body(component,world.timeline.presentation_state().actors.get(actor_id,{}),world.rigs.get(track.get("rig",""),{}))
        if not disclosed.is_empty():
            sound.world_position=_socket(world,disclosed,"body_center");sound.attachment_source="disclosed_stationary_body";return sound
        sound.attachment_error="attachment_unavailable";return sound
    var row:Dictionary=actor.row
    if attachment=="ground":sound.world_position=Placement.contact(row)
    elif attachment in ["body","body_center","target_body"]:sound.world_position=_socket(world,row,"body_center")
    elif attachment in ["head","face","hand","weapon"]:
        var socket="hand" if attachment=="weapon" else attachment
        if row.has("rig") and _has_socket(world,row,socket):sound.world_position=_socket(world,row,socket)
        else:sound.attachment_error="attachment_socket_unavailable"
    elif attachment=="screen":sound.screen_position=world.camera.unproject_position(_socket(world,row,"body_center"))
    else:sound.attachment_error="attachment_unsupported"
    return sound

static func _facing(world: Node,row: Dictionary) -> String:
    var cycle: Array=world.rig_config.FACING_CYCLE
    return cycle[posmod(cycle.find(row.get("facing","SW"))+world.quarter*2,8)]

static func _receiving_context(world: Node,record: Dictionary,component: Dictionary,origin: Vector3,scale: float) -> Dictionary:
    var projected: Vector2=world.camera.unproject_position(origin)
    var pixel_scale=projected.distance_to(world.camera.unproject_position(origin+world.camera.basis.x))*scale/float(record.pixels_per_unit)
    var context={"screen_origin":projected-Vector2(record.pivot[0],record.pivot[1])*pixel_scale,"pixel_scale":pixel_scale,
        "light_cap":1.0 if world.light_cap_enabled else 0.0,"supports":[],"source_basis":Basis.IDENTITY}
    if component.get("direction_from")!=null and component.get("direction_to")!=null:
        var a=component.direction_from;var b=component.direction_to
        var direction=Vector3(b[0]-a[0],0,b[1]-a[1])
        if not direction.is_zero_approx():context.source_basis=Basis.looking_at(direction.normalized(),Vector3.UP)
    if "depth_receiver" in record.get("requirements",[]):
        var tiles: Dictionary=world.timeline.presentation_state().tiles
        for x in range(floori(origin.x)-1,floori(origin.x)+2):
            for y in range(floori(origin.z)-1,floori(origin.z)+2):
                var tile: Dictionary=tiles.get("%d,%d" % [x,y],{})
                if not tile.has("elevation_steps"):continue
                var contact=Vector3(x,float(tile.elevation_steps)*Placement.HEIGHT_UNIT,y)
                context.supports.append(Transform3D(Basis.from_scale(Vector3.ONE/maxf(.001,scale)),(contact-origin)/maxf(.001,scale)))
    return context

static func _projectile_point(world: Node,component: Dictionary,fraction: float) -> Vector3:
    return SpellPlacement.projectile_point(world,component,fraction)

static func _socket(world: Node,row: Dictionary,socket: String) -> Vector3:
    return SpellPlacement.socket(world,row,socket)

static func _has_socket(world: Node,row: Dictionary,socket: String) -> bool:
    return SpellPlacement.has_socket(world,row,socket)

func _witness(world: Node,component: Dictionary,visible: bool) -> void:
    if not visible:return
    for id in [component.id]+component.get("trace_keys",[]):
        pending_evidence.append({"trace_track_id":id,"display_ms":world.timeline.display_ms,"visible":true})

static func _entry_visible(world: Node,entry: Dictionary) -> bool:
    if not entry.node.is_visible_in_tree():return false
    var mesh: QuadMesh=entry.node.mesh
    var transform: Transform3D=entry.node.global_transform
    var a=world.camera.unproject_position(transform*(mesh.center_offset+Vector3(-mesh.size.x*.5,mesh.size.y*.5,0)))
    var b=world.camera.unproject_position(transform*(mesh.center_offset+Vector3(mesh.size.x*.5,-mesh.size.y*.5,0)))
    return Rect2(a,b-a).abs().intersects(world.get_viewport().get_visible_rect())

static func _actor_visible(world: Node,id: String) -> bool:
    var actor: Dictionary=world.visual_actors.get(id,{})
    if actor.is_empty() or not actor.valid:return false
    for entry in actor.entries:
        if entry.role!="shadow" and not entry.get("texture_path","").is_empty() and _entry_visible(world,entry):return true
    return false

func _condition_witnesses(world: Node,actor_id: String,samples: Array) -> void:
    var selected=Conditions.select_recipes(actor_id,samples)
    for sample in samples:
        if sample.kind!="condition" or sample.actor_uuid!=actor_id:continue
        if not selected.any(func(value):return value.recipe.get("definitionRef")==sample.recipe.get("definitionRef")):continue
        var persistent: Dictionary=sample.recipe.get("persistent",{})
        var poses:Array=persistent.get("activityPoses",[])
        if not poses.is_empty():
            var actor:Dictionary=world.timeline.presentation_state().actors.get(actor_id,{})
            var activity:String=world.displayed_samples.get(actor_id,{}).get("activity","idle")
            var rig:String=world.visual_actors[actor_id].row.rig
            var pose=Conditions.ConditionPose.select(actor,rig,activity,world.catalog_cache)
            if pose.get("condition_uuid")==sample.condition_uuid and world.playbacks[actor_id].clip==pose.get("clip"):
                for i in poses.size():
                    if poses[i].rigId==rig and poses[i].activity==activity:
                        _witness(world,{"id":"condition:"+sample.condition_uuid+":activityPoses:"+str(i)},true)
        for mechanism in ["bodyColor","alphaMultiplier","bodyRamp","bodyOutline","bodyPose","frozenPose"]:
            if persistent.get(mechanism)==null:continue
            if mechanism=="bodyRamp" and (persistent.bodyRamp.get("mapping")!="flowing_film" or not world.textures.has(world.resources.get(persistent.bodyRamp.get("texture")))):continue
            if mechanism=="bodyOutline" and (not outlines.owners.has(actor_id) or not outlines.owners[actor_id].drawn):continue
            if mechanism in ["bodyPose","frozenPose"]:
                if not world.displayed_samples.get(actor_id,{}).is_empty():continue
                var actor: Dictionary=world.timeline.presentation_state().actors.get(actor_id,{})
                var pose=Conditions.pose(actor,world.visual_actors[actor_id].row.rig,world.catalog_cache)
                if pose.get("condition_uuid")!=sample.condition_uuid or world.playbacks[actor_id].clip!=pose.get("clip"):continue
            _witness(world,{"id":"condition:"+sample.condition_uuid+":"+mechanism},true)

func _release(world: Node, id: String) -> void:
    var handle: Dictionary=handles[id]
    for draw in handle.draws: world.actor_entries.erase(draw)
    handle.node.close();handle.node.queue_free();handles.erase(id)
    world.draw_order_dirty=true

func close(world: Node) -> void:
    native_spells.close(world)
    native_hits.close()
    blood.close(world)
    outlines.close(world)
    for id in handles.keys(): _release(world,id)
    for label in numbers.values(): label.queue_free()
    numbers.clear()
    for entry in media_handles.values():world.actor_entries.erase(entry);entry.node.queue_free()
    media_handles.clear();audio.close()
    prepared_groups.clear();pending_evidence=[]
    _native_prepare_key=[];_native_prepare_groups=[];_native_optical_groups=[];_native_prepare_components=[];_native_prepare_records=[]
    _native_budget={"frame":-1,"used_usec":0,"limit_usec":NATIVE_CONSTRUCTION_USEC}
    _optional_components=[];_optional_blood_groups=[];_optional_owner=[]
