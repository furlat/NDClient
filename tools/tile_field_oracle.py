"""Export explicit tile-field fixtures from native projection and Python reduction.

Run from the backend's documented uv environment, passing --output explicitly.
Inputs reuse tests/player/test_tile_field_updates.py's native fixture helpers.
Only typed contract variations are added; no server identity or gameplay is made
up. The resulting JSON belongs in an ignored fixture directory, not source control.
"""
from argparse import ArgumentParser
from dataclasses import replace
from pathlib import Path
import json
import sys
from uuid import uuid4

BACKEND = Path(__file__).resolve().parents[2] / "dnd_engine"
sys.path.insert(0, str(BACKEND))

from pydantic import TypeAdapter, ValidationError
from dnd.core.world_edges import ElevationSurfaceKind, SlopeAxis
from dnd.player import reduction
from dnd.player.facts import PlayerInitialization, PlayerLineage, PlayerUpdate, TileFieldUpdate, WorldUpdate
from dnd.player.projection import begin_projection
from dnd.types.materials import Material, SurfaceLayer, TileSurface
from dnd.types.residues import TileResidueState
from dnd.types.world import LightLevel
from tests.player.test_projection_local_world import initial, sensory
from tests.player.test_tile_field_updates import light_change, project_event, tile_change
from reducer_oracle import normalized


def cold(owner, value):
    return TypeAdapter(owner).validate_json(TypeAdapter(owner).dump_json(value))


def initialization_case(name, value):
    value = cold(PlayerInitialization, value)
    raw = normalized(value)
    try:
        expected = {"ok": True, "value": normalized(reduction.reduce_initialization(value))}
    except ValueError as error:
        expected = {"ok": False, "message": str(error)}
    assert normalized(value) == raw, name
    return {"name": name, "value": raw, "expected": expected}


def operation_case(name, before, lineages):
    packet = cold(PlayerUpdate, PlayerUpdate(audience=before.viewing_audience,
        lineages=tuple(lineages), hud=None, combat_log_appends=(), content_additions=()))
    old_state, old_packet = normalized(before), normalized(packet)
    stages, events = [], []
    try:
        final = reduction.reduce_operation(before, packet)
        state = before
        for lineage in packet.lineages:
            stages.append({"lineage_uuid": str(lineage.lineage_uuid),
                "tiles": normalized(reduction.stage_lineage(state, lineage))["tiles"]})
            cursors = {row.event_uuid: row.source_index for row in lineage.version_rows}
            for index, node in enumerate(lineage.events):
                prefix = lineage.events[:index + 1]
                ids = {row.uuid for row in prefix}
                after = reduction.reduce_nodes(state, prefix, lineage.version_rows,
                    tuple(row for row in lineage.observations if cursors[row.event_uuid] <= cursors[node.uuid]),
                    tuple(row for row in lineage.world_updates if row.event_uuid in ids))
                events.append({"event_uuid": str(node.uuid), "tiles": normalized(after)["tiles"]})
            state = reduction.reduce_lineage(state, lineage)
        expected = {"ok": True, "value": normalized(final), "events": events, "stages": stages}
    except ValueError as error:
        expected = {"ok": False, "message": str(error)}
    assert normalized(before) == old_state and normalized(packet) == old_packet, name
    return {"name": name, "before": old_state, "packet": old_packet, "expected": expected}


def wire_case(name, owner, raw):
    try:
        value = TypeAdapter(owner).validate_json(json.dumps(raw))
        expected = {"ok": True, "value": normalized(value)}
    except ValidationError:
        expected = {"ok": False}
    return {"name": name, "root": owner.__name__, "value": raw, "expected": expected}


