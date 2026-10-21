extends RefCounted
const NativePreview=preload("res://presentation/native_effect_preview.gd")
const Placement=preload("res://placement.gd")
const AudioPresenter=preload("res://presentation/audio_presenter.gd")
const NativeSources=preload("res://presentation/native_effects.gd")
const NativeItems=preload("res://presentation/native_items.gd")
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
const SourceMaterial=preload("res://presentation/source_material.gd")
const EnvironmentSource=preload("res://presentation/environment_source.gd")
const EnvironmentMedia=preload("res://presentation/environment_media.gd")
var native_spells=NativeSpells.new()
var native_hits=NativeHits.new()
var blood=BloodRenderer.new()
var outlines=ConditionOutline.new()
var audio=AudioPresenter.new()
var handles: Dictionary={}
var numbers: Dictionary={}
var media_handles: Dictionary={}
var _prepared_resource_scope:Array=[]
var _prepared_resource_groups:Array=[]
var _prepared_resource_result:Dictionary={}
var _next_resource_cue_ms:float=-INF
var _next_optional_cue_ms:float=INF
var _resource_membership_revision:int=0

func invalidate_preparation()->void:
    # The display owner calls this after installing actor/world membership.
    # Source clocks and ordinary poses do not invalidate allocated resources.
    _resource_membership_revision+=1

func _resource_scope(world:Node)->Array:
    var timeline:RefCounted=world.timeline
    return [timeline.initialization_revision,timeline.resource_revision,
        world.quarter,world.get_viewport().get_visible_rect().size,
        world.native_spell_hit_material,_resource_membership_revision,native_spells.preparation_revision]

func _same_resource_groups(groups:Array)->bool:
    var previous:int=0
    for group in groups:
        if group.get("components",[]).is_empty() and group.get("native_requirements",[]).is_empty() and group.get("actor_tracks",[]).is_empty():continue
        while previous<_prepared_resource_groups.size() and _prepared_resource_groups[previous].get("components",[]).is_empty() \
                and _prepared_resource_groups[previous].get("native_requirements",[]).is_empty() \
                and _prepared_resource_groups[previous].get("actor_tracks",[]).is_empty():previous+=1
        if previous>=_prepared_resource_groups.size() or not is_same(group,_prepared_resource_groups[previous]):return false
        previous+=1
    while previous<_prepared_resource_groups.size():
        var group:Dictionary=_prepared_resource_groups[previous]
        if not group.get("components",[]).is_empty() or not group.get("native_requirements",[]).is_empty() or not group.get("actor_tracks",[]).is_empty():return false
        previous+=1
    return true

func _next_resource_cue(groups:Array,world:Node,through_ms:float)->float:
    if is_inf(through_ms):return INF
    var next:float=INF
    var start:float=world.timeline.group_start_ms if not world.timeline.current.is_empty() else world.timeline.display_ms
    for group in groups:
        start=maxf(start,float(group.get("preview_start_ms",start)))
        if not group.get("preparation_always_due",false):
            for component in group.get("components",[]):
                var at:float=start+float(component.preparation_at_ms) if component.has("preparation_at_ms") else float(component.get("absolute_start_ms",start+float(component.get("start_ms",0.0))))
                if at>through_ms+0.000001:next=minf(next,at)
        start+=float(group.get("duration_ms",0.0))
    return next

func _next_optional_cue(world:Node)->float:
    var start:float=world.timeline.group_start_ms+float(world.timeline.current.get("duration_ms",0.0))
    for group in world.timeline.queue:
        start=maxf(start,float(group.get("preview_start_ms",start)))
        var admission:float=start-NATIVE_PREFETCH_MS
        if admission>world.timeline.display_ms+0.000001:return admission
        start+=float(group.get("duration_ms",0.0))
    return INF
var epoch=-1
var ready=true
var readiness:Dictionary={}
var prepared_groups: Dictionary={}
var pending_evidence: Array=[]
var _native_prepare_groups:Array=[]
var _native_optical_groups:Array=[]
var _native_prepare_components:Array=[]
var _native_base_groups:Array=[]
var _native_persistent:Array=[]
const NATIVE_PREFETCH_MS=4000.0
const NATIVE_CONSTRUCTION_USEC=2000
var _native_budget:Dictionary={"frame":-1,"used_usec":0,"limit_usec":NATIVE_CONSTRUCTION_USEC}
var _optional_components:Array=[]
var _optional_blood_groups:Array=[]
var _optional_owner:Array=[]

