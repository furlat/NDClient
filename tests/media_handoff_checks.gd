extends "res://tests/media_latency_checks.gd"
## Prepared metadata crosses the same accepted operation boundary as its groups.

func active_character_paths(plan:Dictionary,profile:String)->Dictionary:
    # Independent membership oracle: neutral metadata retains all alternatives;
    # displayed demand excludes only registered normals of inactive profiles.
    var variants={}
    var selected={}
    for profiles in plan.get("normal_sets",{}).values():
        for path in profiles.values():variants[path]=true
        if profiles.has(profile):selected[profiles[profile]]=true
    var paths={}
    for path in plan.character:
        if not variants.has(path) or selected.has(path):paths[path]=plan.character[path]
    return paths

func packet(state: Dictionary, rows: Array, cache: Dictionary, sequence: int) -> Dictionary:
    return {"kind":"operation","sequence":sequence,"groups":rows,
        "media":Media.prepare_handoff(state,rows,cache)}

func held_required(request: Dictionary, result: Dictionary, cache: Dictionary, entered: Semaphore, release: Semaphore) -> void:
    Media._plan_sources(request,result,cache)
    entered.post()
    release.wait()

func optional_interleaving(state: Dictionary, prepared: Dictionary, queued: bool) -> void:
    var data := Media.create()
    var entered := Semaphore.new()
    var release := Semaphore.new()
    var key_a := [1,["required-a"],0]
    var key_b := [1,["handoff-b"],0]
    var request := {"key":key_a,"state":Media._snapshot(state),"groups":[]}
    data.plan_thread=Thread.new()
    data.plan_thread.start(held_required.bind(request,data.plan_result,data.plan_cache,entered,release))
    entered.wait()
    if queued: Media.request_plan(data,[1,["queued-required"],0],state,[])
    var received := Media.receive_handoff(data,prepared,key_b)
    Media.adopt_required(data,1)
    var wanted := {}
    for path in received.value.required: wanted[path] = Catalog.media_path(path)
    Media.demand(data,wanted)
    check(not Media.ready(data,received.value.required),"Held metadata task does not grant missing required texture readiness")
    release.post()
    var first := await poll_plan(data)
    check(first.get("stage")=="required" and first.key==key_a,"Older required task still publishes its own exact result")
    if queued:
        var next := await poll_plan(data)
        check(next.get("stage")=="required" and next.key[1]==["queued-required"],"Already queued required work keeps priority over newer optional handoff")
    Media.demand(data,wanted) # Scene demand admits the pending optional job after required completion.
    var optional := await poll_plan(data)
    check(optional.get("stage")=="optional" and optional.key==key_b and not optional.value.encounter.is_empty(),
        "Newer handoff optional intent survives older required completion"+(" and pending dispatch" if queued else ""))
    Media.adopt_encounter(data,optional.value.encounter,1)
    check(is_same(data.encounter,optional.value.encounter) and not Media.ready(data,received.value.required),"Latest optional family can be adopted without granting unpublished required bytes")
    Media.close(data)

