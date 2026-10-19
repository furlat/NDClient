# Spell and condition handover migration — 2026-10-19

This report covers all **191 typed spell entries** (189 current server spell IDs), against the installed Factory package `conditions-candidate-7fab471588209a41`: **155 lifecycle families, 148 exact owner IDs, 109 body-bearing owner IDs**. It records metadata and ownership compatibility; it does not claim visual approval or complete scenarios.

All **278 typed condition entries** use the existing `play_package_lifecycle` policy. Every one of the **147 condition owners** named by the package has an enabled typed entry. The remaining package owner is the existing spatial Web owner, whose explicit handover is preserved.

The migration joins exact `applies_conditions` IDs, exact Factory `condition.owner_ids` and `body_channel_included`, and the actual EffectUse `attached`/`recipient_*` roles. It does not infer condition names from spell names. Only new `owner_kind`, `owner_ids`, and `owner_cues` metadata changes in the 50 spell sources. Cast/body timings, positions, projectiles, area and impact cues remain as authored.

| Source disposition | Typed spells |
| --- | ---: |
| Recipient-attached body cues handed over to exact condition owners | 50 |
| Existing explicit owner/cue bindings preserved | 9 |
| Summon creation kept separate from transitive summon conditions | 8 |
| Delivered body owner; source has no eligible recipient-attached cue | 19 |
| No delivered body replacement for its declared conditions; cast kept | 51 |
| No authored condition application; no condition handover inferred | 54 |

Typed entries outside the current server spell ID list: `spell.antimagic_field`, `spell.ice_knife.burst`.

## New body handovers

The old attached cue is no longer dispatched or included in first-use preparation. The real condition instance owns application, sustain and removal through the existing package lifecycle path. Caster preparation, travel, area and impact effects retain their own event clocks.

