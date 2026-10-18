extends RefCounted
## Exact conversion between the old exported records (camelCase, ms, decimal
## colours, as JSON parses them: every number a float) and the typed ability
## entries (snake_case, seconds, tiles, hex colours). The converter moves a
## value into a typed field only when it converts back to exactly the same
## value; anything else stays in the entry's `unported` record as exported.
## The builder writes typed values back over that record.

## Units: ms <-> seconds, px/s <-> tiles/s (64 px per tile, rig.json TILE_W),
## decimal colour <-> "#rrggbb", or the value unchanged.
const TILE_PX := 64.0

static var _defaults: Dictionary = {}
## Paths where two numbers below 1e-12 differ in their last digit: Godot's
## .tres text writer keeps 16 digits for numbers in exponent form, so such a
## value in an old record's leftovers cannot come back exactly.
static var tiny: Array = []

static func deep(value: Variant) -> Variant:
    return value.duplicate(true) if value is Dictionary or value is Array else value

## Same value and same type all the way down (an int is not a float).
static func same(a: Variant, b: Variant) -> bool:
    if typeof(a) != typeof(b):return false
    if a is Dictionary:
        if a.size() != b.size():return false
        for key in a:
            if not b.has(key) or not same(a[key], b[key]):return false
        return true
    if a is Array:
        if a.size() != b.size():return false
        for i in a.size():
            if not same(a[i], b[i]):return false
        return true
    return a == b

## Differences between two records, as "path: why" lines (at most `limit`).
static func differences(a: Variant, b: Variant, path: String = "", out: Array = [], limit: int = 50) -> Array:
    if out.size() >= limit:return out
    if typeof(a) != typeof(b):
        out.append(path + ": " + type_string(typeof(a)) + " " + str(a).left(60) + " vs " + type_string(typeof(b)) + " " + str(b).left(60))
    elif a is Dictionary:
        for key in a:
            if not b.has(key):out.append(path + "/" + str(key) + ": only in first")
            else:differences(a[key], b[key], path + "/" + str(key), out, limit)
        for key in b:
            if not a.has(key):out.append(path + "/" + str(key) + ": only in second")
    elif a is Array:
        if a.size() != b.size():out.append(path + ": size " + str(a.size()) + " vs " + str(b.size()))
        else:
            for i in a.size():differences(a[i], b[i], path + "/" + str(i), out, limit)
    elif a is float and absf(a) < 1e-12 and absf(b) < 1e-12 and a != b:tiny.append(path)
    elif a != b:out.append(path + ": " + str(a).left(60) + " vs " + str(b).left(60))
    return out

## Dictionaries whose key order differs between two equal records.
static func order_differences(a: Variant, b: Variant, path: String = "", out: Array = []) -> Array:
    if a is Dictionary and b is Dictionary:
        var left: Array = a.keys().map(func(key): return str(key));var right: Array = b.keys().map(func(key): return str(key))
        if left.filter(func(key): return key in right) != right.filter(func(key): return key in left):out.append(path)
        for key in a:
            if b.has(key):order_differences(a[key], b[key], path + "/" + str(key), out)
    elif a is Array and b is Array and a.size() == b.size():
        for i in a.size():order_differences(a[i], b[i], path + "/" + str(i), out)
    return out

static func _parts(path: String) -> PackedStringArray:
    return path.split("/", false)

static func has_path(record: Variant, path: String) -> bool:
    var node: Variant = record
    for part in _parts(path):
        if node is Dictionary:
            if not node.has(part):return false
            node = node[part]
        elif node is Array:
            if not part.is_valid_int() or int(part) >= node.size():return false
            node = node[int(part)]
        else:return false
    return true

static func value_at(record: Variant, path: String, fallback: Variant = null) -> Variant:
    var node: Variant = record
    for part in _parts(path):
        if node is Dictionary and node.has(part):node = node[part]
        elif node is Array and part.is_valid_int() and int(part) < node.size():node = node[int(part)]
        else:return fallback
    return node

## Removes the value at `path` (its parents stay, possibly empty).
static func erase_path(record: Variant, path: String) -> void:
    var parts := _parts(path)
    var parent: Variant = value_at(record, "/".join(parts.slice(0, parts.size() - 1)))
    if parent is Dictionary:parent.erase(parts[parts.size() - 1])

## Sets `path`, creating dictionaries on the way (array items must exist).
static func put(record: Dictionary, path: String, value: Variant) -> void:
    var parts := _parts(path)
    var node: Variant = record
    for i in parts.size() - 1:
        var part: String = parts[i]
        if node is Array:node = node[int(part)];continue
        if not node.has(part) or not (node[part] is Dictionary or node[part] is Array):node[part] = {}
        node = node[part]
    if node is Array:node[int(parts[parts.size() - 1])] = value
    else:node[parts[parts.size() - 1]] = value

