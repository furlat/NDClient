extends "res://tests/sdk_reducer_checks.gd"
# Public value ownership, using the existing independently generated Python
# oracle and three real current-SDK journal records. No private reducer helpers.
# Run: Godot --headless --path <project> --script res://tests/sdk_snapshot_checks.gd
#   -- --recording=<current SDK journal> --sequence=<sensory operation>
#   [--cases=<reducer-oracle.json>]
# The recording is deliberately caller-supplied, never a portable test default.
const Journal = preload("res://sdk/journal.gd")
var checks = 0
var failures: Array = []
var selected_cases: Array = []
var mutated_collections = 0
var composed_cases: Array = []

func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures.append(label)
        print("SDK_SNAPSHOT_FAIL ",label)

func _poison(value: Variant) -> void:
    # A public caller can edit any nested part of its returned JSON value.
    # Descend before editing containers so an aliased child cannot go unnoticed.
    if value is Dictionary:
        for child in value.values(): _poison(child)
        value["snapshot_test_mutation"] = true
        mutated_collections += 1
    elif value is Array:
        for child in value: _poison(child)
        value.append("snapshot_test_mutation")
        mutated_collections += 1

func _detached(case: Dictionary) -> void:
    var args: Array = case.arguments.duplicate(true)
    var original: Array = args.duplicate(true)
    var actual = invoke(case.method,args)
    selected_cases.append(case.name)
    check(actual.ok,"Public success: "+case.name)
    if not actual.ok: return
    check(difference(case.expected.value,actual.value).is_empty(),"Python value parity: "+case.name)
    check(args==original,"Successful call preserves inputs: "+case.name)
    _poison(actual.value)
    check(args==original,"Returned nested values are detached: "+case.name)

func _late_operation_failures(case: Dictionary) -> void:
    var source: Array = case.arguments
    var valid = invoke(case.method,source.duplicate(true))
    check(valid.ok and valid.value.actors!=source[0].actors,"Late-failure control commits an actual actor mutation")
    check(not source[1].content_additions.is_empty(),"Late-failure control also admits content")
    for kind in ["hud","log"]:
        var args: Array = source.duplicate(true)
        if kind=="hud":
            args[1].hud.revision = int(args[1].lineages[-1].end_cursor)+1
        else:
            check(not args[1].combat_log_appends.is_empty(),"Existing log after-value available")
            if args[1].combat_log_appends.is_empty(): continue
            args[1].combat_log_appends[-1].encounter_log_index += 9
        var frozen: Array = args.duplicate(true)
        var result = invoke(case.method,args)
        check(not result.ok,"Late "+kind+" rejection after valid lineage")
        check(args==frozen,"Late "+kind+" rejection preserves state and packet")

func _late_sensory_failure(case: Dictionary) -> void:
    var args: Array = case.arguments.duplicate(true)
    var event: Dictionary = args[2]
    check(not event.entity_contacts_changed.is_empty() and not event.visible_cells_added.is_empty(),
        "Sensory control has contact and visibility mutations before light validation")
    var valid = invoke(case.method,args)
    check(valid.ok and valid.value!=args[0],"Sensory control changes perception")
    event.effective_light_levels_changed["91,92"] = 8
    var frozen: Array = args.duplicate(true)
    var rejected = invoke(case.method,args)
    check(not rejected.ok and rejected.error.message=="Unknown recorded light level","Late sensory value rejected explicitly")
    check(args==frozen,"Late sensory rejection preserves all previous observer maps and input event")

