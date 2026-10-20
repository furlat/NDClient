# Scenario coverage worklist — 20 October 2026

Phase 5 expands genuine behavioral studies; a recorded outcome does not mean its
presentation is implemented or visually accepted. This lane changed recorder
sources and data only. It ran no Godot, GPU, source build or production backend.

## Current evidence and intake

Before this expansion the active library had **202 cases: 189 spell baselines
plus 13 larger studies; 196 recorded, 6 failed**. This batch supplies **42 additional
successful studies**, including **39 with independent original Amber/Blue
journals** and **3 explicitly single-party direct-character studies**.
There are **8 remaining failed requirements** with exact evidence retained:
the initial six recipe gaps plus two genuine passive outcomes whose public
typed attribution is missing. The current cohort source has 63 recipes in total,
50 absent from the old active library. Root merged all 50 current intake rows;
the active library now has **252 cases: 238 recorded, 14 failed**. This is scenario progress, not an all-spells/all-conditions
completion claim.

- Source recipes: [cases.py](../tools/studio_cases/cases.py).
- New intake index: [index.json](../.runtime/scenario-expansion-20261020/index.json).
- Exact observed damage, life transitions, movements, own-seat packet counts and
  receipt counts: [capture_evidence.json](../.runtime/scenario-expansion-20261020/capture_evidence.json).
- Complete per-ID spell/action/condition/reaction/class-feature/trait/feat matrix
  from the extracted registry plus actually observed identities (including empty coverage rows):
  [coverage.json](../.runtime/scenario-expansion-20261020/coverage.json).
- [Receipt and outcome qualification](../.runtime/scenario-expansion-20261020/receipt_qualification.json): **680 checks, zero failures**, covering 738 original packets and 197 committed commands across the 42 successful studies. Own-seat cursor identity is checked; equal cursors between factions are never assumed.
- Frozen native registry snapshot:
  [registry_ids.json](../.runtime/scenario-expansion-20261020/registry_ids.json).

This recording lane did not overwrite `.runtime/studio-library/index.json`.
Root merged the current recipe IDs, retained named failed requirements in the
library, and excluded the superseded historical
`spell.greater_invisibility/attack_then_removal` attempt. That attempt incorrectly
assumed the engine's BG3 Greater Invisibility always survives an attack. Its
original evidence is retained; separate failed-Stealth reveal and explicit
concentration-removal branches replace it.

All captures use frozen engine `211b71134ed15c89e62232587381f7e15a5961c3`, player
schema16, via ordinary SDK Choices/Preview/Command and actual receipts. Both
faction followers independently reduce and store their original response bytes.
No wire translation, rule injection, initial Hidden/Petrified cheat, nearest
recipient substitution or invented outcome is used. Wounded actors in survival
recipes are alive initially; the recorded hostile action causes dying/death.

## New study inventory

Every row is reachable through its actual spell/action/condition subjects;
these are capability studies, not a random replay list. Full source setup,
ordered commands, exact required outcomes and legal deterministic seed live in
the source recipe beside each ID.

