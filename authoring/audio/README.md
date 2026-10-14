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

## Semantic selectors and current review work

These names select real shared-compiler clocks; `source_marker` in a cue is a
human-readable description, not the timing program.

| Selector | Current assignments | Review status |
| --- | --- | --- |
| `body.source_frame` | Walking stride, jump takeoff/touchdown | Markers above reviewed; sounds/mix provisional. |
| `body.contact` | Weapon release/swing, Magic Missile release | Existing authored body contact; artistic review pending. |
| `body.impact` | Shove, Action Surge | Existing authored body impact; artistic review pending. |
| `body.end` | Body fall, Prone application | Existing completion choice, **not** a reviewed floor-contact frame. |
| `event.start` | Dash/Dodge/Disengage, door state changes, rise, Prone removal, object impact/break | Explicit provisional event timing; these actions do not necessarily have an enabled body clip. |
| `damage.hp` | Physical damage impact | Existing causal damage clock; artistic review pending. |
| `condition.interval` | Concentration loop | Disclosed condition ownership; sound/mix provisional. |
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