## A compiler packet begins with its own before-snapshot coverage. Normalize
## those immutable source operands against the displayed owner's actual prior
## disclosures; no world delta or future owner clock is replayed here.
static func surface_requirements(requirements:Array,coverage:Dictionary,world:Node)->Array:
    var result:Array=[]
    for requirement in requirements:
        var cue:Dictionary=requirement.get("native_cue",{})
        var descriptor:Dictionary=cue.get("constructor_input",{})
        if descriptor.get("cell_input")!="surface_groups" or requirement.get("spatial_removal",false) or requirement.get("status")=="missing":
            result.append(requirement);continue
        var identity:String=str(requirement.spatial_effect_uuid)
        var base:String=str(requirement.get("spatial_coverage_base_id",requirement.id))
        var key:Array=[identity,base]
        if not coverage.has(key):
            var owner:Dictionary=world.timeline.spatial_effect_owners.get(identity,{})
            var original:Dictionary=owner.get("source_effect",{})
            var origin:Dictionary=Conditions.NativePersistent.SpatialInputs.surface_origin(original,owner.get("source_disclosures",[]))
            if origin.anchor==null:origin={"anchor":requirement.from_position,"elevation_steps":float(requirement.from_elevation_feet)/5.0}
            coverage[key]={"known":owner.get("source_disclosed_cells",{}).duplicate(),
                "disclosures":owner.get("source_disclosures",[]).duplicate(),
                "constructions":owner.get("surface_constructions",{}).get(int(cue.source_index),{}).duplicate(),
                "anchor":origin.anchor,"elevation":origin.elevation_steps}
        var projected:Dictionary=coverage[key]
        var cells:Array=requirement.spatial_source_cells
        var added:Array=[]
        for position in cells:
            if projected.known.has(position):continue
            projected.known[position]=true;added.append(position)
        if not added.is_empty():projected.disclosures.append({"cells":added,"original":projected.disclosures.is_empty()})
        for disclosure in projected.disclosures:
            var first:Array=disclosure.cells[0]
            var batch:String=str(first[0])+","+str(first[1])
            if not projected.constructions.has(batch):
                if disclosure.cells==cells and projected.anchor==requirement.from_position:
                    projected.constructions[batch]={"operands":requirement.native_constructor_inputs,
                        "surface_records":requirement.spatial_surface_records,"evidence":requirement.native_constructor_evidence,
                        "source_anchor":projected.anchor,"source_elevation_steps":projected.elevation,"source_cells":cells}
                else:
                    projected.constructions[batch]=Conditions.NativePersistent.SpatialInputs.surface_construction(identity,
                        str(requirement.spatial_content_id),disclosure.cells,projected.anchor,projected.elevation,descriptor)
            result.append(Conditions.NativePersistent.surface_component(requirement,disclosure,projected.constructions[batch]))
    return result

static func preparation_groups(groups:Array,persistent:Array,world:Node=null)->Array:
    # Compiler-owned requirements contain no live occurrence clocks. Join them
    # with the current displayed owners without copying owner history or replaying
    # future commits on the scene thread.
    var result:Array=[];var coverage:Dictionary={}
    for group in groups:
        var requirements:Array=group.get("native_requirements",[])
        if requirements.is_empty():
            result.append(group);continue
        var prepared:Dictionary=group.duplicate()
        prepared.components=group.get("components",[]).duplicate()
        prepared.components.append_array(surface_requirements(requirements,coverage,world) if world!=null else requirements)
        result.append(prepared)
    if not persistent.is_empty():result.append({"components":persistent,"preparation_always_due":true})
    return result

# Scene owner supplies metadata admission; passive fixture callers have no
# pending Session handoff and need no additional gate or ownership directory.
var source_group_ready:Callable

func _native_prefetch(groups:Array,world:Node)->Array:
    # Future reduced groups are already authoritative. This horizon admits
    # preparation only: it never activates a cue or advances a commit.
    var result=groups.duplicate()
    var at:float=world.timeline.group_start_ms+float(world.timeline.current.get("duration_ms",0.0))
    at=maxf(at,world.timeline.display_ms)
    for group in world.timeline.queue:
        at=maxf(at,float(group.get("preview_start_ms",at)))
        if at-world.timeline.display_ms>NATIVE_PREFETCH_MS:break
        if (not source_group_ready.is_valid() or source_group_ready.call(group)) \
                and not result.any(func(item):return item.get("id")==group.id):result.append(group)
        at+=float(group.duration_ms)
    return result

func ensure_epoch(world: Node) -> void:
    if epoch!=world.timeline.initialization_revision:
        close(world);epoch=world.timeline.initialization_revision

## Drops requirements compiled for a condition or spatial owner at a cut the
## display has passed when the timeline has since retired that owner (removed
## and its removal played): they are not prepared again.
static func live_requirements(groups:Array,world:Node)->Array:
    var owners:Dictionary=world.timeline.condition_owners;var areas:Dictionary=world.timeline.spatial_effect_owners
    var grants:Dictionary=world.timeline.temporary_hp_owners
    var start:float=world.timeline.group_start_ms if not world.timeline.current.is_empty() else world.timeline.display_ms
    var result:Array=[]
    for group in groups:
        start=maxf(start,float(group.get("preview_start_ms",start)))
        var at:float=start
        var stale:Callable=func(component):
            if component.has("item_owner_uuid"):
                var owner:Dictionary=world.timeline.item_effect_owners.get(component.get("item_effect_owner",""),{})
                return component.has("preparation_key") and at+float(component.preparation_at_ms)<=world.timeline.display_ms and (owner.is_empty() or not NativeItems.active(owner,world.timeline.state))
            if component.get("native_grant",false):
                return component.has("preparation_key") and at+float(component.preparation_at_ms)<=world.timeline.display_ms and not grants.has(component.grant_uuid)
            var id:Variant=component.get("condition_uuid",component.get("spatial_effect_uuid"))
            return component.has("preparation_key") and id!=null and at+float(component.preparation_at_ms)<=world.timeline.display_ms and not owners.has(id) and not areas.has(id)
        if group.get("components",[]).any(stale):
            group=group.duplicate();group.components=group.components.filter(func(component):return not stale.call(component))
        result.append(group)
        start+=float(group.get("duration_ms",0.0))
    return result

