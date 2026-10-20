# Gallery issued-command and Studio profile — 20 October

Baseline runtime010343ab, sole `codex-authoring-schemabump` branch, installed
Factory `production-bindings-c494177f9ef03e3d`, frozen engine211b71134/schema16.
Three independent fresh game processes; Forward+/Vulkan/RTX5090; root1600×960,
orthographic size18, VSync off, no competing GPU jobs. OS/driver caches were not
flushed. These are fresh-process trials, not claims of cold storage or drivers.

## Real game results

All three executions pass313 assertions, with zero script/engine errors and
zero owned processes left running. Each issues27 ordinary admitted player
commands, including the door, room entry, seven spell families, a real Shield
reaction and repeated Fire Bolt. They use the production SDK/reducer/renderer;
there is no manual replay stepping. Capture/profile serialization happens after
the measured window. The intact prop selector is described below.

| Trial / run suffix | Frames | p50 ms | p95 ms | p99 ms | Max ms | Frames >16.667 / >33.333 ms |
|---|---:|---:|---:|---:|---:|---:|
|1 /031510.054960Z|7388|6.029|12.564|16.375|64.525|65 /1|
|2 /031620.636361Z|7892|5.521|11.877|15.439|59.287|47 /4|
|3 /031731.113557Z|7979|5.680|12.130|16.004|63.383|61 /2|

The exact run directories are in
`.runtime/consolidation/current-three-trial-breakdown.json` and the original
`.runtime/consolidation/live-spells-three-props-010343ab/{1,2,3}/` logs. Frame
windows start at the first issued command and end when the last command ends;
startup is excluded. The original JSON/logs retain every stage and frame.

### Exclusive input-to-animation intervals

All columns below use the same Godot monotonic clock, add to the final observed
time, and do not sum inclusive worker/render parents. “Fold” includes canonical
consumer scheduling/commit; “Compile” starts at that consumer boundary.
“Publication” is the remaining wall interval from the prepared opening to the
first animation observation. It includes readiness/main-thread scheduling and
frame observation; it is not a single CPU function.

| Action / trial | Input→preview reply | Reply→command sent | Sent→operation framed | Framed→admitted | Fold | Compile | Opening metadata | Publication | Total ms |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
|Door1|12.784|3.480|47.043|3.967|30.608|6.531|4.134|39.334|147.881|
|Door2|15.294|4.445|59.116|4.233|31.685|7.882|4.532|49.956|177.143|
|Door3|13.871|2.103|62.092|5.013|38.485|7.503|5.078|38.916|173.061|
|Fireball1|17.100|9.583|69.182|1.902|33.136|7.604|6.759|62.226|207.492|
|Fireball2|16.840|15.240|61.583|1.562|30.722|7.361|6.575|45.949|185.832|
|Fireball3|15.777|4.071|63.601|2.085|33.665|8.859|7.553|42.910|178.521|

Authoritative player-command server dispatch, measured on its own clock, is
29.709/29.391/29.300ms for the door and45.883/49.389/44.587ms for Fireball. These
durations sit inside “sent→operation framed”; they are not extra addends or
timestamps that can be subtracted across clocks. First Fireball dispatch1 splits
into30.173ms execution and15.558ms audience projection. Its51,280-byte observed
operation admits in1.893ms; JSON parse is1.789ms. Its canonical consumer takes
33.111ms:31.482 reduce,0.852 stage,0.729 commit; reducer world15.592 and facts
12.664 are nested inside reduce. The7.441ms compiler splits into actor cuts.940,
components.729, event trace2.164, input shell.854, lineage1.450, requirements.339,
schedule.745, ending.199 and disclosure.016ms. Opening metadata is6.759ms.

Original stage records and derivation are retained in
`.runtime/consolidation/current-exclusive-latency.json`, each run's
`client-pipeline-trace.json`, `live-command-trace.json` and
`worker-dispatch.jsonl`. The two active faction workers can use the same command
number: server rows are matched to the actual command actor as well as number.

