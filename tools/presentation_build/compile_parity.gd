extends SceneTree
## Compiles every recorded Studio journal of the case inventories with the
## Studio's own recording path (Recording.read: reducer, compiler, timeline
## rows) and writes one digest per compiled group and timeline row, so two
## states of the presentation data can be compared operation by operation.
##   --headless --script res://tools/presentation_build/compile_parity.gd -- --output=<json> [--compare=<json>]
##   [--journal=<one journal>] [--dump=<text file: one canonical group or row per line>]
const Recording = preload("res://studio/recording.gd")
const INVENTORIES := ["res://generated/studio_case_inventory.json", "res://generated/studio_spell_case_inventory.json"]
## Wall-clock measurements and per-run identities: never part of a digest.
## Dead fields the abilities source leaves out (provenance prose and notes no
## reader uses); with --dead they are not part of a digest either.
const DEAD := ["cue_role", "material_class", "source_note", "light_color_source", "footprint", "registration_note",
    "timing_note", "source_evidence", "authored_footprints", "clip_by_id", "replaces_media"]
static var ignore_dead := false
const VOLATILE := ["compile_ms", "decode_ms", "reduce_ms", "index_ms", "read_ms", "total_ms", "elapsed_ms", "profile",
    "read_profile", "process_uptime_ms", "created_usec", "requested_usec", "cache"]

func _initialize() -> void:
    run.call_deferred()

func canonical(value: Variant) -> String:
    match typeof(value):
        TYPE_DICTIONARY:
            var keys: Array = value.keys().map(func(key): return str(key))
            keys.sort()
            var parts := PackedStringArray()
            for key in keys:
                if key in VOLATILE or (ignore_dead and key in DEAD):continue
                parts.append(JSON.stringify(key) + ":" + canonical(value[key] if value.has(key) else value[StringName(key)]))
            return "{" + ",".join(parts) + "}"
        TYPE_ARRAY:
            return "[" + ",".join(PackedStringArray(value.map(func(item): return canonical(item)))) + "]"
        TYPE_FLOAT:return String.num_scientific(value)
        TYPE_OBJECT:
            if value == null:return "null"
            if value is Resource and not value.resource_path.is_empty():return "<" + value.resource_path + ">"
            return "<" + value.get_class() + ">"
        TYPE_CALLABLE:return "<callable>"
    if value is PackedFloat32Array or value is PackedFloat64Array or value is PackedVector2Array or value is PackedVector3Array or value is PackedColorArray or value is PackedInt32Array or value is PackedStringArray:
        return canonical(Array(value))
    return var_to_str(value)

func journals() -> Array:
    var result: Array = []
    for path in INVENTORIES:
        if not FileAccess.file_exists(path):continue
        var inventory: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
        for item in inventory.get("cases", []):
            if item.has("journal"):result.append(str(item.journal))
            for perspective in item.get("perspectives", []):result.append(str(perspective.journal))
    return result

func run() -> void:
    var output := "";var compare := "";var dump := "";var only := ""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--output="):output = argument.trim_prefix("--output=")
        elif argument.begins_with("--compare="):compare = argument.trim_prefix("--compare=")
        elif argument.begins_with("--dump="):dump = argument.trim_prefix("--dump=")
        elif argument.begins_with("--journal="):only = argument.trim_prefix("--journal=")
        elif argument == "--dead":ignore_dead = true
    var report := {}
    var dumped := PackedStringArray()
    for journal in journals():
        if not only.is_empty() and journal != only:continue
        var index: Dictionary = Recording.read(journal)
        if not index.get("ok", false):report[journal] = {"error": str(index.get("error", ""))};continue
        var groups := PackedStringArray()
        for group in index.groups:groups.append(canonical(group).sha256_text().left(16))
        var rows := PackedStringArray()
        for row in index.rows:rows.append(canonical(row).sha256_text().left(16))
        report[journal] = {"groups": groups, "rows": rows, "duration_ms": index.duration_ms}
        if not dump.is_empty():
            for group in index.groups:dumped.append(canonical(group))
            for row in index.rows:dumped.append(canonical(row))
        print("COMPILE_PARITY ", journal, " groups=", groups.size(), " rows=", rows.size())
    if not output.is_empty():
        var file := FileAccess.open(output, FileAccess.WRITE);file.store_string(JSON.stringify(report, "  "));file.close()
    if not dump.is_empty():
        var file := FileAccess.open(dump, FileAccess.WRITE);file.store_string("\n".join(dumped));file.close()
    if compare.is_empty():quit(0);return
    var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(compare))
    var differences := 0
    for journal in before:
        var a: Dictionary = before[journal];var b: Dictionary = report.get(journal, {})
        for part in ["groups", "rows"]:
            var left: Array = a.get(part, []);var right: Array = b.get(part, [])
            var changed: Array = []
            for i in maxi(left.size(), right.size()):
                if i >= left.size() or i >= right.size() or left[i] != right[i]:changed.append(i)
            if not changed.is_empty() or a.has("error") != b.has("error"):
                differences += 1
                print("COMPILE_PARITY_DIFF ", journal, " ", part, " ", changed.slice(0, 10), " of ", left.size(), "/", right.size())
    print("COMPILE_PARITY_COMPARED ", JSON.stringify({"journals": before.size(), "differences": differences}))
    quit(0 if differences == 0 else 1)
