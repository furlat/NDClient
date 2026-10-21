extends "res://tests/media_demand_checks.gd"
## The removed flat-demand capture cache is not a source owner. Exercise its
## current successors: selector-owned immutable records and the existing
## physical owner's revision-checked optional worker/publication boundary.

func immutable_family(amounts:Array=[16,16,16])->Dictionary:
    var value:Dictionary=family(amounts)
    for field in ["paths","source_sizes","gpu_only"]:value[field].make_read_only()
    value.ordered_paths.make_read_only();value.make_read_only()
    return value

func record_demand(label:String,records:Array,hint:Dictionary={})->void:
    Media.demand_records(current,records,hint)
    original_demand(original,records,hint)
    await settle();compare(label)

func record_ownership()->void:
    var base:Dictionary=immutable_family()
    reset(base,32)
    var a:String="source/0";var b:String="source/1"
    var paths:Dictionary={a:base.paths[a],b:base.paths[b]}
    var gpu:Dictionary={a:true,b:true}
    var selected:Dictionary=Media.source_record(paths,{},{},gpu)
    var frozen:PackedByteArray=var_to_bytes(selected)
    check(selected.is_read_only() and selected.roles.is_read_only() and selected.roles.values().all(func(row):return row.is_read_only()),
        "Selector hands off immutable exact path/role records")
    paths[a]="/changed/caller.png";gpu.clear()
    check(selected.roles[a]==[base.paths[a],0,0,0] and var_to_bytes(selected)==frozen,
        "Mutable caller paths and roles cannot rewrite the published selector record")
    var records:Array=[selected]
    await record_demand("Original immutable contribution",records)
    var pending:Array=physical(current).pending.map(func(job):return [job.path,job.absolute,job.fixture,job.required])
    await record_demand("Retained exact contribution",records)
    check(current.demand_counts.records_retained==1 and current.demand_counts.source_role_entries_visited==0,
        "Retained selector ownership visits no source-role entries")
    check(physical(current).pending.map(func(job):return [job.path,job.absolute,job.fixture,job.required])==pending,
        "Retained selection preserves exact queued source/order/role operands")
    await record_demand("Fresh equal contribution",[Media.source_record({a:base.paths[a],b:base.paths[b]},{},{},{a:true,b:true})])
    check(physical(current).pending.map(func(job):return [job.path,job.absolute,job.fixture,job.required])==pending,
        "Equal detached contribution values do not restart or reorder retained source work")
    check(var_to_bytes(selected)==frozen,"Selection and budget workers never mutate the source-owned record")

func overlapping_roles()->void:
    var base:Dictionary=immutable_family([8,8,8])
    reset(base,32)
    var a:String="source/0";var b:String="source/1"
    var body:Dictionary=Media.source_record({a:base.paths[a],b:base.paths[b]},{},{},{a:true,b:true})
    var cpu:Dictionary=Media.source_record({a:base.paths[a]},{},{},{},{a:true})
    var fixture:Dictionary=Media.source_record({a:base.paths[a]},{},{a:true},{a:true})
    var environment:Dictionary=Media.source_record({a:base.paths[a]},{a:true},{},{a:true})
    await record_demand("Overlapping exact source ownership",[body,cpu,fixture,environment])
    check(current.wanted.size()==2 and current.cpu_required.has(a) and current.fixtures.has(a) and current.environment.has(a),
        "Independent selectors share one source while retaining every required preprocessing role")
    await publish(a,8,true);await publish(b)
    check(Media.boot_ready(current) and Reference.boot_ready(original),"Exact initial receipts finish both startup owners before role withdrawal")
    check(Media.ready(current,{a:true,b:true}),"Actual color/GPU/fixture receipt satisfies all joined selectors")
    await record_demand("Withdraw one of several CPU owners",[body,fixture,environment])
    check(current.cpu_required.has(a) and current.fixtures.has(a),"Withdrawing one owner cannot erase another selector's role")
    await record_demand("Withdraw fixture but retain environment",[body,environment])
    check(not current.fixtures.has(a) and current.cpu_required.has(a) and Media.ready(current,{a:true}),
        "Role withdrawal preserves the still-owned original and exact readiness")
    await record_demand("Return to GPU-only body",[body])
    check(not current.cpu_required.has(a) and not current.environment.has(a),"Last explicit CPU role leaves the original GPU-only selection")
    # Previously used CPU pixels are retained cache while under budget. Create
    # actual pressure, as the independent physical-owner gate does, then prove
    # only CPU bytes retire and the still-required GPU allocation stays ready.
    current.budget_bytes=0;original.budget_bytes=0
    await record_demand("GPU-only retirement under actual pressure",[body])
    Media.release_cold_images(current,-1);Reference.release_cold_images(original,-1)
    compare("Joined selector CPU retirement")
    check(Media.ready(current,{a:true}) and current.resident[a].cpu_bytes==0,
        "CPU retirement cannot remove the remaining actual GPU allocation")

