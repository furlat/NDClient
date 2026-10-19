# Actor-context candidate — 19 October 2026

**20 October authority update:** The user explicitly required all work in the
main client. This cohort is merged at `7ef2f3f8` into
`C:/Users/tommaso/Documents/Dev/NDClientGodot` /
`codex-authoring-schemabump`, the sole active branch. The former implementation
worktree is inactive. The private-publication restriction below is superseded;
it must not be used to move current work away from main.

The complete installed package remains `production-bindings-c494177f9ef03e3d`
and the frozen engine remains `211b71134` / protocol1 / schema16.
`native_actor_context_render_checks` is now a required native gate:34 assertions
pass, but two real Factory shader errors fail the gate. Output, colour parity
and first-draw performance remain unqualified. The human deferred this Factory
blocker and requested continuing independent client work. Do not patch sealed
Factory shaders in the client. [Exact Factory follow-up](FACTORY_RUNTIME_FOLLOWUP_HANDOUT_2026-10-19.md).

The sections below retain the original candidate's implementation and measurement
history; references to private worktrees, deleted test APIs or migration-owned
status describe the earlier run only.

## Existing shared seams changed

- `native_inputs.gd` supplies actual ordered visible actor layer nodes, private
  material/source revisions, pivots/ground heights, camera, capture dimensions,
  actual actor contact origin and the renderer's RGB24 reversed-Z depth texture.
  There is no GPU readback or substituted actor. `history_state.duplicate_count`
  comes only from disclosed ConditionState, with a named absence gap.
- Zero-delay, nondeparture constructor specifications can sample the current
  pose directly. Blur/departure histories remain unavailable; current poses
  sampled at older clocks are not genuine predecessors.
- `compiler.gd` keeps only the small disclosed count in future native preparation
  operands. It continues to remove complete conditions, runtime clocks and
  removal/initial state from that boundary. Publication consumes the actual
  ordered condition normally.
- `native_spell_renderer.gd` gives actor-context sources their already allocated
  private pass bit at construction, and allocates their compositor using actual
  current context in optional preparation while output remains hidden. Ordinary
  native paths retain their existing initial mask and clock behavior.
- `effect_package.gd` owns the complete occurrence for actor-context sources,
  including compositor siblings of the source's ordinary visual root. It hides
  that occurrence before tree attachment. Main-World3D output geometry added
  later is registered only on tree membership changes; own-world capture meshes
  stay outside submitted output geometry. Removal and close prune/disconnect
  callback references. No per-pose tree traversal or new manager.
- Deactivation withdraws actor context once through the public source setter.
  This suspends capture passes as well as hiding output. Normal sampling restores
  the actual context. Teardown closes the complete private occurrence.

`history_allocated` means compositor CPU objects allocated. It does not certify
GPU warming. Forward playback with a real preparation lead sets it before the
cue. Immediate restore into an already active condition may allocate during its
first sample; that remains an explicit readiness/performance limitation.

## Evidence

Run from the private worktree:

```bash
bash tools/run_tests.sh --only native_input_binding_checks,schema16_native_preparation_checks,native_immutable_preparation_checks,native_item_owner_checks,native_item_render_checks
bash tools/run_tests.sh --only native_actor_context_render_checks
```

Five affected regression gates pass **254 checks** with zero script/engine errors:
`.runtime/tests/20261019T212230Z/`. Actual created Flame Blade's 29 native output,
view, seek and ownership checks remain green. The existing live-exit ObjectDB
warning is not resolved by this work.

The actor-context forward replay uses original actual schema16 journals for both
factions under `tests/fixtures/schema16/mirror-image/`; only Amber's rendered
path is qualified by the candidate test. The gate exercises application from
ordinary initial state, current count3, four camera views, dynamic same-world
output membership, context withdrawal/resumption and reverse restore.

Latest repeat `.runtime/tests/20261019T212433Z/` passes **34 assertions** with zero
script errors, but **fails overall** with two Factory shader compilation errors.
Its manifest row is explicitly `owned-by-migration`, not green. Both serialized
source shaders retain unresolved preprocessor code/integration includes; the
exact Resource paths and original logs are in the Factory handout. Changed pixels
from an invalid shader are not a correct-output witness. No source monkey patch,
legacy-lighting rollback or counterfeit integration directory was added.

At640×480: constructor9.045ms (`_ready`8.966ms), max inclusive context allocation
6.318ms, input binding.093ms, native sample5.087ms. Invalid shaders prevent GPU
performance/colour qualification; overlapping phases must not be summed. Sample
at zero then immediate suspension allocates objects without proving GPU first draw.

Two older replay checks run during this chunk also fail before rendering:
`native_spell_playback_checks` (three prior-state admission failures, known-red)
and `native_spell_retention_checks` (five stale Gallery/Shield/Web recording
admission failures). Original logs: `.runtime/tests/20261019T211919Z/`.
They do not replace the new current-schema replay gate and are not described as
passing or silently updated to fabricated input.

Bounded plan/correctness/anti-slop review found and fixed the missing future
count operand and geometry-watch callback cycle. Final review: no additional
ownership/scope blocker; keep the candidate private while source qualification
fails. No reviewer launched Godot or changed files.

## Remaining gates

Factory: compile both delivered binary shaders in the actual consumer, fix
neutral assembled-colour compatibility with approved receiving/body materials,
prepare expensive source construction and compositor first use. Follow the
existing Factory repair plan and return one complete sealed successor package.

Client: re-run the current candidate with that package; compare actual neutral
capture and intentional spectral output; record real3→2→1→removal transitions,
concurrent shared-rig owners/factions and bounded compositor memory/GPU cost.
Qualify short-queue/cold first use and immediate active-condition restore without
clock holds. Then implement actual rolling predecessors for Blur and real
logical departure/current-view recapture for Banishment. Do not mark those
providers complete from this zero-delay context slice.

The full migration estimates remain unchanged: providers43%, Factory migration68%,
scenario depth42%, final performance10%. These are rough implementation estimates,
not percentages of passing visual/runtime gates. The overall plan remains active.
