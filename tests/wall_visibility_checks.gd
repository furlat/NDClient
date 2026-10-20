extends SceneTree
const ViewPublication=preload("res://tests/view_publication.gd")
# Real recorded visibility and input lifecycle. Pixel/member geometry acceptance
# is in wall_member_view_checks and wall_reveal_checks, without a shared oracle.
const Player=preload("res://play.tscn")
const Cells=preload("res://sdk/fold_cells.gd")
const BACK_FACES=[["west","south"],["west","north"],["east","north"],["east","south"]]
var checks=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok: failures.append(label); print("WALL_VISIBILITY_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func key(echo: bool=false) -> void:
    var event=InputEventKey.new(); event.keycode=KEY_Z; event.physical_keycode=KEY_Z; event.pressed=true; event.echo=echo
    root.push_input(event,true); event=event.duplicate(); event.pressed=false; event.echo=false; root.push_input(event,true)
func rear_policy(scene: Node,label: String) -> void:
    var rear=0
    for row in scene.placements:
        if row.kind not in ["wall","cliff"]: continue
        if row.boundaries[0] in BACK_FACES[scene.quarter]:
            rear+=1; check(row.id not in scene.faded_walls,label+": rear member never qualifies")
    check(rear>0 and not scene.faded_walls.is_empty(),label+": both rear and front members exercised")
func run() -> void:
    root.unfocusable=true; root.position=Vector2i(-16000,-16000)
    var scene=Player.instantiate(); scene.timeline.paused=true; root.add_child(scene)
    var deadline=Time.get_ticks_msec()+120000
    while (not scene.session.recording_ready or not scene._environment_media_ready() or not scene.MediaWarmup.ready(scene.media_warmup,scene.media_plan.required)) and scene.session.issue.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
    await scene.presentation_updated; scene.set_process(false)
    check(scene.session.issue.is_empty() and not scene.timeline.state.is_empty(),"Real recorded encounter initialized")
    if scene.timeline.state.is_empty(): quit(1); return
    var before: Dictionary=scene.timeline.state.duplicate(true)
    for q in range(4):
        scene.wall_mode="solid"; check(await ViewPublication.finish(scene,q),"Requested camera quarter publishes")
        key(); check(scene.wall_mode=="translucent","Z solid -> translucent q%d"%q)
        rear_policy(scene,"Initial q%d"%q)
        var faded: Array=scene.faded_walls.duplicate(); faded.sort()
        key(); check(scene.wall_mode=="hidden","Z translucent -> hidden q%d"%q)
        var hidden: Array=scene.faded_walls.duplicate(); hidden.sort()
        check(faded==hidden,"Same native members qualify in both modes")
        for entry in scene.static_entries:
            if entry.get("wall_variant","")==entry.placement.id and entry.placement.id in hidden:
                check(not entry.node.visible,"Hidden member has no residual rendered fragment")
        key(); check(scene.wall_mode=="solid" and scene.faded_walls.is_empty(),"Z hidden -> solid")
        key(true); check(scene.wall_mode=="solid","Key repeat never cycles")
        scene.hud.toggle_inventory(); scene.hud.search.grab_focus(); key()
        check(scene.wall_mode=="solid","Typing Z into inventory search preserves wall mode")
        scene.hud.search.release_focus(); scene.hud.toggle_inventory(); key()
        var size: float=scene.camera.size; scene.camera.size*=2; scene.update_wall_visibility()
        var zoomed: Array=scene.faded_walls.duplicate(); zoomed.sort()
        check(zoomed==faded,"Zoom does not change native selection"); scene.camera.size=size
        scene.timeline.state.senses.visible=Cells.mask([]); scene.update_wall_visibility()
        check(scene.faded_walls.is_empty(),"Memory without current visibility reveals nothing")
        scene.timeline.state.senses.visible=before.senses.visible.duplicate(true); scene.update_wall_visibility()
        var restored: Array=scene.faded_walls.duplicate(); restored.sort()
        check(restored==faded,"Current visibility restores member selection")
        # Explicit changed elevation after-values invalidate the projection cache.
        # Every known support now lies well above these finite wall spans.
        var revision:int=scene.timeline.revision
        var world_revision:int=scene.timeline.world_revision
        var raised: Dictionary=scene.timeline.state.tiles.duplicate(true)
        for tile in raised.values(): tile.elevation_steps+=100
        scene.timeline.state.tiles=raised; scene.timeline.revision+=1; scene.timeline.world_revision+=1
        direct_projection(scene)
        scene.update_wall_visibility(); check(scene.faded_walls.is_empty(),"Raised supports no longer occluded by lower walls")
        # Restore the original recorded cut, including its revision owner. The
        # isolated projection must not leave fake revisions in later replay.
        scene.timeline.state.tiles=before.tiles.duplicate(true)
        scene.timeline.revision=revision;scene.timeline.world_revision=world_revision
        direct_projection(scene); scene.update_wall_visibility()
        restored=scene.faded_walls.duplicate(); restored.sort()
        check(restored==faded,"Restored elevations invalidate cached candidates")
    check(scene.timeline.state==before,"UI/view changes preserve exact initial backend state")
    scene.set_process(true); deadline=Time.get_ticks_msec()+120000
    while (not scene.session.terminal or scene.timeline.busy() or scene.timeline.sequence!=scene.session.latest_sequence) and scene.presentation_errors.is_empty() and Time.get_ticks_msec()<deadline:
        scene.timeline.paused=false; scene.timeline.advance(1000000); scene.timeline.paused=true
        await scene.presentation_updated
    while (not scene._environment_media_ready() or not scene.MediaWarmup.ready(scene.media_warmup,scene.media_plan.required)) and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline: await scene.presentation_updated
    scene.set_process(false)
    check(not scene.timeline.busy() and scene.timeline.state==scene.session.journal.state and scene.presentation_errors.is_empty(),"All real operations drain to canonical terminal state")
    check(scene.world_revision==scene.timeline.world_revision and not scene.publication_failed,
        "Recorded terminal world already published through its actual prepared owner")
    scene._sample_actors(); scene._sample_fixtures()
    var terminal: Dictionary=scene.timeline.state.duplicate(true)
    for q in range(4):
        check(await ViewPublication.finish(scene,q),"Requested camera quarter publishes"); rear_policy(scene,"Terminal q%d"%q)
    check(scene.timeline.state==terminal,"Later corridor visibility never mutates backend state")
    var report={"checks":checks,"failures":failures,"scope":"Actual recorded initial and terminal states, input focus, four views, visibility/elevation invalidation"}
    var file=FileAccess.open("res://generated/wall_visibility_checks.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
    print(JSON.stringify(report)); scene.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)

func direct_projection(scene:Node)->void:
    # Explicit isolated renderer after-value control. The real recorded cuts
    # above/below retain their prepared owners; no fabricated SDK event enters.
    var epoch:int=scene.world_prepare_epoch
    scene.world_prepare_epoch=-1
    scene._sync_world()
    scene.world_prepare_epoch=epoch
