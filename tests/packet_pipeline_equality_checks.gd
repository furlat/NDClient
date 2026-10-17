extends SceneTree
# Every recorded packet through the client's packet path, in isolation: SSE
# admission (the trusted producer parse for the current contract), journal
# reduction with recorded transitions, and the presentation compiler. The
# reduced state, its captures, the detached public fold and the compiled
# presentation must stay byte-identical (var_to_bytes, key order included) to
# a reference generated from the unchanged pipeline.
# Usage: godot --headless --path <client> --script res://tests/packet_pipeline_equality_checks.gd
#        -- [--recording=<journal-dir>]... [--defaults] [--reference=<json>] [--write-reference]
#           [--timings=<repeats>] [--report=<json>] [--dump=<dir>]
# Without --recording (or with --defaults): the local Gallery journal and every
# Studio case journal. The live player runs are passed as --recording paths:
#   --recording=<main tree>/.runtime/player-runs/20261017T210238.704817Z/journal
#   (likewise 20261017T210158.554073Z and 20261017T210321.881516Z) --defaults
# The checked-in reference was written with --write-reference by 6c4b601's
# reducer/compiler. Authored catalog content feeds the compiler, so a content
# change needs a new reference from the unchanged pipeline, not from new code.
# --timings skips hashing and reports per-packet phase medians (first pass
# warms the authoring cache and is excluded).
const Journal = preload("res://sdk/journal.gd")
const Reducer = preload("res://sdk/reducer.gd")
const Compiler = preload("res://presentation/compiler.gd")
const REFERENCE = "res://tests/packet_pipeline_reference.json"
const GALLERY = "res://.runtime/player-runs/20261017T050051.313612Z/journal"
const STUDIO = "res://.runtime/studio-cases"
var checks := 0
var failures: Array = []
var dump := ""

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("PACKET_PIPELINE_FAIL ",label)

# Native spell sources name the shared bake generation that was current while
# compiling ("res://.derived/native-spells/<generation>/..."). Rebakes change
# only that directory, so compiled output is hashed with it normalized.
static var _bake := RegEx.create_from_string("res://\\.derived/native-spells/[0-9]+/")

static func _portable(value: Variant) -> Variant:
    match typeof(value):
        TYPE_DICTIONARY:
            var result := {}
            for key in value: result[_portable(key)] = _portable(value[key])
            return result
        TYPE_ARRAY:
            var result := []
            for item in value: result.append(_portable(item))
            return result
        TYPE_STRING:
            return _bake.sub(value, "res://.derived/native-spells/current/", true) if value.contains(".derived/native-spells/") else value
    return value

static func digest(value: Variant) -> String:
    var context := HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(var_to_bytes(value))
    return context.finish().hex_encode()

# Event-time records as the compiler consumes them. Each lineage's "world"
# entry only indexes the fold's own detached rows by key (no new values).
static func _records(transitions: Dictionary) -> Dictionary:
    var result: Dictionary = transitions.duplicate()
    if result.has("lineages"):
        result.lineages = []
        for lineage in transitions.lineages:
            var row: Dictionary = lineage.duplicate()
            row.erase("world")
            result.lineages.append(row)
    return result

static func recording_name(directory: String) -> String:
    var parts := directory.trim_suffix("/").split("/")
    # <run>/journal or <case>/amber/journal
    if parts.size() >= 3 and parts[-2] == "amber": return "studio:" + parts[-3]
    return parts[-2] if parts.size() >= 2 else directory

