extends SceneTree
const DecimalFloat = preload("res://sdk/decimal_float.gd")

func _bits(value: float) -> String:
    var bytes = PackedByteArray()
    bytes.resize(8); bytes.encode_double(0,value)
    return bytes.hex_encode()

func _init() -> void:
    var started = Time.get_ticks_msec()
    var fixture: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/sdk_decimal_cases.json"))
    var failures: Array = []
    var checks = 0
    for row in fixture:
        checks += 1
        var result = DecimalFloat.parse(row.token)
        if row.get("bits") == null:
            if result.ok: failures.append({"token":row.token.substr(0,100),"expected":"failure","actual":_bits(result.value)})
        elif not result.ok or _bits(result.value) != row.bits:
            failures.append({"token":row.token.substr(0,100),"expected":row.bits,"actual":_bits(result.value) if result.ok else result.error.message})
    # Long legal tokens remain linear scans with bounded bigint allocation.
    for row in [{"token":"1"+"0".repeat(1000000)+"e-1000000","bits":"000000000000f03f"},
            {"token":"-0e"+"9".repeat(1000000),"bits":"0000000000000080"}]:
        checks += 1
        var result = DecimalFloat.parse(row.token)
        if not result.ok or _bits(result.value) != row.bits: failures.append("Million-digit token")
    print(JSON.stringify({"checks":checks,"failures":failures,"elapsed_ms":Time.get_ticks_msec()-started}))
    quit(0 if failures.is_empty() else 1)
