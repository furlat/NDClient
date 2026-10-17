extends RefCounted
## Strict JSON syntax, preserving integer tokens (Godot JSON parses all as float).
const DecimalFloat = preload("res://sdk/decimal_float.gd")
## Native exact path. A text that _grammar matches whole is strict JSON nested
## at most NATIVE_DEPTH containers deep, whose strings hold no control character
## and no \u escape, whose integers have at most 18 digits and whose other
## numbers are plain decimals (no exponent). For exactly these texts Godot's
## Variant parser (str_to_var) builds the value the character parser below
## builds: equal Strings, int and float tokens, key order, a duplicate key
## keeping its last value. Its decimals use String.to_float, which can be one
## ULP from correct rounding, so every decimal token is first compared bit for
## bit with DecimalFloat. Any other text, or any difference, parses below.
const NATIVE_DEPTH = 32
static var _grammar: RegEx = _native_grammar()
static var _decimals := RegEx.create_from_string("\"(?:[^\"\\\\]++|\\\\.)*+\"(*SKIP)(*F)|-?[0-9]++\\.[0-9]++")
var source := ""
var offset := 0
var issue := ""

func parse(text: String) -> Dictionary:
	var native := _native(text)
	if not native.is_empty(): return native
	source = text
	offset = 0
	issue = ""
	var value: Variant = _value(0)
	_space()
	if issue.is_empty() and offset != source.length(): issue = "Trailing JSON input"
	if not issue.is_empty(): return {"ok": false, "error": {"kind": "protocol", "message": "%s at character %d" % [issue, offset], "retryable": false}}
	return {"ok": true, "value": value}

static func _native(text: String) -> Dictionary:
	if _grammar.search(text) == null: return {}
	for found in _decimals.search_all(text):
		var token := found.get_string()
		var exact := DecimalFloat.parse(token)
		if not exact.ok or PackedFloat64Array([exact.value]).to_byte_array() != PackedFloat64Array([str_to_var(token)]).to_byte_array(): return {}
	return {"ok": true, "value": str_to_var(text)}

static func _native_grammar() -> RegEx:
	const SPACE = "[ \\t\\n\\r]*+"
	const STRING = "\"(?:[^\"\\\\\\x00-\\x1f]++|\\\\[\"\\\\/bfnrt])*+\""
	const NUMBER = "-?+(?:(?:0|[1-9][0-9]*+)\\.[0-9]++|0|[1-9][0-9]{0,17}+)"
	# Level n: a scalar, or a container whose members are at most level n-1.
	var levels := "(?<v0>(?>" + STRING + "|" + NUMBER + "|true|false|null))"
	for n in range(1, NATIVE_DEPTH + 1):
		var inner := "(?&v%d)" % (n - 1)
		var member := STRING + SPACE + ":" + SPACE + inner + SPACE
		var element := inner + SPACE
		levels += "(?<v%d>(?>(?&v0)|\\{%s(?:%s(?:,%s%s)*+)?+\\}|\\[%s(?:%s(?:,%s%s)*+)?+\\]))" % [n, SPACE, member, SPACE, member, SPACE, element, SPACE, element]
	return RegEx.create_from_string("(?(DEFINE)" + levels + ")\\A" + SPACE + "(?&v%d)" % NATIVE_DEPTH + SPACE + "\\z")

func _space() -> void:
	while offset < source.length() and source.unicode_at(offset) in [9, 10, 13, 32]: offset += 1

func _take(token: String) -> bool:
	if source.substr(offset, token.length()) != token: return false
	offset += token.length()
	return true

func _value(depth: int) -> Variant:
	_space()
	if depth > 512:
		issue = "JSON nesting exceeds 512"
		return null
	if offset >= source.length():
		issue = "Expected JSON value"
		return null
	match source[offset]:
		'"': return _string()
		"{":
			offset += 1
			var result: Dictionary = {}
			_space()
			if _take("}"): return result
			while issue.is_empty():
				_space()
				if offset >= source.length() or source[offset] != '"':
					issue = "Expected object key"
					break
				var key := _string()
				_space()
				if not _take(":"):
					issue = "Expected colon"
					break
				result[key] = _value(depth + 1)
				_space()
				if _take("}"): return result
				if not _take(","):
					issue = "Expected object separator"
					break
			return result
		"[":
			offset += 1
			var result: Array = []
			_space()
			if _take("]"): return result
			while issue.is_empty():
				result.append(_value(depth + 1))
				_space()
				if _take("]"): return result
				if not _take(","):
					issue = "Expected array separator"
					break
			return result
	if _take("true"): return true
	if _take("false"): return false
	if _take("null"): return null
	return _number()

func _hex4() -> int:
	if offset + 4 > source.length():
		issue = "Incomplete Unicode escape"
		return 0
	var value := 0
	for i in 4:
		var digit := "0123456789abcdef".find(source[offset + i].to_lower())
		if digit < 0:
			issue = "Invalid Unicode escape"
			return 0
		value = value * 16 + digit
	offset += 4
	return value

func _string() -> String:
	offset += 1
	var result := ""
	var start := offset
	while offset < source.length():
		var c := source.unicode_at(offset)
		if c == 34:
			result += source.substr(start, offset - start)
			offset += 1
			return result
		if c < 32:
			issue = "Unescaped control character"
			return ""
		if c != 92:
			offset += 1
			continue
		result += source.substr(start, offset - start)
		offset += 1
		if offset >= source.length(): break
		var escape := source[offset]
		offset += 1
		match escape:
			'"', "\\", "/": result += escape
			"b": result += char(8)
			"f": result += char(12)
			"n": result += "\n"
			"r": result += "\r"
			"t": result += "\t"
			"u":
				var code := _hex4()
				if not issue.is_empty(): return ""
				if code == 0:
					issue = "Godot strings cannot represent NUL characters"
					return ""
				if code >= 0xd800 and code <= 0xdbff:
					if not _take("\\u"):
						issue = "Unpaired Unicode surrogate"
						return ""
					var low := _hex4()
					if not issue.is_empty() or low < 0xdc00 or low > 0xdfff:
						issue = "Invalid Unicode surrogate pair"
						return ""
					code = 0x10000 + (code - 0xd800) * 1024 + low - 0xdc00
				elif code >= 0xdc00 and code <= 0xdfff:
					issue = "Unpaired Unicode surrogate"
					return ""
				result += char(code)
			_:
				issue = "Invalid string escape"
				return ""
		start = offset
	issue = "Unterminated string"
	return ""

func _digit() -> bool:
	return offset < source.length() and source.unicode_at(offset) >= 48 and source.unicode_at(offset) <= 57

func _number() -> Variant:
	var start := offset
	_take("-")
	if _take("0"):
		pass
	elif _digit() and source[offset] != "0":
		while _digit(): offset += 1
	else:
		issue = "Expected JSON number"
		return null
	var integral := true
	if _take("."):
		integral = false
		if not _digit(): issue = "Missing fraction"
		while _digit(): offset += 1
	if _take("e") or _take("E"):
		integral = false
		if not _take("+"): _take("-")
		if not _digit(): issue = "Missing exponent"
		while _digit(): offset += 1
	var token := source.substr(start, offset - start)
	# Integers outside the portable wire range are rejected by their schema.
	# Parse huge tokens as float instead of overflowing Godot's signed int64.
	if integral and token.trim_prefix("-").length() < 19: return token.to_int()
	var converted := DecimalFloat.parse(token)
	if not converted.ok:
		issue = converted.error.message
		return null
	return converted.value
