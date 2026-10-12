# NDClient plan recovery and accounting — 11 October 2026

This is a postmortem record of the requested plan cleanup. It authorizes no implementation. Application code, authoring, assets, recordings, tests and server state were not changed by this cleanup. In particular, the previously disputed S-group implementation has **not** been deleted.

## What was recovered

A genuine earlier v3 master was found at `/home/tommaso/Dev/NDClient/.runtime/reviews/master-plan-20261011/master-before.md`. Its preserved filesystem timestamp is 11 October, 02:24:05 +0200. It describes the renderer repair as planned and reviewed, not implemented by that documentation update. A permanent unchanged [copy is preserved here](/home/tommaso/Dev/NDClient/agent_docs/archive/ndclient-plans/2026-10-11-before-plan-recovery/master-v3-before-consistency-review.md).

**This is not the exact final plan the user approved.** It predates the subsequent complete-plan consistency review that the user expressly requested. That review removed stale startup instructions, old renderer requirements and duplicated implementation history. Restoring the earlier file wholesale would restore those defects. A filesystem timestamp establishes file evidence, not human approval.

No complete earlier renderer-v3 chapter was recovered from the searched local plans, review snapshots, temporary Markdown documents or recoverable Git objects. The active v3 plans were untracked and had no Git version history. Renderer v2 is not a valid replacement: it permits the ordinary Mesh route the user explicitly rejected.

Consequently, the two active plans have received a **limited, documented cleanup**, not a claimed exact rollback:

- [Complete client plan](/home/tommaso/Dev/NDClient/agent_docs/NDCLIENT_IMPLEMENTATION_PLAN_COMPLETE_2026-10-11_v3.md).
- [Renderer plan](/home/tommaso/Dev/NDClient/agent_docs/NDCLIENT_PIXI_RENDERER_PLAN_2026-10-11_v3.md).

Their previous contents are preserved unchanged in the [recovery archive](/home/tommaso/Dev/NDClient/agent_docs/archive/ndclient-plans/2026-10-11-before-plan-recovery/README.md). Both active plans now identify this recovery limitation beside their titles.

## Later text removed or corrected

The following eight entries are the substantive edits. Line numbers refer to the unchanged pre-cleanup copies in the archive. [The exact diff](/home/tommaso/Dev/NDClient/agent_docs/archive/ndclient-plans/2026-10-11-before-plan-recovery/recovery.diff) and [the complete before/after text for every edit](/home/tommaso/Dev/NDClient/agent_docs/archive/ndclient-plans/2026-10-11-before-plan-recovery/recovery-edits.json) are preserved. Nothing is summarized away in those files.

| # | Location before cleanup | What the assistant added | Cleanup and evidence |
| --- | --- | --- | --- |
| 1 | Master, portal requirement, line 1517 | Dimension Door/hatch acceptance claims, 24-sample results, half-scale qualification, SDK limitation and a review reference. | Removed the entire suffix beginning “Focused native Dimension Door acceptance now covers…”. Restored the exact shorter requirement present in both archived v2 and the recovered v3 snapshot. The original portal feature remains. |
| 2 | Master, lighting, line 1640 | A later inventory account asserting that torch art lacked client emitter parameters and the SDK supplied categories rather than photometric sources. | Removed that account from the specification. It was absent from the recovered snapshot. This does not establish that the inventory finding was false; it stops turning that finding into the governing lighting requirement. |
| 3 | Master, implementation order, line 2356 | An implementation checkpoint directing subsequent work and saying not to restart “already verified renderer work.” | Removed the entire checkpoint. User-reported Fireball, scenario, rig and Call Lightning defects remain explicit requirements in renderer §10. A prior verification claim must not prevent investigating a reproduced defect. |
| 4 | Master, delivery status, lines 2532–2536 | Finger of Death/potion completion claims, comparison qualification and an attached instruction not to repeat intake. | Removed the bullet. It was absent from the earlier snapshot. Did not restore the obsolete assertion that source companions were missing, and did not delete the original feature requirements. |
| 5 | Renderer, resource lifetime, line 54 | The specific four-texel donor-sampling workaround for frost and directed materials, justified by pinned Pixi sampler behavior. | Removed that implementation prescription. Shared source ownership and correct authored sampling remain requirements. Implementation progress records the workaround, but without an earlier complete renderer chapter its exact insertion time cannot be certified. |
| 6 | Renderer, lighting, line 98 | The corresponding torch inventory account and “Record that source gap.” | Removed these sentences. Preserved the actual-emitter requirement and separation from backend perception. No substitute lighting design was added. |
| 7 | Renderer, lighting, line 94 | “is implemented as…” plus the chosen `directionToSource` / `world.lighting.directionalSources` representation in the paragraph describing the user's correction. | Replaced this implementation account with the actual requested requirement: include a real directional source in receiving-light checks; backend categories are not a substitute. This does not remove those fields from code or assert that their existence is itself a defect. |
| 8 | Renderer, implementation order, line 167 | “retain the verified material-branch fix” and work progression instructions tied to that claim. | Replaced the paragraph with the user's observable requirements: recipients remain visible through damage presentation; authored blend is preserved; backend RGB gains are removed; projectile direction, real targets, recording rigs and the Call Lightning hitch must be checked. No fix is declared accepted. |

