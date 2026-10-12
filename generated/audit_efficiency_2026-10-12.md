# Efficiency audit — 2026-10-12

This is a read-only audit of the live Godot player, SDK, presentation compiler and timeline, rendering, HUD, and supporting tools/tests. No implementation changes or native benchmark processes were run for this audit. Findings use source inspection and existing recorded profiles. Suggestions describe bounded follow-up work, not authorization to change architecture or backend behavior.

Original observations are preserved below. Explicit disposition paragraphs and
the subsequent evidence section describe later authorized changes; historical
timings and source descriptions are not measurements of the revised code.

## Evidence and limits

Primary evidence: [2026-10-12T02-29-44-encounter-final.json](profiles/2026-10-12T02-29-44-encounter-final.json), an existing native recorded-player profile. The final scene contains four actors and 229 placements, with 421 textures. This is useful evidence for cold admission and the current small encounter; it does not establish large-map capacity.

**This profile predates the newest per-fragment wall-cutout implementation.** During the audit, the parent task removed `_scan_wall_tile` and introduced the shared tile-list shader. Earlier wall-visibility timings must not be reported as measurements of that new implementation. Source locations below identify the audited functions; line numbers may move as the parent task continues.

| Observation | Recorded value | Interpretation |
| --- | ---: | --- |
| Worst initialization frame | 772.556 ms | Measured first-admission stall |
| Synchronous texture decoding in that frame | 461.523 ms | Measured main-thread phase |
| World synchronization in that frame | 446.685 ms | Inclusive phase; overlaps texture loading |
| Actor sampling in that frame | 185.887 ms | Inclusive phase; includes missing-sheet loading |
| Later playback reveal frame | 135.825 ms | World sync 101.844 ms, texture decode 52.053 ms |
| Another character-reveal frame | 80.616 ms | Actor sample 43.675 ms, texture decode 37.911 ms |
| Warm settled frame p95 | 2.651 ms | Small recorded scene, VSync disabled |
| Warm wide-view frame p95 | 1.797 ms | Small recorded scene, VSync disabled |
| Final reported video memory | 3844.906 MiB | Engine monitor for the process; not a per-texture attribution |
| Final reported static memory | 3121.231 MiB | Includes scene, caches, queued/recorded data, and profiling |

CPU phase values are inclusive: do not add child phases to parent phases. Renderer timing can lag a frame. The profile uses a fixed presentation step and an uncapped renderer; its frame distribution is not a claim about live network latency. The final memory figures do not isolate a single owner, but the source confirms unbounded live media retention.

## Prioritized findings

### P1 — Live media residency has no budget

**Confirmed behavior with measured aggregate memory evidence.** `play.gd:_sync_actors` (around line 406) queues every authored clip for every layer of an admitted character. `_warm_media` (around line 423) retains both the decoded `Image` and GPU `ImageTexture`. The live `_process` override never calls `main.gd:prune_texture_cache`, which the offline scene calls periodically. Hidden character presentations and their loaded media also remain resident.

The latest profile grows to 421 textures and roughly 3.8 GiB of reported video memory with only four actors. Additional character appearances, equipment combinations, and map art can increase that footprint. A particular platform's exhaustion point was not measured.

**Recommendation:** use a byte-budgeted active and near-future media set, preserving all original authored content. Eviction must coordinate source images used for picking, material references, and queued work. `presentation/media_warmup.gd:enqueue` permanently records paths in `queued`; its lifecycle must allow evicted assets to be requested again.

**12 October implementation disposition:** the live actor path now requests exact
rest/current-group/one-lookahead clips and outfit witnesses, with a 512 MiB soft
combined CPU-image plus estimated RGBA GPU byte budget. Current/prepared sheets
stay pinned, with explicit over-budget diagnostics; this is not a measured VRAM
cap. Cold CPU picking pixels are released immediately. Cold GPU textures use LRU
retention and are reused after asynchronous CPU restoration; full eviction also
releases material references. Pending cancellation, revisit and eviction no
longer leave permanent `queued` membership. `tests/media_warmup_checks.gd` now
passes42 native headless boundary/asset checks, including null senses, future
failure scope, worker snapshot isolation and separately pinned environment
sources; existing character checks passed 56. The later environment preparation
extension retains current/prepared four-view environment media separately from
the character budget, with independent profiling counters. Its full recorded
performance comparison is still pending at this checkpoint; no final improvement
factor is inferred from source changes alone.

### P1 — First-use loading still blocks the scene thread