func _initialize() -> void:
    var recordings: Array = []
    var reference_path := REFERENCE
    var write := false
    var repeats := 0
    var report_path := ""
    var defaults := false
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="): recordings.append(arg.trim_prefix("--recording="))
        elif arg.begins_with("--reference="): reference_path = arg.trim_prefix("--reference=")
        elif arg == "--write-reference": write = true
        elif arg.begins_with("--timings="): repeats = int(arg.trim_prefix("--timings="))
        elif arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
        elif arg.begins_with("--dump="): dump = arg.trim_prefix("--dump=")
        elif arg == "--defaults": defaults = true
    if recordings.is_empty() or defaults:
        recordings.append(GALLERY)
        var cases := Array(DirAccess.get_directories_at(STUDIO))
        cases.sort()
        for name in cases:
            var journal: String = STUDIO.path_join(name).path_join("amber/journal")
            if DirAccess.dir_exists_absolute(journal) and not DirAccess.get_files_at(journal).is_empty(): recordings.append(journal)
    if repeats > 0:
        _timings(recordings, repeats, report_path)
        return
    var reference: Dictionary = {}
    if not write:
        var text := FileAccess.get_file_as_string(reference_path)
        var parsed: Variant = JSON.parse_string(text)
        check(parsed is Dictionary, "Reference loads: " + reference_path)
        if not parsed is Dictionary: finish({}); return
        reference = parsed
    var produced: Dictionary = {}
    var packets := 0
    for directory in recordings:
        var name := recording_name(directory)
        var rows: Dictionary = _run(directory, name, true, {}).hashes
        produced[name] = rows
        packets += rows.size()
        if write: continue
        check(reference.has(name), "Reference covers recording " + name)
        if not reference.has(name): continue
        var expected: Dictionary = reference[name]
        var expected_keys: Array = expected.keys(); expected_keys.sort()
        var keys: Array = rows.keys(); keys.sort()
        check(expected_keys == keys, "Same packet sequences as the reference: " + name)
        for sequence in rows:
            for field in rows[sequence]:
                check(expected.get(sequence, {}).get(field) == rows[sequence][field], "%s #%s %s equals reference" % [name, sequence, field])
    if write:
        var file := FileAccess.open(reference_path, FileAccess.WRITE)
        file.store_string(JSON.stringify(produced, "  ", true) + "\n")
        file.close()
    print("PACKET_PIPELINE ", JSON.stringify({"recordings":recordings.size(), "packets":packets, "written":write}))
    finish(produced)

func finish(_produced: Dictionary) -> void:
    print("PACKET_PIPELINE_RESULT ", JSON.stringify({"checks":checks, "failures":failures.slice(0, 40), "failure_count":failures.size()}))
    quit(1 if not failures.is_empty() else 0)

func _scratch(name: String) -> String:
    var path := OS.get_user_data_dir().path_join("packet_pipeline_probe").path_join(name.replace(":", "_"))
    DirAccess.make_dir_recursive_absolute(path)
    for file in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(file))
    return path

