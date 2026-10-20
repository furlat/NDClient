extends SceneTree
## Native source adapter checked against both independently recorded audiences.
const Journal = preload("res://sdk/journal.gd")
const Lighting = preload("res://presentation/lighting_2d.gd")
const Placement = preload("res://placement.gd")
const Cells = preload("res://sdk/fold_cells.gd")
const Fixtures = preload("res://tests/recording_fixtures.gd")
# Exact original schema16 operation ends at the [4,6] subject. The disclosed
# torch moves [10,6] -> [7,6] -> [6,6]; categories are recorded, not radiance.
const PROBES = [
    {"label":"dim","sequence":8,"source_position":[10,6],"level":2},
    {"label":"bright","sequence":13,"source_position":[7,6],"level":3},
    {"label":"very_bright","sequence":14,"source_position":[6,6],"level":4}]
var checks = 0
var failures: Array = []
var evidence: Array = []

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("OPTICAL_SOURCE_FAIL ",label)

func _initialize() -> void: run.call_deferred()

func run() -> void:
    var directory = Fixtures.journal("hide-light").get_base_dir()
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording-root="): directory = arg.trim_prefix("--recording-root=")
    var display = SubViewport.new(); display.size = Vector2i(768,512); root.add_child(display)
    var camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; display.add_child(camera)
    var page = SubViewport.new(); page.disable_3d = true; root.add_child(page)
    var second = SubViewport.new(); second.disable_3d = true; root.add_child(second)
    var adapter = Lighting.new(); adapter.attach(page); adapter.attach_page(second)
    var last_state: Dictionary = {}
    for audience in ["amber","blue"]:
        var journal = Journal.new()
        var opened = journal.open(directory.path_join(audience),true,false)
        check(opened.ok,audience+": current-schema journal opens")
        if not opened.ok: continue
        for probe in PROBES:
            var replayed = journal.replay(probe.sequence)
            check(replayed.ok,audience+": strict recorded boundary "+probe.label)
            if not replayed.ok: print(replayed); continue
            var state: Dictionary = journal.snapshot()
            var original = state.duplicate(true)
            check(state.has("light_sources"),audience+": current optical observations are explicit")
            if not state.has("light_sources"): continue
            check(not state.light_sources.is_empty(),audience+": actual illuminating source reaches this view")
            var perceived: Dictionary = Cells.values_map(state.senses.effective_light_levels)
            check(state.tiles["4,6"].resolved_light==probe.level and Cells.contains(state.senses.visible,[4,6]) \
                and perceived.get("4,6")==probe.level,audience+": original objective/current perceived category "+probe.label)
            check(state.light_sources.size()==1 and state.light_sources.values()[0].position==probe.source_position,audience+": exact disclosed source location "+probe.label)
            # Named adapter-only controls: obsolete optional footprint metadata
            # never replaces the actual public source position or radial data.
            var compact = state.duplicate(true)
            for observed in compact.light_sources.values():
                if probe.label=="bright": observed.erase("affected_tiles")
                else: observed.affected_tiles = {}
            var compact_before = compact.duplicate(true)
            check(Lighting.resolve(compact)==Lighting.resolve(state),audience+": compact source resolves exactly like archive "+probe.label)
            adapter.sync(compact)
            var cookie_deadline: int = Time.get_ticks_msec()+10000
            while adapter.sources.any(func(source):return adapter.cookie_pending(source)) and Time.get_ticks_msec()<cookie_deadline:await process_frame
            check(adapter.sources.all(func(source):return not adapter.cookie_pending(source)),audience+": exact source cookies finish preparation")
            adapter.sync(compact)
            check(adapter.nodes.size()==state.light_sources.size(),audience+": one native light per observed source, no private-inventory duplicate")
            for quarter in 4:
                var angle = PI/4+quarter*PI/2
                camera.position = Vector3(cos(angle)*20,20/sqrt(3.0),sin(angle)*20)
                camera.look_at(Vector3.ZERO)
                for zoom in [16.0,24.0]:
                    camera.size = zoom; adapter.project(camera)
                    var origin = camera.position-camera.basis.z*10
                    var ppu = camera.unproject_position(origin+camera.basis.x).distance_to(camera.unproject_position(origin))
                    for id in state.light_sources:
                        var observed: Dictionary = state.light_sources[id]
                        var light: PointLight2D = adapter.nodes[id]
                        var lift = Lighting.ExistingLighting.CARRIED_OPTICAL_LIFT_STEPS if observed.actor_anchored else Lighting.ExistingLighting.UNREGISTERED_OPTICAL_LIFT_STEPS
                        var position = Vector3(observed.position[0],(observed.base_height_steps+lift)*Placement.HEIGHT_UNIT,observed.position[1])
                        check(light.enabled and light.position.is_equal_approx(camera.unproject_position(position)),audience+": optical position retained across camera/zoom")
                        check(is_equal_approx(light.height,56.0*2.0/Placement.PIXELS_PER_UNIT*ppu),audience+": approved native normal height")
                        var radius = maxf(floor(float(observed.bright_radius_feet+observed.dim_radius_feet)/5.0),1.0)
                        check(is_equal_approx(light.texture_scale*light.texture.get_width(),radius*2*ppu),audience+": engine feet calibrate native diameter")
                        check(light.color==(Lighting.TORCH_COLOUR if observed.appearance=="torch" else Color.WHITE),audience+": explicit optical appearance calibrates colour")
                        check(is_equal_approx(light.energy,2.0),audience+": existing reference intensity retained")
            check(state==original,audience+": presentation leaves recorded gameplay state unchanged")
            check(compact==compact_before,audience+": presentation preserves compact input")
            evidence.append({"audience":audience,"sequence":probe.sequence,"label":probe.label,
                "objective":state.tiles["4,6"].resolved_light,"perceived":perceived.get("4,6"),
                "sources":state.light_sources.size()})
            last_state = compact
    if not last_state.is_empty() and not adapter.sources.is_empty():
        # Named adapter perturbations: no outcome or replay facts are fabricated.
        # They check identity privacy and disappearance at its public boundary.
        var hidden = last_state.duplicate(true)
        var before = adapter.sampled.duplicate(true)
        var disclosed_positions: Array = hidden.light_sources.values().map(func(source):return source.position)
        for observed in hidden.light_sources.values():
            observed.anchor_entity_uuid = null; observed.anchor_item_uuid = null
        hidden.senses.visible=Cells.mask(Cells.mask_points(hidden.senses.visible).filter(func(point):return point not in disclosed_positions))
        var private_before: PackedByteArray=var_to_bytes(hidden)
        adapter.sync(hidden); adapter.project(camera)
        for id in before:
            check(adapter.sampled[id].position==before[id].position,"Withheld identities preserve optical elevation and location")
        check(var_to_bytes(hidden)==private_before,"Withheld-identity control preserves its optical data and current cell mask")
        var empty = last_state.duplicate(true); empty.light_sources = {}
        adapter.sync(empty); adapter.project(camera)
        check(adapter.nodes.is_empty() and adapter.canvas_sources().is_empty(),"Explicit empty observation removes lights despite retained lit inventory")
        await process_frame
        check(second.get_child_count()==0,"Removal clears additional receiving pages")
        adapter.sync(last_state); adapter.project(camera)
        check(adapter.nodes.size()==last_state.light_sources.size(),"Replay seek restores only current disclosed optical sources")
    adapter.clear_pages()
    for node in [display,page,second]: node.queue_free()
    await process_frame
    var report = {"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Independent real Amber/Blue server journals, strict reducer, native source position/height/radius/colour/energy across four cameras and two zooms. Named privacy/removal adapter perturbations. No pixel-equivalence or gameplay light solver claim."}
    FileAccess.open("res://generated/optical_light_source_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("OPTICAL_LIGHT_SOURCES ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
