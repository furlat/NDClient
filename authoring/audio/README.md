# Audio authoring handoff

The current sounds are temporary licensed sources. The compiler produces the same
inspectable audio components used by the game, Studio timeline and native players.
Editing these files changes that shared presentation; there is no Studio-only timer.
The server remains authoritative for movement, damage, conditions and visibility.

## Where to edit

| File | Artist-owned choice |
| --- | --- |
| `bindings.json` | Event/content selection, cue ID, executable semantic timing selector, review status. |
| `contacts.json` | Rig, native animation clip, trajectory, foot/contact frame, crossing direction and review evidence. |
| `cues.json` | Source variants and durations, per-variant transient sync, gain, bus, attachment, loop and release fade. |
| `sources.json`, `licenses/` | Provenance and license of every delivered sound. Keep these when replacing sources. |
| `waveforms.json` | Source waveform previews. Regenerate when replacing a file; this is not evidence of emitted audio. |
| `../presentation/actions/hide.tres` | Hide's native action effect frame and its selected `effect_audio_cue`. |

The waveform is the complete selected source. Studio separately marks its authored
contact and reports the timing source, selected variant, source-sync offset and
native voice status. A prepared waveform does not imply a sound was heard.

## Contact frames and source transients

Frames are **zero-based frame boundaries**. A marker at frame3 occurs when frame3
begins. A nonlooping `clip_end` marker at frame15 denotes the end boundary of a
15-frame clip, not an extra sprite. Markers are inverted through the body's actual
`source_time_keys`; rate changes and held/reversed phases retain their authored
source meaning. Set `direction` to `forward` or `reverse` explicitly. Holds do not
repeat contacts. A contact shared by adjacent body segments belongs to the arriving
segment once; genuine animation loops repeat the marker.

Current qualified markers:

| Rig / clip / trajectory | Contact | Cue / source sync | Evidence and status |
| --- | --- | --- | --- |
| Modular / Run / path | Frames3 and10 | footstep /0s | E and SW source frames inspected; provisional artistic placement. |
| Modular / CrouchRun / path | Frames2 and9 | footstep /0s | E and SW source frames inspected; provisional artistic placement. |
| Modular / Rolling / direct_arc | Frame0 | jump_takeoff /0s | Start of the admitted jump body. |
| Modular / Rolling / direct_arc | Frame15, `clip_end` | landing /0.080s | Actual native Jump reaches world ground at this endpoint. Frames11 and14 remain airborne. |

`contacts.json` contains the source and native capture evidence. Creature clips and
window connector motion have **not** been reviewed for foot contacts. They emit
`source_contact_markers_not_authored` gaps, not guessed tile-end sounds. A valid
marker outside the current split segment emits nothing; an interrupted arc that
never reaches its contact does not invent a landing.

The landing source has a soft prelude and its strongest impact at approximately
81.75ms. Its authored `source_sync_s` is0.080. For every one-shot:

```
contact_ms = resolved semantic or native source-frame marker
start_ms   = contact_ms - selected_variant.source_sync_s * 1000
```

The full sound begins80ms before touchdown; its impact reaches ground contact.
Duration and waveform retain the complete source, including its prelude and tail.
This does not change the jump arc, spatial endpoint or server commit. The source
is not pitched according to movement speed; Studio transport speed affects both
animation and native playback normally.

Each `source_sync_s` array must match `clips` and `clip_durations_s` in length. Choose
the actual transient independently for each replacement variant. A missing sync,
invalid frame, unsupported crossing or unavailable lead-in is an explicit gap.
The compiler never silently clamps a sound to an owner start and makes its impact
late. Loop cues currently require source sync0; arbitrary loop transient shifting
has no supported interval semantics. Native Ogg loops must end at the file end.

### Source-authored endpoint assignments, 21 October

`contacts.json` now also selects Goblin Rolling/direct_arc frame0 takeoff and
frame14 landing from that rig's actual `0 → 3 → 10 → 14` full-arc source keys;
modular Run/connector_transfer reuses its frame3/frame10 stride source; modular
Rolling/window connector uses forward frame0 takeoff and reverse frame0 landing
from the existing `0 → 3 hold → 0` body program. These source choices are
unvalidated; all artwork/audio, contact placement and mix remain unreviewed.

An optional `motion_endpoint` value of `start` or `end` qualifies a source-frame
crossing using the actual motion fraction, disclosed endpoints/elevations and
the same `Tracks.samples` lift used for rendering. A repeated source loop,
incomplete arc or positive lift cannot authorize a qualified landing. The
qualifier does not move a marker, change a source/body clock or turn a step-end
into a contact. The modular direct-arc markers use it too. A marker outside a
split segment still emits nothing.

