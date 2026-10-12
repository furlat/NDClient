# Frozen condition body pose

The existing `frozenPose` recipe now controls the physical body and its attached
condition media in the shared gameplay/Studio actor sampler. Paralyzed holds the
authored modular `Idle` frame 3; native removal resumes living Idle. World contact,
current equipment, damage flash and material ownership remain current. Death keeps
its existing final-body rule. No alternate renderer or actor state machine was added.

The implementation follows the original `condition_body_pose` and
`register_condition_lifetimes` functions: exact rig-qualified `condition_hold`
context, authored frame fallback, one capture immediately before application when
`captureCurrent` is requested, and retained capture for overlapping owners. A cold
snapshot with no known application does not invent or repeatedly recapture a pose.
The independent renderer review found no concrete source mismatch.

## Native evidence

`.runtime/recordings/held-pose/case.json` contains nine original SDK packets,
compared with their server spool frames. The first actual Hold Person cast saves;
the second applies Paralyzed at sequence 7. The discovered native
`action.drop_concentration` removes it at sequence 8. No save, condition, event or
HP outcome was edited. The setup uses original generic modular characters and the
supported original open-floor battlefield.

`tests/condition-pose.test.ts` failed before the change because the held frame was
absent. Both condition checks now pass, including four camera quarters, native
removal, prefix replay and the lower-level body-sample/contact boundary. Actor dust
and Mirror Image regressions pass with it; typecheck passes.

`tests/condition-pose.browser.mjs` passes four views with an explicit directional
light source. Advancing 2400 ms leaves all held body pixels unchanged and keeps
source frame 3. After the real removal, Idle changes the body pixels in all four
views. Cleanup returns views and leases to zero; browser errors are empty.
Evidence is in `.runtime/reviews/condition-pose/evidence.json`; q0/q3 screenshots
were inspected.

## Qualification

Petrified's `captureCurrent` has source review and a focused body-sample check,
not a captured live Petrified application. That native lifecycle remains
unaccepted. This checkpoint does not complete all condition consumers or N3.

## Authored Paralyzed body outline

The subsequent source-to-consumer scan found that the populated `persistent.bodyOutline`
operand was not consumed. The effective selected native owner now supplies that
outline independently of its held pose and attached media. Its original one-pixel
inner edge and five clipped angular pulse strokes run on the final composed Sprite
after displayed scaling. They retain the original byte blit, colour, threshold,
opacity, onset and period. This adds no body target, mesh, hit region or actor state.

`game_obsolete/condition_draw.py::condition_body_outline` and
`condition_media_lifetime.py::sample_condition_lifetimes` define the appearance
and age. A witnessed application uses the existing rebased presentation date;
cold membership pulses on the displayed clock without inventing an onset. Native
removal or suppression removes the selected contribution. Original Mirror copies,
Blur contours/trails and frozen absence bodies retain the outline at their existing
body sample clock; original shadows and disintegration dust exclude it. The bounded
paired interval observes the existing output content revision when only the outline
changes. Physical picking remains unchanged. Independent ECS/source readback passed.

The extended native `condition-pose` test covers the real sequence 7 application,
sequence 8 removal, cold membership, delayed start and shadow exclusion. The existing
Studio projection test exposes one separate outline operation and its actual pinned
recipe; the real Studio thumbnail/inspector check passes without moving playback.
Typecheck and both focused test files pass.

The extended `condition-pose.browser.mjs` produces 24 source samples (four quarters,
two displayed scales, onset/peak/quiet ages). `condition-outline-reference.py` invokes
the unchanged original Pygame function on those same displayed body pixels: all
24 outputs match exactly, including alpha and support. The actual native scene
keeps its frame 3 body pixel-identical while the outline pulse changes in every
quarter; removal resumes Idle, rewind is exact, and disposal leaves zero leases or
prepared views. Browser errors are empty. Evidence and reference outputs are in
`.runtime/reviews/condition-pose/`; q0 and the Studio outline screenshot were inspected.
The native cast and source-pixel oracle are separate evidence: synthetic coexistence
of Paralyzed with Mirror/Blur/absence has not been claimed as recorded gameplay.
