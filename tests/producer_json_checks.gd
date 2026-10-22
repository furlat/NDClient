extends SceneTree
## Exact scalar contract and current producer reducer/compiled timeline parity.
const Protocol=preload("res://sdk/protocol.gd")
const Reducer=preload("res://sdk/reducer.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Timeline=preload("res://presentation/timeline.gd")
const Strict=preload("res://sdk/strict_json.gd")
const Producer=preload("res://sdk/producer_json.gd")

func difference(a:Variant,b:Variant,path:String="$",dictionary_order:bool=false)->Dictionary:
    if typeof(a)!=typeof(b):return {"path":path,"kind":"type","left_type":type_string(typeof(a)),"right_type":type_string(typeof(b)),"left":str(a),"right":str(b)}
    if a is Dictionary:
        if a.size()!=b.size():return {"path":path,"kind":"dictionary_size","left":a.size(),"right":b.size()}
        if dictionary_order and var_to_bytes(a.keys())!=var_to_bytes(b.keys()):return {"path":path,"kind":"dictionary_order","left":a.keys(),"right":b.keys()}
        var right_keys={}
        for key in b:right_keys[var_to_bytes(key).hex_encode()]=key
        for key in a:
            var encoded:String=var_to_bytes(key).hex_encode()
            if not right_keys.has(encoded):return {"path":path,"kind":"exact_dictionary_key","left":str(key),"left_type":type_string(typeof(key))}
            var found:Dictionary=difference(a[key],b[right_keys[encoded]],path+"["+str(key)+"]",dictionary_order)
            if not found.is_empty():return found
    elif a is Array:
        if a.size()!=b.size():return {"path":path,"kind":"array_size","left":a.size(),"right":b.size()}
        for index in a.size():
            var found:Dictionary=difference(a[index],b[index],path+"["+str(index)+"]",dictionary_order)
            if not found.is_empty():return found
    elif var_to_bytes(a)!=var_to_bytes(b):
        return {"path":path,"kind":"scalar_bytes","type":type_string(typeof(a)),"left":str(a),"right":str(b),"left_bits":var_to_bytes(a).hex_encode(),"right_bits":var_to_bytes(b).hex_encode()}
    return {}

func _initialize()->void:run.call_deferred()
func run()->void:
    var old=Strict.new();var candidate=Producer.new();var checks=0;var failures=[]
    var texts=['{"a":1,"a":2}','{"n":999999999999999999}','{"n":1000000000000000000}','{"s":"a\\u0000b"}','{"s":"a\\nb"}','{"s":"\\uD83D\\uDE00"}','{"s":"slash\\/"}','{"s":"back\\\\end"}','{"s":"literal\\\\u1234 and 1.234e-9"}','{"s":"café😀"}','{"n":0.5}','{"n":999999999999999.5}','{"n":-0.0}','{"n":-0}']
    # Only arbitrary/offline decoding owns a syntax contract. The private
    # producer path accepts the backend's already serialized JSON grammar.
    for malformed in ['{"n":01}','{"n":1,}','{"n":1} {}','{"n":Vector2(1,2)}','{"n":Object()}','[1,]','{1:2}']:
        checks+=1
        if old.parse(malformed).ok:failures.append("Strict arbitrary input accepted "+malformed)
    for row in JSON.parse_string(FileAccess.get_file_as_string("res://tests/sdk_decimal_cases.json")):texts.append('{"n":'+row.token+'}')
    for depth in [510,512]:texts.append('['.repeat(depth)+'0'+']'.repeat(depth))
    checks+=1
    if old.parse('['.repeat(513)+'0'+']'.repeat(513)).ok:failures.append("Strict arbitrary input lost its depth limit")
    for text in texts:
        var a=old.parse(text);var b=candidate.parse(text);checks+=1
        if a.ok!=b.ok or (a.ok and var_to_bytes(a.value)!=var_to_bytes(b.value)):failures.append(text.left(200))
    var recording="";var previous:RefCounted=null
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="):recording=arg.trim_prefix("--recording=")
        if arg.begins_with("--producer-oracle="):previous=load(arg.trim_prefix("--producer-oracle=")).new()
    if recording.is_empty():printerr("Pass actual --recording=<journal>");quit(2);return
    var protocol=Protocol.new();var state={};var admitted_state={};var cache={};var native_cache={};var timings=[];var diagnostics={}
    var files=DirAccess.get_files_at(recording);files.sort()
    for file in files:
        if not file.ends_with(".json"):continue
        var raw=FileAccess.get_file_as_bytes(recording.path_join(file))
        var root_name="InitializationResponse" if file=="0000000000000000.json" else "PlayerOperation"
        var strict=protocol.decode(root_name,raw)
        var admitted=protocol._decode_framed_event(root_name,raw,false,root_name=="PlayerOperation")
        checks+=1
        if not strict.ok or not admitted.ok or var_to_bytes(strict.value)!=var_to_bytes(admitted.value):failures.append("Actual packet exact parity "+file);continue
        # Both production lanes consume the producer's sparse packet. Normalizing
        # only the strict lane inserts optional defaults (for example eleven
        # object-look fields instead of four), changing the state being tested.
        # Keep normalization parity as its own exact, independent comparison.
        checks+=1
        if var_to_bytes(protocol.normalize(root_name,strict.value))!=var_to_bytes(protocol.normalize(root_name,admitted.value)):failures.append("Actual normalized packet exact parity "+file)
        if root_name=="InitializationResponse":
            state=Reducer.reduce_initialization(strict.value.initialization,strict.value.content_additions).value
            admitted_state=Reducer.reduce_initialization(admitted.value.initialization,admitted.value.content_additions).value
        else:
            var canonical=Compiler.compile(state,strict.value,cache)
            var native=Compiler.compile(admitted_state,admitted.value,native_cache)
            checks+=1
            if not canonical.ok or not native.ok or var_to_bytes(canonical.value.groups)!=var_to_bytes(native.value.groups):failures.append("Actual compiled timeline groups "+file)
            if canonical.ok and native.ok and not diagnostics.has("groups") and var_to_bytes(canonical.value.groups)!=var_to_bytes(native.value.groups):diagnostics.groups={"file":file,"semantic":difference(canonical.value.groups,native.value.groups),"serialization":difference(canonical.value.groups,native.value.groups,"$",true)}
            state=canonical.value.final_state;admitted_state=native.value.final_state
            var a=Timeline.new();var b=Timeline.new();a.accept({"kind":"initialization","state":state,"sequence":0});b.accept({"kind":"initialization","state":admitted_state,"sequence":0})
            checks+=1
            if var_to_bytes(state)!=var_to_bytes(admitted_state) or var_to_bytes(a.state)!=var_to_bytes(b.state):failures.append("Actual canonical/timeline state "+file)
            if not diagnostics.has("state") and var_to_bytes(state)!=var_to_bytes(admitted_state):diagnostics.state={"file":file,"semantic":difference(state,admitted_state),"serialization":difference(state,admitted_state,"$",true)}
            var text=raw.get_string_from_utf8();var costs=[]
            for parser in [old,candidate]+([previous] if previous!=null else []):
                var samples=[]
                for repeat in 3:
                    var started=Time.get_ticks_usec();parser.parse(text);samples.append((Time.get_ticks_usec()-started)/1000.)
                costs.append(samples)
            timings.append({"file":file,"bytes":raw.size(),"strict_ms":costs[0],"producer_ms":costs[1],"previous_producer_ms":costs[2] if previous!=null else []})
    var report={"checks":checks,"failures":failures,"recording":recording,"protocol":protocol.identity,"diagnostics":diagnostics,"timings":timings,"scope":"Current shipped producer contract: exact Variant types/decimal bits, unchanged strict fallback, exact actual sparse and normalized packet parity, and byte-exact complete canonical state and compiled timeline groups from independent parser outputs. Native Godot headless CPU timings; no full-game latency claim."}
    FileAccess.open("res://.runtime/producer-json-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("PRODUCER_JSON_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
