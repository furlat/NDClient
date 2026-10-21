# Creature body artwork still using stand-ins — 20 October 2026

Source: current `authoring/characters/characters/*.tres`, reconciled 21 October. This is a source-resource inventory, not a rendering test or a request for 63 new bodies. No assets were imported or moved. **All artwork and audio remain UNREVIEWED.**

## Twelve summon bodies with explicit substitute artwork

These are the concrete summon-art gaps. Each already has a playable substitute rig and an assigned portrait. The body artwork is missing for the named creature itself.

| Creature | Exact owner | Current substitute body |
|---|---|---|
| Air Elemental | [`creature.spell.air_elemental`](../authoring/characters/characters/creature.spell.air_elemental.tres) | `smallscale.enemies.11arcane-elemental` |
| Air Myrmidon | [`creature.spell.air_myrmidon`](../authoring/characters/characters/creature.spell.air_myrmidon.tres) | `smallscale.enemies.11arcane-elemental` |
| Cambion | [`creature.spell.cambion`](../authoring/characters/characters/creature.spell.cambion.tres) | `smallscale.demonelite01` |
| Deva | [`creature.spell.deva`](../authoring/characters/characters/creature.spell.deva.tres) | `smallscale.characters.4paladin` |
| Djinni | [`creature.spell.djinni`](../authoring/characters/characters/creature.spell.djinni.tres) | `smallscale.characters.6mage` |
| Draconic Spirit | [`creature.spell.draconic_spirit`](../authoring/characters/characters/creature.spell.draconic_spirit.tres) | `smallscale.dinosaurs.elite-armored-t-rex` |
| Earth Elemental | [`creature.spell.earth_elemental`](../authoring/characters/characters/creature.spell.earth_elemental.tres) | `smallscale.enemies.11arcane-elemental` |
| Earth Myrmidon | [`creature.spell.earth_myrmidon`](../authoring/characters/characters/creature.spell.earth_myrmidon.tres) | `smallscale.enemies.11arcane-elemental` |
| Fire Elemental | [`creature.spell.fire_elemental`](../authoring/characters/characters/creature.spell.fire_elemental.tres) | `smallscale.enemies.11arcane-elemental` |
| Fire Myrmidon | [`creature.spell.fire_myrmidon`](../authoring/characters/characters/creature.spell.fire_myrmidon.tres) | `smallscale.enemies.11arcane-elemental` |
| Water Elemental | [`creature.spell.water_elemental`](../authoring/characters/characters/creature.spell.water_elemental.tres) | `smallscale.enemies.11arcane-elemental` |
| Water Myrmidon | [`creature.spell.water_myrmidon`](../authoring/characters/characters/creature.spell.water_myrmidon.tres) | `smallscale.enemies.11arcane-elemental` |

The five elemental Dragon summon forms share `creature.spell.draconic_spirit`; this is one missing dragon body family, not five independently missing base rigs. The current body is an armoured T-Rex. All eight elemental/Myrmidon creatures currently reuse the same arcane-elemental body. Their existing portraits do not supply animated body art.

## Other substitutions already recorded in the roster

These are existing substitutions to review separately. A `stand_in` label is not by itself a requirement to commission another body.

| Creature | Current substitute body |
|---|---|
| [`creature.bugbear`](../authoring/characters/characters/creature.bugbear.tres) | `smallscale.orc04` |
| [`creature.dire_wolf`](../authoring/characters/characters/creature.dire_wolf.tres) | `smallscale.animals.elite-wolf` |
| [`creature.ghoul`](../authoring/characters/characters/creature.ghoul.tres) | `smallscale.zombies-top-down.zombie-decay-02` |
| [`creature.gnoll`](../authoring/characters/characters/creature.gnoll.tres) | `smallscale.orc10` |
| [`creature.goblin_archer`](../authoring/characters/characters/creature.goblin_archer.tres) | `smallscale.goblin03` |
| [`creature.goblin_caster`](../authoring/characters/characters/creature.goblin_caster.tres) | `smallscale.goblin02` |
| [`creature.hobgoblin`](../authoring/characters/characters/creature.hobgoblin.tres) | `smallscale.orc03` |
| [`creature.kobold`](../authoring/characters/characters/creature.kobold.tres) | `smallscale.goblin01` |
| [`creature.ogre`](../authoring/characters/characters/creature.ogre.tres) | `smallscale.barbarians.1ogre` |
| [`creature.ogre_zombie`](../authoring/characters/characters/creature.ogre_zombie.tres) | `smallscale.zombies-hd.zombiehulk1` |
| [`creature.skeleton`](../authoring/characters/characters/creature.skeleton.tres) | `smallscale.undead.6warrior` |
| [`creature.skeleton_warlock`](../authoring/characters/characters/creature.skeleton_warlock.tres) | `smallscale.undead.8necromancer` |
| [`creature.zombie`](../authoring/characters/characters/creature.zombie.tres) | `smallscale.zombies-hd.zombiemale1` |

