# Required current Studio lifecycle originals

20 October 2026. Test-only repair on the sole `codex-authoring-schemabump`
checkout. No Factory/engine edits, fabricated membership/removal, runtime
validator or alternate effect is part of this cohort.

`native_persistent_studio_checks` previously read
`generated/studio_spell_case_inventory.json`, whose ten families point at
`.runtime/studio-spells-20261018/*` and the retired wire contract. Its required
scope remains **Bane, Command, Guidance, Light, Mage Armor, Resistance,
Sanctuary, Shield, Shield of Faith and Web**, plus Ice Knife's one-cast/multiple
application trace. A new family or a cast-only journal is not equivalent.

The existing current library baselines have 7–9 original Amber packets each.
Direct original-wire inspection found their expected condition applications but
**zero condition removal rows in all ten baselines**. They cannot qualify the
retained removal/close/seek assertions. The durable Gallery has an actual Shield
removal, and the durable Web baseline proves actual disclosed spatial/body
owners; neither supplies the other eight families' full lifecycles.

## Recorder scope and exact existing seams

Use `tools/studio_cases/adapter.py` through its existing worker and frozen engine
`/home/tommaso/.cache/ndclient/dnd_engine-211b71134`. Existing `actors(spells)`
in `cases.py` supplies lawful caster/ally/enemy roles. Existing actions are
`hold_walk`, `end_tracked`, `tail_walk`, `equip`, ordinary `end_turn` and offered
spell/action commands; no new recorder primitive is needed.

For each family retain both untouched journals, scenario, recording result,
issued command trace and engine identity. Require the actual named membership
and the same UUID's authoritative end. A failed save/setup or a missing end is a
failed recording with its exact reason, never a reason to edit wire values.

| Family | Actual lawful sequence | Source evidence / required check |
|---|---|---|
| Bane | Cast on the disclosed enemy with `track=true, track_condition=condition.spell.bane`; move while held if legal; `end_tracked(strategy=concentration)`; walk after removal. | Current baseline discloses Bane and Concentrating. Preserve real save outcome; retry lawful seed/setup if no Bane applies. |
| Guidance | Cast on ally, track `condition.spell.guidance`; holder walk; drop actual concentration through `end_tracked`; holder walk. | Typed spell `owner_ids` selects that exact condition; current baseline has the actual concentrating membership. |
| Light | Cast on disclosed actor, track `condition.spell.light`; holder walk; end actual concentration; holder walk. | Current baseline actually discloses Concentrating. Frozen `evocation.py:3935–3977` owns the real light source by the condition and removes it on release. Follow current engine state rather than importing a different rules assumption. |
| Resistance | Cast on ally, track `condition.spell.resistance`; holder walk; end actual concentration; holder walk. | Current typed owner and baseline concentrating membership are present. This is the saving-throw cantrip, not elemental resistance. |
| Shield of Faith | Cast on ally; walk; a real incoming attack if offered; drop concentration; walk after removal. | Existing `spell.shield_of_faith/defend_then_remove` recipe already expresses this in `cases.py`; record it unchanged where viable. |
| Command | Cast the actual offered Grovel/Halt/Flee variant on enemy and track the exact selected branch; caster movement while target has the condition; advance ordinary turns until that same UUID ends; target walks if legally restored. | Frozen `enchantment.py:1568–1590` and its turn handlers own next-turn activation and cleanup. Do not demand movement from a target whose actual branch denies its turn. |
| Mage Armor | Start the recipient unarmored with `armor.chain_mail` in inventory; cast and track `condition.spell.mage_armor`; walk; `{"do":"equip","by":"ally","slot":"Body","item":"armor.chain_mail"}`; walk after removal. | Frozen `abjuration.py:447–518` explicitly removes Mage Armor on a committed body-armor equip. `BodyPart.BODY` is exactly `"Body"` in `dnd/core/equipment_types.py`. Avoid an 8-hour turn loop or assumed clothing removal. Retain the real item UUID and equip command. |
| Sanctuary | Cast on ally, track `condition.spell.sanctuary`; ally walks; ally performs a real hostile attack/spell; ally walks after ward removal. | Frozen `abjuration.py:2820–2860` removes the exact ward when its protected actor acts against an enemy. A hostile action is a lawful end, not a client-made expiry. |
| Shield | Extend the existing real Magic Missile interruption setup; track the protected actor's actual Shield UUID; advance to its actual next-turn expiration; walk afterward. | Existing `spell.shield/reaction` proves application/interception; Gallery separately proves removal. New compact original must retain both with actual intercepted-event/condition identity. |
| Web | Cast actual Web area containing a recipient, inspect original spatial UUID/cells and actual restrained memberships; walk only where legal; drop actual caster concentration; preserve the real membership/area cleanup if emitted. | `spell.web.tres` names `spatial_effect.spell.web`; body restraint is a separate UUID. The historical gate exempted Web from a required source-close interval; do not invent one. Preserve actual spatial-owner controls and exact source clocks. |
| Ice Knife trace | Preserve an unchanged current cast with actual primary contact/burst/recipient applications, preferably multiple real recipients. | One actual cast/body owner; applications do not demand duplicate caster/projectile tracks. No manual events or outcome packets. |

## Durable fixture contract and pending gate

Write originals under `tests/fixtures/schema16/native-persistent-studio/` and
`cases.json` beside them, or pass `--cases=<durable descriptor>` explicitly.
The descriptor retains the existing test format:

```json
{"cases":[{"id":"native-spell-bane","spell_id":"bane","perspectives":[
  {"id":"amber","journal":"res://tests/fixtures/schema16/native-persistent-studio/bane/amber"},
  {"id":"blue","journal":"res://tests/fixtures/schema16/native-persistent-studio/bane/blue"}
]}]}
```

Include exactly one `native-spell-<family>` entry for every required family and
`native-spell-ice_knife` for the area trace. Copy unchanged entire required
prefixes; retain original provenance beside them. This is test input metadata,
not a runtime registry or a new authoring format.

The test now requires both independent seats and compares each final Studio
restore with its independent original SDK fold. Its existing UUID/phase clocks,
removal intervals, source replacement, Shield interception evidence and missing
coverage checks remain strict. Until genuine originals are recorded, the gate
stays **red/unqualified** with each missing family named. It has not been run
or promoted by this repair lane. A metadata/index test provides no native draw
or artistic approval.

## Other two test repairs in this cohort

- `native_light_cookie_checks`: use the actual asynchronous `_effect_cookie`
  result (`ImageTexture`/null), wait its existing worker, and compare the carried
  immutable image. Retain exact native GradientTexture bytes, exact attenuation
  identity, shadow image registration and automatic inactive retention bound.
  Source review found `_trim_effect_cookies` has no production caller; this real
  ownership gap remains a required failing control, not a test-only manual trim.
- `native_optical_media_checks`: use unchanged durable schema16 Gallery originals,
  actual typed source packet geometry and the existing optional-selector
  readiness before asserting budget/residency. Passive publication receipts
  remain labelled accounting controls, not uploaded texture/render proof.

No GPU or source build was launched. Root owns serialized qualification,
manifest status and the recording worker. This finishes the bounded stale-input
repair while retaining actual provider, source and full-suite failures.
