# Native blood harness request ordering

`native_blood_partition_checks` and `native_effect_receiving_checks` now submit
every source request after `process_frame` and before the draw which owns its
completion. Their old settle loops submitted the next native delta from the
previous `frame_post_draw` continuation, unlike the player's process/draw path.
Partition changes, held-age checks and light-only checks use the same order.

Only those two tests changed. Requested source age 0.2, original sources/seeds,
reset histories and all four camera views remain unchanged. The tests retain
nonzero original coverage, exact separated-side RGBA and union coverage,
unchanged emitter bounds, source clocks, normal capture, final alpha and actual
native light response. No production clock or source-art edit was made.

After the whole `runtime-e102c29dec58524b` package and source build, the single
serialized native pair passed at
`.runtime/tests/20261020T064929.458159Z/`: partition **84 checks / 0 failures**
(3.6 s), receiving **84 / 0** (5.0 s). Both exited 0 with zero script/engine
errors and no owned leftover processes. Earlier failed receipts remain intact.
This qualifies these finite four-view assertions; it does not establish an
independent general particle-clock equivalence oracle.