The clearest species substitutions are Bugbear, Gnoll and Hobgoblin using Orc bodies; Kobold using a Goblin; and Ghoul using a decayed Zombie. Other rows already use an appropriate pack variant (for example Ogre, Dire Wolf, Skeleton or Zombie) and should not automatically be treated as missing art.

## Why the old report said 63

The original 63-resource snapshot contained **12 summon bodies**, **34 modular-body assignments**, and **17 other substitutions**. Four of those 17 were duplicate `creature.configured_srd.*` entries for Bugbear/Gnoll/Hobgoblin/Kobold. The modular assignments include ordinary human NPC roles and their configured aliases; the shared layered humanoid rig already supplies those bodies. Skeleton Warrior has since moved from that modular group to the installed skeletal melee body below. The old 63 flags are historical receipt counts, not 63 current missing-body commissions.

`creature.spell.flaming_sphere` and `creature.spell.spiritual_weapon` are explicitly VFX-owned internal actors; their absence of a character rig is intentional and does not request creature artwork.

## Original flagged inventory with current source assignments

| Owner | Current rig |
|---|---|
| [`creature.acolyte`](../authoring/characters/characters/creature.acolyte.tres) | `neuroclient.modular` |
| [`creature.bandit`](../authoring/characters/characters/creature.bandit.tres) | `neuroclient.modular` |
| [`creature.bandit_captain`](../authoring/characters/characters/creature.bandit_captain.tres) | `neuroclient.modular` |
| [`creature.berserker`](../authoring/characters/characters/creature.berserker.tres) | `neuroclient.modular` |
| [`creature.bugbear`](../authoring/characters/characters/creature.bugbear.tres) | `smallscale.orc04` |
| [`creature.commoner`](../authoring/characters/characters/creature.commoner.tres) | `neuroclient.modular` |
| [`creature.configured_srd.acolyte`](../authoring/characters/characters/creature.configured_srd.acolyte.tres) | `neuroclient.modular` |
| [`creature.configured_srd.bandit`](../authoring/characters/characters/creature.configured_srd.bandit.tres) | `neuroclient.modular` |
| [`creature.configured_srd.bandit_captain`](../authoring/characters/characters/creature.configured_srd.bandit_captain.tres) | `neuroclient.modular` |
| [`creature.configured_srd.berserker`](../authoring/characters/characters/creature.configured_srd.berserker.tres) | `neuroclient.modular` |
| [`creature.configured_srd.bugbear`](../authoring/characters/characters/creature.configured_srd.bugbear.tres) | `smallscale.orc04` |
| [`creature.configured_srd.commoner`](../authoring/characters/characters/creature.configured_srd.commoner.tres) | `neuroclient.modular` |
| [`creature.configured_srd.cult_fanatic`](../authoring/characters/characters/creature.configured_srd.cult_fanatic.tres) | `neuroclient.modular` |
| [`creature.configured_srd.cultist`](../authoring/characters/characters/creature.configured_srd.cultist.tres) | `neuroclient.modular` |
| [`creature.configured_srd.gnoll`](../authoring/characters/characters/creature.configured_srd.gnoll.tres) | `smallscale.orc10` |
| [`creature.configured_srd.guard`](../authoring/characters/characters/creature.configured_srd.guard.tres) | `neuroclient.modular` |
| [`creature.configured_srd.hobgoblin`](../authoring/characters/characters/creature.configured_srd.hobgoblin.tres) | `smallscale.orc03` |
| [`creature.configured_srd.knight`](../authoring/characters/characters/creature.configured_srd.knight.tres) | `neuroclient.modular` |
| [`creature.configured_srd.kobold`](../authoring/characters/characters/creature.configured_srd.kobold.tres) | `smallscale.goblin01` |
| [`creature.configured_srd.mage`](../authoring/characters/characters/creature.configured_srd.mage.tres) | `neuroclient.modular` |
| [`creature.configured_srd.priest`](../authoring/characters/characters/creature.configured_srd.priest.tres) | `neuroclient.modular` |
| [`creature.configured_srd.scout`](../authoring/characters/characters/creature.configured_srd.scout.tres) | `neuroclient.modular` |
| [`creature.configured_srd.spy`](../authoring/characters/characters/creature.configured_srd.spy.tres) | `neuroclient.modular` |
| [`creature.configured_srd.thug`](../authoring/characters/characters/creature.configured_srd.thug.tres) | `neuroclient.modular` |
| [`creature.configured_srd.tribal_warrior`](../authoring/characters/characters/creature.configured_srd.tribal_warrior.tres) | `neuroclient.modular` |
| [`creature.configured_srd.veteran`](../authoring/characters/characters/creature.configured_srd.veteran.tres) | `neuroclient.modular` |
| [`creature.cult_fanatic`](../authoring/characters/characters/creature.cult_fanatic.tres) | `neuroclient.modular` |
| [`creature.cultist`](../authoring/characters/characters/creature.cultist.tres) | `neuroclient.modular` |
| [`creature.dire_wolf`](../authoring/characters/characters/creature.dire_wolf.tres) | `smallscale.animals.elite-wolf` |
| [`creature.generic_caster`](../authoring/characters/characters/creature.generic_caster.tres) | `neuroclient.modular` |
| [`creature.ghoul`](../authoring/characters/characters/creature.ghoul.tres) | `smallscale.zombies-top-down.zombie-decay-02` |
| [`creature.gnoll`](../authoring/characters/characters/creature.gnoll.tres) | `smallscale.orc10` |
| [`creature.goblin_archer`](../authoring/characters/characters/creature.goblin_archer.tres) | `smallscale.goblin03` |
| [`creature.goblin_caster`](../authoring/characters/characters/creature.goblin_caster.tres) | `smallscale.goblin02` |
| [`creature.guard`](../authoring/characters/characters/creature.guard.tres) | `neuroclient.modular` |
| [`creature.hobgoblin`](../authoring/characters/characters/creature.hobgoblin.tres) | `smallscale.orc03` |
| [`creature.knight`](../authoring/characters/characters/creature.knight.tres) | `neuroclient.modular` |
| [`creature.kobold`](../authoring/characters/characters/creature.kobold.tres) | `smallscale.goblin01` |
| [`creature.mage`](../authoring/characters/characters/creature.mage.tres) | `neuroclient.modular` |
| [`creature.ogre`](../authoring/characters/characters/creature.ogre.tres) | `smallscale.barbarians.1ogre` |
| [`creature.ogre_zombie`](../authoring/characters/characters/creature.ogre_zombie.tres) | `smallscale.zombies-hd.zombiehulk1` |
| [`creature.priest`](../authoring/characters/characters/creature.priest.tres) | `neuroclient.modular` |
| [`creature.scout`](../authoring/characters/characters/creature.scout.tres) | `neuroclient.modular` |
| [`creature.skeleton`](../authoring/characters/characters/creature.skeleton.tres) | `smallscale.undead.6warrior` |
| [`creature.skeleton_warlock`](../authoring/characters/characters/creature.skeleton_warlock.tres) | `smallscale.undead.8necromancer` |
| [`creature.skeleton_warrior`](../authoring/characters/characters/creature.skeleton_warrior.tres) | `smallscale.undead.6warrior` — now partial, not a modular body |
| [`creature.spell.air_elemental`](../authoring/characters/characters/creature.spell.air_elemental.tres) | `smallscale.enemies.11arcane-elemental` |
| [`creature.spell.air_myrmidon`](../authoring/characters/characters/creature.spell.air_myrmidon.tres) | `smallscale.enemies.11arcane-elemental` |
| [`creature.spell.cambion`](../authoring/characters/characters/creature.spell.cambion.tres) | `smallscale.demonelite01` |
| [`creature.spell.deva`](../authoring/characters/characters/creature.spell.deva.tres) | `smallscale.characters.4paladin` |
| [`creature.spell.djinni`](../authoring/characters/characters/creature.spell.djinni.tres) | `smallscale.characters.6mage` |
| [`creature.spell.draconic_spirit`](../authoring/characters/characters/creature.spell.draconic_spirit.tres) | `smallscale.dinosaurs.elite-armored-t-rex` |
| [`creature.spell.earth_elemental`](../authoring/characters/characters/creature.spell.earth_elemental.tres) | `smallscale.enemies.11arcane-elemental` |
| [`creature.spell.earth_myrmidon`](../authoring/characters/characters/creature.spell.earth_myrmidon.tres) | `smallscale.enemies.11arcane-elemental` |
| [`creature.spell.fire_elemental`](../authoring/characters/characters/creature.spell.fire_elemental.tres) | `smallscale.enemies.11arcane-elemental` |
| [`creature.spell.fire_myrmidon`](../authoring/characters/characters/creature.spell.fire_myrmidon.tres) | `smallscale.enemies.11arcane-elemental` |
| [`creature.spell.water_elemental`](../authoring/characters/characters/creature.spell.water_elemental.tres) | `smallscale.enemies.11arcane-elemental` |
| [`creature.spell.water_myrmidon`](../authoring/characters/characters/creature.spell.water_myrmidon.tres) | `smallscale.enemies.11arcane-elemental` |
| [`creature.spy`](../authoring/characters/characters/creature.spy.tres) | `neuroclient.modular` |
| [`creature.thug`](../authoring/characters/characters/creature.thug.tres) | `neuroclient.modular` |
| [`creature.tribal_warrior`](../authoring/characters/characters/creature.tribal_warrior.tres) | `neuroclient.modular` |
| [`creature.veteran`](../authoring/characters/characters/creature.veteran.tres) | `neuroclient.modular` |
| [`creature.zombie`](../authoring/characters/characters/creature.zombie.tres) | `smallscale.zombies-hd.zombiemale1` |