### Long-frame causes that remain open

1. All three largest game frames are the background preparation of
   `original-repairs/chill-touch/contact-layers`, playing its delivered
   **recorded** approach. The existing `baked_instantiate` envelope takes
   56.678/53.997/54.434ms. It includes scene instantiation, private material
   handling, particle/track binding, geometry/light scanning and opacity setup;
   it does not yet identify which leaf is responsible. It must not be described
   as a measured live Factory constructor. The next run instruments those
   existing leaves without changing behavior. Magic Missile cast has the same
   envelope at22.456/21.494/21.195ms. A2ms admission budget cannot interrupt an
   indivisible operation after it starts.
2. Studio repeatedly recalculates the same source readiness while crossing
   zero-duration turn-only groups. The repair below is in progress.
3. Other first-use render gaps are separate. An earlier baseline75.378ms frame
   had only7.650ms Play CPU; the adjacent last-available renderer CPU result was
   65.519ms and a native surface-pipeline counter changed. This is evidence of a
   native first-use issue, not proof that every unexplained wall gap is pipeline
   compilation. In the current trials some >30ms wall frames have low measured
   Play/GPU CPU and no corresponding renderer result; those remain unallocated.
   Godot's renderer counters can lag. Do not label background specialization
   compilation itself a blocking operation.

