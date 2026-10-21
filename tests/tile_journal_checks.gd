extends SceneTree
## Current native world rows, transactional missing-base rejection and exact
## original two-seat prefixes. Retired wire identities stay refused.
const Journal=preload("res://sdk/journal.gd")
const Protocol=preload("res://sdk/protocol.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const ORACLE="res://tests/fixtures/schema16/spool-oracle"
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
var missing_base_cases:int=0
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("TILE_JOURNAL_FAIL ",label)
func _initialize()->void:run.call_deferred()
func run()->void:
    var directory:String=ORACLE
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--oracle="):directory=arg.trim_prefix("--oracle=")
    var index:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("index.json")))
    var states:=ZIPReader.new()
    check(states.open(directory.path_join(index.states_archive))==OK,"Independent frozen Python world archive opens")
    for seat in index.seats:original(directory,seat,states)
    states.close()
    check(evidence.size()==4 and missing_base_cases==2,"Both Door factions exercise actual world-row refusal; both lethal-OA prefixes retain exact independent world memory")
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,"producer_reference":index.reference,
        "scope":"All actual Door/lethal-OA faction prefixes against frozen Python canonical states; missing-base negative control on actual Door world rows, rejection/no publication, retry, exact durable bytes, retained snapshots, duplicate and cold replay. Schema6/7/8/9 refusal only; no compatibility replay or invented positive wire facts."}
    FileAccess.open("res://generated/tile_journal_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("TILE_JOURNAL_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func original(directory:String,seat:Dictionary,states:ZIPReader)->void:
    var path:String="user://tile-native-"+str(Time.get_ticks_usec())
    var journal:RefCounted=Journal.new()
    check(journal.open(path).ok,str(seat.id)+": isolated original-byte journal opens")
    journal.protocol=Protocol.new(Protocol.PRE_REVIEW_SCHEMA,Protocol.PRE_REVIEW_IDENTITY)
    var held:Array=[];var frozen:Array=[];var refused:bool=false
    for sequence in seat.records.size():
        var record:Dictionary=seat.records[sequence];var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(record.bytes))
        var decoded:Dictionary=journal.protocol.decode("InitializationResponse" if sequence==0 else "PlayerOperation",raw)
        check(decoded.ok,str(seat.id)+": exact original native record strictly admits "+str(sequence))
        if not decoded.ok:break
        var packet:Dictionary=decoded.value
        if sequence==0:retired_refusal(journal,packet,str(seat.id))
        if sequence>0 and not refused:
            var chosen:int=-1
            for i in packet.lineages.size():
                if not packet.lineages[i].get("world_updates",[]).is_empty():chosen=i;break
            if chosen>=0:
                # Labelled malformed-row control on this real update: a keyed
                # scalar patch must never invent an unknown cell's base row.
                var invalid:Dictionary=packet.duplicate(true)
                var update:Dictionary=invalid.lineages[chosen].world_updates[0]
                var position:Array=journal.state.tiles.values()[0].position.duplicate();position[0]+=10000
                while journal.state.tiles.has("%d,%d"%position):position[0]+=10000
                var rows:Array=update.get("tile_changes",[]).duplicate(true)
                rows.append({"position":position,"changes":{"walking_cost":1}});update.tile_changes=rows
                var invalid_raw:PackedByteArray=JSON.stringify(invalid,"",false,true).to_utf8_buffer()
                check(journal.protocol.decode("PlayerOperation",invalid_raw).ok,str(seat.id)+": malformed missing-base row still passes current wire schema")
                var before:Dictionary=journal.snapshot();var cursor:Dictionary=journal.cursor.duplicate(true);var owned:Dictionary=journal.state
                var original_packet:Dictionary=packet.duplicate(true);var original_invalid:Dictionary=invalid.duplicate(true)
                var denied:Dictionary=journal.consume(invalid,invalid_raw)
                check(not denied.ok and denied.error.message=="Tile field update requires an already known tile",str(seat.id)+": exact missing tile base rejects after current world staging")
                check(not denied.has("transitions") and journal.state==before and journal.cursor==cursor and is_same(journal.state,owned),str(seat.id)+": refusal preserves canonical state, cursor and ownership without captures")
                check(packet==original_packet and invalid==original_invalid,str(seat.id)+": refusal changes neither original nor malformed input")
                check(not FileAccess.file_exists(path.path_join("%016d.json"%sequence)),str(seat.id)+": refused packet never joins committed journal")
                refused=true;missing_base_cases+=1
        var accepted:Dictionary=journal._consume_admitted(packet,raw,true)
        check(accepted.ok,str(seat.id)+": exact original commits after any refusal "+str(sequence))
        if not accepted.ok:break
        check(FileAccess.get_file_as_bytes(journal._file(sequence))==raw,str(seat.id)+": durable original bytes remain exact "+str(sequence))
        var expected:Variant=JSON.parse_string(states.read_file(record.expected).get_string_from_utf8())
        var issue:String=Compare.difference(journal.state,expected)
        check(issue.is_empty(),str(seat.id)+": independent complete Python world cut "+str(sequence)+" "+issue)
        for i in held.size():check(held[i]==frozen[i],str(seat.id)+": later world publication preserves prefix "+str(i))
        held.append(journal.state);frozen.append(journal.snapshot())
        var repeat:Dictionary=journal._consume_admitted(packet,raw,true)
        check(repeat.ok and not repeat.has("transitions") and journal.state==frozen[-1],str(seat.id)+": reconnect duplicate cannot apply native world rows twice")
    check(refused==str(seat.id).begins_with("door/"),str(seat.id)+": world-row control presence follows the actual recording")
    var cold:RefCounted=Journal.new()
    check(cold.open(path).ok and cold.state==journal.state,str(seat.id)+": strict cold replay equals exact live prefix")
    evidence.append({"case":seat.id,"records":seat.records.size(),"missing_base_control":refused,"final_tiles":journal.state.tiles.size(),"final_objects":journal.state.objects.size()})
    for name in DirAccess.get_files_at(path):DirAccess.remove_absolute(path.path_join(name))
    DirAccess.remove_absolute(path)
func retired_refusal(journal:RefCounted,initial:Dictionary,label:String)->void:
    for version in [6,7,8,9]:
        var stale:Dictionary=initial.duplicate(true);stale.protocol.player_schema_version=version
        var raw:PackedByteArray=JSON.stringify(stale,"",false,true).to_utf8_buffer()
        check(not journal.consume(stale,raw).ok and journal.state.is_empty() and journal.cursor.is_empty(),label+": retired schema"+str(version)+" cannot publish live world state")
        var path:String="user://tile-retired-"+str(Time.get_ticks_usec())
        DirAccess.make_dir_recursive_absolute(path);var file:=FileAccess.open(path.path_join("0000000000000000.json"),FileAccess.WRITE);file.store_buffer(raw);file.close()
        check(not Journal.new().open(path,true,false).ok,label+": explicit offline read also refuses retired schema"+str(version))
        DirAccess.remove_absolute(path.path_join("0000000000000000.json"));DirAccess.remove_absolute(path)
