"""Compare the two native_atlas_publication_checks runs, including source clocks.

Generate the reference script with git show 581ec3a:presentation/native_light_atlas.gd
in .runtime/atlas-baseline.gd, then run the fixture with/without --reference-atlas
against the same private journal. Run this tool in the engine's Pillow environment.
"""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageChops


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--baseline", default="581ec3a (atlas only)")
    args = parser.parse_args()
    folder = args.root / ".captures/atlas-publication"
    reference = json.loads((folder / "reference/report.json").read_text())
    current = json.loads((folder / "current/report.json").read_text())
    originals = {row["label"]: row for row in reference["captures"]}
    results = []
    labels_match = [r["label"] for r in reference["captures"]] == [r["label"] for r in current["captures"]]
    for row in current["captures"]:
        if row["label"] not in originals:
            continue
        before = originals[row["label"]]
        mismatched = [key for key in before if key != "file" and before[key] != row.get(key)]
        source = Image.open(args.root / before["file"].removeprefix("res://")).convert("RGBA")
        target = Image.open(args.root / row["file"].removeprefix("res://")).convert("RGBA")
        delta = ImageChops.difference(source, target)
        maximum = max(high for low, high in delta.getextrema())
        changed = sum(any(pixel) for pixel in delta.getdata()) if maximum else 0
        results.append({"label": row["label"], "mismatched_receipt_fields": mismatched,
                        "different_pixels": changed, "maximum_byte_error": maximum})
    report = {"baseline": args.baseline, "labels_match": labels_match, "cases": results,
              "checks_per_run": [reference["checks"], current["checks"]],
              "run_failures": [reference["failures"], current["failures"]],
              "notes": "Exact source/clock/publication receipts and final RGBA from the same immutable live journal. First disclosure frames and four views with wall/cap/Normals transitions. No pixel tolerance."}
    (args.root / "generated/atlas_pixel_comparison.json").write_text(json.dumps(report, indent=2) + "\n")
    passed = labels_match and not any(report["run_failures"]) and all(not r["mismatched_receipt_fields"] and r["maximum_byte_error"] == 0 for r in results)
    print(json.dumps({"passed": passed, "captures": len(results)}))
    raise SystemExit(0 if passed else 1)


if __name__ == "__main__":
    main()
