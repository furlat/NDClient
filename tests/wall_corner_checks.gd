extends SceneTree
const ViewPublication=preload("res://tests/view_publication.gd")
# Disclosed boundary edges -> authored visual tile, without merging game objects.
const World = preload("res://presentation/world.gd")
const Catalog = preload("res://source_catalog.gd")
const Player = preload("res://play.tscn")
# Reviewed original art: e=front, n=right, w=back, s=left. These fixed
# expectations deliberately do not repeat the catalog's pose-index arithmetic.
const EXPECTED_VIEWS = {"e":["e","s","w","n"],"s":["n","e","s","w"],
    "w":["w","n","e","s"],"n":["s","w","n","e"]}
var checks = 0
var failures: Array = []
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("WALL_CORNER_FAIL ",label)
func edge(id: String, direction: String, height: float = 0, material: String = "stone") -> Dictionary:
    return {"placement":{"kind":"boundary","position":[2,3],"base_height_steps":height,
        "top_height_steps":height+2,"boundary_direction":direction},
        "item":{"item_id":"wall."+material,"boundary_structure":{"structure":"wall","material":material}}}
func _initialize() -> void: run.call_deferred()
func run() -> void:
    if "--background-check" in OS.get_cmdline_user_args():
        root.unfocusable = true; root.position = Vector2i(-16000,-16000)
    var cache = {}
    var authored = Catalog.read_file("world.json",cache)
    for facing in ["e","s","w","n"]:
        var faces: Array = authored.wall_corner_faces[facing]
        var state = {"tiles":{},"senses":{},"objects":{"first":edge("first",faces[0]),"second":edge("second",faces[1])}}
        var before = state.duplicate(true)
        var result = World.rows(state,cache)
        var visual: Array = result.get("visual_rows",result.rows)
        check(result.rows.size()==2,"Both original wall identities survive")
        check(visual.size()==1,"Adjacent edges select one corner tile: "+facing)
        if visual.size()==1:
            check(visual[0].get("wall_members",[]).size()==2,"Corner retains both original target rows")
            for quarter in range(4):
                var record = Catalog.environment(visual[0],quarter,cache)
                var pose: String = EXPECTED_VIEWS[facing][quarter]
                var expected: Dictionary = Catalog.read_file("assets.json",cache).resources[authored.stone_wall_corner[pose]]
                check(record==expected,"Exact corner colour/normal/depth/pivot/scale in view "+pose)
        check(state==before,"Visual corner does not mutate the backend state")
        state.objects.erase("second")
        result = World.rows(state,cache)
        visual = result.get("visual_rows",result.rows)
        check(visual.size()==1 and visual[0].boundaries==[faces[0]],"Removing one edge restores the remaining straight wall")
    for other in [edge("second","west"),edge("second","north",1),edge("second","north",0,"wood")]:
        var state = {"tiles":{},"objects":{"first":edge("first","east"),"second":other}}
        var result = World.rows(state,cache)
        check(result.get("visual_rows",result.rows).size()==2,"Opposite/material/height mismatch remains separate")
    var stacked = {"tiles":{},"objects":{"low-east":edge("low-east","east"),"low-north":edge("low-north","north"),
        "high-east":edge("high-east","east",3),"high-north":edge("high-north","north",3)}}
    var joined = World.rows(stacked,cache)
    check(joined.rows.size()==4 and joined.visual_rows.size()==2,"Separate support heights form independent corner tiles")
    stacked.objects["high-north"].placement.top_height_steps = 6
    joined = World.rows(stacked,cache)
    check(joined.visual_rows.size()==3,"Different top heights cannot form a corner")
    if "--recording" in OS.get_cmdline_user_args(): await native_corners()
    var report = {"checks":checks,"failures":failures}
    var file = FileAccess.open("res://generated/wall_corner_checks.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  ")); file.close()
    print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)

func native_corners() -> void:
    var scene = Player.instantiate()
    scene.timeline.paused = true
    root.add_child(scene)
    var deadline = Time.get_ticks_msec()+60000
    while (not scene.session.recording_ready or not scene._media_ready({})) and scene.session.issue.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
    scene.session.close()
    await scene.presentation_updated
    scene.set_process(false); scene.hud.hide(); scene.force_attack = true
    var before: Dictionary = scene.timeline.state.duplicate(true)
    check(not before.is_empty() and scene.session.issue.is_empty(),"Real recorded state admits")
    if before.is_empty(): scene.queue_free(); return
    var hit_ids = {}
    var member_ids = {}
    var last_corner = {}
    for q in range(4):
        check(await ViewPublication.finish(scene,q),"Requested camera quarter publishes")
        var corners: Array = scene.static_entries.filter(func(entry):return entry.role=="wall" and entry.placement.has("wall_members"))
        check(corners.size()==4,"Recorded rectangular room uses four authored corners")
        for entry in corners:
            last_corner = entry.placement
            var contact = scene.Placement.contact(entry.placement)
            scene.camera_focus = contact; scene.camera.size = 5; scene.position_camera(); scene._sort_draws()
            for member in entry.placement.wall_members:
                member_ids[member.id] = true
                check(not scene._identity_hit(member.id).is_empty(),"Both original backend identities remain available")
            var mesh: QuadMesh = entry.node.mesh
            for y in range(48,240,8):
                for x in range(48,208,8):
                    var local = Vector3((float(x)/256-.5)*mesh.size.x,(.5-float(y)/256)*mesh.size.y,0)+mesh.center_offset
                    var point = scene.camera.unproject_position(entry.node.global_transform*local)
                    var hit: Dictionary = scene.pick_world(point)
                    if member_ids.has(hit.get("id","")): hit_ids[hit.id] = true
        scene.camera_focus = Vector3(4,0,5); scene.camera.size = 12; scene.position_camera(); scene._sort_draws()
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://.captures/walls/corners-%d.png" % q)
    check(hit_ids.size()==member_ids.size(),"Ctrl picking reaches every original wall edge across the four views: %d/%d" % [hit_ids.size(),member_ids.size()])
    check(scene.timeline.state==before,"Corner assembly and picking preserve canonical state")
    # Named destruction/removal after-value; the backend still owns the event.
    var removed: String = last_corner.wall_members[0].id
    var remaining: String = last_corner.wall_members[1].id
    scene.timeline.state.objects.erase(removed)
    scene._sync_world(); scene._sort_draws()
    var survivor = scene.static_entries.filter(func(entry):return entry.role=="wall" and entry.placement.id==remaining)
    check(survivor.size()==1 and not survivor[0].placement.has("wall_members"),"Native corner becomes the surviving straight wall on removal")
    check(scene._identity_hit(removed).is_empty() and not scene._identity_hit(remaining).is_empty(),"Removed edge cannot remain a stale pick target")
    scene.timeline.state = before
    scene.queue_free(); await process_frame
