# UI artwork coverage — 19 October 2026

Current catalog-wide evidence from the official schema-16 `authoring/server_ids.json`, typed authoring roots, installed production images, and the shipping HUD maps. This report does not claim visual acceptance or renderer/VFX completeness. No artwork was generated, copied, resized, or substituted during this pass.

Reproduce with `tools/ui_art_coverage.gd -- --write-icons`; the ordinary full presentation build uses those same icon builders. The exhaustive per-ID paths, sources, dimensions, statuses, and shipping-map comparisons are in [generated/reports/ui-art-coverage.json](../generated/reports/ui-art-coverage.json).

## Current coverage

| Requirement | Current IDs | Assigned / deliberate shared images | Explicit generic placeholders | Missing files / shipping mismatch |
|---|---:|---:|---:|---:|
| spell | 189 | 188 | 1 | 0 / 0 |
| action | 119 | 96 | 23 | 0 / 0 |
| reaction | 9 | 9 | 0 | 0 / 0 |
| class_feature | 2 | 2 | 0 | 0 / 0 |
| trait | 34 | 23 | 11 | 0 / 0 |
| feat | 1 | 0 | 1 | 0 / 0 |
| condition | 235 | 188 | 47 | 0 / 0 |
| item | 246 | 246 | 0 | 0 / 0 |
| Current creature portraits | 232 | 232 | 0 | 0 / 0 |
| Selectable player portraits | 432 | 432 | 0 | 0 / 0 |

All 188 production spell roots have assigned 48×48 artwork. `spell.fixture.test_bless` is the maintained developer-only fixture (`ContentVisibility.DEVELOPER` in the frozen engine); its placeholder remains explicit. All 232 current creature IDs have a readable 192×256 portrait. Of these, 53 are existing borrowed assignments, now marked `portrait_status = stand_in`; 63 bodies separately use stand-in rigs/art. Those are different qualifications. The five saved premade aliases remain unchanged.

## Corrected integration

The 18 October delivery is `assets/art/ui-delivery-20261018` (190 selected icons and 19 portraits). Its runtime manifest, semantic batch22 map, batch36 additive assignments and NPC binding proposal were checked against actual current IDs. Older selected smooth48 and full portrait banks remain in use. Exact legacy spelling aliases, delivered elemental technique names, reaction owners, core/world actions, and the explicitly approved Help Attack/Assassin Poison reuses now bind through their existing typed ImageRefs.

The ordinary abilities builder previously merged a legacy condition named `spell.false_life` over the real spell icon, replacing its dedicated image with `condition.generic`. It now selects each ID’s actual typed domain owner. A lifecycle alias cannot override a spell/feature/action ImageRef even when that alias claims `ready`; this is covered by an executable collision test.

The layout and image dimensions are unchanged. `PresentationCharacter.portrait_status` qualifies the assignment independently from the body’s existing status. A generic player/other-creature portrait is not presented as newly delivered dedicated character artwork.

## Remaining icon work

Rows below retain their authored non-ready status. A shared spell/condition glyph is named as shared; a generic filter/condition symbol is named as a placeholder. None of these rows is silently promoted to finished artwork. Some membership/cadence/resource rows are internal bookkeeping and may ultimately need no visible UI glyph; that decision is still explicit in the authored owner, not inferred by this report.

### spell — 1 non-ready assignments

| Current ID | Image treatment | Authored owner status |
|---|---|---|
| `spell.fixture.test_bless` | placeholder: `ui.filter-spells` | internal |

### action — 23 non-ready assignments

