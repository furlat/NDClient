# Camera, playback, Studio and death-visibility audit — 2026-10-11

Read-only audit of `/home/tommaso/Dev/NDClient`; engine/server/SDK remained read-only. No implementation changes or new tests. Actual Fireball packets were inspected and compiled with the installed presentation using production `compileOperation`, reducers, `actorFacings`, `retainedRestPoses` and `actorContact` in a read-only Node/tsx probe. This establishes packet and timing evidence, not a GPU benchmark.

## Coverage inventory

All 35 files (3,919 lines) in assigned source directories were inspected:

- `src/app`: action-bar.ts, camera.ts, combat-log.ts, details.ts, feedback.ts, hud.ts, inspection.ts, interaction.ts, inventory.ts, log-evidence.ts, main.ts, panels.ts, playback.ts, style.css, ui-content.ts, widgets.ts, world-input.ts.
- `src/studio`: channels.ts, events.ts, fields.ts, recording.ts, style.css, timeline.ts, workspace.ts.
- `src/session`: admission.ts, client.ts, journal.ts, messages.ts, worker.ts.
- `src/player`: audience.ts, history.ts, logs.ts, reduction.ts, selections.ts, values.ts.
- Cross-boundary inspection: presentation actors.ts, scene-patch.ts, commits.ts, timeline.ts, playback.ts, compiler.ts and release.ts; rendering projection.ts. Main renderer implementation belongs to the other audit partition.
- Recording inventory: 20 real-server case descriptors; detailed raw packet audit of fireball and fireball-sorcerer. Targeted tests: camera.browser, idle-facing.browser, corpse-pose.test, studio-timeline.browser, studio-recordings.browser, studio-preview.browser, studio-continuity.browser; related assertions reviewed in studio-replay.browser, playback.test, reduction.test, corpse-pose.browser, transport.test. Not all test suites were executed.

## 1. Q/E currently replaces playback instead of updating the displayed camera

`src/app/main.ts:99–111` snapshots active operation/local time, calls `showPrefix(operation - 1, nextQuarter)`, then asynchronously prepares that operation again and seeks back. `src/app/playback.ts:61–90` marks preparing, discards prepared lookahead, creates a complete prefix scene, destroys the active operation, publishes the earlier state and sets time to zero. `tickPlayback:215` freezes while preparing. After prefix publication, operation preparation and texture readiness must complete before the sampled spell returns.

This is direct code evidence for pauses and a visible pre-operation interval during active spell rotation. It is not merely a projection formula problem. Floating number feedback also derives from `playback.active` (`feedback.ts:10–12`), so it disappears during this intermediate prefix. Playback remains nominally playing, but the active scene/time are interrupted.

Rapid Q/E adds two risks: the target is calculated from the last *published* quarter, so repeated presses during preparation can collapse into the same target; the `.then` continuation at main.ts:110 has no candidate/generation validity check. A superseded `showPrefix` returns normally after its own ticket check, permitting that stale continuation to prepare/seek old time against a later selection. Existing Studio selection paths have stronger generation/ticket checks (`workspace.ts:95–123`).

Required correction scope: camera/view change over the current sampled operation, its current absolute/local clocks, sources, lights and pending tails; retain the displayed coherent scene while any needed view is becoming ready, then publish the new quarter together. Do not route a camera key through historical state publication. Queue/coalesce desired quarter and reject stale asynchronous continuation.

Preserve existing camera math: `projection.ts:76–81` anchors the same viewed ground point at the actual viewport centre; `70–74` anchors wheel zoom under pointer. The model is explicitly `Quarter = 0 | 1 | 2 | 3`, with four authored view banks (`projection.ts:6,14–25`), not continuous-angle source art. Responsive seamless switching among those authored quarters during active spells is the supported requirement; interpolating nonexistent angles would be a different art/product task.

`tests/camera.browser.mjs` only rotates a paused prefix and awaits each change. It proves centring/zoom and no warm uploads, but cannot catch active spell resets, rapid Q/E, or cross-view stale publication. Preserve its existing guarantees and add relevant active recorded-spell acceptance later.

## 2. Fireball: received death-related visibility collapse is committed before the visible event ends

Original case: `.runtime/recordings/fireball/000003.json`, sequence 3, game `combat_fireball_six_goblins`, epoch `4dbab324-854e-41ac-9f54-7adfa5cc4e18`, audience `8d351404-81c3-4b80-a001-4576cd43b485`. Its controlled/observer audience is the six goblins. The caster `e8915953-6f78-4315-a1b4-770126baac77` is a living noncontrolled opponent, retained at [2,6] with HP56.

