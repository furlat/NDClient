extends SceneTree
const Audience = preload("res://sdk/audience.gd")
const Journal = preload("res://sdk/journal.gd")
const Reducer = preload("res://sdk/reducer.gd")
var checks = 0
var failures: Array = []
var rejection_evidence: Dictionary = {}

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("POINTS_UNION_FAIL ",label)

# Flat independent oracle: coordinate identity, last writer, then numeric order.
func reference_union(first: Array, second: Array) -> Array:
    var points = {}
    for point in first + second: points["%d,%d" % [point[0],point[1]]] = point
    var result: Array = points.values()
    result.sort_custom(func(a,b): return a[1]<b[1] if a[0]==b[0] else a[0]<b[0])
    return result

func verify(first: Array, second: Array, expected: Array, label: String) -> void:
    var original = [first,second].duplicate(true)
    var actual = Audience.points_union(first,second)
    check(actual==expected,label+": exact deduplicated numeric order")
    check([first,second]==original,label+": input remains unchanged")
    var winners = reference_union(first,second)
    check(actual.size()==winners.size(),label+": unique coordinates")
    if actual.size()==winners.size():
        var identical = true
        for i in actual.size(): identical = identical and is_same(actual[i],winners[i])
        check(identical,label+": last input reference retained")

func verify_public_rejection(directory: String) -> void:
    check(DirAccess.dir_exists_absolute(directory),"Recorded rejection fixture exists")
    if not DirAccess.dir_exists_absolute(directory): return
    # Select the recording's existing schema without replaying or writing packets.
    var journal = Journal.new()
    var opened = journal.open(directory,true,false)
    check(opened.ok,"Recorded rejection fixture selects its admitted protocol")
    if not opened.ok: return
    var names = DirAccess.get_files_at(directory)
    names.sort()
    var packet_name = RegEx.new()
    packet_name.compile("^[0-9]{16}\\.json$")
    var state: Dictionary = {}
    var sequence = 0
    for name in names:
        if packet_name.search(name) == null: continue
        check(name == "%016d.json" % sequence,"Recorded rejection fixture is contiguous")
        if name != "%016d.json" % sequence: return
        var kind = "InitializationResponse" if sequence == 0 else "PlayerOperation"
        var decoded = journal.protocol.decode(kind,FileAccess.get_file_as_bytes(directory.path_join(name)))
        check(decoded.ok,"Recorded rejection fixture decodes " + name)
        if not decoded.ok: return
        var packet: Dictionary = journal.protocol.normalize(kind,decoded.value)
        var sensory_count = 0
        if sequence > 0:
            for lineage in packet.lineages:
                for event in lineage.events:
                    if not event.canceled and event.fact != null and event.fact.kind == "sensory": sensory_count += 1
        var prior = state.duplicate(true)
        var original_packet = packet.duplicate(true)
        var reduced = Reducer.reduce_initialization(packet.initialization,packet.content_additions) if sequence == 0 else Reducer.reduce_operation(state,packet)
        check(reduced.ok,"Original recorded operation succeeds " + name)
        if not reduced.ok: return
        check(state == prior and packet == original_packet,"Successful reduction leaves original inputs unchanged " + name)
        if sequence > 0 and sensory_count > 0 and packet.hud != null:
            # Every real lineage and sensory fact remains intact. Only the final
            # operation HUD is made invalid, after those facts have been folded.
            var invalid = packet.duplicate(true)
            var committed_cursor = int(reduced.value.reducer_cursor)
            invalid.hud.revision = committed_cursor + 1
            var original_invalid = invalid.duplicate(true)
            var rejected = Reducer.reduce_operation(state,invalid)
            check(not rejected.ok,"Public operation rejects final future HUD after sensory work")
            check(not rejected.ok and rejected.error.message == "HUD belongs to a different or future operation",
                "Rejection occurs at the final operation HUD boundary")
            check(state == prior,"Late public rejection preserves the complete prior state")
            check(invalid == original_invalid,"Late public rejection preserves the complete invalid input packet")
            check(packet == original_packet,"Rejection fixture preserves the original recorded operation")
            rejection_evidence = {"sequence":sequence,"sensory_facts":sensory_count,
                "prior_reducer_cursor":prior.reducer_cursor,"committed_reducer_cursor":committed_cursor,
                "rejected_hud_revision":invalid.hud.revision}
            return
        state = reduced.value
        sequence += 1
    check(false,"Recording contains an operation with sensory facts and a final HUD")

func _initialize() -> void:
    verify([],[],[],"empty")
    verify([],[[0,0]],[[0,0]],"new point")
    verify([[0,0]],[],[[0,0]],"retained point")
    verify([[2,3],[-4,7],[2,1],[2,3]],[[2,3],[-4,-9]],
        [[-4,-9],[-4,7],[2,1],[2,3]],"unsorted overlapping coordinates")
    verify([[10,2],[2,10],[2,2]],[[-10,2],[-2,2],[2,-10],[2,-2]],
        [[-10,2],[-2,2],[2,-10],[2,-2],[2,2],[2,10],[10,2]],"numeric rather than string order")
    verify([[9007199254740991,9007199254740991],[9007199254740990,-9007199254740991]],
        [[-9007199254740991,9007199254740990],[9007199254740991,-9007199254740991]],
        [[-9007199254740991,9007199254740990],[9007199254740990,-9007199254740991],
        [9007199254740991,-9007199254740991],[9007199254740991,9007199254740991]],"full wire integer range")
    var rng = RandomNumberGenerator.new()
    rng.seed = 38107
    for i in range(32):
        var pair = [[],[]]
        for j in range(120): pair[j%2].append([rng.randi_range(-32,32),rng.randi_range(-64,64)])
        verify(pair[0],pair[1],reference_union(pair[0],pair[1]),"arbitrary point collection %d"%i)
    var directory = ""
    var journal_requested = false
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--journal="):
            journal_requested = true
            directory = argument.trim_prefix("--journal=")
    if journal_requested: verify_public_rejection(directory)
    FileAccess.open("res://generated/sdk_points_union_checks.json",FileAccess.WRITE).store_string(
        JSON.stringify({"checks":checks,"failures":failures,"rejection_after_sensory":rejection_evidence},"  "))
    print("POINTS_UNION_CHECKS ",checks," failures=",failures)
    quit(0 if failures.is_empty() else 1)
