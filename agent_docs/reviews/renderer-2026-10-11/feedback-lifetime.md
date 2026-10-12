# Independent floating feedback lifetime

## Behavior and evidence

Damage/healing numbers and outcome badges now retain their original start, contact and authored duration after the physical action finishes. Native commits and the next action do not wait for decorative text. The same displayed clock governs playback, Pause, replay, camera rotation and final Idle. Studio displays the continuing contribution across the action boundary.

`game_obsolete/feedback.py` is the reference. Outcome badges use `badge_style`; numeric damage/healing uses `number_style`. No second clock, feedback queue, renderer or native-state mutation was added. Semantic label identity preserves the DOM span across worker clones and operation changes. The terminal panel waits for pending feedback without changing command authority.

The actual Counterspell case preserves six unmodified SDK packets. Its countered Fireball completes at 1454.9305759154413 ms; another native Fireball begins while “Counterspelled” remains visible. The original badge uses 1400 ms, 16 px text and fadeFrom .7. The earlier duration assertion failed before the implementation. The final pure test passes original-style selection, native state equality, independent expiry and actual-start rebasing.

The production browser check passes the next-cast boundary, the same label DOM element, explicit Pause, all four camera quarters, prefix reconstruction at the same clock, final Idle expiry, zero retained views/leases and no browser errors. The final screenshot was inspected. Numeric placement separately passes four quarters with seven concurrent actual Fireball labels. Independent workflow source review found no blocker.

Evidence: `.runtime/reviews/feedback-lifetime/{evidence.json,following-cast.png}`, `feedback-lifetime-before.log`, `feedback-lifetime-after.log`, `feedback-lifetime-browser.log`, `feedback-layout-browser.log`. Native case: `.runtime/recordings/feedback-continuity/case.json`; raw commands, receipts and spool: `.runtime/private/feedback-continuity/`.

## Scope

This accepts the witnessed Counterspell-to-Fireball boundary and shared numeric/badge lifetime behavior. The terminal predicate has source review; a specific native terminal encounter whose label outlives all action bodies was not added to this focused capture. This checkpoint does not complete the global client plan.
