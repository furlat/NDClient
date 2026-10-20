# Plant Growth: actual spatial owner and constructed cells

This cohort binds the sealed `c494177f9ef03e3d` Plant Growth source to the existing schema16 spatial-owner path. It does not modify the Factory package, gameplay rules, approved lighting or materials. The cast body remains authored; the former spell-owned review ground probe is excluded so the actual field owns one native occurrence.

The existing admitted-cell provider alone cannot construct this source: `plant_growth.gd` builds native vegetation from constructor `cells` before any setter runs, and its public `set_removed_cells(cells, observed_at_seconds)` takes two arguments. The binding supplies actual cells before construction and forwards the timed setter through the occurrence's already prepared receiver index. Other spatial sources retain their existing constructor/setter behavior.

## Original evidence

Durable original journals are under `tests/fixtures/schema16/scenarios/plant-growth/{amber,blue}`. They are unchanged copies of `.runtime/studio-library/cases/spell.plant_growth__baseline/20261019T143140.921882Z`; scenario and recording metadata accompany them. Frozen engine 211b71134/schema16 generated both independent journals.

The actual field UUID is `7f14bbfb-2cc1-4188-a9b8-a28aceaa55ec`; its content is `spatial_effect.spell.plant_growth`. The original SpatialEffectStateFact declares operation `created` with 49 cells, independently disclosed to both seats. Amber's native spatial occurrence is 55 and SpellFact 57. There is no observed partial burn, removal or expiry in these originals.

The existing owner retains its first immutable disclosed topology and registration. The constructor receives those cells translated into the source's world-aligned local frame; sealed leaf meshes, source material/noise, palette, growth/sway and artistic clocks remain untouched. Current disclosed positions/suppression still use the existing reversible AreaMask. Disappearance from subjective visibility is not a permanent burn. Empty `observed_removals` means this baseline has no observed retirement; no burning is synthesized.

Newly disclosed positions outside the constructed topology remain `spatial_source_topology_extension_not_bound`. The partial-burn variant remains a probe requiring a real removal recording and producer. Neither setter availability nor this baseline qualifies permanent removal, expiry, performance or user approval.

## Gates and current qualification

- `plant_growth_input_checks`: headless, args[]. Builds only the two typed records in memory; unchanged original two-seat reduction, exact49-cell fact oracle, private source/art parity, one owner, two-argument receiver forwarding, actual source clock, visibility/suppression restoration, explicit extension/missing-observation controls, final canonical-state ordering.
- `native_plant_growth_render_checks`: GPU, args[]. Ordinary Recording/Play path; exact actual UUID/content/cells, source groups, declared setter admission, source-specific native framebuffer pixels, backward seek and fresh-loop ownership beyond the finite review clip.

Qualification on the single main checkout: `plant_growth_input_checks`145/145 and the complete124-test fast lane pass (`.runtime/tests/20261020T024525.194818Z/`). The native gate passes34/34 (`.runtime/tests/20261020T024414.366993Z/`), including both original factions, 28,750 changed native pixels per seat, backwards seek, private lookahead invisibility and one fresh-loop owner. Source metadata/image availability is not used as a substitute for those native pixels. Performance and user visual approval remain unqualified.

The native gate exposed one shared readiness bug: an ordinary budget-delayed AreaMask was classified as a fatal missing effect, preventing the following preparation frame. The renderer now treats only `native_area_not_prepared` as pending and keeps the prepared occurrence invisible until its mask is ready; other missing/unsupported masks remain explicit errors. No clock hold, fabricated topology or source retuning was introduced.

## Performance limit remains explicit

The installed Factory manifest reports 3130.391 ms construction and 1981 µs sample for the 49-cell fixture. The source constructs six native vegetation clumps per cell, each with one native vine mesh and five leaves (roughly 2058 nodes plus the root/fill). Client input binding does not remove that indivisible source construction cost. Native qualification may use a sufficient timeout; that is not performance acceptance. No source geometry is dropped, no clock is held and no package art is retuned to hide this cost.
