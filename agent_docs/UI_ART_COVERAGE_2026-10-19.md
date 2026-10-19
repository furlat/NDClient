# UI artwork coverage — 19 October 2026

Current evidence from the official schema-16 `authoring/server_ids.json`, all actual typed UI owners, installed production images, and the shipping HUD maps. Typed-only class actions remain visible with `availability = typed_only`; they do not claim presence in the static server ID inventory. This report does not claim visual acceptance or renderer/VFX completeness.

Reproduce with `tools/ui_art_coverage.gd -- --write-icons`; the ordinary presentation build uses the same icon builders. Exhaustive per-ID paths, sources, dimensions, statuses, availability and shipping-map comparisons are in [generated/reports/ui-art-coverage.json](../generated/reports/ui-art-coverage.json). No new artwork, resizing or UI layout changes are involved.

## Coverage

| Requirement | Server IDs | Additional typed owners | Assigned / deliberate shared | Generic placeholders | Missing files / shipping mismatch |
| --- | ---: | ---: | ---: | ---: | ---: |
| spell | 189 | 2 | 189 | 2 | 0 / 0 |
| action | 119 | 85 | 177 | 27 | 0 / 0 |
| reaction | 9 | 1 | 10 | 0 | 0 / 0 |
| class_feature | 2 | 3 | 5 | 0 | 0 / 0 |
| trait | 34 | 0 | 23 | 11 | 0 / 0 |
| feat | 1 | 0 | 0 | 1 | 0 / 0 |
| condition | 235 | 2 | 189 | 48 | 0 / 0 |
| item | 246 | 0 | 246 | 0 | 0 / 0 |
| Current creature portraits | 232 | 0 | 232 | 0 | 0 / 0 |
| Selectable player portraits | 432 | 0 | 432 | 0 | 0 / 0 |

All 188 production spell IDs in the current engine inventory retain assigned 48×48 artwork. The developer-only `spell.fixture.test_bless` placeholder remains explicit. The typed-only Antimagic Field icon is assigned; the separate legacy `spell.ice_knife.burst` partial source still has a placeholder. All 232 current creature IDs have readable 192×256 portraits; 53 existing borrowed portrait assignments are marked independently as `portrait_status = stand_in`, and 63 bodies separately use stand-in rigs/art. The five premade aliases remain unchanged.

## Corrected integration

The 18 October delivery is `assets/art/ui-delivery-20261018` (190 selected icons and 19 portraits). Its runtime manifest, semantic batch22 map, batch36 additive assignments and NPC binding proposal were checked against actual current IDs. Older selected smooth48 and full portrait banks remain in use. Exact legacy spelling aliases, delivered elemental technique names, reaction owners, core/world actions and explicitly approved Help Attack/Assassin Poison reuses bind through existing typed ImageRefs.

The abilities builder now respects each ID’s actual typed domain owner. A lifecycle alias named `spell.false_life` cannot overwrite the real spell image, even if the alias claims ready. This has an executable collision test.

The initial server-only report omitted 85 actual typed actions, three typed class features and a retaliation reaction. Those now participate in the same report. Eighty-four existing ImageRefs were corrected using delivered exact action art or the already authored direct-feature assignment. Named monster multiattacks use their delivered exact icons where available, and otherwise explicitly share the delivered multiattack mechanic icon. Feature/wing/affinity glyph reuse is named as shared. These are existing art assignments, not newly generated dedicated per-character assets.

## Remaining icon work

Each row below retains its non-ready image status. Shared images are named as shared; filter and condition-generic symbols are placeholders. Some internal bookkeeping may ultimately need no visible glyph, but this report does not silently remove or approve those requirements.

### spell — 2 non-ready assignments

| ID | Availability | Image treatment | Authored owner status |
| --- | --- | --- | --- |
| `spell.fixture.test_bless` | server_id | placeholder: `ui.filter-spells` | internal |
| `spell.ice_knife.burst` | typed_only | placeholder: `ui.filter-spells` | partial |

### action — 27 non-ready assignments

