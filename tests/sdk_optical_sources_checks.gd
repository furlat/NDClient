extends SceneTree
## Public journal/observer values: current optical inputs and explicit archive fallback.
const Journal = preload("res://sdk/journal.gd")
const Audience = preload("res://sdk/audience.gd")
const Protocol = preload("res://sdk/protocol.gd")
var checks = 0
var failures: Array = []
var summaries: Array = []

func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failures.append(label); print("OPTICAL_SDK_FAIL ", label)

func _initialize() -> void:
    var recording = ""
    var legacy = ""
    var oracle = ""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="): recording = arg.trim_prefix("--recording=")
        if arg.begins_with("--legacy="): legacy = arg.trim_prefix("--legacy=")
        if arg.begins_with("--oracle="): oracle = arg.trim_prefix("--oracle=")
    if recording.is_empty() or legacy.is_empty():
        check(false, "Pass --recording=<schema9 case root> and --legacy=<schema8 journal>")
        finish(); return
    var expected: Dictionary = {}
    if not oracle.is_empty():
        var parsed = Protocol.parse_json(FileAccess.get_file_as_bytes(oracle))
        check(parsed.ok, "Independent Python source oracle loads")
        if parsed.ok: expected = parsed.value
    var template = {}
    var source = {}
    var member = {}
    for side in ["amber", "blue"]:
        var journal = Journal.new()
        var directory = recording.path_join(side).path_join("journal")
        check(journal.open(directory, false, false).ok, "Current journal opens: " + side)
        var names: Array[String] = []
        for name in DirAccess.get_files_at(directory):
            if name.ends_with(".json") and name.trim_suffix(".json").is_valid_int(): names.append(name)
        names.sort()
        check(names.size() > 14, "Actual off/ignite/move prefix exists: " + side)
        var held: Array = []
        var frozen: Array = []
        for index in names.size():
            var raw = FileAccess.get_file_as_bytes(directory.path_join(names[index]))
            var admitted = journal.protocol.decode("InitializationResponse" if index == 0 else "PlayerOperation", raw)
            check(admitted.ok, "Strict schema9 packet " + side + "/" + str(index))
            if not admitted.ok: break
            if index == 0 and template.is_empty():
                for node in admitted.value.initialization.nodes:
                    if node.fact != null and node.fact.kind == "sensory": template = node.fact.duplicate(true); break
            var consumed = journal.consume(admitted.value, raw)
            check(consumed.ok, "Public journal accepts " + side + "/" + str(index))
            if not consumed.ok: break
            var senses: Dictionary = journal.state.senses
            check(senses.has("light_sources") and senses.has("light_source_removals"), "Current empty/nonempty source ownership is explicit")
            check(senses == Audience.view(journal.state.perception, journal.state.observer_uuid), "Incremental and exhaustive audience outputs agree")
            for prior in held.size(): check(held[prior] == frozen[prior], "Later source observation retains prefix " + str(prior))
            held.append(senses); frozen.append(senses.duplicate(true))
            if index in [8, 13, 14]:
                var level = {8:2, 13:3, 14:4}[index]
                check(journal.state.tiles["4,6"].resolved_light == level and senses.effective_light_levels["4,6"] == level, "Real objective/perceived zone " + side + "/" + str(index))
                check(senses.light_sources.size() == 1, "Opposing and controlled views each receive one actual lit source")
                if senses.light_sources.size() == 1:
                    var row: Dictionary = senses.light_sources.values()[0]
                    check(row.position == {8:[10,6], 13:[7,6], 14:[6,6]}[index], "Published optical source position follows real movement")
                    check(row.actor_anchored, "Actor optical elevation remains disclosed without private identity")
                    if side == "amber":
                        check(row.anchor_item_uuid == null, "Opposing private torch item identity withheld")
                        check(row.anchor_entity_uuid == null or senses.entities.get(row.anchor_entity_uuid,{}).get("visual",false), "Optional opposing actor anchor has an actual visual contact")
                    source = row.duplicate(true)
                    member = journal.state.perception.members.values()[0].duplicate(true)
            var record = {"sequence":index, "light_sources":senses.light_sources, "light_source_removals":senses.light_source_removals,
                "objective_light":journal.state.tiles.get("4,6",{}).get("resolved_light"),
                "ambient_light":journal.state.tiles.get("4,6",{}).get("default_light"), "currently_visible":[4,6] in senses.visible}
            if expected.has(side):
                var python_row: Dictionary = expected[side][index] if index < expected[side].size() else {}
                var comparable = {}
                for field in record: comparable[field] = python_row.get(field)
                if index == 0:
                    for field in record:
                        if not Protocol._equal(record[field], comparable[field]):
                            print("OPTICAL_ORACLE_FIELD ",side," ",field," actual=",JSON.stringify(record[field]).left(400)," expected=",JSON.stringify(comparable[field]).left(400))
                check(Protocol._equal(record, comparable), "Independent Python exact source/tombstone/objective parity " + side + "/" + str(index))
        summaries.append({"audience":side, "sequences":names.size(), "cursor":journal.cursor.get("sequence",-1)})
    check(not template.is_empty() and not source.is_empty() and not member.is_empty(), "Actual typed input supports observer composition cases")
    if not template.is_empty() and not source.is_empty():
        composition(template, source, member)
        compact_composition(template, source, member)
    var old = Journal.new()
    check(old.open(legacy, true, false).ok and old.protocol.identity.player_schema_version == 8, "Historical mode selects archived schema8")
    var restored = old.replay(0)
    check(restored.ok, "Archived schema8 initialization reduces")
    if restored.ok: check(not old.state.senses.has("light_sources"), "Legacy absence stays absent, never authoritative emptiness")
    var strict = Journal.new()
    check(strict.open(legacy, false, false).ok and not strict.replay(0).ok, "Live/current admission still rejects old identity")
    finish()