static func due_groups(groups:Array,world:Node,through_ms:float)->Array:
    if is_inf(through_ms):return groups
    var result:Array=[]
    var start:float=world.timeline.group_start_ms if not world.timeline.current.is_empty() else world.timeline.display_ms
    for group in groups:
        start=maxf(start,float(group.get("preview_start_ms",start)))
        var components:Array=[]
        for component in group.get("components",[]):
            var at:float=start+float(component.preparation_at_ms) if component.has("preparation_at_ms") else float(component.get("absolute_start_ms",start+float(component.get("start_ms",0.0))))
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
    if world!=null:
        ensure_epoch(world)
        if not _prepared_resource_result.is_empty() and _prepared_resource_scope==_resource_scope(world) and _same_resource_groups(groups) \
                and (is_inf(through_ms) and is_inf(_next_resource_cue_ms) or through_ms<_next_resource_cue_ms-0.000001) \
                and world.source_lighting.native_preparation_ready:
            _native_base_groups=groups.duplicate()
            if allow_optional:prepare_optional(world,cache,budget)
            budget.used_usec+=maxi(0,Time.get_ticks_usec()-prepare_started-(budget.used_usec-charged_before))
            FrameProfile.end_phase(world.profile,"component_prepare_reuse",prepare_started)
            FrameProfile.end_phase(world.profile,"component_prepare",prepare_started)
            return _prepared_resource_result
    var stage_started:int=Time.get_ticks_usec()
    var sources: Array=[]
    for group in groups:
        if group.is_empty() or is_same(prepared_groups.get(group.get("id")),group):continue
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
        FrameProfile.end_phase(world.profile,"component_prepare_blood",stage_started)
        stage_started=Time.get_ticks_usec()
        var persistent_charged_before:int=budget.used_usec
        var required_groups:Array=groups.filter(func(group):return not group.is_empty())
        if not world.timeline.current.is_empty() and not required_groups.any(func(item):return item.get("id")==world.timeline.current.id):required_groups.push_front(world.timeline.current)
        var retained_components:Array=world.timeline.retained_components.map(func(item):return item.component)
        if not retained_components.is_empty():required_groups.append({"components":retained_components,"preparation_always_due":true})
        # Sampling may prune expired membership, so lend private shallow map
        # shells. Owner after-values and actual clocks remain Timeline-owned.
        var persistent:Array=Conditions.samples(world.timeline.condition_owners.duplicate(),world.timeline.display_ms,cache,{},false)
        persistent.append_array(Conditions.NativePersistent.spatial_samples(world.timeline.spatial_effect_owners.duplicate(),world.timeline.display_ms,cache))
        persistent.append_array(NativeItems.samples(world.timeline.item_effect_owners,world.timeline.state,world.timeline.display_ms))
        persistent.append_array(Conditions.NativePersistent.grant_samples(world.timeline.temporary_hp_owners.duplicate(),world.timeline.display_ms,cache,{}, {},false))
        _native_base_groups=groups.duplicate();_native_persistent=persistent
        var future:Array=live_requirements(preparation_groups(_native_prefetch(required_groups,world),persistent,world),world)
        var required:Array=live_requirements(preparation_groups(required_groups,persistent,world),world)
        var due:Array=due_groups(required,world,through_ms)
        var due_components:Array=[]
        for group in due:due_components.append_array(group.components)
        _native_prepare_groups=due;_native_prepare_components=due_components;_native_optical_groups=required
        var audio_errors:Array=audio.prepare(due_components,world,budget)
        var audio_ready:bool=audio.ready(due_components)
        var presentation_ready:bool=_prepare_presenters(world,due_components,budget,required)
        var outline_ready:bool=true
        var outline_actors:Dictionary={}
        for component in due_components:
            if component.get("kind")=="condition_outline":outline_actors[component.actor_uuid]=true
            elif component.get("kind")=="condition" and component.get("recipe",{}).get("persistent",{}).has("bodyOutline"):outline_actors[component.actor_uuid]=true
        for actor_id in outline_actors:
            if not outlines.prepare(world,actor_id,budget).ready:outline_ready=false
        readiness.audio=audio_ready;readiness.presenters=presentation_ready;readiness.outlines=outline_ready
        # A sound still loading never holds the picture: its voice starts when
        # its stream arrives, at its offset into the clip (AudioCues).
        result.ready=result.ready and presentation_ready and outline_ready
        result.errors.append_array(audio_errors)
        _select_optional(world,future)
        var optional:Array=_optional_components
        var retained_presenters:Dictionary={}
        for group in future:
            for component in group.get("components",[]):retained_presenters[component.id]=true
        for component in world.displayed_components:retained_presenters[component.id]=true
        _retire_presenters(world,retained_presenters,budget)
        budget.used_usec+=maxi(0,Time.get_ticks_usec()-stage_started-(budget.used_usec-persistent_charged_before))
        FrameProfile.end_phase(world.profile,"component_prepare_persistent",stage_started)
        stage_started=Time.get_ticks_usec()
        # Required owners always get the shared frame budget first. Optional
        # queries have independent readiness and cannot pause current playback.
        var native=native_spells.prepare(due,cache,world,[{"components":optional}],budget,false,required)
        FrameProfile.end_phase(world.profile,"component_prepare_sources",stage_started)
        stage_started=Time.get_ticks_usec()
        var hits=native_hits.prepare(world,due_components,cache,optional,budget,false)
        readiness.native_sources=native.ready;readiness.native_hits=hits.ready
        FrameProfile.end_phase(world.profile,"component_prepare_hits",stage_started)
        result.ready=result.ready and native.ready and hits.ready
        # A required spell load owns admission before legacy constructors. The
        # latter build private hidden presenters, never permission to allocate
        # later inside sample(). No source clock runs during preparation.
        var legacy=_prepare_legacy(world,due_components,cache,budget,result.ready)
        readiness.legacy_instances=legacy.ready
        result.ready=result.ready and legacy.ready
        result.errors.append_array(legacy.errors)
        budget.used_usec+=maxi(0,Time.get_ticks_usec()-prepare_started-(budget.used_usec-charged_before))
        if result.ready and allow_optional:prepare_optional(world,cache,budget)
        result.errors.append_array(native.errors)
        for issue in hits.issues:
            if issue.get("status")=="missing":result.errors.append(str(issue))
        if result.ready and result.errors.is_empty():
            _prepared_resource_scope=_resource_scope(world)
            _prepared_resource_groups=groups.duplicate()
            _prepared_resource_result=result
            _next_resource_cue_ms=_next_resource_cue(required,world,through_ms)
    budget.used_usec+=maxi(0,Time.get_ticks_usec()-prepare_started-(budget.used_usec-charged_before))
    if world!=null:FrameProfile.end_phase(world.profile,"component_prepare",prepare_started)
    return result

