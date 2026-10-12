# NDClient implementation progress

This is implementation evidence and a list of concrete gaps, not a replacement plan. The active scope remains [the complete plan](NDCLIENT_IMPLEMENTATION_PLAN_COMPLETE_2026-10-11_v3.md) and [its Pixi renderer chapter](NDCLIENT_PIXI_RENDERER_PLAN_2026-10-11_v3.md). No backend, SDK or original authoring changes are part of this work.

## Current execution and remaining plan — 11 October

**The full plan is unfinished.** Current repairs belong to N1–N3 and their integrated N5 checks; they do not complete N0–N5. Entries below this checkpoint record evidence, including historical states that have since changed.

| Current user feedback | Verified state and remaining work |
| --- | --- |
| Fireball recipients disappear during damage | Shared material-branch parameter ownership corrected; six actual recorded recipients remain visible at 1.90/2.01 s. Broader effect and lifecycle coverage continues under N2/N3. |
| Fireball projectile colour differs between scenes | Scoped filters now preserve authored final blending. Separate backend light-category RGB treatment removed; actual positioned Fireball light has independent on/off evidence. This does not establish all spell/receiver acceptance. |
| Lightning Bolt aims at the map corner; bow action uses axe artwork | Replaced through genuine server captures using appropriate native targets/equipment. New Lightning Bolt sequence 20 targets only the enemy at [9,7]; Call Lightning sequence 27 targets only the enemy at [9,10]. Native preview/outcome and server-byte provenance are recorded with the cases. Targeted regressions and Studio structure checks pass. Continuous-play performance remains separate. |
| Several scenes fail with `No authored rig` | Both Wall of Fire cases had stale presentation pins missing the existing generic-caster rig assignment. They now name the compatible immutable release. All 20 cases passed worker initial-load/compile checks before authoring reload; integrated Studio rendering is a separate check still to finish. No fallback rig or server identity edit. |
| Call Lightning appears absent or frozen | The original strike is present and both corrected-recording runs finish. First/replay software-WebGL worst frame gaps are 266.7/200 ms while measured JS peaks are 24.8/9.4 ms; zero foreground decodes and zero replay uploads. GPU timers are unavailable, so no exact GPU cause is established. Performance acceptance remains open; changing the target is not a performance fix. |
| Playback freezes all aftermath | Natural completion now continues visible living Idle while recording time, cursor, state and logs stay fixed. Focused browser checks pass: living source changes, six corpses unchanged, explicit Pause freezes, replay restarts with commits once. |
| Actual directional light in focused tests | An explicit directional source now uses world-space direction and receiver normals in the shared lighting filter. One real floor receiver passes above/below and east/west light checks in all four views with unchanged alpha. Source list is empty unless explicitly authored; no implicit ambient or backend-derived light. |

The [recording audit](reviews/renderer-2026-10-11/recording-provenance-and-setup.md) verifies all 20 active cases / 197 packets against retained server frames. Eight older cases still have unused shortbow grants on axe-bearing goblins; these setup leftovers are listed there and remain to remove through real recapture, without editing native packets.

Continue in this order within the existing plan:

1. **Renderer v3 was implemented and its single production drawing path verified before resuming N3/N4.** The user's latest instruction corrected the previous sequencing: general N3/N4 implementation advanced before the renderer's combined acceptance was complete. The completed checkpoint covers renderer scale comparison, the selected Fireball/wall interaction, lifecycle/camera/source-work checks and removal of obsolete routing. Gameplay and Studio must use the same ordinary Sprite/filter path. Do not count partial fixes or passing source tests as completion of renderer §11.
2. **The general plan is now active again.** Weapon-trail, Globe, Dimension Door, original hatch clipping and straight Ice/Stone construction have since completed bounded source/native checks, with qualifications recorded below. Continue remaining N3 authored consumers and Studio inspection, N4 playable workflows, N0/N2 reconnect/resources and N5 integrated delivery. They remain part of this delivery.
3. Keep measured limitations explicit: Call Lightning software-renderer frame gaps are not a confirmed RTX GPU diagnosis; missing source-qualified wall blockers are not permission to invent geometry or claim obstruction works. Do not label the renderer or full port complete while its required work remains unresolved.

Renderer checkpoint for this execution — implementation/combined source checks passed; global work resumed:

| Renderer step | Evidence and outstanding work |
| --- | --- |
| 1–3: source colour, Sprite path, texture preparation and lighting | Separate tint/swap/material, native environment, fixed character cleanEdge and source-light checks pass. The obsolete character-review Mesh factory is now outside production source; its independent oracle is retained. Fireball scale versus native area and accepted proof passes; the 48-case selected wall oracle and resource/context checks pass. Final build passes; the bounded Ice worker correction preserves the complete response and reduces measured compile time from 10.35 s to 4.89 s. |
| 4: blood | Independent Pygame comparison and all-quarter floor-plane checks pass, with fractional-alpha differences recorded below. |
| 5: camera/Studio | Existing adjacent-preload and continuity checks pass individually. The combined rerun passes, including active persistent effects, row/selection/scroll preservation and natural completion Idle versus explicit Pause. The reproduced blank-thumbnail context-restoration defect is fixed and its full Studio regression passes. |
| 6: admitted lethal event | Recorded Fireball and cold-prefix retention tests pass without changing canonical death, sight or target legality. |
| 7: combined acceptance | GPU source/lifecycle batches and final anti-slop/anti-OOP reviews pass. Context restoration returns identical body, paired-effect and Studio thumbnail pixels without repeat decoding. Final build passes. Both built HTML entries use the same application bundle; retired ordinary routing/factories are absent from source and bundle. The unchanged-retained-field correction passes full response equality and browser responsiveness checks. General N3/N4 now resumes. |

Continued native sight after death still requires separate backend approval. The client already retains presentation of an admitted lethal event through its visual end; those are different changes.

## 11 October — renderer v3 implementation, current status

Implementation is in NDClient. The ordinary catch-all Mesh shader has been removed; image colour, lighting and coverage now use ordinary Pixi Sprites with scoped filters. Meshes remain for actual particle, orbit, arc and directed geometry. This is not yet a declaration that the complete client or every renderer acceptance case is finished.

Verified in the production path:

- Environment colour remains at original resolution; numeric companions remain lossless. Characters are composed on their original grid and processed by the author's cleanEdge at physical 2× with unchanged logical registration. Two accepted character reference images compare exactly, with zero differing channels.
- Tint, exact original-byte colour swap and material are separate operations. GPU checks preserve unmapped/nearby colours and partial alpha, with maximum byte error zero. Hand-magic material remains owned by its effect; full Body previews include it while physical-part previews remain separate. Dropped items retain their equipped tint. A white item tint no longer discards explicit glints/emission.
- The old `colour-palette` and `colour` keys duplicated the same PNG. The resource owner now supplies both consumers from one decoded colour source and its existing tone metadata; an actual Magic2 timeline/material check has one request. Warm Body/effect/material previews need zero new decodes.
- Floor cache clipping used the screen dimensions for an offscreen target. Bounded filters now retain their complete source/cache region. Eight cached/uncached comparisons covering memory/disclosure, pan, removal, grid, emitter end, quarter and graphics-context restoration have zero differing channels. After removing categorical lighting filters, ordinary uncached floors batch into four draws per frame, equal to cached floors, with zero warm source uploads; the earlier 16-versus-453 total is obsolete.
- Retained actor frame/height sampling matches fresh preparation and backward seek exactly. A jumping body's height remains separate from its grounded shadow. Fixed-character neutral composition and maximum-RGB, frost, wither and flowing-film treatments pass focused GPU checks without recomputing source colour merely for zoom.
- Goblin/Demon/animal controls now pass 42 independent source-PNG endpoints (maximum one byte rounding; all seven wolf endpoints exact). The wolf body had retained its source shadow as well as the separate shadow because its authored `source_rgba` selection was ignored. Ordered original-byte selection now runs before material treatment, with the original texture retained through frame changes.
- Material donor sampling preserves the original frost clamp and directed-trail wrap semantics without changing shared texture sampler state. Texture-edge GPU checks match their expected values exactly.
- Blood deposits use the original 64-pixel source grid and the horizontal receiving plane. Independent original Pygame comparison has 98.782% silhouette overlap and premultiplied RGB mean error 0.567/255; fractional-alpha raster differences remain explicit. All four quarters, accumulation and rewind were exercised.
- Received lethal-event context is retained through its actual visual end and can be reconstructed from a cold prefix; canonical sight/death and targeting stay unchanged. Remembered living actors do not advance unseen animation. Continued native observations after death remain the separate, unapproved backend proposal.

Additional renderer acceptance completed in this execution:

- Factory paired radiance now uses a bounded floating-point effect group before its final display conversion. Original Fireball frames 8 and 20 match across all quarters within one display byte, including alpha-zero radiance and HDR. The actual far–blood–near painter interval also passes at zoom 1.6 and 2 (maximum one display byte, float error below 0.00144). Interposed particle geometry and clocks retain their original owners. Unsupported interposed row types remain explicit; this is not a general transparency solver. The separate selected-wall source acceptance is recorded below.
- Camera/playback and adjacent-source preload acceptance now passes serially. All 26 commits stay ordered; replay makes zero foreground decodes. Both adjacent rotations require zero new decodes/source uploads and preserve the playhead through impact and aftermath. The background admission check runs after foreground RAF callbacks and admits nothing during overloaded frames. The test now follows production's draw-on-change rule rather than forcing paused redraws every RAF. These software-renderer measurements are not a hardware FPS claim.
- Fireball source scale/native-area comparison, selected-wall source oracle, combined browser checks, final build and anti-slop/anti-OOP reviews pass. Hardware utilization and native wall-crossing gameplay remain qualified separately.

### Current Fireball feedback — 11 October

- **Six goblins disappear at recording `fireball`, stream 2.01 s:** reproduced in the actual Studio, including with the burst temporarily hidden. The actors were present with opacity 1, and the original `TakeDamage` frame was nonempty. A copied material-branch resource table still pointed to the final composition's shader parameters. Refresh therefore replaced each branch's own stage parameters and recursively sampled its prior treated result. `prepareSourceImage` now retains its own parameter owner. The same Studio frame shows all six bodies; the original 348 opaque native pixels survive. `fireball-flash.browser.mjs` passes all six actors at both 1.90 and 2.01 s, alpha difference at most one byte and zero repeated-draw drift. Evidence: `.runtime/reviews/renderer-final/studio-fireball-branches.json` and `studio-fireball-branches-2010-withoutBurst.png`.
- **Fireball trajectory/source/impact:** both actual recordings select `isometricHybrid` fine rotation for travel, including the area cast. Native-record checks in `source-emission.test.ts` verify the selected release socket, all four camera angles, transformed image direction and endpoint at the received `aoe_position`, followed by the burst at that same contact. This verifies the registered path; visual inspection of the source artwork remains distinct from this calculation.
- **Different projectile colours:** reproduced with identical original pixels and tint. The sorcerer recording's non-neutral categorical light values enabled a receiving filter, whose default final blend was normal; the other recording skipped that filter and kept the authored additive blend. The final scoped filter now retains the occurrence's authored blend. `scoped-blend.browser.mjs` passes 36 normal/add/screen, lighting/coverage and partial-alpha cases with zero byte error. Both actual Studio captures show the corrected glowing projectile. The user's subsequent instruction removes the separate backend-light-level RGB treatment; that instruction is tracked independently from this blend correction.

Recipient placement also now consumes the eight existing Bestow Curse resisted-layer `actorTopClearancePx` values. It uses visible occupied actor pixels without culling padding, omits the world effect without a visible recipient, and retains asset-only Studio previews. Production-source GPU checks pass all four quarters at zoom 2 and 3.2 with exactly the authored 10 logical pixels, no repeated-draw drift and no visible orphan effect. This is source placement coverage; a native resisted-Curse cast is still a separate gameplay acceptance case.

Full-port work remains after this repair. Concrete active authored gaps include measured weapon trails/contact media; wall assemblies and recipient layers; safe-side wall tint and partial suppression; disclosed handler save-outcome acceptance; selected Fireball/wall interaction; Studio field interpretation; and live encounter/UI/reconnect acceptance. Cone of Cold's authored directional painter-depth offsets are now connected without moving its image mounts; full native Cone of Cold gameplay capture remains to exercise. Disabled recovery or empty media arrays are not priority implementation tasks.

The potion strip omission recorded below is historical: the tracked `action_media_assets` now contains `strip.effect2.special1.phase1`, and the recorded potion test exercises its original nine frames at 12 FPS.

Browser checks use headless software WebGL. They measure correctness, preparation/source work and draw counts; they do not establish RTX 5090 utilization or hardware frame rates.

### Positioned illumination — 11 October user correction

Backend `effective_light_levels` no longer become world, body or equipment RGB gains. The categorical field interpolation and ambient/base-response uniforms were removed; category-only changes no longer rebuild those source occurrences. Native reduction, visibility and audience evidence remain unchanged. Remembered terrain retains an explicitly named disclosure treatment, sampled without blending into current cells. Current artwork stays neutral without actual sources.

The existing Fireball impact `VisualEmitter` remains the positioned source, sampled once per logical impact with its authored position, colour, intensity and range. The installed standing/wall torch bindings have lit-state and flame animation artwork but no client photometric emitter definition; the installed SDK supplies categorical perception light and item state rather than positioned source parameters. Torch illumination remains a documented source gap. No emitter parameters, backend fields or replacement ambient colour were invented.

