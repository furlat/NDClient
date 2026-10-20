# Banishment: genuine departure, return and remaining provider work

20 October 2026. Completed recorder intake on the sole client branch. The
implementation design remains
[BANISHMENT_DEPARTURE_INPUT_COHORT_2026-10-20.md](BANISHMENT_DEPARTURE_INPUT_COHORT_2026-10-20.md).
No runtime/provider, Factory, engine, artwork or source-build change was made by
this intake. Native actor-history shader failures remain failures.

## Unchanged original corpus

`tests/fixtures/schema 16/banishment-departure/` contains both complete original
Amber/Blue streams, **18 packets per seat**, original scenario, command/receipt
trace, recording result and source provenance. Original runtime capture:
`.runtime/scenario-banishment-departure/20261020T051654.893924Z/`.
The frozen engine is `211b71134ed15c89e62232587381f7e15a5961c3`, schema 16 digest
`49d14bc20920f5698eb4f09e3aeece442380242cd1453893d45f94ea9fb0c8a5`.
The single owned backend PID 2793188 was confirmed closed after the capture.

The reproducible source is
`tools/studio_cases/cases.py::banishment_departure_study()`, included in
`first_cohort()`, id `spell.banishment/departure_and_return`.
Seed 2 uses normal roster grants and offered player commands only:

1. Caster executes the actual level 4 Banishment against the target.
2. Caster moves to `[3,6]` while the target is authoritatively absent.
3. The actual concentrating caster executes `action.drop_concentration`.
4. The returned target legally moves from `[4,7]` to `[5,7]`.

All ten issued commands/receipts, including ordinary turn changes, are retained.
The final movement triggers real opportunity/Shield side events; these were not
removed or renamed to simplify the fixture. No target was moved while absent,
no save outcome was overridden, and no condition/removal/return was fabricated.
The first bounded attempt succeeded.

## Actual public identities and ordered cuts

Caster: `42c9cde4-fc03-4aa4-9360-3fa1acb57db8`.
Target: `624b4c84-d297-4a3e-9b17-f267b7c4ce81`.
Banishment owner: `ecf7b3e2-db29-4bd1-a409-db454c273679`.
Concentration owner: `dc10ce5a-9a4b-4a00-9fe1-e8253b886d02`.

| Public fact | Amber | Blue |
| --- | --- | --- |
| Admission packet | sequence 8 | sequence 8 |
| Banishment admission occurrence / native lineage / parent | 58 /51 /50 | 62 /51 /50 |
| Rows in that same actor change | spatial_disposition=absent, then the condition member | Same ordered fields |
| Condition duplicate_count | null | null |
| Condition duration | Undisclosed/null | Ten rounds |
| Additional departure spatial event | Not disclosed | entity_left 56, native lineage 53, commit 53, position `[4,7]` |
| Return packet | sequence 10 | sequence 10 |
| Actual entity_entered / native lineage / commit | 118 /114 /114 at `[4,7]` | 121 /117 /117 at `[4,7]` |
| Same owner's removal / native lineage / parent | 119 /111 /110 | 122 /114 /113 |
| Later target MovementFact | sequence 17 occurrence 201 | sequence 17 occurrence 204 |

Native lineage is read from each group's actual `version_rows` occurrence map;
it is distinct from the enclosing operation group's lineage. Neither native
occurrence nor packet cursor is assumed to be global across factions.
`departure-evidence.json` records original row indices and separate
`group_lineage`/`native_lineage` fields beside independent frozen-SDK state cuts.
It is derived inspection metadata; the original packets are untouched.

### Material canonical difference between seats

Independent original SDK folds, not renderer guesses, establish:

| Cut | Amber target | Blue target |
| --- | --- | --- |
| Before cast, sequence 7 | present, position `[4,7]`, no Banishment membership | Same public body facts |
| After admission and held caster move, sequences 8/9 | absent, **last_visual_position=null**, contact membership removed | absent, **last_visual_position=`[4,7]`**, contact membership removed |
| After return, sequence 10 | present at `[4,7]`, Banishment member absent | Same public restoration |
| After target movement, sequence 17 | present at `[5,7]`; genuine Shield membership | Same public restoration/movement |

Both pre-cast and immediately returned visual loadouts are exactly equal in
the independent SDK folds. The old design's retained-position observation must
not be generalized to Amber. A departed actor may have no usable position at
all; its optical echo must use the actual immutable pre-admission capture.
Later seek state, another faction's retained position and a body temporarily
made present are not permissible substitutes.

## Precise bounded implementation seams

Production edits are held until root publishes its coherent checkpoint.
The already approved design has these existing owners:

