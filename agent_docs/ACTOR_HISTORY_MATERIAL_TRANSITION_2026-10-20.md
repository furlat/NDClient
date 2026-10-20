# Historical body treatment qualification

The bounded next proof uses the existing unchanged two-seat `blur` fixture,
not a new recording or a modified journal. Amber sequence 8 has actual
opportunity-attack applied damage occurrence 94: 14 Slashing to
`7f95fe86-17ea-4647-8f15-1639954bd31e`, while actual Blur UUID
`b81bcd18-42f0-419a-aadd-0b0549890dce` remains active. The test resolves each
seat's own occurrence from its original journal rather than joining raw IDs
across perspectives. Sequence 9 contains the real concentration removal.

The existing authored physical-damage flash is finite and does not require a
borrowed native hit framebuffer. Observing 40 ms after that actual flash ends
keeps real positive-flash captures inside Blur's authored 240 ms history window
while the current same-rig actor has returned to zero flash strength.

`tests/actor_history_material_transition_checks.gd` checks actual result
ownership, old-prefix appearance/item looks, immutable history treatment ages,
the production uniform projection, actual removal and deterministic reverse
seek. `tests/native_actor_history_material_transition_checks.gd` additionally
checks the ordinary Play/media path, real supplied inputs, actual captured
material uniforms versus restored published actor layers, private material
ownership, four published camera quarters and return, isolated history
framebuffer contribution, exact paused restoration, removal/seek and cleanup.
The native gate reuses the existing corrected process-frame preparation helper.

The logical gate passes **94 checks, zero failures**, 3.2 seconds, receipt
`.runtime/tests/20261020T081158.823921Z/summary.json`. Root owns registration
and serialized native execution. Suggested gate rows: headless
`actor_history_material_transition_checks` (120 seconds, no args) and GPU
`native_actor_history_material_transition_checks` (300 seconds, no args).

The first native run (`.runtime/tests/20261020T081320.703278Z`) completed
4,746 checks with 12 failures and no script/engine errors. All actual historical
material, current restoration, private ownership and native pixel assertions
passed. Every failure was the combined paused-frame restoration control:
`Effects.hide` deliberately withdraws `actor_context`, which hides the source's
private compositor owner and suspends its viewports. Merely showing the outer
root while Play remained process-disabled never re-supplied that context.
The corrected test restores through ordinary same-clock Play processing, then
separately requires identical canonical state, historical material identities
and uniforms, source admission, and exact paused framebuffer restoration.
It saves present/hidden/restored captures and reports each comparison. The
corrected native rerun passes **4,806 checks, zero failures**, 11.8 seconds, with
zero script/engine errors and no owned leftovers:
`.runtime/tests/20261020T082003.334192Z/summary.json`. Exact paused framebuffer,
source/owner clocks, private material identities/uniforms and canonical state
all restore through the ordinary path. No production change or relaxed pixel
threshold was introduced.

The durable Blur, Mirror Image and Banishment history recordings contain no
equipment/appearance row transition on the history owner. Their old and current
outfits may correctly remain equal; that is not a gear-transition proof. A real
same-owner equipment change during the retained window remains a named scenario
gap. No synthetic equip, substituted outfit, approval of art, or live frame-cost
claim is part of this cohort.