Validation: `lighting.test.ts`, cutaway and recorded playback tests pass; native categories 0–4 produce byte-identical production GPU artwork. `positioned-light.browser.mjs` renders the actual recorded Fireball at 160, 440 and 1329 ms after impact and the peak in another quarter. Disabling only its actual emitter energy changes 60,167–519,298 RGB channels (maximum 57–64 display bytes), preserves alpha exactly, and restoring energy reproduces the original pixels exactly. Lit/unlit screenshots and values are in `.runtime/reviews/renderer-final/positioned-light/`. The 36 scoped blend cases still pass with zero byte error. This validates existing source illumination; the selected Fireball/wall obstruction interaction and additional source definitions remain separate gaps.

### Retained spatial consumers — 11 October

The current wall replacement records explicitly replace the historical back/front halves with one complete paired instance. The retained Wall of Fire consumer now coalesces those aliases at the same placement and lifecycle stage; original far/near band identity keeps their painter sides and survives frames with an absent band. The native Wall of Fire segment cases pass all four camera-quarter checks with no duplicate active packet at one contact. Paired source geometry tests and typecheck pass. This does not supply new camera banks: these delivered wall banks have one captured view.

Ice Storm recipient settlement now carries the existing finite target-ground track's exact contact and end date through the spatial lifetime. The authentic `ice-storm-recipients` capture has a successful sequence-2 cast at `[9,7]`, 14 damage leaving 13 HP, intervening native turns and sequence-7 expiry. The spatial lifecycle test passes in all four camera quarters: no settled samples before the finite source end, exact playback-hold rebasing, retained contacts through later commands and disappearance on native expiry. Canonical spatial facts stay unchanged; cold snapshots do not invent recipient contacts. The separate wall safe-side tint still lacks a selection mask in the chosen paired replacement (the historical raster masks are not registered to these packets); wall assemblies and partial spatial suppression remain open consumers.

## Connected and checked

- Persistent Pixi scene, ordinary Sprite/Container ordering, authored mounts and shared pan/zoom are connected. The ordinary material/lighting Mesh route has been removed; only actual specialized geometry retains Mesh. General depth peeling, manual colour interpolation and whole-scene custom picking are removed.
- Original character shadow sources and accepted environment/character proportions. Ground/detail/body relationships replace floor/body fragment-depth competition.
- Live intake and Studio use the same reduction, presentation compiler and drawing functions. Studio publishes tracks before GPU readiness, keeps them while paused/finished, and uses separate preview display handles sharing source textures. FPS/frame/CPU-submit timing is visible.
- Native attacks, classes, anchored spells, True Strike's actual child attack, Lightning Bolt, Call Lightning, Fog Cloud lifetime, and Misty Step endpoints are exercised by captured server records. Conjure Animals was recorded, but that capture did not exercise a visible summoned-actor lifecycle.
- Retained portal opening/closing and transfer phases consume native transitions and existing authored banks. The focused native `dimension-door` case passes entry/exit/settled/completion across four quarters and two zooms; opening clipping and shadow suppression now follow the original crossing-only rule. Hatch departure also consumes the original front-image alpha through the existing coverage filter. Unchanged original native hatch scenarios provide traveler/departure/arrival views; 48 GPU samples repeat/restore exactly and 24 native-pixel samples match original clipping exactly. Half-scale nearest-sampling residuals are qualified, and SDK/Studio hatch acceptance remains blocked by the supported encounter configuration's lack of portal placement. R16 remains partial. See [movement/portal source and native evidence](reviews/renderer-2026-10-11/movement-and-portals.md).
- Eyebite ribbon/eye and Disintegrate charge/trail/original particles/impact use their copied donor resources and native cast/application clocks. Source-material browser tests compile and render both through the production Pixi path; this is not yet native high-level-spell gameplay coverage. Target scaling, target-owned saving throws and source/travel/impact painter contacts are connected.
- Source sheets stay reusable across camera changes and replay inside the current recording/session. A new source scope retires unused old sources. Browser test confirms identical PNG/WebP pixels and cache reuse/release.
- Inventory, authored action groups/variants, character sheets, reactions, subjective event/log views, target preview/commit separation and automatic foreground wall cutaway are connected. Remaining integrated interaction checks are required.

- Spirit Guardians retains native application time and admitted footprint, source-facing sprites, individual wake-segment order and mist. Production Pixi browser check renders formation and retention in all four cameras from actual SDK packets.
- Terrain picking uses each received support height, including individual stair treads, through ordinary Pixi hit areas.

## Concrete remaining work / gaps

- Complete the remaining R01–R23 source consumers and native acceptance. Whole Ice/Stone, Frigid Air, Force membrane/motes, Wind flow/interception and whole actor/prop dust now have the bounded evidence recorded below. Partial construction cuts/suppression and other unexercised spatial responses remain; source-qualified safe-side inputs are still missing. Existing source resources and equations remain the reference.
- Finite and retained body materials are connected. Native Hold Person frozen pose and removal now pass all four views; live Petrified capture remains unaccepted. Mirror Image native copies/count losses, Blur distortion/contours/historical body afterimages and Banishment witnessed departure/return now pass all four views. Broader high-level spell/lifecycle acceptance remains separate from source-shader comparisons.
- The selected Fireball/wall interaction was accepted at the renderer checkpoint; it is no longer an implementation gap. A genuine lethal opportunity attack now interrupts a UI-submitted walking route at its native reached cell and passes actual Studio motion replay. Continue the remaining movement/condition/construction combinations, including unexercised jump/flight interruption and unavailable native portal-placement coverage. Do not restore a general depth compositor.
- Continue the remaining N4/N5 acceptance matrix. Current evidence includes native inventory, choices/resource conversion, log controls, routes/ally passage, interrupted walking, camera input, and ordinary actor/object plus support-top highlights. Actual support hover passes all four views and clears during a native spending boundary; exact post-occlusion edges and specialized construction highlights remain qualified. All five supported controller/AI arrangements pass bounded connection, unit-inspection and turn-authority checks, including native automated actions; whole encounters per mode remain separate. Supported-size DPR1 layout passes at 75–150% UI size. Actual support inspection, pinned door refresh and native door-driven dossier admission loss pass. Split-party inspection preserves the shared audience/connection and non-turn spending restrictions; remembered support exposes only retained terrain facts. Remaining native connector/inspection combinations, actual OS focus, monitor/DPR and hardware performance remain open.
- Floating feedback placement and independent lifetime now pass native concurrent-label and Counterspell-to-next-cast checks, four camera views, pause/prefix restoration and Idle expiry. N3 read-only source inspection and existing N2 journal/reload/scope/quota checks have evidence below; neither closes the full content or delivery matrix.
- **Finger of Death focused consumer accepted with rasterization qualification:** the exact three open shells, nine float donors and splinter geometry now use effect-local nearest/farthest selection, bounded linear composition and the original final palette, displayed through the shared scene as a Sprite. The 32 original-Python comparisons cover four quarters, two zooms and launch/travel/tail: IoU 95.65–99.23%, aggregate RGB mean 3.16/255, with sparse palette differences amplified by the software GPU's four-bit subpixel grid; this is not byte parity. A separate raster-grid diagnostic, exact context restoration, target/lease disposal, and the authentic single-enemy Studio cast/aftermath/replay pass. Source/native evidence and remaining qualification are in [the focused review](reviews/renderer-2026-10-11/finger-of-death.md). Backend, source art and native outcomes remain unchanged.
- Directed object impacts now use the existing disclosed construction-shell calculation. Actual Disintegrate chest destruction and Force construction retirement have native recordings; other extents, partial cuts and outcome combinations remain separate coverage.

- **Resolved potion-strip authoring gap:** `strip.effect2.special1.phase1` now resolves to its existing original strip, and the actual potion record checks all nine frames at 12 FPS. The earlier unresolved-reference entries below are historical.

## Historical feedback work — timeline resize correction

- At that time, full-port work was paused for feedback and this timeline fix was separately authorized. This records that bounded correction; current execution order is in the active plan.
- Report: dragging the Studio divider makes tracks/previews flash and reload. Reproduction on the recorded Fighter Second Wind operation removed 22 preview elements during one down/up drag.
- Cause: offscreen previews were destroyed, and width changes called the full track rebuild. Resize/scroll callbacks could also move the DOM before the Pixi mask was updated.
- Correction: retain generated samples/textures for the current operation; preserve their sample times; resize existing tracks in place; update layout and clipping within the application frame. Model replacement still releases previews, and new preview generation is limited to visible samples.
- Browser replay of the same drag retained all 20 original previews and all 5 rows, with zero removals or browser errors. This does not close the separate initial-track/operation-switch delay report.

## Historical feedback work — recorded tracks before Play

- At that time, the user separately authorized the empty-timeline correction during the feedback pause. This is historical task scope, not a current pause instruction.
- Cause: Stream inspection showed only the active operation. `anchored-spells` begins with seven zero-duration turn operations, so the first body/spell tracks appeared only after playback advanced to operation 8.
- Stream inspection now compiles the received recording while paused, using the existing production compiler and source patches. It retains source metadata; it does not GPU-prepare the entire recording. Visible preview samples use the same production samplers and shared source textures.
- The timeline shows canonical recording time, keeps rows and previews as playback advances, and seeks a selected preview through the existing operation-selection path. Selected-operation inspection remains available. This implementation invalidated inspection data on recording, camera and committed-authoring changes; divider changes did not. Renderer v3 corrects camera handling to refresh only view-dependent images while retaining semantic tracks and inspection state.
- Browser verification: a fresh `anchored-spells` load remained paused at operation 1/time zero with body and spell tracks and rendered previews. Clicking a spell preview selected native operation 8 at that sample time, still paused. All 33 rows remained mounted while playback advanced. Selected-operation resizing retained all 5 rows and 20 original previews. No browser errors occurred.
- Typecheck and the recorded playback/movement-tail tests passed. This closes the initial empty-track report and preserves the divider correction; it is not a claim that all loading/performance or presentation feedback is resolved.

## Verification limits

Latest batch: 25 Node client tests passed. Targeted browser source checks pass for resource decoding/cache ownership and Eyebite/Disintegrate GPU materials. Browser checks here run on software WebGL, so these results do not establish RTX 5090 utilization or hardware frame rates. Do not describe unimplemented consumers or source-only checks as complete gameplay.


## 11 October — renderer audit and plan revision 3

The current execution chapter is [renderer v3](NDCLIENT_PIXI_RENDERER_PLAN_2026-10-11_v3.md), following the user's three-filter, native-environment and character-only cleanEdge decisions. Prior progress entries are historical evidence; they do not establish acceptance of the current ordinary material/lighting path. This phase changed documentation only.

[The code audit](NDCLIENT_RENDERER_CODE_AUDIT_2026-10-11.md) records all runtime partitions, confirmed defects, unfinished consumers and independent blood/Fireball diagnostics. The blood streaks reproduce when floor geometry repeats a residue sample down vertical side faces. Corrected diagnostic images are not product fixes. Source-level colour, view rotation and lethal-event retention work remains for implementation.

Baseline: 33 Node tests passed and typecheck passed. Hardware performance and replacement GPU rendering are not validated by that baseline. Anti-slop, anti-OOP/ECS and camera/visibility plan reviews passed after corrections; their disposition is recorded in the audit. The subsequent adjacent-view preload requirement passed targeted review too: fetch/decode/upload through existing owners, yielding to foreground playback, with frame-time and warm-rotation acceptance. The DEAD-only native sight proposal requires separate explicit approval; no backend change was made or authorized here.

The subsequent [Fireball/scale check](reviews/renderer-2026-10-11/fireball-scale.md) confirms an additional ×2 applied to the already calibrated Fireball impact, and records the actual four-step/20-foot-radius ground area. Renderer v3 §3.4 now requires reviewing all media scale producers and checking dimensions with native environment textures and character-only 2× cleanEdge. Inherited scales in other paired banks cannot be removed blindly. This remains diagnosis and planning: the product scale has not been changed and visual area agreement is not yet accepted.

## 11 October — selected-channel Studio inspection

The existing inspector now reads exact authored values from the selected active release through `openRelease/readSource`, including the canonical file and JSON pointer. Compiled array selectors such as Reedshot's `variants[goblin03-ranged]` resolve their explicit authored row ID to the actual numeric pointer in that pinned document. Source values, resolved channel/source data and received causes stay separate; full source documents remain lazily inspectable. Frame indices, source FPS/rate, milliseconds and explicit source-pixel dimensions disclose their units. Unresolved selectors report their error without hiding other valid source values; no registry, editor or runtime fallback was introduced.

A clicked thumbnail holds its actual production sample time and frame while playback remains unchanged. Source metadata comes from that operation interval and preceding source patch, rather than the last occurrence anywhere in the recording. Replacing a trace clears obsolete selected metadata. Candidate versus recorded revision is explicit; the complete source field-family browser and full meaning/unit coverage remain §8.4 work.

Validation: typecheck and release isolation test pass, including different source-array ordering in an explicit candidate. `studio-timeline.browser.mjs` passes source-frame/rate inspection for Healing Word, selected-sample versus playhead separation, stable rows/previews, hierarchy, both Wall of Fire initial loads and explicit old-pin recovery. `studio-inspection.browser.mjs` passes against the genuine Reedshot capture and displays its pinned `/rigs/goblin03/body/Attack 1.png` source without advancing time. The timeline test now waits for the existing full-trace preparation signal after reload; the candidate banner alone can precede completion of that asynchronous compilation. These checks complete this inspector slice, not full N3/N4/N5 acceptance.