All six applied-damage facts, all six dead/intact life facts, all six spell applications and the complete Fireball root are present. Root UUID `1a5e81e1-b1a0-4f43-866a-393c6162aaf8`, source index 453. This is not a missing killing-event packet.

Each dying observer loses all 225 visible cells and visual_access becomes 0:

| Source index | Sensory event UUID |
|---|---|
|132|10ebf9a5-963f-45b7-8c7f-8e687d384ba4|
|197|c94346c9-9ed4-405a-9dea-a63cbf61f061|
|263|9d06256c-36ee-40e6-a4b5-9cf121eb1120|
|328|8672a3e9-49af-4a90-93c5-88fc297a9655|
|391|5b7de9e2-9bb8-4b50-aa51-98778f844f64|
|446|0821bc3e-5683-47b0-88fc-5966964f71c8|

The last event removes the last caster contact. The client's `audience.ts:41–65` faithfully deletes the cells and contacts, and `reduceNodes`/`applyPlayerFact` apply those sensory facts. `commits.ts:25–30` dates observed changes with their causal milestones; `sampleOperation` selects committed state at its date (`timeline.ts:142–147`). `actorContact` (`actors.ts:51–60`) excludes a living noncontrolled actor lacking a current visual contact, despite its retained last_visual_position. `scene-patch.ts:67–96` removes the resulting missing occurrences and changes the world to memory lighting.

Production compile probe of that actual operation:

- Cast body: 0–1250ms.
- Projectile: 583.333–1310.652ms.
- At 1310.652ms: all six sight-loss facts commit; visible union goes 225→0; caster contact becomes null.
- Impact media: 1310.652–3227.319ms.
- Six hit reactions: 1310.652–2310.652ms.
- Six death falls: 2310.652–3560.652ms.
- At final state caster remains alive HP56, last_visual_position [2,6], but actorContact remains null.

Thus the scene loses current visual context at the start of an explosion with roughly 1.917 seconds remaining, and 2.25 seconds before falls finish. The compiler has enough admitted facts, positions, sources and retained poses to display this already-received lethal event fully. Separate gameplay/subjective reduction from the visible lifetime of that admitted event; preserve its caster/context/effects through their authored end and retain its witnessed aftermath. Do not discard canonical death/HP or invent new result facts. The display-only deferral should be causally tagged to the received sensory observed_changes/cause and its actual lethal result, retaining the pending sight-loss update until that admitted visual event completes. It must not drop sensory updates forever or defer unrelated fog, blindness, ordinary occlusion or new independent observations. Simultaneous deaths must not erase their own remaining explosion, reactions, falls and retained tails.

Contrast case `.runtime/recordings/fireball-sorcerer/000002.json`: controlled caster `67cfc18e-0df1-4817-b032-a162a7942976`, HP22 after self damage, visible cells remain225, casterContact remains [3,0,7]. Its impact is 963.634–2880.301ms, final falls end3213.634ms. No analogous vision collapse occurs.

The current `tests/idle-facing.browser.mjs` explicitly asserts zero caster rows at impact/end and says to honour the recorded loss of sight. That assertion encodes the rejected display behavior and must be revised for the user's requested experience. Preserve that test's independent living Idle animation, retained facing, cold-prefix equivalence, and paused pixel stability guarantees.

## 3. Exact backend boundary; separate proposal only

In the read-only engine reference:

- `dnd/creature_transforms.py:336–361`: DEAD applies incapacitation **and** a visual-denial modifier at356–360.
- `322–332` independently gives Unconscious visual denial;343–348 applies that transform to DYING/STABLE.
- `dnd/entity.py:2494–2496` commits state and replaces life-state modifiers. Death also suppresses the entity's light and updates perceiveability2498–2513.
- `dnd/blocks/sensory.py:663–681` visual_access0 yields no optical FOV candidates.427 and435 produce visible/contact removals;861–871 installs the resulting senses.
- `dnd/player/projection.py:129–148` copies these into the existing SensoryFact. No missing field is demonstrated.

If the desired additional behavior is actual *continued observation of later native events after death*, existing client history cannot invent those unreceived facts. The smallest demonstrated mechanical change to propose separately is omitting **only** the DEAD branch's visual-denial contribution while retaining dead incapacitation, action/movement denial, light suppression, life facts, corpse mechanics, all independent blindness/unconscious conditions, and DYING/STABLE visual denial. That makes death itself cease to revoke optical access at the retained position; ordinary LOS/light/range still governs later native perception. This affects native dead perception, so it requires explicit approval and must not be smuggled into client renderer cleanup. No spectator framework, new audience switch, or new SDK/wire field is indicated by this change.

