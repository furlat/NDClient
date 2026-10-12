extends RefCounted
## Correctly rounded decimal -> IEEE-754 binary64 (nearest, ties to even).
## Godot String.to_float() can differ from correctly rounded input by one ULP.
## Big unsigned integers use little-endian 30-bit limbs, keeping every product
## below 2^60 and therefore inside GDScript's signed 64-bit integers.
const BASE = 1 << 30
const MASK = BASE - 1
const SAFE_INTEGER = 1 << 53
const SIGN = -9223372036854775807 - 1
const POW10 = [1,10,100,1000,10000,100000,1000000,10000000,100000000,1000000000]
const KEEP_DIGITS = 1400

static func _bad(message: String) -> Dictionary:
    return {"ok":false,"error":{"kind":"protocol","message":message,"retryable":false}}

static func _value(bits: int, negative: bool) -> Dictionary:
    var bytes = PackedByteArray()
    bytes.resize(8)
    bytes.encode_u64(0,bits | (SIGN if negative else 0))
    return {"ok":true,"value":bytes.decode_double(0)}

static func parse(token: String) -> Dictionary:
    var length = token.length()
    if length == 0: return _bad("Expected JSON number")
    var offset = 0
    var negative = token.unicode_at(0) == 45
    if negative: offset += 1
    if offset == length: return _bad("Expected JSON number")
    var digits = PackedByteArray()
    var significant = 0
    var fractional = 0
    var sticky = false
    var fraction = false
    var seen_dot = false
    var integral_digits = 0
    var first_integral = -1
    while offset < length:
        var c = token.unicode_at(offset)
        if c == 46 and not seen_dot and integral_digits > 0:
            seen_dot = true; fraction = true; offset += 1; continue
        if c < 48 or c > 57: break
        if fraction: fractional += 1
        else:
            integral_digits += 1
            if first_integral < 0: first_integral = c
            elif first_integral == 48: return _bad("Leading zero in JSON number")
        var digit = c-48
        if digit != 0 or significant > 0:
            significant += 1
            if digits.size() < KEEP_DIGITS: digits.append(digit)
            elif digit != 0: sticky = true
        offset += 1
    if integral_digits == 0 or (seen_dot and fractional == 0): return _bad("Incomplete JSON number")
    var exponent = 0
    if offset < length and token.unicode_at(offset) in [69,101]:
        offset += 1
        var exponent_negative = false
        if offset < length and token.unicode_at(offset) in [43,45]:
            exponent_negative = token.unicode_at(offset) == 45
            offset += 1
        var exponent_start = offset
        # Saturating beyond the entire token length cannot hide a cancellation
        # by decimal placement or leading/trailing zeros elsewhere in the token.
        var cap = length+4096
        while offset < length:
            var c = token.unicode_at(offset)
            if c < 48 or c > 57: break
            exponent = mini(cap,exponent*10+c-48)
            offset += 1
        if offset == exponent_start: return _bad("Missing JSON exponent")
        if exponent_negative: exponent = -exponent
    if offset != length: return _bad("Invalid JSON number")
    if significant == 0: return _value(0,negative)
    var magnitude = exponent-fractional+significant-1
    if magnitude > 308: return _bad("Non-finite JSON number")
    if magnitude < -324: return _value(0,negative)
    var scale = exponent-fractional+significant-digits.size()
    # Every finite rounding boundary is a dyadic rational with at most 1075
    # decimal fractional places and 309 integer places: < 1400 significant
    # digits. A discarded-tail interval therefore has no boundary inside it.
    # Keeping a nonzero sticky digit distinguishes its lower endpoint from any
    # positive tail, including values infinitesimally above an exact halfway.
    if sticky: digits.append(1); scale -= 1
    while digits[digits.size()-1] == 0:
        digits.resize(digits.size()-1); scale += 1
    # Both operands exactly representable: one IEEE division rounds only once.
    if digits.size() <= 16:
        var coefficient = 0
        for digit in digits: coefficient = coefficient*10+digit
        if coefficient <= SAFE_INTEGER:
            if scale <= 0 and scale >= -15:
                var denominator = 1
                for i in -scale: denominator *= 10
                var value = float(coefficient)/float(denominator)
                return {"ok":true,"value":-value if negative else value}
            if scale > 0 and scale <= 15:
                var value = coefficient
                var exact = true
                for i in scale:
                    if value > SAFE_INTEGER/10: exact = false; break
                    value *= 10
                if exact: return {"ok":true,"value":-float(value) if negative else float(value)}
    var numerator = PackedInt64Array([0])
    var chunk = 0
    var chunk_digits = 0
    for digit in digits:
        chunk = chunk*10+digit; chunk_digits += 1
        if chunk_digits == 9:
            numerator = _multiply_add(numerator,1000000000,chunk)
            chunk = 0; chunk_digits = 0
    if chunk_digits > 0: numerator = _multiply_add(numerator,POW10[chunk_digits],chunk)
    var denominator = PackedInt64Array([1])
    if scale >= 0: numerator = _times_power10(numerator,scale)
    else: denominator = _times_power10(denominator,-scale)
    var exponent2 = _bits(numerator)-_bits(denominator)
    var lower = _compare(numerator,_shift(denominator,exponent2)) if exponent2 >= 0 else _compare(_shift(numerator,-exponent2),denominator)
    if lower < 0: exponent2 -= 1
    var subnormal = exponent2 < -1022
    var shift = 1074 if subnormal else 52-exponent2
    if shift >= 0: numerator = _shift(numerator,shift)
    else: denominator = _shift(denominator,-shift)
    var divided = _divide(numerator,denominator)
    var mantissa: int = divided.quotient
    var halfway = _compare(_shift(divided.remainder,1),denominator)
    if halfway > 0 or (halfway == 0 and (mantissa & 1) != 0): mantissa += 1
    if subnormal: return _value(mantissa,negative)
    if mantissa == SAFE_INTEGER:
        mantissa >>= 1; exponent2 += 1
    if exponent2 > 1023: return _bad("Non-finite JSON number")
    return _value(((exponent2+1023)<<52) | (mantissa-(1<<52)),negative)

