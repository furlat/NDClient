# Accepted operation provider — 20 October 2026

Phase 4 factual-input cohort on the sole `codex-authoring-schemabump` checkout. This closes the shared accepted-operation input and native output gate for two delivered Wizard studies. Live performance and art approval remain separate.

## Actual authority and source contract

Frozen engine `211b71134ed15c89e62232587381f7e15a5961c3`, schema 16. `BaseAction._apply_action` publishes a noncanceled completion only after its accepted effect. The source receives that actual native occurrence as its opaque `operation_uuid`, with the real actor identity. It remains an ActionFact, not a SpellFact.

The installed e102 source phases are `sources/81d5f1ea0e712942dafe/phase-0.tres` (Arcane Recovery) and `sources/60bcf0b8a178e23d3a41/phase-0.tres` (scroll learning). Both expose `set_operation_state`. The original phase/art is retained. The private constructor clears review `state` and `review_states`; only the observed operation packet admits it. Recovery's source does not consume the fixture `restored_slot_ranks`; the client supplies no invented restored ranks.

Scroll learning needs the actual source item and learned spell. The last consumed scroll is absent from completed ActionFact.source_item_uuid in the real original. Its unique uncanceled descendant ItemChargeFact preserves the exact item UUID and consumption ancestry. The projector accepts that explicit fallback, never a cached or first inventory item. It excludes charges under an intervening action/spell/attack or canceled ancestor. Missing or multiple different consumed item identities remain unavailable.

Spellbook changes have a different disclosure boundary: frozen `player/sheet_facts.py:61` projects SpellbookChangedEvent, but `player/projection.py::project_hud` folds it into the **operation-level own HUD patch**. No public descendant SheetFact node exists. The projector compares the retained original own `scribed_spell_ids` with that actual HUD after-value and requires one new ID plus exactly one accepted ActionFact for this actor across the whole operation. Multiple same- or different-behavior actions are ambiguous. No sheet occurrence, emitted lineage, peer state or learned ID is invented.

## Existing paths extended

- `presentation/operation_results.gd`: pure finite projection and small immutable own-sheet witness; existing NativeActions descendant helper supplies native item ancestry.
- `presentation/compiler.gd`: one derived operation sheet map, shared by the existing lineage graphs. No new reducer, actor snapshots or publication policy.
- `presentation/components.gd`: the existing action cue arm forwards public constructor operands and `operation_state` through the ordinary native component.
- `tools/presentation_build/abilities.gd`: offline descriptor/source-interface checks.
- Existing `EffectUse.constructor_input` in `action.class.wizard.arcane_recovery.tres` and `action.wizard.learn_scroll.tres`: exact selected clips, source hand endpoint and normal finite clocks. No new authoring type, renderer branch or manager.

The sources depict their own authored notation/parchment/book. They do not add an inventory item, spellbook, rule result or world prop.

## Original recordings

`tests/fixtures/schema16/accepted-operations/` retains all original packets, command traces, scenario, recording result and provenance.

| Case | Lawful commands | Original streams | Actual disclosure |
|---|---|---|---|
| `arcane-recovery` | Level-1 Magic Missile defeats an initially wounded Goblin; actual outside-combat rank-1 Arcane Recovery | Amber 4 packets, Blue 3 | Amber action occurrence 85. Blue's sole actor died in the real preceding attack, and Blue receives no later recovery action. No absent action is manufactured. |
| `scroll-learning` | Offered Learn Spell on the actual Hold Person scroll | Amber 3, Blue 3 | Amber action 33/lineage 25; consumed item charge 31/lineage 26, parent 25; item `60b59aaf-66ff-4a52-b117-139ce0d756eb`; own HUD adds `spell.hold_person`. Blue action 28 has no item charge or own book and stays explicitly unavailable. |

Reproduce each capture from the preserved scenario using the existing worker, an absolute output path, frozen Python and frozen `PYTHONPATH`:

```bash
PYTHONDONTWRITEBYTECODE=1 \
PYTHONPATH=/home/tommaso/.cache/ndclient/dnd_engine-211b71134:/home/tommaso/.cache/ndclient/dnd_engine-211b71134/sdk/python/src \
/home/tommaso/.cache/dnd-engine/venv/bin/python -B tools/studio_cases/worker.py \
  --engine /home/tommaso/.cache/ndclient/dnd_engine-211b71134 \
  --scenario /mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/tests/fixtures/schema16/accepted-operations/scroll-learning/scenario.json \
  --out /mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/accepted-operation-reproduction \
  --timeout 150
```

The initial relative-output launch failed before the host could read its config; it remains under `.runtime/accepted-operations-20261020/arcane-recovery`. Successful unchanged capture is its separate `arcane-recovery-r2` sibling. This is not a producer failure.

## Evidence and remaining gates

`.runtime/tests/20261020T083421.482566Z/summary.json`: `accepted_operation_checks` **109/0** and existing `native_action_cue_checks` **125/0**, each exit 0, zero script/engine errors and no owned leftover processes. The focused test checks original independent reducers, exact finite component count, typed phase construction, own-sheet scope, consumed item ancestry, immutable inputs and rejection of cancellation/declaration/application, foreign/unlinked/recovered/nested charge, multiple items and ambiguous operations. It stages only the two current typed action documents in a private test cache; it does not rebuild shared outputs. Parent's coordinated abilities build `.runtime/tests/20261020T083259.617045Z` completed in 4.6 seconds with exit 0/no errors.

Parent's serialized native receipt `.runtime/tests/20261020T083414.723741Z/summary.json`: `native_accepted_operation_render_checks` **196/0**, 8.4 seconds, exit 0, zero script/engine errors and no owned leftover processes. Actual source setter/constructor identities, source-hidden framebuffer pixels in four actual published quarters, before/end absence, reverse seek/loop and private teardown pass. Blue gaps remain gaps. Source captures and per-cut evidence are `.runtime/accepted-operation-captures/` and `.runtime/native-accepted-operation-render-checks.json`. This native result is separate from the logical headless result and does not approve art or live latency.

Parent owns manifest registration: `accepted_operation_checks` headless/fast/90s/no arguments; `native_accepted_operation_render_checks` GPU/gate/240s/no arguments. Offline coverage recognizes `operation_state` only for the new `observed_operation` descriptor; a generic setter or constructor success is not render qualification.

The finite 98-selection inventory disposition is [SHARED_FACTUAL_PROVIDER_DISPOSITION_2026-10-20.json](SHARED_FACTUAL_PROVIDER_DISPOSITION_2026-10-20.json), derived from the current e102 matrix. Known rider attribution, selectors, grants, payloads and source contracts remain distinct from actionable client wiring. Glyph/Thorns baselines lacking actual triggers/contacts require lawful evidence before claiming a new backend field is necessary.