| Current ID | Image treatment | Authored owner status |
|---|---|---|
| `action.class.cleric.divine_intervention.arm_thy_servant` | placeholder: `ui.filter-actions` | missing |
| `action.class.cleric.divine_intervention.golden_generosity` | placeholder: `ui.filter-actions` | missing |
| `action.class.cleric.divine_intervention.opulent_revival` | placeholder: `ui.filter-actions` | missing |
| `action.class.cleric.divine_intervention.sunder_heretical` | placeholder: `ui.filter-actions` | missing |
| `action.class.cleric.preserve_life` | placeholder: `ui.filter-actions` | missing |
| `action.class.cleric.turn_undead` | placeholder: `ui.filter-actions` | missing |
| `action.class.paladin.cleansing_touch` | placeholder: `ui.filter-actions` | missing |
| `action.class.paladin.divine_sense` | placeholder: `ui.filter-actions` | missing |
| `action.class.paladin.holy_nimbus` | placeholder: `ui.filter-actions` | missing |
| `action.class.paladin.lay_on_hands` | placeholder: `ui.filter-actions` | missing |
| `action.class.paladin.sacred_weapon` | placeholder: `ui.filter-actions` | missing |
| `action.class.paladin.turn_unholy` | placeholder: `ui.filter-actions` | missing |
| `action.class.wizard.arcane_recovery` | placeholder: `ui.filter-actions` | missing |
| `action.draconic_spirit.breath` | placeholder: `ui.filter-actions` | missing |
| `action.earth_myrmidon.landing` | placeholder: `ui.filter-actions` | missing |
| `action.environment.storage_chest.loot` | placeholder: `ui.filter-actions` | missing |
| `action.item.devotees_mace.healing_incense` | placeholder: `ui.filter-actions` | missing |
| `action.item.field_kit.deploy` | placeholder: `ui.filter-actions` | partial |
| `action.item.potion_true_seeing.drink` | placeholder: `ui.filter-actions` | ready |
| `action.monster.natural_attack` | placeholder: `ui.filter-actions` | ready |
| `action.spell.arcane_sword.move` | placeholder: `ui.filter-actions` | missing |
| `action.spell.payload.throw` | placeholder: `ui.filter-actions` | missing |
| `action.wizard.learn_scroll` | placeholder: `ui.filter-actions` | missing |

### trait — 11 non-ready assignments

| Current ID | Image treatment | Authored owner status |
|---|---|---|
| `trait.body_response` | placeholder: `ui.filter-all` | internal |
| `trait.brave` | placeholder: `ui.filter-all` | internal |
| `trait.brute` | placeholder: `ui.filter-all` | internal |
| `trait.dark_devotion` | placeholder: `ui.filter-all` | internal |
| `trait.dire_wolf_bite_prone` | placeholder: `ui.filter-all` | internal |
| `trait.keen_hearing_and_sight` | placeholder: `ui.filter-all` | internal |
| `trait.keen_hearing_and_smell` | placeholder: `ui.filter-all` | internal |
| `trait.martial_advantage` | placeholder: `ui.filter-all` | internal |
| `trait.sneak_attack` | placeholder: `ui.filter-all` | internal |
| `trait.surprise_attack` | placeholder: `ui.filter-all` | internal |
| `trait.wolf_bite_prone` | placeholder: `ui.filter-all` | internal |

### feat — 1 non-ready assignments

| Current ID | Image treatment | Authored owner status |
|---|---|---|
| `feat.lucky` | placeholder: `ui.filter-all` | internal |

### condition — 110 non-ready assignments

