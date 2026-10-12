extends RefCounted
# Byte framing keeps a UTF-8 character split across network chunks intact.
const Protocol = preload("res://sdk/protocol.gd")
const MAX_BYTES = 64 * 1024 * 1024
var protocol: RefCounted
var limit: int
var buffer = PackedByteArray()
var scan = 0
var skip_lf = false
var first_line = true
var data: Array[PackedByteArray] = []
var record_bytes = 0
var event = "message"
var event_id: Variant = null
var failure: Dictionary = {}

func _init(admission: RefCounted = null, byte_limit: int = MAX_BYTES) -> void:
    protocol = admission if admission != null else Protocol.new()
    limit = byte_limit

func _bad(message: String, emitted: Array = []) -> Dictionary:
    failure = {"ok":false,"error":{"kind":"protocol","message":message,"retryable":false},"records":emitted}
    return failure

func feed(chunk: PackedByteArray) -> Dictionary:
    if not failure.is_empty(): return failure
    var incoming = chunk
    if skip_lf and not incoming.is_empty():
        if incoming[0] == 10: incoming = incoming.slice(1)
        skip_lf = false
    buffer.append_array(incoming)
    var emitted: Array = []
    var consumed = 0
    while true:
        var cr = buffer.find(13, scan)
        var lf = buffer.find(10, scan)
        var end = lf if cr < 0 else (cr if lf < 0 else mini(cr, lf))
        if end < 0:
            scan = buffer.size()
            if buffer.size() - consumed + record_bytes > limit + 1024:
                return _bad("Oversized unfinished SSE record",emitted)
            break
        var width = 1
        if buffer[end] == 13:
            if end + 1 == buffer.size(): skip_lf = true
            elif buffer[end + 1] == 10: width = 2
        var line = buffer.slice(consumed, end)
        consumed = end + width
        scan = consumed
        if first_line:
            if line.size() >= 3 and line.slice(0,3) == PackedByteArray([239,187,191]): line = line.slice(3)
            first_line = false
        var decoded: Dictionary = protocol.validate_utf8(line)
        if not decoded.ok: return _bad("Invalid SSE UTF-8",emitted)
        if line.is_empty():
            if not data.is_empty():
                var raw = PackedByteArray()
                for i in range(data.size()):
                    if i > 0: raw.append(10)
                    raw.append_array(data[i])
                if raw.size() > limit: return _bad("SSE data exceeds record limit",emitted)
                emitted.append({"event":event,"id":event_id,"raw":raw})
            data.clear(); record_bytes = 0; event = "message"; event_id = null
            continue
        record_bytes += line.size() + width
        if record_bytes > limit + 1024: return _bad("Oversized SSE record",emitted)
        var colon = line.find(58)
        var field = line if colon < 0 else line.slice(0,colon)
        var value = PackedByteArray() if colon < 0 else line.slice(colon+1)
        if not value.is_empty() and value[0] == 32: value = value.slice(1)
        if field.has(0): continue
        match field.get_string_from_ascii():
            "data": data.append(value)
            "event":
                if value.has(0): return _bad("Godot strings cannot represent NUL in SSE event names",emitted)
                event = value.get_string_from_utf8()
            "id":
                if not value.has(0): event_id = value.get_string_from_utf8()
    if consumed > 0:
        buffer = buffer.slice(consumed)
        scan -= consumed
    return {"ok":true,"value":emitted}

func finish() -> Dictionary:
    # A network EOF never completes a partially framed event.
    buffer.clear(); data.clear(); scan = 0; record_bytes = 0
    return failure if not failure.is_empty() else {"ok":true,"value":[]}
