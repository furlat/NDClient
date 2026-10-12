extends SceneTree
# Actual Crypt emitter activation/art plus named presentation-height fixtures.
const Player = preload("res://play.tscn")
var checks = 0
var failures: Array = []
func check(ok: bool,label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("EMITTER_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func capture() -> Image:
    await process_frame; await process_frame; await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
static func actor_pixels(scene: Node) -> Dictionary:
    var output = {}
    for entry in scene.actor_entries:
        if entry.role=="shadow" or not entry.node.visible: continue
        var row: Dictionary = entry.placement
        if not output.has(row.id): output[row.id] = {}
        var image: Image = scene.source_images[entry.texture_path]
        var uv: Vector4 = entry.material.get_shader_parameter("frame_uv")
        var ox = roundi(uv.x*image.get_width()); var oy = roundi(uv.y*image.get_height())
        for y in range(int(entry.cell.y)):
            for x in range(int(entry.cell.x)):
                if image.get_pixel(ox+x,oy+y).a<.5: continue
                var local = Vector3((x+.5-entry.pivot.x)*entry.scale/scene.Placement.PIXELS_PER_UNIT,(entry.pivot.y-y-.5)*entry.scale/scene.Placement.PIXELS_PER_UNIT,0)
                var screen = scene.camera.unproject_position(entry.node.global_transform*local)
                output[row.id][Vector2i(screen)] = true
    return output
static func brightness(image: Image, pixels: Dictionary) -> Dictionary:
    var result = {}
    for id in pixels:
        var total = 0.0; var dark = 0
        for point in pixels[id]:
            var value = image.get_pixelv(point).get_luminance()
            total += value
            if value<.02: dark += 1
        result[id] = {"mean_luminance":total/maxi(1,pixels[id].size()),"dark_pixels":dark,"pixels":pixels[id].size()}
    return result
func run() -> void:
    root.unfocusable = true; root.position = Vector2i(-16000,-16000)
    var scene = Player.instantiate(); scene.timeline.paused = true; root.add_child(scene)
    var deadline = Time.get_ticks_msec()+90000
    while not scene.session.recording_ready and scene.session.issue.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
    scene.session.close(); await scene.presentation_updated
    while not scene._media_ready({}) and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline: await scene.presentation_updated
    check(scene._media_ready({}) and scene.presentation_errors.is_empty(),"Actual Crypt and exact original fixture/character media prepare")
    if not scene._media_ready({}): quit(1); return
    scene.set_process(false); scene.hud.hide(); scene.camera_focus = Vector3(4,0,5); scene.camera.size = 8
    scene.position_camera(); scene.wall_mode = "hidden"; scene.update_wall_visibility(); scene._sort_draws(); scene._sample_actors(); scene._sample_fixtures()
    var original: Dictionary = scene.timeline.state.duplicate(true)
    var anchors = {}; for row in scene.actor_rows: anchors[row.id] = row
    var pixels = actor_pixels(scene)
    var native_sources: Array = scene.source_lighting.sources.duplicate(true)
    check(native_sources.size()==4,"Exactly two canonical carried and two fixture emitters, without duplication")
    var sources_by_id = {}; for source in native_sources: sources_by_id[source.item_uuid] = source
    var folder = "res://.captures/emitter-placement/"; DirAccess.make_dir_recursive_absolute(folder)
    var comparisons = {}
    for lift in [1.0,2.0,2.5]:
        scene.source_lighting.carried_optical_lift_steps = lift
        var heights: Dictionary = {} if lift==1.0 else scene.fixture_heights
        scene.source_lighting.sample(anchors,scene.fixture_energy,heights)
        var shown = await capture()
        shown.save_png(folder+"carried-"+str(lift)+".png")
        comparisons[str(lift)] = brightness(shown,pixels)
        for i in range(native_sources.size()):
            var source: Dictionary = native_sources[i]; var sample:Dictionary = scene.source_lighting.sampled[source.item_uuid]; var point:Vector3=sample.position; var node:OmniLight3D=scene.source_lighting.nodes[source.item_uuid]
            check(is_equal_approx(point.x,source.position.x) and is_equal_approx(point.z,source.position.z),"Optical elevation preserves backend radial XY at "+str(lift))
            check(is_equal_approx(node.omni_range,source.outer) and scene.source_lighting.sources[i]==source,"Optical elevation preserves canonical radius metadata and native optical range at "+str(lift))
    scene.camera.size = 4.0
    scene.position_camera(); scene._sample_actors()
    for lift in [2.0,2.5]:
        scene.source_lighting.carried_optical_lift_steps = lift
        scene.source_lighting.sample(anchors,scene.fixture_energy,scene.fixture_heights)
        (await capture()).save_png(folder+"calibrated-close-"+str(lift)+".png")
    for entry in scene.actor_entries:
        entry.material.set_shader_parameter("calibrated_component_receiver",false)
    (await capture()).save_png(folder+"old-camera-close-2.5.png")
    for entry in scene.actor_entries:
        entry.material.set_shader_parameter("calibrated_component_receiver",true)
        entry.material.set_shader_parameter("has_component_geometry",false)
    (await capture()).save_png(folder+"flat-close-2.5.png")
    for entry in scene.actor_entries:
        entry.material.set_shader_parameter("has_component_geometry",not entry.get("geometry_paths",{}).is_empty())
        entry.material.set_shader_parameter("authored_base_light",1.0)
    var source_environment:Environment
    for child in scene.get_children():
        if child is WorldEnvironment:source_environment=child.environment
    var source_ambient=source_environment.ambient_light_energy;source_environment.ambient_light_energy=0.0
    for node in scene.source_lighting.nodes.values():node.visible=false
    (await capture()).save_png(folder+"unlit-source-tint-close.png")
    for node in scene.source_lighting.nodes.values():node.visible=true
    source_environment.ambient_light_energy=source_ambient
    for entry in scene.actor_entries: scene.source_lighting.apply(entry.material)
    scene.camera.size = 8.0; scene.position_camera(); scene._sample_actors()
    for id in pixels:
        check(comparisons["2.0"][id].mean_luminance>comparisons["1.0"][id].mean_luminance,"Above-avatar source improves actual body readability: "+original.actors[id].name)
    scene.source_lighting.carried_optical_lift_steps = 2.5
    for object in scene.timeline.state.objects.values():
        if object.item.get("is_lit")==true: object.item.is_lit = false
    scene.source_lighting.sync(scene.timeline.state); scene.source_lighting.sample(anchors)
    check(scene.source_lighting.sources.size()==2,"Extinguished world fixtures leave exactly the two carried lights")
    for entry in scene.fixture_entries: entry.node.visible = false
    var self_lit = await capture(); self_lit.save_png(folder+"carried-only.png")
    var self_stats = brightness(self_lit,pixels)
    for id in pixels: check(self_stats[id].mean_luminance>.015,"Actual carried source illuminates its owner's original body: "+original.actors[id].name)
    for actor in scene.timeline.state.actors.values():
        for item in actor.get("controlled_items",[]):
            if item.get("is_lit")==true: item.is_lit = false
    scene.source_lighting.sync(scene.timeline.state); scene.source_lighting.sample(anchors)
    check(scene.source_lighting.sources.is_empty(),"Native extinguished after-values remove every emitter")
    var indirect = await capture(); indirect.save_png(folder+"all-extinguished.png")
    var indirect_stats = brightness(indirect,pixels)
    for id in pixels: check(indirect_stats[id].mean_luminance>.02,"Native ambient keeps an extinguished scene readable: "+original.actors[id].name)
    var environment: Environment
    for child in scene.get_children():
        if child is WorldEnvironment: environment = child.environment
    var ambient_energy = environment.ambient_light_energy
    environment.ambient_light_energy = 0.0
    var dark_stats = brightness(await capture(),pixels)
    for id in pixels: check(dark_stats[id].mean_luminance<.002,"Isolated zero-ambient fixture has no stray self-emission: "+original.actors[id].name)
    environment.ambient_light_energy = ambient_energy
    scene.timeline.state = original.duplicate(true); scene.source_lighting.sync(scene.timeline.state)
    for entry in scene.fixture_entries: entry.node.visible = true
    for id in anchors:
        var raised: Dictionary = anchors[id].duplicate(true); raised.base_height_steps += 2; raised.visual_height += .5
        anchors[id] = raised
    scene.source_lighting.sample(anchors,scene.fixture_energy,scene.fixture_heights)
    for i in range(scene.source_lighting.sources.size()):
        var source: Dictionary = scene.source_lighting.sources[i]
        if not source.actor_uuid.is_empty():
            var row: Dictionary = anchors[source.actor_uuid]
            check(is_equal_approx(scene.source_lighting.sampled[source.item_uuid].position.y,(row.base_height_steps+row.visual_height+2.5)*scene.Placement.HEIGHT_UNIT),"Carried anchor follows displayed raised support and jump lift exactly")
        else:
            check(is_equal_approx(scene.source_lighting.sampled[source.item_uuid].position.y,(source.base_height_steps+scene.fixture_heights[source.item_uuid])*scene.Placement.HEIGHT_UNIT),"Fixture follows original registered flame centroid height")
    for value in scene.fixture_heights.values(): check(value>1.0 and value<2.0,"Original flame elevation replaces fixed one-step placement")
    check(scene.timeline.state==original,"Comparisons restore original canonical snapshot")
    var report = {"checks":checks,"failures":failures,"candidate_brightness":comparisons,"carried_only":self_stats,"extinguished":indirect_stats,"isolated_all_off":dark_stats,"fixture_heights":scene.fixture_heights,
        "scope":"Actual Crypt initial snapshot; named optical-lift candidates, native ambient readability with all sources extinguished, isolated zero-ambient control, raised-support/jump fixtures. No hand binding, altered XY/range or duplicated light."}
    var file = FileAccess.open("res://generated/emitter_placement_checks.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
    print("EMITTER_PLACEMENT_CHECKS ",JSON.stringify(report))
    scene.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
