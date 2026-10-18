# Condition effects: handoff to VFX production (18 October 2026)

For the VFX Factory production agent. The client is NDClientGodot, branch `feature/opus-refactor` at `3109b05` or later. The package installed is `20261018-c3c616e88a6b725f`.

The client now plays the package's 29 condition lifecycles in game and Studio (merge `30b8bd7`). This handoff lists what the client needs next. It has three parts:
1. Make the 29 cheap and correct.
2. Cover the visible conditions that have no effect yet.
3. Deliver the one spatial hold still frozen (Web).

Background: [VFX_PACKAGE_CONTRACT_2026-10-18.md](VFX_PACKAGE_CONTRACT_2026-10-18.md) §7–8.

## 1. How the client plays a condition lifecycle today

These rules are the contract for everything delivered below.

- **Lookup.** The key is the server's exact condition id, taken from `selections[].condition.owner_ids` (or `runtime_key`), with the `when` filter matched against the disclosed state. The ids come from the modern engine branch (schema 15). The full list is `authoring/server_ids.json` → `ids.condition` (235 ids, engine commit `ef82cb7ba`).
- **One occurrence per owner and lifecycle.**
  - It is built from the application clip and runs all three phases.
  - Every frame its `owner_state` input gets the phase (`application`, `sustain`, `removal`), the phase age and the owner's age.
  - It samples on the owner's age. The application plays at the real application.
  - The sustain runs for as long as the server keeps the condition: seconds, or hours for Aid. There is no expiry from the clip's length.
  - The removal starts at the real removal, from whatever sustain age the owner has reached.
- **Placement.** `registration` decides where it sits:
  - `recipient_ground`;
  - `recipient_body`, which means the head socket for overhead markers, or the body centre on rigs without one.

  It follows the recipient while it walks.
- **Visibility.** `visibility` decides when it shows: hidden with an invisible actor and by life state. An actor's overhead markers take turns, one group at a time by priority.
- **Spell visual handover.** When a lifecycle carries the spell's body visual (`body_channel_included`), the spell's own attached cue is not played at the cast. The condition's application replaces it.
- **Warm-up.** Every lifecycle warms while the game loads. A lifecycle that fails to build is reported and skipped (`3109b05`).
- **Checks the client runs:**
  - `tests/condition_lifecycle_checks.gd` (GPU). Builds every lifecycle twice and samples the sustain at 0, at the loop seam, at an arbitrary age, at 180 s and on a reverse seek, checking for no blank, no seam and no expiry trough. It also tests removal from sustain ages 0.5, 7.3 and 180 s, plus display selection.
  - `tests/condition_lifecycle_frames.gd`: Studio frames of the lifecycle cases.
  - Studio cases in `.runtime/studio-spells-20261018/<case>/amber/journal`: cast, condition held, walk with it on, the real end, a walk after.

## 2. Make the 29 cheap: recorded (or GPU) approaches

All 29 are native-only today. Each build runs a constructor on the game's main thread, so every first appearance in play is a visible frame spike, and loading waits for all 29.

Measured in the client (`condition_lifecycle_checks`, first build / rebuild):

| Lifecycle | Build ms | First-draw compiles |
|---|---|---|
| Sanctuary | 243 / 166 | 2–15 |
| Bane (body) | 210 / 160 | 2–15 |
| Shield of Faith | 155 / 118 | 2–15 |
| Resistance | 81 / 43 | 2–15 |
| Bless | 79 / 40 | 2–15 |
| Light | 70 / 47 | 2–15 |
| Mage Armor | 62 / 35 | 2–15 |
| Aid | 56 / 38 | 2–15 |
| Guidance | 54 / 32 | 2–15 |
| Shield | 39 / 29 | 2–15 |
| 19 overhead markers | 23–66 / 9–16 | 0–2 |

**Request:** deliver a `recorded` approach for every application, sustain and removal clip (or `gpu` where a recording cannot hold the look), like the 645 spell recordings. Acceptance:

