extends SceneTree
## Real Studio → shared player → published native-compatible receiving inputs.
## No unused PointLight2D page is manufactured in the production light-table path.
const Studio = preload("res://studio/studio.gd")
const Fixtures = preload("res://tests/recording_fixtures.gd")
const Cells = preload("res://sdk/fold_cells.gd")
const Journal = preload("res://sdk/journal.gd")
const Lighting = preload("res://presentation/lighting_2d.gd")
const Placement = preload("res://placement.gd")
const PROBES = preload("res://tests/optical_light_source_checks.gd").PROBES
# Supply ordinary library metadata around the unchanged durable journals. The
# production selector/loader still owns both independent views and every seek.
class FixtureStudio extends Studio:
    func _discover_cases() -> void:
        super._discover_cases()
        case_records=[Fixtures.public_case("hide-light")];case_paths.clear()
        for perspective in case_records[0].perspectives:case_paths.append(perspective.journal)
        _populate_capability(0)
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
func original_prefix(audience: String,sequence: int) -> Dictionary:
    var journal=Journal.new()
    var opened: Dictionary=journal.open(Fixtures.journal("hide-light",audience),true,false)
    check(opened.ok,audience+": independent original SDK journal opens")
    if not opened.ok:return {}
    var replayed: Dictionary=journal.replay(sequence)
    check(replayed.ok,audience+": independent SDK fold reaches actual represented cursor "+str(sequence))
    return journal.snapshot() if replayed.ok else {}
func receiving(world: Node,state: Dictionary,label: String) -> Array:
    var lights=world.source_lighting
    var sources: Array=lights.canvas_sources()
    var expected: Array=state.light_sources.keys();expected.sort()
    var actual: Array=sources.map(func(source):return str(source.id));actual.sort()
    check(actual==expected and not actual.is_empty(),label+": shared player publishes exactly the disclosed receiving sources")
    check(sources.all(func(source):return source.enabled and source.texture is Texture2D and source.energy>0.0),label+": actual receiving sources are enabled with prepared native cookies")
    var table_ids: Array=Array(world.light_table.ids);table_ids.sort()
    var enabled: Array=sources.filter(func(source):return source.enabled).map(func(source):return str(source.id))
    enabled.append_array(lights.canvas_directionals().filter(func(source):return source.enabled).map(func(source):return str(source.id)));enabled.sort()
    check(table_ids==enabled and world.light_table.count==enabled.size() and world.light_table.rows.size()==enabled.size()*Studio.Play.LightTable.FLOATS \
        and world.light_table.uploads>0,label+": actual uploaded GPU receiving table contains exactly the enabled source identities")
    var camera: Camera3D=world.camera
    var centre: Vector3=camera.global_position-camera.global_basis.z*10.0
    var ppu: float=camera.unproject_position(centre+camera.global_basis.x).distance_to(camera.unproject_position(centre))
    for source in sources:
        if not state.light_sources.has(source.id):continue
        var observed: Dictionary=state.light_sources[source.id]
        var lift: float=Lighting.ExistingLighting.CARRIED_OPTICAL_LIFT_STEPS if observed.actor_anchored else Lighting.ExistingLighting.UNREGISTERED_OPTICAL_LIFT_STEPS
        var position:=Vector3(observed.position[0],(observed.base_height_steps+lift)*Placement.HEIGHT_UNIT,observed.position[1])
        var outer: float=maxf(floor(float(observed.bright_radius_feet+observed.dim_radius_feet)/5.0),1.0)
        check(source.world_position.is_equal_approx(position) and source.screen_position.is_equal_approx(camera.unproject_position(position)),label+": exact public optical location reaches the displayed camera")
        check(is_equal_approx(source.height,56.0*2.0/Placement.PIXELS_PER_UNIT*ppu) and is_equal_approx(source.texture_scale*source.texture.get_width(),outer*2.0*ppu),label+": approved normal height and authoritative feet radius reach receiving inputs")
        check(source.color==(Lighting.TORCH_COLOUR if observed.appearance=="torch" else Color.WHITE) \
            and is_equal_approx(source.energy,Lighting.OPTICAL_ENERGY*world.light_strength),label+": source colour and configured reference intensity reach receiving inputs")
    return sources