**Confirmed behavior and measured stalls.** `main.gd:texture` (line 178) synchronously calls `Image.load_from_file` and creates an `ImageTexture` on a cache miss. Live environment construction and `play.gd:_sample_actors` call this path. Background warmup does not prevent a newly revealed actor or an immediately needed animation from missing the cache. Fixture and UI image loading also have synchronous first-use paths.

The measured 772.6 ms initialization frame and 135.8/80.6 ms playback reveal frames establish that this remains visible beyond ordinary steady rendering.

**Recommendation:** prepare assets required by upcoming admitted presentation groups before their visual playback begins, decode off the scene thread, and budget upload work. Preserve authored pixels and causal timing; do not substitute guessed visuals or silently advance an action with missing assets.

**12 October implementation disposition:** live `_sample_actors` no longer calls
the synchronous `texture()` fallback. A default-unset timeline readiness callback
holds the displayed clock before initial/group staging and commits, including
zero-duration groups and large manual time steps crossing several groups. It
discards waiting wall time instead of catching up through skipped animation.
Exact complete outfits become drawable after worker preparation; unsupported
sources fail explicitly at their affected group's boundary. SDK intake remains
independent. Current image upload is limited to one completed sheet per frame.
The same preparation path now includes exact four-view environment sources,
original corner members, masks, water inputs and fixture frames. Fixture native
luminance reduction also moved to its worker decode. Source planning uses a
worker-owned authoring cache and immutable group unions instead of repeating
the same lookups on every step/HP commit. Native world/cache suites exercise
source selection without synchronous fallback. UI image decode, scene creation
and individual GPU upload cost remain open parts of this finding, pending the
preserved-baseline comparison. The small
captured/typed loading checks are recorded in `media_warmup_checks.json`; they
are boundary evidence, not an end-to-end performance benchmark.

### P2 — Small world changes recreate the whole environment

**Confirmed behavior, with measured world-sync cost; large-map growth is an inference.** `play.gd:_sync_world` (line 193) derives all rows, compares the complete array, and frees/recreates every static node and ground batch if any row differs. It invalidates the wall mask and ordering as part of that rebuild. An object-state change or newly disclosed tile therefore performs work proportional to the entire learned map.

The later reveal frame spends 101.844 ms in world synchronization; this includes loading, so it is not an isolated measurement of node rebuilding. `presentation/lighting.gd:apply` (around line 127) also scans all registered weak references for each material, making registration during a large rebuild quadratic in material count.

**Recommendation:** retain entries by existing object/tile identity, update changed rows, and rebuild only affected batches and neighboring corner assemblies. Register known-new materials without repeatedly scanning the complete registry.

**Disposition — implemented and correctness-checked.** `_sync_world` now retains
unchanged canonical visual-owner groups and floor-material batches, replacing
only changed/added/removed groups. It still derives the disclosed rows and
reassembles corner candidates at world revisions; it is not a sublinear world
adapter. Changes within one ground material still rebuild that material's
MultiMesh. First use of a camera quarter binds the registered artwork; the later
bounded view cache reuses it while canonical world rows remain unchanged.
Hidden-mode substituted rows remain separate from canonical group snapshots.
`Lighting.apply` now registers materials by instance ID with weak references,
avoiding the scan through all previous registrations. `sync` prunes dead
references and writes source counts only when the count changes. Native world
equivalence evidence is recorded below; no isolated speedup is inferred from
the algorithm change.

### P2 — Continuous actor movement triggers global sorting

**Confirmed algorithmic cost; large-map impact is not benchmarked.** `grid_order.gd:key` (line 16) includes continuous projected contact position. `play.gd:_sort_draws` (line 500) compares these keys each frame; a moving actor changes its key throughout a walk, forcing the complete draw list to sort and every sorting offset to be assigned again. Static entry visibility is also scanned each frame.

**Recommendation:** preserve the exact ordering key, retain the sorted static sequence, and insert/update the small moving set. `grid_renderer.gd:insert_dynamic` contains a related approach for the offline renderer, though its fixed-map cache cannot simply be substituted for a backend-driven map.

**Disposition — implemented and correctness-checked.** `_sort_draws` keeps the
visible static sequence until world membership, camera registration or a Hidden
corner replacement invalidates it. Actor layers use the original full key and
identity tie-break, then merge with that static sequence. Native sorting offsets
are written only when their rank or projected origin changes; actor visual lift
is compensated even when the ground key is unchanged. Sorting is not removed:
changed actor order still requires a linear merge, and changed static membership
still requires a static sort. The complete merged sequence and renderer pixels
were compared against independent full-sort/full-rebuild references.