func _journal_snapshots(recording: String) -> void:
    var path = "user://sdk-snapshot-check-"+str(Time.get_ticks_usec())
    var journal = Journal.new()
    check(journal.open(path).ok,"Open isolated current-protocol journal")
    var held: Array = []
    var originals: Array = []
    for sequence in range(3):
        var source = recording.path_join("%016d.json" % sequence)
        check(FileAccess.file_exists(source),"Recorded public packet exists: "+str(sequence))
        if not FileAccess.file_exists(source): break
        var raw = FileAccess.get_file_as_bytes(source)
        var decoded = journal.protocol.decode("InitializationResponse" if sequence==0 else "PlayerOperation",raw)
        check(decoded.ok,"Current schema admits recorded packet: "+str(sequence))
        if not decoded.ok: break
        var packet: Dictionary = decoded.value
        var frozen_packet: Dictionary = packet.duplicate(true)
        if sequence==1:
            var invalid: Dictionary = packet.duplicate(true)
            check(invalid.hud!=null and not invalid.lineages.is_empty(),"Real operation has a final HUD and preceding lineage")
            if invalid.hud!=null and not invalid.lineages.is_empty():
                invalid.hud.revision = int(invalid.lineages[-1].end_cursor)+1
                var invalid_raw = JSON.stringify(invalid).to_utf8_buffer()
                check(journal.protocol.decode("PlayerOperation",invalid_raw).ok,"Late invalid HUD still passes wire schema")
                var old_cursor = journal.cursor.duplicate(true)
                var denied = journal.consume(invalid,invalid_raw)
                check(not denied.ok,"Journal rejects late invalid HUD")
                check(journal.state==originals[0] and journal.cursor==old_cursor,"Journal rejection preserves prior state and cursor")
                check(not FileAccess.file_exists(path.path_join("%016d.json" % sequence)),"Rejected operation not durably committed")
        var consumed = journal.consume(packet,raw)
        check(consumed.ok,"Recorded operation publishes: "+str(sequence))
        if not consumed.ok: break
        check(packet==frozen_packet,"Journal consumption leaves caller packet unchanged: "+str(sequence))
        for index in range(held.size()):
            check(held[index]==originals[index],"Later publication preserves retained state "+str(index)+" at "+str(sequence))
        held.append(journal.state)
        originals.append(journal.state.duplicate(true))
    check(held.size()==3,"Three real public boundaries exercised")
    if held.size()==3:
        check(originals[0]!=originals[1] and originals[1]!=originals[2],"Retained-state proof contains real changes at both operations")
        var snapshot = journal.snapshot()
        _poison(snapshot)
        check(journal.state==originals[-1],"Mutating public snapshot cannot alter canonical journal state")
        check(journal.replay(0).ok,"Cold replay can restore the initial boundary")
        check(journal.state==originals[0],"Restored initial boundary is exact")
        check(not journal.replay(99).ok and journal.state==originals[0],"Failed later replay restores its prior boundary")
        for index in range(held.size()):
            check(held[index]==originals[index],"Cold replay never mutates retained state "+str(index))
    for filename in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(filename))
    DirAccess.remove_absolute(path)

func _composition_case(state: Dictionary, lineage: Dictionary, label: String, expected_cells: Dictionary = {}) -> void:
    var frozen_state = state.duplicate(true)
    var frozen_lineage = lineage.duplicate(true)
    var cursors = {}
    for row in lineage.version_rows: cursors[row.event_uuid] = row.source_index
    var boundaries = 0
    for index in range(lineage.events.size()):
        var node: Dictionary = lineage.events[index]
        if node.fact == null or node.fact.kind != "sensory" or node.canceled: continue
        var admitted: Array = lineage.observations.filter(func(row): return cursors[row.event_uuid] <= cursors[node.uuid])
        # Each public prefix independently establishes its first-view proof.
        # The exhaustive public composer remains a separate value oracle.
        var result = Reducer.reduce_nodes(state,lineage.events.slice(0,index+1),lineage.version_rows,admitted,lineage.world_updates)
        check(result.ok,"Sensory prefix accepts: "+label)
        if not result.ok: continue
        boundaries += 1
        check(result.value.senses == Audience.view(result.value.perception,state.observer_uuid),"Exhaustive composed view after event: "+label)
        if expected_cells.has(node.uuid):
            var cell: Dictionary = expected_cells[node.uuid]
            check(result.value.senses.effective_light_levels.get(cell.key)==cell.level and result.value.senses.hazardous_cells.get(cell.key)==cell.hazard,
                "Recorded two-observer winner/tie semantics: "+label)
        _poison(result.value)
        check(state == frozen_state and lineage == frozen_lineage,"Prefix output mutation preserves caller inputs: "+label)
    check(boundaries>=2,"Several accepted sensory boundaries exercised: "+label)
    composed_cases.append({"case":label,"sensory_boundaries":boundaries})