| Study ID | Actual recording | Main transition |
|---|---|---|
| `action.class.barbarian.reckless_attack/reciprocal` | Recorded — both factions | Reckless Attack: setup, own attack, enemy response and expiry |
| `action.class.cleric.divine_intervention.arm_thy_servant/direct_character` | Gap; exact failure retained | Divine Intervention: actual permanent mace, unequip, equip and Healing Incense |
| `action.class.cleric.divine_intervention.golden_generosity/direct_character` | Recorded — one party seat | Divine Intervention: actual reward chest, loot transfer and close |
| `action.class.cleric.divine_intervention.opulent_revival/direct_character` | Recorded — one party seat | Divine Intervention: approach actual enemies, incoming damage and Opulent Revival healing |
| `action.class.cleric.divine_intervention.sunder_heretical/direct_character` | Recorded — one party seat | Divine Intervention: actual level10 Sunder, radiant recipient damage and death |
| `action.class.fighter.action_surge/extra_attacks` | Recorded — both factions | Action Surge: two attacks, extra action, two further attacks |
| `action.class.paladin.lay_on_hands/heal_ally` | Recorded — both factions | Lay on Hands: actual wounded ally healing and movement |
| `action.class.paladin.sacred_weapon/expiry` | Gap; exact failure retained | Sacred Weapon: exact held item, attack and natural expiration |
| `action.dash/budget_then_reset` | Recorded — both factions | Dash: ordinary spending, added allowance, departure and next-turn reset |
| `action.disengage/departure` | Recorded — both factions | Disengage: apply, leave real threat, expire and walk normally |
| `action.dodge/attack_then_expire` | Recorded — both factions | Dodge: actual incoming attack, expiry and ordinary movement |
| `action.help_attack/consume_assistance` | Gap; exact failure retained | Help Attack: helper selects enemy and ally, actual assisted attack consumes owner |
| `action.jump/land_and_walk` | Recorded — both factions | Jump: actual launch, landing and subsequent walking |
| `action.shove/forced_departure` | Recorded — both factions | Shove: real contest, forced displacement and recipient movement |
| `class_feature.cleric.blessed_healer/actual_self_heal` | Attribution gap — one actual party seat | Actual incoming Fireball, Healing Word on ally and real self-heal; passive handler attribution absent |
| `class_feature.cleric.destroy_undead/committed_turning_result` | Attribution gap — both factions | Actual failed Turn Undead save, Turned owner and radiant damage; passive handler attribution absent |
| `combat.fire/immunity` | Recorded — both factions | Fire damage: actual immunity outcome and recipient response |
| `combat.fire/resistance` | Recorded — both factions | Fire damage: actual resistance outcome and recipient response |
| `combat.fire/vulnerability` | Recorded — both factions | Fire damage: actual vulnerability outcome and recipient response |
| `condition.prone/drop_stand_walk` | Gap; exact failure retained | Prone: voluntarily lie down, stand at real cost, resume walking |
| `condition.prone/grease_auto_stand` | Recorded — both factions | Grease: actual failed save, prone owner, turn-start standing and movement |
| `conditions.hold/independent_owners` | Recorded — both factions | Paralysis: two actual spell owners, first removal retains second, final restoration |
| `interaction.storage/open_loot_close` | Recorded — both factions | Storage: actual chest opening, loot transfer and closing |
| `interaction.torch/carried_lifecycle` | Recorded — both factions | Carried torch: extinguish, move, ignite and extinguish |
| `movement.connector/ladder_return` | Recorded — both factions | Ladder: actual connector, elevated endpoint and return |
| `movement.connector/rope_return` | Recorded — both factions | Rope: actual action cost, elevated endpoint and later return |
| `movement.ramp/descent_ascent` | Recorded — both factions | Ramp: real height transition in both directions |
| `movement.stairs/ascent_descent` | Recorded — both factions | Stairs: real progressive supports, ascent and descent |
| `movement.window/cleared_both_directions` | Recorded — both factions | Window: enter actual empty aperture, cross and return |
| `movement.window/destroy_insert_cross` | Recorded — both factions | Window: actual grille destruction, retained frame and traversal |
| `reaction.opportunity_attack/airborne_lethal` | Recorded — both factions | Opportunity attack: real later airborne death stops uncommitted jump |
| `reaction.opportunity_attack/jump_resume` | Recorded — both factions | Opportunity attack: real jump interrupted by nonlethal hit and resumed landing |
| `reaction.opportunity_attack/walk_resume` | Recorded — both factions | Opportunity attack: real walking departure, reaction, damage and surviving route |
| `spell.blur/defend_then_remove` | Recorded — both factions | Blur: actual incoming attack, held movement and restored body |
| `spell.enlarge_reduce/enlarge_lifecycle` | Recorded — both factions | Enlarge: actual size owner, movement, attack and restoration |
| `spell.enlarge_reduce/reduce_lifecycle` | Recorded — both factions | Reduce: actual size owner, movement, attack and restoration |
| `spell.flesh_to_stone/petrification_restoration` | Recorded — both factions | Petrification: ordinary movement, failed saves, stone and restoration |
| `spell.greater_invisibility/concentration_removal` | Recorded — both factions | Greater Invisibility: ordinary movement, held owner and actual concentration removal |
| `spell.greater_invisibility/failed_stealth_reveals` | Recorded — both factions | Greater Invisibility: movement, attack, actual failed Stealth reveal |
| `spell.hold_person/agency_restoration` | Recorded — both factions | Hold Person: actual paralysis, skipped recipient turn, concentration end, movement restored |
| `spell.invisibility/attack_breaks` | Recorded — both factions | Invisibility: visible idle, vanish, move, attack and genuine reveal |
| `spell.invisibility/observer_counter` | Recorded — both factions | Invisibility: vanish, unseen movement, actual See Invisibility, observed movement, restoration |
| `spell.magic_missile/split_recipients` | Recorded — both factions | Magic Missile: three actual deliveries across two recipients |
| `spell.magic_weapon/wield_attack_remove` | Gap; exact failure retained | Magic Weapon: actual held weapon, recipient attack, removal and normal attack |
| `spell.scorching_ray/split_recipients` | Recorded — both factions | Scorching Ray: three actual deliveries across two recipients |
| `spell.shield_of_faith/defend_then_remove` | Recorded — both factions | Shield of Faith: recipient application, real attack, concentration removal |
| `spell.sleep/shake_awake` | Recorded — both factions | Sleep: ordinary actor, real spell sleep, adjacent ally wakes and moves |
| `spell.slow/movement_and_restore` | Recorded — both factions | Slow: actual application, reduced movement, concentration end and restored movement |
| `survival.revive/death_revivify_walk` | Recorded — both factions | Living fighter: real lethal damage, Revivify and restored movement |
| `survival.stabilize/heal_and_walk` | Gap; exact failure retained | Living fighter: real damage, dying, Spare the Dying, healing and walking |

