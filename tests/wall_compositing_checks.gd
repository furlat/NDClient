extends SceneTree
const ViewPublication=preload("res://tests/view_publication.gd")
# Real recorded wall art: compare opacity against the solid painter result,
# including joins, original translucent edges, and changed camera/viewport.
const Player = preload("res://play.tscn")
var checks = 0
var failures: Array = []
var measurements: Array = []
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok: failures.append(message); print("WALL_COMPOSITING_FAIL ",message)
func _initialize() -> void: run.call_deferred()
func capture() -> Image:
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
func walls(scene: Node, opacity: float, mask: bool) -> void:
    for entry in scene.static_entries:
        if entry.placement.kind in ["wall","cliff"] and entry.role != "shadow":
            entry.material.set_shader_parameter("wall_opacity",opacity)
            entry.material.set_shader_parameter("wall_mask_enabled",mask)
func compare(a: Image, b: Image, base: Image = null, opacity: float = 1.0) -> Dictionary:
    var error = 0.0
    var maximum = 0.0
    var samples = 0
    var bad = 0
    for y in range(0,a.get_height(),2):
        for x in range(0,a.get_width(),2):
            var actual = a.get_pixel(x,y)
            var expected = b.get_pixel(x,y)
            if base != null:
                var background = base.get_pixel(x,y)
                if Vector3(expected.r-background.r,expected.g-background.g,expected.b-background.b).length() < .04: continue
                expected = background.srgb_to_linear().lerp(expected.srgb_to_linear(),opacity).linear_to_srgb()
            var delta = maxf(absf(actual.r-expected.r),maxf(absf(actual.g-expected.g),absf(actual.b-expected.b)))
            error += delta; maximum = maxf(maximum,delta); samples += 1
            if delta > .025: bad += 1
    return {"mean":error/maxi(1,samples),"maximum":maximum,"samples":samples,"bad":bad}

func admission_diagnostic(scene:Node)->Dictionary:
    # Failure-only reads of the same preparation owners as the native gates.
    # Do not invoke _detailed_frame_context: it consumes profiling counters.
    var pending:Dictionary={}
    if scene.pending_world!=null:
        var candidate=scene.pending_world
        pending={"phase":candidate.phase,"prepared":candidate.prepared,"admitted":candidate.admitted,"initial":candidate.initial,
            "epoch":candidate.epoch,"quarter":candidate.quarter,"actor_binding_cursor":candidate.binding_cursor,
            "actor_binding_total":candidate.actor_bindings.size(),"blocked_actor":candidate.blocked_actor.duplicate(true),
            "blocked_source":candidate.blocked_source.duplicate(true),"blood_rows":candidate.result.get("blood_rows",{}).size()}
        if candidate.binding_cursor<candidate.actor_bindings.size():
            var binding:Dictionary=candidate.actor_bindings[candidate.binding_cursor]
            var value:Dictionary=binding.value
            var missing:Array=[]
            for path in [value.path]+value.get("geometry",{}).get("textures",{}).values():
                if not scene.textures.has(path) and path not in missing:missing.append(path)
            pending.binding={"path":value.path,"prepared":not binding.get("prepared",{}).is_empty(),"missing_textures":missing}
        var blood=scene.component_renderer.blood
        var waiting:Array=[];var ready:int=0
        for key in candidate.blood_preparation.handles:
            var record:Dictionary=candidate.blood_preparation.handles[key]
            if record.get("removed",false):continue
            var held:Dictionary=record.get("handle",{})
            if held.get("ready",false):ready+=1;continue
            if waiting.size()==4:continue
            var callback:Callable=held.get("draw_callback",Callable())
            waiting.append({"key":key,"slot":held.get("slot",-1),"generation":held.get("generation",-1),
                "borrowed":record.get("borrowed",false),"draw_wait":held.get("draw_wait",-1),
                "draw_wait_owned":blood._draw_waits.has(held.get("draw_wait",-1)),
                "callback_connected":callback.is_valid() and RenderingServer.frame_post_draw.is_connected(callback)})
        var admission=scene.component_renderer.BloodRenderer.Admission
        pending.blood={"ready":blood.ready,"resources_ready":blood.resources_ready,"ready_handles":ready,
            "total_handles":candidate.blood_preparation.handles.size(),"pending_examples":waiting,
            "loading_path":admission.loading_path,"settling":admission.settling,"material_job":not admission._material_job.is_empty()}
    return {"recording_ready":scene.session.recording_ready,"session_issue":scene.session.issue,"timeline_empty":scene.timeline.state.is_empty(),
        "waiting_for_world":scene.timeline.waiting_for_world,"sequence":scene.timeline.sequence,"display_ms":scene.timeline.display_ms,
        "world_revision":scene.world_revision,"timeline_world_revision":scene.timeline.world_revision,
        "world_epoch":scene.world_prepare_epoch,"timeline_epoch":scene.timeline.initialization_revision,
        "component_ready":scene.component_renderer.ready,"component_leaves":scene.component_renderer.readiness.duplicate(true),
        "media_gate":scene.media_gate.duplicate(true),"media_issue":scene.media_issue,"errors":scene.presentation_errors.duplicate(),
        "native_startup":scene.native_startup.duplicate(true),"pending_world":pending}

