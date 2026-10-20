# Weapon enchantment lifecycle: real SDK evidence

20 October 2026, after checkpoint `bc123c49`. Bounded recording cohort only;
no runtime, renderer, typed spell, Factory, manifest or catalog changes.
One frozen backend ran at a time and each was closed by the existing host's
`finally` cleanup. No GPU, Godot, source build or client test was launched.

## Reproducible setup and originals

`tools/studio_cases/weapon_enchantment_cases.py::studies()` returns three ordinary
scenario dictionaries for the existing recorder worker. The caster is the
supported authored `creature.generic_caster`, level 20/caster level 20, with its
actual modular `appearance.presentation_kind="layered"`, an initially equipped
`weapon.quarterstaff` in `MELEE_MAIN` and an inventory `weapon.longsword`.
The opponent is an ordinary adjacent Ogre. Seed 2 is unchanged throughout;
no outcome/condition/damage was injected and no seed fishing occurred.

All casts explicitly target self; Magic Weapon and Shillelagh select the actual
offered `form=MELEE_MAIN`. Ordinary turn endings replenish actions between cast
and attacks. Concentration is dropped through its real offered action; Shillelagh
ends through a real unequip. The replacement sword is legally equipped and used.

Durable originals:
`tests/fixtures/schema16/weapon-enchantment-lifecycle/{magic-weapon,shillelagh,divine-favor}`.
Each contains original scenario, recording, commands/receipts and both complete
seat journals. `cases.json` retains the actual statuses. It is not registered in
the shared Studio index or test manifest by this cohort.

| Case | Commands/receipts | Own-seat packets | Factual result |
|---|---:|---:|---|
| Magic Weapon | 17 committed | 29 each | Required condition observation **failed**; complete actual command sequence retained. |
| Shillelagh | 13 committed | 23 each | Actual UUID admission/use/unequip removal/replacement. |
| Divine Favor | 17 committed | 29 each | Actual UUID admission/use/drop-concentration removal/replacement. |

No configs, credentials, host logs/hash inventories, art or captures were copied into the
fixtures. Original attempts remain under
`.runtime/weapon-enchantment-lifecycle-20261020/`: an initial relative-path launch
failure, a premade Fighter grant that did not offer Magic Weapon, and a cast
followed by an unaffordable same-turn attack. The final recipes correct setup
and action economy; they do not reinterpret those failures as successes.

## Magic Weapon: actual producer ownership gap

This is stronger evidence than the old baseline's uncertain eligible target.
The new original explicitly equips a real Quarterstaff and executes every command:
cast → staff attack → real drop concentration → staff attack → unequip → equip
Longsword → replacement attack. In each independent audience:

- Sequence2 occurrence24: completed `spell.magic_weapon`.
- Sequence7 attack51: Quarterstaff UUID
  `c9b7213a-ab09-4be2-a4a0-9cc6d2a17964`, Miss.
- Sequence13 attack103: the same Quarterstaff, Hit, after concentration removal.
- Sequence28 attack195: replacement Longsword UUID
  `2bce8acb-6986-4941-aa85-65e062df960f`, Hit.

The original summary contains only Concentrating application/removal. There is
no `condition.spell.magic_weapon` ActorChange member, no matching ItemRecord
effect, and no AttackFact `item_effects` owner. The original recording remains
`ok=false`, `required_conditions absent from actual journal: condition.spell.magic_weapon`.
The requirement is not removed or weakened.

Frozen producer source explains this boundary:
`dnd/spells/transmutation.py:2222` applies `MagicWeaponEffect` to the selected
**Weapon UUID**. Unlike Shillelagh, it does not project `affected_item_uuid` on an
actor-owned member. It also inherits
`dnd/core/base_conditions.py:758::snapshot_item_effect`, which returns `None`;
`MagicWeaponEffect` defines no accepted item-effect snapshot override. Existing
schema16 `ItemRecord.effects`/`AttackFact.item_effects` could carry item effect
membership, but no such actual Magic Weapon value is disclosed here.

The client cannot fabricate a UUID lifetime from the cast or Concentrating.
Actual item-effect owner admission/removal is a named producer gap; an additional
generic ActorChange binder would not recover the absent public owner.

## Shillelagh: exact item and authoritative removal

Actual condition UUID `90693c04-e891-4d61-b10c-e8d03a9e0b6b` is admitted at
sequence2 occurrence18 and carries public
`state.affected_item_uuid=1a1a0c16-f5f9-4ea5-92b1-bdba449bf793`.
Sequence7 attack60 uses that exact Quarterstaff and hits.
The real unequip removes the condition at sequence12, **Amber89 / Blue88**.
Sequence22's next attack uses replacement Longsword
`9037f983-219c-42a8-9bd9-4819c695b320`, **Amber157 / Blue156**, and hits.

Frozen `ShillelaghEffect.snapshot_state` explicitly exposes its real weapon UUID;
its installed release handler removes this actual condition after the matching
`WeaponUnequipEvent`. These are original public memberships and commands, not
client-derived expiration. The original required condition and condition-end
checks both pass.

## Divine Favor: genuine lifetime, no invented positive hit

Actual condition UUID `cb23fb5c-34ed-4488-a2eb-a6632d4a45e4` is admitted at
sequence2 occurrence22. It is an actor-owned benefit and discloses
`affected_item_uuid=null`; the rules do not bind it to one permanent weapon UUID.
The held attack at sequence7 occurrence52 uses Quarterstaff
`fb2ced07-91a5-4c96-82c5-b8d377161d58` and misses.

Real drop concentration removes this UUID at sequence12 **Amber83 / Blue82**;
the corresponding action is **Amber86 / Blue85**. The next staff attack and
later replacement sword attack both hit, after the condition ended. The latter
uses `609052a9-b8fa-457f-9c24-240fde3439a1` at sequence28
**Amber197 / Blue196**.

The original condition and condition-end requirements pass. No positive Radiant
damage was emitted during the held phase, so rider/impact inputs and native
pixels are explicitly **not qualified** by this recording. No retry was made to
change that authentic miss into a desired outcome.

These records are usable logical lifecycle/ownership inputs. Root still owns
production provider integration, Studio registration, native output and timing
qualification; this cohort makes no rendering or performance claim.


## Current client qualification

`weapon_enchantment_lifecycle_checks`: **653/0**, both original seats for all
three cases, zero script/engine errors or owned leftovers,
`.runtime/tests/20261020T112635.321519Z/summary.json`. The same receipt has
UI-art3166/0 and audio failed-source55/0.

The gate uses current production Resources, ordinary Studio Recording and an
independent SDK Journal. It compares actual operation-prefix boundaries and
ordinary held/back/loop/end seeks, exact equipped staff/empty/replacement sword
states, source UUIDs, actual Unequip/DropConcentration removal and retained
pre-removal member data. It does not construct a Magic Weapon owner or positive
Divine Favor damage after the authentic Miss. It proves logical lifecycle/source
integration; native weapon/body pixels, native removal choreography, first-use
performance and user visual acceptance remain separate.

The complete original cases are published in the existing local Studio library.
Recreate them without a backend:

```sh
python3 tools/studio_cases/record.py --import-recordings tests/fixtures/schema16/weapon-enchantment-lifecycle
```

Select Shillelagh or Divine Favor → `equipped_use_retire_replace`. Magic Weapon's
same-named case remains Failed with the actual missing-membership reason; its
successful command receipt is not substituted for condition output coverage.
