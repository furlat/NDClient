extends RefCounted
## Test-only named renderer after-values. These are not backend commands/facts.
## Accepted state is immutable; the ordinary Timeline media/world boundary owns
## construction and publication exactly as it does for a received commit.
const Compiler=preload("res://presentation/compiler.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")

static func open(scene:Node)->Dictionary:
    if scene.session.replay_thread!=null:return {"ok":true}
    return scene.session.open_recording(Fixtures.journal("door"))

static func initial_ready(scene:Node,timeout_ms:int=90000)->bool:
    var deadline:int=Time.get_ticks_msec()+timeout_ms
    while (not scene.session.recording_ready or not scene._media_ready({}) or not scene.media_initial_ready or scene.world_revision<0 or scene.visual_actors.is_empty()) and scene.session.issue.is_empty() and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline:
        await scene.get_tree().process_frame
    return scene.session.recording_ready and scene._media_ready({}) and scene.media_initial_ready and scene.world_revision>=0 and not scene.visual_actors.is_empty() and scene.session.issue.is_empty() and scene.media_issue.is_empty()

static func replace(scene:Node,after:Dictionary,label:String)->bool:
    var before:Dictionary=scene.timeline.state
    var delta:Dictionary=Compiler.empty_delta()
    for field in ["actors","items","tiles","objects"]:
        for identity in after[field]:
            if not before[field].has(identity) or before[field][identity]!=after[field][identity]:delta[field][identity]=after[field][identity]
    for field in ["tiles","objects"]:
        for identity in before[field]:
            if not after[field].has(identity):delta[field+"_removed"].append(identity)
    # This isolated occlusion fixture deliberately retains one original actor.
    # There is no fabricated departure event or stand-in body in the test.
    if before.actors.keys()!=after.actors.keys():delta.set.actors=after.actors
    if before.senses!=after.senses:delta.set.senses=after.senses
    if before.light_sources!=after.light_sources:
        delta.set.light_sources=after.light_sources
        # Original SDK optical updates belong to a sensory publication, even
        # when its visibility mask is unchanged. Keep that prepared owner.
        delta.set.senses=after.senses
    scene.timeline.accept({"kind":"operation","groups":[{"id":"renderer-fixture:"+label+":"+str(scene.timeline.sequence+1),
        "operation_sequence":scene.timeline.sequence+1,"operation_end":true,"duration_ms":0.0,
        "actor_tracks":[],"components":[],"staged_tiles":{},"staged_actors":{},"events":[],
        "commits":[{"at_ms":0.0,"delta":delta}]}]})
    var requested:int=scene.requested_quarter
    scene.requested_quarter=scene.world_quarter
    var processing:bool=scene.is_processing()
    var paused:bool=scene.timeline.paused
    var speed:float=scene.playback_speed
    var displayed_at:float=scene.timeline.display_ms
    # Async worker frames are not animation time in a zero-duration fixture.
    # The ordinary advance(0) path still prepares and publishes this commit.
    scene.playback_speed=0.0
    scene.timeline.paused=false;scene.set_process(true)
    var deadline:int=Time.get_ticks_msec()+60000
    while (scene.timeline.busy() or scene.pending_world!=null or scene.world_revision!=scene.timeline.world_revision or not scene._environment_media_ready()) and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline:
        await scene.get_tree().process_frame
    scene.timeline.paused=paused;scene.playback_speed=speed;scene.set_process(processing)
    scene.requested_quarter=requested
    return scene.timeline.display_ms==displayed_at and not scene.timeline.busy() and scene.pending_world==null and scene.world_revision==scene.timeline.world_revision and scene._environment_media_ready() and scene.media_issue.is_empty()
