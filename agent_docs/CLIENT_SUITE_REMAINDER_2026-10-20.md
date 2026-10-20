# Durable current-client suite remainder

20 October 2026, sole `codex-authoring-schemabump` client branch. This is a
tests-only migration of four ignored/temporary historical snapshots. The
current schema16 SDK folds the original seat packets; no compatibility adapter,
invented gameplay outcome, production change or runtime validator is introduced.
Native/GPU qualification remains separate from headless preparation/diagnostics.

## Exact original inputs

| Test | Removed input dependency | Durable replacement |
| --- | --- | --- |
| `media_warmup_checks` | `.runtime/player-runs/20261011T223103.996259Z/state.json` | `tests/fixtures/schema16/scenarios/door/amber`, SDK fold through sequence0 |
| `media_role_race_checks` | Same ignored Oct11 state | Same original door prefix and actual disclosed fixture PNGs |
| `ui_checks` | `AppData/Local/Temp/ndclient-presentation-attack/amber/states/0000000000000000.json` | `tests/fixtures/schema16/scenarios/interaction-media/amber`, SDK fold through sequence0: actual fighter inventory/Javelin, two controlled actors and a disclosed opponent |
| `ui_recorded_checks` | `.runtime/player-runs/20261011T222502.988278Z/{state,discovery}.json` | `tests/fixtures/schema16/scenarios/gallery/amber`, SDK fold through actual turn-start sequence1, plus unchanged committed `gallery/choices.json` |

All four journals retain the actual frozen engine211b71134 / schema16 identity.
The recorded Gallery choices name the same original actor and encounter
generation `237cfdaa-bca9-4c3e-b42f-4eab645adfdf`; the test asserts this identity.
The choice file is already a committed native server output, also used by the
existing choice-prefetch and compact-interaction gates. No old choice is retagged.

Canonical carried inventory remains UUID membership in the actual actor; item
look/profile/state come from top-level `state.items` through `UI.item` and
`UI.inventory`. The UI boundary fixture retains its explicitly labelled local
page/disabled/upcast/input controls. Its current-turn display perturbation is a
private test copy, not a recorded turn or a backend command.

The genuine Gallery choice inventory has twelve Base families, eight Class
families (including distinct conversion ranks), eleven Spells and three Items.
The strict UI expectations follow those actual rows. Magic Missile's original
one action offers `cast_levels=[1,2,3]`: each painted rank must retain that exact
source action and all source/target operands; only the offered cast level varies.
Raw original state and choices must remain unchanged after HUD use.

## Qualification state

The first migrated `media_warmup_checks` diagnostic completed81 checks without
script/resource errors, but six assertions were red in
`.runtime/consolidation/media-warmup-durable-headless.log`. Its repaired
headless functional run now passes86 checks with no script/resource errors:
`.runtime/consolidation/media-warmup-durable-headless-r3.log`.

- Three old worker-slot expectations assume optional work can fill all eight
  current decode workers. The current producer explicitly caps optional work
  at four; required jobs can use eight and finite required batches contain up
  to two images. Preserve the starvation/publication test against these actual
  ownership limits, rather than asserting the retired scheduling arrangement.
  Both spare urgent capacity and a genuinely full eight-worker pool later
  withdrawn to optional now retain explicit publication/reclamation controls.
- Exact resting-demand checks now include the actual item-look operands and
  the independently authored equipment `Taunt` closure alongside `Idle`.
  They still reject every unrelated clip/outfit.
- The immutable source-snapshot allowlist now names admitted environment
  Resource paths/native source ownership while retaining exact immutable
  references and exclusion of mutable planner indexes.

`ui_checks` passes83 headless functional checks in
`.runtime/consolidation/ui-durable-headless.log`; native pointer/texture output
remains unqualified. Two scripts still have real stale-test failures:

- `media_role_race_checks` previously accessed obsolete optional-selection
  planner fields (`selection_deferred`, `demand_precomputation`) and assumed
  used CPU pixels were discarded under budget. The candidate now uses an actual
  immutable GPU-family→CPU-family replacement, explicit byte pressure and the
  public pending/readiness path; original PNG bytes and bounded publication,
  shared physical counters and close controls remain strict. Its final rerun
  is pending the root's profiling window.
- `ui_recorded_checks` now folds the actual combat-start packet before
  expecting a current actor. Original Gallery initialization alone correctly
  has `current_actor_uuid=null`; no test assignment manufactures that turn.
  Offered JSON numeric levels are compared with canonical integer display ranks,
  while every original source/target field and underlying action owner remains
  required. Its final rerun is pending the same window.

The remaining migrated scripts await functional/native qualification. There is
no GPU, input-dispatch, texture-byte or overall-suite pass claim yet. The root
owns the exclusive source build, manifest and serialized native runs. Proposed
`ui_recorded_checks` optional inputs are `--recording` and `--choices`, replacing
the obsolete state-directory `--capture` option; the default needs neither.
It creates its own ignored report directory, so a standalone run never depends
on `ui_checks` having run first. Native image-byte and input checks remain intact.

## Deleted workshop path

`tests/workshop_checks.gd:51` still loads the removed `res://main.tscn` and drives
the old offline workshop's local `destruction`/`reset_destruction`/palette tools.
That is not the authoritative current player. It must not pass by reviving local
game-state mutation or by adding a fake scene. Root owns explicit manifest
retirement; retirement is recorded as retired/replaced, never counted as pass.

Required current behavior has separate executable owners:

- `door_overlap_checks`, `wall_fragment_checks`, `hidden_corner_checks` and
  `wall_compositing_checks`: real authored door/wall/corner partition, aperture
  and painter/depth composition.
- `chest_render_checks`, actual `chest_live_checks`, `loot_live_checks` and
  `player_interaction_checks`: real open/close/equipment/loot and authoritative
  object state, with source bytes/placement retained.
- `actor_layer_endpoint_checks`, `native_demo_parity_checks`,
  `native_assembled_demo_checks` and current condition/weapon render gates:
  modular source layering/tint, optical body model and actual effect ownership.

The removed workshop's palette/editor/reset shortcuts are not current gameplay
features. Current native controls and actual issued backend actions retain their
own gates; no invented destruction outcome replaces a recorded positive.

## Genuine remaining source failure

`native_actor_context_render_checks` is not a stale-fixture excuse. Its original
Mirror Image recording reaches the installed c494 ActorHistory source, then
two embedded `#include`/`#define` shader compilation errors remain. The red
`.runtime/tests/20261019T231410.817195Z/native_actor_context_render_checks.log`
must stay visible. The inspected sealed weapons5dc successor does not contain
those fixes; later Factory WIP is not installed delivery evidence. A completed
source repair and actual native output qualification are still required.