func _prepare_presenters(world:Node,components:Array,budget:Dictionary,groups:Array=[])->bool:
    var complete:bool=true
    for component in components:
        if component.get("status")=="missing":continue
        if component.get("kind") in ["damage_number","feedback_text"]:
            if numbers.has(component.id):continue
            if budget.used_usec>=budget.limit_usec:complete=false;continue
            var started:int=Time.get_ticks_usec()
            var label=Label3D.new();label.visible=false;label.text=component.text;label.font_size=component.style.fontSizePx
            label.pixel_size=128.0/float(world.rig_config.TILE_W)/Placement.PIXELS_PER_UNIT
            var font=SystemFont.new();font.font_names=PackedStringArray([component.style.fontFamily]);font.font_weight=700;label.font=font
            label.outline_size=component.style.strokeWidthPx;label.outline_modulate=Color.hex(int(component.style.strokeColor)*256+255)
            label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true;label.modulate=Color.hex(int(component.color)*256+255)
            label.render_priority=127;label.outline_render_priority=126
            world.add_child(label);numbers[component.id]=label
            budget.used_usec+=Time.get_ticks_usec()-started
        elif component.get("kind")=="geometry_projectile":
            if not _prepare_media_entry(world,component.id,component,BoltShader,budget):complete=false
        elif component.get("kind")=="world_activation":
            for path in EnvironmentMedia.world_media_paths(component,world.catalog_cache):
                if not world.textures.has(path) or not world.source_images.has(path):complete=false
            var program:Dictionary=Components.world_program(str(component.get("content_id","")),world.catalog_cache)
            for part in _world_activation_parts(component,program):
                if not _prepare_media_entry(world,part.id,component,world.ENVIRONMENT_SHADER,budget):complete=false;continue
                var entry:Dictionary=media_handles[part.id]
                entry.placement.position=part.position;entry.placement.base_height_steps=float(part.elevation_feet)/5.0
                var record:Dictionary=Catalog.world_media_record(str(component.content_id),"exit" if program.get("kind")=="portal" else "body",world.quarter,"east",0,world.catalog_cache)
                if not record.is_empty():entry.screen_rect=EnvironmentSource.quad(entry.placement,record,world.quarter,world.camera.basis).screen_rect
            if not program.get("projectile",{}).is_empty() and not _prepare_media_entry(world,component.id+":projectile",component,world.ENVIRONMENT_SHADER,budget):complete=false
    var depth_sources:Array=world.world_media_entries+media_handles.values().filter(func(entry):return not entry.get("actor_depth_band",false))
    var tracks:Array=[]
    for group in groups:tracks.append_array(group.get("actor_tracks",[]))
    if not world.prepare_actor_depth_bands(depth_sources,budget,tracks):complete=false
    return complete