## Named blockers, rather than fabricated completion

| Capability | Exact boundary and next work |
|---|---|
| Voluntary Prone / Stand Up | `action.core.drop_prone` is declared but not offered to the ordinary current fighter. Standard action setup omits it; the frozen roster behavior-grant applier also rejects that identity. The final recipe uses ordinary legal setup and fails at discovery. A separate real Grease→Prone→turn-start stand→movement study succeeds. Do not replace this gap with initial Prone. |
| Help Attack | The first Preview provides the named ally; Preview #2 repeatedly returns `stale_state` with the same actual revision/generation. Bounded fresh discovery does not fix it. The host maps most native rejections to this code, so the underlying issue may be the secondary selection, not publication timing. Original query stage, rejected response and committed prefix are retained. |
| Sacred Weapon / Magic Weapon | Actual actions/casts and weapon attacks commit. Their expected native membership is not present in these original packets, so the exact lifecycle requirements fail. The schema declares `ItemEffectsRow`, but these captures have neither a corresponding emitted row nor an actor condition membership. Resolve actual item-effect disclosure/ownership; do not manufacture a condition UUID from the action or combat-log text. |
| Spare the Dying | A real Magic Missile command produces `alive→dying`; the adjacent allied caster still receives `spell.spare_the_dying:no_valid_targets`. Both a 1HP wounded actor and an exact-zero first-hit setup were attempted. This also affects the old baseline. Preserve the actual dying/body HP facts and inspect native target eligibility. |
| Devotee's Mace / Healing Incense | Arm Thy Servant really creates and equips the mace; unequip/equip commands commit. `action.item.devotees_mace.healing_incense` is then absent from discovery. This is an incomplete item-action lifecycle, not missing spell artwork. The original native creation/equipment evidence remains useful independently. |
| Blessed Healer | An ordinary lawful level10 cleric and allied fighter take actual Fireball damage; Healing Word on the ally produces 10 ally HP and 3 self HP. The self HealFact has no parent and no typed `effective_handler` / `emitted_lineages` naming `class_feature.cleric.blessed_healer`. A combat-log string is insufficient. The strict case remains failed; original party-only fixture is `tests/fixtures/schema16/scenarios/blessed-healer/`. |
| Destroy Undead | A lawful level5 cleric's actual Turn Undead makes the ordinary Zombie fail its WIS save and take 17 Radiant damage. Neither independent journal attributes that result to `class_feature.cleric.destroy_undead` through typed handler metadata. The strict case remains failed; original two-faction fixture is `tests/fixtures/schema16/scenarios/destroy-undead/`. |