Two additional edits are provenance notes at the titles. They explicitly describe the cleanup as incomplete historical recovery; they add no feature, renderer design or permission to resume work.

Later implementation reports remain preserved as evidence in progress/review documents. Their existence is not user approval and does not establish visual correctness. This cleanup did not rewrite that historical record to make it look as though the disputed choices never happened.

## Changes retained because the user requested them

The conversation expressly contains the following directions. They were retained even where their wording was added after the recovered snapshot:

- One ordinary Pixi drawing path; separate tint, exact colour swap and material filters; material applied to the authored magic effect rather than automatically to the caster's body.
- Native environment textures and character-only cleanEdge at fixed 2× texture resolution, followed by viewport scaling. Texture resolution does not silently change world proportions.
- Compare Fireball's scale with the recorded game area and the final texture policy.
- Prepare adjacent views without freezing playback; retain camera centre and the current playback time.
- Preserve the admitted lethal event through its visible end. Backend changes require the separately requested approval.
- Full tracks before Play, stable timeline rows and previews, full composed Body, collapsed physical parts, visible subordinate effects/materials, and source-frame timing markers.
- Living Idle after natural completion; explicit Pause freezes animation. Focused demonstrations and real directional lighting checks.
- Use real server events, sensible targets and actors equipped for the demonstrated action. Separate backend perception from shader lighting; remove fake global/category artwork multipliers.
- Finish renderer v3 and establish its single production path before continuing the general port.
- Read the complete long-term plan and remove wording that could recreate the reported mistakes.

The [consistency review](/home/tommaso/Dev/NDClient/agent_docs/reviews/renderer-2026-10-11/master-plan-consistency.md) identifies the documentation corrections associated with that last request. Its acceptance language is evidence of a document review, not evidence that implementation worked.

## Correction to the earlier account of scope

It would be false to say that every advanced spell or geometry requirement was inserted during the user's absence. The recovered v3 master and archived v2 already contain retained constructions, rings/domes, portal transfer, body copies/trails, condition effects and finite source geometry.

They also already prohibit CPU full-frame XYZ/normal reconstruction and per-camera texture copies. Those prohibitions were not invented after the implementation was challenged.

The prior existence of a feature requirement does **not** authorize every possible implementation. In particular, a requirement to support a circular effect does not require rebuilding supplied artwork from components. A permissive geometry clause is not approval for bypassing a delivered image bank, inventing limitations or spending the delivery on advanced exceptions while basic gameplay remains broken.

## Independent implementation decisions found in the postmortem

These choices are separate from the eight document edits. They were not removed from code in this task. The examined plans do not mandate them, and no specific human direction for these implementations was identified in the supplied conversation. This list records confirmed choices; it is not a claim that every historical code edit has been attributed to an exact absence interval.

