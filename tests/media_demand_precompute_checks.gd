extends "res://tests/media_demand_checks.gd"
const Player=preload("res://play.gd")
# Existing optional worker may prepare pure selection only. Every rejected
# captured input follows the independent original demand, including role recovery.
func observable(data:Dictionary) -> Dictionary:
    var result:Dictionary=super.observable(data)
    for category in ["false","true"]:
        result[category].metadata_phases.erase("optional_validation")
        result[category].metadata_phases.erase("optional_validation_ms")
    return result

func optional_dispatch() -> void:
    var base:Dictionary=family()
    base.selection_index=Encounter.selection_index(base)
    reset(base)
    demand("Dispatch fixture demand",{"a":"/test/a.png"})
    publish("a");Media.boot_ready(fast);Media.boot_ready(reference)
    demand("Dispatch fixture boot complete",{"a":"/test/a.png"})
    fast.optional_pending={"key":[1,[],0],"state":{"actors":{}},"groups":[],
        "required":{"environment_required":{},"environment_upcoming":{},"required":{},"upcoming":{},"fixtures":{},"cpu_required":{},"gpu_only":{}}}
    Media._start_plan(fast)
    check(fast.plan_task<0 and not fast.optional_pending.is_empty(),"Optional receipt waits for final exact scene demand")
    Media.demand(fast,{"b":"/test/b.png","a":"/test/a.png"})
    check(fast.plan_task>=0 and fast.optional_pending.is_empty(),"Demand dispatches the existing optional worker after selecting new pins")
    check(fast.metadata_phases.optional_capture.required==2,"Capture sees the newly selected demand, not previous group paths")
    var completed:Dictionary={};var deadline:int=Time.get_ticks_msec()+10000
    while completed.is_empty() and Time.get_ticks_msec()<deadline:
        completed=Media.poll_plan(fast)
        if completed.is_empty():await process_frame
    check(completed.get("stage","")=="optional" and completed.value.demand_precomputation.is_empty(),
        "Optional worker completes normally and unknown exact paths retain strict fallback")
    fast.optional_pending={"key":[1,[],0]}
    Media.close(fast)
    check(fast.optional_pending.is_empty() and fast.plan_task<0,"Close releases undispatched optional intent without spawning work")

func stable_scene_dispatch() -> void:
    var player=Player.new()
    player.timeline.state={"actors":{}}
    player.media_plan_epoch=player.timeline.initialization_revision
    player.media_plan_key=[player.timeline.initialization_revision,[],player.timeline.revision]
    player.media_warmup.optional_pending={"key":player.media_plan_key,"state":{"actors":{}},"groups":[],
        "required":{"environment_required":{},"environment_upcoming":{},"required":{},"upcoming":{},"fixtures":{},"cpu_required":{},"gpu_only":{}}}
    var frozen:PackedByteArray=var_to_bytes(player.timeline.state)
    player._prepare_media()
    check(player.media_warmup.plan_task>=0 and player.media_warmup.optional_pending.is_empty(),
        "Stable Play media key dispatches newer optional intent after an older task completed")
    check(var_to_bytes(player.timeline.state)==frozen and player.timeline.queue.is_empty(),
        "Stable-key optional dispatch publishes no gameplay state or events")
    Media.close(player.media_warmup)
    player.context_menu.free();player.free()

func hold_metadata(entered:Semaphore,release:Semaphore)->void:
    entered.post();release.wait()