## Skeleton Warrior assignment repaired; kit and optical limits remain

[`creature.skeleton_warrior`](../authoring/characters/characters/creature.skeleton_warrior.tres)
now selects the already-installed
[`smallscale.undead.6warrior`](../authoring/characters/rigs/smallscale.undead.6warrior.tres),
a real skeletal melee/shield body with 29 authored poses. Its existing attack,
cast, movement, hit, Block and Die clips keep their source frames and clocks.
The bow-bodied Skeleton Archer is not substituted. No body artwork was copied,
painted or imported for this repair.

The resource remains `partial`: the baked pixels show a spear and wooden
shield rather than the native Longsword, Wooden Shield and Armor Scraps kit.
They cannot render arbitrary acquired equipment or equipment swaps. The rig's
existing partial optical coverage and named clip fallbacks remain unchanged.
The separate `undead--6warrior` portrait is still explicitly borrowed; no exact
Skeleton Warrior portrait was supplied. This is a source assignment, with no
new runtime, screenshot or human acceptance claim. **All artwork is UNREVIEWED.**

The impossible `Head11` offer was also removed from the modular rig's helmet
choices. The installed delivery contains no `Head11` part, sprites or optical
companions. No current gear/appearance selected it; Leather Hood already uses
its explicit `Head12`/`Head7` variants. This removes unsupported unused metadata
and does not request a fabricated donor part or change a used selection.

