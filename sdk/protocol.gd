extends RefCounted
## Current schema-16 admission. Trusted server packets stay sparse and borrowed.

const MAX_BYTES := 64 * 1024 * 1024
const SAFE_INTEGER := 9007199254740991
const Choices = preload("res://sdk/choices.gd")
const StrictJSON = preload("res://sdk/strict_json.gd")
const ProducerJSON = preload("res://sdk/producer_json.gd")
var schema: Dictionary
var identity: Dictionary
var setup_error := ""
var _patterns: Dictionary = {}
var _current_server_contract := false
var _producer_json: RefCounted
# The shipped schema and identity are parsed once per path pair per process
# (each strict parse is ~95 ms). Protocol objects share only these parsed,
# never-mutated dictionaries; their caches above stay per object.
static var _parsed: Dictionary = {}
static var _parsed_mutex := Mutex.new()
# Exact native UTF-8 admission. get_string_from_ascii reads bytes 1-255 as
# U+0001-U+00FF (a NUL ends it, failing the length check); this expression
# accepts exactly the sequences validate_utf8 accepts (Unicode Table 3-7).
static var _utf8_sequences := RegEx.create_from_string("\\A(?:[\\x01-\\x7f]++|[\\xc2-\\xdf][\\x80-\\xbf]|\\xe0[\\xa0-\\xbf][\\x80-\\xbf]|[\\xe1-\\xec\\xee\\xef][\\x80-\\xbf]{2}|\\xed[\\x80-\\x9f][\\x80-\\xbf]|\\xf0[\\x90-\\xbf][\\x80-\\xbf]{2}|[\\xf1-\\xf3][\\x80-\\xbf]{3}|\\xf4[\\x80-\\x8f][\\x80-\\xbf]{2})*+\\z")

func _init(schema_path: String = "res://sdk/player-api-v1.schema.json", identity_path: String = "res://sdk/protocol-identity.json") -> void:
	var key := schema_path + "\n" + identity_path
	_parsed_mutex.lock()
	if not _parsed.has(key): _parsed[key] = _parse(schema_path, identity_path)
	var parsed: Dictionary = _parsed[key]
	_parsed_mutex.unlock()
	setup_error = parsed.error
	if not parsed.has("schema"): return
	schema = parsed.schema
	identity = parsed.identity
	_current_server_contract = schema_path == "res://sdk/player-api-v1.schema.json" and identity_path == "res://sdk/protocol-identity.json"

func _parse(schema_path: String, identity_path: String) -> Dictionary:
	var schema_result := StrictJSON.new().parse(FileAccess.get_file_as_string(schema_path))
	var identity_result := StrictJSON.new().parse(FileAccess.get_file_as_string(identity_path))
	if not schema_result.ok or not schema_result.value is Dictionary or not schema_result.value.get("$defs") is Dictionary:
		return {"error": "Cannot load the shipped player schema"}
	if not identity_result.ok or not identity_result.value is Dictionary:
		return {"error": "Cannot load the shipped protocol identity"}
	schema = schema_result.value
	return {"schema": schema, "identity": identity_result.value, "error": _vocabulary(schema)}

static func failure(message: String) -> Dictionary:
	return {"ok": false, "error": {"kind": "protocol", "message": message, "retryable": false}}

static func validate_utf8(raw: PackedByteArray) -> Dictionary:
	# Validate before get_string_from_utf8, which otherwise repairs bad sequences.
	var i := 0
	while i < raw.size():
		var a := int(raw[i])
		if a < 128:
			i += 1
			continue
		var count := 0
		var lower := 128
		var upper := 191
		if a >= 194 and a <= 223:
			count = 1
		elif a >= 224 and a <= 239:
			count = 2
			if a == 224: lower = 160
			if a == 237: upper = 159
		elif a >= 240 and a <= 244:
			count = 3
			if a == 240: lower = 144
			if a == 244: upper = 143
		else:
			return failure("Invalid UTF-8 at byte %d" % i)
		if i + count >= raw.size() or raw[i + 1] < lower or raw[i + 1] > upper:
			return failure("Invalid UTF-8 at byte %d" % i)
		for j in range(2, count + 1):
			if raw[i + j] < 128 or raw[i + j] > 191:
				return failure("Invalid UTF-8 at byte %d" % (i + j))
		i += count + 1
	return {"ok": true}