func contraction_deferral() -> void:
    var base:Dictionary=family();base.selection_index=Encounter.selection_index(base)
    var old_paths:Dictionary={"a":"/test/a.png","outside":"/test/outside.png"}
    var paths:Dictionary={"a":"/test/a.png"}
    for change in ["accepted","cancelled","budget","role","boot","epoch","absolute","growth"]:
        reset(base,32)
        for data in [fast,reference]:Media.adopt_source_sizes(data,{"outside":8},1)
        demand(change+" contraction initial",old_paths)
        for source in ["a","b","c","outside"]:publish(source)
        Media.boot_ready(fast);Media.boot_ready(reference)
        demand(change+" contraction boot",old_paths)
        var entry:Semaphore=Semaphore.new();var release:Semaphore=Semaphore.new()
        fast.plan_task=WorkerThreadPool.add_task(hold_metadata.bind(entry,release),false,"Held existing metadata boundary")
        entry.wait()
        fast.optional_pending={"key":[1,[],0]}
        var next:Dictionary=paths.duplicate();var roles:Array=[{},{},{},{}]
        for data in [fast,reference]:
            match change:
                "budget":data.budget_bytes=48
                "boot":data.boot_complete=false
        match change:
            "cancelled":fast.optional_pending={}
            "role":roles[1]={"a":true}
            "epoch":fast.optional_pending.key[0]=2
            "absolute":next.a="/other/a.png"
            "growth":next={"a":"/test/a.png","outside":"/test/outside.png","b":"/test/b.png"}
        Media.demand(fast,next,roles[0],roles[1],roles[2],roles[3])
        Reference.demand(reference,next,roles[0],roles[1],roles[2],roles[3])
        check(fast.demand_counts.selection_deferred==(change=="accepted"),change+": exact contraction deferral boundary")
        check(Media.ready(fast,next)==Media.ready(reference,next),change+": exact required readiness matches synchronous oracle")
        if change=="accepted":
            check(fast.preload_selected.keys()==["a"] and reference.preload_selected.keys()==["a","b"],
                "First admission retains only already-budgeted optional pins while pure expansion waits")
            check(Media.diagnostics(fast).pinned_bytes<=fast.budget_bytes and fast.pending.is_empty() and Media.ready(fast,next),
                "Contraction never exceeds cap, creates a mandatory hold, or restarts warm sources")
            check(fast.demand_counts.resident_refreshed==0 and fast.demand_counts.priority_scanned==0,
                "Unchanged optional membership/roles do not scan newly fillable families on first render")
            var input:Dictionary=Media._capture_demand(fast)
            var prepared:Dictionary=Media._precompute_demand(input,base)
            check(not prepared.is_empty(),"Existing metadata worker can finish expansion even when family stays equal")
            fast.optional_pending={}
            Media.adopt_encounter(fast,base,1,prepared)
            Media.demand(fast,next)
            check(fast.demand_counts.precomputed,"Equal-family expansion is adopted instead of hidden behind exact-demand no-op")
        fast.optional_pending={}
        release.post();WorkerThreadPool.wait_for_task_completion(fast.plan_task);fast.plan_task=-1
        check(observable(fast)==observable(reference),change+": eventual queue, roles, budget and accounting equal frozen synchronous demand")

func unrelated_headers() -> void:
    var base:Dictionary=family();base.selection_index=Encounter.selection_index(base)
    reset(base)
    demand("Header scope baseline",{"a":"/test/a.png"})
    publish("a");Media.boot_ready(fast);Media.boot_ready(reference)
    demand("Header scope boot complete",{"a":"/test/a.png"})
    for data in [fast,reference]:Media.adopt_source_sizes(data,{"a":99},1)
    demand("Fixed family estimate overrides participating header",{"a":"/test/a.png"},[{},{},{},{}],true)
    check(fast.required_estimated_bytes==16,"Unconsumed header cannot change fixed family budget arithmetic")
    for data in [fast,reference]:Media.adopt_source_sizes(data,{"new-lookahead":8},1)
    demand("Unrelated lookahead header retains accepted ledger",{"a":"/test/a.png"},[{},{},{},{}],true)
    demand("New header path becomes required",{"new-lookahead":"/test/lookahead.png"})
    check(fast.required_estimated_bytes==16 and fast.pending[0].path=="new-lookahead",
        "Promoted header still enters exact budget/readiness and mandatory queue")
    for data in [fast,reference]:Media.adopt_source_sizes(data,{"new-lookahead":16},1)
    demand("Participating header update invalidates ledger",{"new-lookahead":"/test/lookahead.png"})
    check(fast.required_estimated_bytes==32,"Changed participating header updates CPU plus GPU estimate")

