# Typed spell variants — shared application dispatch

20 October 2026. Existing master plan phases 4–5. This is a shared source/dispatch/preparation implementation; it does not accept the imported alternative artwork or complete its gameplay branches.

**Superseding production receipt:** [integration closure](PRODUCTION_INTEGRATION_CLOSURE_2026-10-20.md).
Three actual saved-outcome predicates are now authored. The zero-predicate
statements below describe this document's earlier infrastructure checkpoint.
The130 imported alternatives are not130 missing gameplay implementations: many
are already condition/spatial/item/event-owned, review alternatives or rejected
native weapon bodies. Their count is not a completion denominator.

## Implemented ownership

- `PresentationSpellVariant.when` is an explicit conjunction of exact disclosed `SpellFact` values. Initial supported fields are `attack_outcome` (`Hit`, `Miss`, `Crit`, `Crit Miss`) and `target_kind` (`creature`, `object`), each with an authored nonempty array of alternatives. Unknown or null values keep the baseline. `kind`, `value`, IDs and titles never select an effect.
- Offline build checks reject unknown fields, noncanonical values, empty value arrays, overlapping active predicates, changed caster-body recipes, and base cue-index ownership policies applied to replaced cue lists. `dispatch_gap` can retain a known source limitation separately from an authored predicate. No runtime validator, registry or reducer was added.
- The existing native spell Resource retains every alternative's predicate, selection, recipe, status, requirement source and prepared requirements, including undispatched drafts. The behavior cache retains only immutable source records. Each application borrows its own selected record; neither sibling outcomes nor the last sampled variant replace the cache.
- Compiler, delivery/components, requirement projection and event trace consume that same actual application choice. The original cast body and native cast owner stay single. Variant recipes cannot replace the original caster body. Miss impact suppression remains the baseline unless this actual Miss value is explicitly authored and the alternative supplies a replacement effect list. A target-kind-only choice or effects-empty inherited choice cannot imply successful impact on a Miss.
- Only the actively selected capability adds eligible alternatives to the existing optional source plan. In `Play._native_startup_request`, these have `due_ms=INF`; readiness requires only actual observed/received source deadlines. An exact received selected application becomes required through the existing compiled component. Other offered capabilities and catalog startup continue to request their baselines.

## Complete imported inventory and boundaries

The focused build-in-memory inventory on the current source contains **130 alternatives, 240 alternative cues, 43 native spell owners**. All 130 alternatives are serialized. **Zero production predicates were activated.** The older 39-owner snapshot was not used as a hand count.

The full typed-source join additionally retains **3 alternatives in 3 deliberately native-disabled owners** (Bless, Call Lightning, False Life), for **133 alternatives / 46 owners overall**. Their two effect cues remain `authored_disabled`; they are not admitted through the native-enabled record path or silently switched on.

The native metadata and `tools/factory_binding_coverage.py` retain missing public-fact predicates separately from supplied channels, unbound constructor inputs, source status, scenario evidence and visual approval. The join output is `.runtime/consolidation/typed-variant-binding-coverage.json`; it does not claim that 139 source-present cues were played or reviewed.

Known examples requiring authored/public semantics before activation:

| Alternative | Exact remaining boundary |
|---|---|
| Ray of Sickness miss | `review_endpoint_position_not_bound`: the imported cue contains fixed review point `[2, 0.8, 0.65]`. No new optical miss endpoint/offset was invented. |
| Ray of Sickness hit/saved | Attack `Hit` alone does not prove the actual save result. |
| Sorcerous Burst / Chromatic Orb elemental alternatives | Attack result alone does not choose an element. |
| Acid Arrow miss/patch alternatives | Actual source-compatible delivery and disclosed spatial/result ownership still require separate qualification. |
| Other imported forms, riders, saves, areas and drafts | Empty predicates remain `public_fact_predicate_not_authored`; names are not evidence. |

## Independent original evidence

`tests/fixtures/schema16/typed-variants-miss` contains both complete untouched journals, scenario, commands, recording header and provenance. One legal fixed-seed encounter executed target Dodge, then one level-1 Ray of Sickness against that armoured target:

- Amber sequence 7, occurrence **45**, actual `attack_outcome="Miss"`.
- Blue sequence 7, occurrence **53**, actual `attack_outcome="Miss"`.
- Actual source `c1e9601c-af74-49ea-955d-58d4f1b9b2c9`, target `6a850ea5-5f5d-49d1-86ed-ea8f9b2fd233`, positions `[3,7]` → `[6,7]`; no damage fact.