func staged_selection(change:String)->void:
    var base:Dictionary=immutable_family()
    reset(base,16)
    Media.demand_records(current,[]);original_demand(original,[],{})
    check(Media.boot_ready(current) and Reference.boot_ready(original),"Empty initial cut completes before post-startup selector revision controls")
    var a:String="source/0"
    var records:Array=[Media.source_record({a:base.paths[a]},{},{},{a:true})]
    Media.demand_records(current,records);original_demand(original,records,{})
    var owner:Dictionary=physical(current)
    var deadline:int=Time.get_ticks_msec()+10000
    while owner.selection_task<0 and Time.get_ticks_msec()<deadline:
        Media.prepare_optional(current);Reference.prepare_optional(original)
        if owner.selection_task<0:await process_frame
    check(owner.selection_task>=0,change+": constrained optional family starts the existing selection worker")
    if owner.selection_task<0:return
    while not WorkerThreadPool.is_task_completed(owner.selection_task) and Time.get_ticks_msec()<deadline:await process_frame
    check(WorkerThreadPool.is_task_completed(owner.selection_task),change+": existing worker completes within its bounded control")
    if not WorkerThreadPool.is_task_completed(owner.selection_task):return
    # The actual completed worker result has not been polled or published yet.
    var captured:int=owner.selection_result.revision
    var source_before:PackedByteArray=var_to_bytes(base)
    check(not Media.ready(current,{a:true}) and not owner.resident.has(a),
        change+": completed metadata cannot grant source/GPU readiness")
    var hint:Dictionary={}
    match change:
        "budget":current.budget_bytes=32;original.budget_bytes=32
        "required":records=[Media.source_record({"source/1":base.paths["source/1"]},{},{},{"source/1":true})]
        "role":records=[Media.source_record({a:base.paths[a]},{},{},{},{a:true})]
        "header":
            Media.adopt_source_sizes(current,{a:24},1);Reference.adopt_source_sizes(original,{a:24},1)
        "epoch":
            for pair in [[Media,current],[Reference,original]]:
                pair[0].adopt_required(pair[1],2);pair[0].adopt_source_sizes(pair[1],base.source_sizes,2);pair[0].adopt_encounter(pair[1],base,2)
        "family":
            var next:Dictionary=immutable_family([16,16])
            Media.adopt_encounter(current,next,1);Reference.adopt_encounter(original,next,1)
        "hint":
            hint={"paths":{"hint":"/test/hint.png"},"source_sizes":{"hint":8},"gpu_only":{"hint":true}}
        "close":
            Media.close(current)
            check(owner.selection_task<0 and owner.selection_result.is_empty() and owner.consumers.is_empty(),
                "Close joins the owned selection worker and withdraws its exact source interests")
            return
    Media.demand_records(current,records,hint);original_demand(original,records,hint)
    if change=="accepted":check(owner.selection_revision==captured,"Unchanged selector retains the actual worker revision")
    else:check(owner.selection_revision!=captured,change+": changed authority invalidates the completed worker revision")
    Media.prepare_optional(current)
    if change!="accepted":
        check(owner.selection_publication.get("revision",-1)!=captured,
            change+": stale completed budget output is not published under newer authority")
    await settle();compare(change+" actual worker adoption")
    var required:Dictionary={}
    for record in records:
        for path in record.roles:
            required[path]=int(base.source_sizes.get(path,0))*(2 if record.roles[path][1] else 1)
    if change=="header":required[a]=24
    if change not in ["epoch","hint"]:
        var expected:Dictionary=greedy(current.encounter,required,current.budget_bytes)
        check(owner.preload_selected==expected,change+": accepted ordered pins match the independent authored greedy budget")
    check(var_to_bytes(base)==source_before,change+": adoption leaves the actual immutable family unchanged")

func bounded_publication()->void:
    var amounts:Array=[]
    for i in 80:amounts.append(1)
    var base:Dictionary=immutable_family(amounts)
    reset(base,80)
    Media.demand_records(current,[]);original_demand(original,[],{})
    var owner:Dictionary=physical(current)
    check(Media.ready(current,{}) and Media.boot_ready(current) and Reference.boot_ready(original),"Empty required picture never waits for optional family discovery")
    Media.prepare_optional(current)
    var visited:int=0
    for row in owner.families:visited+=int(row.cursor)
    check(visited<=Media.OPTIONAL_UPDATES_PER_FRAME and owner.preload_selected.size()<=Media.OPTIONAL_UPDATES_PER_FRAME,
        "First optional admission stays within the existing per-frame family/publication allowance")
    var first:int=owner.optional_updates
    Media.prepare_optional(current)
    check(owner.optional_updates<=Media.OPTIONAL_UPDATES_PER_FRAME and owner.optional_updates>=first,
        "Repeated same-frame preparation shares one bounded optional allowance")
    await settle();compare("Bounded optional publication")
    check(owner.preload_selected==base.paths,"All eighty affordable actual source identities eventually publish in authored order")
    var consumer:Dictionary=owner.consumers[current.consumer_id]
    check(is_same(consumer.family,base),"Physical owner borrows the exact selector family instead of a reconstructed capture cache")
    current.optional_pending={"key":[1]}
    Media.close(current)
    check(current.optional_pending.is_empty() and current.plan_thread==null and owner.selection_task<0,
        "Close releases undispatched metadata intent and all owned selection work")

func run()->void:
    await record_ownership()
    await overlapping_roles()
    for change in ["accepted","budget","required","role","header","epoch","family","hint","close"]:await staged_selection(change)
    await bounded_publication()
    print("MEDIA_DEMAND_PRECOMPUTE ",JSON.stringify({"checks":checks,"failures":failures,
        "scope":"Current immutable selector records, joined roles, actual worker stale-result/close controls and bounded publication. Removed flat capture-cache implementation checks are retired; the complete independent frozen physical-owner oracle and authored budget matrix run next. No native texture/pixel/performance claim."}))
    await super.run()