func readonly_capture() -> void:
    var base:Dictionary=family()
    for field in ["paths","environment","fixtures","gpu_only","cpu_required"]:base[field].make_read_only()
    base.selection_index=Encounter.selection_index(base)
    reset(base,32)
    var paths:Dictionary={"a":"/test/a.png"}
    demand("Readonly owner baseline",paths)
    publish("a");Media.boot_ready(fast);Media.boot_ready(reference)
    demand("Readonly owner boot",paths)
    var input:Dictionary=Media._capture_demand(fast)
    check(fast.preload_selected.is_read_only() and is_same(input.selected,fast.preload_selected),
        "Capture retains immutable internally selected membership without copying")
    check(is_same(input.family_roles.cpu_required,fast.selection_roles.cpu_required),
        "Capture retains immutable published family-role ownership")
    paths.a="/mutated/a.png"
    check(input.selection_required.a=="/test/a.png" and input.paths.a=="/test/a.png",
        "Mutable caller paths and selection_required remain detached from worker input")
    var same_values:Dictionary=input.selected.duplicate()
    check(Media._captured_selection_matches(input,same_values),"Writable equivalent selection still uses exact values and order")
    same_values.erase("a");same_values.a="/test/a.png"
    check(not Media._captured_selection_matches(input,same_values),"Writable equal membership with changed order rejects identity shortcut")

func immutable_family(revision:int=1, include_outside:bool=true) -> Dictionary:
    var result:Dictionary=family()
    result.revision=revision
    if include_outside:result.estimates.outside={"bytes":16}
    result.estimate_bytes=Encounter.estimate_bytes(result.estimates)
    for field in ["paths","environment","fixtures","gpu_only","cpu_required","estimate_bytes","estimate_summary"]:result[field].make_read_only()
    result.selection_index=Encounter.selection_index(result)
    result.selection_index.positions.make_read_only();result.selection_index.ordered_paths.make_read_only()
    result.selection_index.make_read_only();result.make_read_only()
    return result