## Conversions from the old record's value (as JSON parsed it) to the typed
## field's value, and back.
static func to_typed(kind: String, value: Variant) -> Variant:
    match kind:
        "ms":return float(value) / 1000.0 if value is float else null
        "tiles":return float(value) / TILE_PX if value is float else null
        "hex":return "#%06x" % int(value) if value is float and value == floorf(value) and value >= 0 and value <= 0xffffff else null
        "colour":return Color.hex((int(value) << 8) | 0xff) if value is float and value == floorf(value) and value >= 0 and value <= 0xffffff else null
        "colours":
            if not value is Array:return null
            var colours := PackedColorArray()
            for item in value:
                var colour: Variant = to_typed("colour", item)
                if colour == null:return null
                colours.append(colour)
            return colours
        "hex_colours":
            if not value is Array or value.any(func(item): return not item is String):return null
            var colours := PackedColorArray()
            for item in value:colours.append(Color(item))
            return colours
        "strings":
            if not value is Array or value.any(func(item): return not item is String):return null
            return PackedStringArray(value)
        "ints", "float_ints":
            if not value is Array or value.any(func(item): return not (item is int or (item is float and item == floorf(item)))):return null
            return PackedInt32Array(value.map(func(item): return int(item)))
        "vec3":
            if not value is Array or value.size() != 3 or value.any(func(item): return not item is float):return null
            return Vector3(value[0], value[1], value[2])
        "vec2s":
            if not value is Array or value.any(func(item): return not item is Array or item.size() != 2 or not item[0] is float or not item[1] is float):return null
            var points := PackedVector2Array()
            for item in value:points.append(Vector2(item[0], item[1]))
            return points
        "int":return int(value) if value is float and value == floorf(value) and absf(value) < 1e15 else null
        "string":return value if value is String else null
        "float":return value if value is float else null
        "bool":return value if value is bool else null
    return value

static func to_legacy(kind: String, value: Variant) -> Variant:
    match kind:
        "ms":
            var ms: float = value * 1000.0
            return roundf(ms) if absf(ms - roundf(ms)) < 1e-7 else ms
        "tiles":return value * TILE_PX
        "hex":return float(value.substr(1).hex_to_int())
        "colour":return float(value.to_rgba32() >> 8)
        "colours":return Array(value).map(func(colour): return float(colour.to_rgba32() >> 8))
        "hex_colours":return Array(value).map(func(colour): return colour.to_html(false))
        "strings":return Array(value)
        "int":return float(value)
        "ints":return Array(value).map(func(item): return int(item))
        "float_ints":return Array(value).map(func(item): return float(item))
        "vec3":return [float(value.x), float(value.y), float(value.z)]
        "vec2s":return Array(value).map(func(point): return [float(point.x), float(point.y)])
    return value

static func default_of(target: Object, property: String) -> Variant:
    var script: Script = target.get_script()
    var key: String = script.resource_path + ":" + property
    if not _defaults.has(key):
        var fresh: Object = script.new()
        _defaults[key] = deep(fresh.get(property))
    return _defaults[key]

## Moves the value at `path` of `raw` into `target.property` when it converts
## back to exactly the same value and differs from the field's default (a
## default value stays in `raw`, so presence is kept exactly).
## With `always`, a default value moves too (the builder always writes it).
static func move(raw: Dictionary, path: String, target: Object, property: String, kind: String = "same", always: bool = false) -> bool:
    if not has_path(raw, path):return false
    var value: Variant = value_at(raw, path)
    var typed: Variant = to_typed(kind, value)
    if typed == null:return false
    var previous: Variant = target.get(property)
    target.set(property, typed)
    var stored: Variant = target.get(property)
    if typeof(stored) != typeof(previous) or not same(to_legacy(kind, stored), value) or (not always and same(stored, default_of(target, property))):
        target.set(property, previous);return false
    erase_path(raw, path)
    return true

## Writes `target.property` back at `path` unless it holds the field's
## default. An `always` field is written whenever the record lacks it (it is
## in the record only when the converter could not move it exactly).
static func emit(record: Dictionary, path: String, target: Object, property: String, kind: String = "same", always: bool = false) -> void:
    if target == null:return
    var value: Variant = target.get(property)
    if always and has_path(record, path):return
    if not always and same(value, default_of(target, property)):return
    put(record, path, to_legacy(kind, value))

## Moves a dictionary entry `key` -> `target.property[name]` (markers, roles).
static func move_item(raw: Dictionary, path: String, target: Object, property: String, name: String, kind: String = "same") -> bool:
    if not has_path(raw, path):return false
    var value: Variant = value_at(raw, path)
    var typed: Variant = to_typed(kind, value)
    if typed == null or not same(to_legacy(kind, typed), value):return false
    var holder: Dictionary = target.get(property)
    holder[name] = typed
    if not same(holder[name], typed):holder.erase(name);return false
    erase_path(raw, path)
    return true

