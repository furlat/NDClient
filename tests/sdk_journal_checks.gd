extends SceneTree
## Exact current-server bytes, durable publication and independently replayed prefixes.
const Journal=preload("res://sdk/journal.gd")
const Protocol=preload("res://sdk/protocol.gd")
const FIXTURE="res://tests/fixtures/schema18/current-production/fire-bolt/amber"
const ARCHIVED="res://tests/fixtures/schema16/scenarios/door/amber"
const PREVIOUS="res://tests/fixtures/schema16/current-production-0c/fire-bolt/amber"
var failures:Array=[]
var checks=0
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("SDK_JOURNAL_FAIL ",label)
func raw(sequence:int)->PackedByteArray:return FileAccess.get_file_as_bytes(FIXTURE.path_join("%016d.json"%sequence))
func decoded(journal:RefCounted,sequence:int)->Dictionary:
    return journal.protocol.decode_server("InitializationResponse" if sequence==0 else "PlayerOperation",raw(sequence)).value
func recorded_admission(path:String,initial:Dictionary)->void:
    for control in [{"label":"setup","schema":{"$defs":{},"unsupported_keyword":true},"error":"Unsupported schema keyword unsupported_keyword"},
            {"label":"unsupported contract","schema":{"$defs":{}},"error":"Unknown recorded producer contract"}]:
        var schema_path:String=path.path_join(control.label.replace(" ","-")+"-schema.json")
        var file=FileAccess.open(schema_path,FileAccess.WRITE);file.store_string(JSON.stringify(control.schema));file.close()
        # Real Protocol construction supplies the malformed/unsupported contract;
        # do not replace the decoder or manufacture its result/setup flags.
        var refused_protocol=Protocol.new(schema_path,"res://sdk/protocol-identity.json")
        check(refused_protocol.setup_error==(control.error if control.label=="setup" else ""),"Construct actual "+control.label+" admission control")
        var expected:Dictionary=Protocol.failure(control.error)
        var unopened=Journal.new();unopened.protocol=refused_protocol
        check(unopened.open(path,true,false)==expected,"Existing current packet zero refuses "+control.label+" before retained admission")
        check(unopened.state.is_empty() and unopened.cursor.is_empty(),"Refused open publishes no state or cursor: "+control.label)
        var cached=Journal.new()
        check(cached.open(path,true,false).ok,"Open actual current packet zero before "+control.label+" changes")
        var supported=cached.protocol;cached.protocol=refused_protocol
        check(cached.decode_record(0,raw(0))==expected,"Retained packet-zero admission preserves protocol failure: "+control.label)
        check(cached.state.is_empty() and cached.cursor.is_empty(),"Refused retained packet publishes no state or cursor: "+control.label)
        cached.protocol=supported
        var accepted:Dictionary=cached.decode_record(0,raw(0))
        check(accepted.ok and accepted.value==initial,"Restored current contract admits unchanged initialization: "+control.label)
    for original in [{"label":"current","path":path},{"label":"previous","path":PREVIOUS},{"label":"archived","path":ARCHIVED}]:
        var reader=Journal.new()
        check(reader.open(original.path,true,false).ok,"Open exact "+original.label+" original without replay")
        var bytes:PackedByteArray=FileAccess.get_file_as_bytes(original.path.path_join("0000000000000000.json"))
        var first:Dictionary=reader.decode_record(0,bytes)
        check(first.ok and int(first.value.cursor.sequence)==0,"Retained "+original.label+" initialization admits cursor zero")
        var repeated:Dictionary=reader.decode_record(0,bytes)
        check(repeated==first,"Noncached "+original.label+" fallback preserves the exact admitted packet")
    var fallback=Journal.new()
    check(fallback.open(path,true,false).ok,"Open current packet-zero fallback control")
    check(not fallback.decode_record(0,'{'.to_utf8_buffer()).ok,"Different malformed bytes cannot reuse valid packet zero")
    var restored:Dictionary=fallback.decode_record(0,raw(0))
    check(restored.ok and restored.value==initial,"Original bytes still admit after the malformed-byte refusal")
func _init()->void:
    var path="user://sdk-journal-check-"+str(Time.get_ticks_usec())
    var journal=Journal.new()
    check(journal.open(path).ok,"Open empty current-protocol journal")
    var initial=decoded(journal,0)
    check(journal.consume(initial,raw(0)).ok,"Accept exact current initialization")
    var before=journal.snapshot();var before_cursor=journal.cursor.duplicate()
    var operation=decoded(journal,1)
    var gap=operation.duplicate(true);gap.cursor.sequence=2
    check(not journal.consume(gap,JSON.stringify(gap).to_utf8_buffer()).ok,"Reject sequence gap")
    check(journal.state==before and journal.cursor==before_cursor,"Rejected gap preserves published state and cursor")
    var target=path.path_join("0000000000000001.json")
    check(DirAccess.make_dir_absolute(target)==OK,"Create durable commit obstruction")
    var blocked=journal._consume_admitted(operation,raw(1),true)
    check(not blocked.ok and not blocked.has("transitions"),"Failed durable commit exposes no transitions")
    check(journal.state==before and journal.cursor==before_cursor,"Failed commit preserves prior canonical state")
    DirAccess.remove_absolute(target)
    for sequence in range(1,9):
        var admitted=journal._consume_admitted(decoded(journal,sequence),raw(sequence),true)
        check(admitted.ok,"Admit real current record "+str(sequence))
        check(FileAccess.get_file_as_bytes(journal._file(sequence))==raw(sequence),"Durable packet bytes remain exact "+str(sequence))
    var after=journal.snapshot()
    var repeated=journal._consume_admitted(decoded(journal,8),raw(8),true)
    check(repeated.ok and not repeated.has("transitions") and journal.state==after,"Identical duplicate neither mutates state nor republishes transitions")
    var altered=decoded(journal,8).duplicate(true);altered.state_revision+="-changed"
    check(not journal.consume(altered,JSON.stringify(altered).to_utf8_buffer()).ok and journal.state==after,"Conflicting duplicate rejected without publication")
    var reopened=Journal.new()
    check(reopened.open(path,true).ok and reopened.state==after,"Cold current replay equals admitted live state")
    check(reopened.replay(0).ok and reopened.state==before,"Seeking the initialization prefix restores its exact state")
    check(not reopened.replay(999).ok and reopened.state==before,"Unavailable prefix preserves the previous state")
    check(reopened.replay().ok and reopened.state==after,"Replay after a failed seek returns to the exact terminal state")
    var snapshot=journal.snapshot();snapshot.actors.clear()
    check(journal.state==after,"External snapshot cannot mutate canonical publication")
    var foreign=decoded(journal,8).duplicate(true);foreign.cursor.sequence=9;foreign.cursor.audience_id="00000000-0000-4000-8000-000000000001"
    check(not journal.consume(foreign,JSON.stringify(foreign).to_utf8_buffer()).ok and journal.state==after,"Foreign audience cannot enter the journal")
    var stale_path=path+"-stale";DirAccess.make_dir_recursive_absolute(stale_path)
    var stale=initial.duplicate(true);stale.protocol.player_schema_version=9
    var file=FileAccess.open(stale_path.path_join("0000000000000000.json"),FileAccess.WRITE);file.store_string(JSON.stringify(stale));file.close()
    check(not Journal.new().open(stale_path,true,false).ok,"Offline mode refuses retired wire schema; saved-container version is separate")
    recorded_admission(path,initial)
    for directory in [path,stale_path]:
        for filename in DirAccess.get_files_at(directory):DirAccess.remove_absolute(directory.path_join(filename))
        DirAccess.remove_absolute(directory)
    print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