## Optical mouth authoring for public Draconic Breath readiness

This is **client body/pose authoring**, separate from the twelve missing summon
bodies listed above. The current `creature.spell.draconic_spirit` resource uses
`smallscale.dinosaurs.elite-armored-t-rex`. Its real body remains that explicit
substitute until artwork is assigned; no dinosaur head/face centre is an
anatomical mouth measurement.

Factory `runtime-public-admission-20261020-976f8289ebcefa5c` now supplies the
public readiness gate and its paired direct source constructors for the five
playable Fire/Cold/Lightning/Acid/Poison forms. The client binds the actual
condition UUID, current public `ready`/`breath_type`, owner/source actor,
observation revision and ordinary owner/phase clocks. It does not require a
private FreeAction ID, issued flag or granted lineage. The remaining draw input
is an **authentic scoped mouth surface** for this actual body and its displayed
pose/view, currently `authentic_mouth_region_not_authored`.

The concrete requested asset data are:

- For the current armoured-T-Rex source (and later the real dragon body), author
  a `mouth` socket for each supported clip, frame and facing through the existing
  rig pose-socket data. An unsupported frame/view must remain absent.
- Author the bounded optical sampling slots/radius around that actual mouth,
  retaining the original colour/depth/support/normal source pixels. The existing
  `PresentationCondition.lifecycle_geometry` can select these real slots with
  `region={id:"mouth",socket:"mouth",radius_cells:<authored finite value>}`.
  Remove its explicit missing status only when that body data exist. No new
  spell-specific consumer is needed: current pose/socket resolution and actual
  EntitySurface sampling already supply those exact points and geometry
  revision to the selected public source.
- Include the same scope for idle, movement, casting/attack, hurt and other
  displayed body clips/views that should support readiness. Missing scope
  stays an explicit empty/missing input; a whole head is never relabelled.

The delivered source witness contains only four inspected lower-forward-face
pixels `(65,48),(66,48),(65,49),(66,49)` on modular
`Head1/Idle.png`, frame1, source UV `(1/15,.625,1/15,.125)`. That is a bounded
Factory source witness, **not** mouth authoring for the actual T-Rex body or a
universal region assignment. No Head1-only demonstration adapter was added.
Actual public `ready=false` still retires the source without mouth geometry;
actual accepted breath firing remains a separate native action. All artwork
remains **unreviewed**, and this new public-source wiring is **unvalidated**.
