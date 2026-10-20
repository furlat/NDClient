# Historical native hit materials: bounded next cohort

Design only. No production change, new recording, build, GPU run or visual
approval is claimed. This extends the master plan's existing authentic actor
history/departure work, following the separate non-native damage-flash proof
(`native_actor_history_material_transition_checks`: 4,806 checks, zero failures,
receipt `.runtime/tests/20261020T082003.334192Z`).

## Current ownership and the actual gap

- `Timeline._history_draw_operands` already captures the real pre-cut actor,
  outfit/item looks, material operands, layer samples and motion. It explicitly
  refuses native-hit framebuffer and Factory body-treatment overlaps. Keep those
  refusals until their respective inputs are prepared.
- `NativeInputs.prepare_history/prepare_departure/_private_layer_context`
  already realize private earlier layers from the original consumed prefix.
  `Conditions.parameters` is the existing uniform producer for those layers.
- `NativeSpellHits` extracts an immutable age-zero material template through
  `EffectPackage.hit_material`, applies the exact authored overrides and owns
  private `NativeMaterialSurface` evaluators. The live hit's `ViewportTexture`
  changes whenever its source clock changes; it is not an old-frame snapshot.
- Factory `actor_history.gd::_snapshot` shallow-copies layer materials. Texture
  references remain shared. Its colour/depth viewports render the selected old
  material later; they do not freeze every material texture at admission.

Consequently, neither borrowing the current hit texture nor repeatedly sampling
one historical evaluator is correct: both would mutate older retained poses.

## Smallest coherent implementation

1. Keep the real sampled flash component in the existing logical material
   operands: component/result identity, target actor, exact historical `age_ms`,
   native-hit clip/definition and finishing profile. Keep journal and canonical
   state unchanged. No texture or native node enters a Timeline cut.
2. Expose/reuse the existing `NativeSpellHits` template preparation, without
   borrowing or resampling its live occurrence records. Continue using the
   existing source admission and preparation budget.
3. In the existing history/departure handle, own a private material evaluator
   for each distinct actual historical hit evaluation. Share immutable shader,
   texture and template Resources. Once drawn at its requested source age, that
   evaluator's texture stays unchanged while captured materials reference it.
   No GPU readback, replacement character atlas, new manager or source edit.
4. Require the real post-draw completion and matching requested/drawn age before
   binding the texture. `NativeMaterialSurface.ready` alone is insufficient for
   a newly requested age: its current live sampler keeps `ready` after an age
   change. A one-shot historical evaluator must not be resampled while pending.
5. Make a private shallow copy of the capture's material/flash operands, add the
   prepared `native_surface` plus its actual ramp/finishing, then call the same
   `Conditions.parameters` and `Construction.bind_source_values` path. Preserve
   body alpha, normals/depth, source registration, view and source revisions.
   Feed the actual layers to the existing history helper at their original age.
6. Keep these evaluators in the existing handle teardown/pruning lifetime.
   Releasing or recycling a texture while a retained material still uses it is
   incorrect. View recapture may reuse an immutable UV-space evaluation;
   initialization/source revisions and distinct real hit identities cannot.

Expected production scope: narrow `timeline.gd`, `native_inputs.gd`,
`native_spell_hits.gd` and, only if needed, an explicit completed-age predicate
in `native_material_surface.gd`. The native renderer's existing preparation
entry may need to forward readiness; no reducer/compiler clock reorder or
condition lifetime rewrite is required. Source topology sharing stays separate
from distinct evaluated hit textures.

Each evaluator currently has a 256×256 target. Count actual texture format,
depth attachments, distinct ages and owners in qualification. The 240 ms Blur
window is bounded, but this design does not claim a measured memory/frame cost
or permission to truncate real captures.

## Source contract limits

An authored absolute material clock is client-bindable through the existing
template path; Fire Bolt declares `clock_parameter="source_clock"`. A clockless
material is eligible only with actual static-source proof; Magic Missile's
selected original Box1 shader has no `TIME`. An empty clock field alone is not
proof that an arbitrary material can reproduce an earlier state. Native GPU
particles, external mutable textures and unbound clock dependencies remain
explicitly unsupported until their real source contract provides reconstruction.

Factory body-treatment leases are a separate next cohort. Their
`body_program.gd` reads `vfx_package_clock` through `factory_body_slots`;
`body_receiver.gd` changes shader/stack bindings on actual actor materials.
Shallowly copying such a material retains future clock data and potentially a
recycled slot. Authentic reconstruction needs the actual historical selected
source/owner state and a retained private source clock, or a source-supported
frozen-clock override. Do not clear
`departure_native_body_treatment_not_bound` as part of native-hit integration.
Appearance-opacity leases remain separately explicit too.

## Required original evidence and gates

The durable Blur fixture records actual 14 Slashing opportunity-attack damage,
not a native spell hit. The Banishment departure/return fixture has no damaging
spell command. These recordings do not prove native-hit overlap. Obtain a legal
original two-seat spell-hit/history interaction before claiming that scenario.

- Headless: exact original applied result/component/actor identity and source
  age; no flash before impact or after its real end; retained earlier treatment
  versus restored current body; separate removal/reapply owners; immutable
  original data and deterministic seek. Unsupported source clocks stay gaps.
- Native: ordinary Play/Recording, actual source material and draw-fenced
  historical evaluations, earlier/current texture independence, source-specific
  pixel comparison at matching ages, four views, concurrent owners, reverse
  seek/loop, real removal and cleanup. Changing the current live hit must not
  change any frozen historical evaluator or captured material texture.
- Report source availability, provider binding, real scenario evidence and user
  visual approval separately. Keep the existing non-native 4,806-check proof as
  its own qualified capability; it does not qualify this proposed cohort.

## Coherence boundary discovered during private implementation

The first five-file client draft and two draft tests exist only under ignored
`.runtime/consolidation/native-hit-history/private`; they are not production
changes and have not run. They can reconstruct one-shot earlier hit evaluators,
but that alone does not fix ordinary live history: Factory's normal sample also
retains the current mutable native-hit texture through a shallow material copy.
Per-frame prefix replay would append that mutable current dependency again.
The parent explicitly rejected shipping that partial solution.

The required source-owned immutable capture/fence/lifetime contract and genuine
new Fire Bolt/Magic Missile originals are described in
[the Factory handoff](FACTORY_NATIVE_HIT_HISTORY_CONTRACT_HANDOFF_2026-10-20.md).
The Fire Bolt original includes real owner replacement; Magic Missile has no
recorded authoritative end. Do not retain the earlier recording-gap assumption
or infer retirement from failed requests. No production guard was removed.