- **Build:** under 1 ms after warm-up, and 0 pipeline compiles at the first in-play draw.
- **Sustain:** an exact seamless loop of a stated `loop_seconds`. The client samples `owner_age mod loop_seconds`.
- **Removal:** must start without a pop from any sustain age. Either deliver the removal from loop phase 0 and state a short crossfade the client applies (≤ 0.15 s), or deliver removals at evenly spaced loop phases. Say which, in the index.
- **Application:** ends where the sustain loop begins.
- **No per-frame cost:**
  - Today `occurrence.set_owner_state` walks the whole effect node tree twice on every call, and the phase age has to be sent every frame.
  - A recording should need only the sample time.
  - If live inputs remain, make them O(1).

## 3. Fix the defects found in the 29

1. **Shield of Faith:** the sustain goes blank after about 5 s. Its emitters fire once; there are no `continuous_emitters`.
2. **Sanctuary:** the sustain drops to about 15% of its coverage once the ring disappears.
3. **Guidance:** the sustain is about 7% of its opening coverage after 2 s, nearly invisible.
4. **Aid:** the application draws nothing for its first 0.55 s.
5. **Light and all 19 markers:** the sustain is static (`steady_artwork`).
   - The user's request is an animated hold: the "immobile Shield looks dead" feedback applies to every lasting condition.
   - Give each one gentle motion (breathing, orbit, flicker) that loops seamlessly.
6. **`origin_path`:** markers use `Glyph`, which is inside the component, while body lifecycles use `effect/Retained`, from the root. Use one convention.
7. **Bane:** has two lifecycles on one condition id (body orbit + marker). The client plays both. Confirm that is intended and document it in the index.

## 4. Cover the visible conditions that have no effect

There are 235 server conditions. 40 are covered by the 29 lifecycles through `owner_ids`. 40 more are zone or spatial-effect conditions (§5).

The remaining **138 visible body conditions** have no package effect. Below they are grouped by what they are, from the server snapshot and the hand-checked key-space review. Some are handled by the client alone and need no effect; those are listed at the end.

**Core conditions (D&D standard):** blinded, charmed, deafened, stunned. Overhead markers like the existing 19.

**Spell conditions on the body.**

Buffs and wards:
- aid-like auras: `aura_of_life.owner/benefit`, `holy_aura`
- `barkskin`, `beacon_of_hope`, `blur`, `darkvision`, `death_ward`, `dispel_evil_and_good`, `divine_favor`
- `enhance_ability`, `expeditious_retreat`, `fly`, `foresight`, `freedom_of_movement`
- `haste`, `heroism`, `jump`, `longstrider`, `magic_weapon`, `mirror_image`, `pass_without_trace`
- `protection_from_energy`, `protection_from_evil_and_good`, `protection_from_poison`
- `regenerate`, `see_invisibility`, `shillelagh`, `stoneskin`, `true_seeing`
- `fire_shield` (warm and chill), `flame_blade`, `flaming_sphere.aura`, `summon_dragon.shared_resistance`

Debuffs and marks:
- `acid_arrow` (acid DoT), `bestow_curse.{ability,attack,damage,inaction}`, `branding_smite` (outline)
- `chill_touch` (no-heal), `faerie_fire` (glowing outline), `feeblemind`, `hex.quarry`, `hunters_mark.quarry`
- `phantasmal_force`, `ray_of_sickness.poison`, `searing_smite` (burning), `starry_wisp` (outline)
- `vicious_mockery`, `vitriolic_sphere.residue` (acid DoT), `acid_surface`, `simple_toxin`