### P2 — Packet validation and state reduction repeat across layers

**Confirmed repeated work; latency at large state sizes is inferred.** `sdk/transport.gd:_event` decodes an operation. `sdk/journal.gd:consume` (line 27) decodes it independently, normalizes it, and reduces it. `presentation/session.gd:_consume` normalizes it again; `presentation/compiler.gd:compile` (line 239) performs another complete reduction before replaying the committed mutations to extract presentation deltas. `sdk/reducer.gd:copy_target` deep-copies state at operation and lineage transaction boundaries.

These actions run on the worker rather than in the normal render callback. The worker also owns networking and ACK/status work, so a growing map and history can delay those tasks. Offline recording startup additionally replays the journal before reading it again for presentation preparation.

**Recommendation:** reuse an admitted internal representation and final reduction result, and consolidate commit extraction with reduction where feasible. Keep strict standalone journal validation, immutable failure behavior, complete state fields, and the existing Python/Godot parity guarantees. Removing checks without preserving these boundaries is not an efficiency fix.

### P2 — Queued operations retain repeated accumulated history

**Confirmed allocation pattern; long-session growth is inferred.** `presentation/compiler.gd:compile` (around line 336) copies the full content collection and accumulated combat log into every operation's ending delta, even when those fields did not change. `presentation/timeline.gd:accept` (line 24) permits an unlimited presentation queue while paused. With a growing combat log, retaining many queued operations repeats progressively larger histories. Diagnostic `completed_groups` and `skipped` arrays also grow without bounds.

**Recommendation:** use append deltas for new log rows, change-only content publication, and a bounded preparation window backed by the existing durable journal. Keep all authoritative history available; bound redundant prepared presentation data rather than discarding game facts. Use counters or bounded diagnostic rings when full diagnostic history is unnecessary.

### P2 — Source-light cost multiplies with every disclosed emitter

**Confirmed shader scaling property, not a measured bottleneck in this encounter.** `presentation/source_lighting.gdshaderinc:disclosed_irradiance` (line 36) loops over all disclosed sources for every rendered fragment, including distant sources rejected after texture reads and distance calculation. Large visible maps with many lit fixtures can therefore multiply fragment cost.

**Recommendation:** reuse disclosed source radii and coarse spatial bounds to restrict applicable lights for spatial draw batches if profiling demonstrates this cost. This does not require optical wall physics, CPU depth reconstruction, or altered backend light ranges.

## Smaller findings and validation gaps

- `play_hud.gd:_process` (around line 216) rebuilds the complete action bar for every displayed-state revision, even if discovery and painted action controls did not change. Separate status/resource refresh from control reconstruction. First-use UI textures are loaded synchronously in `presentation/ui_catalog.gd:texture`.
- `play.gd` computes actor samples before `_sync_actors`, then recomputes them in `_sample_actors`. Staged actor dictionaries are also rebuilt repeatedly inside actor loops. These are lower-priority repeated allocations, not the measured cause of the largest stalls.
- `frame_profile.gd:frame` measures the main viewport's render CPU/GPU time. It does not separately enable and collect timing for the wall-mask viewport. Add those timings before attributing the total cost of translucency to the shader or mask.
- `tests/player_profile.gd` prints `presentation_errors` but its final exit status depends only on final canonical-state equality. A broken presentation can therefore leave this profiling script successful. Make the script fail on presentation errors and incomplete playback as well as state mismatch.
- `tools/check_sdk.py` uses a subprocess timeout without the explicit native Windows child cleanup present in `tools/play.py`. A WSL bridge timeout can leave a native test process affecting later checks. This is a harness risk; no dangling process was launched or demonstrated by this audit.
- The profile history ring is bounded, but an explicitly enabled recording appends indefinitely. Long recordings should be streamed or bounded if they are expected to remain enabled for extended play.

## Wall-mask recommendation and current change status

At the beginning of this audit, `update_wall_visibility` used `_scan_wall_tile` to scan original sprite pixels for each uncached wall/tile pair and then applied opacity to the whole wall. Cache entries were keyed by camera quarter, so returning to an earlier view replaced the prior cached signature. The parent task has since removed that CPU scan and added a shared numeric tile-list texture with per-fragment diamond tests. The obsolete scan is recorded here as audit context, **not an outstanding implementation defect**.