- `PresentationCondition.capture_departure` and `ability_records.gd` round-trip
  the explicit intent to `persistent.actorHistory.captureDeparture`; build
  checking proves the sealed non-Mirror departure source. It is not frozen-body
  pose arbitration.
- `Timeline.pose_admissions` / `ConditionPose.admissions` receive the immutable
  canonical **pre-state**, not just actors. Resolve pre-cut actor/loadout,
  item-look/support, body treatment, actual track/source pose, facing and
  motion/passage operands at the existing before-apply seam and retain them
  under the actual condition UUID. Ordered canonical commits do not change.
- `ActorResources.build_private` receives the retained source/material operands;
  the existing native occurrence owns capture-only private layers and their
  cleanup. Source selection is asynchronous; no current/future actor proxy,
  general capture registry, runtime validator or GPU readback is introduced.
- The approved narrow pure extraction moves only Play's current layer transform
  equations into `ActorConstruction.layer_transform`: camera basis, contact,
  passage socket/scales, body scale and lift. Both displayed and departure
  layers call those same equations with their own actual operands. Selection,
  publication, approved graphics and source binding stay in their owners.
- NativeInputs/NativeRenderer forward original departure layers/revision/origin
  to the sealed compositor. SpellPlacement permits only that explicit, ready
  departure's authored ground registration; ordinary unseen targets still
  fail. A missing observed prefix remains missing. Non-Mirror departure's
  unused history_state receives an exact offline inapplicability proof;
  authoritative Mirror count behavior stays unchanged.

Logical operand and ownership checks are implementable without claiming the
Factory shader programs work. The original invalid serialized include programs
remain a real native gate failure until a corrected sealed package is accepted.

## Current shared-provider / scenario inventory

A fresh **read-only in-memory** join of typed sources and the installed Factory
reported 730 sources (191 spells, 281 conditions, 258 actions), 504 selections and
1,159 clips. Current cue dispatch: 216 provider-present/unqualified, 125 owner
handovers, 55 provider gaps, 18 explicit gaps, 11 authored-disabled and 6 excluded
probes. These are source facts, not completion percentages or rendered coverage.
No generated report/index was overwritten.

| Priority | Cohort / current exact seam | Genuine available evidence | Remaining boundary |
| --- | --- | --- | --- |
|1 | Banishment original departure through existing actor-context/private-layer owners | This complete two-seat cast/absence/return/move corpus, exact condition UUID and before/after SDK cuts | Client logical/optical capture is missing; Factory history shader error independently blocks positive native output |
|2 | Finite typed damage_event receiver on `recipient_contact.gd` (Freezing Sphere + Delayed Blast Fireball), and `element_contact.gd` (Dragon's Breath) | Existing baselines only create/grant/hold their spell payloads; their actual original summaries contain **no damage** | Need lawful launch/detonation/exhale recordings first. Match actual payload/caster/recipient/result ownership; do not equate a payload-owner field with a cast UUID merely because both are strings. Existing observed-result seam can then project the proven finite recipient branch |
|3 | Existing effective-handler/weapon-strike seam for Divine Smite, separated from other smites | Actual baseline `20261019T145247.222900Z` has effective handler occurrence 61, Attack 86 and a public applied Slashing result 77 whose body-release names secondary Radiant | Still **not ready**: no separately attributed Radiant applied component or emitted-lineage link proves the requested native rider. Do not turn all combined attack damage into Smite or reuse an equipped review packet |

Other apparent dictionary setters are not automatically ready:

- Glyph of Warding baseline creates/removes actual spatial owner
  `a6a5c2b2-44c1-4795-bc39-6d4ba58ec844` in sequence 8, and discloses caster sustain
  member `e726a9f3-97b1-43e4-9fb5-957929cc8fb2`. Its actual spatial state is null;
  the source additionally requires observed `armed` and suppression. Current
  membership/topology alone does not disclose those values.
- Shillelagh baseline discloses actual affected item
  `d00df81b-f6d9-4c14-879c-c6090aea9cab` under condition
  `cdd5a0b6-1ff1-4036-8a24-5b46f752a2db`. `equipped_enchantment.gd` still requires
  observed present/equipped/**not-suppressed** state. Public ConditionState has
  no general contribution-active/suppression operands, so idle effectiveness
  cannot be filled from a membership alone.
- Dragon resistance/breath variants, passive divine rider attribution,
  Counterspell's moving incoming path and rolling Blur histories retain their
  prior precise gaps. The new weapon delivery and unaccepted art were not
  imported or used as evidence in this inventory.

This intake qualifies actual recording/reducer evidence only. It does not
claim a new provider has rendered, that the full native suite passes, that the
approved graphics changed, or that timing/performance/art acceptance is complete.