| Current ID | Image treatment | Authored owner status |
|---|---|---|
| `condition.attack_assistance` | placeholder: `condition.generic` | ready |
| `condition.class.cleric.intervention_use` | placeholder: `condition.generic` | internal |
| `condition.class.divine.turned` | placeholder: `condition.generic` | ready |
| `condition.class.feature_lifetime` | placeholder: `condition.generic` | internal |
| `condition.class.paladin.aura_benefit` | placeholder: `condition.generic` | ready |
| `condition.class.paladin.aura_membership` | placeholder: `condition.generic` | internal |
| `condition.class.paladin.aura_owner` | placeholder: `condition.generic` | ready |
| `condition.class.paladin.cleansing_capacity` | placeholder: `condition.generic` | ready |
| `condition.class.paladin.divine_sense` | placeholder: `condition.generic` | ready |
| `condition.class.paladin.holy_nimbus` | placeholder: `condition.generic` | ready |
| `condition.class.paladin.purity_of_spirit` | placeholder: `condition.generic` | ready |
| `condition.class.paladin.sacred_weapon` | placeholder: `condition.generic` | ready |
| `condition.class.wizard.recovery_state` | placeholder: `condition.generic` | internal |
| `condition.consumable.weapon_coat.concentration_fire` | placeholder: `condition.generic` | ready |
| `condition.consumable.weapon_coat.fire` | placeholder: `condition.generic` | ready |
| `condition.consumable.weapon_coat.lightning` | placeholder: `condition.generic` | ready |
| `condition.consumable.weapon_coat.timed_fire` | placeholder: `condition.generic` | ready |
| `condition.revealed` | placeholder: `condition.generic` | ready |
| `condition.spell.acid_arrow` | shared: `spell.acid_arrow` | ready |
| `condition.spell.acid_surface.membership` | placeholder: `condition.generic` | internal |
| `condition.spell.animal_friendship` | shared: `spell.animal_friendship` | ready |
| `condition.spell.arcane_sword` | shared: `spell.arcane_sword` | ready |
| `condition.spell.aura_of_life.benefit` | shared: `spell.aura_of_life` | ready |
| `condition.spell.aura_of_life.membership` | shared: `spell.aura_of_life` | internal |
| `condition.spell.aura_of_life.owner` | shared: `spell.aura_of_life` | ready |
| `condition.spell.banishment` | shared: `spell.banishment` | ready |
| `condition.spell.bestow_curse.ability` | shared: `spell.bestow_curse` | ready |
| `condition.spell.bestow_curse.attack` | shared: `spell.bestow_curse` | ready |
| `condition.spell.bestow_curse.damage` | shared: `spell.bestow_curse` | ready |
| `condition.spell.bestow_curse.inaction` | shared: `spell.bestow_curse` | ready |
| `condition.spell.branding_smite` | shared: `spell.branding_smite` | ready |
| `condition.spell.calm_emotions` | shared: `spell.calm_emotions` | ready |
| `condition.spell.charm_monster` | shared: `spell.charm_monster` | ready |
| `condition.spell.charm_person.effect` | shared: `spell.charm_person` | ready |
| `condition.spell.dancing_lights` | shared: `spell.dancing_lights` | internal |
| `condition.spell.dispel_evil_and_good` | shared: `spell.dispel_evil_and_good` | ready |
| `condition.spell.dissonant_whispers` | shared: `spell.dissonant_whispers` | ready |
| `condition.spell.divine_favor` | shared: `spell.divine_favor` | ready |
| `condition.spell.dragons_breath` | shared: `spell.dragons_breath` | internal |
| `condition.spell.ensnaring_strike` | shared: `spell.ensnaring_strike` | ready |
| `condition.spell.eyebite.sickened` | shared: `spell.eyebite` | ready |
| `condition.spell.faerie_fire` | shared: `spell.faerie_fire` | ready |
| `condition.spell.feeblemind` | shared: `spell.feeblemind` | ready |
| `condition.spell.flame_blade` | shared: `spell.flame_blade` | ready |
| `condition.spell.flaming_sphere.aura` | shared: `spell.flaming_sphere` | ready |
| `condition.spell.flesh_to_stone.stages` | shared: `spell.flesh_to_stone` | ready |
| `condition.spell.foresight` | shared: `spell.foresight` | ready |
| `condition.spell.foresight.owner` | shared: `spell.foresight` | ready |
| `condition.spell.globe_of_invulnerability.zone` | shared: `spell.globe_of_invulnerability` | ready |
| `condition.spell.glyph_of_warding` | shared: `spell.glyph_of_warding` | ready |
| `condition.spell.glyph_of_warding.sleep` | shared: `spell.glyph_of_warding` | ready |
| `condition.spell.goodberry.batch` | shared: `spell.goodberry` | ready |
| `condition.spell.heroism` | shared: `spell.heroism` | ready |
| `condition.spell.hex` | shared: `spell.hex` | internal |
| `condition.spell.hex.quarry` | shared: `spell.hex` | ready |
| `condition.spell.hideous_laughter` | shared: `spell.hideous_laughter` | ready |
| `condition.spell.holy_aura` | shared: `spell.holy_aura` | ready |
| `condition.spell.holy_aura.blindness` | shared: `spell.holy_aura` | ready |
| `condition.spell.hunters_mark` | shared: `spell.hunters_mark` | internal |
| `condition.spell.hunters_mark.quarry` | shared: `spell.hunters_mark` | ready |
| `condition.spell.independent_summon_owner` | placeholder: `condition.generic` | internal |
| `condition.spell.irresistible_dance` | shared: `spell.irresistible_dance` | ready |
| `condition.spell.magic_weapon` | shared: `spell.magic_weapon` | ready |
| `condition.spell.moonbeam` | shared: `spell.moonbeam` | internal |
| `condition.spell.pass_without_trace` | shared: `spell.pass_without_trace` | ready |
| `condition.spell.pass_without_trace.bonus` | shared: `spell.pass_without_trace` | ready |
| `condition.spell.pass_without_trace.membership` | shared: `spell.pass_without_trace` | internal |
| `condition.spell.payload_lifetime` | placeholder: `condition.generic` | ready |
| `condition.spell.phantasmal_force` | shared: `spell.phantasmal_force` | ready |
| `condition.spell.phantasmal_killer` | shared: `spell.phantasmal_killer` | ready |
| `condition.spell.protection_from_evil_and_good` | shared: `spell.protection_from_evil_and_good` | ready |
| `condition.spell.ray_of_sickness.poison` | shared: `spell.ray_of_sickness` | ready |
| `condition.spell.regenerate` | shared: `spell.regenerate` | ready |
| `condition.spell.resilient_sphere` | shared: `spell.resilient_sphere` | ready |
| `condition.spell.searing_smite` | shared: `spell.searing_smite` | ready |
| `condition.spell.slow` | shared: `spell.slow` | ready |
| `condition.spell.spiritual_weapon.owner` | shared: `spell.spiritual_weapon` | internal |
| `condition.spell.starry_wisp` | shared: `spell.starry_wisp` | ready |
| `condition.spell.stinking_cloud.nauseated` | shared: `spell.stinking_cloud` | ready |
| `condition.spell.summon_dragon.shared_resistance` | shared: `spell.summon_dragon` | ready |
| `condition.spell.vampiric_touch` | shared: `spell.vampiric_touch` | ready |
| `condition.spell.vicious_mockery` | shared: `spell.vicious_mockery` | ready |
| `condition.spell.vitriolic_sphere.residue` | shared: `spell.vitriolic_sphere` | ready |
| `condition.spell.weird` | shared: `spell.weird` | ready |
| `condition.summon.draconic_breath_cadence` | placeholder: `condition.generic` | ready |
| `condition.summon.elemental_multiattack_bonus` | placeholder: `condition.generic` | ready |
| `condition.summon.myrmidon_strike_dice` | placeholder: `condition.generic` | ready |
| `condition.summon.raging_vortex_owner` | placeholder: `condition.generic` | ready |
| `condition.summon.sweetplum_field_owner` | placeholder: `condition.generic` | ready |
| `condition.summon.sweetplum_membership` | placeholder: `condition.generic` | internal |
| `condition.summon.sweetplum_restrained` | placeholder: `condition.generic` | ready |
| `condition.summon.tenacity` | placeholder: `condition.generic` | ready |
| `condition.tile.spike_trap` | placeholder: `condition.generic` | ready |
| `condition.tile.zone_marker` | placeholder: `condition.generic` | ready |
| `spatial_effect.class.paladin.aura` | placeholder: `condition.generic` | ready |
| `spatial_effect.item.devotees_mace.healing_incense` | placeholder: `condition.generic` | ready |
| `spatial_effect.spell.acid_surface` | placeholder: `condition.generic` | ready |
| `spatial_effect.spell.antilife_shell` | placeholder: `condition.generic` | ready |
| `spatial_effect.spell.aura_of_life` | placeholder: `condition.generic` | ready |
| `spatial_effect.spell.blade_barrier` | placeholder: `condition.generic` | ready |
| `spatial_effect.spell.flaming_sphere.aura` | placeholder: `condition.generic` | ready |
| `spatial_effect.spell.forcecage` | placeholder: `condition.generic` | ready |
| `spatial_effect.spell.glyph_of_warding` | placeholder: `condition.generic` | ready |
| `spatial_effect.spell.moonbeam` | placeholder: `condition.generic` | ready |
| `spatial_effect.spell.pass_without_trace` | placeholder: `condition.generic` | ready |
| `spatial_effect.spell.plant_growth` | placeholder: `condition.generic` | ready |
| `spatial_effect.spell.simple_toxin` | placeholder: `condition.generic` | ready |
| `spatial_effect.summon.fire` | placeholder: `condition.generic` | ready |
| `spatial_effect.summon.raging_vortex` | placeholder: `condition.generic` | ready |
| `spatial_effect.summon.sweetplum_gales` | placeholder: `condition.generic` | ready |

