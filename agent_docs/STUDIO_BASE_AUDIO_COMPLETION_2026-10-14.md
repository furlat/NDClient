# Existing Studio audio completion

The human authorized completing audio in current Studio scenarios, then excluded
spell/VFX sounds and requested removal of Magic Missile's current sound. This
continues the audio authoring section of the Studio base-mechanics plan only.
Preserve concurrent sandbox work, native visual integration and approved lighting.

Requested behavior: supported base actions produce native sound on the same
resolved clocks shown in Studio. Spell assignments are explicitly deferred.
Boundary: shared compiler components, Studio tracks/diagnostics and native SFX
mixer output. Input: existing real Library journals and actual authored bodies.
Output: correctly owned cue starts, silent scrubbing, one voice per admitted
occurrence/pass, one selected listening audience, and visible unassigned sources
or unreviewed contacts.

1. Inventory every current Library audience, actual event owners, contact tracks,
   cue assignments, source availability and resolved markers before editing.
2. Disable spell release/concentration assignments while preserving their source
   assets and generic native loop support. Fill base equipment, disclosed unarmed
   attacks, stance and physical interaction gaps using authored data. Preserve
   qualified Run/CrouchRun/Jump contacts and the landing source's 80 ms sync.
3. Check resolved components against real journals, then native Windows Godot
   Forward+/WASAPI playback for new cues and seek/loop/listener ownership.
   Mixer PCM establishes output, not physical speaker audibility or a final mix.
4. Record added coverage, finite evidence and unresolved sources/contact markers
   in the audio handoff; do not claim full spell/condition implementation.

Review is assigned to the audio plan-adherence subagent throughout implementation.
Its anti-slop review checks source/timing/output evidence against claims; its
anti-OOP review checks passive authoring and reuse of existing compiler/player
owners without a new scheduler or presentation system. The final review checks
the actual diff and reports, independently of historical acceptance counts.

## Implemented and qualified

The initial inventory covers all 57 current Library audiences. Added authored
source coverage: 56 equipment occurrences, two torch ignitions, two Frenzy stance
changes, one physical potion swallow and one explicitly unarmed release. Action
Surge's two authored occurrences now select physical cloth. These audience counts
are resolved source assignments, not 62 independent human listening events.
Magic Missile's eight disclosed occurrences resolve explicit disabled rows;
concentration's persistent selection is disabled as well. Original source assets,
licenses, generic loop support and visual authoring are preserved.

Equipment body placement is an explicit `disclosed_stationary_body` data option.
It admits an already-disclosed stationary actor/body without a draw handle;
unknown, stale/moved/gone actors, absent spatial disclosure, unqualified anchors
and hand sockets are rejected. This closes the two real equipment playback
omissions found during native replay without a graphics or hearing-rule change.
Torch and unarmed source choices use provisional body attachment; they do not
infer missing hand sockets. Every cue's mix and source choice remains replaceable
in the audio authoring data.

Acceptance uses installed Windows Godot 4.7.2:

- Source-contact checks: 54 passed; contacts.json is unchanged.
- Presenter/source/admission checks: 94 passed, including source loading and
  explicit unknown/moved/removed/missing-anchor/spatial/socket rejections.
- Actual Library binding checks: 1838 passed over 57 audience recordings.
- Isolated native SFX lane: 71 passed over 18 exercised source cues.
- Actual Studio Forward+/Vulkan/WASAPI lane: 249 passed over 14 mixer captures.
  New equipment selected-onset looping plays twice, seeking inside stays silent,
  and base cues cross their actual resolved clocks. Action Surge's real action
  economy recording is included. Amber starts ten cues with its peer silent;
  Blue starts nine with primary silent. Private/unselected voices are not played.
  Jump remains at 1370 ms sound onset/1450 ms ground contact; source offset is
  80 ms, observed native offset 83.71 ms and sprite-ground distance zero.

The native lane records the one source-ready Goblin handaxe release skipped for
an unqualified weapon socket as a runtime gap. It is not counted as played.
Other explicit gaps: six torch extinguishing occurrences with no selected source,
six window contact tracks without authored markers, two unsupported looped jump
clip-end markers in the late-lethal Blue audience, and unreviewed creature foot
contacts (not exercised by current Library movement). Other spell/condition
entry/removal sounds stay unassigned; no universal sound fallback was introduced.

Evidence is in generated/audio_presenter_checks.json, base_audio_checks.json,
base_audio_native_checks.json, audio_contact_checks.json,
studio_audio_transport_checks.json and studio_audio_coverage.json. Captured
replay PCM is under .captures/studio/audio/. The final coverage inventory joins
saved native dispatch/skip diagnostics by recording and resolved component ID;
its aggregate mixer peak does not claim per-cue physical-speaker audibility.
The new FLAC selections retain original samples in classic PCM24 WAV containers,
validated by full decoded equality; source credits are in the existing manifest.

Only audio authoring/consumers, associated tests, intake and evidence are changed
by this task. Concurrent sandbox, visual/native-effect, shadow and large-plan
changes are outside this task and are not staged or committed.

Final independent plan-adherence, anti-slop and anti-OOP review found no blocker.
It checked the current component/source policy, reports, captured PCM, listener
selection, retained contact clocks and explicit remaining gaps.

Reproduce from this client with the installed Windows executable:

```text
../Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe --headless --path C:/Users/tommaso/Documents/Dev/NDClientGodot --script res://tests/base_audio_checks.gd
../Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe --path C:/Users/tommaso/Documents/Dev/NDClientGodot --rendering-method forward_plus --rendering-driver vulkan --script res://tests/studio_audio_transport_checks.gd -- --recording=res://.runtime/studio-cases/walk_diagonal-seed3-v2/amber/journal
../Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe --headless --path C:/Users/tommaso/Documents/Dev/NDClientGodot --script res://tools/studio_audio_coverage_audit.gd
```
