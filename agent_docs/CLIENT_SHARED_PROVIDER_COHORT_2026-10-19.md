# Client provider migration — 19 October 2026

Implementation checkout: `NDClientGodot-authoring-schema`, branch `codex/schema16-unit-a`. Receiving checkout: `NDClientGodot`, branch `codex-authoring-schemabump`. Engine export remains `dnd_engine-211b71134`, protocol1/schema16. Factory remains the complete sealed `production-bindings-2081189e43bf0443` delivery. No Factory or official engine source was edited.

## What changed

- `PresentationCondition.effects` is a typed array of the existing `PresentationEffectUse`. The abilities build emits native condition cues into its existing Resource documents. These cues share condition UUID ownership, preparation, clocks, selection, retirement and Studio inspection with package lifecycles; there is no second scheduler or runtime catalog scan.
- Rage/Frenzy mantle sources moved from four-second action clips onto their actual condition owners. Finite onset stays action-owned. Unknown removal uses the delivered source’s explicit negative sentinel; only an observed removal starts its return. The source owns that return, so the generic finite-clip controller never evaluates infinite fade bounds. Only explicitly replaced mantle media is suppressed. Unrelated missing application/removal media remains a requirement.
- Frenzy’s parent UUID remains unavailable in the public state. Its source and onset stay explicit input gaps. Frenzy outranks Rage in the existing exclusive group, so the legal Berserker sequence does **not** qualify a visible ordinary Rage mantle. An initial owner without its application history also remains an explicit gap. The legacy Rage body film has not been qualified against Factory’s newer standalone film API.
- Five divine actions now have eleven typed native cues: Preserve Life; Cleansing Touch; Opulent Revival’s single invocation plus separate living/dead receivers; Turn Undead/Turn Unholy’s source cast and radial release. Their existing condition-owned markers are not duplicated. Preserve Life is qualified with actual journals and submitted native draw witnesses; the other four action bindings need their own legal scenario/output qualification.
- Shared factual inputs index positive unblocked healing, accepted recipient-local removals and committed dead-to-alive changes from native descendants once per group. The declaration owns the invocation; application facts cannot play it again. Each receiver retains its own original result occurrence, lineage, target and amount, separately from the source action. Revival requires no fabricated HealFact.
- The public constructor adapter now projects sibling identity fields before construction as well as nested result dictionaries. Actual actor roles and geometry IDs replace study IDs; review event/lease packets are cleared before construction. Actual result packets, displayed visibility and authored logical-to-pose socket mappings reach the ordinary shared setters. Unchanged packets are not resent to rebuilding setters; the small prior packet is private so in-place changes are still detected.
- Native retention now includes `Timeline.retained_components`. Previously a zero-time operation could finish before a delayed receiver started: preparation created the receiver, sampling freed it, and the same work exhausted the next frame’s allowance indefinitely. Existing timeline ownership now keeps that prepared instance until expiry; its resource revision invalidates the retention cache. This applies to every compatible finite native effect, not one spell.
- Studio exposes the authored held source, exact clip and missing reason. Expected named input gaps remain visible missing work without rejecting the whole playback. Unexpected missing resources and actual available-source failures remain errors.

## Evidence

Artifacts below are worktree-relative, under ignored `.runtime/`.

| Gate | Result / artifact |
|---|---|
| Abilities build | Zero errors, seven existing warnings; `shared-providers-build-final.log` |
| Five focused headless gates | 498 checks after Second Wind; all pass; `tests/20261019T193941Z/summary.json` |
| Original class journals | Both factions: one Preserve Life declaration, three applications, two positive heals, exactly one invocation/two receiving cues; real Frenzy application/move/attack/voluntary removal and explicit parent gap. Preserve Life/Frenzy passed184 actual-journal checks; adding Second Wind raises the same gate to257 checks. |
| Preserve Life native Studio | 619 checks, zero failures; actual invocation plus both receiving draw witnesses; seek/faction switch/play/loop; `shared-providers-preserve-native-qualified.{json,log}` |
| Second Wind original journals | Actual wounded level-five fighter, positive self-heal and movement, both factions; `shared-providers-second-wind-record.log`, `tests/20261019T193510Z/`. Main native output passes757 checks with one actual self-heal draw witness; seek, independent factions and automatic loop. Main `shared-providers-second-wind-native.{json,log}`. |
| Frenzy native Studio | 1778 checks, zero failures; missing-parent indication preserved through playback/seek/loop, no substitute mantle; `shared-providers-frenzy-native-qualified.json`, `shared-providers-frenzy-native-final.log` |
| Current package recording sweep | 183 available spell recordings compile/fold safely; six unavailable server baselines remain. No script/resource errors. `shared-provider-recording-safety-final/report.json` |
| Actual Gallery player actions | Two83-check runs, zero failures: open door → enter room → Haste potion → Fireball twice. Last run `player-runs/20261019T192000.172347Z/`; `shared-provider-gallery-profile-final.json` |
| Native issued-command spell sweep | Complete189-case native batch:182 passes, seven failures,1,783 checks; native process exit0. Final `shared-providers-live-spells/results.json` retains every attempt and original journals. Overall gate stays red. No script/parse/resource error; three server connection error lines remain. |

