# Actual condition-owned body scale

20 October 2026. Existing Phase 4 body/material provider cohort on the sole
`codex-authoring-schemabump` client branch. Focused headless and native
qualification receipts are below. No Factory, engine, shader, source
sheet, lighting or backend-occupancy change belongs to this cohort.

## Authoring and ownership

`PresentationLookStep.scale_by_size_change` is an optional typed field on the
existing `body_adjust` step. Enlarge/Reduce's exact presentation factors are
`enlarge=1.175`, `reduce=0.75`, moved from `unported.persistent.bodyScale` into
that typed home. Existing AbilityRecords F move/emit produces the runtime recipe;
key/factor validation happens in the offline build only.

The existing `Conditions.select_recipes` chooses condition owners. The public
member's actual `state.size_change` selects an authored factor; absent/unmatched
selectors are neutral. Selected independent recipes compose multiplicatively,
and one recipe's duplicate owner is not applied once per layer or condition copy.
Existing owner removal alpha, if present, interpolates that contribution back
to neutral. There is no independent scale timer, condition or new reducer.

Play applies this uniform XYZ factor once to the real outfit model about its
existing feet/contact. Local source geometry, original mesh, UVs, `row.scale`,
`entry.scale`, source normals/depth and physical source-cache identities remain
unchanged. Passage transforms compose with it; airborne/support displacement
keeps its original movement owner. The sampled pose retains the actual selected
condition UUID/state/factor so equal sprite frames cannot lose an application
or removal.

EntitySurface transforms the unchanged local optical points through that actual
model and uses inverse-transpose normals. Pixel picking already uses its inverse.
The shared source-pixel socket helper now uses the same model/pivot, preserving
the caller's actual event-time requested contact/elevation and lift. Painter bounds use
the transformed quad only for non-neutral size; the neutral path remains exact.
The shadow adapter captures the same model delta against its previous camera/
mirror basis. Both CPU footprint and the original native caster use that delta
about their established optical support pivot; the native source shader and
height-compression rule are unchanged. Neutral caster math returns the original
operands directly. Its native culling AABB remains in pre-model source space;
only the CPU footprint bounds include the model before helper placement. The
caster node's basis/support-pivot transform applies to its vertices and local
box once, including Reduce.

Studio's existing condition-operation rows expose Body scale with the actual
owner, state, factor and authoring source, plus an actual removal/restoration row.
The existing body draw witness requires the same selected UUID/state/factor in
the sampled outfit. A generic body/marker witness cannot qualify it. The distinct
ActorChange `resolved_size` requirement and unsupported distortion/copies/absence
mechanisms retain their prior unassessed/missing status.

## Original recordings

- The earlier Enlarge baseline remains unchanged under
  `tests/fixtures/schema16/body-scale-enlarge/{amber,blue}`: original packet 8,
  occurrence 55, UUID `8e2e8283-3753-479e-a9f3-86172ce4e59b`. It proves application
  only, not removal or Reduce.
- Fresh lawful existing recorder recipes both succeeded through the frozen
  `211b71134` engine, schema 16 /digest `49d14bc2`. Complete independent originals
  are under `tests/fixtures/schema16/body-scale/{enlarge,reduce}/{amber,blue}`
  with their unchanged `scenario.json` and joined `cases.json` provenance.
  Each original seat contains real application, two movement steps, two attacks
  (including the actual reaction), drop concentration and the actual same-UUID
  removal. No wire packet or after-value was edited.
- Enlarge UUID `d19e9881-ff1e-467d-b4e4-316fa4bdc953`, actor
  `108d084b-1055-4b94-a690-10d539b7e8e5`; Reduce UUID
  `1f9fb82d-7b7d-4795-b369-f4cc46bf1f18`, actor
  `f4a5b1bb-9666-484d-8550-4d2cda8534c6`. Both apply in operation 6; each audience
  retains its own occurrence identity (Amber 47, Blue 42).
- Recorder originals/results remain under `.runtime/body-scale-recordings/`.

Reproduce recordings, one frozen backend at a time:

```bash
/home/tommaso/.cache/dnd-engine/venv/bin/python -B tools/studio_cases/record.py \
  --only spell.enlarge_reduce/enlarge_lifecycle,spell.enlarge_reduce/reduce_lifecycle \
  --out .runtime/body-scale-recordings-new --timeout 240
```

## Qualification checklist and boundaries

- [x] Typed/resource and shared renderer implementation written; source-index
  build passed with 85 checks/zero errors in root's qualification lane
  (`.runtime/tests/20261020T033114.930165Z/source_index_owner_checks.log`).
- [x] Two lawful frozen-engine lifecycle recordings, both audiences; complete
  original prefixes preserved (76 fresh packets plus 18 earlier baseline packets).
- [x] `tests/body_scale_checks.gd`: 110 checks, zero failures/script/resource
  errors in `.runtime/tests/20261020T034812.969969Z/body_scale_checks.log`;
  headless/no args; typed round-trip, actual
  both-seat selectors, genuine Enlarge/Reduce removal and canonical restoration,
  exact Studio rows/seek, labelled unit composition and model/socket/caster math,
  including exact frozen endpoint lift independent of a later displayed lift.
  The full recipe round-trip exposed an existing converter loss of an explicitly
  empty `appearanceLayers` array. The normal F move default-preservation path now
  retains that presence; no values or whole-record assertions were discarded.
- [x] `tests/body_scale_render_checks.gd`: 1,696 checks, zero failures/script/
  resource errors or warnings in
  `.runtime/tests/20261020T034826.061518Z/body_scale_render_checks.log`;
  GPU/no args; actual lifecycle through
  ordinary prepared publication, all outfit layers, actual opaque-pixel picking,
  four cameras, paired scaled/control native frames, selected UUID witnesses,
  restoration and seek/loop. These controls do not manufacture gameplay outcomes.
  Each requested camera waits for real prepared publication and asserts both
  actual camera quarter and its world owner before output/picking/socket checks.
  All eight source extrema lie inside the actual native caster's local culling
  box and its once-transformed box, matching the CPU support-pivot placement.
  The earlier 224-check receipt did not wait for rotation completion and does
  not qualify four-view coverage; the corrected receipt supersedes that claim.
- [x] Bounded independent correctness/anti-slop/anti-OOP review: actual once-only
  outfit/socket/caster transform, neutral path, selected UUID witness and genuine
  camera publication checked against source and native assertions; no material
  blocker found. The full126-test fast lane passes at
  `.runtime/tests/20261020T040632.046300Z/`, including the repaired actual-source
  socket fixtures. A second native1696-check pass is at
  `.runtime/tests/20261020T041209.004924Z/`.
- [ ] Complete broader native neutral-art gate and final current-checkpoint
  full-fast rerun. Root owns builds/serialized GPU and final receipts.

The focused native gate qualifies unchanged source units, exact sampled-model
framebuffer restoration, real shadow/socket operands, picking and both recorded
lifecycles across the four actual cameras. Broader neutral-art regression and a
bounded independent review remain separate checks. This shared mechanism does
not qualify the deferred Factory actor-history shaders, the new weapon package
integration or visual acceptance of unrelated spells.