## 11 October — renderer camera and Studio combined acceptance

The renderer-first correction was read back against master §10, renderer §10 and this document's current execution order. All now require renderer completion before general N3/N4 resumes. New N4 work stopped without production edits or native commands; the owned private Crypt host was shut down.

Six existing browser scripts pass serially: `studio-replay`, `studio-continuity`, `playback-aftermath`, `camera-playback`, `camera` and `adjacent-camera`. The obsolete replay expectation now observes natural end Idle, explicit Pause, replay from time zero with empty prior origins, and native commits 1–26 exactly once. Selected-operation replay still restarts locally. Studio rotation retains expanded rows, selected inspection and scroll. Living Idle changes rendered pixels after completion; all six corpses remain unchanged, and explicit Pause/source-frame stepping freeze both clocks.

The camera race test now includes the real retained Bless sustain loop during a later Shatter action: its clock advances 87 ms and both visible parts advance frame 17 to 19 while the next quarter prepares; publication preserves the current frames, alpha and contacts. Existing cold operation-boundary, rapid rotation and rotate→seek/reload/case checks still pass. Warm camera/zoom checks have zero source uploads, allocations or new decodes; adjacent q1/q3 retain the playhead through flight, impact and aftermath and admit no speculative decodes during busy frames. Camera logs are in `.runtime/reviews/renderer-v3-final/`. The adjacent run used SwiftShader, 640×480, DPR 1: mean JavaScript work 3.68 ms with prefetch versus 3.34 ms without, mean frame intervals 22.49/22.74 ms. Background preparation yielded throughout its 60 active frames, then completed while paused. These measurements do not establish hardware FPS or complete the remaining renderer wall, lifecycle, performance and shared-path review gates.

### Studio thumbnail context restoration

A later lifecycle check found a real gap: the main scene recovered after WebGL context restoration, but Studio's cached final thumbnail textures stayed blank. The paused Body sample lost 360 pixel channels. `timeline.ts` now invalidates derived preview targets on the existing GPU generation, preserves compiled operation-view metadata, and regenerates demanded pixels through its existing bounded queue after restoration. In-flight work checks both the preview version and GPU generation before attaching a result; no preview pumping occurs while the context is lost. No full trace or new source decoding is requested.

Typecheck and the complete existing `studio-timeline.browser.mjs` pass. The repaired paused thumbnail matches its original pixels exactly, with zero foreground decodes and zero compile requests; DOM row identity, selected/expanded state, scroll, operation and clock are unchanged. Existing resize/inspection, both Wall of Fire initial loads and explicit stale-pin recovery still pass. Before, failed and restored images are in `.runtime/reviews/renderer-v3-final/studio-context-{before,failed,restored}.png`.

## Renderer completion checkpoint and return to the global plan

The requested single ordinary production path is implemented and verified. Both built entry pages import the same `main-C5OTEliT.js`; source and bundle contain none of `usesMaterial`, `surface-shaders`, `createCharacterMaterial` or the tool-only material factory. Gameplay, Studio world and thumbnails use the existing shared Sprite/filter composition. Specialized changing geometry and bounded source passes remain their explicit owners.

Final `npm run build` passes, including TypeScript. The prior complete 43-test suite passed; the subsequent worker changes passed the exhaustive scene-delta/native spatial tests, and the thumbnail correction passed the complete Studio timeline browser test. Focused colour/native texture/donor/sampling/blend checks, paired radiance, restored body/material targets, camera/aftermath and selected-wall checks pass. The build's existing bundle-size advisory is not a rendering failure.

The wall fixture checks 48 combinations of original straight-wall/door/D6 sources, four quarters, opaque/cutaway alpha and two zooms. Independent depth/colour comparison differs by at most one display byte, neutral cutaway and repeated frames are exact, picking stays with the original source objects and owned targets release. Source frame 8 is near peak Fireball radiance; most wall colour is visibly covered by nearer fire. This demonstrates the selected original-source composition, not a fabricated native gameplay recording or arbitrary-direction light occlusion. The existing camera ray-depth and receiver mesh do not establish closed light blockers. Torch emitter definitions and hardware GPU conclusions remain explicitly unresolved source/measurement boundaries.

Ice Storm's actual worker response formerly repeated unchanged retained spatial definitions at every media boundary. Reusing those unchanged definitions reduces browser compilation from 10.35 s to 4.89 s. Complete pre/post responses are deeply equal: 4,777 boundaries and 9,603 upserts. The isolated browser recorded 291 animation frames with maximum gap 16.8 ms and no errors. Remaining preparation latency and earlier Call Lightning software-renderer gaps continue under N2/N5; neither is presented as solved RTX performance.

N3 resumes with Finger of Death, measured equipped-weapon trails/contact media and retained spatial/construction/suppression consumers. N4 resumes genuine playable Crypt/UI/SDK interactions. Their preserved partial code is not accepted until its source and native cases pass. N0/N2 integration/reconnect and whole-product N5 remain part of the full authorized scope.

## 11 October — native Globe response and original Fire Bolt sheet

The unchanged server produced a focused 14-packet SDK recording: Globe creation at sequence 2, canceled Fire Bolt at 5, partial Fireball suppression at 10, and native concentration removal at 13. All packets directly match the retained native frame payloads. The setup uses existing generic caster profiles and an existing Globe spell grant; no HP, damage, roll or outcome overrides. The owned capture host is stopped. Case and provenance are in `.runtime/recordings/globe-response/`.

The spell consumer now retains a source-qualified blocked attempt until its recorded provider's disclosed sphere, using the original trajectory sampling/refinement. Display cutoff preserves the original source and trajectory duration instead of accelerating the projectile into its recipient. Both original Globe response bands play once per provider; canceled application facts remain eligible for that response. The maintained shell stays present and uses its original rear/front painter offset without moving the image. Missing provider geometry and other unsupported cancellation families remain explicit gaps; this is not general Counterspell or interruption completion.

Fire Bolt exposed a separate real N3 omission: its original sheet was already installed and described by `sheet`, `frame`, `rowOrder`, `phases` and `resources`, but the resolver required packed storage. The existing resolver now consumes those original fields when a packed representation is absent, retaining explicit errors for missing source paths. Its authored additive blend reaches the ordinary Sprite. No image copies, packing, alternate renderer or source schema were added. Studio source-frame labels preserve the same interrupted playback duration.

TypeScript and five focused Globe/release/paired/arc tests pass. The native Globe test verifies shell contact at x=7 before the recipient at x=9, no invented damage or destination impact, both source bands and painter offsets in all four quarters, canonical state equality and real removal. Six GPU samples across q0/q1 use an explicit directional review source: the attempted Fire Bolt contributes 723–864 changed channels and the response 22,233–45,551, repeated draws are exact, and browser errors are empty. Fireball additionally retains its actual positioned emitter. Evidence and screenshots are in `.runtime/reviews/globe-response/`; these software-renderer checks do not establish hardware performance or complete partial-volume suppression/construction consumers.

## 11 October — equipped weapon trail and native contact

The focused unchanged server capture `melee-extra-attack` contains an adjacent Fighter/Gloomplate ordinary attack (native Miss), followed by Extra Attack (native Hit). Original SDK payloads, discovered selections, previews and receipts are retained together. No critical result, damage value or recipient state was fabricated. The case is in the Studio index.

The consumer selects the existing measured equipped-weapon pose, samples it on the attack's authored contact clock, replaces the generic physical slash only when that pose exists, and draws the original 24-frame/32-FPS contact once on the actual recipient. Hit scale is 1; Crit retains the authored 1.2 factor. The target's retained facing now selects its rest-pose contact rather than an unconditional South-facing offset. Original actor media uses the same existing source consumer.

GPU review found holes caused by a local LESS depth test on mathematically coplanar trail triangles. The strip now uses stable authored triangle order, followed by its existing two-pixel palette pass and ordinary result Sprite. This does not change actual three-dimensional shell depth selection or restore a world Mesh path. Unchanged rendering takes one world pass; viewport zoom does not regenerate the source strip.

The unchanged original `weapon_trail_draw_commands` is the visual oracle for 16 quarter/time samples. Silhouette overlap is 98.832–100%, weighted premultiplied RGBA mean error 1.209/255. Maximum localized difference is 151/255; this is explicitly **not pixel-exact parity**. The separate diagnostic identifies original floating-point depth ties (spread 7e-15–3.4e-14) selecting different overlapping UVs. Calling the original rasterizer triangle by triangle with stable last-face ownership reduces means to 0.08–0.93/255; the remaining differences are source-grid subpixel coverage/UV rounding. The actual acceptance comparison continues to use the unmodified original whole function. Anti-slop review accepts this qualified evidence and the removal of the erroneous local depth test.

The native compiler/sample test verifies activation, replacement of the generic slash, contact recipient/time/rate/scale, disappearance outside the authored trail interval, and living Idle with retained facing in all quarters. Existing cast-routing and actor-scale tests also pass. Evidence: `.runtime/reviews/weapon-trail/{input,reference,diagnostic}.json` and source/actual images. Full gameplay acceptance of every melee outcome remains distinct from this recorded Hit/Miss slice.

## 11 October — durable reload and local journal replay (N2)

A real SDK follower against the owned unchanged melee host durably records initialization and sequences 1–3. A fresh worker reconciles the SDK's repeated initialization/prefix without replacing bytes or emitting duplicate operations, restores displayed sequence 1 / operation 2 at 100 ms, and compiles the unplayed attack from that same retained prefix. All four IndexedDB payloads match the original capture byte for byte.

The source review exposed a release-identity gap before the first rendered frame: the initial raw record could be acknowledged while its presentation revision existed only in memory. The consumer now durably pins the selected release and initial zero position before retaining/acknowledging that initial packet; ordinary later display checkpoints continue through the same owner. No credential is persisted. An aborted old session can finish its own storage transaction but cannot publish into the replacement session.

Studio can now select saved gameplay scopes from the existing journal. It reads their exact bytes through the same admission, reducer and compiler, restores the saved display checkpoint and requires the recorded presentation revision. It creates no SDK connection, cannot submit native commands, and does not overwrite the live game's saved display position during inspection. Missing initialization, mismatched packet scope or an absent pin produces an explicit error. With the game server blocked, both worker and actual Studio UI acceptance pass: zero attempted game-server requests, unchanged source duration and preserved checkpoint. Studio selects the saved journal, restores operation 2 at 100 ms, stays paused and shows body tracks before Play. The screenshot was inspected; browser errors are empty. Independent anti-OOP and plan-adherence review passes: no new store/schema/parser/manager or second compiler.

Evidence: `tests/session-reload.browser.mjs`, `.runtime/reviews/session-reload/evidence.json`. Full reconnect failure/retention-expiry and all-generation race acceptance remain N2/N5 work; this focused recovery case is not whole transport completion.

## 11 October — native straight Stone/Ice construction sections (R12 slice)

The unchanged SDK capture `construction-sections` contains ten original packets: two ten-foot Stone sections at sequence 2, native concentration retirement at 3, two Ice sections at 8 and retirement at 9. All ten payloads match the native spool bytes. Existing server discovery and preview admitted the path from `[6,5]` to `[10,5]`; no object geometry, hit points, outcomes or packets were rewritten. The owned port 8809 server is stopped. This case and the previously accepted Globe case are now listed in Studio.

The existing world/media/compiler owners consume `world.construction_media`: exact segment module counts, authored heading/variant selection, original pixel scale, source centerline mount and separate physical midpoint for painter order. Camera rotation selects the corresponding existing directional bank. Historical back/front aliases marked as complete replacements coalesce into one actual near/far pair. Cold acquisition selects the intact source directly; witnessed formation/removal uses finite media tracks and the existing scene replacement set, without a second retained lifetime or rendering route. Native admission and clearance use the original 843.75 ms and 850 ms commit offsets. The selected 32-frame formation and 29-frame removal windows remain available at 32 FPS, with the removal tail completing at 906.25 ms.

The real retirement packets also contain generic `ObjectDestroyedFact` rows from item-location retirement. Native owner removal without an explicit fracture, disintegration or damage selects removal art; it does not invent a fracture. Explicit destructive contacts keep their original contact time independently of the visual tail. Formation requires its already-visible footprint. Current object perception, rather than a fractional image mount, selects the ordinary current-versus-memory treatment.

Paired physical sources retain their existing individual hit nodes and painter positions. Only those source images are suppressed after pair composition; the combined result stays noninteractive. The native browser check renders both materials in four quarters with an explicit directional light, sends real DOM pointer events through the production picker, and receives the intended native object UUID in all eight samples. Formation contributes 82,439–90,650 changed pixel channels against the same native scene without the section art; repeated formation/intact draws are exact. Both recorded removals leave no owned drawing; browser errors and presentation issues are empty. Stone q0 and Ice q1 captures were visually inspected. Evidence is in `.runtime/reviews/construction-sections/`; TypeScript and the focused construction/Globe/paired tests pass.

This completes the straight, source-matched Stone/Ice formation/intact/retirement slice only. It does not claim acceptance of damaging fracture, disintegration, partial section cuts or suppression, procedural force/ice domes, arbitrary unsupported headings, other spatial assemblies, or Wall of Fire's missing registered safe-side selection. Those remain R12/N3 work with explicit source limitations; no replacement geometry or mask was invented.