def build():
    cases, initializations, wire = [], [], []
    start = initial((), ((1, 0), (2, 0)), {})
    projection, public = begin_projection(start)
    before = reduction.reduce_initialization(public)
    initializations.append(initialization_case("first_discovery", public))
    packets = [project_event(projection, light_change(start.observer_uuid, light), start.end_cursor + index)
        for index, light in enumerate((LightLevel.DIM_LIGHT, LightLevel.DARKNESS, LightLevel.BRIGHT_LIGHT))]
    assert all(not row.world_updates[0].tiles and row.world_updates[0].tile_changes for row in packets)
    cases.append(operation_case("repeated_light_each_event", before, packets))
    first = public.world_updates[0]
    initial_field = replace(public, world_updates=(replace(first,
        tile_changes=(TileFieldUpdate(position=(1, 0), changes={"resolved_light": LightLevel.DIM_LIGHT}),)),
        *public.world_updates[1:]))
    initializations.append(initialization_case("initialization_full_then_field", initial_field))
    missing = TileFieldUpdate(position=(99, 99), changes={"resolved_light": LightLevel.DARKNESS})
    initializations.append(initialization_case("initialization_missing_base", replace(public,
        world_updates=(replace(first, tile_changes=(missing,)), *public.world_updates[1:]))))
    absent_collection = normalized(first); absent_collection.pop("tile_changes")
    wire.append(wire_case("omitted_tile_changes_defaults_empty", WorldUpdate, absent_collection))

    # Reuse the backend's actual enrichment/clear pattern, including a populated
    # nested surface so replacement must discard all of its old layers/text.
    projection, public = begin_projection(initial((), ((1, 0),), {}))
    before = reduction.reduce_initialization(public)
    original = before.tiles[(1, 0)]
    enriched = original.model_copy(update=dict(name="Ramp",
        surface=TileSurface(base_material=Material.WOOD,
            layers=(SurfaceLayer(material=Material.WATER, description="Wet layer"),), description="Old surface"),
        blocks_optics=True, blocks_propagation=True, walking_cost=2, flying_cost=2,
        swimming_cost=2, burrowing_cost=2, elevation_steps=2,
        surface_kind=ElevationSurfaceKind.RAMP, slope_axis=SlopeAxis.EAST_WEST,
        default_light=LightLevel.DIM_LIGHT, resolved_light=LightLevel.DIM_LIGHT,
        condition_names=("Ash",), residues=(TileResidueState(condition_uuid=uuid4(), residue_id="test.ash", description="Ash"),)))
    enrich = project_event(projection, tile_change(public.observer_uuid, enriched), public.end_cursor)
    clears = dict(blocks_optics=False, blocks_propagation=False, walking_cost=0, flying_cost=0,
        swimming_cost=0, burrowing_cost=0, elevation_steps=0,
        surface_kind=ElevationSurfaceKind.ORDINARY, slope_axis=None,
        default_light=LightLevel(0), resolved_light=LightLevel(0), condition_names=(), residues=())
    cleared = enriched.model_copy(update=clears)
    clear = project_event(projection, tile_change(public.observer_uuid, cleared), public.end_cursor + 1)
    surface = cleared.model_copy(update={"surface": TileSurface(base_material=Material.STONE)})
    replacement = project_event(projection, tile_change(public.observer_uuid, surface), public.end_cursor + 2)
    cases.append(operation_case("omission_explicit_clears_whole_surface", before, (enrich, clear, replacement)))
    assert "name" not in clear.world_updates[0].tile_changes[0].changes
    assert "surface" not in clear.world_updates[0].tile_changes[0].changes
    assert replacement.world_updates[0].tile_changes[0].changes == {"surface": surface.surface}

    # Native hidden changes never produce a disclosed packet. Rediscovery
    # catches up the remembered tile and introduces a genuinely new neighbor.
    start = initial((), ((1, 0),), {})
    projection, public = begin_projection(start)
    before = reduction.reduce_initialization(public)
    hide = project_event(projection, sensory(start.observer_uuid, visible_cells_removed=[(1, 0)]), 2)
    assert project_event(projection, light_change(start.observer_uuid, LightLevel.DIM_LIGHT), 3, disclosed=False) is None
    reveal = project_event(projection, sensory(start.observer_uuid, visible_cells_added=[(1, 0), (2, 0)]), 4)
    state = reduction.reduce_operation(before, PlayerUpdate(audience=before.viewing_audience,
        lineages=(hide, reveal), hud=None, combat_log_appends=(), content_additions=()))
    new_tile = state.tiles[(1, 0)].model_copy(update={"tile_uuid": uuid4(), "name": "Replacement"})
    full = project_event(projection, tile_change(start.observer_uuid, new_tile), 5)
    assert full.world_updates[0].tiles == (new_tile,) and not full.world_updates[0].tile_changes
    cases.append(operation_case("hidden_then_rediscovery_full_identity_replacement", before, (hide, reveal, full)))

    # Typed causal variations from the real two-event projected light fixture.
    start = initial((), ((1, 0),), {})
    projection, public = begin_projection(start)
    before = reduction.reduce_initialization(public)
    early = project_event(projection, light_change(start.observer_uuid, LightLevel.DIM_LIGHT), 2)
    late = project_event(projection, light_change(start.observer_uuid, LightLevel.DARKNESS), 3)
    new_tile = before.tiles[(1, 0)].model_copy(update={"position": (99, 99), "tile_uuid": uuid4()})
    introduction = replace(early, events=(replace(early.events[0], fact=None),),
        world_updates=(replace(early.world_updates[0], tiles=(new_tile,), tile_changes=()),))
    patch = replace(late, world_updates=(replace(late.world_updates[0], tiles=(), tile_changes=(missing,)),))
    cases.append(operation_case("earlier_introduction_then_patch", before, (introduction, patch)))
    future_gap = replace(early, world_updates=(replace(early.world_updates[0], tiles=(), tile_changes=(missing,)),))
    future_intro = replace(late, world_updates=(replace(late.world_updates[0], tiles=(new_tile,), tile_changes=()),))
    cases.append(operation_case("future_introduction_cannot_repair_missing_base", before, (future_gap, future_intro)))
    missing_late = replace(late, world_updates=(replace(late.world_updates[0],
        tile_changes=(*late.world_updates[0].tile_changes, missing)),))
    cases.append(operation_case("later_failure_after_valid_field_change", before, (early, missing_late)))
    canceled = replace(early, root=replace(early.root, canceled=True),
        events=tuple(replace(node, canceled=True) for node in early.events))
    cases.append(operation_case("canceled_fact_still_applies_associated_world_update", before, (canceled,)))
    same_event = replace(early, world_updates=(replace(early.world_updates[0],
        tiles=(new_tile,), tile_changes=(missing,)),))
    cases.append(operation_case("full_introduction_precedes_same_event_field", before, (same_event,)))
    ordered_rows = replace(early, world_updates=(replace(early.world_updates[0], tiles=(), tile_changes=(
        TileFieldUpdate(position=(1, 0), changes={"resolved_light": LightLevel.DIM_LIGHT,
            "blocks_optics": True, "condition_names": ("Ash",)}),
        TileFieldUpdate(position=(1, 0), changes={"resolved_light": LightLevel(0),
            "blocks_optics": False, "condition_names": ()}))),))
    cases.append(operation_case("same_event_duplicate_position_ordered_clears", before, (ordered_rows,)))

    for name, changes in [
        ("empty_omission", {}), ("false_zero_empty_null", dict(blocks_optics=False,
            walking_cost=0, condition_names=[], residues=[], slope_axis=None)),
        ("whole_surface_defaults", {"surface": {"base_material": "stone"}}),
        ("invalid_light_null", {"resolved_light": None}),
        ("invalid_collection_null", {"condition_names": None}),
        ("invalid_negative", {"walking_cost": -1}),
        ("invalid_boolean_number", {"walking_cost": True}),
        ("invalid_fraction", {"walking_cost": 1.5}),
        ("invalid_tile_identity", {"tile_uuid": str(new_tile.tile_uuid)}),
        ("invalid_position_identity", {"position": [1, 0]}),
        ("invalid_unknown", {"unknown": 1}),
    ]:
        wire.append(wire_case(name, TileFieldUpdate, {"position": [1, 0], "changes": changes}))
    return {"scope": "Existing native tile-field/projection fixture helpers, current Python reduction and typed causal variations. No server/session identity, rendering, or performance claim.",
        "protocol_identity": json.loads((BACKEND / "sdk/protocol/protocol-identity.json").read_text()),
        "normalization": "Only visible/seen set order and process-local sense_modes_hash, as existing reducer oracle.",
        "initializations": initializations, "cases": cases, "wire_cases": wire}


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path, help="Explicit ignored JSON fixture path")
    args = parser.parse_args()
    suite = build()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(suite, separators=(",", ":")))
    print(json.dumps({"output": str(args.output), "initializations": len(suite["initializations"]),
        "operations": len(suite["cases"]), "wire_cases": len(suite["wire_cases"])}))


if __name__ == "__main__":
    main()