Important explicit scope consequence: DYING/STABLE→DEAD would remove the previous life-owned unconscious modifier and therefore restore visual access unless another owner denies it. Initial DEAD configuration would also retain authored sight. Neither consequence should be hidden in a plan. This proposal does not continue an encounter that the native server already ended, nor invent later events absent from this terminal recording.

Existing expectations needing narrow approved update: `tests/engine/test_life_state_ownership.py:104,161`; retain the DYING/STABLE expectations at74/99 and healing/action denial. Add real native→player packet/reducer evidence for death while another visible entity continues changing, independent blindness plus death, revival modifier ownership, LOS and light constraints. If requested behavior is only replay/witnessed aftermath from admitted data, no backend change is necessary.

## 4. Studio loading, cache and rebuild findings

`workspace.ts:79–94` keys a full recording trace by camera quarter. Every quarter change requests the initial world again and compiles camera-specific sources for every operation (`recording.ts:7–21`), although semantic compiled operations are cached in worker.ts:161–180. `compileScene` builds all semantic patches and stores only one last camera/sequence scene (`worker.ts:202–244`); playback and recording trace both use this path. This is extra camera-dependent metadata/preparation work; it is not evidence of a required second renderer.

When a new trace arrives, `refreshTimeline` calls timeline.update. `timeline.ts:222–228` destroys all preview RenderTextures, drops the preview view, clears expansion/selection, and recreates rows. Quarter rotation therefore invalidates the complete timeline, even though resize/scroll correctly preserve it. During warm thumbnail production, pump51–77 renders the whole demanded strip sequentially without yielding between already-resident samples. This is a possible burst of work worth measuring; no measured GPU percentage is attributed to it here. Demand filtering and caches already exist and should be preserved rather than replaced wholesale.

Current improvements already in place:

- Main ResizeObserver only schedules resize; layout and render occur together at main.ts122–134, preventing canvas clear between browser paints.
- Timeline resize uses layout121–142 and retains DOM sample identity/time and texture; scrolling selects visible samples91–117 without evicting cached previews. Fold rebuild143–216 retains textures and scroll.
- `workspace.ts247–252` retains inspected tracks through intermediate prefix preparation; it no longer blindly empties timeline on active becoming undefined.
- `recordingTrace` retains source records, no GPU scenes. `presentation/playback.ts23–31` makes metadata before full graphics preparation;33–53 retains predecessor leases, preloads shared sources, prepares moments, uploads deduplicated sources.
- `createThumbnailView`/`channelThumbnail` use independent view handles and shared sources; live scene is not republished by preview sampling. Interactive preview draws remain GPU resident. Source framing uses source-cell size across actor strips, not fluctuating alpha bounds.
- Normal lookahead does not set `preparing`; current operation proceeds during `filling`. Lookahead crosses zero-duration bookkeeping operations (`app/playback.ts169–198`). At an admitted-but-unprepared boundary the clock intentionally holds; live idle only advances when no admitted next operation exists (`238–253`). Avoid losing this causal distinction while fixing throughput.
- Authoring reload uses explicit prepare/commit/discard transaction and generation checks; old displayed scene remains owned until replacement prepared (`playback.ts94–154`). Recorded release identity and manual recovery remain functional.

## 5. Functional boundaries to retain

Transport admission verifies exact protocol/sequence and journal consistency. Worker `consume:76–106` reduces before durable append and publishes only after admission; generation gating rejects old session responses. Canonical latest history and sampled/displayed state are separate. Recorded/live paths use identical reduction and compiler.

Do not refactor action legality/selection while changing rendering: interaction.ts uses displayed sequence plus server ACK/catch-up/revision gating; exact pending command payload survives ambiguous receipts. World picking/feedback, multi-target allocations, approach interactions, inventory/equipment, abilities, sheet/reactions, party/initiative, source inspection, event tree, authored source links, log filtering/detail/copy, floating feedback, replay/loop/seek and manual JSON reload are actual retained clients. No unrelated business-state replacement is justified by this audit.

No runtime GPU/loading timing or browser screenshot measurements were made in this audit. Static evidence distinguishes present safeguards from remaining camera-triggered rebuilds. The concrete dynamic evidence is the real production-compiler timing and reduced visibility above.