static func _multiply_add(value: PackedInt64Array, multiplier: int, addend: int) -> PackedInt64Array:
    var carry = addend
    for i in value.size():
        var product = value[i]*multiplier+carry
        value[i] = product & MASK
        carry = product >> 30
    if carry != 0: value.append(carry)
    return value

static func _times_power10(value: PackedInt64Array, exponent: int) -> PackedInt64Array:
    while exponent >= 9:
        value = _multiply_add(value,1000000000,0)
        exponent -= 9
    return _multiply_add(value,POW10[exponent],0) if exponent != 0 else value

static func _bits(value: PackedInt64Array) -> int:
    var result = (value.size()-1)*30
    var high = value[value.size()-1]
    while high > 0: result += 1; high >>= 1
    return result

static func _compare(a: PackedInt64Array, b: PackedInt64Array) -> int:
    if a.size() != b.size(): return -1 if a.size()<b.size() else 1
    for i in range(a.size()-1,-1,-1):
        if a[i] != b[i]: return -1 if a[i]<b[i] else 1
    return 0

static func _shift(value: PackedInt64Array, bits: int) -> PackedInt64Array:
    if bits == 0 or (value.size()==1 and value[0]==0): return value
    var words = bits/30
    var remaining = bits%30
    var result = PackedInt64Array()
    result.resize(value.size()+words+1)
    var carry = 0
    for i in value.size():
        var limb = (value[i]<<remaining) | carry
        result[i+words] = limb & MASK
        carry = limb >> 30
    if carry != 0: result[result.size()-1] = carry
    else: result.resize(result.size()-1)
    return result

static func _right_one(value: PackedInt64Array) -> PackedInt64Array:
    var carry = 0
    for i in range(value.size()-1,-1,-1):
        var limb = value[i]
        value[i] = (limb>>1) | carry
        carry = (limb & 1)<<29
    if value.size()>1 and value[value.size()-1]==0: value.resize(value.size()-1)
    return value

static func _subtract(a: PackedInt64Array, b: PackedInt64Array) -> PackedInt64Array:
    var borrow = 0
    for i in a.size():
        var value = a[i]-(b[i] if i<b.size() else 0)-borrow
        borrow = 1 if value < 0 else 0
        a[i] = value+(BASE if value<0 else 0)
    while a.size()>1 and a[a.size()-1]==0: a.resize(a.size()-1)
    return a

static func _divide(numerator: PackedInt64Array, denominator: PackedInt64Array) -> Dictionary:
    # Scaling above bounds the quotient to 53 bits, even for subnormals.
    var shift = _bits(numerator)-_bits(denominator)
    if shift < 0: return {"quotient":0,"remainder":numerator}
    var divisor = _shift(denominator,shift).duplicate()
    var quotient = 0
    for i in range(shift,-1,-1):
        if _compare(numerator,divisor) >= 0:
            numerator = _subtract(numerator,divisor)
            quotient |= 1<<i
        divisor = _right_one(divisor)
    return {"quotient":quotient,"remainder":numerator}
