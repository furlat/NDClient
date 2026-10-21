extends SceneTree
const Audience = preload("res://sdk/audience.gd")
const Journal = preload("res://sdk/journal.gd")
const Reducer = preload("res://sdk/reducer.gd")
const Compare = preload("res://tests/schema16_fold_vectors_checks.gd")
const ORACLE = "res://tests/fixtures/schema16/spool-oracle"
var checks = 0
var failures: Array = []
var rejection_evidence: Array = []

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

func verify_public_rejection(directory: String,seat:Dictionary={},states:ZIPReader=null) -> void:
    check(DirAccess.dir_exists_absolute(directory),"Recorded rejection fixture exists")
    if not DirAccess.dir_exists_absolute(directory): return
    var journal = Journal.new()
    var opened = journal.open(directory,true,false)
    check(opened.ok,"Recorded rejection fixture selects its admitted protocol")
    if not opened.ok: return
    var names = DirAccess.get_files_at(directory)
    names.sort()
    var packet_name = RegEx.new()
    packet_name.compile("^[0-9]{16}\\.json$")
    var state: Dictionary = {}
    var sequence = 0;var rejected_late:bool=false
    for name in names:
        if packet_name.search(name) == null: continue
        check(name == "%016d.json" % sequence,"Recorded rejection fixture is contiguous")
        if name != "%016d.json" % sequence: return
        var kind = "InitializationResponse" if sequence == 0 else "PlayerOperation"
        var decoded = journal.protocol.decode(kind,FileAccess.get_file_as_bytes(directory.path_join(name)))
        check(decoded.ok,"Recorded rejection fixture decodes " + name)
        if not decoded.ok: return
        # Native16 admission preserves exact sparse producer values. The
        # retired schema9 adapter's default-filling normalization is not this
        # public reducer's input boundary.
        var packet: Dictionary = decoded.value
        var sensory_count = 0
        if sequence > 0:
            for lineage in packet.lineages:
                for event in lineage.events:
                    if not event.get("canceled",false) and event.get("fact") != null and event.fact.kind == "sensory": sensory_count += 1
        var prior = state.duplicate(true)
        var original_packet = packet.duplicate(true)
        var reduced = Reducer.reduce_initialization(packet.initialization,packet.content_additions) if sequence == 0 else Reducer.reduce_operation(state,packet)
        check(reduced.ok,"Original recorded operation succeeds " + name)
        if not reduced.ok: return
        check(state == prior and packet == original_packet,"Successful reduction leaves original inputs unchanged " + name)
        if states!=null:
            var expected:Variant=JSON.parse_string(states.read_file(seat.records[sequence].expected).get_string_from_utf8())
            var issue:String=Compare.difference(reduced.value,expected)
            check(issue.is_empty(),str(seat.id)+": entire original prefix matches independent frozen Python state "+str(sequence)+" "+issue)
        if sequence > 0 and sensory_count > 0 and not rejected_late:
            # Labelled malformed-input control: preserve every real lineage,
            # source row and sensory fact, but name an unheld final HUD resource.
            # Native HUD patches have no schema9 revision field.
            var invalid = packet.duplicate(true)
            var sheet:Dictionary=state.hud_snapshot.sheets[0]
            var held:Dictionary=sheet.resources[0]
            var malformed:Dictionary={"actor_uuid":sheet.actor_uuid,"changes":{},"resource_values":[{"key":str(held.key)+":not-held-control","current":held.current,"maximum":held.maximum}]}
            invalid.hud=packet.hud.duplicate(true) if packet.get("hud")!=null else {}
            var patches:Array=invalid.hud.get("sheets",[]).duplicate(true)
            patches=patches.filter(func(row):return row.actor_uuid!=sheet.actor_uuid);patches.append(malformed);invalid.hud.sheets=patches
            var original_invalid = invalid.duplicate(true)
            check(journal.protocol.decode("PlayerOperation",JSON.stringify(invalid,"",false,true).to_utf8_buffer()).ok,"Malformed HUD resource still passes current wire schema")
            var rejected = Reducer.reduce_operation(state,invalid)
            check(not rejected.ok,"Public operation rejects an unheld final HUD resource after actual sensory work")
            check(not rejected.ok and rejected.error.message == "Resource values name a row the sheet does not hold",
                "Rejection occurs at the final operation HUD boundary")
            check(state == prior,"Late public rejection preserves the complete prior state")
            check(invalid == original_invalid,"Late public rejection preserves the complete invalid input packet")
            check(packet == original_packet,"Rejection fixture preserves the original recorded operation")
            rejection_evidence.append({"case":seat.get("id",directory),"sequence":sequence,"sensory_facts":sensory_count,
                "prior_reducer_cursor":prior.reducer_cursor,"committed_reducer_cursor":reduced.value.reducer_cursor,
                "negative_control":"unheld final HUD resource key; original native facts/rows unchanged"})
            rejected_late=true
        state = reduced.value
        sequence += 1
    check(rejected_late,"Recording exercises final HUD refusal after actual sensory work")

func native_originals()->void:
    var index:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ORACLE.path_join("index.json")))
    var states:=ZIPReader.new()
    check(states.open(ORACLE.path_join(index.states_archive))==OK,"Frozen independent Python expected cuts open")
    for seat in index.seats:
        var directory:String=ORACLE.path_join(str(seat.records[0].bytes)).get_base_dir()
        verify_public_rejection(directory,seat,states)
    states.close()
    check(rejection_evidence.size()==4,"Both actual Door and lethal-OA factions exercise late HUD refusal")

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
    if journal_requested:verify_public_rejection(directory)
    else:native_originals()
    FileAccess.open("res://generated/sdk_points_union_checks.json",FileAccess.WRITE).store_string(
        JSON.stringify({"checks":checks,"failures":failures,"rejection_after_sensory":rejection_evidence},"  "))
    print("POINTS_UNION_CHECKS ",checks," failures=",failures)
    quit(0 if failures.is_empty() else 1)