func run() -> void:
    # Reproduce the former multisample edge instability separately. The default
    # lane exercises the project's actual nearest sprite rasterization.
    if "--no-msaa" in OS.get_cmdline_user_args(): root.msaa_3d = Viewport.MSAA_DISABLED
    if "--msaa-4x" in OS.get_cmdline_user_args(): root.msaa_3d = Viewport.MSAA_4X
    if "--background-check" in OS.get_cmdline_user_args():
        root.unfocusable = true; root.position = Vector2i(-16000,-16000)
    var scene = Player.instantiate()
    scene.timeline.paused = true
    root.add_child(scene)
    var deadline = Time.get_ticks_msec()+60000
    while not scene.session.recording_ready and scene.session.issue.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
    # Environment textures alone do not admit the initial actor/world source
    # generation. The ordinary Play process must finish that full boundary
    # before this intentionally frozen fixture drives quarter publication.
    while not scene.playback_prepared() and scene.session.issue.is_empty() and scene.media_issue.is_empty() and scene.presentation_errors.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
    await RenderingServer.frame_post_draw
    var prepared:bool=scene.playback_prepared() and scene.presentation_errors.is_empty() and scene.media_issue.is_empty()
    check(prepared,"Actual initial world, actors and selected sources are admitted before freezing wall captures")
    if not prepared:
        print(JSON.stringify({"checks":checks,"failures":failures,"initial_admission":admission_diagnostic(scene)}))
        scene.session.close()
        scene.queue_free();await process_frame;quit(1);return
    # recording_ready admits the initialization, not every compiled group's
    # promised media handoff. Keep its producer alive through full admission.
    scene.session.close()
    scene.set_process(false); scene.hud.hide()
    scene.wall_mode = "translucent"
    check(scene.session.issue.is_empty() and not scene.timeline.state.is_empty(),"Recorded Crypt initializes")
    if scene.timeline.state.is_empty(): quit(1); return
    for q in range(4):
        root.size = Vector2i(1440,900) if q%2 == 0 else Vector2i(1280,720)
        scene.camera.size = 12.0 if q%2 == 0 else 10.0
        scene.camera_focus += Vector3(.2,0,-.1)
        check(await ViewPublication.finish(scene,q),"Requested camera quarter publishes")
        walls(scene,1.0,false)
        var original = await capture()
        var repeated = await capture()
        var repeat_error = compare(repeated,original)
        walls(scene,1.0,true)
        var solid = await capture()
        walls(scene,0.0,true)
        var background = await capture()
        walls(scene,.28,true)
        var faded = await capture()
        walls(scene,.28,false)
        var legacy = await capture()
        var solid_error = compare(solid,original)
        var fade_error = compare(faded,solid,background,.28)
        var legacy_error = compare(legacy,solid,background,.28)
        check(solid_error.maximum < .005,"Camera %d has no opaque holes from ownership-mask edges: %s" % [q,solid_error])
        check(fade_error.samples>1000,"Camera %d exercises painted wall pixels" % q)
        check(fade_error.mean < .006 and fade_error.bad < fade_error.samples*.03,"Camera %d applies wall opacity once across joins: %s" % [q,fade_error])
        check(legacy_error.mean > fade_error.mean*2,"Camera %d regression catches separate per-wall alpha: %s" % [q,legacy_error])
        measurements.append({"quarter":q,"unchanged_frame":repeat_error,"opaque":solid_error,"faded":fade_error,"old_separate_alpha":legacy_error})
        faded.save_png("res://.captures/walls/composited-%d.png" % q)
        if q == 0: scene.wall_mask_viewport.get_texture().get_image().save_png("res://.captures/walls/owner-mask.png")
    for zoom in [6.7,9.1,12.8]:
        root.size = Vector2i(1373,817)
        scene.camera.size = zoom; scene.camera_focus = Vector3(4.13,0,5.27); check(await ViewPublication.finish(scene,0),"Requested camera quarter publishes")
        walls(scene,1.0,false)
        var original = await capture()
        var repeated = await capture()
        var repeat_error = compare(repeated,original)
        walls(scene,1.0,true)
        var composed = await capture()
        var error = compare(composed,original)
        if error.maximum>=.005:
            original.save_png("res://.captures/walls/opaque-mask-off-%s.png"%zoom)
            composed.save_png("res://.captures/walls/opaque-mask-on-%s.png"%zoom)
            var changed: Array=[]
            for y in range(original.get_height()):
                for x in range(original.get_width()):
                    var a=original.get_pixel(x,y); var b=composed.get_pixel(x,y)
                    if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>.005: changed.append([x,y])
            error.changed_pixels=changed
        check(error.maximum<.005,"Fractional zoom %s has no ownership-mask light leaks: %s" % [zoom,error])
        measurements.append({"zoom":zoom,"size":[1373,817],"unchanged_frame":repeat_error,"opaque":error})
    var report = {"checks":checks,"failures":failures,"msaa_3d":root.msaa_3d,"measurements":measurements}
    var suffix = "_no_msaa" if "--no-msaa" in OS.get_cmdline_user_args() else ""
    if "--msaa-4x" in OS.get_cmdline_user_args(): suffix = "_msaa_diagnostic"
    var file = FileAccess.open("res://generated/wall_compositing_checks%s.json"%suffix,FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  ")); file.close()
    print(JSON.stringify(report))
    scene.queue_free(); await process_frame
    quit(0 if failures.is_empty() else 1)
