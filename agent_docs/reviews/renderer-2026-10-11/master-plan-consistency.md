# Complete-plan consistency review — 11 October 2026

Scope: read every section of the [complete client plan](../../NDCLIENT_IMPLEMENTATION_PLAN_COMPLETE_2026-10-11_v3.md) against the reviewed [renderer v3 chapter](../../NDCLIENT_PIXI_RENDERER_PLAN_2026-10-11_v3.md), user decisions and current source owners. Correct conflicting instructions directly; retain the full N0–N5 and R01–R23 feature scope. This review changes documentation only.

## Coverage

| Independent review | Full reading and additional checks |
| --- | --- |
| Anti-OOP/ECS and ownership | Complete master introduction and §§0–5.7; entire renderer chapter. Checked package, serving, assembly/loading, worker and progress evidence before correcting stale baseline claims. |
| Anti-slop/rendering | Complete master §6 and §13; entire renderer chapter and code audit. Cross-reference scan and surrounding paragraphs across the remaining master for material/scale/sampling/depth/picking/status prescriptions; source checks of native composition, sampling and resource ownership. |
| Workflow/Studio/camera | Complete master §§7–12 and §§14–16; entire renderer chapter. Checked README, progress, release paths and recovery entry pointer. |
| Primary agent | Reconciled findings, corrected active prose and execution order, preserved archived evidence, reviewed the document changes and checked links/coverage identifiers. |

## Corrections

| Location | Contradiction removed / retained requirement |
| --- | --- |
| Header, §1.2, §§5.1/5.4/5.7 | Existing Vite/SDK/types/release loading/UI were described as absent or the next fresh scaffold. Identify existing owners and incomplete behavior accurately; regenerate only when relevant source schemas change. |
| Header and §10 | “After this review resume” was a turn-trigger in a durable plan, while the later work order restarted N0. One order now applies: renderer v3 in current owners, then remaining N0–N5 work. No new stop/approval gate. |
| §4.7 and §7.6 | A universal resource hold could freeze camera rotation. Operation-resource waits retain their causal hold; camera-only requests keep the current quarter advancing and publish the replacement at the current playhead. |
| §7.6, §9.2, §11.3, P06 | “Camera changes never decode” hid legitimate cold-quarter work. Pan/zoom reuse sources; missing quarter sources prepare separately. Bounded adjacent fetch/decode/upload uses existing leases and foreground priority. |
| §5.3, §6 material order, R06 | “Material instead of palette/tint” conflated three operations. Preserve exact swap, tint and selected material independently, including legacy automatic-material override semantics and nonlinear whole-body/gear composite stages. Hand magic remains effect-owned. |
| §6 stairs | Removed a reference to deleted contact-chain visibility continuation. Source contacts still register the art; delivered geometry supports actual lighting/spell consumers. |
| §6 blood, §11.1, R18 | Generic face geometry and “64 texels only a suggestion” could recreate floor-skirt streaks or alter original appearance. Keep the demonstrated 64×64 blood source grid and floor plane; retain only existing declared non-floor behavior. |
| §8.3 | Explicit full composed Body, collapsed body parts, visible subordinate effects and material below its affected owner; front/back media is one group. Static clothing tint is baseline, not a timed operation. |
| §8.3 | Complete recording tracks before Play, bounded shared-source previews, frame/sample counts, stable row/selection/scroll on expansion/resize/rotation. Authored markers stay in source frames; seconds are the resolved ruler. |
| §11.2 | Added camera races/operation-boundary/preload checks and admitted lethal-event continuation. Canonical visibility and target eligibility stay native; separate future dead-sight proposal stays approval-gated. |
| §12 | Removed 190 duplicated lines of old implementation status, including peeling/GPU-picker acceptance and an obsolete material blocker. The exact text already exists in archived v2. Current progress/audit own evidence and remaining gaps. |
| §15 | Removed duplicated historical review narratives and stale “engine master/NDClient copy” claims; archive retains them. Current review responsibilities and evidence remain. |
| §7.2 | Corrected release output to `.runtime/presentation/releases/<revision>/`, matching assembler and serving code. |
| Progress document | Marked former feedback pauses as historical; qualified the remaining ordinary Mesh and old camera-invalidation behavior as current repair work, not instructions to preserve it. |
| Engine `RECOVERY_PLAN.md` | Corrected its single plan link from historical engine v2 to the active NDClient master. No plan copy was synchronized and no engine/server/SDK implementation changed. |

## Review and limits

All three reviewers passed the correction readback in their stated scopes. The workflow review caught one remaining “resume after this review” clause in §14; it was replaced with the active task scope and §10 execution order, then passed a final readback. No further substantive contradiction was identified in these reviews. Current source/visual defects remain those in the code audit; documentation cleanup does not implement or visually accept them.

Historical versions remain archived. The active complete plan and renderer chapter stay at their existing v3 paths; this review creates no competing execution plan. Diagnostics do not expand the backend, artwork or renderer architecture scope. No runtime tests are claimed for this documentation change.

## Later renderer-first checkpoint readback

After the user challenged premature N3/N4 progression, the workflow reviewer reread renderer §§3–11 and the revised execution checkpoints. The master §10, renderer §10 and progress top now agree: finish renderer v3 and verify one production drawing path, then resume the complete N0–N5 scope. Partial consumers stay preserved and unverified. This correction passes plan-adherence review; it does not itself establish renderer acceptance. The accompanying renderer-step-7 test work and measured limitations are recorded in the progress document's camera/Studio acceptance entry. The earlier documentation-only review above remains historical.