static func utf8(raw: PackedByteArray) -> Dictionary:
	var bytes := raw.get_string_from_ascii()
	if bytes.length() == raw.size() and _utf8_sequences.search(bytes) != null: return {"ok": true, "value": raw.get_string_from_utf8()}
	var checked := validate_utf8(raw)
	if not checked.ok: return checked
	if raw.has(0): return failure("Godot strings cannot represent NUL characters")
	return {"ok": true, "value": raw.get_string_from_utf8()}

static func parse_json(raw: PackedByteArray) -> Dictionary:
	if raw.size() > MAX_BYTES: return failure("JSON exceeds 64 MiB")
	var decoded := utf8(raw)
	if not decoded.ok: return decoded
	return StrictJSON.new().parse(String(decoded.value).trim_prefix(char(0xfeff)))

func decode(root_name: String, raw: PackedByteArray) -> Dictionary:
	var parsed := parse_json(raw)
	if not parsed.ok: return parsed
	# The strict parser already establishes finite JSON-only values and depth.
	return _validate_schema(root_name, parsed.value)

func _decode_framed_event(root_name: String, raw: PackedByteArray, profile: bool = false, trusted_operation: bool = false) -> Dictionary:
	# Internal SSE handoff: public framing validates each complete UTF-8 line;
	# explicit live producer trust relies on its canonical UTF-8 serialization.
	# Joining complete lines with LF preserves bytes. Keep exact JSON numbers,
	# size and NUL admission without scanning every UTF-8 byte twice. Body schema
	# admission changes only for the explicit current-producer operation option.
	if raw.size() > MAX_BYTES: return failure("JSON exceeds 64 MiB")
	if raw.has(0): return failure("Godot strings cannot represent NUL characters")
	var started := Time.get_ticks_usec() if profile else 0
	var text := raw.get_string_from_utf8().trim_prefix(char(0xfeff))
	var text_at := Time.get_ticks_usec() if profile else 0
	var parsed: Dictionary
	if trusted_operation and root_name == "PlayerOperation" and _current_server_contract:
		if _producer_json == null: _producer_json = ProducerJSON.new()
		parsed = _producer_json.parse(text,profile)
	else:
		parsed = StrictJSON.new().parse(text)
	if not parsed.ok: return parsed
	var admitted_at := Time.get_ticks_usec() if profile else 0
	var result := _validate_server_operation(parsed.value) if trusted_operation and root_name == "PlayerOperation" else _validate_schema(root_name, parsed.value)
	if profile:
		result.phases_ms = {"text_decode":(text_at-started)/1000.0,"json_parse":(admitted_at-text_at)/1000.0,"schema":(Time.get_ticks_usec()-admitted_at)/1000.0}
		for phase in parsed.get("parser_phases_ms",{}):result.phases_ms["json_"+phase]=parsed.parser_phases_ms[phase]
	return result

func _validate_server_operation(value: Variant) -> Dictionary:
	# The connected current producer owns typed nested values. Cursor order,
	# scope and exact raw bytes are checked by transport/journal, not rewalked.
	if not value is Dictionary: return failure("Server operation must be an object")
	if not _current_server_contract: return failure("Trusted operations require the current shipped server contract")
	if int(value.get("cursor",{}).get("sequence",0)) < 1: return failure("Operation sequence must be positive")
	var checked := check_identity(value.get("protocol",{}))
	return {"ok":true,"value":value} if checked.ok else checked