For the existing 256×256 authored wall/corner sprites, short per-wall candidate lists are a reasonable smaller implementation than immediately adding another full-screen content pass. Record maximum candidate count, mask viewport time, and fragment cost at fractional zoom before replacing it. Keep the three modes—solid, translucent, hidden—consistent with per-pixel picking and the user's rear-wall policy.

A floor-diamond list has a specific generalization limit: it describes eligible floor regions, not the topmost actual content at a screen pixel. A later raised tile or noneligible prop can cover a qualifying diamond, and a character silhouette can extend above it. If those cases must drive reveal eligibility, one shared numeric viewport containing topmost visible content IDs at their actual elevations, plus a wall/content eligibility lookup, offers constant work per wall fragment. Generate eligibility from existing coarse buckets, exact painter ordering, and backend boundary-side data; do not add CPU rasterization or per-wall viewport trees.

The existing wall-owner mask solves a separate problem: preventing opacity accumulation where wall sprites overlap. Keep that ownership purpose distinct from reveal eligibility. Mixed authored corners have no per-face labels; a cell-overlap mask alone cannot guarantee independent treatment of two corner faces that overlap the same pixel.

## Suggested order of follow-up

1. Budget live media residency and remove synchronous first-use decode from visible gameplay transitions.
2. Update static world entries incrementally; preserve sorted static data during actor motion.
3. Consolidate worker-side admission/reduction and bound redundant queued presentation history.
4. Measure all GPU passes and source-light scaling before introducing more GPU data structures.

Keep existing authored assets, canonical backend semantics, and differential/native correctness checks throughout. The small encounter's good warm timing does not justify claiming that a large map is already validated.

## Subsequent scoped implementation evidence

The parent added per-frame wall-mask viewport CPU/GPU timings and candidate
counts, and corrected profiler success gating. The final fragment profile is
`profiles/2026-10-12T02-49-15-encounter-fragments.json`, summarized in
`wall_fragment_profile.json`: max29 candidates per wall,721 shared references,
settled mask GPU median0.288ms, settled frame median1.994ms. Playback still
contains a127.772ms frame; reported final video memory remains3840.85MiB.
These figures validate neither large-map capacity nor solved loading.

### Renderer reuse validation and separate visual repairs

Before the reuse changes, the later `encounter-fragments` profile also contains
world-sync costs of 23.022 ms at frame 14272/sequence 25 and 24.547 ms at
frame 14951/sequence 41, both with zero recorded texture decode/upload. Its
300 settled frames have draw-order median 0.205 ms/p95 0.436 ms; playback has
median 0.351 ms/p95 0.987 ms. These are historical inclusive phases. The
`source_lighting` phase measures fixture/source sampling, not material
registration; registry scans were charged to world/actor synchronization.

The revised renderer passed **89 native checks** in
[world_incremental_checks.json](world_incremental_checks.json). Twelve actual
Crypt room comparisons cover door state changes, all camera quarters and
Solid/Translucent/Hidden, comparing complete painter order with a full sort and
pixels with a full rebuild. No pixel exceeded the one-byte tolerance; one
translucent comparison reached 1/255 and the other 11 were byte-identical.
The checks also confirm unchanged owner/material/floor-batch retention and
actor height compensation. [The native log](../.runtime/world-incremental-checks.log)
contains no script or rendering errors. Larger-map before/after profiling is
separate and was still in progress when this disposition was written.

Two correctness repairs must not be presented as performance improvements:
the door's authored local leaf/frame GPU partition passed
[79 checks](door_overlap_checks.json), and conditional original-byte selection
in the environment/grid shaders passed [16 checks](environment_selection_checks.json).
The door adds one visible leaf pass for intact banks with the required legacy
registration. Neither repair changes source pivots or artwork. The selector
repair followed the frozen performance baseline, so any image differences in
that baseline comparison must account for it separately.

The large-map follow-up identified repeated warm rotation stalls and now retains
one static view per authored quarter, with at most three inactive sets. This
adds bounded node/material/instance residency while sharing existing textures;
it does not retain earlier canonical worlds. Actual row changes release inactive
views. Re-entered views still refresh current visibility and Hidden substitutions,
then publish one ownership mask. This avoids the prior Hidden rotation's mask
build before corner substitution followed by a second complete mask build.
[The cache check](world_view_cache_checks.json) passes **87 native assertions**,
including 15 byte-identical cached/fresh or mode-round-trip comparisons. The
large replay determines performance impact; correctness results are not a
speedup estimate. Nested `world_rows`, `world_objects`, `world_ground` and
`world_views` profile phases now separate row derivation, node/batch construction
and view activation from the inclusive `world_sync` total.

