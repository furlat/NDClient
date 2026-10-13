extends SceneTree
# Actual journal input -> every intermediate displayed snapshot. No renderer,
# synthetic sensory facts or live service; the SDK independently folds events.
# Usage: godot --headless --path <client> --script res://tests/compiler_snapshot_checks.gd
#        -- --recording=<journal-directory> [--sequence=<operation-number>]
#        [--oracle=<preserved-compiler.gd>]
# Without --sequence, the focused regression checks recorded operations 10 and 87.
const Compiler = preload("res://presentation/compiler.gd")
const Journal = preload("res://sdk/journal.gd")
const Reducer = preload("res://sdk/reducer.gd")
var checks := 0
var failures: Array = []
var counts = {"events":0,"senses_snapshots":0,"perception_snapshots":0,"world_updates":0,"observations":0}
var cases: Array = []
var invocation: Dictionary = {}
var oracle: Script
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("COMPILER_SNAPSHOT_FAIL ",label)

func _initialize() -> void:
    var directory = ""
    var oracle_path = ""
    var sequences: Array = [10,87]
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="): directory = arg.trim_prefix("--recording=")
        if arg.begins_with("--sequence="): sequences = [int(arg.trim_prefix("--sequence="))]
        if arg.begins_with("--oracle="): oracle_path = arg.trim_prefix("--oracle=")
    if directory.is_empty():
        print("COMPILER_SNAPSHOT_USAGE: --recording=<journal-directory> is required; no local timestamp is assumed.")
        print("godot --headless --path <client> --script res://tests/compiler_snapshot_checks.gd -- --recording=<journal-directory> [--sequence=<operation-number>]")
        quit(2)
        return
    invocation = {"script":"res://tests/compiler_snapshot_checks.gd",
        "arguments":Array(OS.get_cmdline_user_args()),"sequences":sequences.duplicate(),
        "recording_requirement":"External recorded journal; not a checked-in fixture. Default operations: 10 and 87."}
    if not oracle_path.is_empty():
        oracle = load(oracle_path)
        check(oracle!=null,"Explicit preserved compiler oracle loads")
        if oracle==null: finish(); return
    for sequence in sequences:
        var count_before = counts.duplicate()
        var check_before = checks
        var failure_before = failures.size()
        run_case(directory,sequence)
        var case_counts = {}
        for key in counts: case_counts[key] = counts[key]-count_before[key]
        cases.append({"sequence":sequence,"checks":checks-check_before,
            "failures":failures.size()-failure_before,"counts":case_counts})
    finish()

