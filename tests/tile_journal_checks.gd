extends SceneTree
# Explicit current and previous real journals exercise protocol migration and
# transactional missing-base rejection without rewriting recorded identities.
const Journal = preload("res://sdk/journal.gd")
var checks = 0
var failures: Array = []
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("TILE_JOURNAL_FAIL ",label)

func _initialize() -> void:
    var current = ""
    var previous = ""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="): current=arg.trim_prefix("--recording=")
        if arg.begins_with("--previous="): previous=arg.trim_prefix("--previous=")
    if current.is_empty() or previous.is_empty():
        check(false,"Supply --recording=<schema7 journal> and --previous=<schema6 journal>")
        finish(); return
    var directory="user://tile-journal-"+str(Time.get_ticks_usec())
    var journal=Journal.new()
    check(journal.open(directory).ok,"Open isolated current live journal")
    var old_raw=FileAccess.get_file_as_bytes(previous.path_join("0000000000000000.json"))
    var old_packet=Journal.Protocol.parse_json(old_raw)
    check(old_packet.ok,"Read original schema6 initialization bytes")
    if not old_packet.ok: finish(); return
    check(not journal.consume(old_packet.value,old_raw).ok,"Live client rejects previous protocol identity")
    var archived=Journal.new()
    check(archived.open(previous,true,false).ok,"Explicit historical replay selects archived schema6")
    check(archived.protocol.identity.player_schema_version==6,"Historical identity remains exact schema6")
    check(archived.replay(2).ok,"Original schema6 prefix cold-replays without rewriting bytes")
    var held: Array=[]
    var rejected_missing_base=false
    var sequence=0
    while FileAccess.file_exists(current.path_join("%016d.json" % sequence)):
        var raw=FileAccess.get_file_as_bytes(current.path_join("%016d.json" % sequence))
        var decoded=journal.protocol.decode("InitializationResponse" if sequence==0 else "PlayerOperation",raw)
        check(decoded.ok,"Current wire record admitted: "+str(sequence))
        if not decoded.ok: break
        var packet: Dictionary=decoded.value
        var update: Dictionary={}
        if sequence>0:
            for lineage in packet.lineages:
                if not lineage.world_updates.is_empty(): update=lineage.world_updates[-1]
        if not update.is_empty():
            var invalid=packet.duplicate(true)
            for lineage in invalid.lineages:
                for row in lineage.world_updates:
                    if row.event_uuid==update.event_uuid:
                        row.tile_changes.append({"position":[9999,9999],"changes":{"resolved_light":0}})
            var bytes=JSON.stringify(invalid).to_utf8_buffer()
            check(journal.protocol.decode("PlayerOperation",bytes).ok,"Missing-base operation still passes schema admission")
            var before=journal.snapshot()
            var cursor=journal.cursor.duplicate(true)
            var denied=journal.consume(invalid,bytes)
            check(not denied.ok,"Missing tile base rejects live consumption")
            check(journal.state==before and journal.cursor==cursor,"Rejection preserves published state and cursor")
            check(not FileAccess.file_exists(directory.path_join("%016d.json" % sequence)),"Rejected record never joins committed journal")
            rejected_missing_base=true
        var accepted=journal.consume(packet,raw)
        check(accepted.ok,"Original record commits: "+str(sequence))
        if not accepted.ok: break
        for row in held: check(row.state==row.frozen,"Later publication preserves retained snapshot")
        held.append({"state":journal.state,"frozen":journal.snapshot()})
        if rejected_missing_base:
            var after=journal.snapshot()
            check(journal.consume(packet,raw).ok and journal.state==after,"Reconnect duplicate cannot apply tile changes twice")
            var cold=Journal.new()
            check(cold.open(directory).ok and cold.state==after,"Current schema cold replay equals corrected live stream")
            break
        sequence+=1
    check(rejected_missing_base,"Actual recording reaches an event-associated world update")
    for name in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(name))
    DirAccess.remove_absolute(directory)
    finish()

func finish() -> void:
    var report={"checks":checks,"failures":failures,"arguments":Array(OS.get_cmdline_user_args())}
    FileAccess.open("res://generated/tile_journal_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("TILE_JOURNAL_CHECKS ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