Godot documents that actual mesh/node material overrides and viewport features
affect first-use surface pipelines, and distinguishes those from background
specialization compilation. Any preparation change must warm the actual native
variant and preserve private occurrence clocks and approved pixels. See
[Godot4.7 pipeline guidance](https://docs.godotengine.org/en/4.7/tutorials/performance/pipeline_compilations.html).
Rendering-node instancing is not generally thread-safe under the default model;
moving this envelope to arbitrary workers is not an established fix. See
[Godot4.7 thread-safe APIs](https://docs.godotengine.org/en/4.7/tutorials/performance/thread_safe_apis.html).

## Ordinary Studio on the exact first journal

The full46,455.981ms clip completes with no failures, one rendered faction,
real-time clocks, follow tracks enabled and actual sorcerer selected. Root
1600×960, rendered pane1600×470, view size18, **6025 measured frames**.
p50/p95/p99/max are7.373/12.591/16.911/61.052ms;63 frames exceed16.667ms and7
exceed33.333ms. Display/wall ratio is.989864; no readback/manual stepping occurs
in the window. Output:
`.runtime/studio-profile-gallery-props-current-010343ab.json`; invocation receipt:
`.runtime/consolidation/studio-props-gallery-profile/`.

Startup is separate: first publication5,210.545ms after profiling setup begins;
process uptime8,379.787ms. Original journal read1,954.179ms, final media projection
1,645.879ms, combined3,604.935ms; required native warm532.822ms. These figures
remain too high; successful clip completion is not startup acceptance.

At display21,499/27,477/35,614ms, frames45.898/41.538/41.898ms cross twelve
ordered packets each. The middle range is only14 turn facts, no actor/world
change; the other ranges add a Shield removal. Play media readiness takes
28.282/27.065/25.451ms. A second comparable clip exposes the same CPU leaves:
path set projection/copies5.6–6.0ms, interest updates2.2–4.0ms, native receiver
membership3.2–3.5ms, native image requirements2.5–2.9ms and persistent component
preparation2.4–2.9ms. Group identity, start and queue changes invalidate readiness
despite reused physical sources. Neither world/media hold nor pipeline changes
explains those frames. Reuse must follow actual prepared source cuts and
component requirements; ordered commits, true condition changes and clocks
remain independent and must still execute.

## Harness correction and limits

The previous Fire Bolt selector could choose a structural wall. One earlier
strict live run correctly failed when both observed casts were cancelled, with
no source animation. Those packets contain no Counterspell reaction; their
cancellation cause is not established. The corrected fixture selects actual
offered, intact, positive-HP nonstructural props (or a genuinely offered
disclosed opponent). All313 assertions remain. Earlier failed logs are retained.

The profiler also removes its stale generated-case/caster UUID, selects the
actual named controlled sorcerer, and accepts the ordinary paused state at the
natural clip end. It still fails an unexpected pause before the end.

**The final100+FPS/no-spike and startup targets are not met.** This baseline
qualifies reproducible current issued-command safety and decomposes the open
work; it does not qualify every spell variant, new package or visual approval.

## Recorded source preparation repair, pending live comparison

The source decomposition now identifies the first recorded `PackedScene`
instantiation as the large leaf. A controlled fresh-process three-source test
measures Chill Touch at52.823ms for scene instantiation inside56.452ms total.
Its second and third scene instantiations take.215/.178ms. Material discovery
is.106ms; it is not the cause of this particular pause.

Preparing the actual scene Material programs with the existing
`NativeSourceAdmission.prepare_materials` worker reduces the first scene
instantiation to.525ms. That worker takes55.020ms without instantiating rendering
nodes, advancing a source clock or publishing any game state. The implemented
path also prepares the recorded process-material prototypes; its controlled
results are:

| Actual recorded source | Before: scene / total ms | Integrated: scene / total ms |
|---|---:|---:|
|Chill Touch contact layers|52.823 /56.452|.431 /1.787|
|Magic Missile cast|7.631 /11.381|.229 /.833|
|Fireball lifecycle|14.971 /16.154|.194 /1.190|

Nine sequential actual occurrences per invocation complete without script/engine
errors or owned leftovers. Generic exit leak warnings are retained, not called
clean teardown. Baseline/probe/integrated receipts and exact leaves remain in
`.runtime/consolidation/recorded-source-{setup,prewarmed-setup,integrated-setup}/`
and their `recorded-source-setup*-parts.json` data. The implementation retains
actual immutable scene/prototype references in the existing bundle owner; the
existing admission worker owns program initialization. It does not change
source art, sampling, private occurrence materials or shader operands.

These source-only CPU controls establish the preparation mechanism, **not**
first-visible-frame, native output parity or final live-game frame acceptance.
The same original Studio journal and fresh issued-command path must now be
measured again, including pipeline counters and every remaining long frame.

## First actual post-repair comparison

Same original journal, view, root/pane resolution and renderer; no competing
GPU jobs or CPU benchmarks. Native recorded-program gate subsequently passes191
assertions, including real worker completion and original/borrowing consumers
remaining pending until actual post-draw. Source/raw exact pixels and private
clocks/materials remain unchanged. Receipt:
`.runtime/tests/20261020T040902.266184Z/`.

The full Studio clip completes without failure in
`.runtime/studio-profile-gallery-preparation-after.json`: p50/p95/p99/max
7.395/12.774/17.016/40.745ms, with66frames>16.667ms and3>33.333ms. Its worst
frame was61.052ms and7frames>33.333ms before the repair. Native preparation
construction now peaks1.470ms; timeline media readiness20.690ms and path-set
projection.308ms. The overall frame distribution has not become uniformly fast;
the specific repeated/preparation costs improved. First publication remains
5,213.274ms, versus5,210.545ms; startup has not improved and is still open.

Fresh live run `.runtime/player-runs/20261020T041020.322094Z/` passes313checks,
zero script/engine errors and owned leftovers. Within the same27-command window:
7030frames, p50/p95/p99/max6.909/13.699/17.645/135.961ms,
96frames>16.667ms and2>33.333ms. Recorded native construction peaks1.809ms,
versus the previous54–57ms Chill Touch envelope. Media readiness peaks10.572ms.
Door input→first animation176.107ms; Fireball201.236ms. The constructor repair
does not claim input-latency improvement.

### Separate large optional texture transfer

The135.961ms frame occurs during later Fire Bolt command25, not the repaired
Chill Touch construction. Main Play/HUD costs11.004/.163ms; renderer counters
stay unchanged across adjacent frames, with last-available render CPU.427ms and
GPU.504ms. It is not established as a shader-compile stall.

The actual optional stone-bench broken-geometry sheet is26112×1536 RGBA8,
160,432,128bytes (153MiB). Its worker PNG load takes288.158ms, followed by an
83.082ms worker texture upload, started52,905,580us and finished52,988,662us.
That upload overlaps the long observed interval52,921,210→53,057,171us;
reported video residency rises240MiB then153MiB across adjacent frames.
Publication itself is inexpensive and readiness was not held. The overlap
identifies a concrete large-transfer candidate, not proof that this transfer
accounts for every remaining millisecond. No art downsampling, texture-format
change or speculative graphics workaround is applied. Repeat trials and a
bounded native transfer/publication study remain separate from provider work.

Original full profile:
`generated/profiles/2026-10-20T06-11-23-gallery-live-spells.json`; original worker
clock and byte operands are retained at frame6872's media publication. Source
inputs, raw captures/profiles and reports remain outside the code checkpoint.

### Repeatability after repair

All three independent issued-command trials pass313checks each, with no
script/engine errors or owned leftovers. Identical launch settings and command
route; original reports and worker traces remain in each run.

| Trial / run suffix | Frames | p50 /p95 /p99 ms | Max ms | >16.667 / >33.333ms | Native construction max ms | Door /Fireball input→animation ms |
|---|---:|---:|---:|---:|---:|---:|
|1 /041020.322094Z|7030|6.909 /13.699 /17.645|135.961|96 /2|1.809|176.107 /201.236|
|2 /041352.586436Z|7027|6.706 /13.462 /17.220|59.376|83 /2|1.622|183.230 /196.247|
|3 /041506.709528Z|7541|5.842 /12.581 /15.966|38.360|54 /1|1.686|173.062 /185.473|

The repeated54–57ms recorded-construction pause is absent in all three new
trials. Full-frame time and input latency remain distinct: the new frame tails
still fail the final no-spike target, and the first two trials' ordinary
distributions are slower than the earlier baseline. The long optional transfer
is not the only open interval: all three trials also show35–39ms during the
first end-turn, and trial2's later Fire Bolt reaches59.376ms with8.243ms measured
Play CPU. Those intervals retain their exact counters rather than being assigned
to compilation without evidence. No blanket final-performance claim follows.

Aggregate:
`.runtime/consolidation/preparation-after-three-trials.json`.
Invocation results:
`.runtime/consolidation/preparation-after-live-{1,2,3}/result.json`.

### Bounded next transfer cohort — deferred during provider migration

Read-only ownership review locates the shared boundary: `media_warmup.gd`
sets `request.worker_upload` for every new physical texture, including optional
priority2 work, and `_decode()` creates the entire ImageTexture on that worker.
Play's2ms publication allowance receives that completed texture; it does not
bound the earlier GPU transfer. A withdrawn request is checked at receipt,
after upload, so optional intent alone cannot make that transfer harmless.
The recorded overlap above remains correlation, not a full135.961ms attribution.

Reuse the existing lossless bank-page path before considering another runtime
system. `tools/presentation_build/environment.gd::_page/_paginate` already
copies whole cells into1536×768 RGBA8 pages and verifies saved cell bytes;
`SourceCatalog._layout_region()` translates the source rectangles. The bench's
384×384 cells would occupy34pages of4.5MiB instead of one153MiB sheet. A settled
four-view endpoint of that sheet needs at most four such pages (18MiB); a full destruction
still needs its actual finite source closure. This reduces transfer granularity,
not necessarily total bytes or a proven frame-time bound. Originals, authored
clocks/registration, numeric encoding, paint and lighting must remain unchanged.

Generic activation must follow measured source size using the existing16MiB
eligibility policy, rather than a bench-name runtime special case. Before it is
enabled, audit source/selected-normal cell consistency and companion aliases:
`SourceCatalog.texture_layout()` currently remaps geometry/normal only, while
`door_frame()` returns raw bank numeric regions without that remap. An eligible
door's frame could therefore retain the oversized original despite a paged leaf.
Support, hit-mask and door-partition references must retain their own exact
contract; do not assume they share geometry cells or silently rename them.
The all-source header inventory was deliberately stopped once this structural
risk was established; no complete source-count or total disk-budget claim is made.

Required gates: retain the independent original-cell/corner/all-view/all-frame
and finite-versus-settled closure assertions in
`environment_texture_layout_checks`; replace its current six-layout/three-bank
inventory assumption with actual independently measured eligibility. Add native
raw-atlas versus paged output parity, including door frame/leaf, selected normals,
endpoints and animation frames, before generic activation. Required received
world/destruction cuts keep precedence and preparation; suppressing an optional
variant must never omit a due source or defer the real destruction. Then repeat
the same live command window and inspect upload/whole-frame tails. No paging,
asset packing, runtime change or graphics acceptance occurred in this review.

### Whole-cell numeric pages — implementation awaiting qualification

The bounded follow-up now uses the existing environment builder for every
oversized RGBA8 depth/original-normal or selected receiving-normal source,
rather than the three manually selected banks. The independent header inventory
contains **171 eligible physical files**; the independent grayscale support
files remain separate. The threshold is strictly greater than16MiB of decoded
RGBA8; cells retain every source byte and occupy pages of at most1536×768
(**4.5MiB**). Color sheets, source files, source clocks, sampling transforms,
normal selection and physical registration are unchanged. This is a transfer
size bound, **not a demonstrated frame-time bound**.

`source_catalog.gd` now applies the same address mapping to both door-frame
branches and every matching current physical alias: geometry, normal, support,
hit mask, door partition and role mask. Independent masks/support files keep
their original paths. Door frames keep their existing original-normal policy;
leaf/body sources keep their existing selected receiving-normal policy. The
three existing layouts retain their output directories and addressing.

The builder owns a small `texture_page_cache.res` output containing original
length/mtime, cell/page-layout generation and derived-output length/mtime. An
unchanged repeated build reuses its pages without decoding/repacking the sheets;
changed source/registration or a missing/changed page requires packing again.
No runtime reader, runtime stamp/hash check or source-art mutation is introduced.
First generic build cost and output file count still need measurement.

Qualification gates prepared for the exclusive build/native lane:

- `environment_page_build_checks` (headless): independent9-cell RGBA control,
  partial final page/transparent padding, original immutability, eligibility,
  offline reuse invalidation and exact current physical aliases. This replaces
  the same tiny control in the obsolete Python wrapper that imports the removed
  `tools.prepare_environment_texture_layout` implementation; it does not claim
  that obsolete Python implementation remains supported.
- `environment_texture_layout_checks` (headless, full offline gate): independent
  current typed-source/PNG-header eligibility, every original cell/page corner,
  preserved original three layouts, actual all-frame/all-view bench plus prior
  banks, finite/settled demand closure and door-frame original normals.
- `native_environment_texture_layout_checks` (GPU): strict RGBA original-sheet
  versus paged output through the production spatial material and light table,
  lit/normals modes, all four views, bench finite/page-boundary/settled samples,
  and directional/elegant/shabby-battens door leaf/frame/destruction. Existing
  `door_overlap_checks` remains the independent original painter-partition oracle.

No new build, native output or post-change live profile is claimed here yet.

Offline control qualified: `environment_page_build_checks` **69checks/0failures**
in `.runtime/tests/20261020T060222.303186Z`. The retired executable Python
wrapper `tests/test_environment_texture_layout.py` imported the already removed
`tools.prepare_environment_texture_layout.paginate`; it tested a9×6RGBA source,
3×2cells and6×4pages (nine cells, three pages), exact cell bytes, transparent
final-page padding and unchanged original file bytes. Those exact assertions
are retained in the69-check current-builder gate, alongside eligibility,
registration, reuse invalidation and alias controls. This is an explicit
replacement of that obsolete implementation-bound wrapper, not a claim that
its removed Python packer executes. Full source-cell/native/live qualification
remains pending.
