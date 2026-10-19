"""Export schema-16 reference fold fixtures from an explicit frozen engine.

Test-only: stores each original input plus the reference canonical state after every step.
No engine discovery, recording conversion or runtime validation belongs here.
"""
import argparse
import json
from pathlib import Path
import sys
from uuid import UUID


def export(engine: Path, output: Path) -> None:
    sys.path.insert(0, str(engine))
    from pydantic import TypeAdapter
    from dnd.player.audience import PlayerAudience
    from dnd.player.facts import PlayerState, PlayerWorld, WorldUpdate, BodyRecord, ActorChangeFact, SpatialFact, SensoryRows, SensoryFact, PlayerLineage
    from dnd.player.reduction import enter_body, apply_actor_change_fact, apply_player_fact, clear_unseen_positions, composed_values, fold_composed_sensory, reduce_lineage, lineage_branch
    from dnd.player.world_reduction import fold_world_update
    from dnd.core.cells import mask_from_positions
    from dnd.types.senses import SensesSnapshot, PerceivedContact
    from dnd.types.cells import EMPTY_VALUES
    from dataclasses import replace
    from devtools.performance.seat_oracle import state_data
    adapters = {"update": TypeAdapter(WorldUpdate), "body": TypeAdapter(BodyRecord), "change": TypeAdapter(ActorChangeFact), "spatial": TypeAdapter(SpatialFact)}
    world = PlayerWorld(battlefield_id="vectors", battlefield_name="Vectors", bounds=(0, 0, 15, 15), width=16, height=16)
    generation = UUID("00000000-0000-4000-8000-00000000f000")
    output.mkdir(parents=True, exist_ok=True)
    names = []
    for path in sorted((engine / "sdk/protocol/fold-vectors").glob("*/*.json")):
        document = json.loads(path.read_text())
        observers = tuple(UUID(value) for value in document["observers"])
        audience = PlayerAudience(observers=observers, controlled=tuple(UUID(value) for value in document.get("controlled", [])))
        state = PlayerState(generation=generation, observer_uuid=observers[0], world=world, audience=audience)
        fixture = {"name": document["name"], "family": path.parent.name, "initial": state_data(state), "steps": []}
        steps = document.get("steps", [{"update": document.get("initial", {}), "expected": {}}, {"group": document.get("group", {}), "expected": document.get("expected", {})}])
        for step in steps:
            if "update" in step:
                fold_world_update(state, adapters["update"].validate_json(json.dumps(step["update"])))
            elif "sensory_rows" in step:
                fold_composed_sensory(state, TypeAdapter(SensoryFact).validate_json(json.dumps(step["fact"])), composed_values(TypeAdapter(SensoryRows).validate_json(json.dumps(step["sensory_rows"]))))
            elif "body" in step:
                enter_body(state, adapters["body"].validate_json(json.dumps(step["body"])))
            elif "change" in step:
                apply_actor_change_fact(state, adapters["change"].validate_json(json.dumps(step["change"])))
            elif "spatial" in step:
                apply_player_fact(state, adapters["spatial"].validate_json(json.dumps(step["spatial"])), composed_values(SensoryRows()))
            elif "seen" in step:
                seen = step["seen"]
                contacts = {UUID(identity): PerceivedContact(position=tuple(row["position"]), visual=row["visual"]) for identity, row in seen["contacts"].items()}
                visible = mask_from_positions(tuple(tuple(point) for point in seen["visible"]))
                state.senses = SensesSnapshot(position=(0, 0), visible=visible, seen=visible, entities=contacts, objects={}, effective_light_levels=EMPTY_VALUES, paths_dirty=False, passive_perception=10, sense_modes_key=(), sense_modes=(), visual_access=1)
                clear_unseen_positions(state)
                for identity, contact in contacts.items():
                    if contact.visual and identity in state.actors and state.actors[identity].present:
                        state.actors[identity] = replace(state.actors[identity], last_visual_position=contact.position)
            elif "group" in step:
                group = TypeAdapter(PlayerLineage).validate_json(json.dumps(step["group"]))
                state = reduce_lineage(state, group)
                branch = lineage_branch(group, group.events[group.root])
                assert [node.occurrence for node in branch.events] == step["expected"]["root_branch_occurrences"]
            fixture["steps"].append({"input": {key: value for key, value in step.items() if key != "expected"}, "expected": state_data(state)})
        name = path.name
        (output / name).write_text(json.dumps(fixture, indent=1) + "\n")
        names.append(name)
    identity = json.loads((engine / "sdk/protocol/protocol-identity.json").read_text())
    (output / "index.json").write_text(json.dumps({"protocol": identity, "fixtures": names}, indent=1) + "\n")
    print(f"Exported {len(names)} native fold vectors")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--engine", type=Path, required=True)
    parser.add_argument("--out", type=Path, default=Path("tests/fixtures/schema16/fold"))
    args = parser.parse_args()
    export(args.engine, args.out)


if __name__ == "__main__":
    main()