func decode_server(root_name: String, raw: PackedByteArray) -> Dictionary:
	# Current-server HTTP boundary. Parse once without recursive schema checks
	# or materializing defaults across shared choices, bodies and world columns.
	if not setup_error.is_empty(): return failure(setup_error)
	if not _current_server_contract: return failure("Trusted responses require the current shipped server contract")
	if raw.size() > MAX_BYTES: return failure("JSON exceeds 64 MiB")
	if raw.has(0): return failure("Godot strings cannot represent NUL characters")
	if _producer_json == null: _producer_json = ProducerJSON.new()
	var parsed:Dictionary=_producer_json.parse(raw.get_string_from_utf8().trim_prefix(char(0xfeff)))
	if not parsed.ok: return parsed
	if not parsed.value is Dictionary: return failure("Server response must be an object")
	if root_name in ["InitializationResponse","BootstrapResponse"]:
		var checked := check_identity(parsed.value.get("protocol",{}))
		if not checked.ok:return checked
	if root_name=="InitializationResponse" and int(parsed.value.get("cursor",{}).get("sequence",-1))!=0:
		return failure("Initialization sequence must be zero")
	return parsed

func decode_server_choices(raw: PackedByteArray) -> Dictionary:
	return decode_server("ChoicesResponse",raw)

func validate(root_name: String, value: Variant) -> Dictionary:
	var json_issue := _json_value(value, 0)
	if not json_issue.is_empty(): return failure(json_issue)
	return _validate_schema(root_name, value)

func _validate_schema(root_name: String, value: Variant) -> Dictionary:
	if not setup_error.is_empty(): return failure(setup_error)
	if not schema["$defs"].has(root_name): return failure("Unknown schema root: " + root_name)
	var issue := _check(schema["$defs"][root_name], value, "$", 0)
	if issue.is_empty() and schema["$defs"].has("PlayerChoices"):
		match root_name:
			"ChoicesResponse": issue = Choices.check_choices(value.choices)
			"PlayerChoices": issue = Choices.check_choices(value)
			"PreviewResponse": issue = Choices.check_preview(value.preview)
			"PlayerSelectionPreview": issue = Choices.check_preview(value)
	if issue.is_empty() and root_name == "InitializationResponse" and value.cursor.sequence != 0: issue = "Initialization sequence must be zero"
	if issue.is_empty() and root_name == "PlayerOperation" and value.cursor.sequence < 1: issue = "Operation sequence must be positive"
	return {"ok": true, "value": value} if issue.is_empty() else failure(root_name + ": " + issue)

func check_identity(value: Dictionary) -> Dictionary:
	# Identity defaults may be omitted by valid current envelopes. Compare the
	# three scalar contract fields once, without a schema/default tree walk.
	if value.get("protocol_version",1)!=identity.protocol_version or value.get("player_schema_version",16)!=identity.player_schema_version or value.get("schema_digest")!=identity.schema_digest:
		return failure("Protocol identity mismatch")
	return {"ok": true, "value": value}

static func _json_value(value: Variant, depth: int) -> String:
	if depth > 512: return "JSON nesting exceeds 512"
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING: return ""
		TYPE_FLOAT: return "" if is_finite(value) else "Non-finite JSON number"
		TYPE_ARRAY, TYPE_DICTIONARY:
			if value is Dictionary:
				for key in value:
					if typeof(key) not in [TYPE_STRING, TYPE_STRING_NAME]: return "Non-string JSON key"
			for child in value.values() if value is Dictionary else value:
				var problem := _json_value(child, depth + 1)
				if not problem.is_empty(): return problem
			return ""
	return "Non-JSON value"

func normalize(root_name: String, value: Variant) -> Variant:
	return _normalize(schema["$defs"][root_name], value)

func _ref(spec: Dictionary) -> Dictionary:
	return schema["$defs"][String(spec["$ref"]).get_slice("/", 2)] if spec.has("$ref") else spec

func _pattern(pattern: String, value: String) -> bool:
	if not _patterns.has(pattern):
		var expression := RegEx.new()
		expression.compile(pattern)
		_patterns[pattern] = expression
	return _patterns[pattern].search(value) != null