func _composed_snapshots(recording: String, sequence: int) -> void:
    var journal = Journal.new()
    check(journal.open(recording,true,false).ok,"Read-only composition recording opens")
    var replay = journal.replay(sequence-1)
    check(replay.ok,"Actual preceding sensory state replays")
    if not replay.ok: return
    var decoded = journal.protocol.decode("PlayerOperation",FileAccess.get_file_as_bytes(recording.path_join("%016d.json" % sequence)))
    check(decoded.ok,"Selected sensory operation passes current SDK schema")
    if not decoded.ok: return
    var matches: Array = decoded.value.lineages.filter(func(row):
        return row.events.filter(func(node): return node.fact!=null and node.fact.kind=="sensory" and not node.canceled).size()>=4)
    check(matches.size()>0,"Selected operation contains a multi-sensory lineage")
    if matches.is_empty(): return
    var state: Dictionary = journal.state
    var lineage: Dictionary = matches[0]
    _composition_case(state,lineage,"actual admitted sensory lineage")
    var inconsistent = state.duplicate(true)
    inconsistent.senses.visible=[]; inconsistent.senses.seen=[]
    inconsistent.senses.effective_light_levels={"-777,-888":4}
    inconsistent.senses.hazardous_cells={"-777,-888":true}
    _composition_case(inconsistent,lineage,"caller-composed cells inconsistent with perception")
    var changed: Dictionary = lineage.duplicate(true)
    var sensory: Array = changed.events.filter(func(node): return node.fact!=null and node.fact.kind=="sensory")
    sensory[0].canceled=true
    _composition_case(state,changed,"first sensory canceled before first accepted view")
    changed=lineage.duplicate(true)
    sensory=changed.events.filter(func(node): return node.fact!=null and node.fact.kind=="sensory")
    var initialized = journal.protocol.decode("InitializationResponse",FileAccess.get_file_as_bytes(recording.path_join("0000000000000000.json")))
    check(initialized.ok,"Actual initial sensory input admits")
    if initialized.ok:
        for node in initialized.value.initialization.nodes:
            if node.fact!=null and node.fact.kind=="sensory" and node.fact.observer_uuid==sensory[1].fact.observer_uuid:
                sensory[1].fact=node.fact.duplicate(true)
                var member: Dictionary = state.perception.members[node.fact.observer_uuid]
                check(node.fact.visible_cells_added.size()<member.visible.size() and node.fact.seen_cells_added.size()<member.seen.size(),"Initial reset shrinks existing visible and seen collections")
                break
        check(sensory[1].fact.initial,"Second sensory is an actual initial observer reset")
        _composition_case(state,changed,"initial observer reset after established composition")
    changed=lineage.duplicate(true)
    sensory=changed.events.filter(func(node): return node.fact!=null and node.fact.kind=="sensory")
    var first: String = sensory[0].fact.observer_uuid
    var second: String = sensory[1].fact.observer_uuid
    check(first!=second and sensory[2].fact.observer_uuid==first and sensory[3].fact.observer_uuid==second,"Actual input alternates two observer updates")
    var point: Array=[]
    for candidate in state.perception.members[first].visible:
        if candidate in state.perception.members[second].visible: point=candidate; break
    check(not point.is_empty(),"Actual observers share a cell for brightness/hazard winner checks")
    if point.is_empty(): return
    var key = Audience.point_key(point)
    var ranked = state.duplicate(true)
    for member in ranked.perception.members.values(): member.effective_light_levels[key]=0; member.hazardous_cells[key]=false
    ranked.senses=Audience.view(ranked.perception,ranked.observer_uuid)
    var expected_cells={}
    for index in range(4):
        var fact: Dictionary = sensory[index].fact
        fact.visible_cells_added=[point.duplicate()]; fact.visible_cells_removed=[]
        fact.effective_light_levels_changed[key]=4 if index<2 else 1
        fact.hazardous_cells_changed[key]=index%2==0
        expected_cells[sensory[index].uuid]={"key":key,"level":4 if index<3 else 1,
            "hazard":true if index==0 else (false if index==2 else first<second)}
    _composition_case(ranked,changed,"typed competing light/hazard values with lexical observer ties",expected_cells)