## Bounded repair of the six spell baseline gaps

The six baseline failures remain failed after inspecting their original logs
and correcting legal source recipes. Their source, exact own-seat receipts,
native exception lines and original damage/life/resource facts are collected in
[baseline_failure_evidence.json](../.runtime/scenario-expansion-20261020/baseline_failure_evidence.json).
The initial 50-row cohort intake is unchanged; these baseline rows replace
existing IDs rather than add new capabilities or improve the success count.

| Baseline | Actual bounded attempt and remaining boundary |
|---|---|
| Branding Smite, Searing Smite, Ensnaring Strike | Explicit equipped Longsword and exact ordinary Knight recipient still cause `capture._lineage_graph` to raise `ValueError: lineage requires terminal root and child facts`. The SDK command is indeterminate; it is never resubmitted. These require a native event-settlement/capture correction, not a renderer workaround. |
| Spare the Dying | A wounded but living ordinary Fighter takes exactly one real 4-point Magic Missile hit, enters DYING at exactly 0 HP, and takes no further missiles. Original Amber packet4 occurrences62/63 prove both damage and life state. The adjacent caster still receives `no_valid_targets`. Native `_collect_entity_actions` passes the global discovery `include_dead` into `_compute_target_pool` rather than this template's `include_dead=True`; the zero-HP candidate is removed before the spell's rule. The recipe now retains this precise legal evidence instead of starting with a dying actor. |
| Hellish Rebuke | The ordinary weapon probe missed, so it cannot qualify the trigger. A final actual Ice Storm deals 23 damage to the ordinary Fire Myrmidon and spends both its reaction and innate Rebuke resource. Neither independent journal emits the required reaction attribution or Fire damage. The older real Magic Missile trigger similarly spends those resources without the result. This is retained as a native result/disclosure gap, not silently accepted from resource consumption alone. |
| Fixture Test Bless | The original native startup rejects its roster spell grant: `Spell grant ...spell.fixture.test_bless@1 has no directly registered spell action`. It is a developer spell declaration, not a currently grantable action. No fake substitution with Bless, special engine import, or unnecessary new backend attempt is made. |

Latest corrected baseline journals are under
`.runtime/scenario-expansion-20261020/cases/`; their exact paths are in the
evidence report. The six failed outcomes are not relabeled as presentation
coverage. No frozen or production engine source was changed.

## Recorder changes and direct-character boundary

- Connector selections now match the **actual disclosed**
  `row.connector_traversal.command.destination_position`, retaining the native
  SelfBinding/index. The ladder/rope/window rows are not PositionBindings; no
  guessed connector or endpoint is added.
- A stale read is re-discovered at most twice before submission. Exact rejected
  responses are recorded. An issued command is never repeated; its submitted
  body and latest real receipt are retained, including a canceled/failed run.
- Outside-combat continuation uses the exact requested controlled actor through
  the engine's existing `outside_encounter` choices path. It does not wait for
  an input turn that can never reappear after combat ended.
- Worker/index perspective IDs come from actual config credentials. Ordinary
  recipes retain two seats. The existing native direct-player-build entry point
  has one `party` seat and AI opponents; no opposing view is fabricated.
