"""Generate admission cases using the installed current Python player SDK.

Run with dnd_engine/sdk/python/src on PYTHONPATH and its Python environment.
The expected acceptance and accepted values come from that SDK, not Godot.
These are schema/transport boundary cases, not simulated gameplay evidence.
"""
import argparse
import base64
from collections import Counter
from copy import deepcopy
from importlib.resources import files
import json
import math
from pathlib import Path

from dnd_player import transport as sdk


SCHEMA = json.loads(files("dnd_player").joinpath("player-api-v1.schema.json").read_bytes())
DEFS = SCHEMA["$defs"]
UUID = "00000000-0000-4000-8000-000000000001"


def resolved(spec):
    return DEFS[spec["$ref"].rsplit("/", 1)[1]] if "$ref" in spec else spec


def example(spec):
    """A candidate input; the independent SDK must validate every baseline."""
    if isinstance(spec, bool):
        return None
    spec = resolved(spec)
    if "const" in spec:
        return deepcopy(spec["const"])
    if "default" in spec:
        return deepcopy(spec["default"])
    if "enum" in spec:
        return deepcopy(spec["enum"][0])
    if "anyOf" in spec or "oneOf" in spec:
        return example(spec.get("anyOf", spec.get("oneOf"))[0])
    kind = spec.get("type")
    if kind == "object":
        props = spec.get("properties", {})
        return {key: example(rule) for key, rule in props.items()
                if key in spec.get("required", ()) or "default" in rule or "const" in rule}
    if kind == "array":
        prefix = spec.get("prefixItems", [])
        count = max(spec.get("minItems", 0), len(prefix))
        return [example(prefix[i] if i < len(prefix) else spec.get("items", True)) for i in range(count)]
    if kind == "string":
        if spec.get("format") == "uuid":
            return UUID
        if spec.get("pattern") == "^[0-9a-f]{64}$":
            return "a" * 64
        if "pattern" in spec:
            return "content.example"
        return "x" * max(1, spec.get("minLength", 0))
    if kind in ("integer", "number"):
        lower = spec.get("minimum", 0)
        if "exclusiveMinimum" in spec:
            lower = max(lower, math.floor(spec["exclusiveMinimum"]) + 1)
        upper = spec.get("maximum", lower)
        if "exclusiveMaximum" in spec:
            upper = min(upper, math.ceil(spec["exclusiveMaximum"]) - 1)
        return min(lower, upper)
    if kind == "boolean":
        return False
    return None


def variations(spec):
    """Finite mutations for the validation vocabulary actually shipped today."""
    if isinstance(spec, bool):
        return
    spec = resolved(spec)
    kind = spec.get("type")
    if kind:
        yield "wrong-type", [] if kind != "array" else {}
    if "const" in spec:
        yield "const", "not-the-declared-constant"
    if "enum" in spec:
        yield "enum", "not-an-enumerated-value"
    if "anyOf" in spec or "oneOf" in spec:
        yield "union-wrong-type", {"undeclared": True}
        for i, branch in enumerate(spec.get("anyOf", spec.get("oneOf"))):
            yield "union-branch-" + str(i), example(branch)
            nested = resolved(branch)
            if "anyOf" in nested or "oneOf" in nested:
                for label, value in variations(nested):
                    yield "union-branch-" + str(i) + "/" + label, value
    if kind in ("integer", "number"):
        yield "number-bool", True
        yield "number-string", "1"
        if kind == "integer":
            yield "integer-fraction", 0.5
            yield "integer-real-token", float(example(spec))
        for bound in ("minimum", "maximum", "exclusiveMinimum", "exclusiveMaximum"):
            if bound in spec:
                value = spec[bound]
                yield bound + "-at", value
                yield bound + "-below", value - 1
                yield bound + "-above", value + 1
    if kind == "string":
        if "minLength" in spec:
            yield "minLength-at", "x" * spec["minLength"]
            yield "minLength-below", "x" * max(0, spec["minLength"] - 1)
        if "maxLength" in spec:
            yield "maxLength-at", "x" * spec["maxLength"]
            yield "maxLength-above", "x" * (spec["maxLength"] + 1)
        if "pattern" in spec:
            yield "pattern-invalid", "# invalid"
        if spec.get("format") == "uuid":
            for label, value in (("uppercase", UUID.upper()), ("no-hyphens", UUID.replace("-", "")),
                                 ("trailing-newline", UUID + "\n"), ("invalid-hex", "g" + UUID[1:])):
                yield "uuid-" + label, value
    if kind == "array":
        base = example(spec)
        if "minItems" in spec:
            yield "minItems-below", base[:max(0, spec["minItems"] - 1)]
        if "maxItems" in spec and spec["maxItems"] <= 1024:
            yield "maxItems-above", [None] * (spec["maxItems"] + 1)
        if spec.get("uniqueItems"):
            item = example(spec.get("items", True))
            yield "uniqueItems-duplicate", [item, deepcopy(item)]
        prefix = spec.get("prefixItems", [])
        for i, rule in enumerate(prefix):
            changed = deepcopy(base)
            changed[i] = True if resolved(rule).get("type") in ("integer", "number") else {"bad": True}
            yield "prefixItems-" + str(i), changed
    if kind == "object":
        base = example(spec)
        if spec.get("additionalProperties") is False:
            yield "additionalProperties", {**base, "__unexpected__": 1}
        if "propertyNames" in spec:
            value = example(spec.get("additionalProperties", True))
            yield "propertyNames-invalid", {"not-a-valid-property-name": value}


