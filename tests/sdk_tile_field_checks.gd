extends SceneTree
# Python native projection/reduction oracle -> SDK acceptance and every displayed
# event boundary. Requires an explicit generated fixture; no private default path.
const Reducer = preload("res://sdk/reducer.gd")
const Compiler = preload("res://presentation/compiler.gd")
const Protocol = preload("res://sdk/protocol.gd")
const StrictJSON = preload("res://sdk/strict_json.gd")
var checks = 0
var failures: Array = []
var cases: Array = []
var event_count = 0
var fixture_path = ""

func check(condition: bool, label: String) -> void:
    checks += 1
    if not condition: failures.append(label); print("SDK_TILE_FIELD_FAIL ",label)

func equal(expected: Variant, actual: Variant, label: String) -> void:
    check(expected==actual,label)
    if expected!=actual: print("SDK_TILE_FIELD_DETAIL ",label," expected=",JSON.stringify(expected)," actual=",JSON.stringify(actual))

func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--cases="): fixture_path=arg.trim_prefix("--cases=")
    if fixture_path.is_empty():
        check(false,"Usage: --cases=<generated tile-field oracle JSON> is required")
        finish(); return
    var loaded=StrictJSON.new().parse(FileAccess.get_file_as_string(fixture_path))
    check(loaded.ok,"Explicit Python oracle loads")
    if not loaded.ok: finish(); return
    var suite: Dictionary=loaded.value
    var protocol=Protocol.new()
    check(protocol.setup_error.is_empty(),"Current generated protocol schema loads")
    equal(suite.protocol_identity,protocol.identity,"Fixture uses the exact current exported protocol identity")
    for row in suite.wire_cases:
        var frozen=row.value.duplicate(true)
        var admitted=protocol.validate(row.root,row.value)
        equal(row.expected.ok,admitted.ok,row.name+" wire acceptance matches Python TypeAdapter")
        if admitted.ok and row.expected.ok:
            equal(row.expected.value,protocol.normalize(row.root,admitted.value),row.name+" omission/default/value semantics")
        equal(frozen,row.value,row.name+" schema admission leaves original wire unchanged")
    for row in suite.initializations:
        var frozen=row.value.duplicate(true)
        var result=Reducer.reduce_initialization(row.value,[])
        equal(row.expected.ok,result.ok,row.name+" initialization acceptance")
        if result.ok and row.expected.ok:
            equal(row.expected.value,result.value,row.name+" initialization result matches Python")
        equal(frozen,row.value,row.name+" initialization input retained")
    for row in suite.cases:
        var start=checks
        var prior_failures=failures.size()
        operation(row)
        cases.append({"name":row.name,"checks":checks-start,"failures":failures.size()-prior_failures})
    finish()

