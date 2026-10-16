extends SceneTree
## Same-frame displayed-source ownership only. Native readiness/pixels and real
## operation playback are qualified by the live route and Studio suites.
const Player=preload("res://play.gd")
const Media=preload("res://presentation/media_warmup.gd")
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("TERMINAL_SOURCE_HANDOFF_FAIL ",label)
func run()->void:
    var player=Player.new()
    player.timeline.accept({"kind":"initialization","sequence":0,"state":{
        "actors":{},"tiles":{},"objects":{},"senses":{},"audience":{"controlled":[]}}})
    var group:Dictionary={"id":"terminal-lease-boundary","duration_ms":20.0,"commits":[],
        "actor_tracks":[],"staged_actors":{},"staged_at_ms":{},"staged_tiles":{},"staged_tile_at_ms":{},
        "operation_sequence":1,"operation_end":true}
    player.timeline.accept({"kind":"operation","groups":[group]})
    player.timeline.advance(20)
    check(player.timeline.current.is_empty() and player.timeline.queue.is_empty()
        and player.timeline.completed_group_count==1,"Actual Timeline reaches its completed idle boundary")
    var records:Array=[]
    for i in 160:
        var record:Dictionary=Media.source_record({"shared":"/unused/shared.png"},{},{},{"shared":true}).duplicate()
        record.source_id="terminal-source-"+str(i);record.make_read_only();records.append(record)
    records.make_read_only()
    var prior:Array=records.slice(0,8);prior.make_read_only()
    var profile:String=player.character_light_profile
    var opening:Dictionary={"source_records":{profile:prior},"coverage_until_ms":1.0}
    var continuation:Dictionary={"source_records":{profile:records}}
    player.media_empty_plan=opening
    player.media_group_plans[group.id]=continuation
    player.media_metadata_ready=true
    player.media_plan_key=[player.timeline.initialization_revision,[],player.timeline.revision]
    player.media_terminal_plan={"id":group.id,"epoch":player.timeline.initialization_revision,
        "state":player.timeline.state,"revision":player.timeline.revision,"completed":1}
    # Native playback already holds these exact references before publication.
    player.displayed_source_records=records
    player._publish_media_interest(player.timeline.display_ms)
    var runs:int=player.media_warmup.demand_runs
    check(Media.physical(player.media_warmup).consumers[player.media_warmup.consumer_id].records.size()==160,
        "Displayed owner holds all 160 immutable source registrations")
    # Production order: render-body retain, then optional source publication,
    # before the next frame's _prepare_media can run.
    player._retain_displayed_sources()
    player._publish_media_interest(player.timeline.display_ms)
    check(is_same(player.media_empty_plan,continuation) and is_same(player.displayed_source_records,records),
        "Idle adopts the latest complete plan before replacing displayed leases")
    check(player.media_terminal_plan.is_empty(),"Terminal receipt transfers exactly once")
    check(Media.physical(player.media_warmup).consumers[player.media_warmup.consumer_id].records.size()==160,
        "Same-frame optional publication retains all displayed leases")
    check(player.media_warmup.demand_runs==runs
        or (player.media_warmup.demand_counts.records_removed==0 and player.media_warmup.demand_counts.records_added==0),
        "Terminal handoff withdraws and reacquires zero of the 152 retained registrations")
    runs=player.media_warmup.demand_runs
    player._retain_displayed_sources();player._publish_media_interest(player.timeline.display_ms)
    check(player.media_warmup.demand_runs==runs,"Repeated idle sampling performs no source-role publication")
    # An unrelated epoch cannot use the completed receipt to substitute a plan.
    player.media_terminal_plan={"id":group.id,"epoch":player.timeline.initialization_revision-1,
        "state":player.timeline.state,"revision":player.timeline.revision,"completed":1}
    player.media_group_plans[group.id]=opening
    player._retain_displayed_sources()
    check(is_same(player.media_empty_plan,continuation),"Stale receipt leaves the actual displayed source plan intact")
    Media.close(player.media_warmup);player._exit_tree();player.context_menu.free();player.free()
    var report:Dictionary={"checks":checks,"failures":failures,
        "scope":"Actual completed Timeline, displayed/optional source transfer, latest continuation, immutable160-source lease set and stale epoch; CPU ownership only, no native readiness/performance claim."}
    FileAccess.open("res://generated/terminal_source_handoff_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("TERMINAL_SOURCE_HANDOFF ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