func contraction_refill() -> void:
    for change in ["accepted","budget","epoch","role","profile","superseded","selected","family_role","close"]:
        var base:Dictionary=immutable_family()
        reset(base,32)
        var old_paths:Dictionary={"a":"/test/a.png","outside":"/test/outside.png"}
        demand(change+" refill initial",old_paths)
        for source in ["a","b","c","outside"]:publish(source)
        Media.boot_ready(fast);Media.boot_ready(reference)
        demand(change+" refill boot",old_paths)
        var paths:Dictionary={"a":"/test/a.png"}
        Media.demand(fast,paths);Reference.demand(reference,paths)
        check(fast.demand_counts.selection_deferred and fast.plan_task>=0,
            change+": strict immutable contraction dispatches existing optional worker without source planning")
        check(Media.ready(fast,paths) and Media.diagnostics(fast).pinned_bytes<=32,
            change+": retained pins stay capped and exact received source is ready")
        check(fast.preload_selected.keys()==["a"] and fast.demand_counts.priority_scanned==0,
            change+": first display does not fill optional remainder or replay family priority")
        if change=="close":
            Media.close(fast)
            check(fast.plan_task<0 and fast.optional_pending.is_empty(),"Close joins pure selection worker and releases pending ownership")
            continue
        var completed:Dictionary={}
        while completed.is_empty():
            completed=Media.poll_plan(fast)
            if completed.is_empty():await process_frame
        check(completed.selection_only and completed.phases.keys()==["selection"] and not completed.has("source_files"),
            change+": pure result contains no authoring scan/source publication")
        if change=="selected":
            # Compare both full-demand bodies from the same retained selection
            # before simulating external mutation, not from already-filled pins.
            for field in ["preload_selected","selection_required",
                "selection_extra","selection_summary","selection_roles","selected_ready","selected_failed"]:
                reference[field]=fast[field].duplicate()
            reference.preload_skipped=fast.preload_skipped
            reference.preload_estimated_bytes=fast.preload_estimated_bytes
            reference.stats={}
        var roles:Array=[{},{},{},{}]
        for data in [fast,reference]:
            match change:
                "budget":data.budget_bytes=48
                "epoch":Media.adopt_encounter(data,base,2)
                "selected":data.preload_selected=data.preload_selected.duplicate();data.preload_selected.erase("a");data.stats={}
                "family_role":data.selection_roles.cpu_required={"a":true}
        match change:
            "role":roles[1]={"a":true}
            "profile":paths={"b":"/test/b.png"}
            "superseded":
                paths={"b":"/test/b.png","a":"/test/a.png"}
                Media.demand(fast,paths);Reference.demand(reference,paths)
        if change!="epoch":fast.demand_precomputation=completed.value.demand_precomputation
        Media.demand(fast,paths,roles[0],roles[1],roles[2],roles[3])
        reference.demand_snapshot={}
        Reference.demand(reference,paths,roles[0],roles[1],roles[2],roles[3])
        check(fast.demand_counts.precomputed==(change=="accepted"),change+": exact captured input accepts only unchanged authority/roles/profile/budget")
        var a:Dictionary=observable(fast);var b:Dictionary=observable(reference)
        for category in ["false","true"]:
            for field in ["metadata_jobs","metadata_phases","selection_jobs","selection_refreshed"]:
                a[category].erase(field);b[category].erase(field)
        if a!=b:
            for field in a:
                if a[field]!=b[field]:print("REFILL_DIFFERENCE ",change," ",field," ",a[field]," vs ",b[field])
        check(a==b,change+": exact ordered queue/readiness/accounting equals frozen synchronous oracle")
    for boundary in ["mutable_family","unknown_exact","role"]:
        var plan:Dictionary=family() if boundary=="mutable_family" else immutable_family()
        reset(plan,32)
        for data in [fast,reference]:Media.adopt_source_sizes(data,{"outside":8,"unknown":8},1)
        var old_paths:Dictionary={"a":"/test/a.png","outside":"/test/outside.png","unknown":"/test/unknown.png"}
        demand(boundary+" requeue fallback initial",old_paths)
        for source in ["a","b","c","outside","unknown"]:publish(source)
        Media.boot_ready(fast);Media.boot_ready(reference)
        demand(boundary+" requeue fallback boot",old_paths)
        var paths:Dictionary={"a":"/test/a.png"}
        if boundary=="unknown_exact":paths.unknown="/test/unknown.png"
        var roles:Array=[{},{},{},{}]
        if boundary=="role":roles[1]={"a":true}
        demand(boundary+" requeue retains synchronous fallback",paths,roles)
        check(not fast.demand_counts.selection_deferred and fast.plan_task<0 and fast.optional_pending.is_empty(),
            boundary+": no worker or retained selection when immutable complete role proof is absent")
    reset(family(),32)
    var diagnostic:Dictionary={}
    Media._precompute_demand({},fast.encounter,diagnostic)
    check(diagnostic.reason=="missing_capture","Precompute exposes missing capture reason")
    var base:Dictionary=immutable_family()
    reset(base,32)
    demand("Estimate diagnostic setup",{"a":"/test/a.png"})
    publish("a");Media.boot_ready(fast);Media.boot_ready(reference)
    demand("Estimate diagnostic boot",{"a":"/test/a.png"})
    var input:Dictionary=Media._capture_demand(fast)
    input.paths={"unknown":"/test/unknown.png"}
    check(Media._precompute_demand(input,base,diagnostic).is_empty() and diagnostic.reason=="missing_exact_estimate" and diagnostic.path=="unknown",
        "Native/resident-only exact source remains fallback with concrete rejection path")

