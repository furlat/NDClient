"""Full Python-reference states for unchanged, checked-in two-seat recordings.

Run with the frozen engine on PYTHONPATH, never the production checkout:
  PYTHONPATH=/home/tommaso/.cache/ndclient/dnd_engine-9f81d5267 \
    /home/tommaso/.cache/dnd-engine/venv/bin/python tools/recorded_state_oracle.py

Raw packets remain in their original journals. The ZIP holds complete canonical
JSON states, not client-generated expectations or a second delta language.
"""
import argparse
import json
import os
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

from pydantic import TypeAdapter

from dnd.player import reduction
from dnd.player.facts import PlayerState
from server.protocol import InitializationResponse, PlayerOperation


PROJECT = Path(__file__).resolve().parents[1]
CATALOG = PROJECT / "tests/fixtures/schema16/scenarios/catalog.json"
DEFAULT_OUTPUT = PROJECT / "tests/fixtures/schema16/spool-oracle"
STATE = TypeAdapter(PlayerState)


def export(cases: list[str], output: Path) -> None:
    catalog = json.loads(CATALOG.read_text())
    reference = Path(reduction.__file__).resolve().parents[2]
    output.mkdir(parents=True, exist_ok=True)
    index = {"reference": {}, "states_archive": "canonical-states.zip", "seats": []}
    with ZipFile(output / index["states_archive"], "w", compression=ZIP_DEFLATED, compresslevel=9) as archive:
        for name in cases:
            case = catalog[name]
            if reference != Path(case["engine"]["path"]).resolve():
                raise ValueError(f"Reference imports must come from frozen recorded engine: {reference}")
            index["reference"] = case["engine"]
            for seat in case["perspectives"]:
                directory = PROJECT / seat["journal"].removeprefix("res://")
                files = sorted(directory.glob("[0-9]" * 16 + ".json"))
                if not files or files[0].stem != "0000000000000000":
                    raise ValueError(f"No original initialization: {directory}")
                state = None
                records = []
                for sequence, path in enumerate(files):
                    if int(path.stem) != sequence:
                        raise ValueError(f"Noncontiguous journal: {path}")
                    raw = path.read_bytes()
                    if sequence == 0:
                        packet = InitializationResponse.model_validate_json(raw)
                        state = reduction.reduce_initialization(packet.initialization, content_additions=packet.content_additions)
                    else:
                        state = reduction.reduce_operation(state, PlayerOperation.model_validate_json(raw))
                    expected = f"{name}/{seat['id']}/{path.name}"
                    entry = ZipInfo(expected)
                    entry.compress_type = ZIP_DEFLATED
                    archive.writestr(entry, STATE.dump_json(state), compresslevel=9)
                    records.append({"bytes": os.path.relpath(path, output), "expected": expected})
                index["seats"].append({"id": f"{name}/{seat['id']}", "records": records})
    (output / "index.json").write_text(json.dumps(index, indent=1) + "\n")
    print(json.dumps({"seats": len(index["seats"]), "records": sum(len(seat["records"]) for seat in index["seats"]),
        "archive_bytes": (output / index["states_archive"]).stat().st_size, "reference": str(reference)}))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cases", nargs="+", default=["door", "oa-jump-late-lethal"])
    parser.add_argument("--out", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    export(args.cases, args.out)


if __name__ == "__main__":
    main()