| ID | Availability | Image treatment | Authored owner status |
| --- | --- | --- | --- |
| `action.class.cleric.divine_intervention.arm_thy_servant` | server_id | placeholder: `ui.filter-actions` | missing |
| `action.class.cleric.divine_intervention.golden_generosity` | server_id | placeholder: `ui.filter-actions` | missing |
| `action.class.cleric.divine_intervention.opulent_revival` | server_id | placeholder: `ui.filter-actions` | missing |
| `action.class.cleric.divine_intervention.sunder_heretical` | server_id | placeholder: `ui.filter-actions` | missing |
| `action.class.cleric.preserve_life` | server_id | placeholder: `ui.filter-actions` | missing |
| `action.class.cleric.turn_undead` | server_id | placeholder: `ui.filter-actions` | missing |
| `action.class.paladin.cleansing_touch` | server_id | placeholder: `ui.filter-actions` | missing |
| `action.class.paladin.divine_sense` | server_id | placeholder: `ui.filter-actions` | missing |
| `action.class.paladin.holy_nimbus` | server_id | placeholder: `ui.filter-actions` | missing |
| `action.class.paladin.lay_on_hands` | server_id | placeholder: `ui.filter-actions` | missing |
| `action.class.paladin.sacred_weapon` | server_id | placeholder: `ui.filter-actions` | missing |
| `action.class.paladin.turn_unholy` | server_id | placeholder: `ui.filter-actions` | missing |
| `action.class.wizard.arcane_recovery` | server_id | placeholder: `ui.filter-actions` | missing |
| `action.draconic_spirit.breath` | server_id | placeholder: `ui.filter-actions` | missing |
| `action.earth_myrmidon.landing` | server_id | placeholder: `ui.filter-actions` | missing |
| `action.environment.storage_chest.loot` | server_id | placeholder: `ui.filter-actions` | missing |
| `action.item.devotees_mace.healing_incense` | server_id | placeholder: `ui.filter-actions` | missing |
| `action.item.field_kit.deploy` | server_id | placeholder: `ui.filter-actions` | partial |
| `action.item.potion_true_seeing.drink` | server_id | placeholder: `ui.filter-actions` | ready |
| `action.monster.natural_attack` | server_id | placeholder: `ui.filter-actions` | ready |
| `action.spell.arcane_sword.move` | server_id | placeholder: `ui.filter-actions` | missing |
| `action.spell.entangle.escape` | typed_only | placeholder: `ui.filter-actions` | partial |
| `action.spell.evards_black_tentacles.escape_dexterity` | typed_only | placeholder: `ui.filter-actions` | partial |
| `action.spell.evards_black_tentacles.escape_strength` | typed_only | placeholder: `ui.filter-actions` | partial |
| `action.spell.payload.throw` | server_id | placeholder: `ui.filter-actions` | missing |
| `action.spell.telekinesis.grab` | typed_only | placeholder: `ui.filter-actions` | partial |
| `action.wizard.learn_scroll` | server_id | placeholder: `ui.filter-actions` | missing |

### trait — 11 non-ready assignments

| ID | Availability | Image treatment | Authored owner status |
| --- | --- | --- | --- |
| `trait.body_response` | server_id | placeholder: `ui.filter-all` | internal |
| `trait.brave` | server_id | placeholder: `ui.filter-all` | internal |
| `trait.brute` | server_id | placeholder: `ui.filter-all` | internal |
| `trait.dark_devotion` | server_id | placeholder: `ui.filter-all` | internal |
| `trait.dire_wolf_bite_prone` | server_id | placeholder: `ui.filter-all` | internal |
| `trait.keen_hearing_and_sight` | server_id | placeholder: `ui.filter-all` | internal |
| `trait.keen_hearing_and_smell` | server_id | placeholder: `ui.filter-all` | internal |
| `trait.martial_advantage` | server_id | placeholder: `ui.filter-all` | internal |
| `trait.sneak_attack` | server_id | placeholder: `ui.filter-all` | internal |
| `trait.surprise_attack` | server_id | placeholder: `ui.filter-all` | internal |
| `trait.wolf_bite_prone` | server_id | placeholder: `ui.filter-all` | internal |

### feat — 1 non-ready assignments

| ID | Availability | Image treatment | Authored owner status |
| --- | --- | --- | --- |
| `feat.lucky` | server_id | placeholder: `ui.filter-all` | internal |

### condition — 111 non-ready assignments

