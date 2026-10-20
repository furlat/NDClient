# Disclosed water source ownership — 20 October 2026

Bounded Phase4/5 client integration on the sole main checkout, sealed runtime-e102c29dec58524b. No Factory source/art, engine, reducers, scheduler, lighting or registration changes.

The delivered `bg3-36/create-or-destroy-water/create` source now belongs to the actual disclosed `spatial_effect.material.water_surface` UUID. The finite cast copy is excluded. `SpatialInputs` supplies immutable `surface_groups` before construction, through the existing spatial-owner constructor path: at most32 original cells per group,160 deterministic optical coverage samples inside those cells, bounds in the same unscaled local cell frame, and the actual source UUID. These optical samples are not additional gameplay cells or particle outcomes. Source meshes/materials/textures/colours/rain equations remain unchanged. The existing private spatial owner retains the constructed records; sampling does not regenerate the160points. Existing AreaMask publication clips current cells, suppression and visibility without reconstructing the source. Topology expansion beyond the first disclosed source cells remains `spatial_source_topology_extension_not_bound`.

First disclosure is not creation. Rainfall opens only when this exact owner's native `operation=created` observation occurs at its admission cut. Initial membership, later first disclosure and remembered-owner readmission without that evidence start at the authored3.5second held-puddle state. The authoritative owner start/duration is unchanged. The current original has no native created row, so it qualifies held water coverage only; it does not prove rainfall onset. Physical removal closes that actual owner; destroy-animation/expiry choreography is not claimed. Wet baseline also supplies no real removal; its false-membership controls are explicitly private, not invented server events.

The original null-behavior Wet member is a separate real UUID. It discloses semantic key `unbound:dnd.spatial.environmental_conditions.Wet`, not `condition.spell.rain_wet`. Current `Conditions.recipe` admits sources by behavior ID before NativePersistent sampling; an authored semantic-key reader would require a separately coordinated owner-admission change. The finite Wet cue therefore retains explicit gap `null_behavior_wet_semantic_owner_not_bound`, and the false applied-condition declaration is removed. No alias or generic Wet state is fabricated.

Telekinesis's existing actual-contact source additionally receives an explicitly authored `suppressed=false`, with policy `schema16_retired_antimagic`. NativeInputs supplies this only when the cue authors that boolean; unrelated sources retain `provider_not_bound`. This is the same schema16 no-Antimagic rule disposition already used by other source owners, not a global suppression fallback or new gameplay rule.

## Exact original evidence

`tests/fixtures/schema16/water-source-provider/{amber,blue}/journal` are complete unchanged copies of `.runtime/studio-library/cases/spell.create_or_destroy_water__baseline/20261019T144441.380200Z`. Each independent seat has9packets. Scenario, actual commands, recording result and provenance accompany them:22files/1,369,173bytes before the small provenance clarification. Frozen engine211b71134/schema16; no new backend, roll, packet or fact was created for this cohort.

Actual water owner `939c2874-27d3-4b6e-9596-195cfbc4a1ea` has13 disclosed cells. Amber native sensory occurrence63 supplies its membership; the actual root SpellFact64 supplies the same13 resolved cells around6,7. Recipient Wet owner `dede53e7-00f4-44ab-a4b1-e9a7bbf785e3` is admitted by ActorChange49 with null behavior and the explicit semantic key above. No native created/removal event exists in this capture. Blue is independently reduced; no Amber facts are inserted there.

## Gates and integration

`water_source_provider_checks`: headless, timeout120seconds,args[]. It builds only the typed water spell/condition in memory and uses both original journals, exact independent13cell constants, complete canonical compile/drain parity, actual constructor UUID/cells, original sealed phase/art immutability, no post-construction setter calls, immutable per-owner reuse beyond the finite review clip, and independent partition capacity/coverage controls. Synthetic controls are explicitly labeled: suppression/recovery, permanent partial-cell removal, topology growth, actual-created row, late disclosure/readmission, and already-present owners. Telekinesis checks preserve the explicit false literal, unchanged-input reuse and missing-authoring negative.

The spatial and exact semantic sources are registered in `authoring/abilities.tres`. Root owns coordinated production builds and test receipts below. Source presence/headless readiness is not visual acceptance or performance approval.


## Production qualification receipt

Abilities-only build: clean,5.0seconds,
`.runtime/tests/20261020T111844.774605Z/summary.json`.
Headless actual surface ownership/input166/0 and actual Wet semantic owner45/0:
`.runtime/tests/20261020T111916.664424Z/summary.json`.
Wet plus offline misuse controls52/0:
`.runtime/tests/20261020T112011.752970Z/summary.json`.

Native ordinary Play/Recording **278/0**, zero script/engine errors or owned
leftovers: `.runtime/tests/20261020T112056.899193Z/summary.json`. Exact pixels,
clock/UUID/cell observations and24captures are retained under
`.runtime/water-source-provider/native-checks.json` and `native-captures/`.
Both independent seats traverse initialization→held→initialization→held→lateheld;
all four actual camera publications preserve each private source occurrence.
The actual source is hidden/restored per framebuffer probe, separately for
water and Wet; current geometry and all required inputs must be ready after a
rendered frame. The shared test helper now rechecks those inputs after its frame
await instead of returning on stale readiness from the preceding view.

The first native failures are retained in the earlier reports. They exposed the
legacy composition default suppressing Wet, then a test-only view/input-readiness
race. Neither a disabled assertion nor alternate art was used to make the gate
pass. The first source-control failure was a test receiver missing the declared
input_setters map; it was corrected to the actual Godot setter interface.

Re-publish the unchanged baseline into the existing Studio library without a backend:

```sh
python3 tools/studio_cases/record.py --import-recordings tests/fixtures/schema16/water-source-provider
```

Open `studio.cmd`, select Create or Destroy Water's baseline, and inspect its
spatial-water and distinct Wet tracks. The original lacks rainfall creation,
Wet retirement and destroy-water choreography; native application/hold output
does not qualify those missing recordings, first-use timing or user acceptance.
