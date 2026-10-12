"""Regenerate binary64 oracle fixtures; Python is test tooling, never SDK runtime."""
import decimal
import json
import math
from pathlib import Path
import random
import struct


def generate():
    rows = {}

    def add(token):
        try:
            number = float(token)
            bits = struct.pack("<d", number).hex() if math.isfinite(number) else None
        except ValueError:
            bits = None
        rows[token] = {"token": token, "bits": bits}

    for token in [
        "0", "-0", "0.0", "-0.0", "0e999999999", "-0e-999999999",
        "2.5821854891016334", "2.582185489101634", "0.1", "1.2345678901234567",
        "9007199254740991", "9007199254740992", "9007199254740993",
        "1e308", "1e309", "1e9999999999", "-1e9999999999", "1e-9999999999",
        "1.7976931348623157e308", "1.7976931348623158e308", "1.7976931348623159e308",
        "2.2250738585072014e-308", "2.2250738585072011e-308", "4.9406564584124654e-324",
        "2.4703282292062327e-324", "2.4703282292062328e-324", "-1e-999",
    ]:
        add(token)
    rng = random.Random(0xDEC1A1)
    for _ in range(1600):
        number = struct.unpack("<d", rng.getrandbits(64).to_bytes(8,"little"))[0]
        if math.isfinite(number):
            add(repr(number))
            add(format(number,".25g"))
    # Exact halfway decimals and a distant final digit to either side exercise
    # ties-to-even and the sticky tail beyond the retained 1,400-digit prefix.
    with decimal.localcontext() as context:
        context.prec = 5000
        decimal_numbers = [0.0, math.ulp(0.0), 2*math.ulp(0.0),
                           math.nextafter(float.fromhex("0x1p-1022"),0),
                           float.fromhex("0x1p-1022"),
                           1.0, math.nextafter(1.0,math.inf), 2.0, 1e300]
        for exponent in [-1074,-1022,-900,-100,-1,0,1,52,100,900,1023]:
            value = math.ldexp(1.0,exponent)
            decimal_numbers.extend([value,math.nextafter(value,math.inf)])
        for value in decimal_numbers:
            high = math.nextafter(value,math.inf)
            midpoint = (decimal.Decimal(value)+decimal.Decimal(high))/2
            step = decimal.Decimal(10) ** (midpoint.adjusted()-1800)
            for number in [midpoint-step, midpoint, midpoint+step]:
                add(str(number)); add(str(-number))
        overflow = decimal.Decimal(2)**1024-decimal.Decimal(2)**970
        for value in [overflow-1,overflow,overflow+1]:
            add(str(value)); add(str(-value))
    for token in ["1."+"0"*10000, "1."+"0"*10000+"1",
                  "1"+"0"*10000+"e-10000", "0."+"0"*10000+"1e10001",
                  "0e"+"9"*10000, "-0e-"+"9"*10000]:
        add(token)
    for invalid in ["", "-", "+1", "01", "1.", ".1", "1e", "1e+", "1e-", "1.1.1", "1 2", "NaN", "Infinity", "--1"]:
        rows[invalid] = {"token":invalid,"bits":None}
    output = Path(__file__).with_name("sdk_decimal_cases.json")
    output.write_text(json.dumps(list(rows.values()),separators=(",",":"))+"\n")
    print(f"{len(rows)} exact binary64 cases -> {output}")


if __name__ == "__main__":
    generate()