static func emit_item(record: Dictionary, path: String, target: Object, property: String, name: String, kind: String = "same") -> void:
    if target == null:return
    var holder: Dictionary = target.get(property)
    if holder.has(name):put(record, path, to_legacy(kind, holder[name]))

## The key orders of `original` at every path where `built` has the same
## keys in another order: what the build must restore.
static func needed_order(original: Variant, built: Variant, path: String = "", out: Dictionary = {}) -> Dictionary:
    if original is Dictionary and built is Dictionary:
        var keys: Array = original.keys().map(func(key): return str(key))
        var common: Array = built.keys().map(func(key): return str(key)).filter(func(key): return key in keys)
        if keys.filter(func(key): return key in common) != common:out[path] = keys
        for key in original:
            if built.has(key):needed_order(original[key], built[key], path + "/" + str(key), out)
    elif original is Array and built is Array and original.size() == built.size():
        for i in original.size():needed_order(original[i], built[i], path + "/" + str(i), out)
    return out

## A path with array indices as "#" and, in a table keyed by ids, the id as "*".
static func pattern(path: String, table: bool) -> String:
    var parts := path.split("/", false)
    for i in parts.size():
        if parts[i].is_valid_int():parts[i] = "#"
    if table and not parts.is_empty():parts[0] = "*"
    return "/" + "/".join(parts) if not parts.is_empty() else ""

## Reorders the dictionaries of `value`: a path's own order when `order.exact`
## has it, else its pattern's order from `order.generic`; keys the order does
## not name keep their place after the named ones.
static func ordered(order: Dictionary, value: Variant, path: String = "", table: bool = false) -> Variant:
    if value is Dictionary:
        var known: Array = order.get("exact", {}).get(path, order.get("generic", {}).get(pattern(path, table), []))
        var keys: Array = value.keys()
        var place := {}
        for i in keys.size():
            var at: int = known.find(str(keys[i]))
            place[keys[i]] = (at if at >= 0 else known.size()) * 100000 + i
        keys.sort_custom(func(a, b): return place[a] < place[b])
        var result := {}
        for key in keys:result[key] = ordered(order, value[key], path + "/" + str(key), table)
        return result
    if value is Array:
        var items: Array = []
        for i in value.size():items.append(ordered(order, value[i], path + "/" + str(i), table))
        return items
    return value

## Merges key sequences per pattern, in first-seen order (a later sequence
## that disagrees leaves the earlier order; `needed_order` then keeps that
## path's own order as an exception).
static func merge_order(generic: Dictionary, sequences: Dictionary, table: bool) -> void:
    for path in sequences:
        var key: String = pattern(path, table)
        var known: Array = generic.get(key, [])
        var previous: int = -1
        for name in sequences[path]:
            var at: int = known.find(name)
            if at < 0:known.insert(previous + 1, name);previous += 1
            else:previous = maxi(previous, at)
        generic[key] = known

## Plain data as the old documents parsed: String keys and values (never
## StringName), arrays instead of packed arrays. Runtime records go through
## it before they are saved. Numbers keep their type.
static func plain(value: Variant) -> Variant:
    match typeof(value):
        TYPE_STRING_NAME:return String(value)
        TYPE_DICTIONARY:
            var result := {}
            for key in value:result[String(key) if key is StringName else key] = plain(value[key])
            return result
        TYPE_ARRAY:return value.map(func(item): return plain(item))
        TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
            return Array(value)
    return value

## JSON text whose numbers parse back to exactly the same doubles (Godot's
## own writer keeps 16 digits for numbers in exponent form). Measured files
## are written with it.
static func to_json(value: Variant) -> String:
    match typeof(value):
        TYPE_DICTIONARY:
            var parts := PackedStringArray()
            for key in value:parts.append(JSON.stringify(str(key)) + ":" + to_json(value[key]))
            return "{" + ",".join(parts) + "}"
        TYPE_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_STRING_ARRAY:
            var parts := PackedStringArray()
            for item in value:parts.append(to_json(item))
            return "[" + ",".join(parts) + "]"
        TYPE_FLOAT:return exact_number(value)
        TYPE_INT:return str(value)
    return JSON.stringify(value)

static func exact_number(value: float) -> String:
    var text := String.num_scientific(value)
    if text.to_float() == value:return text
    if "e" in text:
        var exponent := int(text.get_slice("e", 1))
        for digits in [16, 17, 18]:
            var mantissa := value / pow(10.0, exponent)
            for step in [0.0, 1.0, -1.0, 2.0, -2.0]:
                var candidate := String.num(mantissa + step * pow(10.0, -digits), digits) + "e" + str(exponent)
                if candidate.to_float() == value:return candidate
    return String.num(value, 30) if String.num(value, 30).to_float() == value else text
