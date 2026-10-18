extends RefCounted
## Exact JSON text spans. Godot's JSON and .tres writers shorten some doubles,
## so measured data is moved by copying the delivered number text verbatim:
## these helpers find value spans in UTF-8 bytes without re-serializing them.

static func _space(bytes: PackedByteArray, i: int) -> int:
    var size := bytes.size()
    while i < size:
        var c := bytes[i]
        if c != 32 and c != 10 and c != 13 and c != 9: break
        i += 1
    return i

static func _string_end(bytes: PackedByteArray, i: int) -> int:
    # i is the opening quote; returns the index after the closing quote.
    var j := i + 1
    while true:
        j = bytes.find(34, j)
        if j < 0: return bytes.size()
        var slashes := 0
        while bytes[j - 1 - slashes] == 92: slashes += 1
        if slashes % 2 == 0: return j + 1
        j += 1
    return bytes.size()

## Index after the JSON value that starts at (or after whitespace from) i.
static func value_end(bytes: PackedByteArray, i: int) -> int:
    i = _space(bytes, i)
    var c := bytes[i]
    if c == 34: return _string_end(bytes, i)
    if c != 123 and c != 91:
        while i < bytes.size():
            c = bytes[i]
            if c == 44 or c == 125 or c == 93 or c == 32 or c == 10 or c == 13 or c == 9: break
            i += 1
        return i
    var depth := 0
    var size := bytes.size()
    while i < size:
        c = bytes[i]
        if c == 34: i = _string_end(bytes, i); continue
        if c == 123 or c == 91: depth += 1
        elif c == 125 or c == 93:
            depth -= 1
            if depth == 0: return i + 1
        i += 1
    return i

## [[key, value_start, value_end], ...] of the object starting at i.
static func members(bytes: PackedByteArray, i: int = 0) -> Array:
    var result: Array = []
    i = _space(bytes, i)
    assert(bytes[i] == 123, "JSON object expected")
    i += 1
    while true:
        i = _space(bytes, i)
        if bytes[i] == 125: break
        var key_end := _string_end(bytes, i)
        var key: String = JSON.parse_string(bytes.slice(i, key_end).get_string_from_utf8())
        i = _space(bytes, key_end) + 1
        var start := _space(bytes, i)
        var end := value_end(bytes, start)
        result.append([key, start, end])
        i = _space(bytes, end)
        if bytes[i] == 44: i += 1
    return result

static func text(bytes: PackedByteArray, start: int, end: int) -> String:
    return bytes.slice(start, end).get_string_from_utf8()

## The member spans of an object as {key: text}.
static func member_texts(bytes: PackedByteArray, start: int = 0) -> Dictionary:
    var result := {}
    for member in members(bytes, start): result[member[0]] = text(bytes, member[1], member[2])
    return result

## An object written from {key: value text} in order, one member per line.
static func object(values: Dictionary, indent: String = "") -> String:
    var lines := PackedStringArray()
    for key in values: lines.append(indent + "  " + JSON.stringify(key) + ": " + values[key])
    return "{}" if lines.is_empty() else "{\n" + ",\n".join(lines) + "\n" + indent + "}"