func _prepare_media_entry(world:Node,id:String,component:Dictionary,shader:Shader,budget:Dictionary)->bool:
    if media_handles.has(id):return true
    if budget.used_usec>=budget.limit_usec:return false
    var started:int=Time.get_ticks_usec()
    var node=MeshInstance3D.new();node.visible=false;node.mesh=QuadMesh.new();node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var material=ShaderMaterial.new();material.shader=shader;node.material_override=material;world.add_child(node)
    var row:Dictionary={"id":component.id,"position":[0,0],"base_height_steps":0.0,"kind":"effect","facing":"SW"}
    media_handles[id]={"id":id,"node":node,"material":material,"placement":row,"role":"native_effect","layer":100,"published":false,"component_id":component.id}
    if component.get("kind")=="world_activation":
        node.sorting_use_aabb_center=false
        row.kind="resource";row.orientation="east";row.boundaries=[];row.layer=1;row.presentation_only=true
        media_handles[id].role="body";media_handles[id].layer=12;media_handles[id].source_role=1
        media_handles[id].world_media_content=str(component.get("content_id",""))
        SourceMaterial.initialize(media_handles[id])
    budget.used_usec+=Time.get_ticks_usec()-started
    return true

func _retire_presenters(world:Node,retained:Dictionary,budget:Dictionary)->void:
    for id in media_handles.keys():
        var entry:Dictionary=media_handles[id]
        if retained.has(entry.component_id) or entry.node.visible:continue
        if budget.used_usec>=budget.limit_usec:return
        var started:int=Time.get_ticks_usec()
        if entry.published:world.actor_entries.erase(entry);world.draw_order_dirty=true
        entry.node.queue_free();media_handles.erase(id)
        budget.used_usec+=Time.get_ticks_usec()-started
    for id in numbers.keys():
        if retained.has(id) or numbers[id].visible:continue
        if budget.used_usec>=budget.limit_usec:return
        var started:int=Time.get_ticks_usec()
        numbers[id].queue_free();numbers.erase(id)
        budget.used_usec+=Time.get_ticks_usec()-started

static func _publish_media(world:Node,entry:Dictionary)->void:
    if not entry.published:
        world.actor_entries.append(entry);world.draw_order_dirty=true;entry.published=true
    entry.node.visible=true

func _prepare_legacy(world:Node,components:Array,cache:Dictionary,budget:Dictionary,construct:bool)->Dictionary:
    var wanted:Dictionary={}
    for component in components:
        if component.get("kind")=="native_effect" and not component.get("native_spell",false) and component.get("status")=="available":wanted[component.id]=component
    # A cancelled candidate has no draw membership to retire. Published owners
    # stay alive until sampling the new displayed cut releases them.
    for id in handles.keys():
        if not handles[id].get("published",false) and not wanted.has(id):_release(world,id)
    var result={"ready":true,"errors":[]}
    for id in wanted:
        if handles.has(id):continue
        result.ready=false
        if not construct or budget.used_usec>=budget.limit_usec:continue
        var started:int=Time.get_ticks_usec()
        var loading=NativeSources.prepare([wanted[id].source_id],cache)
        budget.used_usec+=Time.get_ticks_usec()-started
        result.errors.append_array(loading.errors)
        if not loading.ready or budget.used_usec>=budget.limit_usec or not NativeSources.Admission.begin_mutation():continue
        started=Time.get_ticks_usec()
        var component:Dictionary=wanted[id]
        var presenter=NativePreview.new();presenter.visible=false;world.add_child(presenter)
        var issue=presenter.configure(component.source_id,cache,Components.effect_seed(component),component.get("palette",[]))
        if issue.is_empty():issue=presenter.bind_receiving()
        if not issue.is_empty():
            result.errors.append(issue);presenter.close();presenter.queue_free()
        else:
            var placement={"id":id,"position":[0,0],"base_height_steps":0.0,"kind":"effect","facing":"SW"}
            handles[id]={"node":presenter,"draws":presenter.draw_entries(id,placement,-10,100),"placement":placement,"component":component,"published":false}
            budget["required_legacy_constructors"]=budget.get("required_legacy_constructors",0)+1
        budget.used_usec+=Time.get_ticks_usec()-started
    result.ready=result.errors.is_empty() and wanted.keys().all(func(id):return handles.has(id))
    return result

func prepare_optional(world:Node,cache:Dictionary,admission:Dictionary={})->void:
    var budget:Dictionary=_native_budget if admission.is_empty() else admission
    if budget.frame!=Engine.get_process_frames():budget.frame=Engine.get_process_frames();budget.used_usec=0
    if budget.used_usec>=budget.limit_usec:return
    if _optional_owner.is_empty():return
    var owner:Array=[world.timeline.initialization_revision,world.timeline.resource_revision,world.timeline.group_start_ms,world.timeline.current,world.timeline.queue]
    if _optional_owner!=owner or world.timeline.display_ms>=_next_optional_cue_ms-0.000001:
        # A different lookahead changes optional opportunity, not the already
        # admitted current sources. Refresh only this background projection.
        if _prepared_resource_result.is_empty() or _prepared_resource_scope!=_resource_scope(world):return
        var required:Array=_native_base_groups.filter(func(group):return not group.is_empty())
        if not world.timeline.current.is_empty() and not required.any(func(group):return group.get("id")==world.timeline.current.id):required.push_front(world.timeline.current)
        _optional_blood_groups=_native_prefetch(_native_base_groups,world)
        var future:Array=live_requirements(preparation_groups(_native_prefetch(required,world),_native_persistent,world),world)
        _native_optical_groups=live_requirements(preparation_groups(required,_native_persistent,world),world)
        _select_optional(world,future)
    var started:int=Time.get_ticks_usec();var charged_before:int=budget.used_usec
    if not _optional_blood_groups.is_empty():blood.prepare(world,_optional_blood_groups,budget)
    if not _optional_components.is_empty() and budget.used_usec<budget.limit_usec:
        _prepare_presenters(world,_optional_components,budget)
        audio.prepare(_native_prepare_components+_optional_components,world,budget)
        for component in _optional_components:
            if component.get("kind")=="condition_outline":outlines.prepare(world,component.actor_uuid,budget)
        native_spells.prepare(_native_prepare_groups,cache,world,[{"components":_optional_components}],budget,true,_native_optical_groups)
        native_hits.prepare(world,_native_prepare_components,cache,_optional_components,budget)
    budget.used_usec+=maxi(0,Time.get_ticks_usec()-started-(budget.used_usec-charged_before))
    FrameProfile.end_phase(world.profile,"component_prepare_prefetch",started)