The adjacent paired-wall lifecycle regression now also checks picking after cutaway returns. It reproduced a real unchanged-bounds defect: the restored wall still had interaction disabled, so a click selected the actor behind it. Refreshing the existing hit-node eligibility before the geometry-cache early return fixes it. The same regression passes with the faded wall excluded, returned wall selectable, exact return pixels, one warm world pass, all owned targets/leases released and no browser errors. Evidence: `.runtime/reviews/construction-cutaway-{before,after}.log` and the existing paired-wall lifecycle JSON.

## 11 October — live Crypt UI and exploration

The existing native `crypt` configuration and Expedition seat ran unchanged on the owned private host. One uninterrupted browser journey issued 22 actual commands and retained SDK packets 0–29: supplies approach/open/loot, Vault door, the trap (Sorcerer HP 37→29), sealed cache open/loot, trap lever, Crypt passage and Burial Hall door, ending with the Sorcerer at `[13,6]` and Fighter still at `[3,5]`. Native Reedshot and Gloomplate are then visible. The private setup uses the existing acceptance configuration; no backend, rules, equipment grants or event packets were changed.

The live check reproduced and repaired modal keys moving the camera, double-shrunk HUD anchors under UI scaling, duplicate object labels for equally ranked native verbs, and exposed native bold-colour log syntax. Existing HUD/input owners now capture modal/panel keys, preserve anchors at 75–150% scale, fit action groups to the actual HUD width, expose one label with explicit native alternatives, and use the shared log formatter. Attack buttons resolve the exact disclosed owned weapon's existing icon by its native item UUID. The frame-time display has an actual menu toggle.

`crypt-play.browser.mjs` passes at 1280×720 and 1920×1080, DPR1, with zero page/client errors. Inventory search, compatible-slot inspection, simultaneous inventory/log panels, modal Space, both End Turn gestures and exactly-once loot pass. Typecheck and four native log-evidence tests pass. A test click now waits for the displayed camera frame after portrait focus; a separate development reload interrupted an earlier attempt, so the live harness retains the connected Vite client but holds only its replacement messages. SDK traffic is unchanged. Screenshots, command observations and journey evidence are in `.runtime/reviews/live-crypt/`; exact native bytes remain in the private host spool for epoch `0f80746c-762e-403f-92dc-05dbde2de5c0`.

This completes the selected UI/exploration slice, not N4. Combat through native terminal, ordered target/variant/page/hotkey gestures, reactions/pins, full log gestures and four-camera route/input coverage remain. The inventory follow-up below closes the initially observed FPS/log-header overlap and cramped empty slot labels. The independent original-source review explains the mostly red Sorcerer: the selected Wizard Hat hides Head22 and supplies grayscale Head15 under the native red multiplication tint, with matching red torso/shoes and gold belt. No speculative palette correction was applied; the neutral/tinted source comparison is `.runtime/reviews/live-crypt/sorcerer-original-layers.png`. Software-renderer snapshots do not establish hardware performance or the available monitor/DPR matrix.

## 11 October — live Crypt inventory lifecycle

The same unchanged native Crypt continued through SDK sequences 32–39. The actual inventory/world UI issued seven commands exactly once: recover the robe dropped by the first diagnostic, equip, unequip, drop at the actor's own tile, pick up, re-equip and drink an existing Healing Potion. The original Wizard's Robe UUID and native Body visual layer match before and after pickup; the potion stack decreases by one and native HP rises from 29 to 36. Browser errors are empty. The 1280×720 screenshots were inspected; the frame counter avoids both the resizable combat log and initiative portraits, and empty equipment labels fit their existing slots.

The first run exposed a real world-interaction match defect. Native pickable descriptors omit a template constraint while the admitted action is named `Pick Up`; strict template equality missed that action and attempted movement on the actor's own tile. The existing selection/approach/context-menu owners now share the original `game_obsolete/ui/world_interaction.py` predicate: constrain the template only when supplied, while preserving exact behavior/ref/facets/connector and source-item identity. No movement, item grant or command is invented. The regression uses the existing genuine `inventory-flow/04-pickup-handaxe` choices/preview and fails against the previous match. Both inventory tests pass. Evidence: `tests/crypt-inventory.browser.mjs` and `.runtime/reviews/live-crypt-inventory/{evidence.json,panels.png,complete.png}`; original native bytes remain in the same private Crypt spool. This closes the selected inventory lifecycle only, not the remaining N4 interaction matrix.


### 11 October — native Ice dome source material (R12 slice)

The installed Ice dome now has a finite source consumer for witnessed formation, cold intact hold and native concentration retirement. It consumes the original 5ft/10ft mesh, original normals/UV/indices, three float donor textures, near/far surface selection, Fresnel material, source palette and source timing. Existing construction tracks, native object replacement, worker scene deltas, resource leases and ordinary Sprite output retain ownership; no replacement geometry or general scene-depth pass was introduced. Material normals belong to inner and outer surfaces and do not determine painter ordering; source triangle positions supply the near/far painter representatives without moving the artwork.

`/recordings/ice-dome/case.json` retains four original native packets (formation sequence2, retirement sequence3), each byte-equal to the native spool. Setup uses the existing level-11 generic caster with a real Wall of Ice grant and the original Gloomplate; SDK discovery/preview selected the actual 5ft dome at [7,5]. No geometry, actor HP, event outcome or packet was rewritten. The owned server8809 is stopped.

Validation: `ice-dome.test.ts` passes original mesh equality, four camera views, formation850ms/removal750ms commits, cold hold without replay and final canonical equality; straight-section regression also passes. `ice-dome.browser.mjs` plus the unmodified Python source oracle passes24 samples (four quarters × two zooms × formation/held/removal). Mean occupied-pixel RGB difference is0.696–0.876byte; silhouette intersection/union is at least99.965%. Sparse raster-boundary differences remain (maximum156byte at isolated opaque-background edges), so this is not byte parity. The GPU material-to-original-palette diagnostic was exact for both selected shells. The actual recorded scene uses an explicit directional light and accepts a real pointer selection of the native dome. Held/repeated pixels are exact; warm renders issue only the ordinary world pass; context restoration changes0pixels and decodes0sources; retirement leaves0owner contributions; disposal releases all leases and owned targets. Evidence: `.runtime/reviews/ice-dome/{input.json,reference.json,native-intact.png}` and `.runtime/reviews/ice-dome-final.log`.

R12 remains open for witnessed damaging dome fracture/recorded fragment poses, partial removal/suppression, Force membrane/motes, Frigid Air, unsupported wall headings and the documented missing safe-side source selection. Formation/held/removal acceptance does not stand in for those consumers or an actor-inside interaction case.

## N2/N3 — native Counterspell grouping and original dissipation

The canceled Fireball attempt, reaction gesture and mask now run through the single production Sprite/filter path. Exact native handler attribution groups the consecutive reaction and incoming root; state reduction retains original native order. Both release/cutoff occur at 871.597 ms in the real automatic-success capture. The original carrier keeps its sampled position while the 500 ms mask advances; no impact/damage is invented. Source `Magic3` hand pixels and per-camera response rings remain separate from body coloring.

Typecheck, five focused native tests and 16 Fireball production GPU samples pass; final state equals native reduction, each event is revealed once, backward seek is deterministic, mask restoration/repeat have zero differences, and views/leases are released. The actual case is listed in Studio. Finger's explicit cancellation profile is also connected and captured through the unchanged native SDK/server: original 1,275 ms cutoff, 2,375 ms cameo tail, camera/facing reaction profile, no directed delivery or recipient damage. Two focused native tests and 16 Finger scene samples pass. The original-source comparison is qualified by fractional sprite rasterization (raw IoU 89.28–100%, mean 0.056–18.26/255; one-pixel-neighbour colour diagnostic mean ≤0.390/255), with no alternate raster path. [Review and qualifications](reviews/renderer-2026-10-11/counterspell.md). Failed/nested/lethal reaction combinations and interrupted arcs remain separate; this does not close all N2 or N3.

## N2 — disconnect and scope replacement

Explicit disconnect now rejects outstanding worker requests, suppresses already queued callbacks from the retired generation and rejects requests until another source starts. Previously a pending compile could remain unresolved forever after worker-side stop. `session-scope.browser.mjs` passes with the exact Counterspell and Dimension Door recordings: replacement during compilation, explicit disconnect, subsequent reopen, correct new prefixes and no stale state/error callbacks. The browser test uses real worker admission/compiler functions and no GPU or fabricated packet. Independent adherence/ECS review passes. Evidence: `.runtime/reviews/session-scope/evidence.json`.

The combined regression batch after these changes passes typecheck and all 51 Node tests (47 top-level tests), in 18.44 seconds. This batch covers merged current consumers; it is not full native/UI/performance acceptance. Subsequent active slices require their own focused checks.

## N3 — complete indexed source access in Studio

The read-only Sources tab now enumerates every family in the active release's existing file map, including sources without a track in the selected recording. It searches indexed names, loads only the selected document and exposes its canonical file/pointer plus all source fields through the existing lazy field tree. Recorded, local-candidate and unpinned identities stay explicit. No new catalog, authoring/save API, preview renderer or eager library load was introduced.

Selected-track inspection now exposes the separate exact colour swap, palette/layer material, alpha mask, blend and paired radiance values, together with any authored media emitter. The receiving-policy/current-versus-memory field is labelled separately; native light categories are not shader illumination. Ordinary action effects, including Counterspell, use their exact unique body lineage as the existing subordinate track relationship.

Typecheck and `studio-inspection.browser.mjs` pass. The genuine ranged case retains its pinned Goblin03 Attack1 source/frame and unchanged clock; browsing the same release's Fireball source performs only that selected JSON read, leaves the map bounds unchanged and provides no editing controls. The screenshot was inspected at 1200×900. Evidence: `.runtime/reviews/studio-inspection.log` and `.runtime/reviews/studio-inspection/sources.png`. This closes indexed source access, not all source-family semantic/rendering acceptance.


### 11 October — native Ice dome fracture and bounded source targets (R12 slice)

`/recordings/ice-dome-fracture/case.json` contains32 original native packets, byte-equal to its unchanged server spool. A real level-11 caster creates the native120HP dome and uses the existing Fire Bolt action against its actual object target. Native damage38/44/miss/36/52 destroys the dome at sequence27; all following packets through31 are retained. No HP, geometry, damage or packet edits supplied this result; owned server8809 is stopped. Studio lists the recording.

The existing construction source consumer now plays the original72 fragment meshes and recorded144Hz poses for2,300ms, in original piece → far → near order. Native destruction commits at the actual lethal hit, independently of its visual tail. One float selection scratch and one encoded output replace the proposed per-fragment target multiplication. Across the24 source samples the largest color allocation is170,136bytes, plus up to2,754depth pixels. This count excludes shared donor textures and geometry buffers. Both targets are reused; repeated samples do no source work, and context restoration produces identical pixels with zero new decodes. Disposal releases all source leases and owned targets. The native Node check passes exact source mesh/pose equality, all quarters and final state equality. The previous whole-dome q0 source/picking/lifecycle regression remains unchanged and passes after this refactor. Independent source/ownership review passes.

The unmodified Python source comparison was run for24 fracture samples (four quarters × two zooms ×100/800/1,800ms). Its existing whole-dome mean<1.5byte assertion still fails10 half-scale samples: maximum mean1.808byte and isolated channel maximum184byte, with silhouette intersection/union at least99.823%. All12 zoom2 samples pass that assertion. This is qualified numerical/source evidence, not byte parity or a silent tolerance change. A separate offline calculation feeds the exact original fragment RGBA into the new encoded rgba8 accumulation sequence: that grouping alone adds roughly0.60–0.82mean bytes versus original per-command drawing over the backdrop; production versus the independently grouped original is below1.5mean bytes across24samples. The remaining difference includes the known source/GPU raster boundaries. The original comparison and its failing threshold remain unchanged in `ice-dome-reference.py` and `.runtime/reviews/ice-fracture/{reference.json,grouping.json}`.

Changing fracture frames still use289 finite source passes plus the ordinary scene pass. On the identified SwiftShader device, eight advancing samples submit in2.5–4.8ms and show33.3–50.1ms RAF gaps; no shader compilation, geometry upload, new texture or donor upload occurs in those advancing samples. Two output resizes occur across the eight samples. The first cold draw takes91.3ms including shader/geometry creation; cached draws take at most0.4ms and only the scene pass. These measurements do not establish hardware-GPU performance. Evidence is `.runtime/reviews/ice-fracture/{input.json,native-fracture.png}` and `ice-fracture-final.log`.

The authentic lethal hit also creates Frigid Air. Its retained `wall_assembly` source consumer is the next R19 slice and is explicitly reported as missing by this recording; fracture does not claim that aftermath complete. Partial construction cuts/suppression, Force membrane/motes, unsupported wall headings and the documented missing safe-side mask also remain open.

## N2 — acknowledgement loss and actual browser storage failure

`session-reconnect.browser.mjs` faults only HTTP delivery to the unchanged native host: once before operation 2's acknowledgement reaches it, and once after the native host accepts that acknowledgement but before the response reaches the SDK. Both cases recover through the existing running follower with one attachment, ACK sequence `0,1,2,2,3`, stream positions `0,2`, exactly one initial callback and operation callbacks `1,2,3`. All four journal payloads equal the captured native bytes; the durable display checkpoint stays at zero. No follower cursor mutation, replacement transport, native command or backend change was added.