| Spell | Exact owners | Attached cue indices |
| --- | --- | --- |
| `spell.aid` | `condition.spell.aid` | 0 |
| `spell.animal_friendship` | `condition.spell.animal_friendship` | 0, 1, 2 |
| `spell.arcane_sword` | `condition.spell.arcane_sword` | 0 |
| `spell.aura_of_life` | `condition.spell.aura_of_life.benefit`, `condition.spell.pass_without_trace.bonus` | 0, 1, 2, 3 |
| `spell.banishment` | `condition.spell.banishment` | 0 |
| `spell.barkskin` | `condition.spell.barkskin` | 0 |
| `spell.beacon_of_hope` | `condition.spell.beacon_of_hope` | 0 |
| `spell.bestow_curse` | `condition.spell.bestow_curse.ability`, `condition.spell.bestow_curse.attack`, `condition.spell.bestow_curse.damage`, `condition.spell.bestow_curse.inaction` | 0 |
| `spell.bless` | `condition.spell.bless` | 0, 1 |
| `spell.blur` | `condition.spell.blur` | 0 |
| `spell.calm_emotions` | `condition.spell.calm_emotions` | 0, 1, 2 |
| `spell.charm_monster` | `condition.spell.charm_monster` | 0, 1, 2 |
| `spell.charm_person` | `condition.charmed` | 0 |
| `spell.darkvision` | `condition.spell.darkvision` | 0 |
| `spell.death_ward` | `condition.spell.death_ward` | 0, 1, 2 |
| `spell.dispel_evil_and_good` | `condition.spell.dispel_evil_and_good` | 0, 1, 2, 3, 4, 5 |
| `spell.dissonant_whispers` | `condition.spell.dissonant_whispers` | 1, 2 |
| `spell.enhance_ability` | `condition.spell.enhance_ability` | 0 |
| `spell.expeditious_retreat` | `condition.spell.expeditious_retreat` | 0, 1 |
| `spell.eyebite` | `condition.spell.eyebite.asleep`, `condition.spell.eyebite.casting` | 1, 2, 3 |
| `spell.faerie_fire` | `condition.spell.faerie_fire` | 0, 1 |
| `spell.feeblemind` | `condition.spell.feeblemind` | 0, 1, 2 |
| `spell.fire_shield` | `condition.spell.fire_shield` | 0, 1, 2 |
| `spell.flesh_to_stone` | `condition.spell.flesh_to_stone.petrified`, `condition.spell.flesh_to_stone.stages` | 0, 1, 2, 3 |
| `spell.fly` | `condition.spell.fly` | 0, 1, 2 |
| `spell.foresight` | `condition.spell.foresight` | 0, 1, 2 |
| `spell.freedom_of_movement` | `condition.spell.freedom_of_movement` | 0 |
| `spell.haste` | `condition.spell.haste` | 0, 1, 2 |
| `spell.heroes_feast` | `condition.spell.heroes_feast` | 0, 1 |
| `spell.heroism` | `condition.spell.heroism` | 0, 1, 2 |
| `spell.hideous_laughter` | `condition.spell.hideous_laughter` | 0, 1 |
| `spell.holy_aura` | `condition.spell.holy_aura` | 0, 1, 2, 3, 4 |
| `spell.hypnotic_pattern` | `condition.charmed` | 0, 1 |
| `spell.irresistible_dance` | `condition.spell.irresistible_dance` | 0, 1, 2 |
| `spell.jump` | `condition.spell.jump` | 0, 1, 2 |
| `spell.longstrider` | `condition.spell.longstrider` | 0 |
| `spell.mirror_image` | `condition.spell.mirror_image` | 0 |
| `spell.pass_without_trace` | `condition.spell.pass_without_trace.bonus` | 0, 1, 2 |
| `spell.phantasmal_force` | `condition.spell.phantasmal_force` | 0, 1, 2 |
| `spell.phantasmal_killer` | `condition.spell.phantasmal_killer` | 0, 1, 2, 3, 4 |
| `spell.protection_from_energy` | `condition.spell.protection_from_energy` | 0 |
| `spell.protection_from_evil_and_good` | `condition.spell.protection_from_evil_and_good` | 0, 1, 2 |
| `spell.protection_from_poison` | `condition.spell.protection_from_poison` | 0 |
| `spell.regenerate` | `condition.spell.regenerate` | 0 |
| `spell.resilient_sphere` | `condition.spell.resilient_sphere` | 0 |
| `spell.see_invisibility` | `condition.spell.see_invisibility` | 0 |
| `spell.stoneskin` | `condition.spell.stoneskin` | 0, 1 |
| `spell.true_seeing` | `condition.spell.true_seeing` | 0 |
| `spell.vicious_mockery` | `condition.spell.vicious_mockery` | 1, 2 |
| `spell.weird` | `condition.spell.weird` | 0, 1, 2, 3, 4, 5, 6, 7 |

## Preserved explicit boundaries

| Spell | Owner kind and IDs | Cue indices |
| --- | --- | --- |
| `spell.bane` | `condition`: `condition.spell.bane` | 0 |
| `spell.guidance` | `condition`: `condition.spell.guidance` | 0 |
| `spell.light` | `condition`: `condition.spell.light` | 0 |
| `spell.mage_armor` | `condition`: `condition.spell.mage_armor` | 0 |
| `spell.resistance` | `condition`: `condition.spell.resistance` | 0 |
| `spell.sanctuary` | `condition`: `condition.spell.sanctuary` | 0 |
| `spell.shield` | `condition`: `condition.spell.shield` | 0 |
| `spell.shield_of_faith` | `condition`: `condition.spell.shield_of_faith` | 0 |
| `spell.web` | `spatial_effect`: `spatial_effect.spell.web` | 1 |

## Missing authored recipient boundary

These sources declare a condition that has delivered body art, but have no eligible recipient-attached EffectUse to hand over. Their existing effects remain intact. Some imported entries currently mark their attached cue as `caster_ground`; changing that placement requires actual authoring, not a condition-name guess.