- [cleric_level10_builds.json](../tools/studio_cases/scenarios/cleric_level10_builds.json)
  is a complete ordinary native CharacterBuild, extending the real level5 Life
  Cleric with `next_class_level` and actual class-choice requirements. Level8
  uses a legal Constitution ASI; level10 selects a new legal cantrip. The native
  pure build resolver succeeds. No resource/feature is injected.
- Sunder's capture requires actual positive applied **Radiant** damage, in
  addition to the actual action and life outcomes. Golden Generosity includes
  actual chest loot/close. Opulent Revival includes actual incoming damage and
  healing. Single-party results do not qualify independent faction disclosure.
- [blessed_healer_party_builds.json](../tools/studio_cases/scenarios/blessed_healer_party_builds.json)
  uses complete lawful level10 Cleric/Fighter builds and an ordinary Fireball
  scroll. No initial wounds, resource injection or passive fact is invented.
  Destroy Undead uses the ordinary level5 Life Cleric roster, where that feature
  is already granted, to retain two independent faction journals.
- Source compatibility remains frozen schema16 / engine `211b71134`. These
  fixtures preserve native source IDs, actor UUIDs, local occurrence identities
  and receipts. They are evidence of actual outcomes and absent attribution,
  not a new presentation contract or Factory visual acceptance.

## Work still required after intake

| Family | Next useful missing studies |
|---|---|
| Movement / interaction | Swimming and underwater support; lift/one-way passage; unavailable/stale connectors; real difficult terrain; blocked doors; corner reveal and repeated door close/open; lever/trap/campfire; item pickup/drop/transfer and coatings. Current stairs/ramp/window/door studies do not stand in for all of them. |
| Action economy / combat | Explicit hit/miss/critical and ranged reach variants; offhand/natural sources; multiple reactors and spent reaction refresh; shove failure/fall; actual death saves/stabilization; potion/temp-HP absorption; Help/Ally Help removals beyond Sleep. |
| Reactions / classes | Shield melee/ranged as well as Magic Missile; Counterspell automatic/check branches; Hellish Rebuke trigger; Protection/Parry/smite; class resources and invocation/recipient outcomes for every currently granted ability. |
| Condition lifecycle | The catalog matrix separates observed application from observed removal. Most condition baselines still lack movement/use/removal/restoration, suppression/overlap, seeking/admission history, event inputs, and all meaningful selector variants. A single baseline or applied child condition is not family completion. |
| Spells / constructs / summons | Variant and upcast branches; maintained-area entry/exit/move; actual wall sections and traversal/destruction; created-item lifecycle; summoned actor action/despawn; delayed/throwable payloads. No client-made fake scenarios or instant owner removals substitute for these. |
| Creatures | The new cohort uses the actual described player bodies, Goblins and limited existing creature sources. The remaining catalog creatures still need appearance, movement, attack, damage and death studies; spell baselines are not that coverage. |
| Presentation / Studio | Import through the existing same-reducer path; inspect all actual recipients, body/item/history/native/audio tracks; qualify seek/loop and meaningful clip bounds. No renderer/source-output or user-review axis is marked complete by this recording task. |

Reproduce a study with:

```sh
python3 tools/studio_cases/record.py \
  --engine /home/tommaso/.cache/ndclient/dnd_engine-211b71134 \
  --only spell.hold_person/agency_restoration \
  --out .runtime/scenario-expansion-20261020
```

Only one owned backend ran at a time. All owned backend processes are closed.
No Godot preview was opened by this lane.

## Stable interrupted-cast fixture

The original successful Counterspell baseline is also persisted under
`tests/fixtures/schema16/scenarios/counterspell/`, with `amber/` and `blue/`
original journals (seven packets each), `scenario.json`, `recording.json`,
`commands.json` and the actual command/receipt pairs in `receipts.json`.
Its native attribution is `reaction.spell.counterspell`; the interrupted cast
produces no fabricated spell damage. Shared fixture `catalog.json` was left to
root's ownership.
