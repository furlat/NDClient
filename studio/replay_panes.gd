extends RefCounted
## Stable viewport owners for offline playback. Mutable render state is never shared.
const Play=preload("res://play.gd")
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

static func prepare(parent:Node,restored:RefCounted,source:Dictionary,reference:Node3D,
        spare:Dictionary,budget:int,share_sources:bool,retain_view:bool)->Dictionary:
    var pane={}
    if not spare.is_empty():
        if share_sources and is_same(spare.index,source):
            freeze(spare,false)
            spare.viewport.audio_listener_enable_3d=false
            spare.world.component_renderer.audio.set_enabled(false)
            if spare.world.try_reset_hidden_playback(restored):pane=spare
            else:discard(spare)
        else:discard(spare)
    var reused=not pane.is_empty()
    if not reused:
        var view=viewport();view.size=reference.get_viewport().size;parent.add_child(view)
        var host=Play.new();host.external_playback=true;host.external_clock=false
        host.component_renderer.audio.set_enabled(false)
        host.catalog_cache=Play.Catalog.source_snapshot(source.cache)
        host.media_warmup.budget_bytes=budget
        if share_sources:Play.MediaWarmup.share(host.media_warmup,reference.media_warmup)
        else:Play.MediaWarmup.physical(host.media_warmup).source_revision=Play.MediaWarmup.physical(reference.media_warmup).source_revision+1
        host.attach_media_sources()
        pane={"world":host,"viewport":view,"index":source,"frozen":[]}
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
    if not reused:owner.quarter=reference.quarter;owner.requested_quarter=reference.quarter
    owner.wall_mode=reference.wall_mode;owner.grid_visible=reference.grid_visible
    if not reused:pane.viewport.add_child(owner)
    owner.native_spell_hit_material=reference.native_spell_hit_material
    owner.camera.size=reference.camera.size if retain_view else 6.0
    owner.camera_focus=reference.camera_focus;owner.initial_focus=retain_view
    owner.playback_speed=reference.playback_speed
    owner.playback_end_ms=source.get("presentation_end_ms",source.duration_ms)
    owner.position_camera()
    if not reused:owner.install_playback(restored)
    else:owner.request_view(reference.quarter)
    pane.reused=reused
    return pane