func capture(studio: Control,name: String) -> void:
    await process_frame; await RenderingServer.frame_post_draw
    root.get_texture().get_image().get_region(Rect2i(studio.preview.get_global_rect())).save_png("res://.captures/studio/optical-light/"+name+".png")
func run() -> void:
    root.unfocusable = true; root.position = Vector2i(-16000,-16000)
    DisplayServer.window_set_size(Vector2i(1280,720))
    DirAccess.make_dir_recursive_absolute("res://.captures/studio/optical-light")
    var studio = FixtureStudio.new(); root.add_child(studio)
    if not await settle(studio): finish(studio); return
    for audience in ["amber","blue"]:
        if studio.active_perspective!=audience:
            studio.select_perspective(audience)
            if not await settle(studio): break
        check(studio.active_perspective==audience,"Real independently captured "+audience+" perspective selected")
        for probe in PROBES:
            var boundary = 0.0
            for item in studio.index.groups:
                if item.group.operation_sequence==probe.sequence and item.group.operation_end: boundary=maxf(boundary,item.start_ms+item.group.duration_ms)
            check(boundary>0.0,audience+" "+probe.label+": exact original operation-ending boundary exists")
            # Consecutive zero-duration turn operations can share this clock.
            # Ordinary restore chooses the representable cursor; the separate
            # SDK journal below remains the value oracle for that actual prefix.
            var target: float=minf(boundary+.01,studio.index.presentation_end_ms)
            var restored: RefCounted=Studio.Recording.restore(studio.index,target)
            var expected: Dictionary=original_prefix(audience,restored.sequence)
            studio._seek(target)
            if not await settle(studio): break
            var state: Dictionary = studio.world.timeline.state
            check(state.has("light_sources") and not state.light_sources.is_empty(),audience+" "+probe.label+": committed optical data present")
            var sources: Array=receiving(studio.world,state,audience+" "+probe.label)
            check(not expected.is_empty() and state==expected and studio.world.timeline.sequence==restored.sequence,audience+" "+probe.label+": ordinary Studio cut equals the independently folded original SDK prefix")
            var perceived: Dictionary=Cells.values_map(state.senses.effective_light_levels)
            check(state.tiles["4,6"].resolved_light==probe.level \
                and Cells.contains(state.senses.visible,[4,6]) and perceived.get("4,6")==probe.level,audience+" "+probe.label+": original authoritative/current perceived probe remains unchanged")
            check(state.light_sources.size()==1 and state.light_sources.values()[0].position==probe.source_position,audience+" "+probe.label+": original disclosed torch position survives Studio publication")
            check(studio.world.presentation_errors.is_empty() and studio.world.media_issue.is_empty(),audience+" "+probe.label+": no production presentation errors")
            await capture(studio,audience+"-"+probe.label)
            evidence.append({"audience":audience,"sequence":studio.world.timeline.sequence,"label":probe.label,"native_sources":sources.size(),"receiving_table_ids":Array(studio.world.light_table.ids),"original_boundary_sequence":probe.sequence,"objective":state.tiles["4,6"].resolved_light,"perceived":perceived.get("4,6")})
        # Exact source restoration after a backwards seek, not borrowing other view state.
        studio._seek(0.0)
        if await settle(studio):
            var state: Dictionary = studio.world.timeline.state
            var expected: Dictionary=original_prefix(audience,0)
            var sources: Array=receiving(studio.world,state,audience+" backward seek")
            check(state==expected and sources.size()==expected.light_sources.size(),audience+": backward seek restores exactly the independent original initial sources/state")
    finish(studio)
func finish(studio: Control) -> void:
    var report = {"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"evidence":evidence,
        "scope":"Native Studio renders independent schema16 original journals through shared player/reducer. Current production canvas-source parameters and uploaded receiving-table IDs/counts, actual 2/3/4 observations, independent SDK prefix values, factions and reverse seek. No unused PointLight2D page or RGB gameplay oracle."}
    FileAccess.open("res://generated/studio_optical_light_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_OPTICAL_LIGHT ",JSON.stringify(report))
    studio.queue_free()
    quit(0 if failures.is_empty() else 1)