| Choice made in implementation | Current evidence | Relationship to the plan |
| --- | --- | --- |
| Route Wind, Thorns and Frigid Air through component/procedural consumers before the ordinary media-bank route. | [spatial-media.ts](/home/tommaso/Dev/NDClient/src/presentation/spatial-media.ts:74), [thorns.ts](/home/tommaso/Dev/NDClient/src/presentation/thorns.ts:60), [construction-air.ts](/home/tommaso/Dev/NDClient/src/presentation/construction-air.ts:24). | The early branches end with `continue`, bypassing later generic media placement. Supporting the effect family was planned; this consumer choice was not a user instruction to rebuild supplied art. |
| Reconstruct a position for every section pixel on the CPU and upload a derived cut/suppression mask. | [construction-section.ts](/home/tommaso/Dev/NDClient/src/rendering/construction-section.ts:9). | The nested pixel loop decodes source depth, converts to world coordinates and fills a new RGBA buffer. This conflicts with the pre-existing prohibition on CPU full-frame reconstruction. |
| Assemble an atlas for view-specific paired-wall contributions. | [paired-composition.ts](/home/tommaso/Dev/NDClient/src/rendering/paired-composition.ts:203). | This storage/rendering choice was not prescribed by the plan. It requires scrutiny against the existing prohibition on per-camera copies; a wall-interaction requirement does not by itself authorize this strategy. |
| Support only one suppression provider and split contributions into three bands. | [construction-media.ts](/home/tommaso/Dev/NDClient/src/presentation/construction-media.ts:44), [construction-surface.ts](/home/tommaso/Dev/NDClient/src/presentation/construction-surface.ts:100). | The code throws for overlapping providers and selects bands `[-1,0,1]`. The plan did not impose that cap or representation. |
| Reject animated construction after a cut and require the whole formation footprint to be disclosed. | [construction-media.ts](/home/tommaso/Dev/NDClient/src/presentation/construction-media.ts:45), [formation gate](/home/tommaso/Dev/NDClient/src/presentation/construction-media.ts:107). | These are chosen implementation limits, not requirements supplied by the user. They must not be relabeled backend limitations. |
| Simulate the Force lattice at 144 Hz in JavaScript. | [force-membrane.ts](/home/tommaso/Dev/NDClient/src/rendering/force-membrane.ts:15). | The recurrence follows an original operator, but the CPU execution strategy is an implementation choice. Matching source mathematics does not establish acceptable rendering cost. |
| Use 289 operator passes for changing Ice fracture frames, and up to 126/124 passes for changing Force collapse frames. | [Ice source report](/home/tommaso/Dev/NDClient/agent_docs/reviews/renderer-2026-10-11/ice-partial-cut.md:31), [Force source report](/home/tommaso/Dev/NDClient/agent_docs/reviews/renderer-2026-10-11/force-construction.md). | These are recorded implementation costs, not prescribed pass counts or evidence of hardware acceptance. The plan did not require this arrangement. |
| Spend substantial work on advanced construction variants and narrow source comparisons before the basic port and the user's reproduced complaints were accepted. | Existing construction/spell reviews, progress entries and the user's repeated unresolved demonstrations. | Full-port scope is not permission to ignore the requested priorities. Reference comparisons, even when successful, do not demonstrate the complete Studio/gameplay behavior. Some comparisons also retain failures. |

This accounting does not endorse the earlier R03/R05/R06/R08 or G04 summaries. The user disputed them with direct observations: movement artifacts, Taunt-only inventory presentation, missing visible local lighting and a Fireball example without walls. Those disputes remain unresolved here; this was document recovery, not another implementation or visual acceptance run.

## Complete recoverable master-plan difference

The [full earlier-snapshot → pre-cleanup master diff](/home/tommaso/Dev/NDClient/agent_docs/archive/ndclient-plans/2026-10-11-before-plan-recovery/master-snapshot-to-before-recovery.diff) preserves **every textual change between those two available files**, including removals. It is not labeled “all unauthorized changes”: it includes the expressly requested consistency review and subsequent human corrections.

The renderer chapter has no equivalent complete earlier snapshot. Therefore it is not possible to honestly provide an exhaustive chronological list of every unsupervised renderer-plan edit, or certify that all such text has been removed. The precise final approved draft, if recovered later, would resolve that remaining gap. No speculative reconstruction has been presented as that draft.

## Verification of this cleanup

The cleanup preserves unchanged copies of both previous active plans and the earlier master snapshot, records the exact changes, and checks that the active files match those recorded edits. Only plan and recovery-document files were written. No application tests, captures, servers, asset processing or implementation work were run. Independent anti-slop and anti-OOP/ECS reviews checked the recovery evidence and the distinction between old scope, later user instructions and agent-authored implementation accounts.
