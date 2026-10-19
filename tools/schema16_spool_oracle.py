"""Test-only per-record native oracle over exact server spool bytes from a frozen engine."""
import argparse
import json
from pathlib import Path
import struct
import sys


def export(engine: Path, spool: Path, output: Path) -> None:
    sys.path.insert(0, str(engine))
    from server.protocol import InitializationResponse, PlayerOperation
    from dnd.player.reduction import reduce_initialization, reduce_operation
    from devtools.performance.seat_oracle import state_data
    output.mkdir(parents=True, exist_ok=True)
    index = {"seats": []}
    for path in sorted(spool.glob("*.frames")):
        state = None
        records = []
        with path.open("rb") as source:
            sequence = 0
            while header := source.read(4):
                size, = struct.unpack(">I", header)
                raw = source.read(size)
                if len(raw) != size:
                    raise ValueError(f"Incomplete record {path}:{sequence}")
                if sequence == 0:
                    packet = InitializationResponse.model_validate_json(raw)
                    state = reduce_initialization(packet.initialization, content_additions=packet.content_additions)
                else:
                    state = reduce_operation(state, PlayerOperation.model_validate_json(raw))
                stem = f"{path.stem}-{sequence:06}"
                raw_path = output / f"{stem}.json"
                expected_path = output / f"{stem}.expected.json"
                raw_path.write_bytes(raw)
                expected_path.write_text(json.dumps(state_data(state), separators=(",", ":")) + "\n")
                records.append({"bytes": raw_path.name, "expected": expected_path.name})
                sequence += 1
        index["seats"].append({"id": path.stem, "records": records})
    (output / "index.json").write_text(json.dumps(index, indent=1) + "\n")
    print(json.dumps({"seats": len(index["seats"]), "records": sum(len(seat["records"]) for seat in index["seats"])}))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--engine", type=Path, required=True)
    parser.add_argument("--spool", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    export(args.engine, args.spool, args.out)


if __name__ == "__main__":
    main()