| Spell | Delivered body-bearing declared owners | Current effect roles/attachments |
| --- | --- | --- |
| `spell.acid_arrow` | `condition.spell.acid_arrow`, `condition.spell.acid_surface`, `condition.spell.simple_toxin` | attached/caster_ground |
| `spell.aegis_spark` | `condition.aegis_spark` | none |
| `spell.branding_smite` | `condition.spell.branding_smite` | attached/caster_ground |
| `spell.chromatic_orb` | `condition.spell.acid_surface`, `condition.spell.simple_toxin` | attached/caster_ground |
| `spell.divine_favor` | `condition.spell.divine_favor` | attached/caster_ground |
| `spell.ensnaring_strike` | `condition.spell.ensnaring_strike` | attached/caster_ground |
| `spell.flame_blade` | `condition.spell.flame_blade` | attached/caster_ground |
| `spell.glyph_of_warding` | `condition.spell.glyph_of_warding.sleep` | attached/caster_ground |
| `spell.hex` | `condition.spell.hex.quarry` | attached/caster_ground |
| `spell.hunters_mark` | `condition.spell.hunters_mark.quarry` | attached/caster_ground |
| `spell.magic_weapon` | `condition.spell.magic_weapon` | attached/caster_ground |
| `spell.necrotic_bless` | `condition.spell.bane`, `condition.spell.bless` | none |
| `spell.searing_smite` | `condition.spell.searing_smite` | attached/caster_ground |
| `spell.shillelagh` | `condition.spell.shillelagh` | attached/caster_ground |
| `spell.sleep` | `condition.spell.sleep` | area/, cast/, flight/ |
| `spell.starry_wisp` | `condition.spell.starry_wisp` | attached/caster_ground |
| `spell.sunbeam` | `condition.spell.sunbeam` | attached/caster_ground, impact/ |
| `spell.vampiric_touch` | `condition.spell.vampiric_touch` | attached/caster_ground |
| `spell.vitriolic_sphere` | `condition.spell.vitriolic_sphere.residue` | attached/caster_ground |

## Shared-condition finish ownership

The build no longer assigns a condition the first alphabetic spell palette. An existing explicit `Condition.owner_spell` must name an available native candidate; otherwise a unique exact candidate is accepted. Multiple candidates are reported and the package retains its own appearance. No runtime validation is added.

| Condition | Actual candidate spells | Required decision |
| --- | --- | --- |
| `condition.charmed` | `spell.charm_person`, `spell.hypnotic_pattern` | Leave package-native finish or author an explicit condition finish owner. |
| `condition.spell.pass_without_trace.bonus` | `spell.aura_of_life`, `spell.pass_without_trace` | Review the actual `applies_conditions` declaration on Aura of Life; do not choose by spell name in the client. |

## Preserved summon creation

These sources list conditions used by their summon or its abilities. The summon creation effect remains event-owned; those transitive conditions cannot suppress it:

- `spell.conjure_animals`
- `spell.conjure_elemental`
- `spell.conjure_fey`
- `spell.conjure_fiend`
- `spell.flaming_sphere`
- `spell.planar_ally`
- `spell.spiritual_weapon`
- `spell.summon_dragon`

## Remaining non-body handover entries

The following declared-condition sources have only marker/no compatible body lifecycle replacement. Their existing cast effects remain, and their actual condition owners still use any delivered marker lifecycle. This is a body-handover classification, not a claim that those spells are fully rendered or scenario-tested.