A separate test applies a real 32 KiB browser-origin storage quota before admission. The actual 488,388-byte native initialization cannot be retained: there are no initial/operation publications and no ACK requests. This exposed a blank `QuotaExceededError.message`; the worker now reports the failed operation and the storage/reconnect action instead of an empty error. After the test restores browser capacity, a fresh session admits the exact original four records successfully. Previously admitted-prefix reload and scope replacement have separate passing evidence; this storage case specifically tests initial admission, not an artificial claim of later-record exhaustion.

Evidence: `tests/session-{reconnect,storage}.browser.mjs`, `.runtime/reviews/session-{reconnect,storage}/evidence.json`. No GPU was started. Actual host-history expiration remains distinct from a network outage; local offline replay is already verified without any game-server request.

## 11 October — native target gestures and interrupted Crypt recovery

The earlier private Crypt host exited before the queued reaction command was received. Its in-memory encounter has no supported restore entry point. The original epoch `0f80746c-762e-403f-92dc-05dbde2de5c0`, native spool and completed exploration/inventory evidence remain intact; the browser evidence is preserved under `.runtime/reviews/crypt-epoch-0f80746c-before-host-exit/`. No fabricated continuation, HP reset or edited event supplied recovery. The identical existing Crypt configuration was started as a separately owned detached host, and the actual UI repeated exploration and equipment in fresh epoch `6d61d7f1-f0c4-4ab8-b451-aa1bfbea9f4d`: exploration reaches sequence29, six equipment/use commands reach35, and native healing again changes29HP to36HP.

`crypt-gestures.browser.mjs` then passes against that same native session through sequence38, with no browser errors. Visible digit/Shift shortcuts select their painted spell rows; actor-local Magic Missile pin/unpin survives inspecting the non-turn Fighter without granting spending rights; native reaction toggles issue one command each; the displayed healing text copies exactly. The reachable Level2 popup resolves its actual native row without spending. Gloomplate → Reedshot → Gloomplate preserves the ordered repeated prefix, displays native effective allocation counts2/1 and does not auto-submit at maximum. Undo removes only the last index, cancel spends nothing, and a separate Level1 prefix `[0]` confirms once while the server supplies `fill_primary` recipients. Appended cast logs preserve a scrolled-away reading position, and Follow latest reaches the end. Screenshots and exact request/preview observations are in `.runtime/reviews/live-crypt-gestures/`; the ordered-target screenshot was inspected.

The live failures were in existing UI owners: flattened action-button order dispatched a different row than the visible digit slot; delayed help covered the variant choices; removing a focused popup re-entered its removal through focusout. The action bar now maps actual group columns/rows to the existing shortcuts and clears its popup reference before DOM removal. The shared tooltip stays above the open choice region, lets unpinned pointer events reach the choices, and does not publish a delayed caption for a detached anchor. No new interaction model, keybinding framework, native command path or authority rule was added. Independent plan/ECS review passes. These checks close the selected repeated-target/variant/reaction/log gestures only. Full authored Crypt combat, independent group-page coverage, other conditional choice families, full log-fold/filter cases and the remaining route/modifier/four-camera matrix remain separate N4 acceptance.

## N3/R19 — Guardian of Faith native entry response

The genuine `guardian-response` SDK case is now available in Studio: four native entries apply 10/20/20/10 damage and exhaust the real 60-point source budget. The client consumes the original response bank, frame 13 blade contact, finite blade geometry, positive Radiant material/contact media and final fade. Native step arrival admits the response; later movement waits and committed damage is revealed once at source contact. Maintained idle is replaced only while striking, response-facing is retained and admitted motes keep their source visibility rule. The living recipient returns to Idle; the exhausted Guardian retires.

Focused native tests, TypeScript, 24 four-quarter production samples and 32 independent original-source comparisons pass with the recorded raster qualification. Sheet RGB means are 0.21–0.90/255; complete blade/sheet means are 0.32–5.42/255. The recognized native Guardian anchor no longer reports a false missing ground-item appearance; no fallback artwork or backend change was introduced. See [the source/native review](reviews/renderer-2026-10-11/guardian-response.md) for exact evidence and visibility limits. Other R19 consumers and the full plan remain unfinished.

## N2/N3 — Shield condition interception

The actual Magic Missile recording now presents one defensive Shield cast and
three directional interception pairs, using the original condition and spell
recipes. Incoming world direction selects the impact bank; the atlas's E basis
independently selects its camera view. Authored frame rates stay unchanged.
The native regression preserves all three blocks, the defender's 40 HP, canonical
final state and one commit per event. Twelve production GPU samples across four
quarters pass with no errors, exact repeated/restored pixels and zero retained
scene resources after disposal. All three installed packets match server spool
bytes; the case is indexed in Studio. Independent source/ECS review passed.

The negative-start timing branch is source-reviewed but is not exercised by this
recording. Spatial projectile deflection remains separate R08/R19 work; the full
plan remains active. [Detailed evidence](reviews/renderer-2026-10-11/shield-interception.md).


## 11 October — completed native Crypt combat and physical actor picking (N4)

The same authored Crypt epoch `6d61d7f1-f0c4-4ab8-b451-aa1bfbea9f4d` now completes the actual UI journey: exploration through29, equipment/use through35, ordered spell/reaction gestures through38, native approach/AI turns through54, then equipped Longsword against Reedshot55, admitted Move to[12,5]56 and equipped Extra Attack against Gloomplate57. The original server reports terminal cursor57. Both attacks use the exact disclosed weapon UUID, choice index and target index; the native critical hit supplies14 damage and Gloomplate's death. No configuration, HP, rule, packet or backend changes supplied these outcomes. The terminal UI waits for displayed57, disables spending, and retains inventory inspection after dismissal. Browser errors are empty. `tests/crypt-combat.browser.mjs` passes; `.runtime/reviews/live-crypt-combat/{approach-prefix.json,evidence.json,terminal-log.png}` retains the split acceptance evidence. The final scene/log screenshot was inspected at1280×720/DPR1.

The blocked first melee gesture exposed a real Pixi hit-area defect: each fixed goblin frame includes24 alpha-one corner registration pixels. Those widened Gloomplate's hit rectangle across Reedshot's visible body. Existing decode metadata now retains both ordinary rendering occupancy and compact physical occupancy from the same decoded pixels. Rendering still includes the corner markers; physical fixed-body bounds use the original `uBody` companion, and modular bodies honor the rig's existing excluded slots/categories. Only Pixi `hitArea` changes; draw/culling bounds, source pixels, pivots and composition remain unchanged. There is no per-pixel picker, GPU readback or extra decode. The source-backed composition regression and typecheck pass. Before/after actual `pickScene` evidence is retained under `.runtime/reviews/live-crypt-picking/` and `live-crypt-picking-fixed/`: Reedshot torso[704,366] changes from intercepted Gloomplate to the correct Reedshot without sending a command. The subsequent real native attack is the spending-path regression. Independent plan/ECS code review passes.

This closes the selected default Crypt journey and demonstrated physical hit defect, not all N4. Independent group paging/current-page shortcut behavior, additional conditional native choice families, complete log fold/filter/copy behavior, and the route/modifier/four-camera input matrix remain. Hardware-GPU performance and the current monitor's DPR/layout remain separate N5 acceptance; the saved SwiftShader frame counter is not a hardware result.

### R19/R08 — native Wind Wall projectile deflection

Connected the actual received native wall intersection in the existing attack path. Six exact SDK packets prove an equipped longbow shot stops at [7,7] without native damage; source timing/socket correction and the five original WindHit crosses now render through finite GPU material ownership with an ordinary Sprite result. The missing catalog entry for its already installed original texture is corrected. Three focused native tests and typecheck pass; 12 native GPU views, 32 original-source comparisons, warm drawing, context restoration and disposal are recorded in [the focused review](reviews/renderer-2026-10-11/wind-interception.md). Mean source error .47–2.61/255 (raw max73) is explicitly qualified for raster/palette boundaries. The retained-flow gap identified at this checkpoint is now connected and checked in [the retained Wind review](reviews/renderer-2026-10-11/wind-flow.md). No full R12/R19 or full-port completion is claimed.


## 11 October — terminal Crypt log and camera inspection (N4)

The genuine completed Crypt remains at native terminal57 during `crypt-terminal.browser.mjs`. Category=death plus participant=Gloomplate retains the original attack/damage ancestors and dead actor name. Global/row detail, fold state across filter rebuilding, and native attack-roll27/damage14 evidence pass. Filtered tree copy and selected-text copy preserve the recorded text and values; Ctrl+C inside the log does not enable world attack. Closing/reopening retains the reader's scroll position, and Follow latest reaches the final entry. Four actual Q/E views publish matching quarters, return to the same centre/zoom and keep displayed57; terminal Alt exposes no stale action choices. Cursor-anchored zoom and panel typing/copy isolation pass. The test sends zero gameplay commands and reports zero browser errors. The saved final log and all quarter screenshots were inspected; evidence is `.runtime/reviews/live-crypt-terminal/`.

The actual installed blur handlers release held camera movement and Ctrl/Shift when delivered a browser `FocusEvent('blur')`. Playwright forces page focus, and tab switching did not deliver blur even in the bounded focus probes; this acceptance deliberately delivers that event without mutating application state. It does not claim OS-window focus behavior. Active Alt/interactable consistency, routing/modifier spending, paging/current-page shortcuts and remaining conditional native facets stay open for the active native surface. No production source changed in this terminal batch.

### R12/R19 — original Frigid Air dome and segment aftermath

The earlier missing Frigid Air aftermath is now consumed through the existing construction material and passive spatial lifetime owners. The genuine dome fracture supplies its radius-five retained field; the new `frigid-air-segment` case contains 12 unchanged native packets. A normal Fire Bolt applies 38 Fire damage to a real 30 HP Ice section, creating native Air at [6,5], [7,5], [8,5] while the neighboring section remains. The separately owned capture host on 8821 is stopped. No native geometry, damage, HP, packet or source-art edits supplied either result.

Original dome geometry, segment volume box and 16 density samples, source palette, formation/removal laws and 24/14 flake formulas remain intact. Each occurrence uses one retained float selection scratch and one ordinary Sprite output through the existing construction consumer; a shared shader reads the small native admission/exclusion texture. Air is noninteractive, cold acquisition uses the existing retained clock, and backward prefix changes retire the same spatial owner. Studio exposes its source and clock. Independent source/ECS review passes.

Typecheck and the native Ice regression pass, including four-quarter geometry, neighboring-section preservation and canonical state. All 24 original segment source comparisons pass: mean 0.268–0.366/255, IoU at least 99.829%, maximum 4 bytes. Dome evidence remains explicitly qualified: 20 of 24 samples pass the unchanged original assertion; four early half-scale samples contain five or six extra faint pixels and fail its 98% IoU threshold (96.55–97.13%, mean 0.132–0.156/255, maximum 3 bytes). Across all dome samples mean error is 0.086–0.527/255, raw maximum 34 bytes; held/cold IoU is at least 99.94%. The original oracle and failures are preserved, without a tolerance change or byte-parity claim.

Both actual native cases animate while retained, rewind exactly and restore identical pixels after context loss with zero new decode; disposal leaves no views, leases or owned targets. The prior whole-Ice source/picking/lifecycle regression also passes after these additions. Changed dome/segment samples use 53/31 source passes plus the scene pass; repeated unchanged frames use only the scene pass. Maximum color-target totals in these sweeps are 1,361,600/910,000 bytes, excluding depth, admission tables and geometry. These are bounded source measurements, not hardware-GPU performance acceptance. [Detailed evidence and original-source qualification](reviews/renderer-2026-10-11/frigid-air.md).

The authentic records have no Air suppression provider or native Air expiry, and the bare source oracle does not establish actor-inside-field depth interaction. Partial construction cuts/suppression, Force membrane/motes, remaining spatial responses and missing safe-side inputs remain separate full-plan work.

## 11 October — native conditional choices and independent paging (N4)

The private native session on owned port 8825 uses the original premade Sorcerer,
a source-authored generic caster and a Gloomplate enemy. The caster has only the
three relevant supported spell grants: Wall of Fire, Conjure Animals and Spirit
Guardians. No weapon, HP or outcome edits were made. Protection from Energy was
not used for an invented element selector: current native discovery exposes no
such facet. This is UI acceptance, not another public multi-spell visual demo.

`tests/ui-choices.browser.mjs` reproduced a real Wall popup defect: selecting
Ring from a Segment selection immediately entered targeting before exposing the
new heat-side lane. The existing action bar now recomputes the selected native
row's conditional lanes before deciding whether a choice is final. The rerun
passes Level 5 / Ring / Heat outside, then Level 4 / Segment; compatible choices
remain selected and no intermediate action is submitted. Conjure Animals Level
6 / Elephant then Level 3 / Wolf resolves only the actual native form pools.
Base/spell pages and local wheel movement stay independent at a narrow viewport;
visible-slot shortcuts use the current page and cannot execute while inspecting
a different, non-turn actor. The narrow viewport proves paging logic, not the
minimum visual layout matrix.

The same run uses the actual Move command to place the caster at `[3,3]`, outside
the allied Sorcerer's future area, then selects Level 4 / Necrotic Spirit Guardians.
Exactly one final self-action command matches its native preview and discovery
index; the native retained zone reports Necrotic and the ally's HP is unchanged.
All five checks pass with no browser errors. The screenshot was inspected.
Evidence is `.runtime/reviews/ui-native-choices/evidence.json` and
`conditional-complete.png`. Native resource conversion and the remaining full
N4 interaction matrix are separate checks, not implied by this batch.