func run_case(directory: String, sequence: int) -> void:
    var journal = Journal.new()
    var opened = journal.open(directory,true,false)
    check(opened.ok,"Actual recording protocol opens")
    if not opened.ok: return
    var replay = journal.replay(sequence-1)
    check(replay.ok,"Actual preceding canonical state replays")
    if not replay.ok: return
    var before: Dictionary = journal.state
    var before_copy = before.duplicate(true)
    var decoded = journal.protocol.decode("PlayerOperation",FileAccess.get_file_as_bytes(directory.path_join("%016d.json" % sequence)))
    check(decoded.ok,"Measured operation passes strict packet admission")
    if not decoded.ok: return
    var packet: Dictionary = journal.protocol.normalize("PlayerOperation",decoded.value)
    var packet_copy = packet.duplicate(true)
    var canonical = Reducer.reduce_operation(before,packet)
    check(canonical.ok,"SDK accepts operation independently")
    if not canonical.ok: return
    var recorded = Reducer._reduce_operation_recorded(before,packet)
    check(recorded.ok and recorded.value==canonical.value,"Recorded canonical fold equals ordinary public reduction")
    if not recorded.ok: return
    var frozen_records = recorded.transitions.duplicate(true)
    if not recorded.transitions.lineages.is_empty():
        for field in ["lineage_uuid","start_cursor","end_cursor"]:
            var mismatched: Dictionary = recorded.transitions.duplicate()
            mismatched.lineages = recorded.transitions.lineages.duplicate()
            mismatched.lineages[0] = mismatched.lineages[0].duplicate()
            mismatched.lineages[0][field] = "different-lineage" if field=="lineage_uuid" else int(mismatched.lineages[0][field])+1
            check(not Compiler.compile_recorded(before,packet,{},recorded.value,mismatched).ok,
                "Mismatched recorded "+field+" is rejected before presentation")
    var compiled = Compiler.compile_recorded(before,packet,{},recorded.value,recorded.transitions)
    check(compiled.ok,"Canonical records compile without a second event fold")
    if not compiled.ok: return
    var groups: Array = compiled.value.groups
    var frozen_groups = groups.duplicate(true)
    if oracle!=null:
        var previous: Dictionary = oracle.compile_admitted(before,packet,{},canonical.value)
        check(previous.ok and previous.value==compiled.value,"Entire captured result equals the independently preserved refolding compiler")
    check(before==before_copy and packet==packet_copy,"Compilation leaves caller state and packet unchanged")
    var reference = before.duplicate(true)
    for lineage in packet.lineages:
        var matching = groups.filter(func(group):return group.id==lineage.lineage_uuid)
        check(matching.size()==1,"One compiled group preserves each recorded lineage")
        if matching.size()!=1: continue
        var group: Dictionary = matching[0]
        var cursors = {}
        for row in lineage.version_rows: cursors[row.event_uuid]=row.source_index
        # The wire permits several observations at one source cursor; retain
        # their wire order just as the public SDK does when folding a lineage.
        var observations: Array = Reducer._ordered_rows(lineage.observations,cursors,"event_uuid")
        var cursor = 0
        var updates = {}
        for update in lineage.world_updates: updates[update.event_uuid]=update
        for node in lineage.events:
            counts.events += 1
            while cursor<observations.size() and cursors[observations[cursor].event_uuid]<=cursors[node.uuid]:
                Reducer._observe(reference,observations[cursor]); cursor+=1; counts.observations+=1
            if updates.has(node.uuid):
                var updated = Reducer.apply_world_update(reference,updates[node.uuid])
                check(updated.ok,"Independent event world after-values apply")
                if not updated.ok: return
                counts.world_updates+=1
            if node.fact!=null and not node.canceled:
                var folded = Reducer.apply_committed_player_fact(reference,node.fact,cursors[node.uuid],cursors)
                check(folded.ok,"Independent recorded fact folds")
            var commits: Array = group.commits.filter(func(commit):return commit.get("event_uuid")==node.uuid)
            check(commits.size()==1,"Every recorded event retains one causal commit")
            if commits.size()!=1: continue
            var delta: Dictionary = commits[0].delta
            for field in delta.set:
                check(delta.set[field]==reference[field],"Event-time "+field+" matches independent fold at "+node.uuid)
            for field in ["actors","tiles","objects","spatial_commit_cursors"]:
                for id in delta[field]:
                    check(delta[field][id]==reference[field][id],"Event-time "+field+" after-value matches independent fold")
            if delta.set.has("senses"): counts.senses_snapshots+=1
            if delta.set.has("perception"): counts.perception_snapshots+=1
        while cursor<observations.size():
            Reducer._observe(reference,observations[cursor]); cursor+=1; counts.observations+=1
        reference.reducer_cursor=lineage.end_cursor
    var first = before.duplicate(true)
    var second = before.duplicate(true)
    for group in groups:
        for commit in group.commits:
            Compiler.apply_delta(first,commit.delta)
            Compiler.apply_delta(second,commit.delta)
    check(first==canonical.value and second==canonical.value,"Two independent displayed replays retain exact canonical final state")
    check(groups==frozen_groups,"Later folds and both displayed replays preserve every retained intermediate record")
    check(recorded.transitions==frozen_records,"Authoring and displayed replay do not mutate canonical event records")
    var reused = Compiler.compile_recorded(before,packet,{},recorded.value,recorded.transitions)
    check(reused.ok and reused.value==compiled.value,"Repeated scheduling of the same records preserves all groups and state")
    var public_result = Compiler.compile(before,packet,{})
    check(public_result.ok and public_result.value==compiled.value,"Public strict compilation and captured compilation remain identical")
    var admitted = Compiler.compile_admitted(before,packet,{},canonical.value)
    check(admitted.ok and admitted.value==compiled.value,"Final-state-only compatibility uses the same captured compiler")
    # Input containers remain the caller's property. Alter actual sensory inputs
    # after compilation; no event snapshot may still refer to those containers.
    if before.senses!=null:
        before.senses.position[0]+=1000
        before.senses.entities.clear()
        before.senses.visible.clear()
    before.perception.members.clear()
    for actor in before.actors.values():
        if actor.last_visual_position!=null: actor.last_visual_position[0]+=1000
    for lineage in packet.lineages:
        for observation in lineage.observations:
            observation.actor.name="Caller mutation after compilation"
            if observation.actor.last_visual_position!=null: observation.actor.last_visual_position[0]+=1000
            if observation.contact!=null: observation.contact.position[0]+=1000
        for node in lineage.events:
            if node.fact!=null and node.fact.kind=="sensory":
                node.fact.entity_contacts_changed.clear()
                node.fact.visible_cells_added.clear()
                node.fact.seen_cells_added.clear()
                node.fact.effective_light_levels_changed.clear()
        for update in lineage.world_updates:
            for tile in update.tiles: tile.elevation_steps+=1000
            for row in update.get("tile_changes",[]): row.changes.clear()
    check(groups==frozen_groups,"Caller mutation of original sensory/world inputs cannot change compiled history")
    check(recorded.transitions==frozen_records,"Caller mutation cannot change canonical captures retained across compilation")
    check(counts.senses_snapshots>1 and counts.perception_snapshots>1,"Actual input exercises multiple retained sensory boundaries")

func finish() -> void:
    var report = {"checks":checks,"failures":failures,"counts":counts,"cases":cases,"invocation":invocation,
        "scope":"Headless actual-recording event snapshots, independent SDK event folds, two exact displayed replays, public/captured/compatibility parity, repeated record scheduling and caller sensory/world/actor-input isolation. No rendered-pixel or timing claim."}
    FileAccess.open("res://generated/compiler_snapshot_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("COMPILER_SNAPSHOT ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
