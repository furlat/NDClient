extends SceneTree
## Entire real recorded compilation, including native constructor cuts,
## histories, complete coverage, exact log multiplicity and hierarchy.
const Compiler=preload("res://presentation/compiler.gd")
const Journal=preload("res://sdk/journal.gd")
var oracle:Script
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("COMPILER_JOIN_FAIL ",label)
func _initialize()->void:run.call_deferred()
func run()->void:
    var recordings:Array=[];var oracle_path:String=""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--recording="):recordings.append(argument.trim_prefix("--recording="))
        if argument.begins_with("--oracle="):oracle_path=argument.trim_prefix("--oracle=")
    if recordings.is_empty() or oracle_path.is_empty():printerr("Requires --recording=<actual journal> [repeated] --oracle=<frozen pre-change compiler>");quit(2);return
    oracle=load(oracle_path)
    for directory in recordings:examine(directory)
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Exact frozen compiler+trace comparison on actual accepted records; all groups/commits/cuts/components/coverage/logs/versions and input ownership. Isolated timings exclude prior result destruction and are not live acceptance."}
    FileAccess.open("res://.runtime/compiler-join-parity-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("COMPILER_JOIN_PARITY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func examine(directory:String)->void:
    var journal=Journal.new();var opened:Dictionary=journal.open(directory,true,false)
    check(opened.ok,"Actual recorded protocol opens: "+directory)
    if not opened.ok:return
    check(journal.replay(0).ok,"Actual initialization reduces")
    var decoded:Dictionary=journal.protocol.decode("InitializationResponse",FileAccess.get_file_as_bytes(directory.path_join("0000000000000000.json")))
    var initial:Dictionary=journal.protocol.normalize("InitializationResponse",decoded.value)
    check(Compiler.EventTrace.initialization(initial.initialization)==oracle.EventTrace.initialization(initial.initialization),"Entire initial event/log hierarchy equals frozen trace")
    var files:Array=[]
    for file in DirAccess.get_files_at(directory):
        if file.ends_with(".json") and file.get_basename().is_valid_int() and int(file.get_basename())>0:files.append(file)
    files.sort()
    var cache:Dictionary={};var old_cache:Dictionary={}
    var operations:int=0;var rows:int=0;var versions:int=0;var native_requirements:int=0
    var actual:Dictionary={};var expected:Dictionary={}
    for file in files:
        var before:Dictionary=journal.state
        var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(file))
        decoded=journal.protocol.decode("PlayerOperation",raw)
        check(decoded.ok,"Actual packet decodes "+file)
        if not decoded.ok:break
        var admitted:Dictionary=journal._consume_admitted(decoded.value,raw,true)
        check(admitted.ok,"Real operation admits "+file)
        if not admitted.ok:break
        var held:PackedByteArray=var_to_bytes([before,admitted.normalized,admitted.transitions])
        # Release old local outputs outside the measured compiler call. Their
        # destruction is separate preparation-worker lifetime work.
        actual={};expected={}
        var began:int=Time.get_ticks_usec()
        actual=Compiler.compile_recorded(before,admitted.normalized,cache,journal.state,admitted.transitions,true)
        var elapsed:float=(Time.get_ticks_usec()-began)/1000.0
        expected=oracle.compile_recorded(before,admitted.normalized,old_cache,journal.state,admitted.transitions)
        check(actual.ok and expected.ok,"Both compilers schedule accepted operation "+file)
        if not actual.ok or not expected.ok:break
        check(actual.value==expected.value,"Exact groups, clocks, requirements and all trace/log/version rows "+file)
        check(var_to_bytes([before,admitted.normalized,admitted.transitions])==held,"Compilation does not mutate accepted source owners "+file)
        check(actual.has("compile_phases_ms") and actual.compile_phases_ms.total>=0,"Explicit profiling exposes actual nested compiler stages")
        for group in actual.value.groups:
            rows+=group.events.size();native_requirements+=group.native_requirements.size()
            for event in group.events:versions+=event.versions.size()
        operations+=1
        evidence.append({"recording":directory,"operation":int(file.get_basename()),"elapsed_ms":elapsed,"compile_phases_ms":actual.compile_phases_ms})
    check(operations>0,"Actual recorded operations exercised: "+directory)
    var ordinary:Dictionary=Compiler.compile_recorded(journal.state,{"lineages":[],"cursor":{"sequence":999},"content_additions":{},"combat_log_appends":[],"command_number":0},cache,journal.state,{"lineages":[]})
    check(ordinary.ok and not ordinary.has("compile_phases_ms"),"Unprofiled compile adds no timing trace map")
    evidence.append({"recording":directory,"operations":operations,"events":rows,"versions":versions,"native_requirements":native_requirements})
