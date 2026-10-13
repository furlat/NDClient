extends SceneTree
# Real accepted sensory operations retain their derived indexes across journal
# failure/retry and replay rollback; no private candidate becomes public.
const Journal = preload("res://sdk/journal.gd")
const Protocol = preload("res://sdk/protocol.gd")
var checks := 0
var failures: Array = []
func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failures.append(label)
func _initialize() -> void:
    var recording = "res://.runtime/player-runs/20261013T152452.610938Z/journal"
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="): recording = arg.trim_prefix("--recording=")
    var path = "user://sensory-journal-"+str(Time.get_ticks_usec())
    var journal = Journal.new()
    check(journal.open(path).ok,"Open isolated current journal")
    for sequence in range(5):
        var raw = FileAccess.get_file_as_bytes(recording.path_join("%016d.json" % sequence))
        var decoded = journal.protocol.decode("InitializationResponse" if sequence==0 else "PlayerOperation",raw)
        check(decoded.ok,"Recorded prefix strictly admitted "+str(sequence))
        if not decoded.ok: finish(path); return
        check(journal._consume_admitted(decoded.value,raw,true,sequence>0).ok,"Recorded prefix committed "+str(sequence))
    var before = journal.snapshot()
    var cursor = journal.cursor.duplicate(true)
    var context: Dictionary = journal._sensory_context
    var frozen_context = context.duplicate(true)
    check(context.get("cells",{}).get("composed",false),"Control includes accepted sensory indexes")
    var raw = FileAccess.get_file_as_bytes(recording.path_join("0000000000000005.json"))
    var decoded = journal.protocol.decode("PlayerOperation",raw)
    check(decoded.ok,"Following real sensory operation admitted")
    if not decoded.ok: finish(path); return
    var packet: Dictionary = decoded.value
    var invalid: Dictionary = packet.duplicate(true)
    check(invalid.hud!=null,"Control has final HUD after sensory changes")
    if invalid.hud==null: finish(path); return
    invalid.hud.revision = invalid.lineages[-1].end_cursor+1
    var invalid_raw = JSON.stringify(invalid,"",false,true).to_utf8_buffer()
    var denied = journal._consume_admitted(invalid,invalid_raw,true,true)
    check(not denied.ok and not denied.has("transitions"),"Late semantic refusal publishes no captures")
    check(journal.state==before and journal.cursor==cursor,"Late refusal preserves state and cursor")
    check(is_same(journal._sensory_context,context) and context==frozen_context,"Late refusal preserves committed indexes and ownership")
    var destination = path.path_join("0000000000000005.json")
    check(DirAccess.make_dir_absolute(destination)==OK,"Obstruct durable rename after reduction")
    denied = journal._consume_admitted(packet,raw,true,true)
    check(not denied.ok and not denied.has("transitions"),"Durability refusal publishes no captures")
    check(journal.state==before and journal.cursor==cursor,"Durability refusal preserves canonical boundary")
    check(is_same(journal._sensory_context,context) and context==frozen_context,"Durability refusal preserves committed indexes")
    DirAccess.remove_absolute(destination)
    var accepted = journal._consume_admitted(packet,raw,true,true)
    check(accepted.ok and accepted.has("transitions"),"Retry commits complete authoritative operation")
    check(context==frozen_context,"Successful later commit also preserves earlier retained indexes")
    var after = journal.snapshot()
    var after_context = journal._sensory_context
    var frozen_after_context = after_context.duplicate(true)
    var held_captures = accepted.transitions.duplicate(true)
    var bad_path = path.path_join("0000000000000006.json")
    var next_raw = FileAccess.get_file_as_bytes(recording.path_join("0000000000000006.json"))
    var next = journal.protocol.decode("PlayerOperation",next_raw)
    check(next.ok,"Next real operation strictly admitted")
    if not next.ok: finish(path); return
    var broken: Dictionary = next.value.duplicate(true)
    broken.lineages[-1].start_cursor += 1
    FileAccess.open(bad_path,FileAccess.WRITE).store_string(JSON.stringify(broken,"",false,true))
    denied = journal.replay()
    check(not denied.ok,"Replay rejects a later invalid lineage")
    check(journal.state==after and journal.cursor.sequence==5,"Replay rollback restores exact preceding public boundary")
    check(is_same(journal._sensory_context,after_context) and after_context==frozen_after_context,"Replay rollback restores committed index owner")
    DirAccess.remove_absolute(bad_path)
    check(journal._consume_admitted(next.value,next_raw,true,true).ok,"Retry after replay failure consumes next sensory operation")
    check(accepted.transitions==held_captures,"Later retry leaves earlier event-time captures frozen")
    var final_state = journal.snapshot()
    check(journal.replay().ok and journal.state==final_state,"Strict cold replay equals trusted live result")
    check(journal.replay(0).ok and journal._sensory_context.is_empty(),"Initialization-only replay drops prior derived context")
    finish(path)
func finish(path: String) -> void:
    for name in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(name))
    DirAccess.remove_absolute(path)
    var report = {"checks":checks,"failures":failures,"scope":"Real sensory operations, late semantic failure, durable rename failure, retry, frozen captures and strict replay rollback"}
    FileAccess.open("res://generated/sdk_sensory_journal_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SDK_SENSORY_JOURNAL_CHECKS ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