func _select_optional(world:Node,future:Array)->void:
    var required_ids:Dictionary={}
    for component in _native_prepare_components:required_ids[component.get("preparation_key",component.id)]=true
    var optional:Array=[];var seen:Dictionary={}
    for group in future:
        for component in group.get("components",[]):
            var key:String=component.get("preparation_key",component.id)
            if required_ids.has(key) or seen.has(key):continue
            if not component.get("native_spell",false) and component.get("native_hit",{}).is_empty() and component.get("kind") not in ["condition_outline","geometry_projectile","damage_number","feedback_text","audio"]:continue
            optional.append(component);seen[key]=true
    _optional_components=optional
    _optional_owner=[world.timeline.initialization_revision,world.timeline.resource_revision,world.timeline.group_start_ms,world.timeline.current,world.timeline.queue.duplicate()]
    _next_optional_cue_ms=_next_optional_cue(world)

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
        elif witness.status=="missing":pending_evidence.append({"trace_track_id":witness.id,"display_ms":world.timeline.display_ms,"reason":witness.reason})
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
        if component.kind=="world_activation":
            _sample_world_activation(world,component,live_media);continue
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
                ready=false;continue
            var handle: Dictionary=handles[component.id]
            if not handle.published:
                world.actor_entries.append_array(handle.draws)
                handle.published=true;handle.node.visible=true
                world.draw_order_dirty=true
            handle.component=component
            handle.placement.merge(row,true);handle.placement.id=component.id
            var attach: String=component.get("attachment","body")
            if component.get("requires_pose_socket",false) and not _has_socket(world,row,attach):
                handle.node.visible=false
                if not SpellPlacement.has_socket_channel(world,row,attach):
                    ready=false
                    var missing_socket:String="native_pose_socket_unavailable:"+str(component.actor_uuid)+":"+attach
                    if missing_socket not in world.presentation_errors:world.presentation_errors.append(missing_socket)
                # Explicit null current markers hide only this interval. The
                # supplied source age resumes at the next actual marker.
                continue
            if component.get("requires_pose_socket",false):handle.node.visible=true
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
            elif attach in ["body_center","head","face","hand","other_hand"]:origin=_socket(world,row,attach)
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
        elif component.kind=="geometry_projectile":
            live_media[component.id]=true
            if not media_handles.has(component.id):ready=false;continue
            var entry:Dictionary=media_handles[component.id]
            if not entry.published:entry.placement=row.duplicate()
            _publish_media(world,entry)
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
            if not numbers.has(component.id):ready=false;continue
            numbers[component.id].visible=true
            var progress=clampf(component.age_ms/maxf(.001,component.duration_ms),0,1)
            var rig: Dictionary=world.rigs[row.rig]
            var lift=(component.style.anchorLiftPx-rig.origin_y_from_ground)*row.scale+component.style.risePx*progress+component.style.fontSizePx*.5
            numbers[component.id].position=origin+world.camera.basis.y*lift*numbers[component.id].pixel_size
            numbers[component.id].modulate.a=clampf((1-progress)/maxf(.001,1.0-component.style.fadeStartFraction),0,1)
            _witness(world,component,not world.camera.is_position_behind(numbers[component.id].global_position) and world.get_viewport().get_visible_rect().has_point(world.camera.unproject_position(numbers[component.id].global_position)))
        elif component.kind=="material_flash": _witness(world,component,_actor_visible(world,component.actor_uuid))
    for id in handles.keys():
        if handles[id].published and not alive.has(id): _release(world,id)
    for id in numbers:
        if not live_numbers.has(id):numbers[id].visible=false
    for id in media_handles:
        if not live_media.has(id):media_handles[id].node.visible=false
    audio.sample(world,sounds,world.timeline.display_ms,world.playback_speed,world.timeline.paused or world.timeline.waiting_for_media or world.timeline.waiting_for_world,epoch)
    for voice in audio.voices.values():
        if voice.started and not voice.paused:_witness(world,voice.row,true)
    for id in world.visual_actors:
        if _actor_visible(world,id):_condition_witnesses(world,id,samples)