func failed_refill() -> void:
    for failure in ["worker_error","empty_result","stale_epoch","stale_family"]:
        var base:Dictionary=immutable_family()
        reset(base,32)
        var old_paths:Dictionary={"a":"/test/a.png","outside":"/test/outside.png"}
        demand(failure+" initial",old_paths)
        for source in ["a","b","c","outside"]:publish(source)
        Media.boot_ready(fast);Media.boot_ready(reference)
        demand(failure+" boot",old_paths)
        var paths:Dictionary={"a":"/test/a.png"}
        Media.demand(fast,paths);Reference.demand(reference,paths)
        var completed:Dictionary={}
        while completed.is_empty():
            completed=Media.poll_plan(fast)
            if completed.is_empty():await process_frame
        completed.value.demand_precomputation={}
        if failure!="empty_result":completed.error="Injected pure worker failure"
        if failure=="stale_epoch":completed.key=[2]
        if failure=="stale_family":completed.value.encounter=immutable_family()
        var player=Player.new()
        player.timeline.initialization_revision=1
        player.media_warmup=fast
        player.media_plan_key=["unchanged"]
        player._adopt_media_plan(completed,false)
        var current:bool=failure in ["worker_error","empty_result"]
        check(fast.demand_snapshot.is_empty()==current and player.media_plan_key.is_empty()==current,
            failure+": only current failed pure completion invalidates temporary selection ledger")
        check(player.media_group_plans.is_empty() and player.presentation_errors.is_empty(),
            failure+": optional failure does not replace required plans or block gameplay")
        if current:
            Media.demand(fast,paths)
            check(not fast.demand_counts.noop and not fast.demand_counts.selection_deferred and fast.plan_task<0,
                failure+": next demand performs original synchronous selection without another worker retry")
            var a:Dictionary=observable(fast);var b:Dictionary=observable(reference)
            for category in ["false","true"]:
                for field in ["metadata_jobs","metadata_phases","selection_jobs","selection_refreshed"]:
                    a[category].erase(field);b[category].erase(field)
            check(a==b and Media.ready(fast,paths),failure+": failed worker recovers exact frozen-oracle pins, queue, budget and readiness")
        player.media_warmup=Media.create()
        player.context_menu.free();player.free()

