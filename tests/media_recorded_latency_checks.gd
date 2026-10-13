extends "res://tests/media_latency_checks.gd"
# Exact current-schema recorded command groups, with the original world-source
# adapter and frozen pre-optimization demand body as independent references.
const Journal = preload("res://sdk/journal.gd")
const Reducer = preload("res://sdk/reducer.gd")
const DemandReference = preload("res://tests/media_demand_reference.gd")

func verify_recorded(state: Dictionary, groups: Array, cache: Dictionary, label: String) -> void:
    var requested = groups.slice(0,2)
    var expected_character = Media.plan(state,requested,{})
    var expected_environment = exhaustive(state,requested,{})
    var result = {}
    Media._plan_sources({"key":[1,requested.map(func(row):return row.id),0],"state":state,"groups":requested},result,cache)
    for field in ["required","upcoming","errors","upcoming_errors","gpu_only","cpu_required"]:
        check(result.value[field]==expected_character[field],label+" exact character "+field)
    for field in ["required","upcoming","fixtures"]:
        var actual = result.value.fixtures if field=="fixtures" else result.value["environment_"+field]
        check(actual==expected_environment[field],label+" exact original world "+field)
    var optional = {}
    Media._plan_optional(result.optional_request,optional,cache)
    var fast = Media.create(); var reference = Media.create()
    for data in [fast,reference]: Media.adopt_encounter(data,optional.value.encounter,1)
    var wanted = {}; var environment = result.value.environment_required.duplicate()
    environment.merge(result.value.environment_upcoming)
    for paths in [result.value.required,result.value.upcoming,environment]:
        for path in paths: wanted[path] = Catalog.media_path(path)
    Media.demand(fast,wanted,environment,result.value.fixtures,result.value.gpu_only,result.value.cpu_required)
    DemandReference.demand(reference,wanted,environment,result.value.fixtures,result.value.gpu_only,result.value.cpu_required)
    for field in ["pending","queued","wanted","environment","fixtures","gpu_only","cpu_required","failed",
        "preload_selected","preload_skipped","preload_estimated_bytes","required_estimated_bytes","unknown_required",
        "boot_paths","boot_started","boot_complete","ready_paths","boot_waiting","selected_ready","selected_failed"]:
        check(fast[field]==reference[field],label+" frozen demand "+field)
    for category in [false,true]:
        var current = Media.diagnostics(fast,category); var prior = Media.diagnostics(reference,category)
        for field in ["pending","resident_sheets","estimated_bytes","pinned_bytes","cpu_bytes","gpu_estimated_bytes"]:
            check(current[field]==prior[field],label+" exact residency accounting "+field)
    evidence[label] = {"groups":requested.map(func(row):return row.id),"required":result.value.required.size(),
        "environment":result.value.environment_required.size(),"phases":result.phases,"optional_phases":optional.phases}
    Media.close(fast); Media.close(reference)

func run() -> void:
    var directory = ""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="): directory=arg.trim_prefix("--recording=")
    if directory.is_empty(): check(false,"Usage: --recording=<current schema journal>"); finish(); return
    var journal=Journal.new()
    var opened=journal.open(directory,false,false)
    check(opened.ok,"Explicit current journal opens without schema substitution")
    if not opened.ok: finish(); return
    var state={}; var source_cache={}; var selected=0
    var files=DirAccess.get_files_at(directory); files.sort()
    for file in files:
        if file.length()!=21 or not file.ends_with(".json"): continue
        var name="InitializationResponse" if state.is_empty() else "PlayerOperation"
        var decoded=journal.protocol.decode(name,FileAccess.get_file_as_bytes(directory.path_join(file)))
        check(decoded.ok,"Current admitted wire "+file)
        if not decoded.ok: break
        var packet=journal.protocol._normalize_admitted(name,decoded.value)
        if state.is_empty():
            var initial=Reducer.reduce_initialization(packet.initialization,packet.content_additions)
            check(initial.ok,"Original initialization reduces")
            if not initial.ok: break
            state=initial.value; continue
        var chosen=packet.get("command_number") in [48,56]
        var reduced=Reducer._reduce_operation_recorded(state,packet) if chosen else Reducer.reduce_operation(state,packet)
        check(reduced.ok,"Original operation reduces "+file)
        if not reduced.ok: break
        if chosen:
            var compiled=Compiler.compile_recorded(state,packet,source_cache,reduced.value,reduced.transitions)
            check(compiled.ok,"Actual measured command compiles "+file)
            if not compiled.ok: break
            verify_recorded(state,compiled.value.groups,source_cache,"command "+str(packet.command_number)+" before")
            verify_recorded(reduced.value,[],source_cache,"command "+str(packet.command_number)+" after")
            selected+=1
        state=reduced.value
        if selected==2: break
    check(selected==2,"Both actual cold48 and warm56 command boundaries compared")
    state_path=directory
    var report={"checks":checks,"failures":failures,"recording":directory,"evidence":evidence,
        "scope":"Actual schema8 cold48/warm56 before/after groups. Required source closure vs exhaustive original world adapter and exact queue/budget/boot roles vs frozen927a55b demand. Headless correctness only."}
    FileAccess.open("res://generated/media_recorded_latency_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("MEDIA_RECORDED_LATENCY_CHECKS ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
