extends SceneTree
## Exact scalar contract and actual recording reducer/compiled timeline parity.
const Protocol=preload("res://sdk/protocol.gd")
const Reducer=preload("res://sdk/reducer.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Timeline=preload("res://presentation/timeline.gd")
const Strict=preload("res://sdk/strict_json.gd")
const Producer=preload("res://sdk/producer_json.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
    var old=Strict.new();var candidate=Producer.new();var checks=0;var failures=[]
    var texts=['{"a":1,"a":2}','{"n":999999999999999999}','{"n":1000000000000000000}','{"s":"a\\u0000b"}','{"s":"a\\nb"}','{"s":"\\uD83D\\uDE00"}','{"s":"slash\\/"}','{"s":"back\\\\end"}','{"s":"café😀"}','{"n":0.5}','{"n":999999999999999.5}','{"n":-0.0}','{"n":-0}','{"n":01}','{"n":1,}','{"n":1} {}','{"n":Vector2(1,2)}','{"n":Object()}','[1,]','{1:2}']
    for row in JSON.parse_string(FileAccess.get_file_as_string("res://tests/sdk_decimal_cases.json")):texts.append('{"n":'+row.token+'}')
    for depth in [510,512,513]:texts.append('['.repeat(depth)+'0'+']'.repeat(depth))
    for text in texts:
        var a=old.parse(text);var b=candidate.parse(text);checks+=1
        if a.ok!=b.ok or (a.ok and var_to_bytes(a.value)!=var_to_bytes(b.value)):failures.append(text.left(200))
    var recording=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="):recording=arg.trim_prefix("--recording=")
    if recording.is_empty():printerr("Pass actual --recording=<journal>");quit(2);return
    var protocol=Protocol.new();var state={};var admitted_state={};var cache={};var native_cache={};var timings=[]
    var files=DirAccess.get_files_at(recording);files.sort()
    for file in files:
        if not file.ends_with(".json"):continue
        var raw=FileAccess.get_file_as_bytes(recording.path_join(file))
        var root_name="InitializationResponse" if file=="0000000000000000.json" else "PlayerOperation"
        var strict=protocol.decode(root_name,raw)
        var admitted=protocol._decode_framed_event(root_name,raw,false,root_name=="PlayerOperation")
        checks+=1
        if not strict.ok or not admitted.ok or var_to_bytes(strict.value)!=var_to_bytes(admitted.value):failures.append("Actual packet exact parity "+file);continue
        var normalized=protocol.normalize(root_name,strict.value)
        if root_name=="InitializationResponse":
            state=Reducer.reduce_initialization(normalized.initialization,normalized.content_additions).value
            admitted_state=Reducer.reduce_initialization(admitted.value.initialization,admitted.value.content_additions).value
        else:
            var canonical=Compiler.compile(state,normalized,cache)
            var native=Compiler.compile(admitted_state,admitted.value,native_cache)
            checks+=1
            if not canonical.ok or not native.ok or var_to_bytes(canonical.value.groups)!=var_to_bytes(native.value.groups):failures.append("Actual compiled timeline groups "+file)
            state=canonical.value.final_state;admitted_state=native.value.final_state
            var a=Timeline.new();var b=Timeline.new();a.accept({"kind":"initialization","state":state,"sequence":0});b.accept({"kind":"initialization","state":admitted_state,"sequence":0})
            checks+=1
            if var_to_bytes(state)!=var_to_bytes(admitted_state) or var_to_bytes(a.state)!=var_to_bytes(b.state):failures.append("Actual canonical/timeline state "+file)
            var text=raw.get_string_from_utf8();var costs=[]
            for parser in [old,candidate]:
                var samples=[]
                for repeat in 3:
                    var started=Time.get_ticks_usec();parser.parse(text);samples.append((Time.get_ticks_usec()-started)/1000.)
                costs.append(samples)
            timings.append({"file":file,"bytes":raw.size(),"strict_ms":costs[0],"producer_ms":costs[1]})
    var report={"checks":checks,"failures":failures,"recording":recording,"timings":timings,"scope":"Exact Variant types/decimal bits, unchanged strict fallback, actual normalized/reduced state and compiled timeline groups. Native Godot headless CPU timings; no full-game latency claim."}
    FileAccess.open("res://.runtime/producer-json-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("PRODUCER_JSON_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