func header_precomputation() -> void:
    for change in ["gpu","cpu","cpu_wins","header_changed","untyped","resident_only","family_override","family_override_negative","old_family_override"]:
        var base:Dictionary=family();base.selection_index=Encounter.selection_index(base)
        if change=="old_family_override":
            base.estimates.outside={"bytes":24}
            base.estimate_bytes=Encounter.estimate_bytes(base.estimates)
        reset(base,48)
        if change!="resident_only":
            for data in [fast,reference]:Media.adopt_source_sizes(data,{"outside":8},1)
        var paths:Dictionary={"a":"/test/a.png","outside":"/test/outside.png"}
        var roles:Array=[{},{},{"outside":true},{}]
        if change in ["cpu","cpu_wins"]:roles[3]={"outside":true}
        if change=="cpu":roles[2]={}
        if change=="untyped":roles[2]={}
        demand(change+" header setup",paths,roles)
        for source in ["a","b","c","outside"]:publish(source)
        Media.boot_ready(fast);Media.boot_ready(reference)
        demand(change+" header boot",paths,roles)
        var input:Dictionary=Media._capture_demand(fast)
        var next:Dictionary=base.duplicate(true);next.revision=2;next.fixtures={"c":true}
        if change in ["family_override","family_override_negative"]:
            next.estimates.outside={"bytes":24 if change=="family_override" else -1}
            next.estimate_bytes=Encounter.estimate_bytes(next.estimates)
        if change=="old_family_override":
            next.estimates.erase("outside")
            next.estimate_bytes=Encounter.estimate_bytes(next.estimates)
        next.selection_index=Encounter.selection_index(next)
        var diagnostics:Dictionary={}
        var prepared:Dictionary=Media._precompute_demand(input,next,diagnostics)
        var valid:bool=change not in ["untyped","resident_only","family_override_negative"]
        check(not prepared.is_empty()==valid,change+": only fixed headers with explicit CPU/GPU roles extend pure estimate coverage")
        if valid:
            check(input.headers.is_read_only() and input.headers.outside==8,change+": capture owns immutable raw header bytes")
            var expected:int=40 if change=="family_override" else 32 if change in ["cpu","cpu_wins"] else 24
            check(prepared.used==expected,change+": worker mirrors fixed-family precedence and CPU plus GPU byte accounting")
        if change=="family_override_negative":
            check(diagnostics.reason=="unknown_fixed_estimate","Fixed negative estimate retains precedence over positive captured raw header")
        if change=="header_changed":
            for data in [fast,reference]:Media.adopt_source_sizes(data,{"outside":16},1)
            check(input.headers.outside==8,"Current header replacement cannot mutate captured worker input")
        Media.adopt_encounter(fast,next,1,prepared);Media.adopt_encounter(reference,next,1)
        demand(change+" header final exact oracle",paths,roles)
        check(fast.demand_counts.precomputed==(valid and change!="header_changed"),change+": current header changes reject stale calculated budget")

func removed_role_contraction() -> void:
    for role in ["environment","fixtures","gpu_only","cpu_required"]:
        var base:Dictionary=immutable_family()
        reset(base,48)
        var paths:Dictionary={"a":"/test/a.png","b":"/test/b.png","outside":"/test/outside.png"}
        var roles:Array=[{},{},{},{}]
        roles[["environment","fixtures","gpu_only","cpu_required"].find(role)]={"b":true,"outside":true}
        demand(role+" removed role initial",paths,roles)
        for source in ["a","b","c","outside"]:publish(source,8,role=="fixtures")
        Media.boot_ready(fast);Media.boot_ready(reference)
        demand(role+" removed role boot",paths,roles)
        var current:Dictionary={"a":"/test/a.png"}
        Media.demand(fast,current);Reference.demand(reference,current)
        check(fast.demand_counts.selection_deferred and fast.preload_selected.keys()==["a","b"],
            role+": removed-required role changes retain capped optional membership")
        check(Media.ready(fast,current) and Media.diagnostics(fast).pinned_bytes<=48,
            role+": current exact readiness and pin cap stay correct before worker refill")
        check(fast.resident.b.environment==false and fast.resident.outside.environment==false and not Media._pinned(fast,"outside"),
            role+": current role categories update and removed unselected source unpins immediately")
        if fast.plan_task<0:continue
        var completed:Dictionary={}
        while completed.is_empty():
            completed=Media.poll_plan(fast)
            if completed.is_empty():await process_frame
        fast.demand_precomputation=completed.value.demand_precomputation
        Media.demand(fast,current)
        var a:Dictionary=observable(fast);var b:Dictionary=observable(reference)
        for category in ["false","true"]:
            for field in ["metadata_jobs","metadata_phases","selection_jobs","selection_refreshed"]:
                a[category].erase(field);b[category].erase(field)
        check(a==b,role+": final ordered queues, byte/category accounting and exact readiness equal frozen synchronous demand")

