extends SceneTree
## Exact current-server bytes, durable publication and independently replayed prefixes.
const Journal=preload("res://sdk/journal.gd")
const Protocol=preload("res://sdk/protocol.gd")
const FIXTURE="res://tests/fixtures/schema16/fire-bolt"
var failures:Array=[]
var checks=0
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("SDK_JOURNAL_FAIL ",label)
func raw(sequence:int)->PackedByteArray:return FileAccess.get_file_as_bytes(FIXTURE.path_join("%016d.json"%sequence))
func decoded(journal:RefCounted,sequence:int)->Dictionary:
    return journal.protocol.decode_server("InitializationResponse" if sequence==0 else "PlayerOperation",raw(sequence)).value
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
    for directory in [path,stale_path]:
        for filename in DirAccess.get_files_at(directory):DirAccess.remove_absolute(directory.path_join(filename))
        DirAccess.remove_absolute(directory)
    print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