func composition(template: Dictionary, source: Dictionary, member: Dictionary) -> void:
    var first = "00000000-0000-0000-0000-000000000001"
    var second = "00000000-0000-0000-0000-000000000002"
    var identity: String = source.source_uuid
    var a: Dictionary = member.duplicate(true)
    var b: Dictionary = member.duplicate(true)
    var row: Dictionary = source.duplicate(true)
    row.revision = 10; row.affected_tiles = {"4,6":2}; row.anchor_entity_uuid = null; row.anchor_item_uuid = null
    var other: Dictionary = row.duplicate(true)
    other.affected_tiles = {"5,6":3}; other.anchor_entity_uuid = second; other.anchor_item_uuid = first
    a.light_sources = {identity:row}; a.light_source_removals = {}
    b.light_sources = {identity:other}; b.light_source_removals = {}
    var perception = {"members":{first:a,second:b},"contact_cursors":{},"effect_cursors":{},"effect_absences":{}}
    var before = perception.duplicate(true)
    var joined = Audience.view(perception, first)
    check(joined.light_sources[identity].affected_tiles == {"4,6":2,"5,6":3}, "Equal revisions union only authorized footprints")
    check(joined.light_sources[identity].anchor_entity_uuid == second and joined.light_sources[identity].anchor_item_uuid == first, "Equal revisions coalesce disclosed optional anchors")
    joined.light_sources[identity].affected_tiles.clear()
    check(perception == before, "Public source result is deeply detached")
    b.light_sources = {}; b.light_source_removals = {identity:10}
    var same = Audience.view(perception, first)
    check(same.light_sources.has(identity) and same.light_source_removals.is_empty(), "Equal tombstone is local loss of view, surviving observer remains")
    b.light_source_removals[identity] = 11
    var retired = Audience.view(perception, first)
    check(retired.light_sources.is_empty() and retired.light_source_removals == {identity:11}, "Newer tombstone suppresses stale other-observer source")
    other.revision = 12; other.position = [2,3]
    b.light_sources = {identity:other}; b.light_source_removals = {}
    var newest = Audience.view(perception, first)
    check(newest.light_sources[identity].affected_tiles == {"5,6":3} and newest.light_sources[identity].position == [2,3], "Newer shape does not union obsolete footprints")
    var event: Dictionary = template.duplicate(true)
    event.observer_uuid = first; event.light_sources_changed = {}; event.light_sources_removed = {}
    var reset = Audience.reduce_senses(first, a, event)
    check(reset.ok and reset.value.light_sources.is_empty() and reset.value.light_source_removals.is_empty(), "Initial authoritative empty resets source/tombstone history")
    event.initial = false; event.light_sources_removed = {identity:13}
    var snapshot = a.duplicate(true)
    var removed = Audience.reduce_senses(first, a, event)
    check(removed.ok and removed.value.light_sources.is_empty() and removed.value.light_source_removals == {identity:13}, "Source removal retains its revision")
    check(a == snapshot, "Removing a source preserves caller snapshot")
    event.light_sources_changed = {identity:other}
    var readded = Audience.reduce_senses(first, removed.value, event)
    check(readded.ok and readded.value.light_sources.has(identity) and readded.value.light_source_removals.is_empty(), "Changed after removal in one delta wins, matching Python order")
    event.effective_light_levels_changed = {"4,6":9}
    var denied = Audience.reduce_senses(first, a, event)
    check(not denied.ok and a == snapshot, "Rejected sensory value does not publish partial source edits")