### item — 3 non-ready assignments

| Current ID | Image treatment | Authored owner status |
|---|---|---|
| `gear.saddle` | shared: `item.field-kit` | stand_in |
| `tool.banner` | shared: `item.field-kit` | ready |
| `tool.crowbar` | shared: `item.field-kit` | ready |

## Borrowed character portraits

These existing assignments are displayed but do not provide dedicated portraits for the named character. Their native identity is preserved; source portraits do not create backend creatures.

| Current character | Existing borrowed portrait |
|---|---|
| `creature.acolyte` | `cleric--human-white--male` |
| `creature.bandit` | `rogue--human-white--male` |
| `creature.bandit_captain` | `rogue--human-white--male` |
| `creature.berserker` | `barbarian--human-white--male` |
| `creature.bugbear` | `orcs_goblins--orc-04` |
| `creature.commoner` | `monk--human-white--male` |
| `creature.configured_srd.acolyte` | `cleric--human-white--male` |
| `creature.configured_srd.bandit` | `rogue--human-white--male` |
| `creature.configured_srd.bandit_captain` | `rogue--human-white--male` |
| `creature.configured_srd.berserker` | `barbarian--human-white--male` |
| `creature.configured_srd.bugbear` | `orcs_goblins--orc-04` |
| `creature.configured_srd.commoner` | `monk--human-white--male` |
| `creature.configured_srd.cult_fanatic` | `warlock--human-white--male` |
| `creature.configured_srd.cultist` | `warlock--human-white--male` |
| `creature.configured_srd.gnoll` | `orcs_goblins--orc-10` |
| `creature.configured_srd.guard` | `fighter--human-white--male` |
| `creature.configured_srd.hobgoblin` | `orcs_goblins--orc-03` |
| `creature.configured_srd.knight` | `paladin--human-white--male` |
| `creature.configured_srd.kobold` | `creature.goblin` |
| `creature.configured_srd.mage` | `wizard--human-white--male` |
| `creature.configured_srd.priest` | `cleric--human-white--male` |
| `creature.configured_srd.scout` | `ranger--human-white--male` |
| `creature.configured_srd.spy` | `rogue--human-white--male` |
| `creature.configured_srd.thug` | `rogue--human-white--male` |
| `creature.configured_srd.tribal_warrior` | `barbarian--human-white--male` |
| `creature.configured_srd.veteran` | `fighter--human-white--male` |
| `creature.cult_fanatic` | `warlock--human-white--male` |
| `creature.cultist` | `warlock--human-white--male` |
| `creature.dire_wolf` | `animals--elite-wolf` |
| `creature.generic_caster` | `sorcerer--human-white--male` |
| `creature.ghoul` | `top--zombie-decay-02` |
| `creature.gnoll` | `orcs_goblins--orc-10` |
| `creature.goblin_archer` | `creature.goblin_reedshot` |
| `creature.goblin_caster` | `creature.goblin_wispbinder` |
| `creature.guard` | `fighter--human-white--male` |
| `creature.hobgoblin` | `orcs_goblins--orc-03` |
| `creature.knight` | `paladin--human-white--male` |
| `creature.kobold` | `creature.goblin` |
| `creature.mage` | `wizard--human-white--male` |
| `creature.ogre` | `barbarian--1ogre` |
| `creature.ogre_zombie` | `hdz--zombiehulk1` |
| `creature.priest` | `cleric--human-white--male` |
| `creature.scout` | `ranger--human-white--male` |
| `creature.skeleton` | `undead--6warrior` |
| `creature.skeleton_warlock` | `undead--8necromancer` |
| `creature.skeleton_warrior` | `undead--6warrior` |
| `creature.spell.flaming_sphere` | `srd22.portrait.fire_elemental` |
| `creature.spell.spiritual_weapon` | `cleric--human-white--male` |
| `creature.spy` | `rogue--human-white--male` |
| `creature.thug` | `rogue--human-white--male` |
| `creature.tribal_warrior` | `barbarian--human-white--male` |
| `creature.veteran` | `fighter--human-white--male` |
| `creature.zombie` | `hdz--zombiemale1` |

## Validation

`tests/ui_art_coverage_checks.gd` checks every current shipping assignment, full image dimensions, actual ContentRef portrait resolution, all player choices, truthful placeholder status, and exact typed-owner precedence over colliding lifecycle aliases. It performs no runtime checks and adds no gameplay startup work. The detailed report remains generated test evidence, not another editable catalog.