The same authentic UI session then advanced to the original Sorcerer's turn.
`ui-conversion.browser.mjs` selected actual Magic Missile against the enemy and
rank-1 Font of Magic through the action bar: displayed level-1 slots were
4 → 3 → 4, sorcery points 5 → 5 → 3, and bonus actions 1 → 1 → 0. Exactly two
commands were submitted and the conversion used its actual discovery index.
The native action names now distinguish Slot→SP from SP→Slot; the inherited
provider icon remains unchanged. Previously both controls used the provider's
“Sorcery Points” label, obscuring their opposite directions. Stored native HUD
assertions and browser runtime checks pass; the screenshot was inspected.
Evidence: `.runtime/reviews/ui-native-conversion/evidence.json`. Unavailable
choice inspection and the newly connected log resize lock are still under
bounded browser acceptance; this is not full N4 completion.

## N3/R17–R18 — native whole-prop silhouette dust

The actual Disintegrate field-cache recording now removes its chest at native impact while retaining the witnessed original silhouette for 2500 ms of authored dust. Canonical object refresh no longer deletes the finite effect at unrelated animation boundaries. The finite source target draws through the same ordinary Pixi Sprite/light/viewport path, is noninteractive, and does not recompute on zoom. Three SDK packets match the original server bytes.

Native contact/final-state/event tests and the existing full Ice Storm scene-delta regression pass. Twenty four-quarter GPU samples pass placement/lifetime/picking, warm and zoom single-scene-pass behavior, exact rewind/context restore and zero-leak/error checks. The unchanged original Pygame dust comparison passes >99% overlap and <1/255 mean PMA error; raw maximum208 at two particle-edge pixels remains qualified, not hidden as byte parity. The comparison uses raw GPU bytes because Pixi's PNG path adds a Canvas alpha conversion. Independent source/ECS review passed. [Evidence and source review](reviews/renderer-2026-10-11/object-dust.md).

The native destruction spills five items whose ground artwork is unmapped in both adopted authoring and original Pygame: Fireball/Magic Missile scrolls, acid flask, healing potion and Fire weapon coat. Their exact issues remain visible; no fallback artwork or packet edits. Actor dust, partial construction dust, Wind/Force work and other global-plan requirements remain active.

The nonspending continuation now passes: a depleted native rank remains
inspectable and sends no preview or command. The selected action's accessible
caption and delayed tooltip resolve its current native rank/cost instead of the
initial row. The existing tooltip owner accepts a current-content callback; no
second action-selection or tooltip state store was added.

The existing combat-log width grip now has a compact lock control, using local
view state and the same pointer-capture owner, with pointer-cancel release.
Actual dragging enlarges the log, locking prevents resize across close/reopen,
and unlocking allows resize again. The action bar stays in place and no command
is sent. `INSPECT_ONLY=1 node tests/ui-conversion.browser.mjs` passes all three
checks without browser errors; screenshot inspected. Evidence is
`.runtime/reviews/ui-native-conversion-inspection/`. Shared typecheck passes.
The next active N4 checks are four-camera interactable labels/cutaway and native
safe/Shift routing with the actually committed movement prefix; terminal camera
checks and the prior three-door Crypt journey do not establish those contracts.

## N3/R12–R19 — retained Wind Wall flow

The existing selected Wind `wallAssembly.flow` recipe now renders its original joined sheets, chips and formation contacts through retained spatial lifetimes and ordinary Sprite outputs. Original linear composition supplies the shared palette while each source surface keeps separate alpha and scene order. Displayed actor contacts drive quiet parting; only positive native damage packets with the actual field owner drive formation contacts. Native state and source artwork remain unchanged.

The focused `/recordings/wind-flow/case.json` has thirteen exact SDK packets: first wall, actual intercepted shot, entry/exit, concentration removal, then a genuine second wall through the recipient (16 native damage) and removal. Three native/spatial tests and typecheck pass. All 24 native camera/lifecycle views pass; both removals leave zero field drawings after the authored tail. The 32 original-source views are qualified at mean 0.645–1.145/255 and silhouette overlap 96.995–98.902%, with maximum97 at raster/material boundaries. Independent ECS/source readback passed; the original whole-fragment alpha>.01 omission differs at faint reveal/fade edges and remains explicitly qualified. Warm frames use one final world pass; repeat/context restoration are exact with zero new decodes, and disposal leaves zero leases/views and destroys all owned targets. No byte-parity or hardware-performance claim is made. [Source/evidence review](reviews/renderer-2026-10-11/wind-flow.md).

This closes the missing retained-flow consumer identified by the earlier deflection checkpoint. The current native acceptance is a straight wall; the original joined path has source topology coverage, while other native shapes/suppression combinations and the rest of the global plan remain open.

## 11 October — active Crypt labels and native route modifiers (N4)

The next acceptance uses a separate unchanged `configuration('crypt')` host,
8827 / PID 3109157, leaving the completed 8795 encounter and its evidence intact.
The port was free before launch; the prior Force capture owners confirmed their
own processes had stopped. No process was terminated by port.

`crypt-routes.browser.mjs` passes the active four-camera check: each view retains
the same six admitted object labels, and the chest's real native alternative
menu remains reachable and cancels without spending. All four screenshots were
inspected. With a stationary world pointer, Shift requests `prefer_safe=false`
and release requests `true` again; actual previews, then the committed selection,
match exactly. For this clear entry-room route the native result legitimately
uses policy `normal` for both requests because no separate safe path is supplied.
The actual committed step `[4,5] → [5,5]` matches that displayed native route.
There are no browser errors. Evidence: `.runtime/reviews/live-crypt-routes/`.
The longer door/ally corridor and actually interrupted movement are separate
coverage; this first route does not claim either.

The actual continuation also passes both Crypt passage and Burial hall doors:
each uses native approach, receives the movement result, rediscovers and opens
the admitted door. All four movement commands compare their actual preview
paths to committed Step facts and displayed endpoints. The Fighter routes around
the Sorcerer; the Sorcerer's later sequence11 route crosses the Fighter's occupied
`[8,6]` cell, following `[7,6] → [8,6] → [9,6] → [10,6]` for the native 15ft cost.
No command invents an ally obstacle or a client path. The sequence13 screenshot
was inspected and runtime errors are empty. Evidence is
`.runtime/reviews/live-crypt-routes-doors/`. All movements completed normally;
a genuinely interrupted native movement case remains unproven.

## N3/R04–R17 — native actor silhouette dust

The actual disintegrated LifeFact now retires the actor at contact while preserving its immediately preceding complete source image for the original finite dust interval. The existing body compositor applies dust to native pixels before fixed2×cleanEdge, with a separate source-pixel shadow dissolve and no legal actor hit region. Original CRC32 seed, preserved-item exclusion, prior pose/facing/condition/material context and ground-shadow registration are retained. No backend or packet changed.

The focused real case contains eight original SDK packets: a saved first cast, two actual end-turn commands and a lethal second cast applying86 Force damage. All packets match server spool bytes. Twenty four-quarter browser samples pass finite retirement, shared Sprite/picking behavior, repeat/zoom, exact rewind/context restoration and cleanup. Original Pygame dust comparison has100% silhouette and exact alpha across all20 samples; PMA mean0–0.174/255 and maximum<0.5/255. The complete61-test Node suite passes after the compiler context integration, along with typecheck. [Source decisions and bounded acceptance](reviews/renderer-2026-10-11/actor-dust.md) retain qualifications: preserved equipment was not present in this native case, and unfinished Blur/absence/live-copy consumers are not delivered by dust.

The N4 Crypt route continuation also passes the actual intake/display boundary:
native sequence14 moves the Sorcerer from `[11,6]` to `[13,6]`. During the real
received-ahead-of-displayed interval, End Turn is disabled and Space emits no
additional command, while camera panning remains responsive. Newly appended
native log entries preserve the exact visible reading anchor and scroll offset;
Follow latest remains available. The final screenshot was inspected and browser
errors are empty. Evidence: `.runtime/reviews/live-crypt-routes-async/`. This is
an actual normal movement presentation interval, not an interrupted-route case.

## N4 — physical actor/object hover and admitted Alt highlights

The existing input owner now gives the shared renderer current hover/selected
gold and native eligible/Alt green identities. The existing Sprite filter chain
draws the source's two-CSS-pixel inner edge, using physical coverage rather than
image padding. Fixed bodies use their retained body source, excluding the
combined shadow/accent. Modular bodies use their composed physical parts; only
bodies with excluded effect parts need a lazy native coverage target in their
existing body lifetime. Picking, source textures and floor caches are unchanged.
The native readiness gate clears highlight identities during pending spending
or intake/display catch-up; Alt labels use that same gate.

`tests/highlight.browser.mjs` passes exact independent inner-edge pixels at DPR1
and DPR2 and two zooms, including an atlas neighbour, concavity, a hole, partial
alpha, alpha-one registration marks and an excluded modular effect. All eight
real fixed/modular body quarter views contribute, clear exactly and keep the
ordinary Sprite path. Context restoration is exact; lazy targets are disposed
and views/leases return to zero. The genuine sequence14 Crypt's four camera
views also pass actor hover, admitted Alt identities, reachable label hover and
clear without commands or browser errors; all screenshots were inspected.
Evidence: `.runtime/reviews/interaction-highlight/` and
`.runtime/reviews/live-crypt-highlights/`.

This is a bounded source-edge implementation: normal painter order hides the
edge behind foreground artwork, but it does not add the original extra edge
along a newly occluded cut boundary. That exact post-occlusion parity is open.
The support-top follow-up below uses the actual top polygon; a full terrain-image
outline would incorrectly include cliff sides and is not a substitute. No N4/N5 completion or
hardware performance claim follows from this batch.

The bounded support-top follow-up is now implemented in existing ground
feedback: one edge-only source occurrence intersects original source alpha with
the projected received support-top polygon, as `interaction_frame.support_selection`
does. The floor cache and picker remain unchanged. The independent elevated-top
pixel oracle passes all four quarters at DPR1/2 with exact edge pixels and no
side-face pixels; the preceding actor/object contracts still pass. Actual Crypt
support hover UI acceptance now passes all four camera views, including clearing
on a real DOM control. One native admitted Dodge command also confirms that every
observed pending/catch-up frame clears both owner highlights and ground feedback.
The four screenshots were inspected and browser errors are empty. Evidence:
`.runtime/reviews/live-crypt-support-highlights/`. Joined
specialized construction members and exact new edges along foreground cuts
remain separate qualifications; ordinary prop checks do not establish them.

## N3/R12 — original Force membrane and joined panel lifecycle

The installed Force surface now consumes its original dome mesh, straight-panel lattice, pulse/formation material, actual-hit damped field and Disintegrate motes through the existing construction owner. Invisible Force retains physical construction dates without inventing a perceived spatial effect. Only current native object disclosure draws the held membrane. Pending members form separately; adjoining held members share one original material while actual member IDs and native-height picking remain separate. The finite retirement track preserves the preceding clock through contact. No native reduction, authored geometry or outcome changed.

Two genuine recordings are installed: `force-construction` (13 packets, radius5 dome, native Disintegrate) and `force-panels` (18 packets, two native ten-foot members, actual equipped Dagger Hit, native whole-owner Disintegrate). Both equal their retained native spools exactly. Only the missing original Force noise companion was copied, with an exact-source receipt; no JSON reimport. Both native tests, 64 all-quarter panel pick checks, context restoration/cleanup and the shared whole-Ice regression pass. Original144Hz field values are exactly equal at0.1/.3/1second for the genuine hit.

The 80 source-view comparison remains qualified: the unchanged numerical assertions fail11/40 dome views and7/40 panel views, principally sparse collapse and material edges. Dome means are0.318–2.466/255 with overlap93.971–100%; panel means0.336–1.979 with overlap94.726–100%. No threshold or reference was changed, and no byte-parity claim is made. Each prepared side retains one scratch/output pair; changing collapse frames use up to126/124 passes (dome/panel), while unchanged warm frames use one final world pass. Software/source evidence is not hardware-performance acceptance. [Source and ownership review](reviews/renderer-2026-10-11/force-construction.md).

Force membrane/motes are no longer missing consumers. Native normal concentration retirement, other extents/angles, occupied-field interactions, general partial construction cuts/suppression and missing safe-side inputs remain separate coverage; the full plan remains active.

## N3/R17 — readable concurrent floating feedback

Damage/healing/outcome labels now use the original above/below/least-overlap placement against existing physical actor coverage and other labels, preserving authored size, text, color and timing. Three pure placement checks and four real Fireball camera views with seven concurrent labels pass; repeat placement is stable, cleanup has zero views/leases and browser errors are empty. Screenshot inspected and independent source review passed. Browser font rasterization and independent cross-action feedback lifetime remain explicitly separate from this placement result. [Focused evidence](reviews/renderer-2026-10-11/feedback-layout.md).

## N3/R14 — native frozen condition body pose

The real Hold Person capture now holds authored modular Idle frame 3 while Paralyzed and resumes Idle after native concentration removal. Four camera views keep identical held pixels after 2400 ms, then change after removal; current world contact and appearance remain independent of the held body sample. Source review and focused condition/dust/Mirror regressions pass, typecheck passes, and GPU cleanup returns views/leases to zero. Screenshots inspected. The live Petrified captureCurrent lifecycle remains unaccepted; its body-sample boundary has source review and a focused pure check only. Evidence and source ownership: [condition-pose review](reviews/renderer-2026-10-11/condition-pose.md).