static func _world_activation_parts(component:Dictionary,program:Dictionary)->Array:
    if program.get("kind")=="portal" or program.get("requires_object_anchor",true):
        if component.get("origin_position")==null or component.get("elevation_feet")==null:return []
        return [{"id":component.id,"position":component.origin_position,"elevation_feet":component.elevation_feet}]
    var result:Array=[]
    var heights:Dictionary=component.get("affected_elevations_feet",{})
    for position in component.get("affected_positions",[]):
        var key:String="%d,%d"%[position[0],position[1]]
        if not heights.has(key):continue
        result.append({"id":component.id+":cell:"+key,"position":position,"elevation_feet":heights[key]})
    return result

func _sample_world_activation(world:Node,component:Dictionary,live_media:Dictionary)->void:
    var program:Dictionary=Components.world_program(str(component.get("content_id","")),world.catalog_cache)
    if not program.get("native_world_media",false):return
    var direction:Variant=component.get("direction")
    if direction==null or direction==[0,0]:
        var declared:Vector2=Placement.DIRECTIONS.get(str(program.get("default_orientation","")),Vector2.ZERO)
        if declared==Vector2.ZERO:return
        direction=[declared.x,declared.y]
    var column:int=posmod(floori(atan2(float(direction[1]),float(direction[0]))/(PI/4.0)+0.5),8)
    var orientation:String=["east","north","west","south"][floori(float(column)/2.0)]
    var role:String="body";var frame:int=0
    var age:float=float(component.age_ms)
    if program.get("kind")=="portal" and component.get("role")=="portal_exit":
        role="exit"
        var source:Dictionary=program.get("roles",{}).get(role,{})
        var opening:int=int(source.get("opening_frames",0));var hold:int=int(source.get("hold_frames",0))
        var emerge:float=float(program.get("emerge_ms",0.0));var hold_ms:float=float(program.get("exit_hold_ms",0.0))
        if age<emerge and emerge>0.0:frame=mini(maxi(0,opening-1),floori(age*float(opening)/emerge))
        elif age<emerge+hold_ms:frame=opening+posmod(floori((age-emerge)*float(source.get("fps",0.0))/1000.0),maxi(1,hold))
        else:frame=opening+hold+mini(maxi(0,int(source.get("closing_frames",0))-1),floori((age-emerge-hold_ms)*float(source.get("fps",0.0))/1000.0))
    elif program.get("kind")=="sprite":
        var frames:Array=program.get("activation_frames",[])
        if frames.is_empty():return
        frame=int(frames[mini(frames.size()-1,floori(age*float(program.get("fps",0.0))/1000.0))])
    else:return
    var offset:Array=program.get("origin_offset",[0.0,0.0])
    for part in _world_activation_parts(component,program):
        if not media_handles.has(part.id):ready=false;continue
        var entry:Dictionary=media_handles[part.id]
        var origin:Array=part.position
        var point:Array=[origin[0]+offset[0]*direction[0]-offset[1]*direction[1],origin[1]+offset[0]*direction[1]+offset[1]*direction[0]]
        var changed:bool=entry.placement.position!=point or entry.placement.base_height_steps!=float(part.elevation_feet)/5.0
        entry.placement.position=point;entry.placement.base_height_steps=float(part.elevation_feet)/5.0;entry.placement.unlit=program.get("kind")=="portal"
        if changed:entry.erase("world_media_frame_key");world.draw_order_dirty=true
        if not world.sample_world_media_frame(entry,str(component.content_id),role,orientation,frame):ready=false;continue
        live_media[part.id]=true;_publish_media(world,entry)
        entry.node.visible=entry.get("world_media_source_visible",true)
        _witness(world,component,_entry_visible(world,entry))
    if program.get("projectile",{}).is_empty():return
    var projectile_id:String=component.id+":projectile"
    var launch:float=float(component.get("launch_delay_ms",0.0));var travel:float=float(component.get("projectile_ms",0.0))
    if age<launch or age>=launch+travel or travel<=0.0 or component.get("end_position")==null:return
    if not media_handles.has(projectile_id):ready=false;return
    if component.get("end_elevation_feet")==null:return
    var projectile:Dictionary=program.projectile
    var origin:Array=component.origin_position
    var camera_pose:String=Placement.POSES[posmod(world.quarter,4)]
    var fixture_pose:String=Placement.POSES[posmod(world.quarter+floori(float(column)/2.0),4)]
    var tips:Array=projectile.get("tip_offsets_by_pose",{}).get(camera_pose,[])
    var muzzle:Array=projectile.get("muzzle_offsets_by_pose",{}).get(fixture_pose,[])
    if tips.size()!=8 or muzzle.size()!=2:return
    var destination:Array=component.end_position
    var ground_start:float=float(component.elevation_feet)/5.0
    var ground_end:float=float(component.end_elevation_feet)/5.0
    var lift:float=float(projectile.get("muzzle_height_steps",0.0))
    var first:Vector2=Placement.project(Vector2(origin[0],origin[1]),ground_start,world.quarter)+Vector2(muzzle[0],muzzle[1])
    var last:Vector2=Placement.project(Vector2(destination[0],destination[1]),ground_end+lift,world.quarter)
    var fraction:float=clampf((age-launch)/travel,0.0,1.0)
    var anchor:Vector2=first.lerp(last,fraction)
    var height:float=lerpf(ground_start+lift,ground_end+lift,fraction)
    var camera_grid:=Vector2(anchor.x/128.0+(anchor.y+64.0*height)/64.0,(anchor.y+64.0*height)/64.0-anchor.x/128.0)
    var grid:Vector2=Placement.rotate_grid(camera_grid,posmod(-world.quarter,4))
    var vector:Vector2=last-first
    var tip:Vector2=Vector2(tips[column][0],tips[column][1])
    var rotation:float=vector.angle()-tip.angle() if vector.length_squared()>0.0 else 0.0
    var shot:Dictionary=media_handles[projectile_id]
    shot.placement.position=[grid.x,grid.y];shot.placement.base_height_steps=height
    shot.placement.affine=[cos(rotation),sin(rotation),-sin(rotation),cos(rotation)]
    shot.erase("world_media_frame_key")
    if not world.sample_world_media_frame(shot,str(component.content_id),"projectile",orientation,column):ready=false;return
    # The original directional source rotates the whole quad around its authored
    # pivot; the tip vector determines angle, not an extra tip translation.
    live_media[projectile_id]=true;_publish_media(world,shot);world.draw_order_dirty=true

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
        if not selected.any(func(value):return value.condition_uuid==sample.condition_uuid):continue
        var persistent: Dictionary=sample.recipe.get("persistent",{})
        var scale:Dictionary=Conditions.scale_operation(sample)
        if not scale.is_empty():
            var observed:Dictionary=world.visual_actors[actor_id].get("sampled_pose",{}).get("body_scale",{})
            if observed.get("owners",[]).any(func(owner):return owner==scale):
                _witness(world,{"id":"condition:"+sample.condition_uuid+":bodyScale"},true)
        var poses:Array=persistent.get("activityPoses",[])
        if not poses.is_empty():
            var actor:Dictionary=world.timeline.presentation_state().actors.get(actor_id,{})
            var activity:String=world.displayed_samples.get(actor_id,{}).get("activity","idle")
            var rig:String=world.visual_actors[actor_id].row.rig
            var pose=Conditions.ConditionPose.select(actor,rig,activity,world.catalog_cache,world.timeline.condition_owners)
            if pose.get("condition_uuid")==sample.condition_uuid and world.playbacks[actor_id].clip==pose.get("clip"):
                for i in poses.size():
                    if poses[i].rigId==rig and poses[i].activity==activity:
                        _witness(world,{"id":"condition:"+sample.condition_uuid+":activityPoses:"+str(i)},true)
        for mechanism in ["bodyColor","alphaMultiplier","bodyRamp","bodyOutline","bodyPose","frozenPose"]:
            if persistent.get(mechanism)==null:continue
            if mechanism=="bodyRamp" and (persistent.bodyRamp.get("mapping")!="flowing_film" or not world.textures.has(world.resources.get(persistent.bodyRamp.get("texture")))):continue
            if mechanism=="bodyOutline" and (not outlines.owners.has(actor_id) or not outlines.owners[actor_id].drawn):continue
            if mechanism in ["bodyPose","frozenPose"]:
                var displayed:Dictionary=world.displayed_samples.get(actor_id,{})
                if not displayed.is_empty() and not displayed.get("captured",false):continue
                var actor: Dictionary=world.timeline.presentation_state().actors.get(actor_id,{})
                var rig:String=world.visual_actors[actor_id].row.rig
                var pose=Conditions.pose(actor,rig,world.catalog_cache,world.timeline.condition_owners)
                if pose.get("condition_uuid")!=sample.condition_uuid or world.playbacks[actor_id].clip!=pose.get("clip"):continue
                if pose.get("captured",false):
                    var clip:Dictionary=world.rigs[rig].clips[pose.clip]
                    var frame:int=mini(int(world.playbacks[actor_id].sample_seconds*clip.fps),int(clip.frames)-1)
                    if frame!=pose.frame or world.visual_actors[actor_id].row.facing!=pose.world_facing:continue
            _witness(world,{"id":"condition:"+sample.condition_uuid+":"+mechanism},true)

func _release(world: Node, id: String) -> void:
    var handle: Dictionary=handles[id]
    if handle.get("published",false):
        for draw in handle.draws:world.actor_entries.erase(draw)
        world.draw_order_dirty=true
    handle.node.close();handle.node.queue_free();handles.erase(id)

func close(world: Node) -> void:
    native_spells.close(world)
    native_hits.close()
    blood.close(world)
    outlines.close(world)
    _prepared_resource_scope=[];_prepared_resource_groups=[];_prepared_resource_result={};_next_resource_cue_ms=-INF;_next_optional_cue_ms=INF
    _resource_membership_revision+=1
    for id in handles.keys(): _release(world,id)
    for label in numbers.values(): label.queue_free()
    numbers.clear()
    for entry in media_handles.values():world.actor_entries.erase(entry);entry.node.queue_free()
    media_handles.clear();audio.close()
    prepared_groups.clear();pending_evidence=[]
    _native_prepare_groups=[];_native_optical_groups=[];_native_prepare_components=[];_native_base_groups=[];_native_persistent=[]
    _native_budget={"frame":-1,"used_usec":0,"limit_usec":NATIVE_CONSTRUCTION_USEC}
    _optional_components=[];_optional_blood_groups=[];_optional_owner=[]
