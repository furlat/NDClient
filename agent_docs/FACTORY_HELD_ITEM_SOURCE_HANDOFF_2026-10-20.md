# Factory follow-up: existing held-item decorations

20 October 2026. Shared-provider plan phases 4–5. **Source-readiness handoff only:** no code, source/art, constructor-generation system, recording or test was changed for this investigation. The human can forward this with the typed-variant and native-hit-history handoffs.

## Common ownership contract

The client already owns the actual item/effect membership, current held/inventory location, displayed equipment slot and admitted source optical geometry through `NativeItems`, ordered SDK item rows, `NativeWeaponInputs`, `EntitySurface` and `SpellPlacement`. These inputs do not require new wire fields. Cached `ItemRecord` metadata alone is not current existence or permission to render.

The **item/effect owner is immutable; its current holder is mutable**. Please make the existing snapshot setter accept the actual current holder and placement/visibility facts for the same item/effect without restarting its source clock or replacing its native art. Moving, covering, unequipping or transferring an item must not manufacture a new gameplay owner. The client will supply the current actual item transform separately; the snapshot's `point` field is not currently a placement API.

Use a retained, private constructor-generation alternative only if a source identity truly must be immutable. This is not a request for a client manager or a new general construction framework. Source Resources/material programs remain shareable; mutable occurrence clocks, particles and packets remain private.

A permanent decoration also needs a **source-qualified bounded seek/absolute/prepared clock contract**, including backward seek, late restoration, pause and loop. Repeated setters alone do not establish this. Do not relabel a forward simulation as seekable, invent a modulo clock, replay an unbounded permanent lifetime on the main thread, or borrow a mutable current occurrence for an earlier time.

## Continual Flame: exact source gap

- Clip: `review/continual_flame/back/lifecycle`.
- Phase: `assets/vfx/sources/c8565a88a3ee6c18d1e1/00.tres`.
- Program: `assets/vfx/sources/63efbe77094fc90312ab/item_flame.gd`.
- Wrapper: `assets/vfx/clips/ab9f1098a38497b11265f372/construct.gd`.

The constructor fixes `item_uuid`, `effect_uuid`, `behavior_id` and **`holder_uuid`**. `set_item_snapshot` cannot rebind the holder: `admitted()` compares `packet.actor_id` with that constructor holder on every update. Constructor review literals must never reach gameplay unchanged.

The setter receives actual `item_uuid`, `effect_uuid`, `behavior_id`, `actor_id`, membership/visibility facts, `socket_found` and positive `normal_support_points`. Optional `covered` / `suppressed` source guards are not new universal server fields. Source optical admission/registration is a client rendering fact; label it accordingly. Missing actual item registration, hidden/inventory-only items and undisclosed membership stay unavailable rather than receiving a proxy weapon or guessed hand.

The source preserves private age while hidden, which is appropriate. Its nested native flame/base sampler is nevertheless forward-only (`base.gd` advances `while tick < desired_tick` at 144 Hz), and the installed approach explicitly declares **`seekable=false`**. A permanent effect restored much later cannot be qualified by a short forward fixture. Please supply and qualify the bounded clock/preparation contract before claiming coherent live transfer plus replay seeking.

### Genuine current baseline, not a held-output witness

Original complete journals:

`res://.runtime/studio-library/cases/spell.continual_flame__baseline/20261019T142323.291908Z/{amber,blue}/journal`

Amber sequence 8, ActorChange occurrence **47** discloses:

- holder actor `027279f3-6b08-40e7-9259-635743d153b9`;
- item `db1c5335-586d-41ba-9ea4-a04ee62f0d38`;
- effect `67f01492-d9f2-42fc-9186-30509757b3a5`;
- behavior `condition.spell.continual_flame`, permanent duration.

Spell occurrence **48** targets that exact item with `target_kind="object"`. The initialization identifies it as **`consumable.potion_greater_invisibility` in controlled inventory**, not the Factory review's held Club. Blue receives **no corresponding item-effect membership**. Preserve both limitations: no fabricated held body and no cross-faction identity borrowing. This is useful factual evidence, not held pixels, transfer or removal qualification.

## Two finite `enchantment_input` consumers

