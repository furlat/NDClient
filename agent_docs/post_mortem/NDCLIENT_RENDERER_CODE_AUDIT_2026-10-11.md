# NDClient renderer and presentation audit — 11 October 2026

This is evidence for [renderer repair plan v3](NDCLIENT_PIXI_RENDERER_PLAN_2026-10-11_v3.md). The audit and plan update change documentation only. Product code, authoring, artwork and backend were not changed by this audit. Existing uncommitted work was preserved.

## Coverage and method

The source inventory has 125 files: 21 rendering, 56 handwritten presentation, 13 generated authored/contracts, 17 app, 7 Studio, 5 session and 6 player files. The three independent audit assignments cover every handwritten runtime source file; the generated boundary was checked against schema/type generation. Static import traversal from the app, Studio and worker roots found no unreachable handwritten module or local runtime import cycle. This is reachability evidence, not proof that every branch is correct.

The root also inspected entry points, package/Vite configuration, the 29-file tool inventory, authoring assembly/type generation, current plans and README; inventoried 49 test files and 13 schemas; and checked selected authored operands. One-time copy/import tools are distinguished from application runtime and were not rerun. Source/library files were not exhaustively pixel-compared, and every authored spell was not visually executed.

Detailed evidence and file ownership:

- [All 21 rendering modules; anti-slop review](reviews/renderer-2026-10-11/rendering.md).
- [Presentation, colour data, unfinished consumers and independent blood comparison](reviews/renderer-2026-10-11/presentation-and-blood.md).
- [All 35 app/Studio/session/player files; camera and death visibility](reviews/renderer-2026-10-11/camera-visibility.md).
- [Fireball proof comparison, gameplay area and media scale audit](reviews/renderer-2026-10-11/fireball-scale.md).
- [Earlier Pygame/NeuroClient/Unity and pixel-art reference comparison](NDCLIENT_PIXEL_RENDERING_REFERENCE_REVIEW_2026-10-11.md).

The local `.runtime/reviews/renderer-audit-20261011/` directory retains the file/import inventory, tool inventory and blood diagnostic images. Detailed reports give source paths and line numbers at audit time. Pygame functions were executed unchanged as a reference; temporary browser interception was confined to diagnostic pages, not production files.

## Findings and disposition

| Finding | Evidence status | Planned disposition |
| --- | --- | --- |
| Ordinary Sprite still owns hidden universal Mesh; `usesMaterial` selects a second ordinary route | Confirmed source structure, cost not individually benchmarked | v3 §§3–5 remove the route after actual consumers migrate. Retain real geometry effects. |
| Native environment colour reduced to half dimensions with averaging | Confirmed source transformation | v3 §3 restores native source; no cleanEdge on environment. |
| “Swap” uses tolerance and neighbour replacement | Confirmed shader behavior | v3 §4 exact original-colour matching, separate authored material semantics. |
| Nonwhite tint differs between Sprite and Mesh | Earlier browser pixel comparison measured up to 4/255 on body, 8/255 on chest | One tint operation with defined encoded-colour multiplication; preserve alpha. |
| 35 authored media definitions have `paletteSwap`, runtime reader missing | Confirmed source/data path; storage may already contain a transformed image | Trace storage before connecting exact swap; never double-apply baked treatment. |
| Ordinary dropped items lose `part.tint` when no `itemMaterial` exists | Confirmed consumer defect | Preserve tint independently from optional modifier material. |
| `RigLayer.material` copied but unconsumed | Confirmed capability gap; no current non-null catalog assignment found | Connect effect-owned material and existing spell material inheritance, without asserting nonexistent authored data was lost. |
| Q/E publishes previous operation before reseeking and can run stale continuations | Confirmed source flow | Atomic current-view update, desired quarter and existing generation validity. |
| Camera invalidates whole-recording trace, rows and thumbnails | Confirmed source flow | Preserve semantic timeline/selection and update view-dependent previews only. Existing resize fixes remain. |
| Adjacent-view preparation needs foreground priority | `preloadSceneImages` fans out requests; `ResourceStore` already deduplicates and decodes in a worker; pinned Pixi `PrepareBase` queues incremental uploads but provides no foreground priority | User-requested q±1 source preloading includes fetch/decode/upload, feeds bounded work through existing owners, and yields to current playback. Verify frame time instead of assuming async work is free. |
| Fireball removes visual contact before its explosion/falls finish | Actual delivered packet + production-compiler timing | Client causal display retention; separate backend proposal only for future native sight. |
| Fireball's migrated paired impact receives another legacy ×2 size conversion | Actual production compile emits scale 2 despite authored scale 1 and explicit bank host calibration; original lighting proof uses scale 1 | v3 §3.4 corrects the proven unit mismatch, audits other producers without blanket resizing, and checks the burst against recorded 20-foot-radius ground area under the final texture policy. |
| Blood streaks come from floor geometry's vertical skirts | Reproduced independent Pygame/current/geometry-bypass comparison | Plane-only floor deposits, original source-grid appearance; preserve native quantities/templates. |
| Dead mask/support bindings and legacy depth uniforms remain | Confirmed unused GPU consumers | Delete with retired route; preserve used CPU support and authored metadata. |
| Unconditional material work buffers and sampler mutation | Allocations/mutation confirmed; precise impact not measured | Allocate only applicable buffers; isolate sampler state within existing ownership. No cache framework. |
| Other authored consumers incomplete | Source mapping in presentation report | Remain explicit full-port work; not silently completed or pulled into backend repair. |