static func _type_matches(kind: String, value: Variant) -> bool:
	match kind:
		"null": return value == null
		"boolean": return typeof(value) == TYPE_BOOL
		"integer": return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value))
		"number": return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value))
		"string": return typeof(value) == TYPE_STRING
		"array": return typeof(value) == TYPE_ARRAY
		"object": return typeof(value) == TYPE_DICTIONARY
	return false

static func _equal(a: Variant, b: Variant) -> bool:
	# JSON equality must distinguish false/0, including nested uniqueItems.
	if typeof(a) != typeof(b):
		return typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT] and a == b
	if a is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not _equal(a[i], b[i]): return false
		return true
	if a is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _equal(a[key], b[key]): return false
		return true
	return a == b

func _branches(spec: Dictionary, value: Variant) -> Array:
	var branches: Array = spec.get("anyOf", spec.get("oneOf", []))
	if spec.has("discriminator") and value is Dictionary:
		var tag: Dictionary = spec.discriminator
		var selected: Variant = tag.get("mapping", {}).get(value.get(tag.propertyName))
		if selected != null: return [selected if selected is Dictionary else {"$ref": selected}]
	return branches

func _check(original: Variant, value: Variant, path: String, depth: int) -> String:
	if original is bool: return "" if original else path + " is forbidden"
	if depth > 512: return path + " exceeds JSON nesting limit"
	var spec := _ref(original)
	if spec.has("type") and not _type_matches(spec.type, value): return path + " must be " + spec.type
	if spec.has("const") and not _equal(value, spec.const): return path + " differs from const"
	if spec.has("enum"):
		var found := false
		for item in spec.enum:
			if _equal(item, value): found = true
		if not found: return path + " is outside enum"
	if spec.has("anyOf") or spec.has("oneOf"):
		var matches := 0
		for branch in _branches(spec, value):
			if _check(branch, value, path, depth + 1).is_empty():
				matches += 1
				if spec.has("anyOf"): break
		if matches != 1: return path + " does not match union"
	if typeof(value) in [TYPE_FLOAT, TYPE_INT]:
		if not is_finite(float(value)): return path + " is non-finite"
		for bound in ["minimum", "maximum", "exclusiveMinimum", "exclusiveMaximum"]:
			if not spec.has(bound): continue
			var n: Variant = spec[bound]
			if (bound == "minimum" and value < n) or (bound == "maximum" and value > n) or (bound == "exclusiveMinimum" and value <= n) or (bound == "exclusiveMaximum" and value >= n):
				return path + " violates " + bound
	if value is String:
		if value.length() < spec.get("minLength", 0) or value.length() > spec.get("maxLength", 9223372036854775807): return path + " has invalid length"
		if spec.has("pattern") and not _pattern(spec.pattern, value): return path + " violates pattern"
		if spec.get("format")=="base64url" and (value.length()%4!=0 or not _pattern("^[A-Za-z0-9_-]*={0,2}$",value)): return path+" is not base64url"
		if spec.get("format") == "uuid" and (value.length() != 36 or not _pattern("^(?i:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$", value)): return path + " is not UUID"
	if value is Array:
		if value.size() < spec.get("minItems", 0) or value.size() > spec.get("maxItems", 9223372036854775807): return path + " has invalid item count"
		var prefix: Array = spec.get("prefixItems", [])
		var items: Variant = spec.get("items", true)
		if prefix.is_empty() and items is bool and items and not spec.get("uniqueItems", false): return ""
		for i in value.size():
			var rule: Variant = prefix[i] if i < prefix.size() else items
			var issue := _check(rule, value[i], "", depth + 1)
			if not issue.is_empty(): return path + "/" + str(i) + issue
			if spec.get("uniqueItems", false):
				for j in i:
					if _equal(value[i], value[j]): return path + " has duplicate items"
	if value is Dictionary:
		for key in spec.get("required", []):
			if not value.has(key): return path + " missing " + key
		var props: Dictionary = spec.get("properties", {})
		var additional: Variant = spec.get("additionalProperties", true)
		# A union wrapper often adds no child rules. Its selected branch was
		# checked above; unconstrained children need no second recursive visit.
		if props.is_empty() and additional is bool and additional and not spec.has("propertyNames"): return ""
		for raw_key in value:
			if typeof(raw_key) not in [TYPE_STRING, TYPE_STRING_NAME]: return path + " has non-string key"
			var key := str(raw_key)
			if spec.has("propertyNames"):
				var key_issue := _check(spec.propertyNames, key, "", depth + 1)
				if not key_issue.is_empty(): return path + "/<key>" + key_issue
			var issue := _check(props.get(key, additional), value[raw_key], "", depth + 1)
			if not issue.is_empty(): return path + "/" + key + issue
	return ""

