extends SceneTree
## Real server-spool bytes folded against Python canonical state at every record.
const Reducer=preload("res://sdk/reducer.gd")
const StrictJSON=preload("res://sdk/strict_json.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
var passed=0
var failures:Array=[]
func _initialize()->void:call_deferred("run")
func run()->void:
    var directory="res://tests/fixtures/schema16/spool-oracle"
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--oracle="):directory=arg.trim_prefix("--oracle=")
    var index:Variant=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("index.json")))
    if index==null:print("FAIL missing real spool oracle index "+directory);quit(1);return
    var expected_states:=ZIPReader.new()
    if expected_states.open(directory.path_join(index.states_archive))!=OK:
        print("FAIL missing Python canonical state archive "+directory);quit(1);return
    for seat in index.seats:
        var state:Dictionary={};var prior:Dictionary={}
        for i in range(seat.records.size()):
            var record:Dictionary=seat.records[i];var decoded=StrictJSON.new().parse(FileAccess.get_file_as_string(directory.path_join(record.bytes)))
            if not decoded.ok:failures.append("Decode "+str(seat.id)+":"+str(i));break
            var packet:Dictionary=decoded.value;var result=Reducer.reduce_initialization(packet.initialization,packet.get("content_additions",[])) if i==0 else Reducer._reduce_operation_retained(state,packet,true)
            if not result.ok:failures.append(str(seat.id)+":"+str(i)+" "+str(result.error));break
            var expected:Variant=JSON.parse_string(expected_states.read_file(record.expected).get_string_from_utf8());var issue=Compare.difference(result.value,expected)
            if not issue.is_empty():failures.append(str(seat.id)+":"+str(i)+" "+issue)
            else:passed+=1
            if i>0 and state!=prior:failures.append("Previous canonical state mutated "+str(seat.id)+":"+str(i))
            state=result.value;prior=state.duplicate(true)
    expected_states.close()
    print(JSON.stringify({"passed":passed,"failures":failures,"seats":index.seats.size()}));quit(0 if failures.is_empty() else 1)