Goblin Run/path still needs actual planted-foot source-frame authoring; do not
copy modular frames onto it. The two Blue late-lethal clip-end refusals remain:
that original discloses only ground→air/air→air Steps and no complete Movement
path. The other independently recorded audience cannot supply its touchdown.
Exact existing art and original paths are in
`agent_docs/ASSET_AUDIO_REVIEW_2026-10-20.md`.

## Semantic selectors and current review work

These names select real shared-compiler clocks; `source_marker` in a cue is a
human-readable description, not the timing program.

| Selector | Current assignments | Review status |
| --- | --- | --- |
| `body.source_frame` | Walking stride, jump takeoff/touchdown | Markers above reviewed; sounds/mix provisional. |
| `body.contact` | Weapon/unarmed release, physical potion swallow, Frenzy stance | Existing authored body contact; artistic review pending. |
| `body.commit` | Equipment handling | Same authored equipment frame as the visual/state commit; sound/mix provisional. |
| `body.impact` | Shove, Action Surge | Existing authored body impact; artistic review pending. |
| `body.end` | Body fall, Prone application | Existing completion choice, **not** a reviewed floor-contact frame. |
| `event.start` | Dash/Dodge/Disengage, door state changes, torch ignition, rise, Prone removal, object impact/break | Explicit provisional event timing; these actions do not necessarily have an enabled body clip. |
| `damage.hp` | Physical damage impact | Existing causal damage clock; artistic review pending. |
| `condition.interval` | Concentration audio intentionally unassigned | Binding disabled by the human; generic loop-player support and sources remain preserved. |
| `recipe.effect_anchor` | Hide transition | Native `hide.tres` effect frame; selected cue remains provisional. |

Missing body timing stays a gap instead of falling back to event start. The
existing body-fall/prone completion choices are intentionally documented for the
artist to replace with inspected contact markers later; they are not claimed as
newly qualified foot-ground timing.

Current cue gains and attachments are in `cues.json`: footsteps−12dB/ground,
landing−10dB/ground, jump takeoff−18dB/body, with every source using `SFX`.
Other cue values remain individually authored. Ground, body, target-body,
weapon/hand/head, world and UI attachments use the presenter's existing semantics;
required missing sockets produce an attachment gap. Do not invent an undisclosed
actor's location. Variants use the declared deterministic occurrence-ordinal
selection; random pitch and material inference are not implemented.

To replace a sound, update its source/provenance, duration, waveform and transient
sync together, then adjust gain/attachment and mark its review status. To move a
footstep, edit the corresponding contact frame/direction in `contacts.json`.
Review the full native animation and world motion: a foot drawn near the sprite
origin can still be airborne because the world arc lifts the entire sprite.

## Validation

Fast tests: `tests/audio_contact_checks.gd` checks source clocks, split/loop/hold/
reverse boundaries, transient synchronization, invalid authoring and actual Move/
Jump/early and late lethal journals. `tests/base_audio_checks.gd` checks recorded
base bindings and explicitly lists unreviewed contact gaps. Native stream and
transport ownership checks remain in `tests/audio_presenter_checks.gd`.

The slower Forward+ `tests/studio_audio_transport_checks.gd` loads the real Move
recording, exercises whole playback, selected-onset play, silent seek-inside and
two loop passes, then Jump, melee and Hide/light. It records native voice source
clocks and SFX mixer PCM separately. Start it with
`--recording=res://.runtime/studio-cases/walk_diagonal-seed3-v2/amber/journal`.
Native source-frame screenshots are under `.captures/audio-contact/`. This is
render/mixer evidence, not a claim of physical-speaker audibility or a final mix.

## Current base coverage and deliberate omissions — 14 October

The human excluded spell/VFX sound authoring and requested removal of the existing
Magic Missile sound. Its release and concentration's persistent sound now have
`enabled: false` and `reason: spell_audio_deferred` in `bindings.json`. The shared
resolver returns inspectable missing components without a clip. Removing or
disabling an assignment never removes source assets, licenses or generic native
loop support. Spell audio remains a separate authoring pass.

Base additions use the same compiler components as tracks and native playback:
equipment handling at `body.commit`, explicitly disclosed unarmed attacks at
`body.contact`, Frenzy's quiet cloth transition, physical potion swallowing and
torch ignition. Action Surge now uses physical cloth rather than its former
magical source. An absent weapon alone does not select unarmed audio. Potion
swallowing is independent of its magical effect. Ignition is a provisional
adaptation of qubodup's matchstick/flare recording, assigned only to the physical
torch action. Torch and unarmed cues deliberately use provisional body placement;
no hand socket is inferred. Sound selection, transient placement and mix remain
an artist pass.

Equipment's `attachment_source: disclosed_stationary_body` permits its actual
stationary source body to emit without a visual draw handle. The component keeps
this policy beside its source track. Exact actor identity, explicit current
presence/spatial presence, matching disclosed position, stationary position and
elevation, and an existing authored rig body anchor are required. Unknown, moved
or removed actors and missing anchors remain attachment gaps. This does not
grant a hand/weapon socket or disclose another actor's location.