# Internal boundary: schema-admitted values or explicitly trusted server choices.
# Public normalize retains its ordinary branch validation.
func _normalize_admitted(root_name: String, value: Variant) -> Variant:
	return _normalize(schema["$defs"][root_name], value, true)

func _normalize(original: Variant, value: Variant, admitted: bool = false) -> Variant:
	if original is bool: return value.duplicate(true) if value is Array or value is Dictionary else value
	var spec := _ref(original)
	if spec.has("anyOf") or spec.has("oneOf"):
		var branches := _branches(spec, value)
		if admitted:
			if branches.size() == 1:
				return _normalize(branches[0], value, true)
			# Admission has already selected a valid nullable branch.
			if branches.size() == 2:
				for i in 2:
					if branches[i] is Dictionary and _ref(branches[i]).get("type") == "null":
						return null if value == null else _normalize(branches[1 - i], value, true)
		for branch in branches:
			if _check(branch, value, "$", 0).is_empty(): return _normalize(branch, value, admitted)
	if value is Dictionary:
		var result: Dictionary = {}
		var props: Dictionary = spec.get("properties", {})
		for raw_key in value:
			var key := str(raw_key)
			var normalized_key: String = key.to_lower() if spec.get("propertyNames", {}).get("format") == "uuid" else key
			result[normalized_key] = _normalize(props.get(key, spec.get("additionalProperties", true)), value[raw_key], admitted)
		for key in props:
			if not result.has(key) and props[key].has("default"): result[key] = _normalize(props[key], props[key].default)
		# dnd/core/item_types.py serializes this field only when nonempty.
		# State dictionaries use the Python public serialized form, not model internals.
		if spec.get("title") == "ItemPresentationState" and result.get("construction_suppressions", []).is_empty():
			result.erase("construction_suppressions")
		return result
	if value is Array:
		var result: Array = []
		var prefix: Array = spec.get("prefixItems", [])
		for i in value.size(): result.append(_normalize(prefix[i] if i < prefix.size() else spec.get("items", true), value[i], admitted))
		return result
	if value is String and spec.get("format") == "uuid": return value.to_lower()
	return int(value) if spec.get("type") == "integer" else value

func _vocabulary(spec: Variant) -> String:
	if spec is bool: return ""
	if not spec is Dictionary: return "Invalid schema node"
	const ALLOWED = ["$schema", "$id", "$defs", "$ref", "title", "description", "default", "type", "const", "enum", "anyOf", "oneOf", "discriminator", "properties", "required", "additionalProperties", "propertyNames", "items", "prefixItems", "minItems", "maxItems", "uniqueItems", "minimum", "maximum", "exclusiveMinimum", "exclusiveMaximum", "minLength", "maxLength", "pattern", "format"]
	for key in spec:
		if key not in ALLOWED: return "Unsupported schema keyword " + key
		if key == "$ref" and (not String(spec[key]).begins_with("#/$defs/") or not schema["$defs"].has(String(spec[key]).get_slice("/", 2))): return "Unresolved schema reference"
		if key == "format" and spec[key] not in ["uuid","base64url"]: return "Unsupported schema format"
		var children: Array = []
		if key in ["$defs", "properties"]: children = spec[key].values()
		elif key in ["anyOf", "oneOf", "prefixItems"]: children = spec[key]
		elif key in ["additionalProperties", "propertyNames", "items"]: children = [spec[key]]
		for child in children:
			var issue := _vocabulary(child)
			if not issue.is_empty(): return issue
	return ""
