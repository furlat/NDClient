"""Compare atlas-lit and sprite-lit runs of native_atlas_publication_checks.

Run the fixture twice on the same journal, without and with --lit-sprites, then:
  uv run --no-project --with pillow --with numpy python -I tools/compare_lit_captures.py
Receipts (clocks, sources, receivers) must match exactly. Pixels may differ by
at most --tolerance bytes per channel; every difference is counted and an
amplified difference image is written next to the captures for inspection.
With --pngs A B, compare same-named PNGs of two capture folders instead
(e.g. two runs of tests/studio_replay_native_checks.gd).
"""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image


def difference(a_path, b_path, tolerance, diff_path):
    a = np.asarray(Image.open(a_path).convert("RGBA")).astype(np.int16)
    b = np.asarray(Image.open(b_path).convert("RGBA")).astype(np.int16)
    if a.shape != b.shape:
        return {"shape_mismatch": [list(a.shape), list(b.shape)], "maximum_byte_error": 255, "different_pixels": -1, "over_tolerance": -1, "over_tolerance_box": []}
    delta = np.abs(a - b).max(axis=2)
    worst = int(delta.max())
    if worst:
        Image.fromarray(np.clip(delta * (255 // worst), 0, 255).astype(np.uint8)).save(diff_path)
    ys, xs = np.nonzero(delta > tolerance)
    return {"maximum_byte_error": worst, "different_pixels": int((delta > 0).sum()), "over_tolerance": int(len(ys)),
            "over_tolerance_box": [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())] if len(ys) else []}


def compare_folders(first, second, tolerance):
    out = second / "diff"
    out.mkdir(exist_ok=True)
    cases = []
    for a_path in sorted(first.glob("*.png")):
        b_path = second / a_path.name
        if not b_path.exists():
            cases.append({"label": a_path.stem, "missing": True})
            continue
        case = difference(a_path, b_path, tolerance, out / a_path.name)
        case["label"] = a_path.stem
        cases.append(case)
    passed = bool(cases) and all(not c.get("missing") and c["over_tolerance"] == 0 for c in cases)
    for c in cases:
        print(json.dumps(c))
    print(json.dumps({"passed": passed, "captures": len(cases)}))
    raise SystemExit(0 if passed else 1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--folder", default=".captures/atlas-publication")
    parser.add_argument("--tolerance", type=int, default=1)
    parser.add_argument("--pngs", nargs=2, type=Path)
    args = parser.parse_args()
    if args.pngs:
        return compare_folders(args.pngs[0], args.pngs[1], args.tolerance)
    folder = args.root / args.folder
    reference = json.loads((folder / "current/report.json").read_text())
    lit = json.loads((folder / "lit/report.json").read_text())
    rows = {row["label"]: row for row in reference["captures"]}
    (folder / "diff").mkdir(exist_ok=True)
    cases = []
    for row in lit["captures"]:
        before = rows.get(row["label"])
        if before is None:
            continue
        mismatched = [key for key in before if key != "file" and before[key] != row.get(key)]
        a = np.asarray(Image.open(args.root / before["file"].removeprefix("res://")).convert("RGBA")).astype(np.int16)
        b = np.asarray(Image.open(args.root / row["file"].removeprefix("res://")).convert("RGBA")).astype(np.int16)
        delta = np.abs(a - b).max(axis=2)
        worst = int(delta.max())
        if worst:
            heat = np.clip(delta * (255 // max(worst, 1)), 0, 255).astype(np.uint8)
            Image.fromarray(heat).save(folder / "diff" / (row["label"] + ".png"))
        ys, xs = np.nonzero(delta > args.tolerance)
        cases.append({"label": row["label"], "mismatched_receipt_fields": mismatched,
                      "maximum_byte_error": worst, "different_pixels": int((delta > 0).sum()),
                      "over_tolerance": int(len(ys)),
                      "over_tolerance_box": [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())] if len(ys) else []})
    passed = (len(cases) == len(reference["captures"]) and not reference["failures"] and not lit["failures"]
              and all(not c["mismatched_receipt_fields"] and c["over_tolerance"] == 0 for c in cases))
    report = {"tolerance": args.tolerance, "captures": len(cases), "passed": passed,
              "run_failures": [reference["failures"], lit["failures"]], "cases": cases}
    (args.root / "generated/lit_pixel_comparison.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"passed": passed, "captures": len(cases),
                      "worst": max((c["maximum_byte_error"] for c in cases), default=0),
                      "over_tolerance": sum(c["over_tolerance"] for c in cases)}))
    raise SystemExit(0 if passed else 1)


if __name__ == "__main__":
    main()