## N3/R12/R19 — native Ice suppression checkpoint

The `ice-suppression` recording now preserves seven unchanged native SDK packets: witnessed Ice formation, a separate caster's actual Antimagic sphere, and native concentration removal restoring the same Ice object. The existing construction owner consumes original sphere/source coordinates, masks after original palette selection, and separates surviving contributions around the provider's authored back/front depths. It uses no tile mask, substitute geometry, new renderer or backend changes. Native canonical/delta/no-replayed-formation checks pass in all four quarters; the shared Force native tests pass.

Twenty-four source views pass the existing original Ice comparison (mean at most0.918/255, silhouette IoU at least99.938%, existing isolated156-byte raster edge qualification). Native resumption and context restoration are exact, unchanged frames keep one world pass, and disposal leaves no views/leases/hit entries. The full sweep exposed and fixed three displayed-pixel boundary picking mismatches by sampling the displayed texel centre; all112 retained/hole picks now pass. The independent original provider-depth interaction reference also passes all four quarters (mean 0.130–0.411/255, IoU at least99.995%, isolated153–155-byte original-source edges). Its corrected input preserves raw PMA provider pixels because installed Pixi extraction returns premultiplied bytes; source inputs and thresholds were unchanged. Six202×152 source outputs and six float selection targets use3,684,480 colour-attachment bytes at zoom2 and thirteen cold passes; this is not a hardware FPS claim. [Source scope and evidence](reviews/renderer-2026-10-11/construction-suppression.md).

Overlapping provider ordering, partial section cuts and missing safe-side source selection remain separate requirements; Force dome suppression is accepted below. Installed Ice/Stone paired banks do have original depth/camera packets, so their unfinished cut consumer is not a blanket missing-coordinate blocker. This checkpoint does not complete R12/R19 or the full client plan.


## N3/R14 — original Mirror Image live copies

The selected live-copy recipe now uses native condition count dates and the existing composed body/Sprite/filter route. It retains original stable-slot emergence, wave/palette, world offsets, smoke and removal tails, shares current gear/cast pose, and adds no native actor, shadow, legal target, hit region or item-attachment duplicate. Copy-only registration respects held poses; native reduction and authored source inputs are unchanged.

The genuine `mirror-image` case has seventeen exact SDK packets: self-cast, movement and three original longbow attacks consuming counts3→2→1→0. Native/cold-worker tests pass, including a reproduced cold-base metadata omission that lost the second removal smoke. The worker comparison base now uses preceding condition lifetimes, matching its caller; current semantic commits keep their current lifetimes. Held-pose, dust and exhaustive Ice delta regressions and typecheck pass.

Production GPU acceptance passes60 source samples/28 native views in all four quarters, all three smoke losses, no duplicate picking, source-stable zoom, exact rewind/context restoration, zero decodes on restore and zero retained views/leases/errors. The unchanged original `ghost_body` comparison passes: mean 0.180–0.193/255, maximum1.118 raw-PMA bytes, alpha error≤1 and support overlap≥99.784% (one faint-pixel difference in one view). No byte-parity or hardware-performance claim is made. Independent source/ownership review passes. [Focused evidence](reviews/renderer-2026-10-11/condition-copies.md).

The subsequent Blur checkpoint below covers distortion and historical afterimages. Absence echoes and untested coexisting-condition/suppression combinations remain separate requirements; these checkpoints do not complete R14 or the global plan.

## N4 — supported controller arrangements through the actual UI

`tests/controllers.browser.mjs` passes the five existing configurations:
two human sides with two controlled units each; four individual human seats;
human versus AI; AI versus human; and mixed human/AI members on each side.
The client-private setup preserves the original seat assignments, controller
defaults/overrides, initiative policy and deployment. It replaces the historical
generic Goblin plus shortbow grant with the authored Reedshot's native source
and equipment; there are no item grants, patched outcomes or fabricated packets.

Across all ten connected human seats, portrait sets match the native controlled
sets, inspecting units keeps one session connection and sends no command, and
non-owning Space cannot spend. Each admitted End Turn click submits once with
the current native actor. All three AI arrangements include actual native
automatic attack/movement facts and catch up through the same presentation path.
The original test missed primary facts on `lineage.root`; the failed evidence
and native spool remain, and the corrected check reads that root plus its events.
Only the three unfinished modes were rerun. Screenshots were inspected and no
browser errors occurred. Evidence: `.runtime/reviews/controller-matrix/`.

This accepts the bounded connection/authority/controller transitions, not full
combat completion for every setup or hardware performance. Actual interrupted
player routes, native OS focus and available monitor/DPR acceptance remain
separate; supported-size software layout is recorded below. The Reedshot's admitted
Unarmed action currently has a readable text fallback without a mapped icon;
no unrelated icon was invented to hide that source-role gap.

### N3/R12 — native Force dome suppression checkpoint

The `force-suppression` recording preserves twelve exact native spool packets: See Invisibility, Force formation, separate-owner Antimagic suppression and native drop-concentration resumption. Existing construction records/shaders/bands now consume the original Force dome exclusions; picking follows the same displaced source mesh. Canonical/no-replayed-formation/delta tests pass alongside the existing Force dome/panel checks and typecheck. No backend, source artwork, native outcome or geometry was edited.

All 24 source views and four provider interaction views pass the unchanged original oracle at four quarters/two zooms. Source mean 0.370–0.749/255, IoU ≥ 99.954%; combined mean 0.092–0.394/255, IoU ≥ 99.994%; isolated 99-byte source-edge differences remain explicit, not byte parity. All 112 hole/surface picks, eight exact resumptions, unchanged frames, context restoration with zero decodes, and disposal pass. Suppression uses six 185×185 outputs and six float selection targets (4,107,000 colour bytes excluding depth/shared donors), thirteen cold passes versus five neutral passes and one warm world pass; this is software resource evidence, not hardware FPS. See the construction-suppression review and `.runtime/reviews/force-suppression/`.

Overlapping providers, partial section cuts and missing safe-side selection remain open. The installed Ice/Stone paired banks already include genuine depth/camera packets; their remaining source-qualified consumer is tracked separately. Full R12/R19 and the global plan remain active.

## N3 — independent floating feedback lifetime

Outcome badges and numeric feedback retain their original clock/contact/style through later native actions without extending the action join. The original `badge_style` now applies to outcome badges; damage/healing uses `number_style`. Six exact native SDK packets prove Counterspell followed by another actual Fireball. The regression failed before implementation and now passes; the final production browser check passes shared DOM identity, Pause, all four rotations, cold-prefix restoration, final Idle expiry and zero views/leases/errors. Screenshot inspected; independent workflow source review passes. Terminal-predicate and full-delivery qualifications are in [feedback-lifetime review](reviews/renderer-2026-10-11/feedback-lifetime.md).

### N3/R12 — joined Force suppression checkpoint

The native `force-panel-suppression` case keeps twelve exact SDK packets, two original adjoining members, their actual Antimagic provider and native resumption. The existing source-point hit selector now constrains each original native member's own progress/height; no duplicated geometry or replacement owner was introduced. All 24 source views, four provider interactions and 128 hole/member picks pass at four quarters/two zooms. Resumption, repeated frames, context restoration/zero decodes and disposal are exact. Source mean 0.159–0.484/255, IoU ≥ 99.446%; combined mean 0.078–0.496/255, IoU ≥ 99.858%; isolated 101-byte edges are qualified without changing the oracle. Three 258×288 output/float-selection pairs use 4,458,240 colour bytes excluding depth/shared donors, seven cold passes, three neutral and one warm. The independent source/ownership review, five focused native tests and typecheck pass.

Partial section cuts and their affected-source dust remain unfinished. A genuine `ice-partial-cut` capture now supplies eight exact native packets: radius 10ft Ice dome creation at 2 and Disintegrate at 7, preserving the object with the actual ten-foot cube at minimum `[5,6]`, base 0. The original bank `_section_mask` supplies cube semantics; its mesh branch lacks the affected-volume composition. The initial regression reported that missing consumer before publishing an incorrect whole-dome fracture; the affected-source consumer and its validation are recorded below. The first level-11 capture correctly lacked another spell slot; that native refusal remains private. The final supported level-13 setup used an actual admitted Disintegrate; no outcome or packet was changed. This establishes the next source-qualified input, not acceptance of partial cuts.

### N3/R14 — native Blur and historical body checkpoint

The focused `blur` case retains twelve exact native SDK packets: Blur, two moves, actual Dimension Door transfer, another move and concentration removal. Current body distortion and two contours now consume the original recipe through native body composition and shared Sprite filters; historical 80/160/240 ms body samples use the same pure pose resolver and bounded 240 ms head history plus predecessor. Real relocation/portal/admission cuts and current/old effective ownership stop invalid trails. No pixels, per-frame worlds, extra actors or duplicate hit ownership are retained.

All 28 native views across four quarters and 112 source outputs pass the unchanged original operators: alpha exact, support 100%, maximum PMA 0.4981 byte and mean ≤ 0.0811/255. Physical highlight alignment, zoom source invariance, rewind/context restoration, warm 1 pass and zero leases/views/errors pass. Mirror q0 source/GPU regression and the four focused Blur/Mirror/actor-dust native tests pass. The case is indexed in Studio; its private capture host is stopped. Source scope and the unexercised native sight-loss/coexisting-condition cases remain explicit in [the Blur review](reviews/renderer-2026-10-11/condition-distortion.md). Absence remains separate; the whole plan is unfinished.

## N4 — supported viewport and UI-size layout

The genuine active Crypt at native sequence 15 passes the 24-state layout matrix:
1280×720 and 1920×1080, each at 75/100/125/150% UI size, with inventory and log
opened independently. Controls remain reachable, resource numbers and frame-time
text remain separate from controls, and panel opening leaves the action bar in
place. UI size preserves the world camera and canvas bounds. At the tightest
1280×720/150% setting, an actual wheel gesture reaches the carried items without
zooming the world. No native command or browser error occurs.

The check reproduced inventory overflow from viewport units being scaled twice,
log text behind the action bar, and paging arrows sharing the resource row. The
existing HUD ResizeObserver now measures bottom-control clearance; panels size
against the scaled containing block. The resource row reserves the existing
22px pager height. A final focused 150% check also protects complete portrait
bounds after narrowing the responsive log limit from 42% to 40%; the other tested
settings retain their 350px logical limit. All relevant screenshots were inspected.
Typecheck and independent HUD/CSS ownership review pass. No world projection,
renderer, UI hierarchy or native authority changed. Evidence is
`.runtime/reviews/live-crypt-layout/`, with the final tight-layout proof in
`scale150-final/`. This is headless software-renderer DPR1 evidence; actual OS
focus, available monitor/DPR and hardware performance remain separate.

### N3/R12 — native Ice partial-cut checkpoint

The actual surviving dome consumes the original ten-foot cube mask on genuine selected mesh samples. A finite track applies the existing silhouette-dust operator only to the affected preceding source; it does not replace the surviving canonical object or replay whole-dome fracture. Four focused native Ice/suppression tests, TypeScript and independent source/ownership review pass. The full four-quarter/two-zoom GPU sweep passes 40 unchanged-original comparisons, eight actual worker scenes and 85 hole/owner picks (69 holes). Two held sides remain alongside finite dust, then survive alone. Repeat/rewind/context restoration are exact, with zero restore decodes, views/leases/hits and browser errors. Mean error is 0.284–0.792/255, IoU ≥99.679%, with isolated 156-byte edges explicitly qualified, not byte parity. Native q0 and the clear q2 aperture were visually inspected.

Seven cold/three advancing/one warm passes reuse the fixed source; at q0/zoom 2 six finite source/dust targets total 5,718,576 colour bytes excluding depth/shared donors and the separate survivor. This is software resource evidence, not hardware performance. [Source and scope review](reviews/renderer-2026-10-11/ice-partial-cut.md) and `.runtime/reviews/ice-partial-cut/` distinguish combining original operators from the old mesh dispatcher, which omitted cuts. Original bank section cuts, rest selection for fracture after a cut, overlapping providers and missing safe-side selection remain unfinished; the global plan remains active.

## N4 — native resource cost labels

The existing conversion inspection check also passes after correcting the shared
cost formatter. It uses the selected native HUD resource labels with the exact
native amounts, so the unavailable level-3 conversion now reads
`1 Bonus · 5 Sorcery Points` rather than an action caption and raw resource key.
Action-bar and inventory/ability details use their existing displayed sheet;
there is no cost recomputation or new content mapping. The actual selection
sends neither preview nor command, and the existing log resize/lock/reopen check
still passes. Typecheck passes; evidence is
`.runtime/reviews/ui-native-conversion-inspection/` at unchanged sequence 7.

## N3/R14 — native Banishment departure and witnessed return

The existing absence recipe now captures the departure pose once, renders its original dissolution and back/front portal, and consumes a separately witnessed native return before resuming living Idle. Canonical absence/visibility remain unchanged; echoes have no shadow, picking or native actor identity. Nine exact native SDK packets preserve a saved cast, actual applied Banishment and native concentration removal. The first implementation's extra portal ×2 conversion was caught visually, removed and protected by a source-scale assertion. Original recipe values and artwork were unchanged.