Control:
- `animal_friendship`, `banishment` (removed from the map), `blindness_deafness`, `calm_emotions`
- `charm_monster`, `charm_person.effect`, `color_spray`, `dissonant_whispers` (forced flee)
- `divine_word`, `ensnaring_strike` (vines), `eyebite.asleep`, `glyph_of_warding.sleep`, `hideous_laughter`
- `irresistible_dance`, `phantasmal_killer`, `power_word_stun`, `prismatic_spray.restrained`
- `resilient_sphere` (encased), `sleep` (asleep), `sunbeam.blinded`, `sunburst.blinded`
- `web.restrained` (webbed body; the package has `webbed_entity_native` as an entity study), `weird`

Transformations:
- `flesh_to_stone.stages` → `flesh_to_stone.petrified`: a staged turn to stone.
- `summon.transmuted_to_steel`.

Caster states with a visible cue:
- `eyebite.casting`
- `sunbeam` (can re-strike)
- `vampiric_touch` (can re-strike)
- `arcane_sword` (sword owner)

**Weapon coatings** (attach to the weapon, not the body):
- `consumable.weapon_coat.fire`, `.lightning`, `.timed_fire`, `.concentration_fire`, `.basic_poison`, `.assassin_poison`.
- The package needs a `registration` attachment for the weapon or hand (`recipient_weapon`). Please add it to the condition schema.

**Class:**
- Turned (`class.divine.turned`, flee).
- Paladin: `aura_owner/aura_benefit`, `divine_sense`, `holy_nimbus` (radiant light aura), `purity_of_spirit`, `sacred_weapon` (weapon glow, also weapon-attached).

**Summon riders:**
- `summon.brittle`, `.burning`, `.chilled`, `.dazed`, `.shocked`, `.trembling_legs`, `.sweetplum_restrained`
- the buffs on summons: `draconic_breath_cadence`, `elemental_multiattack_bonus`, `myrmidon_strike_dice`, `tenacity`

**Other:** `aegis_spark` (ward), `field_focus`, `revealed` (outlined).

**Handled by the client alone; no effect needed now:**
- Stances `hidden`, `dodging` and `disengaging` (client looks and poses).
- `invisible`, `invisibility` and `greater_invisibility`. Client transparency today; a subtle shimmer is welcome but optional.
- States `concentrating`, `dashing`, `underwater`, `summoned`, `summon_control`, `attack_assistance`. HUD icon only for now.
- Item and timer markers `goodberry.batch`, `payload_lifetime`, and the internal owner or membership markers.

**Order of work:**
1. The core four.
2. The control conditions.
3. Buffs and debuffs with a clear visual (outlines, auras, burning, acid, vines, petrification).
4. Coatings, which need the weapon registration.
5. Class conditions.
6. Summon riders.

Deliver each condition with a recorded approach from the start (§2).

## 5. Spatial: Web's net, and the zones

- **Web's area net still holds a single staged pose.** The package has no spatial lifecycle for `spatial_effect.spell.web`. Deliver application/sustain/removal for it in the same owner-driven form. The owner is the server's spatial effect, and the client already masks it to the unsuppressed cells.
- **The other 39 zone and spatial-effect ids** (fog cloud, darkness, silence, walls, auras, moonbeam, grease, spike growth and others) are surfaces. They will get their own handoff from the client's environment migration. The package's surface scenarios (`grease__surface`, `oil_ignite_douse`, `web_ignite_douse`, freeze/thaw, steam, `ice_dome_native`) are already noted there.

## 6. Delivery

- Same package, same schema (`vfxfactory.condition_lifecycle.v1`). Key each selection by the exact server condition id (`runtime_key` and `owner_ids`), with `when` where one effect serves several states.
- Publish into `assets/vfx/` as before, with a version bump, the binary backup and your client receipt.
- Please name the version in the handoff so the client commits it on its own: the client stages package changes explicitly.
- Run `tests/condition_lifecycle_checks.gd` against the new package and include its report. It must reach 0 failures; today there are 16, all from §3.
- Staging stays client-owned. The client's presentation source binds each condition to its lifecycle and decides scale and registration overrides. Your registration is the starting value.