The headless holding test proves clock/ownership math, not a legal ordinary Rage native visual. Preserve Life/Frenzy native Studio tests retain one ObjectDB exit warning each; the new main Second Wind run retains one warning naming six instances; no zero-warning claim. Draw witnesses establish submitted production instances, not user art approval or all pixels.

The six existing unavailable recorded baselines are Branding Smite, Ensnaring Strike, fixture Test Bless, Hellish Rebuke, Searing Smite and Spare the Dying. Keep the exact journal/report reasons. These are failed gates, not supported visuals or skipped inventory IDs.

## Live performance ledger — continue migration

These are live player commands, separate server execution and client packet-to-first-animation intervals. Last Gallery run:

| Action | Server execution ms | Client packet → animation ms | Peak frame in action window ms |
|---|---:|---:|---:|
| Door open |31.77|80.99|183.00|
| Movement into Gallery |48.24|101.07|20.53|
| Haste potion |11.95|77.12|16.08|
| First Fireball |40.77|54.77|15.89|
| Later Fireball |55.92|61.03|20.85|

Idle same-view p95 is5.207ms, maximum7.561ms; this does not qualify every action frame or final performance.

The door peak is still native startup construction:179.016ms optional native startup /178.877ms construction in the final run. Earlier in this turn the equivalent frame peaked218.019ms with214.785ms optional startup. Previous isolated source decomposition identified Quickened/Twinned `_ready()` as the dominant indivisible work; Factory already has `FACTORY_CONSTRUCTION_READINESS_REQUEST_2026-10-19.md`. A2ms scheduling allowance cannot preempt that constructor. Do not confuse this with server delay or start another optimization detour while migrating providers.

New class Studio preparation also has visible cold/restore waits (about0.5–0.8s for the first Preserve Life seek; a Frenzy loop restore recorded5.873s). These are wall-clock preparation/transport observations including media and native source readiness, **not measured single-frame CPU durations**. Retain the native logs. The previously infinite construct/free loop was fixed, not excused by those finite waits. Full live performance qualification remains open.

## Remaining shared work

- Exact item ownership/appearance and created-item publication; no borrowed first weapon/offhand or counterfeit chest/mace.
- Actual assembled actor history/context/pose capture for Blur/Mirror Image/Banishment and related effects; no per-frame GPU readback.
- Passive effective-handler→emitted-result inputs (Blessed Healer, riders, etc.); no fabricated ActionFacts. Do not treat arbitrary descendant healing/damage as a proven passive result.
- Source/application provenance for held leases, event-state consumers and initial unknown histories.
- Public selectors/attribution: Frenzy parent UUID, paladin aura kind, retained Lay on Hands form, exact damage-component identity, draconic issue/readiness data. Missing variants stay explicit.
- Full source/provider/scenario/native-output/visual-review coverage and surprise first-use readiness. Factory package installation and a safe baseline cast do not finish these rows.

Aid, Bless, False Life and Sacred Flame remain **not user accepted**. No approved lighting/colour/shadow/depth/sorting/body/audio timing was retuned. Assets and binary builds remain ignored.

## Created-item blocker isolated by the current native sweep

Flame Blade is an actual functional failure, not just absent artwork: its real
command creates/equips the item, but the sprite-only outfit selector reports
`No built item visual` and prevents sequence8 from publishing after sequence7.
Original evidence: `shared-providers-live-spells/spell.flame_blade__baseline/`.
The complete sealed208 package already contains both exact native created-item
appearances. No replacement sword or inventory icon was added to hide the gap.