New source selections/provenance are in `sources.json` and `licenses/`: Kenney's
existing CC0 belt sound, qubodup's CC0 Liquid Bottle Drink Set and Flare ignition.
Original FLACs/packages stay in `.runtime/audio-intake/`; the selected FLACs use
classic PCM24 WAV containers with equal decoded source samples. There is no
resampling, gain processing or source deletion. `tools/import_studio_audio.py`
checks equality, source duration and waveforms. For 7z members it uses native
Windows `tar`/libarchive; from WSL pass
`--archive-extractor /mnt/c/Windows/System32/tar.exe`.

Current explicit gaps include torch extinguishing (no suitable selected source),
window `Rolling/connector_transfer` contact markers and the looped/disclosed-edge
`Rolling/direct_arc` clip-end markers in the late-lethal Blue jump perspective.
The current movement/OA Goblin handaxe occurrence also has no qualified weapon
socket; its ready source is explicitly skipped and reported by native diagnostics.
Those two end-marker gaps are preserved; they do not authorize changing the
animation clock or inventing touchdown. Unreviewed creature contacts are also
unchanged, and no creature movement is exercised in the current Library set.
Other unassigned spell/condition lifecycles are inventoried without inventing a
universal entry/removal sound.

### Physical weapon variants, 20 October

The current Library audit exposed equipped attacks whose exact item IDs did not
select their already-authored physical base-weapon swish. `bindings.json` now
names the following ten variants explicitly, preserving each base binding's
existing cue, `body.contact` selector and provisional review status:

| Exact item | Existing base assignment |
| --- | --- |
| `weapon.arcane_staff` | `weapon.quarterstaff` |
| `weapon.circus.flaming_scimitar` | `weapon.scimitar` |
| `weapon.circus.longsword_plus_one` | `weapon.longsword` |
| `weapon.devotees_mace` | `weapon.mace` |
| `weapon.roster.ember_greatsword` | `weapon.greatsword` |
| `weapon.roster.ember_longsword` | `weapon.longsword` |
| `weapon.roster.psychic_greataxe` | `weapon.greataxe` |
| `weapon.roster.psychic_longsword` | `weapon.longsword` |
| `weapon.roster.psychic_longsword_greater` | `weapon.longsword` |
| `weapon.roster.psychic_scimitar` | `weapon.scimitar` |

These are exact mechanical base/WeaponKind associations in the frozen engine's
`dnd/content/items/{authored_item_definitions,roster_item_definitions}.py` and
`dnd/items/divine_rewards.py`, not inference from art or item names. They add
only the physical swing/release; fire, psychic, radiant and other riders do not
inherit a sound. They neither select new assets nor change source-sync offsets,
gain, attachment, authored body clocks or magical-audio exclusions.

The final content batch explicitly assigns the existing broad physical swish
`weapon_swing_heavy` to `weapon.circus.soul_draining_morningstar` (Morningstar)
and `weapon.roster.psychic_trident` (Trident). The real created Scimitar
`weapon.flame_blade` selects the existing physical blade swish `weapon_swing`.
These are authored source reuse decisions at the same `body.contact` clock;
necrotic, psychic and fire sounds are not inferred. All three sound choices,
placement and mix remain unreviewed, and no new native playback is claimed.

The torch inventory still contains ignition only, with no selected extinguishing
source. Magic Missile and concentration bindings remain disabled by the human.
The 18:08:59 audit predates these thirteen assignments; its counts are historical,
not a fresh playback or post-change coverage receipt. See the exact remaining
catalog/owner handoff in `agent_docs/ASSET_AUDIO_REVIEW_2026-10-20.md`.

`tools/studio_audio_coverage_audit.gd` reads all current Library audiences and
reports actual event owners, resolved sources/timing and condition assignments
to `generated/studio_audio_coverage.json`. The initial inventory is retained in
`generated/studio_audio_coverage_before.json`. Neither report is playback proof.
Native source PCM and actual Studio transport evidence are separate in
`generated/base_audio_native_checks.json` and
`generated/studio_audio_transport_checks.json`; replay mixer WAVs for audition
are under `.captures/studio/audio/`.

This pass qualifies 54 contact, 94 presenter, 1838 real-binding (57 audience),
71 isolated native and 249 actual Studio checks. The Studio lane saves 14 replay
mixer captures, verifies the new equipment selected-loop and silent-inside-seek,
plays physical Action Surge in the real action-economy study and verifies both
listening factions without duplicate native starts. The coverage audit links
those saved dispatch/skip outcomes to the same component IDs. A source-ready
handaxe socket omission remains a reported runtime gap, not a successful voice.
