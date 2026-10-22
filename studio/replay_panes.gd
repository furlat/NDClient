extends RefCounted
## Stable viewport owners for offline playback. Mutable render state is never shared.
const Play=preload("res://play.gd")
const Admission=preload("res://presentation/native_source_admission.gd")
const BackgroundRelease=preload("res://presentation/background_release.gd")

static func viewport()->SubViewport:
    var view=SubViewport.new();view.size=Vector2i(1440,430);view.own_world_3d=true
    view.handle_input_locally=false;view.gui_disable_input=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    return view

static func discard(pane:Dictionary)->void:
    if pane.is_empty() or not is_instance_valid(pane.viewport):return
    pane.viewport.audio_listener_enable_3d=false
    if is_instance_valid(pane.world):
        pane.world.component_renderer.audio.set_enabled(false)
        pane.world.timeline.paused=true
        freeze(pane,true)
    # Its Play host's data is dropped on a worker after ordinary teardown.
    BackgroundRelease.release_after_exit(pane.viewport,[pane.get("index",{})])
    pane.viewport.queue_free()

static func freeze(pane:Dictionary,value:bool)->void:
    if pane.is_empty():return
    if value:
        Play.NativeStartup.release(pane.world)
        if not pane.get("frozen",[]).is_empty():return
        pane.frozen=[]
        var views:Array=[pane.viewport]
        views.append_array(pane.viewport.find_children("*","SubViewport",true,false))
        for view in views:
            pane.frozen.append([view,view.render_target_update_mode])
            view.render_target_update_mode=SubViewport.UPDATE_DISABLED
        pane.world.process_mode=Node.PROCESS_MODE_DISABLED
    else:
        pane.world.process_mode=Node.PROCESS_MODE_INHERIT
        for item in pane.get("frozen",[]):
            if is_instance_valid(item[0]):item[0].render_target_update_mode=item[1]
        pane.frozen=[]

## Only reference settings used by the composed renderer. Its source focus and
## requested quarter belong to the actual row/sample, not the reference pose.
static func optical_settings(reference:Node3D)->Array:
    return [reference.get_viewport().size,reference.camera.size,reference.camera.keep_aspect,
        reference.wall_mode,reference.grid_visible,reference.native_spell_hit_material,
        reference.source_depth,reference.source_normals,reference.character_light_profile,
        reference.light_strength,reference.fire_light_flicker,reference.light_cap_enabled]

static func prepare(parent:Node,restored:RefCounted,source:Dictionary,reference:Node3D,
        spare:Dictionary,budget:int,share_sources:bool,retain_view:bool,target_quarter:int=-1,preserve_focus:bool=false)->Dictionary:
    var view_quarter:int=reference.quarter if target_quarter<0 else posmod(target_quarter,4)
    var pane={}
    if not spare.is_empty():
        if share_sources and is_same(spare.index,source) \
            and spare.world.source_depth==reference.source_depth and spare.world.source_normals==reference.source_normals:
            freeze(spare,false)
            spare.viewport.audio_listener_enable_3d=false
            spare.world.component_renderer.audio.set_enabled(false)
            if spare.world.try_reset_hidden_playback(restored):pane=spare
            else:discard(spare)
        else:discard(spare)
    var reused=not pane.is_empty()
    if not reused:
        var view=viewport();parent.add_child(view)
        var host=Play.new();host.external_playback=true;host.external_clock=false
        host.component_renderer.audio.set_enabled(false)
        host.catalog_cache=Play.Catalog.source_snapshot(source.cache)
        if share_sources:
            # Same existing source-snapshot contract as physical media sharing.
            # Mutable occurrences/readiness jobs remain private to each renderer.
            Admission.share_completed(reference.component_renderer.native_spells._resource_cache,host.component_renderer.native_spells._resource_cache)
        host.media_warmup.budget_bytes=budget
        if share_sources:Play.MediaWarmup.share(host.media_warmup,reference.media_warmup)
        else:Play.MediaWarmup.physical(host.media_warmup).source_revision=Play.MediaWarmup.physical(reference.media_warmup).source_revision+1
        host.attach_media_sources()
        pane={"world":host,"viewport":view,"index":source,"frozen":[]}
    # An exact same-cut reuse still has to adopt a resized reference target.
    pane.viewport.size=reference.get_viewport().size
    var owner:Node3D=pane.world
    owner.external_clock=false
    # Host rendering allowance is shared even during an authoring reload, when
    # source residency must deliberately remain independent.
    owner.preparation_admission=reference.preparation_admission
    Play.MediaWarmup.physical(owner.media_warmup).preparation_admission=reference.preparation_admission
    owner.native_startup_plan=source.native_startup_plan if source.has("native_startup_plan") else Play.NativeStartup.recording_plan(source.get("rows",[]))
    owner.native_startup_requested_ms=restored.display_ms
    owner.media_warmup.budget_bytes=budget
    owner.media_warmup.encounter_override=source.get("media_preload",{})
    if share_sources:
        owner.presentation_mutes=reference.presentation_mutes.duplicate()
        owner.presentation_solo=reference.presentation_solo.duplicate()
    # A reused pane still owns its published static quarter. Change it through
    # the ordinary prepared view publication, preserving source/billboard basis.
    if not reused:owner.quarter=view_quarter;owner.requested_quarter=view_quarter
    owner.wall_mode=reference.wall_mode;owner.grid_visible=reference.grid_visible
    owner.source_depth=reference.source_depth;owner.source_normals=reference.source_normals
    if not reused:pane.viewport.add_child(owner)
    owner.native_spell_hit_material=reference.native_spell_hit_material
    if owner.character_light_profile!=reference.character_light_profile:
        owner.character_light_profile=reference.character_light_profile
        owner.media_warmup.light_profile=reference.character_light_profile
        owner.media_plan_key=[]
    owner.light_strength=reference.light_strength;owner.source_lighting.light_strength=reference.light_strength
    owner.fire_light_flicker=reference.fire_light_flicker;owner.source_lighting.fire_light_flicker=reference.fire_light_flicker
    owner.light_cap_enabled=reference.light_cap_enabled
    owner.camera.keep_aspect=reference.camera.keep_aspect
    owner.camera.size=reference.camera.size if retain_view else 6.0
    if not (reused and preserve_focus):
        owner.camera_focus=reference.camera_focus;owner.initial_focus=retain_view
    owner.playback_speed=reference.playback_speed
    owner.playback_end_ms=source.get("presentation_end_ms",source.duration_ms)
    owner.position_camera()
    if not reused:owner.install_playback(restored)
    else:owner.request_view(view_quarter)
    pane.reused=reused
    return pane
