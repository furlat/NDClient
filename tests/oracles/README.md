# Independent renderer test sources

These are test inputs, not production implementations or exported current golden results.

| Input | Original source | Permitted local change |
| --- | --- | --- |
| `condition_selection_original.json` | Original Pygame `game_obsolete/condition_sampling.py` operator oracle, with recorded Poisoned / Hold Person / Rage owners named in its header | None; the 30 original expected operator selections are unchanged |
| `media_before_source_delta.gd` | `e138fc99^:presentation/media_warmup.gd`, before immutable contribution deltas | Provenance comment only |
| `shadows_before_geometry_cache.gd` and its three `shadow_*.gdshader` dependencies | `bd3c20f7:presentation/canvas_shadows.gd`, before geometry caching / fixed helper targets | Provenance comment on the script only; shaders are byte-for-byte originals |
| `blood_before_atlas/*` | `f77f83d1:presentation/{blood_renderer.gd,blood.gd,blood_kernel.gdshader,blood_surface.gdshader,blood_droplet.gdshader}`, before field atlasing / pooled droplets | Provenance comments and preload paths pointing to this folder's original dependencies; one test-only catalog interface adapter for the unchanged region source |

The media test projects immutable current source contributions into the original public flat path/role call. It compares physical pins, source roles, queue ordering, estimates, budgets, startup gates and every readiness/publication result. Queue timestamps, revision-counter values and worker-pool configuration are diagnostic implementation details; the comparison removes those, not source operands or readiness requirements. The keyed/unkeyed union has a separate known first-seen immutable-input assertion.

The condition test retains all original selector expectations, immutability, composition/state predicates and overlap/removal priority checks. Current package lifecycles intentionally replace those old marker sprites, so downstream source-clock / registration / thumbnail-job checks use the installed lifecycle's actual application, sustain and removal records. Native pixel qualification is a separate GPU gate.

# Reproducible test invocation

Run from the project directory with `python3 -B tools/run_tests.py --only <names>`. The manifest contains every required fixture/oracle argument; no `.runtime` source path is necessary.

`basic_condition_checks`, `condition_selection_checks`, `media_source_delta_checks` and `combat_timing_checks` are headless value/ownership tests. They do not qualify native draws, framebuffer pixels, shadow rendering or audible output. They retain `tier=gate`.

`basic_condition_render_checks`, `history_panel_ui_checks`, `blood_atlas_checks` and `shadow_geometry_cache_checks` remain GPU gates: they require actual rendering or native Control interaction. The basic condition source now explicitly omits Dash's retired pink contour (`authoring/abilities/conditions/condition.dashing.tres`); Dodge and Disengage still exercise four-view pixel differences and exact mute restoration.

`blood_before_atlas/catalog_adapter.gd` is only a lookup interface: the retired generic `asset/prepared_asset("particles.region.blood")` calls select the same immutable blood region Resource through the current environment residue owner. It performs no field conversion, simulation, new data generation or production fallback. The original blood math and shaders do not call current renderer code.

Outline preparations intentionally retain hidden nodes. The native condition test checks their actual emitted visibility and pixel differences/restoration, rather than cache membership.

The geometry-cache native fixture explicitly admits only the current registered `Chest14/Idle.png` source descriptor before binding. Its old `/media/` texture name still names the original pixels, but is not a current metadata owner. The oracle and optimized helpers receive the same actual texture/depth/support operands; no publication wait, substituted geometry, tolerance change or graphics adjustment is introduced.

The first serialized rerun qualified native condition131/0, blood atlas26515/0 and history UI20/0. The shadow test's remaining failed input was an unadmitted old-path modular descriptor; the test now explicitly prepares the current registered metadata owner for the same original Chest14 source. Its closure and selected descriptor parse/read are qualified by `.runtime/input-shadow-parse.log`; the final native helper parity result remains separate.


The final native shadow rerun passes **1703/1703** with zero errors,
`.runtime/tests/20261020T014526.330403Z/shadow_geometry_cache_checks.log`.
Both original Goblin and explicitly admitted Chest14 sources retain the same
shadow equations, contact/geometry and original tolerance. The failed old-path
admission attempt remains retained separately.

`blood_before_shape_cache.gd` is the byte-for-byte original `7faf78fb439173cd7f2d77024ad04b6a2da42f2c:presentation/blood.gd`, formerly stored only in the ignored blood-kernels-original.gd. The source-cache worker test compares the original kernel evaluator with the current prepared cache using actual Gallery releases, including eighteen-cell and overlapping/reverse controls. It performs no current-output export to create an oracle.