The initial relative-output host-start failure is retained under `.runtime/typed-variants-miss-20261020`. It executed no backend/commands/RNG. The same scenario/seed succeeded once after correcting the output to an absolute path under `.runtime/typed-variants-miss-20261020-original`; no outcome retry occurred.

`tests/fixtures/schema16/typed-variants-mixed-original` preserves the original Scorching Ray baseline's independent three-application cast. The logical gate first compiles the genuine facts, then separately labels Hit/Miss/Crit mutations as **compiler-only synthetic controls**. These are never represented as recorded native outcomes or folded authoritative after-values. The original bytes remain unchanged; one cast/body and private sibling selection are asserted.

## Qualification

- Abilities build, first metadata version: 5.1 seconds, exit 0, no script/engine errors/leftovers; `.runtime/tests/20261020T091156.384439Z/summary.json`. A final metadata correction only adds `replaces_effects` for explicit Miss impact policy; parent owns its serialized rebuild.
- `native_spell_variant_checks`: **627 checks, 0 failures, 0 script/engine errors, 0 leftovers**, 4.1 seconds; `.runtime/tests/20261020T091518.950166Z/native_spell_variant_checks.log`.
- That gate proves actual Miss facts and independent canonical drain; exact predicate/default/unknown behavior; offline rejection controls; immutable sources/private cues; explicit Miss impact and unrelated/inherited negatives; complete metadata; optional-vs-required actual Play source planning; mixed sibling one-cast ownership.
- `native_spell_variant_render_checks`: syntax checked with headless `--check-only`; **47/0 GPU checks pass**,8.4seconds, zero script/engine errors and owned leftovers,
  `.runtime/tests/20261020T091645.582466Z/summary.json`. It uses the same actual Miss journals, an explicitly test-only predicate and the source-compatible existing Ray delivery. It asserts ordinary Play admission, actual actor endpoints, native source identity and positive pixels, independent canonical seek/loop and release. This does not claim the imported fixed-endpoint Miss artwork is bound or accepted.
- Same-task correctness reviewer identified and rechecked the unrelated-variant Miss suppression issue. Corrected helper requires both actual explicit Miss predicate and authored replacement effects. No further material blocker was reported in that bounded pass.

Parent commands: `tools/run_tests.py --only native_spell_variant_checks --jobs 1`; native row `native_spell_variant_render_checks`, GPU, timeout 300 seconds, args `[]`. Parent owns source builds, manifest, serialized GPU qualification and final receipts.

Final serialized abilities rebuild passes4.6seconds/exit0 with no script/engine
errors or leftovers (`.runtime/tests/20261020T091601.973300Z/summary.json`). The
combined fast165/165 gate passes in `.runtime/tests/20261020T091644.415567Z/summary.json`,
including627/0 variant checks. No current production alternative is inferred
complete from these explicit test-only bindings.

## Persisted recipe ownership correction

The first gate checked builder-process Dictionary aliases. Godot's binary
Resource serializer writes containers by value, so those aliases did not survive
disk admission. This was a metadata ownership gap; it did not create another
cast, body animation or texture upload.

The build now persists an explicit `inherits_recipe` flag and omits inherited
recipe/requirements payloads. Overriding recipient recipes omit the common cast.
The existing physical source reader attaches the base recipe, requirement rows
and caster Dictionary once, before publishing that Resource to worker/occurrence
owners. A nonserialized admission flag makes repeated reads idempotent. There is
no per-occurrence equality validation, recipe cloning or additional owner type.

Actual compact save/reload, cold `Sources.find` admission, recipient overrides,
unchanged original sources and matching/compiler/preparation controls pass
729 logical assertions; native output remains 47/0, with no script/engine errors
or owned leftovers (`.runtime/tests/20261020T093914.107060Z/summary.json`). The
production inventory check additionally examines all 130 actual disk-loaded
alternatives in the final fast lane. These tests do not activate any production
predicate or change approved art.

Final fast lane: **165/165**, including **1,141 variant assertions**, with zero
script/engine errors or owned leftovers;
`.runtime/tests/20261020T094040.778353Z/summary.json`. The actual abilities rebuild
also passed in 5.0 seconds (`.runtime/tests/20261020T093728.618878Z/summary.json`).