The ordinary Sprite atlas-frame notification bug was corrected before this audit; the source-animation regression check exists. Divider resizing and scrolling already preserve preview DOM/texture identity. The renderer has resource leases, decoded-source reuse, a floor cache and warm zoom reuse; **“zero caching” is not the diagnosis**. The audit does not claim to have measured the reported 99% RTX utilization.

## Blood: concrete result

The same actual settled deposits from `anchored-spells` operation 26 were rendered with unmodified Pygame functions and NDClient. Pygame draws compact floor puddles. NDClient reconstructs positions from the floor image's geometry, including its vertical skirt: multiple pixels at different heights address almost the same ground position, repeating a blood sample downward.

Disabling only that receiver geometry removes the long streaks. Restoring Pygame's 64×64 source grid and source-pixel-centre appearance evaluation improves silhouette agreement further. Across four quarters, the original alpha-mask overlap was about 54–57%; geometry bypass reaches about 80.5%; combined diagnostic corrections reach **98.78%**. This is strong causal evidence, **not an implemented fix or exact final-colour parity**. Repeated motifs themselves also exist in Pygame because equal native deposits select the same template; randomizing them would change authored behavior.

![Pygame, current NDClient, and geometry-only diagnostic](/home/tommaso/Dev/NDClient/.runtime/reviews/renderer-audit-20261011/ndclient-blood-cause-comparison.png)

`tests/particles.test.ts` currently asserts reuse of the whole floor image/registration. That assertion enforces the faulty receiver choice; replace it with actual plane/footprint behavior while retaining native quantity, timing, landing and airborne endpoint checks.

## Other incomplete consumers remain visible

The presentation report records existing gaps in action-variant/projectile consumers, equipment-transition media, `attack.actor.media`, trails/interception, movement recovery, healing body/media, some attachment and recipient/wall/spatial operands, and Finger of Death's omitted companion files. It identifies supported authoring, actual call sites and unused operands. These stay in the general plan's existing feature scope and progress inventory. They do not justify changing native rules, adding art aliases or calling the port complete.

Small maintenance findings include a generated type banner naming `types:authoring` instead of the actual `authoring:types` command, and README's preparation-only status despite the existing app. README is corrected in this documentation update; change the generator banner when its relevant owner is next touched. No runtime work is blocked by that banner.

## Verification and limits

