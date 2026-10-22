"""Save unchanged worker publications from the existing caster-defeat regression.

Run with the selected frozen engine and its SDK on PYTHONPATH. The backend test
owns its real roster, commands and deterministic dice. This wrapper only retains
the emitted packets and request evidence; it does not change native state.
"""
import argparse
import json
from pathlib import Path

from dnd.core.content.encounters import RosterControllerKind
from server import worker
from server.protocol import protocol_identity
from tests.player.test_summon_caster_defeat import test_weapon_moves_resets_and_departs_with_only_its_caster


def record(output: Path) -> None:
    output.mkdir(parents=True, exist_ok=False)
    seats, counts, requests = {}, {}, []
    original_start, original_dispatch = worker.start, worker.dispatch

    def save(records):
        for packet in records:
            seat = seats[packet.cursor.audience_id]
            directory = output / seat
            directory.mkdir(exist_ok=True)
            (directory / f"{packet.cursor.sequence:016}.json").write_text(packet.model_dump_json())
            counts[seat] += 1

    def start(request):
        seats.update({identity: seat for seat, identity in request.audience_ids.items()})
        counts.update({seat: 0 for seat in request.audience_ids})
        result = original_start(request)
        save(result[2])
        requests.append(request.model_dump(mode="json"))
        return result

    def dispatch(runtime, request):
        result = original_dispatch(runtime, request)
        save(result[1])
        requests.append(request.model_dump(mode="json"))
        return result

    try:
        worker.start, worker.dispatch = start, dispatch
        test_weapon_moves_resets_and_departs_with_only_its_caster(output, RosterControllerKind.CODEX)
    finally:
        worker.start, worker.dispatch = original_start, original_dispatch
    engine = Path(worker.__file__).resolve().parents[1]
    identity = {"path": str(engine), "commit": json.loads((engine / ".source.json").read_text())["commit"],
        **protocol_identity().model_dump()}
    (output / "requests.json").write_text(json.dumps(requests, indent=1) + "\n")
    (output / "receipt.json").write_text(json.dumps({"ok": True, "engine": identity,
        "controller": "codex", "records": counts,
        "source": "tests.player.test_summon_caster_defeat.test_weapon_moves_resets_and_departs_with_only_its_caster",
        "scope": "Original native worker publications; existing deterministic dice fixture; no HTTP delivery claim",
        "journey": ["cast_two_spiritual_weapons", "move_first_weapon", "reset_movement_on_next_turn",
            "fireball_first_caster", "caster_defeated_departure", "other_caster_weapon_survives"]}, indent=1) + "\n")
    print(json.dumps({"output": str(output), "records": counts, "ok": True}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    record(parser.parse_args().output)


if __name__ == "__main__":
    main()
