extends SceneTree
# Replay the actual user prefix through production SDK/preparation/rendering.
# Native runs also retain first-publication and four-view screenshots.
const Player = preload("res://play.tscn")
const Catalog = preload("res://source_catalog.gd")
var checks = 0
var failures: Array = []
var captures: Array = []
var native = false
var publications: Array = []

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("DOOR_RENDER_FAIL ",label)

func _initialize() -> void: run.call_deferred()

func assert_door(scene: Node, id: String, label: String) -> void:
    check(scene.world_groups.has(id),label+": recorded destroyed object has a rendered group")
    if not scene.world_groups.has(id): return
    var leaf = {}; var frame = {}; var back = {}
    for entry in scene.world_groups[id].entries:
        if entry.source_role==1: leaf=entry
        elif entry.source_role==2: frame=entry
        elif entry.source_role==3: back=entry
    check(not leaf.is_empty() and not frame.is_empty() and not back.is_empty(),label+": original doorway components exist")
    if leaf.is_empty() or frame.is_empty() or back.is_empty(): return
    var owner = Catalog.owner_for(leaf.placement,scene.catalog_cache)
    var bank_id: String=owner.destructions["closed.clear"]
    var bank = Catalog.bank_data(bank_id,scene.catalog_cache)
    var pose = Catalog.pose_for(bank,leaf.placement.orientation,scene.quarter)
    var expected: Dictionary=bank.frames_by_pose[pose][int(bank.frame_count)-1]
    publications.append({"label":label,"quarter":scene.quarter,"timeline_world_revision":scene.timeline.world_revision,
        "published_world_revision":scene.world_revision,
        "bank":leaf.record.bank,"frame":leaf.record.frame,"visible":[leaf.node.visible,frame.node.visible,back.node.visible]})
    check(leaf.record.bank==bank_id and leaf.record.frame==int(bank.frame_count)-1
        and leaf.record.path==expected.path and leaf.record.rect==expected.rect,
        label+": actual material uses authored final debris pixels")
    check(leaf.node.visible and frame.node.visible and not back.node.visible,
        label+": debris and stone frame visible, duplicate intact leaf absent")
    check(leaf.material.get_shader_parameter("colour_texture")!=null
        and leaf.material.get_shader_parameter("normal_texture")!=null,
        label+": original debris colour and normal textures are prepared")
    check(leaf.node.material_override==leaf.material and leaf.material.shader==scene.ENVIRONMENT_SHADER,
        label+": lit sprite output is the prepared debris source material")
    var item: Dictionary=scene.timeline.state.objects[id].item
    check(item.integrity=="destroyed" and item.destruction_outcome=="clear"
        and item.boundary_structure.blocked_channels.is_empty(),label+": display agrees with authoritative clear passage")

func capture(label: String) -> void:
    if not native: return
    await RenderingServer.frame_post_draw
    var path="res://.captures/door-state/"+label+".png"
    check(root.get_texture().get_image().save_png(path)==OK,"Screenshot saves "+label)
    captures.append(path)

func run() -> void:
    var args=OS.get_cmdline_user_args()
    if not "--recording" in args:
        push_error("Pass --recording with the Gallery journal prefix through passage destruction (sequences0..8).")
        quit(1);return
    native=DisplayServer.get_name()!="headless"
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(960,640)
    DirAccess.make_dir_recursive_absolute("res://.captures/door-state")
    ProjectSettings.set_setting("source_data/encounter_cache_mib",0)
    var scene=Player.instantiate();scene.timeline.paused=true;root.add_child(scene)
    scene.grid_visible=false;scene.hud.hide();scene.camera.size=7
    scene.initial_focus=true;scene.camera_focus=Vector3(20,0,6);scene.position_camera()
    scene.fire_light_flicker=false;scene.source_lighting.fire_light_flicker=false
    scene.wall_mode="solid"
    var deadline=Time.get_ticks_msec()+120000
    while (not scene.session.recording_ready or not scene._media_ready({}) or scene.world_revision<0) and Time.get_ticks_msec()<deadline:
        await process_frame
    check(scene.session.recording_ready and scene.media_initial_ready and scene.world_revision>=0 and scene.media_issue.is_empty(),"Recorded prefix initializes through production media and world preparation")
    var id=""
    var saw_intact=false
    var saw_destroyed=false
    # Let the player advance and publish in its normal process order. Advancing
    # externally between process callbacks changes which media group is current.
    scene.timeline.paused=false
    while (not scene.session.terminal or scene.timeline.busy() or scene.timeline.sequence!=scene.session.latest_sequence) and Time.get_ticks_msec()<deadline:
        await scene.presentation_updated
        for key in scene.timeline.state.objects:
            var item: Dictionary=scene.timeline.state.objects[key].item
            if item.name not in ["Gallery passage","Broken Gallery passage"]: continue
            id=key
            if item.integrity!="destroyed" and scene.world_groups.has(id):
                saw_intact=true
            elif item.integrity=="destroyed" and not saw_destroyed:
                scene.set_process(false)
                check(scene.world_revision==scene.timeline.world_revision,"Destroyed state and rendered world publish in the same process callback")
                assert_door(scene,id,"First destruction publication")
                await capture("first-destroyed")
                saw_destroyed=true;scene.set_process(true)
    check(saw_intact and saw_destroyed,"Real recording changes from the intact passage to its destroyed remnant")
    check(scene.session.terminal and not scene.timeline.busy() and scene.timeline.state==scene.session.journal.state,
        "Recorded destruction drains in canonical event order")
    if not id.is_empty() and saw_destroyed:
        for quarter in [0,1,2,3,0]:
            scene.request_view(quarter)
            while scene.rotation_pending() and Time.get_ticks_msec()<deadline: await scene.presentation_updated
            await scene.presentation_updated
            scene.set_process(false)
            check(scene.quarter==quarter and not scene.rotation_pending(),"Requested quarter%d finishes before its capture" % quarter)
            assert_door(scene,id,"Quarter%d" % quarter)
            await capture("quarter%d" % quarter)
            scene.set_process(true)
    check(scene.session.issue.is_empty() and scene.media_issue.is_empty(),"No protocol or missing-source issue during destroyed-door playback")
    scene.queue_free();await process_frame
    var report={"checks":checks,"failures":failures,"native":native,"captures":captures,"publications":publications,
        "scope":"Actual user journal prefix through SDK, causal timeline, prepared world, native receiving materials and camera cache. No newly issued server command or smooth destruction-animation claim."}
    FileAccess.open("res://generated/door_state_render_checks"+("_native" if native else "_headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