| ID | Availability | Image treatment | Authored owner status |
| --- | --- | --- | --- |
| `condition.attack_assistance` | server_id | placeholder: `condition.generic` | ready |
| `condition.class.cleric.intervention_use` | server_id | placeholder: `condition.generic` | internal |
| `condition.class.divine.turned` | server_id | placeholder: `condition.generic` | ready |
| `condition.class.feature_lifetime` | server_id | placeholder: `condition.generic` | internal |
| `condition.class.paladin.aura_benefit` | server_id | placeholder: `condition.generic` | ready |
| `condition.class.paladin.aura_membership` | server_id | placeholder: `condition.generic` | internal |
| `condition.class.paladin.aura_owner` | server_id | placeholder: `condition.generic` | ready |
| `condition.class.paladin.cleansing_capacity` | server_id | placeholder: `condition.generic` | ready |
| `condition.class.paladin.divine_sense` | server_id | placeholder: `condition.generic` | ready |
| `condition.class.paladin.holy_nimbus` | server_id | placeholder: `condition.generic` | ready |
| `condition.class.paladin.purity_of_spirit` | server_id | placeholder: `condition.generic` | ready |
| `condition.class.paladin.sacred_weapon` | server_id | placeholder: `condition.generic` | ready |
| `condition.class.wizard.recovery_state` | server_id | placeholder: `condition.generic` | internal |
| `condition.consumable.weapon_coat.concentration_fire` | server_id | placeholder: `condition.generic` | ready |
| `condition.consumable.weapon_coat.fire` | server_id | placeholder: `condition.generic` | ready |
| `condition.consumable.weapon_coat.lightning` | server_id | placeholder: `condition.generic` | ready |
| `condition.consumable.weapon_coat.timed_fire` | server_id | placeholder: `condition.generic` | ready |
| `condition.environment.wet` | typed_only | placeholder: `condition.generic` | ready |
| `condition.revealed` | server_id | placeholder: `condition.generic` | ready |
| `condition.spell.acid_arrow` | server_id | shared: `spell.acid_arrow` | ready |
| `condition.spell.acid_surface.membership` | server_id | placeholder: `condition.generic` | internal |
| `condition.spell.animal_friendship` | server_id | shared: `spell.animal_friendship` | ready |
| `condition.spell.arcane_sword` | server_id | shared: `spell.arcane_sword` | ready |
| `condition.spell.aura_of_life.benefit` | server_id | shared: `spell.aura_of_life` | ready |
| `condition.spell.aura_of_life.membership` | server_id | shared: `spell.aura_of_life` | internal |
| `condition.spell.aura_of_life.owner` | server_id | shared: `spell.aura_of_life` | ready |
| `condition.spell.banishment` | server_id | shared: `spell.banishment` | ready |
| `condition.spell.bestow_curse.ability` | server_id | shared: `spell.bestow_curse` | ready |
| `condition.spell.bestow_curse.attack` | server_id | shared: `spell.bestow_curse` | ready |
| `condition.spell.bestow_curse.damage` | server_id | shared: `spell.bestow_curse` | ready |
| `condition.spell.bestow_curse.inaction` | server_id | shared: `spell.bestow_curse` | ready |
| `condition.spell.branding_smite` | server_id | shared: `spell.branding_smite` | ready |
| `condition.spell.calm_emotions` | server_id | shared: `spell.calm_emotions` | ready |
| `condition.spell.charm_monster` | server_id | shared: `spell.charm_monster` | ready |
| `condition.spell.charm_person.effect` | server_id | shared: `spell.charm_person` | ready |
| `condition.spell.dancing_lights` | server_id | shared: `spell.dancing_lights` | internal |
| `condition.spell.dispel_evil_and_good` | server_id | shared: `spell.dispel_evil_and_good` | ready |
| `condition.spell.dissonant_whispers` | server_id | shared: `spell.dissonant_whispers` | ready |
| `condition.spell.divine_favor` | server_id | shared: `spell.divine_favor` | ready |
| `condition.spell.dragons_breath` | server_id | shared: `spell.dragons_breath` | internal |
| `condition.spell.ensnaring_strike` | server_id | shared: `spell.ensnaring_strike` | ready |
| `condition.spell.eyebite.sickened` | server_id | shared: `spell.eyebite` | ready |
| `condition.spell.faerie_fire` | server_id | shared: `spell.faerie_fire` | ready |
| `condition.spell.feeblemind` | server_id | shared: `spell.feeblemind` | ready |
| `condition.spell.flame_blade` | server_id | shared: `spell.flame_blade` | ready |
| `condition.spell.flaming_sphere.aura` | server_id | shared: `spell.flaming_sphere` | ready |
| `condition.spell.flesh_to_stone.stages` | server_id | shared: `spell.flesh_to_stone` | ready |
| `condition.spell.foresight` | server_id | shared: `spell.foresight` | ready |
| `condition.spell.foresight.owner` | server_id | shared: `spell.foresight` | ready |
| `condition.spell.globe_of_invulnerability.zone` | server_id | shared: `spell.globe_of_invulnerability` | ready |
| `condition.spell.glyph_of_warding` | server_id | shared: `spell.glyph_of_warding` | ready |
| `condition.spell.glyph_of_warding.sleep` | server_id | shared: `spell.glyph_of_warding` | ready |
| `condition.spell.goodberry.batch` | server_id | shared: `spell.goodberry` | ready |
| `condition.spell.heroism` | server_id | shared: `spell.heroism` | ready |
| `condition.spell.hex` | server_id | shared: `spell.hex` | internal |
| `condition.spell.hex.quarry` | server_id | shared: `spell.hex` | ready |
| `condition.spell.hideous_laughter` | server_id | shared: `spell.hideous_laughter` | ready |
| `condition.spell.holy_aura` | server_id | shared: `spell.holy_aura` | ready |
| `condition.spell.holy_aura.blindness` | server_id | shared: `spell.holy_aura` | ready |
| `condition.spell.hunters_mark` | server_id | shared: `spell.hunters_mark` | internal |
| `condition.spell.hunters_mark.quarry` | server_id | shared: `spell.hunters_mark` | ready |
| `condition.spell.independent_summon_owner` | server_id | placeholder: `condition.generic` | internal |
| `condition.spell.irresistible_dance` | server_id | shared: `spell.irresistible_dance` | ready |
| `condition.spell.magic_weapon` | server_id | shared: `spell.magic_weapon` | ready |
| `condition.spell.moonbeam` | server_id | shared: `spell.moonbeam` | internal |
| `condition.spell.pass_without_trace` | server_id | shared: `spell.pass_without_trace` | ready |
| `condition.spell.pass_without_trace.bonus` | server_id | shared: `spell.pass_without_trace` | ready |
| `condition.spell.pass_without_trace.membership` | server_id | shared: `spell.pass_without_trace` | internal |
| `condition.spell.payload_lifetime` | server_id | placeholder: `condition.generic` | ready |
| `condition.spell.phantasmal_force` | server_id | shared: `spell.phantasmal_force` | ready |
| `condition.spell.phantasmal_killer` | server_id | shared: `spell.phantasmal_killer` | ready |
| `condition.spell.protection_from_evil_and_good` | server_id | shared: `spell.protection_from_evil_and_good` | ready |
| `condition.spell.ray_of_sickness.poison` | server_id | shared: `spell.ray_of_sickness` | ready |
| `condition.spell.regenerate` | server_id | shared: `spell.regenerate` | ready |
| `condition.spell.resilient_sphere` | server_id | shared: `spell.resilient_sphere` | ready |
| `condition.spell.searing_smite` | server_id | shared: `spell.searing_smite` | ready |
| `condition.spell.slow` | server_id | shared: `spell.slow` | ready |
| `condition.spell.spiritual_weapon.owner` | server_id | shared: `spell.spiritual_weapon` | internal |
| `condition.spell.starry_wisp` | server_id | shared: `spell.starry_wisp` | ready |
| `condition.spell.stinking_cloud.nauseated` | server_id | shared: `spell.stinking_cloud` | ready |
| `condition.spell.summon_dragon.shared_resistance` | server_id | shared: `spell.summon_dragon` | ready |
| `condition.spell.vampiric_touch` | server_id | shared: `spell.vampiric_touch` | ready |
| `condition.spell.vicious_mockery` | server_id | shared: `spell.vicious_mockery` | ready |
| `condition.spell.vitriolic_sphere.residue` | server_id | shared: `spell.vitriolic_sphere` | ready |
| `condition.spell.weird` | server_id | shared: `spell.weird` | ready |
| `condition.summon.draconic_breath_cadence` | server_id | placeholder: `condition.generic` | ready |
| `condition.summon.elemental_multiattack_bonus` | server_id | placeholder: `condition.generic` | ready |
| `condition.summon.myrmidon_strike_dice` | server_id | placeholder: `condition.generic` | ready |
| `condition.summon.raging_vortex_owner` | server_id | placeholder: `condition.generic` | ready |
| `condition.summon.sweetplum_field_owner` | server_id | placeholder: `condition.generic` | ready |
| `condition.summon.sweetplum_membership` | server_id | placeholder: `condition.generic` | internal |
| `condition.summon.sweetplum_restrained` | server_id | placeholder: `condition.generic` | ready |
| `condition.summon.tenacity` | server_id | placeholder: `condition.generic` | ready |
| `condition.tile.spike_trap` | server_id | placeholder: `condition.generic` | ready |
| `condition.tile.zone_marker` | server_id | placeholder: `condition.generic` | ready |
| `spatial_effect.class.paladin.aura` | server_id | placeholder: `condition.generic` | ready |
| `spatial_effect.item.devotees_mace.healing_incense` | server_id | placeholder: `condition.generic` | ready |
| `spatial_effect.spell.acid_surface` | server_id | placeholder: `condition.generic` | ready |
| `spatial_effect.spell.antilife_shell` | server_id | placeholder: `condition.generic` | ready |
| `spatial_effect.spell.aura_of_life` | server_id | placeholder: `condition.generic` | ready |
| `spatial_effect.spell.blade_barrier` | server_id | placeholder: `condition.generic` | ready |
| `spatial_effect.spell.flaming_sphere.aura` | server_id | placeholder: `condition.generic` | ready |
| `spatial_effect.spell.forcecage` | server_id | placeholder: `condition.generic` | ready |
| `spatial_effect.spell.glyph_of_warding` | server_id | placeholder: `condition.generic` | ready |
| `spatial_effect.spell.moonbeam` | server_id | placeholder: `condition.generic` | ready |
| `spatial_effect.spell.pass_without_trace` | server_id | placeholder: `condition.generic` | ready |
| `spatial_effect.spell.plant_growth` | server_id | placeholder: `condition.generic` | ready |
| `spatial_effect.spell.simple_toxin` | server_id | placeholder: `condition.generic` | ready |
| `spatial_effect.summon.fire` | server_id | placeholder: `condition.generic` | ready |
| `spatial_effect.summon.raging_vortex` | server_id | placeholder: `condition.generic` | ready |
| `spatial_effect.summon.sweetplum_gales` | server_id | placeholder: `condition.generic` | ready |