func captured_superset() -> void:
    for change in ["accepted","removed_role","consecutive","current_role","unrelated_role","budget","prior_selected","prior_order","headers","over_budget","pending"]:
        var base:Dictionary=immutable_family()
        reset(base,16 if change=="over_budget" else 48)
        for data in [fast,reference]:Media.adopt_source_sizes(data,{"outside":8},1)
        var old:Dictionary={"a":"/test/a.png","b":"/test/b.png","outside":"/test/outside.png"}
        var roles:Array=[{},{},{},{}]
        if change=="removed_role":roles[0]={"b":true,"outside":true}
        if change=="headers":roles[2]={"outside":true}
        demand(change+" superset initial",old,roles)
        for source in ["a","b","c","outside"]:publish(source)
        Media.boot_ready(fast);Media.boot_ready(reference)
        demand(change+" superset boot",old,roles)
        var input:Dictionary=Media._capture_demand(fast)
        var next:Dictionary=immutable_family(2,change!="headers")
        var prepared:Dictionary=Media._precompute_demand(input,next)
        check(not prepared.is_empty(),change+": completed worker prepares exact prior larger demand")
        var current:Dictionary={"a":"/test/a.png"}
        if change=="consecutive":current.b="/test/b.png"
        var current_roles:Array=[{},{},{},{}]
        if change=="current_role":current_roles[1]={"a":true}
        if change=="unrelated_role":current_roles[1]={"c":true}
        for data in [fast,reference]:
            match change:
                "budget":data.budget_bytes=64
                "prior_selected":data.preload_selected=data.preload_selected.duplicate();data.preload_selected.erase("b");data.stats={}
                "prior_order":data.wanted={"outside":"/test/outside.png","b":"/test/b.png","a":"/test/a.png"}
                "headers":Media.adopt_source_sizes(data,{"outside":16},1)
        if change=="pending":fast.optional_pending={"key":[1],"selection_family":base}
        Media.adopt_encounter(fast,next,1,prepared);Media.adopt_encounter(reference,next,1)
        Media.demand(fast,current,current_roles[0],current_roles[1],current_roles[2],current_roles[3])
        Reference.demand(reference,current,current_roles[0],current_roles[1],current_roles[2],current_roles[3])
        var accepted:bool=change in ["accepted","removed_role","consecutive"]
        check(fast.demand_counts.precomputed_superset==accepted,change+": strict captured-superset ownership/cap/role guards")
        check(fast.required_estimated_bytes==reference.required_estimated_bytes and fast.unknown_required==reference.unknown_required \
            and Media.ready(fast,current)==Media.ready(reference,current),change+": current exact bytes/readiness never reuse larger demand totals")
        if accepted:
            check(fast.preload_selected==prepared.selected and fast.selection_required==input.paths and fast.selection_extra==prepared.extra,
                change+": already-capped worker pins retain their true larger-demand provenance")
            check(fast.plan_task>=0 and Media.diagnostics(fast).pinned_bytes<=fast.budget_bytes,
                change+": existing pure worker refills only after immediate capped family adoption")
            if change=="consecutive":
                current={"a":"/test/a.png"}
                Media.demand(fast,current);Reference.demand(reference,current)
                check(fast.demand_counts.selection_deferred and not fast.optional_pending.is_empty(),
                    "Second exact contraction queues latest refill behind the existing worker")
            var completed:Dictionary={}
            while completed.is_empty():
                completed=Media.poll_plan(fast)
                if completed.is_empty():await process_frame
            check(not completed.value.demand_precomputation.is_empty(),change+": preserved provenance prevents refill no-op")
            fast.demand_precomputation=completed.value.demand_precomputation
            Media.demand(fast,current)
            if change=="consecutive":
                check(not fast.demand_counts.precomputed and fast.plan_task>=0,
                    "Older refill cannot supersede the queued newer exact contraction")
                completed={}
                while completed.is_empty():
                    completed=Media.poll_plan(fast)
                    if completed.is_empty():await process_frame
                check(completed.value.demand_precomputation.is_empty(),
                    "Latest refill observes already-recovered current optimal pins without duplicate expansion")
        var a:Dictionary=observable(fast);var b:Dictionary=observable(reference)
        for category in ["false","true"]:
            for field in ["metadata_jobs","metadata_phases","selection_jobs","selection_refreshed"]:
                a[category].erase(field);b[category].erase(field)
        check(a==b,change+": eventual ordered selection/queue/roles/accounting match frozen synchronous oracle")
    var base:Dictionary=immutable_family()
    reset(base,16)
    var old:Dictionary={"a":"/test/a.png","b":"/test/b.png"}
    demand("Over-cap old mandatory pins",old)
    publish("a");publish("b");Media.boot_ready(fast);Media.boot_ready(reference)
    demand("Over-cap completed boot",old)
    demand("Over-cap contraction stays synchronous",{"a":"/test/a.png"})
    check(not fast.demand_counts.selection_deferred and fast.preload_selected.keys()==["a"] and Media.diagnostics(fast).pinned_bytes<=16,
        "Formerly mandatory over-cap sources cannot become retained optional pins")

