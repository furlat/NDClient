# Floating feedback placement — N3/R17

The production DOM feedback overlay now places simultaneous authored damage,
healing and outcome labels against visible physical actor bounds and earlier
labels. It uses the original `animation_draw.py::place_feedback_rect` order:
above first, below if the top has no room, then a stable clamped least-overlap
choice. The six-pixel gap, source text, font size, color and timing remain intact.
The layout uses existing source coverage bounds; it performs no GPU readback.
DOM size reads are batched before position writes.

`tests/feedback-layout.test.ts` passes three placement cases: concurrent labels,
viewport edges, and a crowded viewport without shrinking the authored text.
`tests/feedback-layout.browser.mjs` passes all four camera views of the genuine
Fireball Sorcerer recording. Each view has seven actual concurrent feedback
labels with unchanged text and font size, no actor/label overlap, no viewport
overflow and stable repeated placement. The compiled operation has no issues;
browser errors are empty and disposal leaves zero prepared views or resource
leases. Evidence is `.runtime/reviews/feedback-layout/evidence.json`; the final
`q3.png` was captured before cleanup and visually inspected.

Independent source/ownership review passed. Browser font metrics and strokes
are not claimed to be pixel-identical to Pygame text rasterization. This change
closes placement, not the separate requirement to retain feedback across action
boundaries. It does not claim hardware GPU performance or full R17 completion.
