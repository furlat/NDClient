extends SceneTree
const ViewPublication=preload("res://tests/view_publication.gd")
# Actual Crypt wall/door rows and their original source packets through play.gd.
const Player = preload("res://play.tscn")
const Lighting = preload("res://presentation/lighting.gd")
var checks = 0
var failures: Array = []
var measurements: Array = []
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("ARCH_LIGHT_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func capture() -> Image:
    for i in range(3): await process_frame
    await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
func delta(a: Image,b: Image) -> float:
    var total = 0.0
    for y in range(0,a.get_height(),2):
        for x in range(0,a.get_width(),2):
            var ca = a.get_pixel(x,y); var cb = b.get_pixel(x,y)
            total += absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b)
    return total/(ceilf(a.get_width()/2.0)*ceilf(a.get_height()/2.0)*3.0)
func run() -> void:
    root.unfocusable = true; root.position = Vector2i(-16000,-16000); root.size = Vector2i(640,480)
    var scene = Player.instantiate(); scene.timeline.paused = true; root.add_child(scene)
    while (not scene.session.recording_ready or not scene._media_ready({})) and scene.session.issue.is_empty(): await process_frame
    scene.session.close(); await scene.presentation_updated
    scene.set_process(false); scene.hud.hide()
    check(scene.session.issue.is_empty() and not scene.timeline.state.is_empty(),"Real recorded Crypt admits")
    var original = scene.timeline.state.duplicate(true)
    var door_id = ""
    for entry in scene.static_entries:
        if entry.placement.kind=="door" and entry.placement.position==[7,6]: door_id = entry.placement.id
    check(not door_id.is_empty(),"Original east doorway is present")
    if door_id.is_empty(): quit(1); return
    for q in range(4):
        for sample in [["wall",[7,5],"closed"],["wall",[7,8],"closed"],["door",[7,6],"closed"],["door",[7,6],"inward"],["door",[7,6],"outward"]]:
            # Explicit presentation after-values exercise original open-state art;
            # these are not claimed as live backend command tests.
            scene.timeline.state.objects[door_id]=scene.timeline.state.objects[door_id].duplicate(true)
            scene.timeline.state.objects[door_id].item.is_open = sample[2]!="closed"
            scene.timeline.state.objects[door_id].item.door_swing = sample[2] if sample[2]!="closed" else "inward"
            scene.timeline.current={}; scene.timeline.queue=[]; scene.timeline.revision+=1; scene.timeline.world_revision+=1
            scene._prepare_media()
            var deadline=Time.get_ticks_msec()+60000
            while not scene._environment_media_ready() and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline:
                scene._warm_media();scene._prepare_media();await process_frame
            check(scene._environment_media_ready(),"Exact authored door after-value sources prepare")
            scene._sync_world(); scene._sync_scenery(true)
            scene.camera_focus = Vector3(sample[1][0],0,sample[1][1]); scene.camera.size = 4
            check(await ViewPublication.finish(scene,q),"Requested camera quarter publishes")
            var selected = []
            for entry in scene.entries:
                entry.node.visible = entry.placement.kind==sample[0] and entry.placement.position==sample[1] and entry.role!="shadow"
                if entry.node.visible:
                    selected.append(entry)
                    entry.material.set_shader_parameter("wall_mask_enabled",false)
            var lit = await capture()
            for entry in selected: entry.material.set_shader_parameter("two_sided_receiver",false)
            var previous = await capture()
            for entry in selected: entry.material.set_shader_parameter("two_sided_receiver",true)
            scene.source_lighting.sync({})
            var dark = await capture()
            scene.source_lighting.sync(scene.timeline.state)
            var value = delta(lit,dark)
            var prior = delta(previous,dark)
            var label = "%s at %s %s q%d" % [sample[0],sample[1],sample[2],q]
            check(value>.002,"Disclosed room torches illuminate architectural art from either side: "+label)
            check(value+.001>=prior,"Two-sided room lighting preserves original front-face response: "+label)
            if q==0 and sample[0]=="door" and sample[2]=="closed":
                check(value>prior+.005,"Previously black outward door now receives interior light")
                lit.save_png("res://.captures/walls/door-two-sided.png")
                # Native directional lights must follow the same policy as item sources.
                scene.source_lighting.sync({})
                var result = Lighting.directionals({"directionalSources":[{"id":"back","directionToSource":[-1,0,0],"colorLinear":[1,1,1],"intensity":1}]})
                scene.add_child(result.nodes[0])
                var directional = await capture()
                check(delta(directional,dark)>.005,"Native directional light reaches the back-facing door")
                result.nodes[0].queue_free(); await process_frame
                scene.source_lighting.sync(scene.timeline.state)
            measurements.append({"case":label,"lit_delta":value,"one_sided_delta":prior})
    scene.timeline.state = original
    var report = {"checks":checks,"failures":failures,"measurements":measurements,"policy":"Two-sided normal response for wall and door artwork, independent of opacity; source radius/visibility unchanged."}
    var file = FileAccess.open("res://generated/architectural_lighting_checks.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
    print(JSON.stringify(report)); scene.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