# One pass over a recording, in live order. Hashes when requested, phases always.
func _run(directory: String, name: String, hashing: bool, cache: Dictionary) -> Dictionary:
    var result := {"hashes":{}, "phases":{}}
    var source := Journal.new()
    var opened: Dictionary = source.open(directory, true, false)
    if not opened.ok:
        result.hashes["open"] = {"error":str(opened.error.message)}
        return result
    var protocol = source.protocol
    var journal := Journal.new()
    journal.profile_enabled = not hashing
    var started: Dictionary = journal.open(_scratch(name), false, false)
    if not started.ok:
        result.hashes["open"] = {"error":str(started.error.message)}
        return result
    journal.protocol = protocol
    var files: Array = []
    for file in DirAccess.get_files_at(directory):
        if file.length() == 21 and file.ends_with(".json"): files.append(file)
    files.sort()
    var presentation: Dictionary = {}
    for file in files:
        var sequence := int(file.trim_suffix(".json"))
        var key := str(sequence)
        var raw := FileAccess.get_file_as_bytes(directory.path_join(file))
        var root_name := "InitializationResponse" if sequence == 0 else "PlayerOperation"
        var trusted: bool = sequence > 0 and protocol._current_server_contract
        var parse_started := Time.get_ticks_usec()
        var decoded: Dictionary = protocol._decode_framed_event(root_name, raw, not hashing, true) if trusted else protocol.decode(root_name, raw)
        var parse_ms := (Time.get_ticks_usec() - parse_started) / 1000.0
        if not decoded.ok:
            result.hashes[key] = {"error":str(decoded.error.message)}
            break
        var before: Dictionary = journal.state
        var reduce_started := Time.get_ticks_usec()
        var accepted: Dictionary = journal._consume_admitted(decoded.value, raw, sequence > 0, trusted)
        var reduce_ms := (Time.get_ticks_usec() - reduce_started) / 1000.0
        if not accepted.ok:
            result.hashes[key] = {"error":str(accepted.error.message)}
            break
        var normalized: Dictionary = accepted.normalized
        var reduced_profile: Dictionary = journal.last_profile.duplicate(true)
        var compiled: Dictionary
        var compile_ms := 0.0
        var compile_phases: Dictionary = {}
        if sequence == 0:
            presentation = journal.state
            compiled = {"events":Compiler.EventTrace.initialization(normalized.initialization)}
        else:
            var compile_started := Time.get_ticks_usec()
            var output: Dictionary = Compiler.compile_recorded(presentation, normalized, cache, journal.state, accepted.get("transitions", {}), not hashing)
            compile_ms = (Time.get_ticks_usec() - compile_started) / 1000.0
            if not output.ok:
                result.hashes[key] = {"error":str(output.error.message)}
                break
            presentation = output.value.final_state
            compile_phases = output.get("compile_phases_ms", {})
            compiled = {"groups":output.value.groups, "skipped":output.value.skipped}
        if hashing:
            var row := {"state":digest(journal.state), "compiled":digest(_portable(compiled))}
            if sequence > 0:
                row.transitions = digest(_records(accepted.get("transitions", {})))
                # The detached public fold (non-journal callers, Compiler.compile).
                var detached: Dictionary = Reducer._reduce_operation_recorded(before, normalized)
                row.detached = digest([detached.ok, detached.get("value"), _records(detached.get("transitions", {}))])
            result.hashes[key] = row
            if not dump.is_empty():
                DirAccess.make_dir_recursive_absolute(dump)
                for field in ["state", "compiled"]:
                    var out := FileAccess.open(dump.path_join("%s-%s-%s.txt" % [name.replace(":", "_"), key, field]), FileAccess.WRITE)
                    out.store_string(var_to_str(journal.state if field == "state" else compiled))
                    out.close()
        else:
            result.phases[key] = {"bytes":raw.size(), "parse_ms":parse_ms, "parse":decoded.get("phases_ms", {}),
                "reduce_ms":reduce_ms, "journal":reduced_profile.get("phase_ms", {}), "reducer":reduced_profile.get("reducer_ms", {}),
                "compile_ms":compile_ms, "compiler":compile_phases}
    return result

static func _median(values: Array) -> float:
    if values.is_empty(): return 0.0
    var sorted := values.duplicate()
    sorted.sort()
    return sorted[sorted.size() / 2] if sorted.size() % 2 == 1 else (sorted[sorted.size() / 2 - 1] + sorted[sorted.size() / 2]) / 2.0

static func _flatten(row: Dictionary, prefix: String, into: Dictionary) -> void:
    for key in row:
        var value: Variant = row[key]
        if value is Dictionary: _flatten(value, prefix + str(key) + ".", into)
        elif value is float or value is int: into[prefix + str(key)] = float(value)

func _timings(recordings: Array, repeats: int, report_path: String) -> void:
    var report: Dictionary = {}
    for directory in recordings:
        var name := recording_name(directory)
        var cache: Dictionary = {}
        var samples: Dictionary = {}
        for repeat in range(repeats + 1):
            var phases: Dictionary = _run(directory, name, false, cache).phases
            if repeat == 0: continue
            for sequence in phases:
                var flat: Dictionary = {}
                _flatten(phases[sequence], "", flat)
                if not samples.has(sequence): samples[sequence] = {}
                for field in flat:
                    if not samples[sequence].has(field): samples[sequence][field] = []
                    samples[sequence][field].append(flat[field])
        var medians: Dictionary = {}
        for sequence in samples:
            medians[sequence] = {}
            var fields: Array = samples[sequence].keys()
            fields.sort()
            for field in fields: medians[sequence][field] = snappedf(_median(samples[sequence][field]), 0.001)
        report[name] = medians
        for sequence in medians:
            var row: Dictionary = medians[sequence]
            print("PACKET_PIPELINE_TIMING %s #%s bytes=%d parse=%.2f reduce=%.2f compile=%.2f" % [name, sequence, int(row.get("bytes", 0)), row.get("parse_ms", 0.0), row.get("reduce_ms", 0.0), row.get("compile_ms", 0.0)])
    if not report_path.is_empty():
        var file := FileAccess.open(report_path, FileAccess.WRITE)
        file.store_string(JSON.stringify(report, "  ", true) + "\n")
        file.close()
    quit(0)