func run() -> void:
    await captured_superset()
    await removed_role_contraction()
    header_precomputation()
    await failed_refill()
    await contraction_refill()
    readonly_capture()
    unrelated_headers()
    contraction_deferral()
    stable_scene_dispatch()
    await optional_dispatch()
    var base:Dictionary=family()
    base.selection_index=Encounter.selection_index(base)
    var wanted:Dictionary={"a":"/test/a.png","b":"/test/b.png"}
    for change in ["accepted","budget","epoch","boot","order","path","exact_role","selected","family_role","selection_revision"]:
        reset(base,32)
        demand(change+" initial",wanted)
        publish("a");publish("b");publish("c")
        Media.boot_ready(fast);Media.boot_ready(reference)
        demand(change+" complete boot",wanted)
        var input:Dictionary=Media._capture_demand(fast)
        var frozen:PackedByteArray=var_to_bytes(input)
        var next:Dictionary=base.duplicate(true)
        next.revision=2;next.fixtures={"c":true}
        next.selection_index=Encounter.selection_index(next)
        var prepared:Dictionary=Media._precompute_demand(input,next)
        check(not prepared.is_empty() and var_to_bytes(input)==frozen,change+": worker selection leaves captured inputs untouched")
        Media.adopt_encounter(fast,next,1,prepared);Media.adopt_encounter(reference,next,1)
        var paths:Dictionary=wanted.duplicate()
        var roles:Array=[{},{},{},{}]
        for data in [fast,reference]:
            match change:
                "budget":data.budget_bytes=48
                "epoch":Media.adopt_encounter(data,next,2)
                "boot":data.boot_complete=false
                "selected":data.preload_selected=data.preload_selected.duplicate();data.preload_selected.erase("b");data.stats={}
                "family_role":data.selection_roles.cpu_required={"c":true}
                "selection_revision":data.selection_revision=-9
        match change:
            "order":paths={"b":"/test/b.png","a":"/test/a.png"}
            "path":paths.a="/other/a.png"
            "exact_role":roles[0]={"a":true}
        demand(change+" captured optional adoption",paths,roles)
        check(fast.demand_counts.precomputed==(change=="accepted"),change+": strict captured-input eligibility")
        check(fast.demand_precomputation.is_empty(),change+": captured result consumed once or rejected")
        if change=="accepted":
            check(not Media.ready(fast,{"c":true}),"New optional fixture role does not inherit stale colour readiness")
            demand("Deferred fixture becomes mandatory",{"c":"/test/c.png"})
            check(not Media.ready(fast,{"c":true}) and fast.pending[0].path=="c" and fast.pending[0].fixture,
                "Previously optional unsatisfied role is decoded before later mandatory admission")
    reset(base)
    check(Media._capture_demand(fast).is_empty(),"Startup does not precompute residency-dependent boot selection")
    var unknown:Dictionary=base.duplicate(true);unknown.estimate_summary.unknown=1
    check(Media._precompute_demand({"boot":[true,true]},unknown).is_empty(),"Unknown header budget retains exhaustive fallback")
    super.run()
