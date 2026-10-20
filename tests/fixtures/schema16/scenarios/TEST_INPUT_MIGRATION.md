# Native-suite recording inputs (20 October 2026)

All packet files are unchanged original schema16 seat journals. The catalog names their actual scenario and frozen engine identity. `commands.json` and `recording.json` are unchanged recorder outputs; `receipts.json` is a convenience extraction of the actual command/receipt/seat fields. No server configuration, credential, fake fact, old-protocol translation or cross-seat occurrence identity is supplied.

The following originals make the formerly argument-dependent tests reproducible:

| Catalog key | Actual source | Behavioral use |
| --- | --- | --- |
| `dash` / `dodge` | Existing stable cases | Real action, condition application, movement and removal |
| `disengage` | Expansion `action.disengage/departure`, original capture `20261019T233526.216651Z` | Contour owner lifetime, movement, actual removal |
| `gallery` | Existing real 60-command Gallery recording | Hierarchical combat text, multiple blood deposits and original world state |
| `revive` | Expansion `survival.revive/death_revivify_walk`, original capture `20261019T234434.151052Z` | Multiple actual missile packets, Alive→Dying→Dead, Revivify Dead→Alive and restored movement |
| `death-save-recovery` | Frozen SDK `survival.death_save/turns_seed2`, 20 October | One missile drops a living fighter; subsequent actual turn starts roll 6, 10, 9, 20; the natural20 restores 1 HP |
| `death-save` | Frozen SDK `survival.death_save/turns_seed4`, 20 October | Same legal setup; actual turn-start rolls16, 5, 3, 3; final LifeFact reason=`death_save_failures` |

The two new death-save captures use the ordinary `tools/studio_cases/worker.py` recorder and frozen engine211b. No new recorder rule or setup injection was needed. Each scenario's legal setup wounds the living fighter before recording; a real first missile then reaches zero, and the other two missiles target the healthy caster. The SDK ends ordinary turns. Both factions retain independent original events/cursors.

A bounded attempted repeat Magic Missile against the dying recipient was refused by the actual offered targets; its failed response remains in the ignored capture directory. A legally aimed Ice Storm did apply actual damage to that recipient but the later rolls stabilized it. Neither attempt is used as terminal-death evidence. The durable final-death fixture uses the actual third seed's natural save outcome.

`combat_timing_checks` exercises all five roles: nonlethal attack, lethal opportunity attack, actual final death after saves, natural save recovery, and Revivify. The final-death positive uses the actual Amber retained corpse. Its existing unseen-living negative is an explicit unit policy control: a private shallow state/audience copy excludes that one controller UUID and a private actor copy changes only life_state. It is not claimed as a recorded event or display state. The original canonical input is checked unchanged; Blue's actual later explicit absence is not misrepresented as a retained corpse. The marker perturbations continue to compare exact canonical after-values, commit identities/order, HP/flash clocks and selected source playback rates. Spell-local damage authoring takes precedence over generic/attack-only perturbations; life timing is compared with its actual native damage-request ancestry, so several missiles hitting one actor do not become one invented damage event.

The real Revivify case exposed an omitted authored Dead removal pose. The life-state typed context now explicitly gives `dead` the same authored reverse `Die` recovery source used for Dying/Stable; there is no spell-name switch or general fallback.

## Qualification receipts

The final headless input run produced `basic_condition_checks`198/0, `condition_selection_checks`132/0 and `media_source_delta_checks`5850/0 (`.runtime/tests/20261020T012513.260007Z`). After the exact corpse-policy control was corrected, `combat_timing_checks`passed4021/0 with no script/resource errors (`.runtime/tests/20261020T012822.482676Z`). This includes the actual authored Dead→Alive recovery and source-frame controls.

The headless closure-only probe (`.runtime/input-oracle-parse.log`) admits the frozen blood/shadow oracle scripts and the native condition test. That is parse evidence, not a native rendering pass. Native condition, blood-atlas and geometry-cache pixel comparisons remain the serialized GPU lane's responsibility; all original tolerances and source operands remain asserted.


## Remaining native-inventory input cohort (20 October)

Retired `.runtime/studio-cases`, old player runs and the generated schema9 Gallery descriptor are replaced by the preserved schema16 sources in this directory. `gallery/profile_case.json` names its actual first movement actor; `tools/profile_player_replay.gd --profile-case=` changes only the input descriptor and preserves its existing default and profiling logic. Single-view and thumbnail-cache GPU rows now explicitly pass `--native`, so their named gates exercise the native branch.

New durable originals copied from existing recordings are `jump`, `window`, `window-break`, `stairs`, `magic-missile`, `hold-person`, `blur`, `action-surge` and `prone`. The original Dash still has exactly twenty receiving blood cells; original Gallery operation18 follows the real deposit at17, and its Fireball operation59 owns eighteen received cells across two releases. Tests retain these actual deposit, overlap, worker ownership, publication and reversal requirements.

`blood_before_shape_cache.gd` is byte-for-byte `7faf78fb439173cd7f2d77024ad04b6a2da42f2c:presentation/blood.gd`, the actual original formerly stored only in `.runtime/blood-kernels-original.gd`. Its math is not replaced by current output. The loading test also supplies the closed pre-atlas renderer oracle explicitly.

`interaction-media` is a new legal frozen211b SDK recording: movement, actual unarmed strike, healing-potion7HP restoration and equipped shortbow attack. Both own-seat journals, original scenario, commands and receipts are preserved. `ranged` references these same originals; it is not another manufactured recording. `poisoned` preserves the follow-up actual starting-Poisoned membership and Protection from Poison removal. The original follow-up recording.json remains false because its pre-fix offline summary omitted initial owner identity. Recomputing the original journal with the corrected reader identifies the removed actual owner, without counting initial membership as an application. `cases.py:interaction_media_study` is the reproducible legal recipe; no production outcome is injected.

Nine gates (`audio_contact`, `blood_tile_index`, `character_media_first_use`, `scheduled_environment`, `studio_condition_navigation`, `studio_light_tracks`, `studio_material_method`, `studio_replay_comparison`, `world_preparation_sparse`) are pure value/ownership/timing/source-inspection checks and now use `mode=headless`, retaining `tier=gate` and every semantic assertion. Native framebuffer, audio, thumbnail and actual actor/shadow rendering tests remain GPU gates.

The 27-script closure probe passed with no parse errors (`.runtime/current-input-cohort-parse.log`). The first semantic probe exposed genuine remaining stale readers or policies instead of proving native output: seat-local comparison identities and old fixed jump durations; condition-row held-selection/fallback; exact item-look source requirements; the canonical optical-owner counterfactual; and Shield's native membership event reader. Those are tracked separately from the successful input replacement. No native GPU pass is claimed by this source migration.