func run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--state="): state_path = arg.trim_prefix("--state=")
    if state_path.is_empty(): check(false,"Usage: --state=<recorded canonical state.json>"); finish_handoff(); return
    var state: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(state_path))
    check(not state.is_empty() and state.has("generation"),"Explicit authored canonical fixture loads")
    if state.is_empty() or not state.has("generation"): finish_handoff(); return
    var frozen := var_to_bytes(state)
    var cache := {}
    var old := group("older-current")
    var actor: Dictionary = state.actors[state.observer_uuid].duplicate(true)
    actor.visual_loadout.active_weapon_set = "ranged"
    var first := group("received-first",[{"delta":{"actors":{actor.uuid:actor}}}])
    var second := group("received-second")
    var third := group("unprepared-third")
    var message := packet(state,[first,second,third],cache,1)
    var prepared: Dictionary = message.media
    check(prepared.groups.size()==2 and is_same(prepared.groups[0],first) and is_same(prepared.groups[1],second),"Handoff contains only the first two exact compiled group owners")
    check(prepared.optional_request.state.size()==5 and prepared.optional_request.state.has_all(["actors","tiles","objects","senses","audience"]),"Optional request retains only source-selector snapshot fields")
    var expected_character := Media.plan(state,[first,second],{})
    var expected_environment := exhaustive(state,[first,second],{})
    for field in ["required","upcoming","errors","upcoming_errors","gpu_only","cpu_required"]:
        check(prepared.value[field]==expected_character[field],"Handoff preserves exact original character "+field)
    for field in ["required","upcoming","fixtures"]:
        check((prepared.value.fixtures if field=="fixtures" else prepared.value["environment_"+field])==expected_environment[field],"Handoff equals exhaustive authored environment "+field)
    check(var_to_bytes(state)==frozen,"Planning from operation-before leaves canonical state and nested actor values intact")
    var source_bytes := var_to_bytes(prepared.source_files)
    await optional_interleaving(state,prepared,false)
    await optional_interleaving(state,prepared,true)

    var player = Player.new()
    player.timeline.accept({"kind":"initialization","sequence":0,"state":state})
    player.timeline.paused = true
    player.timeline.current = old
    player.world_revision = 0
    player._reset_media_epoch()
    var old_result := {}
    Media._plan_sources({"key":[player.timeline.initialization_revision,[old.id],0],"state":state,"groups":[old]},old_result,{})
    player._adopt_media_plan(old_result)
    player._prepare_media()
    var old_plan = player.media_group_plans[old.id]
    var old_wanted: Dictionary = player.media_warmup.wanted.duplicate()
    var old_clock: float = player.timeline.display_ms
    player._adopt_received_media(message)
    check(not player.media_group_plans.has(first.id) and player.media_warmup.metadata_jobs==0,"Unaccepted compiled group cannot install metadata or schedule optional work")
    player.timeline.accept(message)
    var session = Player.Session.new()
    player.session = session
    player._adopt_received_media(message)
    check(player.session.source_files_pending.is_empty() and player.session.source_headers_pending.is_empty(),"Session-produced source handoff is not echoed back to its own worker")
    session.close()
    player.session = null
    check(player.media_group_plans.has(first.id) and player.media_group_plans.has(second.id) and not player.media_group_plans.has(third.id),"Accepted operation installs its two prepared group plans")
    check(is_same(player.media_group_plans[old.id],old_plan) and player.media_warmup.wanted==old_wanted,"Ahead metadata does not replace displayed current pins")
    player._prepare_media()
    check(player.media_metadata_ready and player.media_plan.required==active_character_paths(old_plan,player.character_light_profile),"Older active group remains the required source owner")
    check(player.media_plan.upcoming==active_character_paths(player.media_group_plans[first.id],player.character_light_profile),"Only the first queued group becomes the ordinary upcoming demand")
    check(player.media_warmup.plan_pending.is_empty(),"Attached source metadata avoids a duplicate required worker request")
    check(player.media_group_plans.has(second.id),"Second received group survives a window containing older current plus first received")
    check(not Media.ready(player.media_warmup,player.media_plan.required),"Metadata alone never grants texture readiness")
    check(player.timeline.display_ms==old_clock and var_to_bytes(player.timeline.state)==frozen,"Ahead resource planning publishes no actor/clock/world changes")

    var later_first := group("later-operation-first")
    var later_second := group("later-operation-second")
    var later := packet(state,[later_first,later_second],cache,2)
    player.timeline.accept(later)
    player._adopt_received_media(later)
    player._prepare_media()
    check(player.media_received_owners.size()==4 and player.media_group_plans.has(second.id) and player.media_group_plans.has(later_second.id),"Two admitted preparation-window operations keep their four exact pending group owners")
    check(player.media_plan.required==active_character_paths(old_plan,player.character_light_profile) and player.media_warmup.plan_pending.is_empty(),"Second ahead operation neither changes current pins nor duplicates required work")
    var jobs: int = player.media_warmup.metadata_jobs
    var stale: Dictionary = message.duplicate()
    stale.media = message.media.duplicate(); stale.media.groups = [first.duplicate(true),second]
    player._adopt_received_media(stale)
    check(player.media_warmup.metadata_jobs==jobs,"Same-epoch matching IDs with foreign group owners cannot install a stale result")
    stale = message.duplicate(); stale.media = message.media.duplicate(); stale.media.generation = "different-generation"
    player._adopt_received_media(stale)
    check(player.media_warmup.metadata_jobs==jobs,"Foreign canonical generation cannot install prepared metadata")

    # Optional metadata remains on the original serial worker. Older completion
    # cannot overwrite latest required plans or the active group's ownership.
    var completions := 0
    var deadline := Time.get_ticks_msec()+30000
    while (player.media_warmup.plan_thread!=null or not player.media_warmup.optional_pending.is_empty()) and Time.get_ticks_msec()<deadline:
        var done := Media.poll_plan(player.media_warmup)
        if not done.is_empty():
            check(done.stage=="optional","Received metadata schedules only optional family work")
            var current_before = player.media_group_plans[old.id]
            player._adopt_media_plan(done)
            check(is_same(player.media_group_plans[old.id],current_before),"Optional completion never replaces current required plan")
            completions += 1
        player._prepare_media()
        await process_frame
    check(completions>0 and player.media_warmup.plan_thread==null and player.media_warmup.optional_pending.is_empty(),"Optional family queue completes through its existing worker")
    check(var_to_bytes(prepared.source_files)==source_bytes,"Worker cache merge never mutates transferred source-file owners")
    check(not player.media_warmup.encounter.is_empty(),"Matching latest optional completion preserves encounter preload planning")
    player.timeline.current = first
    player.timeline.queue.erase(first)
    player._prepare_media()
    check(player.media_plan.required==active_character_paths(player.media_group_plans[first.id],player.character_light_profile) and player.media_plan.upcoming==active_character_paths(player.media_group_plans[second.id],player.character_light_profile),"First received group uses prepared exact current/upcoming owners")
    check(player.media_warmup.plan_pending.is_empty() and player.media_warmup.plan_thread==null,"First received activation needs no second required metadata task")
    check(not player.media_group_plans.has(old.id),"Retired nonreceived current plan is released")
    player.timeline.current = second
    player.timeline.queue.erase(second)
    player._prepare_media()
    check(not player.media_received_owners.has(first.id),"Retired received group releases its retained metadata owner")
    check(player.media_requested_key[1]==[second.id,third.id] and player.media_warmup.plan_thread!=null,"Groups beyond the first two retain the original required worker fallback")
    var fallback := await poll_plan(player.media_warmup)
    check(not fallback.has("error") and fallback.get("complete",false),"Required fallback publishes successful completion instead of freezing live playback")
    player._adopt_media_plan(fallback)
    player._prepare_media()
    check(player.media_issue.is_empty() and player.media_plan.errors.is_empty() and player.media_group_plans.has(third.id),
        "Later queued event receives its exact media plan without a false preparation error")
    check(player.timeline.current==second and player.timeline.queue.has(third),"Media completion cannot advance or reorder the displayed events")

    # Reinitialization invalidates the old group identities, even for the same
    # canonical generation value; late completions cannot enter this new epoch.
    var old_epoch: int = player.timeline.initialization_revision
    player.timeline.accept({"kind":"initialization","sequence":0,"state":state})
    player._adopt_received_media(message)
    check(player.timeline.initialization_revision!=old_epoch and player.media_group_plans.is_empty() and player.media_received_owners.is_empty(),"Reset clears received metadata and rejects old accepted group owners")
    Media.close(player.media_warmup)
    check(player.media_warmup.plan_thread==null and player.media_warmup.optional_pending.is_empty(),"Close joins owned optional/required work and clears unpublished requests")
    # This metadata-only fixture never enters the tree; run its normal owner
    # teardown explicitly before freeing the detached scene.
    player._exit_tree()
    player.context_menu.free(); player.free()
    evidence = {"groups_prepared":prepared.groups.size(),"required":prepared.value.required.size(),
        "environment":prepared.value.environment_required.size(),"optional_completions":completions}
    finish_handoff()

func finish_handoff() -> void:
    var report := {"checks":checks,"failures":failures,"state":state_path,"evidence":evidence,
        "scope":"Exact authored source closure from operation-before, accepted group ownership, older current plus two queued operations, no early state/pins/readiness, immutable optional transfer, >2 fallback, same-epoch stale owner/reset/close. Headless only; no live latency claim."}
    FileAccess.open("res://generated/media_handoff_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("MEDIA_HANDOFF_CHECKS ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