- `spell.blindness_deafness`
- `spell.chill_touch`
- `spell.cloudkill`
- `spell.color_spray`
- `spell.command`
- `spell.create_or_destroy_water`
- `spell.dancing_lights`
- `spell.darkness`
- `spell.daylight`
- `spell.delayed_blast_fireball`
- `spell.divine_word`
- `spell.dragons_breath`
- `spell.enlarge_reduce`
- `spell.fear`
- `spell.fog_cloud`
- `spell.forcecage`
- `spell.freezing_sphere`
- `spell.globe_of_invulnerability`
- `spell.goodberry`
- `spell.grease`
- `spell.greater_invisibility`
- `spell.guiding_bolt`
- `spell.gust_of_wind`
- `spell.harm`
- `spell.hold_monster`
- `spell.hold_person`
- `spell.ice_storm`
- `spell.incendiary_cloud`
- `spell.insect_plague`
- `spell.invisibility`
- `spell.moonbeam`
- `spell.power_word_stun`
- `spell.prismatic_spray`
- `spell.ray_of_frost`
- `spell.ray_of_sickness`
- `spell.shocking_grasp`
- `spell.silence`
- `spell.sleet_storm`
- `spell.slow`
- `spell.spike_growth`
- `spell.spirit_guardians`
- `spell.stinking_cloud`
- `spell.sunburst`
- `spell.telekinesis`
- `spell.thunderwave`
- `spell.wall_of_fire`
- `spell.wall_of_force`
- `spell.wall_of_ice`
- `spell.wall_of_stone`
- `spell.wall_of_thorns`
- `spell.wind_wall`

The following sources have no authored condition application; the migration adds none:

- `spell.acid_flask`
- `spell.acid_splash`
- `spell.antilife_shell`
- `spell.antimagic_field`
- `spell.blade_barrier`
- `spell.blight`
- `spell.burning_hands`
- `spell.call_lightning`
- `spell.chain_lightning`
- `spell.circle_of_death`
- `spell.cone_of_cold`
- `spell.continual_flame`
- `spell.counterspell`
- `spell.cure_wounds`
- `spell.dimension_door`
- `spell.disintegrate`
- `spell.divine_smite`
- `spell.eldritch_blast`
- `spell.false_life`
- `spell.finger_of_death`
- `spell.fire_bolt`
- `spell.fireball`
- `spell.fixture.test_bless`
- `spell.flame_strike`
- `spell.greater_restoration`
- `spell.guardian_of_faith`
- `spell.heal`
- `spell.healing_word`
- `spell.hellish_rebuke`
- `spell.ice_knife`
- `spell.ice_knife.burst`
- `spell.inflict_wounds`
- `spell.lesser_restoration`
- `spell.lightning_bolt`
- `spell.magic_missile`
- `spell.mass_cure_wounds`
- `spell.mass_heal`
- `spell.mass_healing_word`
- `spell.misty_step`
- `spell.plant_growth`
- `spell.poison_spray`
- `spell.power_word_heal`
- `spell.power_word_kill`
- `spell.prayer_of_healing`
- `spell.produce_flame`
- `spell.remove_curse`
- `spell.revivify`
- `spell.sacred_flame`
- `spell.scorching_ray`
- `spell.shatter`
- `spell.sorcerous_burst`
- `spell.spare_the_dying`
- `spell.thaumaturgy`
- `spell.true_strike`

## Approval and proof

Aid, Bless, False Life and Sacred Flame remain user-rejected/partial with native staging disabled and their original notes preserved. Body handover metadata does not approve their shape, placement, timing or art. False Life still has no authored condition application; none is invented.

The direct headless gate `tests/condition_handover_checks.gd` passed **530 checks, zero failures** against the complete installed package and typed roots. It verifies all exact delivered owner policies, the 50 compatible migrations, the nine preserved bindings, all four rejected spell flags/notes, summon separation, superseded-cue preparation exclusion, and shared-condition ownership behavior. Evidence: `.runtime/schema16-condition-handover.log`. Native lifecycle draws, gameplay, sound and visual acceptance remain separate gates owned by the full delivery plan.

Inputs can be inspected with `tools/condition_handover_inventory.gd`, which only exports typed source data to `.runtime/condition-handover-inventory.json`. The shipping build remains the existing typed-resource abilities build; no parallel runtime catalog or family switchboard is introduced.
