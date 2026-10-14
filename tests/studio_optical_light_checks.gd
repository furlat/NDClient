extends SceneTree
## Real Studio → shared player → native light nodes; one independently saved view at a time.
const Studio = preload("res://studio/studio.gd")
var checks = 0
var failures: Array = []
var evidence: Array = []
func check(ok: bool,label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("STUDIO_OPTICAL_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func settle(studio: Control) -> bool:
    var deadline = Time.get_ticks_msec()+120000
    while (studio.index.is_empty() or studio.loader!=null or studio.seeker!=null or studio.installing or studio.requested_seek>=0 or studio.world.rotation_pending()) and Time.get_ticks_msec()<deadline: await process_frame
    var ready = not studio.index.is_empty() and studio.loader==null and studio.seeker==null and not studio.installing and studio.requested_seek<0 and not studio.world.rotation_pending()
    check(ready,"Studio publishes selected recording/seek/view")
    await process_frame; await process_frame; await RenderingServer.frame_post_draw
    return ready
func capture(studio: Control,name: String) -> void:
    await process_frame; await RenderingServer.frame_post_draw
    root.get_texture().get_image().get_region(Rect2i(studio.preview.get_global_rect())).save_png("res://.captures/studio/optical-light/"+name+".png")
func run() -> void:
    root.unfocusable = true; root.position = Vector2i(-16000,-16000)
    DisplayServer.window_set_size(Vector2i(1280,720))
    DirAccess.make_dir_recursive_absolute("res://.captures/studio/optical-light")
    var studio = Studio.new(); root.add_child(studio)
    if not await settle(studio): finish(studio); return
    for audience in ["amber","blue"]:
        if studio.active_perspective!=audience:
            studio.select_perspective(audience)
            if not await settle(studio): break
        check(studio.active_perspective==audience,"Real independently captured "+audience+" perspective selected")
        var descriptor: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(studio.active_directory.get_base_dir().path_join("case.json")))
        for probe in descriptor.light_probes:
            if probe.label not in ["dim","bright","very_bright"]: continue
            var boundary = 0.0
            for item in studio.index.groups:
                if item.group.operation_sequence==probe.sequence: boundary=maxf(boundary,item.start_ms+item.group.duration_ms)
            studio._seek(boundary+.01)
            if not await settle(studio): break
            var state: Dictionary = studio.world.timeline.state
            var lights = studio.world.source_lighting
            check(state.senses.has("light_sources") and not state.senses.light_sources.is_empty(),audience+" "+probe.label+": committed optical data present")
            check(lights.nodes.size()==state.senses.get("light_sources",{}).size() and not lights.nodes.is_empty(),audience+" "+probe.label+": shared player creates exactly the admitted native sources")
            check(lights.nodes.values().all(func(light):return light is PointLight2D and light.enabled),audience+" "+probe.label+": real native sources enabled")
            check(state.tiles["4,6"].resolved_light==probe.world_resolved_light and state.senses.effective_light_levels.get("4,6")==probe.observer_effective_light,audience+" "+probe.label+": authoritative probe remains unchanged")
            check(studio.world.presentation_errors.is_empty() and studio.world.media_issue.is_empty(),audience+" "+probe.label+": no production presentation errors")
            await capture(studio,audience+"-"+probe.label)
            evidence.append({"audience":audience,"sequence":studio.world.timeline.sequence,"label":probe.label,"native_sources":lights.nodes.size(),"objective":state.tiles["4,6"].resolved_light,"perceived":state.senses.effective_light_levels.get("4,6")})
        # Exact source restoration after a backwards seek, not borrowing other view state.
        studio._seek(0.0)
        if await settle(studio):
            var state: Dictionary = studio.world.timeline.state
            check(studio.world.source_lighting.nodes.size()==state.senses.get("light_sources",{}).size(),audience+": backward seek restores initial source count")
    finish(studio)
func finish(studio: Control) -> void:
    var report = {"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"evidence":evidence,
        "scope":"Native Studio renders independent schema9 server journals through shared player/reducer. Actual 2/3/4 tile observations and enabled native sources, factions and reverse seek. Screenshots retained for appearance; RGB is not used to decide rules."}
    FileAccess.open("res://generated/studio_optical_light_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_OPTICAL_LIGHT ",JSON.stringify(report))
    studio.queue_free()
    quit(0 if failures.is_empty() else 1)
