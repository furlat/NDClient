extends RefCounted
## Stable viewport owners for offline playback. Mutable render state is never shared.
const Play=preload("res://play.gd")

static func viewport()->SubViewport:
    var view=SubViewport.new();view.size=Vector2i(1440,430);view.own_world_3d=true
    view.handle_input_locally=false;view.gui_disable_input=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    return view

static func discard(pane:Dictionary)->void:
    if not pane.is_empty() and is_instance_valid(pane.viewport):pane.viewport.queue_free()

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
        spare:Dictionary,budget:int,paired:bool,share_sources:bool,retain_view:bool)->Dictionary:
    var pane={}
    if not spare.is_empty():
        if is_same(spare.index,source):
            freeze(spare,false)
            spare.viewport.audio_listener_enable_3d=false
            spare.world.component_renderer.audio.set_enabled(false)
            if spare.world.try_reset_hidden_playback(restored):pane=spare
            else:discard(spare)
        else:discard(spare)
    var reused=not pane.is_empty()
    if not reused:
        var view=viewport();view.size=reference.get_viewport().size;parent.add_child(view)
        var host=Play.new();host.external_playback=true;host.external_clock=paired
        host.component_renderer.audio.set_enabled(false)
        host.catalog_cache=Play.Catalog.source_snapshot(source.cache)
        host.media_warmup.budget_bytes=budget
        if share_sources:
            # GPU/source values are immutable; queues, pins and budgets remain private.
            host.textures=reference.textures.duplicate()
            host.source_images=reference.source_images.duplicate()
            host.texture_last_use=reference.texture_last_use.duplicate()
            host.fixture_frame_energy=reference.fixture_frame_energy.duplicate()
            host.fixture_frame_centroids=reference.fixture_frame_centroids.duplicate()
            for path in reference.media_warmup.resident:
                host.media_warmup.resident[path]=reference.media_warmup.resident[path].duplicate()
        pane={"world":host,"viewport":view,"index":source,"frozen":[]}
    var owner:Node3D=pane.world
    owner.external_clock=paired
    owner.media_warmup.budget_bytes=budget
    owner.media_warmup.encounter_override=source.get("media_preload",{})
    if share_sources:
        owner.presentation_mutes=reference.presentation_mutes.duplicate()
        owner.presentation_solo=reference.presentation_solo.duplicate()
    owner.quarter=reference.quarter;owner.requested_quarter=reference.quarter
    owner.wall_mode=reference.wall_mode;owner.grid_visible=reference.grid_visible
    if not reused:pane.viewport.add_child(owner)
    owner.camera.size=reference.camera.size if retain_view else 6.0
    owner.camera_focus=reference.camera_focus;owner.initial_focus=retain_view
    owner.playback_speed=reference.playback_speed
    owner.playback_end_ms=source.get("presentation_end_ms",source.duration_ms)
    owner.position_camera()
    if not reused:owner.install_playback(restored)
    pane.reused=reused
    return pane