The bounded next shared cohort is an optional existing EffectUse on typed Gear,
compiled native-only equipment admission, and one passive item-owner table in
the existing Timeline. Prepare the item occurrence using the existing constructor
path before its actual ordered equipment/world cut. Retain it through normal
requirements/retirement; sample current actual main/off/ground membership and
the existing authored hand point/body sprite basis. No new scheduler or manager.

Observed cast history can supply exact Flame Blade item/caster/lifetime identities:
the failed Amber run has declaration51/cast lineage41, condition48/lineage44,
inventory49/lineage49 and equipped MELEE_MAIN row50. Initial history and Blue's
undisclosed private inventory branch cannot be filled by same-name owner searches
or Amber data. Cached `state.items` membership alone does not prove current
existence. Missing offhand sockets, unknown creation provenance and optical
registration stay explicit gaps. The source templates are nonseekable and need
real long-age replay qualification. Their art remains unaccepted; Factory's later
visual repair is separate from this sealed delivery. This analysis does not claim
the created-item provider is implemented.

## Publication checkpoint

Production provider code `0022d050` is published in main as `556dc0cd`.
Original Second Wind case/test/report follow-up `4d0556f8` is published as
`aae29669`; receiving library has201 original cases. Main's expanded498-check
headless gate passes with zero failures/script/resource/engine errors in
`.runtime/tests/20261019T194118Z/summary.json`. Main abilities build also completed
with zero errors/seven existing warnings. The native189 sweep uses production
provider code0022d050 and sealed208 throughout; subsequent edits add tests,
original class recordings and offline reports/docs only. No package files or
production renderer inputs changed underneath that running gate.

## Final native safety result

The complete current-package issued-command sweep attempts every189 inventory ID:
182 pass, seven fail. All three logged `ERROR` lines are the actual server
`PLAYER_CONNECTION_FAILED: game_failed` responses for Branding Smite, Ensnaring
Strike and Searing Smite. Other failures are Test Bless's unavailable choices,
Flame Blade's missing worn appearance/media stall, Hellish Rebuke's absent required
reaction occurrence, and Spare the Dying's unavailable action. Original records
and per-case logs remain red; no placeholder or skipped ID was called a pass.
Guardian of Faith now passes on the sealed208 source. This is a native-command
safety improvement from the older181 runtime-safe cases; it is not all-spell VFX
completion or visual approval. Source/input gaps in passing commands remain in
their actual trace and the generated coverage report.

Main Second Wind replay passes757 checks with an actual native self-heal draw
witness, exact canonical prefixes, seeking, both faction journals and looping.
Its cold Studio opening/preparation and loop restore are still slow: logged native
warm-up1.795s and one loop publication2.798s. These are wall-clock observations
including preparation/transport, not exclusive single-frame CPU measurements or
normal-game latency. Keep them in the performance ledger, with the current native
source constructor work, rather than claiming the client is fully fast.

## Final receiving-checkout live profile

Main `aae29669`, unchanged provider code556dc0cd/closed208 package, actual native
player controls, same Gallery sorcerer/camera24/window1600×960.83 checks pass,
zero native/script/resource errors;165 ObjectDB instances remain in the exit
warning. Main original run: `.runtime/player-runs/20261019T194506.718192Z/`.
Exclusive stage/frame report: `.runtime/shared-providers-main-gallery-profile.json`.

| Action | Server execution ms | Client packet → animation ms | Peak action frame ms |
|---|---:|---:|---:|
| Gallery door |37.21|74.42|201.32|
| Move into room |45.61|109.75|14.26|
| Haste potion |10.54|69.29|14.46|
| First Fireball |38.07|61.25|18.12|
| Later Fireball |54.59|67.34|21.72|

Door peak is197.455ms native construction/197.591ms optional native startup,
the same already reported source-construction limit; the profile retains its
full nested leaves. Movement has72.007ms canonical worker consumption and
38.371ms required media (overlapping stages, never summed as exclusive delay).
No command exceeded55ms server execution in this sample. Idle same-view p95
5.150ms/max6.259ms across737 frames; this is not all-action100+FPS or no-spike
qualification. Migration continues to record these limits without a separate
optimization detour or graphics retuning.