func _initialize() -> void:
    var cases_path = "res://.runtime/sdk-study/reducer-oracle.json"
    var recording = ""
    var sequence = -1
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--cases="): cases_path=argument.trim_prefix("--cases=")
        if argument.begins_with("--recording="): recording=argument.trim_prefix("--recording=")
        if argument.begins_with("--sequence="): sequence=int(argument.trim_prefix("--sequence="))
    check(not recording.is_empty(),"Required --recording=<current SDK journal>; see script usage")
    check(sequence>0,"Required --sequence=<operation with multiple sensory facts>")
    if recording.is_empty() or sequence<=0:
        print("Usage: Godot --headless --path <project> --script res://tests/sdk_snapshot_checks.gd -- --recording=<current SDK journal> --sequence=<sensory operation> [--cases=<reducer-oracle.json>]")
    var parsed = StrictJSON.new().parse(FileAccess.get_file_as_string(cases_path))
    check(parsed.ok,"Existing Python reducer oracle loads")
    if parsed.ok and not recording.is_empty() and sequence>0:
        var cases = {}
        for case in parsed.value.cases: cases[case.name]=case
        var names = ["contract/complete_initialization","contract/operation_with_lineage","contract/eventless_operation",
            "contract/fact/8_condition","contract/remove_existing_condition","contract/fact/10_item_charge",
            "contract/fact/7_equipment","contract/fact/1_attack","contract/fact/terminal_departure",
            "contract/equal_cursor_observations_keep_received_order","contract/reacquisition_replaces_live_actor",
            "contract/stage_preserves_existing_geometry","contract/staging_introduces_absent_actor",
            "contract/state_before_damage_descendant",
            "contract/senses/coordinate_strings_are_integer_keys","contract/audience_observe_1",
            "contract/audience_view_1","contract/audience_view_5",
            "contract/audience/concealed/view_after_visit","contract/audience/apparent/view_after_removal"]
        for name in names:
            check(cases.has(name),"Required existing oracle case: "+name)
            if cases.has(name): _detached(cases[name])
        _late_operation_failures(cases["contract/operation_with_lineage"])
        _late_sensory_failure(cases["contract/audience_observe_1"])
        _journal_snapshots(recording)
        _composed_snapshots(recording,sequence)
    var report = {"checks":checks,"failures":failures,"cases":selected_cases,"mutated_collections":mutated_collections,
        "recording":recording,"oracle":cases_path,"sequence":sequence,"composed_cases":composed_cases,
        "command":"Godot --headless --path \""+ProjectSettings.globalize_path("res://")+"\" --script res://tests/sdk_snapshot_checks.gd -- --recording=\""+recording+"\" --sequence="+str(sequence)+" --cases=\""+cases_path+"\"",
        "scope":"Public SDK output detachment, late semantic rejection and retained real journal snapshots; no timing or rendering claim"}
    var output = FileAccess.open("res://generated/sdk_snapshot_checks.json",FileAccess.WRITE)
    output.store_string(JSON.stringify(report,"  "));output.close()
    print("SDK_SNAPSHOT_CHECKS ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
