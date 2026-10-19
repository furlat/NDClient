extends SceneTree
## Compare unchanged bytes with the current Python SDK's independent decisions.
const Protocol = preload("res://sdk/protocol.gd")
const StrictJSON = preload("res://sdk/strict_json.gd")

func same_json(left: Variant, right: Variant) -> bool:
	if typeof(left) in [TYPE_INT, TYPE_FLOAT] and typeof(right) in [TYPE_INT, TYPE_FLOAT]: return left == right
	if typeof(left) != typeof(right): return false
	if left is Array:
		if left.size() != right.size(): return false
		for i in left.size():
			if not same_json(left[i], right[i]): return false
		return true
	if left is Dictionary:
		if left.size() != right.size(): return false
		for key in left:
			if not right.has(key) or not same_json(left[key], right[key]): return false
		return true
	return left == right

func mutate_collections(value: Variant) -> void:
	if value is Dictionary:
		for child in value.values(): mutate_collections(child)
		value["normalization_mutation_probe"] = true
	elif value is Array:
		for child in value: mutate_collections(child)
		value.append(null)

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var path := args[0] if not args.is_empty() else "res://tests/fixtures/schema16/protocol_parity.jsonl"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot read protocol oracle cases: " + path)
		quit(1)
		return
	var protocol := Protocol.new()
	var manifest: Dictionary = StrictJSON.new().parse(file.get_line()).value
	var failures: Array = []
	var native_rejections: Array = []
	var count := 0
	var normalized_count := 0
	if manifest.schema_digest != protocol.identity.schema_digest:
		failures.append({"label": "oracle schema identity", "expected": manifest.schema_digest, "actual": protocol.identity.schema_digest})
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty(): continue
		var row: Dictionary = StrictJSON.new().parse(line).value
		var raw := Marshalls.base64_to_raw(row.raw_base64)
		var outcome: Dictionary = protocol.decode(row.root, raw)
		if outcome.ok and row.mode == "identity": outcome = protocol.check_identity(outcome.value)
		count += 1
		if outcome.ok != row.expected_ok:
			failures.append({"label": row.label, "expected_ok": row.expected_ok, "actual": outcome})
		elif outcome.ok and row.has("expected_value") and not same_json(outcome.value, row.expected_value):
			failures.append({"label": row.label, "issue": "admission changed decoded values", "expected": row.expected_value, "actual": outcome.value})
		if outcome.ok:
			var before: Variant = outcome.value.duplicate(true) if outcome.value is Array or outcome.value is Dictionary else outcome.value
			var expected: Variant = protocol.normalize(row.root, outcome.value)
			var normalized: Variant = protocol._normalize_admitted(row.root, outcome.value)
			normalized_count += 1
			if not same_json(expected, normalized):
				failures.append({"label": row.label, "issue": "admitted normalization changed defaults or canonical values"})
			mutate_collections(normalized)
			if not same_json(before, outcome.value):
				failures.append({"label": row.label, "issue": "normalization or edits to its result mutated admitted input"})
		if row.has("native_rejection"):
			native_rejections.append({"label": row.label, "python_ok": row.python_ok, "godot_ok": outcome.ok, "reason": row.native_rejection})
	if count != int(manifest.cases): failures.append({"label": "case count", "expected": manifest.cases, "actual": count})
	print(JSON.stringify({"checks": count, "normalized_cases": normalized_count, "failures": failures, "native_rejections": native_rejections, "oracle": manifest.oracle}))
	quit(0 if failures.is_empty() else 1)