func compact_composition(template: Dictionary, source: Dictionary, member: Dictionary) -> void:
    var first = "00000000-0000-0000-0000-000000000001"
    var second = "00000000-0000-0000-0000-000000000002"
    var identity: String = source.source_uuid
    var protocol = Protocol.new()
    for omitted in [false, true]:
        var label = "Omitted footprint" if omitted else "Empty footprint"
        var row: Dictionary = source.duplicate(true)
        row.affected_tiles = {}; row.anchor_entity_uuid = null; row.anchor_item_uuid = null
        if omitted: row.erase("affected_tiles")
        check(protocol.decode("PerceivedLightSource", JSON.stringify(row).to_utf8_buffer()).ok, label+": unchanged schema admits compact source")
        var a: Dictionary = member.duplicate(true)
        var event: Dictionary = template.duplicate(true)
        event.initial = false; event.observer_uuid = first
        event.light_sources_changed = {identity:row}; event.light_sources_removed = {}
        var reduced = Audience.reduce_senses(first, a, event)
        check(reduced.ok and reduced.value.light_sources[identity]==row, label+": sensory reducer retains compact descriptor")
        if not reduced.ok: continue
        a = reduced.value
        var b: Dictionary = a.duplicate(true)
        var other: Dictionary = row.duplicate(true)
        other.anchor_entity_uuid = second
        b.light_sources = {identity:other}
        var perception = {"members":{first:a,second:b},"contact_cursors":{},"effect_cursors":{},"effect_absences":{}}
        var before = perception.duplicate(true)
        var joined = Audience.view(perception, first)
        check(joined.light_sources[identity].get("affected_tiles",{}).is_empty(), label+": observer union needs no cell footprint")
        check(joined.light_sources[identity].anchor_entity_uuid==second and joined.light_sources[identity].anchor_item_uuid==null, label+": only disclosed anchor joins compact source")
        joined.light_sources[identity].position[0] += 1
        check(perception==before, label+": public descriptor remains detached")
        other.revision += 1; other.position = [2,3]
        var moved = Audience.view(perception, first)
        check(moved.light_sources[identity]==other, label+": newer compact position replaces stale observer")
        b.light_sources = {}; b.light_source_removals = {identity:other.revision+1}
        var removed = Audience.view(perception, first)
        check(removed.light_sources.is_empty() and removed.light_source_removals[identity]==other.revision+1, label+": newer removal retires compact descriptor")

func finish() -> void:
    var report = {"checks":checks,"failures":failures,"recordings":summaries,
        "scope":"Schema9 optical observations, observer revision/tombstone composition, public ownership and explicit schema8 offline compatibility; no renderer or gameplay rule change"}
    FileAccess.open("res://generated/sdk_optical_sources_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SDK_OPTICAL_SOURCES ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