Both use `assets/vfx/sources/7ba5fd40e010d019813f/equipped_enchantment.gd`. Its constructor fixes the actor role; both enchantment and entity-geometry setters compare against that value. Construction must bind the actual actor and begin optically inactive. The source accepts `actor`, `present`, `observed`, `equipped`, `suppressed` plus real measured item geometry and endpoints. These finite approaches declare `seekable=true`, still requiring real current-geometry/clock/output qualification.

| Consumer | Current disposition |
|---|---|
| `shillelagh_native` — phase `sources/0d3ca8787a4e1bf4187a/4b01bea1b3ffc00e.tres` | **Do not enable a second finite coating.** The existing `condition_shillelagh_persistent` prepared application/sustain/removal already owns `condition.spell.shillelagh` on `recipient_weapon`. Add explicit typed handover of the redundant finite spell cue to that lifecycle when integrating this cleanup. |
| `spells/true_strike/back/lifecycle/source-de7fb5137ad74acf` — phase `sources/4fabb29e98f91acabd18/f7108fc4826eb7a1.tres` | Currently **unassigned**. No automatic art switch. A future assignment must bind the actual same-cast equipped attack/item, preserve its source clock and qualify this exact source. |

Shillelagh originals:

`res://.runtime/studio-library/cases/spell.shillelagh__baseline/20261019T144916.773864Z/{amber,blue}/journal/0000000000000008.json`

Both seats disclose condition `cdd5a0b6-1ff1-4036-8a24-5b46f752a2db`, `affected_item_uuid=d00df81b-f6d9-4c14-879c-c6090aea9cab`; Blue's duration is null. Do not invent its private duration. Unequip/change follows actual condition membership and current equipment.

True Strike originals:

`res://.runtime/studio-library/cases/spell.true_strike__baseline/20261019T143804.349073Z/{amber,blue}/journal/0000000000000008.json`

Actual attack **54** identifies `source_item_uuid=f7383041-d87a-468e-a7fe-698fc13cc260`, `source_item_id=weapon.dagger`, `weapon_slot=MELEE_MAIN`, outcome Miss; actual spell **55** is its True Strike ancestor. This proves a concrete legal item/attack association, not persistent item enchantment or acceptance of the unassigned alternative.

## Remaining 17 legacy ownership clips

These remain separate from the already prepared measured-surface sources. Their additional source predicates are not universal wire requirements.

| Exact cohort | Count | Remaining public/source boundary |
|---|---:|---|
| `bg3-36/magic-weapon/magic_weapon_native/{windup,application,sustain,retire}` | 4 | Legacy constructor ownership and contribution semantics require exact public attribution. Frozen `MagicWeaponEffect` does not publish `snapshot_item_effect`; existing baseline journals have no item-effect membership. Do not substitute an actor condition/cast ID for a required item effect. |
| `bg3-36/divine-favor/{divine_favor_native,divine_favor_miss_native}/{windup,application,sustain,hit,retire}` | 10 | Actual caster condition is public. Legacy hit input additionally requires the exact equipped Hit/Crit and attributed rider damage component; generic Radiant damage is insufficient. Miss alternatives also need actual explicit predicates. |
| `divine-class-study/divine_sacred_weapon_study/{0-application,1-sustain,2-retire}` | 3 | Frozen Sacred Weapon does not expose an item-effect snapshot through this route. Actual cast/light does not fabricate its persistent item-effect/contribution owner. |

Shared legacy `sources/6ee57b6fb1e6037a0826/ownership.gd` fixes owner/effect identities at construction. `contribution_active` concerns the actual owner/arbitration semantics; `decoration_admitted` concerns renderer admission. Neither is permission to invent a missing gameplay fact. Prepared measured branches do not require those legacy flags. Active legacy Antimagic suppression was retired in schema 16; an actual explicit override still matters, but do not request an invented old wire field.

## Six deliberately forbidden native weapon-body consumers

Keep disabled under the user's modular-sprite policy:

- `bg3-36/flame-blade/{native_created_item,miss_created_item,inventory_created_item,transfer_created_item}`;
- `items/created/flame_blade/appearance`;
- `items/created/devotees_mace/appearance`.

Their source availability is not a missing loader/provider task. Wielded physical weapons remain the original separate modular sheets with native decoration; no substitute native blade/mace body. Spiritual Weapon remains a separate summoned-actor problem.

Source presence, factual projection, source readiness, original scenario coverage, native output and human visual approval must remain separate. This handoff makes no new qualification or artwork-acceptance claim.
