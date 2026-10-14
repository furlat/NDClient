#!/usr/bin/env python3
"""Render the readable scenario catalog from its single passive authoring source."""

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "authoring/studio/scenarios.json"


def cell(value: str) -> str:
    return value.replace("|", "\\|").replace("\n", " ")


def render(data: dict) -> str:
    scenarios = {row["id"]: row for row in data["scenarios"]}
    if len(scenarios) != len(data["scenarios"]):
        raise ValueError("Duplicate scenario identity")
    capabilities = {row["id"] for row in data["capabilities"]}
    rendered = []
    parts = []
    for part in data["document"]["parts"]:
        if "markdown" in part:
            parts.append(part["markdown"])
            continue
        parts.append(
            "| ID and named scenario | Setup and legal sequence | "
            "Authoritative outcome and visible/audio tracks | Existing evidence / remaining work |\n"
            "|---|---|---|---|\n"
        )
        for identity in part["scenario_ids"]:
            row = scenarios[identity]
            missing = set(row["capability_ids"]) - capabilities
            if missing:
                raise ValueError(f"{identity}: undeclared capabilities {sorted(missing)}")
            expectation_ids = [entry["id"] for entry in row["expectations"]]
            if len(set(expectation_ids)) != len(expectation_ids):
                raise ValueError(f"{identity}: duplicate expectation identity")
            presentation = next(entry["description"] for entry in row["expectations"]
                                if entry["id"] == row["code"] + ".presentation")
            outcome = next(entry["description"] for entry in row["expectations"]
                           if entry["id"] == row["code"] + ".outcome")
            sequence = " → ".join(row["sequence"])
            parts.append(
                f"| **{cell(row['code'])} — {cell(row['label'])}** | "
                f"{cell(row['setup'])} **Sequence:** {cell(sequence)}. "
                f"**Participants:** {cell(', '.join(row['participants']))}. | "
                f"**Engine:** {cell(outcome)} **Presentation:** {cell(presentation)} | "
                f"{cell(row['coverage']['note'])} |\n"
            )
            rendered.append(identity)
    if len(rendered) != len(set(rendered)) or set(rendered) != set(scenarios):
        raise ValueError("The document must render every authored scenario exactly once")
    banner = "<!-- Generated from authoring/studio/scenarios.json; edit that source, then run tools/render_studio_scenarios.py. -->\n\n"
    return banner + "".join(parts)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Check freshness without writing")
    args = parser.parse_args()
    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    output = ROOT / data["document"]["output"]
    text = render(data)
    if args.check:
        if not output.is_file() or output.read_text(encoding="utf-8") != text:
            print(f"Stale scenario document: {output}")
            return 1
    else:
        output.write_text(text, encoding="utf-8")
    print(f"{len(data['scenarios'])} scenarios; {len(data['capabilities'])} declared capabilities; document current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