def build_cases():
    cases = []
    def add(label, root, value=None, raw=None, mode="decode", native_rejection=None):
        if raw is None:
            raw = json.dumps(value, ensure_ascii=True, separators=(",", ":")).encode()
        try:
            admitted = sdk.decode(root, raw)
            if mode == "identity":
                sdk.check_protocol(admitted)
            accepted, error = True, None
        except (sdk.ProtocolError, ValueError, UnicodeError) as failure:
            accepted, admitted, error = False, None, str(failure)
        case = {"label": label, "root": root, "mode": mode,
                "raw_base64": base64.b64encode(raw).decode(), "python_ok": accepted,
                "expected_ok": accepted if native_rejection is None else False}
        if native_rejection is not None:
            if not accepted:
                raise AssertionError("Documented native limitation no longer differs from Python: " + label)
            case["native_rejection"] = native_rejection
        elif accepted:
            case["expected_value"] = admitted
        else:
            case["python_error"] = error
        cases.append(case)
        return accepted

    for root, spec in DEFS.items():
        baseline = example(spec)
        # The SDK root postconditions intentionally go beyond JSON Schema.
        if root == "InitializationResponse":
            baseline["cursor"]["sequence"] = 0
        if root == "PlayerOperation":
            baseline["cursor"]["sequence"] = 1
        if root in ("PlayerSelectionPreview", "PreviewResponse"):
            preview = baseline if root == "PlayerSelectionPreview" else baseline["preview"]
            preview['target_sets'] = [[]]
            preview['next_target_set'] = 0
        if not add(root + "/baseline", root, baseline):
            raise AssertionError("Oracle baseline is not a valid example: " + root + ": " + cases[-1]["python_error"])
        for name, value in variations(spec):
            add(root + "/" + name, root, value)
        if spec.get("type") != "object":
            continue
        for key in spec.get("required", []):
            value = deepcopy(baseline)
            del value[key]
            add(root + "/required/" + key, root, value)
        for key, rule in spec.get("properties", {}).items():
            for name, replacement in variations(rule):
                value = deepcopy(baseline)
                value[key] = replacement
                add(root + "/" + key + "/" + name, root, value)

    initial = example(DEFS["InitializationResponse"])
    initial["cursor"]["sequence"] = 7
    add("initialization/nonzero-sequence", "InitializationResponse", initial)
    operation = example(DEFS["PlayerOperation"])
    operation["cursor"]["sequence"] = 0
    add("operation/zero-sequence", "PlayerOperation", operation)
    add("identity/exact", "ProtocolIdentity", sdk.IDENTITY, mode="identity")
    for key in sdk.IDENTITY:
        value = deepcopy(sdk.IDENTITY)
        del value[key]
        add("identity/missing-" + key, "ProtocolIdentity", value, mode="identity")
    changed = {**sdk.IDENTITY, "schema_digest": "f" * 64}
    add("identity/wrong-digest", "ProtocolIdentity", changed, mode="identity")

    boundary = example(DEFS["PlayerWorld"])
    boundary["battlefield_name"] = "é😀\n"
    raw = json.dumps(boundary, ensure_ascii=False).encode()
    add("JSON/Unicode", "PlayerWorld", raw=raw)
    add("JSON/UTF8-BOM", "PlayerWorld", raw=b"\xef\xbb\xbf" + raw)
    add("JSON/escaped-control-characters", "PlayerWorld",
        {**boundary, "battlefield_name": "".join(chr(code) for code in range(1, 32))})
    add("JSON/escaped-NUL", "PlayerWorld", {**boundary, "battlefield_name": "before\0after"},
        native_rejection="Godot String cannot preserve NUL. Admission explicitly rejects it instead of replacing or truncating data.")
    for label, malformed in (("trailing-comma", raw[:-1] + b",}"),
                             ("trailing-token", raw + b" null"),
                             ("UTF8-surrogate", raw.replace("é".encode(), b"\xed\xa0\x80")),
                             ("UTF8-truncated", raw.replace("é".encode(), b"\xc3")),
                             ("UTF8-overlong", raw.replace("é".encode(), b"\xc0\xaf")),
                             ("unescaped-NUL", raw.replace("é".encode(), b"\0")),
                             ("unescaped-newline", raw.replace(b"\\n", b"\n"))):
        add("JSON/" + label, "PlayerWorld", raw=malformed)
    cursor = example(DEFS["PlayerCursor"])
    cursor_raw = json.dumps(cursor, separators=(",", ":")).encode()
    for token in (b"01", b"+1", b".5", b"1.", b"1e", b"NaN", b"Infinity", b"1e999", b"1e0"):
        add("JSON/number/" + token.decode(), "PlayerCursor", raw=cursor_raw.replace(b'"sequence":0', b'"sequence":' + token))
    # Python's JSON parser alone accepts this, but the current SDK's compiled
    # schema boundary rejects non-scalar Unicode during validation.
    lone = json.dumps({**boundary, "battlefield_name": "\ud800"}).encode()
    add("JSON/lone-surrogate", "PlayerWorld", raw=lone)
    return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    cases = build_cases()
    report = {"kind": "protocol_parity_manifest", "schema_digest": sdk.IDENTITY["schema_digest"],
              "definitions": len(DEFS), "cases": len(cases),
              "oracle": "current dnd_player.transport.decode/check_protocol",
              "expected": dict(Counter("accepted" if row["python_ok"] else "rejected" for row in cases)),
              "native_rejections": [{"label": row["label"], "reason": row["native_rejection"]}
                                    for row in cases if "native_rejection" in row]}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8") as stream:
        for row in (report, *cases):
            stream.write(json.dumps(row, ensure_ascii=True, separators=(",", ":")) + "\n")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