All 28 production views across four quarters pass, and the unmodified Pygame source operator matches exact alpha/100% support with maximum PMA rounding error 0.4942/255 and mean ≤0.2309/255. Frozen source pose, phase expiry, returned Idle/shadow, zoom source stability, exact rewind/context restoration, zero restore decodes and zero views/leases/errors pass. Corrected screenshots were inspected; the case is indexed in Studio. Focused native regressions and typecheck pass. The subsequent delayed-live-start check also passes: the held Idle source matches the actually displayed contact rather than compile time, remains fixed afterward and reconstructs exactly from a cold worker view. Studio operation/thumbnail inspection passes. [Source ownership and bounded acceptance](reviews/renderer-2026-10-11/condition-absence.md) keep unseen destinations, condition combinations and hardware acceptance separate. The global plan is unfinished.

## N4 — native world dossier gestures and displayed refresh

The actual Crypt support opens through right-click → Inspect without first spending movement. Its dossier shows only received terrain, movement and illumination facts. Wheel and focused-key gestures stay within the panel; Escape dismisses that inspector without opening the application menu. The genuine exhausted Sorcerer could not close the door, so the check used native End Turn and rediscovered the Fighter's admitted Close Door choice. With the Crypt passage dossier pinned, the actual close command updates that same dossier from Open to Closed at displayed sequence 18, retaining 18/18 HP. These are exactly two user commands from initial sequence 15; native operations are not assumed to map one-to-one to commands. No browser errors occurred.

`tests/crypt-routes.browser.mjs` with `INSPECTION=1` and the inspected screenshot are recorded in `.runtime/reviews/live-crypt-inspection/`. No production change was needed for this check. Existing native-record tests cover removed-object clearing and restriction of remembered terrain, but this browser run does not establish those admission-loss transitions or actual OS focus behavior.

### N3/Studio — body-presentation source projection

The existing Studio timeline now exposes native Mirror copies, Blur distortion/contours/historical trails and absence body/portal operations beneath their real body owner. Physical source parts stay folded; decorative bodies are excluded from ordinary Body/material/flash components. Inspection reads the same production samplers, native lifetimes and pinned original recipes. Historical candidates share one row per authored age and previews frame the visible source candidate. Zero-duration native return/removal remains an inspectable point; compiled playback durations are unchanged.

Genuine-recording projection tests, TypeScript and the actual Studio source/thumbnail check pass. Mirror copy, Blur history and absence departure thumbnails/source links/sample context were inspected; clicks preserve playback time and errors are empty. A directly observed long-release label collapse received a narrow facts-grid sizing correction and passed the affected UI rerun. Evidence/review: `agent_docs/reviews/renderer-2026-10-11/condition-distortion.md`, `.runtime/reviews/studio-body-presentations/`. This closes the projection gap for these implemented body operators, not remaining renderer families or the whole port.

## N4 — native interrupted walking through UI and offline Studio

The supported private deployment uses the existing Ashhook and Gloomplate
recipes with their actual handaxes, HP and ordinary opportunity-attack handler.
No grants, forced rolls, patched health or backend changes are involved. The
first genuine reaction missed; that complete successful route remains in the
evidence. Actual End Turn and return-movement controls continued the same epoch.
On the second attempt, the current Shift-normal preview requested
`[4,6] → [4,7] → [4,8] → [4,9] → [4,10] → [4,11]` and disclosed the watcher at
`[4,7] → [4,8]`. The UI submitted that exact selection once. Native 9 Slashing
damage changed Ashhook from 7 to −2 HP/dead: only `[4,7]` committed, the next
step was uncommitted, and the final presented body and blood stayed at `[4,7]`.
The final native terminal appeared after presentation; no team result was
inferred. Both actual UI runs had zero browser errors.

All thirteen SDK packets 0–12 match the unchanged server spool byte-for-byte;
readback sent no commands. The owned host was stopped and the case was added to
Studio's existing index. An initial live diagnostic sampled immutable occurrence
contacts, so that evidence establishes committed positions, not interpolated
motion. The corrected actual Studio probe reads the prepared Sprite's current
registration: 61 samples include 16 interpolated first-step positions and 24
alive samples at the reached cell before damage. No sample enters the uncommitted
step; final contact is `[4,0,7]`, HP −2/dead, and operation 12 commits once. The
single native motion lasts 416.667 ms; reaction/death completes at 2166.667 ms.
The host is stopped, game-host requests and browser errors are zero, and the
final Studio screenshot was inspected. No runtime correction was necessary.

Evidence: `.runtime/reviews/interrupted-route/`, including `first-native-miss/`,
`second-attempt/` and `studio-replay/`; original bytes are in
`.runtime/recordings/interrupted-route/`. This closes this walking interruption
boundary; unexercised jump/flight/connector and admission-loss inspection cases,
actual OS focus, monitor/DPR and hardware acceptance remain distinct.

### N3/R12 — original Ice fracture after a native partial cut

The `ice-cut-fracture` case preserves 37 native packets: dome formation at 2, partial Disintegrate at 7, actual Fire Bolt destruction at 32 with the earlier cube retained. The same 72 original pieces and poses now select removed material in their original rest coordinates. No geometry, physics, outcome or target owner was added. The native missing-consumer regression passed after the correction; four focused Ice/suppression tests and TypeScript pass.

All 24 original-operator samples pass unchanged comparison limits (mean 0.727–1.317/255, IoU ≥99.872%, isolated maximum 157 bytes). The first full reference run had a camera-basis conversion error; the test-only correction subtracts the original map-center rotation offset, leaving the saved production outputs and original operators unchanged. Actual native output was visually inspected. Repeat/context restoration are exact, restoration decodes zero, and views/leases/issues/errors are empty. The existing two targets use 145,204–607,836 colour bytes across these views. Changing frames still take 289 source passes plus world; q0 advancing submit is 2.7–5.1ms with SwiftShader gaps 49.9–66.7ms, an explicit performance qualification. [Source review and detailed evidence](reviews/renderer-2026-10-11/ice-partial-cut.md) records the source-operator composition and measured limits.

The subsequent Stone section-cut slice below consumes its original held bank packets. Bank fracture after a cut still requires its actual rest correspondence. Overlapping suppression providers, missing safe-side source selection and the broader client plan remain unfinished.

## N4 — split-party inspection and native sight-loss transition

The same authored Crypt epoch places the Fighter in the passage and the Sorcerer
in the burial hall. Inspecting the non-turn Sorcerer preserves the exact shared
controlled/observer audience and the single SDK connection; End Turn stays
disabled and Space sends no command. The Fighter then uses the actual admitted
Open Door and Close Door choices. Native displayed sequences 55 → 56 → 57 make
the Vault trap lever visible and then remembered again. Its pinned dossier
clears on sight loss and its Alt label disappears. Right-click inspection of an
actual picked remembered support at [2,5] exposes only Surface: stone and
Knowledge: Remembered terrain, without a movement command or current light or
effect facts. The successful check issues exactly two user commands, records
zero browser errors, and both open-lever and remembered-support screenshots were
inspected. No production change was required.

An earlier harness incorrectly expected a door UUID in the target list; native
door actions are self-target choices whose source item identifies the door.
That run sent six real End Turns before failing. Its resulting native combat
state and evidence were retained; the corrected check continued that same epoch
without reset. A second stale-position assertion sent no commands. Both failures
remain alongside the successful `SPLIT_INSPECTION=1` evidence in
`.runtime/reviews/live-crypt-split-inspection/`. The check validates admitted
shared-party observation, not private per-actor sight or a new audience policy.
Actual OS focus, monitor/DPR, hardware performance and remaining connector/window
workflows remain separate.

## N3 selected body outline — 11 October

The populated Paralyzed `persistent.bodyOutline` now reaches the same composed-body Sprite after displayed scaling, independently of held pose and condition media. Original first-owner selection, witnessed/cold clocks, one-pixel inner edge, five clipped strokes and byte blending are preserved. Source-defined copies/trails retain the outline; shadows and disintegration dust omit it. Native Hold Person sequence 7 and concentration removal sequence 8 establish application/removal; three focused native/Studio tests and typecheck pass. The extended held-pose browser passes all four quarters and 24 unchanged-Pygame comparisons (two scales, three ages), all pixel-exact. Held body pixels stay fixed while the pulse advances, removal resumes Idle, rewind is exact, cleanup is zero and browser errors are empty. The native Studio operation/thumbnail exposes the actual pinned outline recipe without seeking; screenshots were inspected. Independent ECS source/ownership readback passes. See [condition pose/outline review](reviews/renderer-2026-10-11/condition-pose.md). This closes that selected operand, not all condition/appearance consumers: authored transient `appearanceLayers` (Fly/Dragon Wings) remain unconsumed, and native `visual_loadout` only supplies equipment rather than those source additions.

### N4/R16 — remaining native connector source boundary

The existing `battlefield.elevation_proving_ground` supplies five maintained
standalone connectors (`traversal.ladder`, `.rope`, `.lift`, `.vertical_stairs`,
`.passage`). The current client and original authored movement context contain
only the `window` connector profile. Reading the original choreography resolves
that absence: connectors without a specialized profile use ordinary walking
body/duration and the native endpoint elevations. The client early return for any missing connector profile was a concrete
consumer gap, corrected in the native ladder checkpoint below rather than
requiring invented art. Native world-interaction descriptors expose
aperture/frame-backed connectors; standalone connectors instead retain their
endpoint-indexed self-action discovery. Their destination-support UI gesture is exercised by the native ladder
checkpoint below; the other connector kinds remain unexercised. The Lantern Crypt contains no window, and current supported
server encounter configuration provides no arbitrary window/portal placement
hook. Existing native window builder tests therefore do not constitute a
server/SDK gameplay capture. This source check preceded the native ladder capture below; window SDK
acceptance remains open.

## N4 — actual multi-cell Jump UI and living aftermath

The same Crypt Fighter uses the existing Jump control, previews the admitted
clear passage and submits exactly one native selection at sequence 57 → 58.
The native path is [8,6] → [9,6] → [10,6] → [11,6]; all three steps commit and
HP remains 44. The disclosed bonus action changes 1 → 0, movement 30 → 15 ft,
and the action stays 1. Forty live samples include five above-ground body
samples; every airborne sample retains its grounded shadow and spending gate.
The body lands at [11,0,6] and its living Idle source advances while displayed
sequence 58 and the one-command count remain fixed. The final screenshot was
inspected and browser errors are empty.

Evidence is `tests/crypt-routes.browser.mjs` with `JUMP=1`, saved in
`.runtime/reviews/live-crypt-jump/`. No production change or native setup change
was needed. This verifies normal live Jump; lethal interruption of a jump,
flight/connector gestures and hardware performance remain separate.

## N4/R16 — native standalone ladder traversal

The unchanged maintained proving ground and existing Fighter/Gloomplate recipes
produce a real affordable ladder self-action at [1,12] → [2,12], from 0 to 5 ft,
with native movement cost 10. Before correction the actual destination support
could not expose its preview or command: the self row has no target UUID or
position. The existing world picker now matches its disclosed connector
destination to a real picked support and keeps its original self target index,
priority, preview and command. The context reads `Traverse Ladder`, reusing the
existing inspection labels instead of exposing `traversal.ladder`. The original
choreography's ordinary walking profile applies when no specialized connector
profile exists; the client no longer discards that admitted movement. No
connector mesh, animation, native descriptor or rules authority was invented.

The before/after live UI check uses the same unspent native epoch. The successful
context gesture submits index 0 once at sequence 1 → 2, spends movement 30 → 20
ft and preserves action/bonus resources. Its 174 live samples include eleven
interpolated elevation contacts with spending disabled; final contact is
[2,1,12], followed by advancing living Idle at the same displayed sequence. The
final screenshot was inspected, browser errors are empty and typecheck passes.
The focused connector, recorded movement, emitted-tail and inventory tests pass
(all five tests). The exact native compiler regression verifies the original
416.667 ms walking duration, midpoint [1.5,0.5,12], body clip and final native
state. Parent source/ownership review passes.

All three SDK packets 0–2 equal the unchanged server spool bytes. The case is
indexed as `/recordings/native-connectors/case.json`; evidence is
`.runtime/reviews/native-connectors/{before,after}/`, and the private setup is
`.runtime/private/native-connectors/`. This bounded test proves a reachable
native support gesture and body/elevation transfer. It does not add ladder
artwork, accept all five standalone connector types, supply a window placement
scenario, or establish hardware performance.

## N3/R12 — native Stone bank section cut

The authentic `stone-partial-cut` case contains eight unchanged SDK packets: one 20 ft Stone panel is formed at sequence 2 and the native cube is removed by Disintegrate at 7, leaving the same object and resulting placement. The existing section consumer now selects held source pixels from the delivered depth packets and native cube. Affected source pixels use the original finite silhouette dust; surviving bands and original hit nodes retain the native identity. Cold acquisition, event dates, canonical reduction and source art remain unchanged. Moving banks after an earlier cut still require actual rest correspondence.

The native regression and TypeScript check pass. Four quarters × two zooms cover 40 source views plus eight native operation views; all 96 hole/survivor picks pass. Repeat, rewind and restored output are exact; restoration decodes, retained views/leases/hits and browser errors are zero. All 64 independent original-packet section selections match exactly. The 24 nonempty original-dust comparisons have mean 0.00335–0.18834/255 and IoU ≥99.9915%, with an isolated particle alpha difference of 202 bytes explicitly retained as a numerical qualification. No oracle tolerance changed. Actual cut/completed screenshots were inspected. [Stone section review](reviews/renderer-2026-10-11/stone-partial-cut.md) records provenance, ownership, tests and remaining limits; this does not close the broader construction or client plan.