- Root baseline: `npm test` — **33 tests passed**; `npm run typecheck` passed. This is the pre-implementation baseline.
- Dedicated blood diagnostic: unchanged Pygame functions, real recorded inputs, production NDClient browser render and targeted diagnostic ablations; four-view silhouette comparison. Final colour difference remains to close during implementation.
- Death diagnostic: actual Fireball operation compiled with production reducers/actor contacts/timing. Sight loss ~1.311s; explosion end ~3.227s; falls end ~3.561s. Caster alive at HP 56. No missing killing-event packet demonstrated.
- Scale diagnostic: actual production Fireball compile, independent accepted-proof crop comparison, engine/recorded 20-foot-radius ground area, and all 46 installed near/far geometry/appearance frames measured at supplied scale 1. Smoke/card/proxy extent is not the damage boundary. No final burst-versus-area visual acceptance is claimed; it belongs to the final texture-policy check.
- No complete new browser regression suite, gameplay feature sweep, hardware GPU profile or runtime-fix acceptance was performed by this planning audit. Earlier browser results are explicitly labelled as earlier evidence in the detailed report.

## Plan review

All three independent reviews **passed after corrections**, followed by targeted rendering and camera approval of the user's adjacent-view preload addition.

| Review | Corrections incorporated before final pass |
| --- | --- |
| Anti-slop/rendering | Preserve modular slot order with Magic2 between physical parts; retain fixed-creature combined/shadow algebra; permit explicit native/cleanEdge targets in the master; combine steps 2–3's ordinary Mesh removal gate. |
| Anti-OOP/ECS, presentation and blood | Full composed Body preview includes attached effects; source parts remain folded. Compare blood source colour/alpha under neutral light, then new linear lighting independently. Reject the old receiver-identity test; retain useful quantity/timing checks. Remove stale execution-version references. |
| Camera/visibility | Keep the old view sampling during preparation, use current playhead at publication, guard with session generation and request ticket, cover operation boundaries/seek/reload/case changes. Canonical contact loss and target legality remain authoritative. DEAD-only backend proposal stays separately approval-gated. |
| Adjacent-view addition | Existing source/lease/upload ownership; q±1 admitted-content dependencies only; foreground priority and frame-time acceptance; safe in-flight lease retirement. Optional additional view preparation only for a measured residual hitch. |
| Fireball/scale addition — anti-slop and anti-OOP/ECS | Trace every media producer; distinguish proven Fireball duplicate conversion from inherited scales in other paired banks. Use actual `resolved_area_positions` and four-step ground radius. Validate the main burst under the final texture policy; do not equate smoke/light range with damage reach or claim all paired effects must be halved. |

These verdicts approve the plan's scope, ownership and acceptance design. They do not assert that its runtime fixes have been implemented, its screenshots accepted, or hardware performance validated.

## Implementation follow-up — single production path

The entries above retain the pre-implementation audit. The renderer-first implementation scan now finds one app frame loop and one `createSceneRenderer` entry shared by gameplay and Studio. Both production HTML entries build to the same main module. Timeline previews create display views through `createSceneView` and use that renderer and resource owner; they do not instantiate another renderer.

`composition.ts` prepares ordinary images as Texture/Sprite plus applicable source-colour, lighting and coverage filters. Its Mesh allocation predicate is limited to actual orbit, directed, arc and particle geometry. Character composition and paired radiance use bounded derived targets with ordinary Sprite outputs. `usesMaterial` and the universal `surface-shaders` fallback are absent. GPU residue generation and specialized geometry remain intentional effect consumers, not an ordinary-image alternative.

The independent original-character review's Mesh factory was still defined in a module imported by production for its GLSL equations. That factory and its setters now live only in `tools/character-review/material-reference.mjs`; `src/rendering/character-material.mjs` exports equations only. The tool retains its independent source comparison. Production source and the built output contain no reference to the review factory or former ordinary-route selector.

The intermediate combined build and typecheck pass; all 43 Node tests pass, including the real Ice Storm worker-delta regression. The existing GPU colour/body tests additionally assert that ordinary inputs allocate zero Meshes and composed characters produce Sprite outputs. Their combined run and remaining context/camera/wall acceptance are recorded in implementation progress rather than inferred from this static scan.
