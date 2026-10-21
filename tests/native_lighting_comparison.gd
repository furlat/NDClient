extends SceneTree
# Actual paused Crypt, unchanged source art/geometry. Native lighting comparison,
# not an assertion that spherical Omni attenuation matches backend circular rules.
const Player = preload("res://play.tscn")
const EmitterChecks = preload("res://tests/emitter_placement_checks.gd")
var failures: Array = []
var checks := 0
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("NATIVE_LIGHT_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func capture() -> Image:
    await process_frame; await process_frame; await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
func run() -> void:
    root.unfocusable = true; root.position = Vector2i(-16000,-16000)
    var scene = Player.instantiate(); scene.timeline.paused = true; root.add_child(scene)
    var deadline = Time.get_ticks_msec()+90000
    while not scene.session.recording_ready and scene.session.issue.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
    while not scene._media_ready({}) and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline: await scene.presentation_updated
    check(scene._media_ready({}) and scene.presentation_errors.is_empty(),"Actual Crypt and exact source companions prepare")
    if not scene._media_ready({}):
        scene.session.close();scene.queue_free();await process_frame;quit(1);return
    # Keep the producer until its compiled groups' media handoffs are admitted.
    scene.session.close(); await scene.presentation_updated
    scene.set_process(false); scene.hud.hide(); scene.camera_focus = Vector3(4,0,5); scene.camera.size = 4
    scene.position_camera(); scene.wall_mode = "hidden"; scene.update_wall_visibility(); scene._sort_draws(); scene._sample_actors(); scene._sample_fixtures()
    var canonical: Dictionary = scene.timeline.state.duplicate(true)
    var environment: Environment
    for child in scene.get_children():
        if child is WorldEnvironment: environment = child.environment
    check(environment.ambient_light_source==Environment.AMBIENT_SOURCE_COLOR and is_equal_approx(environment.ambient_light_energy,0.18),"Production scene uses native colour ambient resource")
    var pixels: Dictionary = EmitterChecks.actor_pixels(scene)
    var omnis:Array=scene.source_lighting.nodes.values()
    check(omnis.size()==4 and omnis.all(func(node):return node is OmniLight3D),"Production owns exactly the four admitted native Omni sources")
    var folder = "res://.captures/native-lighting"; DirAccess.make_dir_recursive_absolute(folder)
    var results = {}
    var variants = [
        {"name":"native-omni-direct","ambient":0.0,"omni":true},
        {"name":"native-omni-ambient-018","ambient":0.18,"omni":true},
        {"name":"native-omni-ambient-030","ambient":0.30,"omni":true},
        {"name":"ambient-only-018","ambient":0.18,"omni":false},
        {"name":"all-off","ambient":0.0,"omni":false}]
    for variant in variants:
        environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        environment.ambient_light_color = Color.WHITE
        environment.ambient_light_energy = variant.ambient
        for light in omnis: light.visible = variant.omni
        var shown = await capture(); shown.save_png(folder.path_join(variant.name+".png"))
        results[variant.name] = EmitterChecks.brightness(shown,pixels)
    for id in pixels:
        check(results["native-omni-ambient-018"][id].mean_luminance>results["native-omni-direct"][id].mean_luminance,"Native ambient increases lit-body readability: "+canonical.actors[id].name)
        check(results["native-omni-ambient-018"][id].dark_pixels<results["native-omni-direct"][id].dark_pixels,"Native ambient reduces near-black body pixels: "+canonical.actors[id].name)
        check(results["native-omni-direct"][id].mean_luminance>.02,"Native Omni reaches actual original modular material: "+canonical.actors[id].name)
        check(results["ambient-only-018"][id].mean_luminance>.02,"No direct source still leaves a readable body: "+canonical.actors[id].name)
        check(results["all-off"][id].mean_luminance<.002,"Ambient result is not stray material emission: "+canonical.actors[id].name)
    check(scene.timeline.state==canonical,"Lighting comparison does not mutate canonical subjective state")
    var report = {"checks":checks,"failures":failures,"actors":results,"renderer":RenderingServer.get_video_adapter_name(),"scope":"Actual frozen initial Crypt; native WorldEnvironment white ambient 0.18/0.30 and four native OmniLight3D at disclosed source positions; Omni energy 2, attenuation 1, spherical outer range, no shadows. Comparison only: native attenuation is intentionally not claimed equivalent to canonical circular band response. Actor pixel summaries include the whole assembled silhouette."}
    var file = FileAccess.open("res://generated/native_lighting_comparison.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
    print("NATIVE_LIGHTING_COMPARISON ",JSON.stringify(report))
    scene.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
