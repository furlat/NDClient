extends SceneTree
const ViewPublication=preload("res://tests/view_publication.gd")
# Actual Crypt wall/door rows and their original source packets through play.gd.
const Player = preload("res://play.tscn")
const Lighting = preload("res://presentation/lighting_2d.gd")
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
func publish(scene:Node)->void:
    scene.source_lighting.sample({},scene.fixture_energy,scene.fixture_heights,scene.fixture_shadow_heights)
    scene._sync_native_lighting()

func alpha_changes(a:Image,b:Image)->int:
    var changed:int=0
    for y in a.get_height():
        for x in a.get_width():
            if a.get_pixel(x,y).a8!=b.get_pixel(x,y).a8:changed+=1
    return changed

func run() -> void:
    root.unfocusable = true; root.position = Vector2i(-16000,-16000); root.size = Vector2i(640,480)
    var scene = Player.instantiate(); scene.timeline.paused = true; root.add_child(scene)
    var initial_deadline:int=Time.get_ticks_msec()+90000
    while (not scene.session.recording_ready or not scene._media_ready({})) and scene.session.issue.is_empty() and Time.get_ticks_msec()<initial_deadline: await process_frame
    scene.session.close(); await scene.presentation_updated
    scene.set_process(false); scene.hud.hide()
    check(scene.session.issue.is_empty() and not scene.timeline.state.is_empty(),"Real recorded Crypt admits")
    if scene.timeline.state.is_empty():scene.queue_free();quit(1);return
    scene.grid_visible=false;scene.normals_visible=false
    scene.fire_light_flicker=false;scene.source_lighting.fire_light_flicker=false
    DirAccess.make_dir_recursive_absolute("res://.captures/walls")
    var original = scene.timeline.state.duplicate(true)
    var normal_responses:int=0
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
            check(not selected.is_empty(),"Original architectural source exists: "+str(sample))
            var held:Array=selected.map(func(entry):return [entry.node.global_transform,entry.record.duplicate(true)])
            publish(scene)
            var lit = await capture()
            # The abs(N·L) switch belonged to the retired 3D receiving path.
            # Approved PointLight2D receiving uses max(N·L,0); its real normal
            # map, alpha, original placement and exact restoration are checked.
            for entry in selected:entry.material.set_shader_parameter("use_source_normals",false)
            var flat=await capture()
            for entry in selected:entry.material.set_shader_parameter("use_source_normals",true)
            var restored=await capture()
            scene.source_lighting.sync({});publish(scene)
            var dark = await capture()
            check(scene.light_table.count==0,"Explicit absent optical set clears native receiving lights")
            scene.source_lighting.sync(scene.timeline.state);publish(scene)
            var value = delta(lit,dark)
            var normal_delta:float=delta(lit,flat)
            var label = "%s at %s %s q%d" % [sample[0],sample[1],sample[2],q]
            check(value>.002,"Disclosed room torches illuminate architectural art: "+label)
            check(alpha_changes(lit,flat)==0 and alpha_changes(lit,dark)==0,"Light and normal changes preserve architectural alpha: "+label)
            check(delta(lit,restored)<.00001,"Restoring original native normals restores the exact architectural frame: "+label)
            check(selected.map(func(entry):return [entry.node.global_transform,entry.record])==held,"Lighting preserves original art, placement and support: "+label)
            if normal_delta>.00001:normal_responses+=1
            if q==0 and sample[0]=="door" and sample[2]=="closed":
                lit.save_png("res://.captures/walls/door-native2d.png")
                # Explicit public directional fixture. It must reach the same
                # actual receiving table; creating an unused node is not proof.
                scene.source_lighting.sync({})
                var direction:Vector3=scene.camera.global_basis.z.normalized()
                var policy={"directionalSources":[{"id":"architectural-directional","directionToSource":[direction.x,direction.y,direction.z],"colorLinear":[1,1,1],"intensity":1}]}
                scene.source_lighting.set_directionals(policy);publish(scene)
                check(scene.source_lighting._directionals.size()==1,"The current 2D adapter admits the explicit directional source")
                check("architectural-directional" in scene.light_table.ids,"Declared DirectionalLight2D reaches the production receiving table; missing directional publication is a renderer gap")
                var directional = await capture()
                check(delta(directional,dark)>.005,"Current native2D directional source illuminates the original door; source declaration alone is insufficient")
                scene.source_lighting.set_directionals(scene.Catalog.environment_world(scene.catalog_cache).lighting)
                scene.source_lighting.sync(scene.timeline.state);publish(scene)
            measurements.append({"case":label,"lit_delta":value,"normal_delta":normal_delta})
    check(normal_responses>0,"Original registered architectural normals affect native2D receiving")
    scene.timeline.state = original
    publish(scene)
    check(scene.timeline.state==original,"Architectural comparisons restore the original canonical snapshot")
    var report = {"checks":checks,"failures":failures,"measurements":measurements,"policy":"Approved native2D max(N·L,0) receiving replaces retired3D abs-dot control; real wall/door normals, alpha, placement, restoration and directional contribution remain explicit checks. No production graphics changes."}
    var file = FileAccess.open("res://generated/architectural_lighting_checks.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
    print(JSON.stringify(report)); scene.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