### Admission, history and harness disposition

The presentation compiler can consume the journal's already-admitted final state
at its exact cursor; its standalone entry point still validates and reduces.
Offline playback no longer reduces the entire journal before preparing it again.
Ending deltas append new combat-log rows and publish changed content instead of
copying each accumulated history into every queued operation. Real spell records
passed 822 checks; separate walking/opportunity-attack, jumping/hit and late lethal
interruption records passed 277 with identical admitted/standalone tracks and commits.

The scene/default and retained-replay boundary passed 16 checks. The SDK launcher
now marks and cleans only its owned native Windows child after a timeout; all six
SDK lanes passed 11,719 checks. HUD action controls no longer rebuild on every
state revision, and full viewport-size changes trigger layout (39 native checks).

Long paused sessions still retain unbounded prepared-operation and diagnostic
history, and explicitly enabled profile recordings remain unbounded. They are
not fixed by append-only log deltas. Source-light fragment work still scales with
disclosed sources; this pass has not replaced that shader with spatial light bins.

### Rejected mask-transform experiment

A shared orthographic canvas transform was tested against the original native
per-wall projection. Godot rounds Control origins in local coordinates, so
moving the transform changed ownership-mask sampling. A bounded GPU correction
restored the original screen-origin rounding, but two native cases still changed
5 and 16 compositor pixels (maximum RGB differences 0.066667 and 0.054902). The
runtime and shader experiment was reverted without loosening pixel tolerances.
The original per-wall projection remains; only the `mask_sync` profiling phase
was retained. [Rejected source and evidence](../.runtime/experiments/wall-mask-affine/README.txt)
are outside the active test suite. This experiment contributes no performance
improvement claim.

### Final measured comparison

The final result and raw profile paths are indexed in
[performance_scale_validation.json](performance_scale_validation.json).
Both original and larger-room replays drain to the exact recorded canonical
state with no presentation errors. The large route uses 58 real SDK commands,
102 packets and a final disclosed state of 1,761 tiles and 360 objects.
Native live movement/jump/reconnect/end-turn also passed 44 checks.

System variance materially affected the earlier runs, so the frozen baseline
was repeated immediately after the final optimized runs. The adjacent native
RTX 5090 / Compatibility / 1440 × 900 / VSync-off comparison is primary:

| Measurement | Frozen baseline repeat | Final |
| --- | ---: | ---: |
| Large-room wide-view p95, four quarters | 6.62–7.67 ms | 3.82–5.16 ms |
| Large-room repeat-quarter rotation stall | 368–429 ms | 47–50 ms |
| Large-room first-quarter construction stall, q1–q3 | 366–407 ms | 140–145 ms |
| Large traversal worst frame, including media holds | 331.49 ms | 135.84 ms |
| Large traversal p95, excluding media-wait context | 9.37 ms | 5.01 ms |
| Large traversal sampled wall time, including holds | 46.13 s | 33.75 s |
| Large final video memory | 3,933.70 MiB | 644.29 MiB |
| Small playback worst frame | 108.85 ms | 38.85 ms |
| Small settled p50 | 1.09 ms | 1.32 ms |
| Small final video memory | 3,856.85 MiB | 602.36 MiB |

The small scene has about 0.2 ms additional steady overhead from readiness and
residency handling. Its fixed-step playback takes 6.56 s versus 4.43 s because
required-media holds are now explicit; complete recorded initialization plus
playback drops from 15.16 s to 13.14 s. These are benchmark wall times, not changes
to the authored animation durations. The large replay includes 6,488 samples
whose end-of-frame context reports media waiting; that count differs from exact
clock-advance iterations. The JSON retains both distributions and completion
logs. Whole-run FPS averages would obscure this distinction.

No 50× whole-game claim follows from these measurements. Scene creation, ground
material-batch rebuilding and wall-mask publication still cause reveal/first-view
stalls. The attempted 8 × 8 ground split failed nine original-art pixel cases and
was reverted: source floor skirts overlap across chunk boundaries. Only the
equivalent precomputed projection keys remain. Backend moving-light publication
also remains expensive after the tested sensory fix; final command p95 is 3.947 s.
Full-state cross-game UUID normalization is inconclusive; only the named command
outcome fields and focused sensory replay/full-refresh checks establish backend
agreement. All earlier raw measurements and rejected experiment evidence remain
available rather than being replaced by the best figures.