### item — 3 non-ready assignments

| ID | Availability | Image treatment | Authored owner status |
| --- | --- | --- | --- |
| `gear.saddle` | server_id | shared: `item.field-kit` | stand_in |
| `tool.banner` | server_id | shared: `item.field-kit` | ready |
| `tool.crowbar` | server_id | shared: `item.field-kit` | ready |

## Borrowed portrait assignments — 53

| Character ID | Existing portrait key | Portrait binding status | Body status |
| --- | --- | --- | --- |
| `creature.acolyte` | `cleric--human-white--male` | stand_in | stand_in |
| `creature.bandit` | `rogue--human-white--male` | stand_in | stand_in |
| `creature.bandit_captain` | `rogue--human-white--male` | stand_in | stand_in |
| `creature.berserker` | `barbarian--human-white--male` | stand_in | stand_in |
| `creature.bugbear` | `orcs_goblins--orc-04` | stand_in | stand_in |
| `creature.commoner` | `monk--human-white--male` | stand_in | stand_in |
| `creature.configured_srd.acolyte` | `cleric--human-white--male` | stand_in | stand_in |
| `creature.configured_srd.bandit` | `rogue--human-white--male` | stand_in | stand_in |
| `creature.configured_srd.bandit_captain` | `rogue--human-white--male` | stand_in | stand_in |
| `creature.configured_srd.berserker` | `barbarian--human-white--male` | stand_in | stand_in |
| `creature.configured_srd.bugbear` | `orcs_goblins--orc-04` | stand_in | stand_in |
| `creature.configured_srd.commoner` | `monk--human-white--male` | stand_in | stand_in |
| `creature.configured_srd.cult_fanatic` | `warlock--human-white--male` | stand_in | stand_in |
| `creature.configured_srd.cultist` | `warlock--human-white--male` | stand_in | stand_in |
| `creature.configured_srd.gnoll` | `orcs_goblins--orc-10` | stand_in | stand_in |
| `creature.configured_srd.guard` | `fighter--human-white--male` | stand_in | stand_in |
| `creature.configured_srd.hobgoblin` | `orcs_goblins--orc-03` | stand_in | stand_in |
| `creature.configured_srd.knight` | `paladin--human-white--male` | stand_in | stand_in |
| `creature.configured_srd.kobold` | `creature.goblin` | stand_in | stand_in |
| `creature.configured_srd.mage` | `wizard--human-white--male` | stand_in | stand_in |
| `creature.configured_srd.priest` | `cleric--human-white--male` | stand_in | stand_in |
| `creature.configured_srd.scout` | `ranger--human-white--male` | stand_in | stand_in |
| `creature.configured_srd.spy` | `rogue--human-white--male` | stand_in | stand_in |
| `creature.configured_srd.thug` | `rogue--human-white--male` | stand_in | stand_in |
| `creature.configured_srd.tribal_warrior` | `barbarian--human-white--male` | stand_in | stand_in |
| `creature.configured_srd.veteran` | `fighter--human-white--male` | stand_in | stand_in |
| `creature.cult_fanatic` | `warlock--human-white--male` | stand_in | stand_in |
| `creature.cultist` | `warlock--human-white--male` | stand_in | stand_in |
| `creature.dire_wolf` | `animals--elite-wolf` | stand_in | stand_in |
| `creature.generic_caster` | `sorcerer--human-white--male` | stand_in | stand_in |
| `creature.ghoul` | `top--zombie-decay-02` | stand_in | stand_in |
| `creature.gnoll` | `orcs_goblins--orc-10` | stand_in | stand_in |
| `creature.goblin_archer` | `creature.goblin_reedshot` | stand_in | stand_in |
| `creature.goblin_caster` | `creature.goblin_wispbinder` | stand_in | stand_in |
| `creature.guard` | `fighter--human-white--male` | stand_in | stand_in |
| `creature.hobgoblin` | `orcs_goblins--orc-03` | stand_in | stand_in |
| `creature.knight` | `paladin--human-white--male` | stand_in | stand_in |
| `creature.kobold` | `creature.goblin` | stand_in | stand_in |
| `creature.mage` | `wizard--human-white--male` | stand_in | stand_in |
| `creature.ogre` | `barbarian--1ogre` | stand_in | stand_in |
| `creature.ogre_zombie` | `hdz--zombiehulk1` | stand_in | stand_in |
| `creature.priest` | `cleric--human-white--male` | stand_in | stand_in |
| `creature.scout` | `ranger--human-white--male` | stand_in | stand_in |
| `creature.skeleton` | `undead--6warrior` | stand_in | stand_in |
| `creature.skeleton_warlock` | `undead--8necromancer` | stand_in | stand_in |
| `creature.skeleton_warrior` | `undead--6warrior` | stand_in | stand_in |
| `creature.spell.flaming_sphere` | `srd22.portrait.fire_elemental` | stand_in | internal |
| `creature.spell.spiritual_weapon` | `cleric--human-white--male` | stand_in | internal |
| `creature.spy` | `rogue--human-white--male` | stand_in | stand_in |
| `creature.thug` | `rogue--human-white--male` | stand_in | stand_in |
| `creature.tribal_warrior` | `barbarian--human-white--male` | stand_in | stand_in |
| `creature.veteran` | `fighter--human-white--male` | stand_in | stand_in |
| `creature.zombie` | `hdz--zombiemale1` | stand_in | stand_in |

## Verification

The headless `tests/ui_art_coverage_checks.gd` gate passed **2,460 checks, zero failures** after regenerating shipping icon outputs. It covers exact typed-domain collisions, all current spell icons, all typed class/action owners, explicit typed-only availability, current creature portraits, all selectable player portraits and shipping-map parity. It does not convert placeholder/shared status into visual approval. Evidence: `.runtime/schema16-ui-art-checks.log`.