func operation(row: Dictionary) -> void:
    var before: Dictionary=row.before
    var packet: Dictionary=row.packet
    var frozen_before=before.duplicate(true)
    var frozen_packet=packet.duplicate(true)
    var public_result=Reducer.reduce_operation(before,packet)
    var recorded=Reducer._reduce_operation_recorded(before,packet)
    equal(row.expected.ok,public_result.ok,row.name+" public acceptance")
    equal(row.expected.ok,recorded.ok,row.name+" recorded acceptance")
    equal(frozen_before,before,row.name+" caller state survives acceptance/rejection")
    equal(frozen_packet,packet,row.name+" caller operation survives acceptance/rejection")
    if not row.expected.ok:
        check(not recorded.has("transitions"),row.name+" rejection exposes no partial event snapshots")
        var denied=Compiler.compile(before,packet,{})
        check(not denied.ok and not denied.has("value"),row.name+" failed world base cannot publish presentation groups")
        return
    if not public_result.ok or not recorded.ok: return
    equal(row.expected.value,public_result.value,row.name+" Python canonical final state")
    equal(public_result.value,recorded.value,row.name+" recorded fold preserves canonical result")
    var frozen_records=recorded.transitions.duplicate(true)
    var compiled=Compiler.compile_recorded(before,packet,{},recorded.value,recorded.transitions)
    check(compiled.ok,row.name+" recorded event-time values compile")
    if not compiled.ok: return
    var cold=Compiler.compile(before,packet,{})
    check(cold.ok and cold.value==compiled.value,row.name+" cold compilation equals recorded handoff")
    var groups: Array=compiled.value.groups
    var frozen_groups=groups.duplicate(true)
    var expected_events={}
    for expected in row.expected.events: expected_events[expected.event_uuid]=expected.tiles
    var seen_events={}
    var reference: Dictionary=before
    for index in packet.lineages.size():
        var lineage: Dictionary=packet.lineages[index]
        var staged=Reducer.stage_lineage(reference,lineage)
        check(staged.ok,row.name+" source binding stage accepts")
        if staged.ok: equal(row.expected.stages[index].tiles,staged.value.tiles,row.name+" staging never pre-applies field updates")
        var matching: Array=groups.filter(func(group):return group.id==lineage.lineage_uuid)
        check(matching.size()==1,row.name+" exact lineage retains one group")
        if matching.size()==1:
            var expected_staged={}
            for key in row.expected.stages[index].tiles:
                if not reference.tiles.has(key): expected_staged[key]=row.expected.stages[index].tiles[key]
            equal(expected_staged,matching[0].staged_tiles,row.name+" staged supports retain full discovery values only")
        var reduced=Reducer.reduce_lineage(reference,lineage)
        check(reduced.ok,row.name+" public lineage folds independently")
        if reduced.ok: reference=reduced.value
    var display=before.duplicate(true)
    var retained_tiles: Array=[]
    for group in groups:
        for commit in group.commits:
            Compiler.apply_delta(display,commit.delta)
            if commit.has("event_uuid"):
                var event: String=commit.event_uuid
                check(expected_events.has(event),row.name+" compiler preserves source event identity")
                if expected_events.has(event):
                    equal(expected_events[event],display.tiles,row.name+" exact Python tile values at event "+event)
                    seen_events[event]=true
                    event_count+=1
                for key in commit.delta.tiles:
                    retained_tiles.append({"value":commit.delta.tiles[key],"frozen":commit.delta.tiles[key].duplicate(true)})
    equal(expected_events.size(),seen_events.size(),row.name+" every intermediate world boundary displayed once")
    equal(row.expected.value,display,row.name+" complete displayed state equals Python canonical state")
    var second=before.duplicate(true)
    for group in groups:
        for commit in group.commits: Compiler.apply_delta(second,commit.delta)
    equal(display,second,row.name+" repeated cold display replay is identical")
    for held in retained_tiles: equal(held.frozen,held.value,row.name+" later patches preserve earlier tile snapshots")
    equal(frozen_records,recorded.transitions,row.name+" compilation/display preserve captured records")
    equal(frozen_groups,groups,row.name+" repeated display preserves compiled records")
    # Caller containers remain independent even after compilation retained values.
    for tile in before.tiles.values():
        tile.name="Caller changed prior tile"
        tile.surface.layers.clear()
    for lineage in packet.lineages:
        for update in lineage.world_updates:
            for change in update.get("tile_changes",[]): change.changes.clear()
            for tile in update.tiles: tile.name="Caller changed full tile"
    equal(frozen_records,recorded.transitions,row.name+" caller edits preserve held event-time tiles")
    equal(frozen_groups,groups,row.name+" caller edits preserve held displayed tiles")

func finish() -> void:
    var report={"checks":checks,"failures":failures,"cases":cases,"event_boundaries":event_count,
        "fixture":fixture_path,"command":"Godot --headless --path \"%s\" --script res://tests/sdk_tile_field_checks.gd -- --cases=\"%s\"" % [ProjectSettings.globalize_path("res://"),fixture_path],
        "scope":"Python native projection/reduction oracle: exact tile-field admission, initialization, event-time canonical/displayed values, independent staging, cold compilation/replay and snapshot/failure isolation. No rendering, server transport or timing claim."}
    FileAccess.open("res://generated/sdk_tile_field_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SDK_TILE_FIELD_CHECKS ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
