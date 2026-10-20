# Gallery issued-command and Studio profile — 20 October

The entries below are chronological evidence. The latest e102 ownership repeat
is in the final section; the original c494 header describes only its baseline.

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

### Post-paging issued-command runs — measured transfer benefit and remaining gaps

Original runs `.runtime/player-runs/20261020T062223.103394Z`, `062335.893012Z` and `062448.928047Z` each pass **313checks/0failures**, with zero script/engine errors or owned leftovers in `.runtime/tests/20261020T062220.033956Z`. The complete machine report is `.runtime/consolidation/paged-gallery-three-analysis.json`; it retains every >16.667ms frame, disjoint measured scopes, exact overlapping worker clocks/paths/bytes, and the client/server stage operands.

**Comparison limit:** these supplied runs use camera size **12**, while all three previous0410/0413/0415 runs used **18**. Both use1600×960, Forward+/Vulkan/RTX5090 and ordinary issued commands. The following distributions cannot establish an isolated paging A/B improvement. A matched zoom18 repeat remains required. No GPU capacity is inferred from the configured cache budget.

All frames from first command input through final command completion are included, including inter-command intervals; startup, test validation/export and readback are excluded. Selection uses `first_input_us <= interval_end_us <= final_command_end_us`, matching the prior report; the first interval straddles the input boundary.

|Trial / run suffix|Frames|p50 /p95 /p99 ms|Max ms|>16.667 / >33.333ms|
|---|---:|---:|---:|---:|
|1 /062223.103394Z|7538|5.973 /12.424 /16.180|35.566|66 /1|
|2 /062335.893012Z|7643|5.993 /12.046 /15.603|36.266|53 /1|
|3 /062448.928047Z|7705|5.752 /11.896 /15.584|41.900|52 /1|

The previous zoom18 maxima were135.961/59.376/38.360ms. Each new run has one >33.333ms frame, all during the first end-turn, rather than the later bench transfer. Remaining tails are still real; the no-spike target is not met.

**The specific large numeric transfer changed.** No new measured-window worker load/upload uses either153MiB whole bench numeric source. All68 unique bench pages are actually admitted (34depth +34selected-normal); each unchanged RGBA8 page is4.5MiB and the complete unique pair remains306MiB. Worst observed page PNG-load times are9.231/9.432/9.200ms; worst page worker-upload times are **2.540/2.678/11.623ms**, versus prior whole-sheet uploads up to83.082ms and PNG-load around288ms. These are actual source/worker measurements, not a page-size-derived frame-time promise.

Optional residency still churns:95/134/136 page **decode admissions** occur for those68 unique paths. Actual `created=true` texture counts are74/95/99, totaling333/427.5/445.5MiB of conservative created-texture estimates; some decodes rehydrate CPU data while reusing a GPU texture. Before paging, the original pair also decoded twice per run; actual GPU creations were3/4/2 ×153MiB. Therefore neither repeated decoding nor every published `gpu_estimated_bytes` row is automatically a new GPU transfer.

The repeat witnesses are at the configured **16GiB combined cache budget**: about17.17GB estimated residency,15,321,792,512bytes of character pins plus0.84–1.04GB environment pins, with eviction counts rising (trial1:1576→1714). This establishes a retained-family/residency pressure gap; it does not establish which individual repeated admission was unnecessary or the GPU's physical capacity. Source-specific clocks and the residency snapshots are in the machine report.

**Remaining long-frame decomposition:** measured main-thread scopes below are mutually exclusive; inclusive parents are not added to their children. Renderer values are the last available viewport counters and may lag.

- Trial1 frame1171:35.566ms =7.590ms Play +0.117ms HUD +0.215ms profile diagnostics +**27.644ms unallocated wall**. Largest disjoint Play scopes: component sampling1.536, lighting1.349, optional component owner1.050, native output0.857ms. A7.5MiB modular `Melee1/CrouchRun.png` worker upload (31.410ms total) overlaps26.567ms of the frame; its depth companion overlaps14.007ms. Last render CPU/GPU .327/.396ms; pipeline counters unchanged. This is overlap evidence, not a complete stall attribution.

- Trial2 frame1055:36.266ms =17.143ms Play +1.100ms HUD +0.186ms diagnostics +**17.837ms unallocated wall**. Preparation-step7.315 and timeline advance4.471ms are disjoint. Nested `media_plan`7.653/`media_plan_demand`4.684ms explain part of those envelopes and are **not extra addends**. No published worker load/upload interval intersects this frame. Last render CPU/GPU .361/.384ms; counters unchanged.

- Trial3 frame1063:41.900ms =8.268ms Play +0.178ms HUD +0.197ms diagnostics +**33.257ms unallocated wall**. Component sample1.816, lighting1.441, optional component owner1.115 and native output0.865ms dominate the disjoint measured scopes. The7.5MiB `modular-profiles/reference/Melee1/Attack6.png` loads for13.186ms and uploads for19.211ms; overlap is12.940/19.211ms. Last render CPU/GPU .309/.416ms; counters unchanged. No blanket CPU/GPU/driver attribution is justified.

Other >16.667ms frames are retained rather than discarded: e.g. trial1 move5 frame1528 is26.725ms with13.916ms preparation-step (nested media planning11.078ms, demand9.573ms); trial2 room-move frame637 is26.533ms with8.664ms lighting (nested modular shadows8.159ms); trial3 post-ready frame1091 is23.735ms with6.248ms preparation and6.096ms HUD. No worker intersection is needed to explain these measured scopes.

**Input→first animation decomposition:** all following intervals use the same Godot monotonic clock and add to the observed total. Input→send includes the actual preview round trip for door/Fireball; movement submits directly without waiting for preview. Fold/compile/opening are client preparation elapsed intervals, not an assertion that the display thread was blocked for their duration. The final publication/observation remainder is not a single CPU function.

|Action / trial|Input→send|Sent→framed|Admission|Fold|Compile|Opening|Publication/observe|Total ms|
|---|---:|---:|---:|---:|---:|---:|---:|---:|
|Door1|16.742|62.245|4.997|31.831|7.115|5.549|51.704|180.183|
|Door2|20.516|62.354|4.889|32.859|8.440|4.935|43.790|177.783|
|Door3|16.436|58.419|4.553|35.128|9.232|6.653|50.186|180.607|
|Room move1|3.179|85.706|3.327|85.122|5.210|8.432|18.284|209.260|
|Room move2|4.204|74.616|3.695|83.978|8.101|10.666|22.514|207.774|
|Room move3|2.972|73.086|2.441|75.330|5.544|8.208|21.453|189.034|
|Fireball1|25.220|70.668|1.921|33.720|10.761|9.780|48.944|201.014|
|Fireball2|21.728|69.905|1.922|35.085|7.822|7.411|56.503|200.376|
|Fireball3|20.400|66.475|2.011|33.774|8.678|7.631|45.248|184.217|

Independent server dispatch durations (same actor + actual command number) are30.261/30.321/30.150ms for door,51.028/48.062/48.874ms for room move and45.970/50.783/46.026ms for Fireball. They are server-clock durations, **not extra addends or client/server timestamp subtraction**. Full server execution/audience components are retained in JSON.

Client work still dominates particular movement responses: room move canonical folding is85.122/83.978/75.330ms (nested reduce83.430/82.681/73.988ms, chiefly fact/world folding). Move5 folds122.594/84.675/82.396ms; trial1 includes27.294ms commit. Move8 reaches279.521/293.090/272.750ms: its compile interval124.335/124.343/118.245ms contains **schedule_delivery110.529/110.744/105.019ms**; the other compiler leaves total roughly13ms. This is the next named client latency leaf to decompose, separately from remaining frame/transfer gaps and Factory integration. No runtime/source change follows from this report alone.

### Move8 attack metadata ownership — bounded repair and exact-prefix proof

The105–111ms `schedule_delivery` leaf above is the first real opportunity attack, not a long movement path: original journal sequence32 has two Step facts, the goblin's actual `reaction.opportunity_attack`, its applied/taken damage and the recipient HP after-value. A private instrumented copy compiled the unchanged prefix on a preparation thread. It subtracts recursive child scheduling before reporting each node's own work; source admission, occurrence copying and variant selection are separate leaves. No server/GPU launch or scheduler clock change was involved.

The cold cost was native metadata admission plus redundant ownership: the abilities builder embedded the same135-pose measured trail bank four times in a3,857,268-byte Variant table, and every attack deep-copied one entire recipe although the goblin cannot use a modular weapon trail. The original measured source is `assets/measured/abilities/attacks/action.attack.trail.json`, shared by four actual typed attack owners. Variant selection itself was only about0.3ms.

The existing abilities builder now writes each exact rig/category/clip pose once under its authored source path. The small recipe table retains exact pose document locators; `Components.weapon_trail` admits a pose only after selecting the actual eligible equipped layer. `Authoring.attack` gives each occurrence its own shallow recipe shell and borrows immutable nested authoring. Source locators, selected geometry/palette, impact art, body/audio/effect clocks and ordered commits are unchanged. All condition/impact/trace consumers were checked; none needs the full pose bank.

|Same original sequence32, preparation-thread probe|Before|After|
|---|---:|---:|
|Cold native attack table admission|85.532ms|6.871ms|
|Cold occurrence recipe copy|11.669ms|0.004ms|
|Cold recursive scheduling total|98.312ms|7.684ms|
|Cold whole compilation|108.744ms|11.565ms|
|Warm scheduling, three repeats|10.580–11.270ms|0.593–0.680ms|
|Warm whole compilation, three repeats|20.344–22.035ms|3.394–3.724ms|
|Recipe table Variant bytes|3,857,268|383,860|

This is a12.8× cold scheduling reduction in the controlled original-prefix probe; **the later live three-trial run has not been repeated for this repair**. The entire compiled result equals the retained pre-split original Dictionary exactly, including all tracks, components, commit timing/deltas and final state. The input state, admitted packet, final canonical state and original journal bytes remain unchanged. The goblin admission loads no modular pose document. Probe evidence: `.runtime/consolidation/move8-delivery-leaves.json` and `move8-delivery-after-leaves.json`; retained original compilation and source table are private binary artifacts beside them.

`attack_recipe_admission_checks` passed **3186 checks/0 failures**: all five actual typed attack owners, every one of the135 original measured pose payloads/provenance,297 independent pre-split selector and actual outfit/pose controls, shared physical admission across aliases, and private occurrence shell/source immutability. It reconstructs expectations from the typed authoring and original measured file, not the runtime selector's answer. Parent exclusive abilities rebuild passed in4.5s with0 errors. This qualifies metadata ownership and exact compilation; it does not declare new artwork approved or replace existing native graphics gates. Engine log: `.runtime/consolidation/attack-recipe-admission-engine.log`.

### Shared-provider live checkpoint —20 October08:02UTC

Actual unchanged Gallery sorcerer live route,27issued client commands,1600×960,
camera size12, Forward+/Vulkan/RTX5090; frozen schema16 engine unchanged.
`.runtime/tests/20261020T080237.031410Z/summary.json`: **313checks/0failures,
zero script/engine errors, zero owned leftovers**,69.8s. Original run:
`.runtime/player-runs/20261020T080239.915794Z`.

The earlier075248run also completed313assertions but emitted20,185 `Invalid
Task ID` errors in selected-media polling; it is a failed run, and its timings
are not acceptance evidence. No duplicate SelectionMedia client join was found.
A diagnostic rerun with task lifecycle prints passed313/0 without errors before
the repair, establishing an intermittent failure rather than a deterministic
client double join. Passive ability/Factory phase metadata still bypassed the
existing isolated SourceMetadata reader from pool workers. Those reads now use
that same reader; native constructors/GPU loading and presentation clocks are
unchanged. Cold worker/replacement/cancel/close gate17/0, actual body-source
reload30/0 and attack admission3186/0 pass. The exact engine token invalidator
has not been proven; one clean post-change live run does not establish permanent
elimination of that intermittent error. The separate definite audio failed-load
consumed-token bug is fixed and independently qualified55/0 plus260 existing
audio assertions, without retrying missing sources each frame.

The first actual opportunity attack, sequence32/command8, now schedules in
**8.787ms** and compiles in13.372ms, compared with the prior same zoom12 live
schedule105.019–110.744ms/compile118.245–124.343ms. This is an observed11.95–12.60×
reduction in that shared leaf after splitting/borrowing the immutable pose bank;
the full response still includes server/transport, folding and publication.
No individual spell art changed.

|Actual command|Input→send|Send→admission|Admission|Fold|Compile|Opening|Publication/gaps|First visible total|
|---|---:|---:|---:|---:|---:|---:|---:|---:|
|Door1|15.176|63.879|4.910|32.580|13.061|8.430|41.951|179.987ms|
|Room move2|3.580|73.648|2.463|72.097|6.707|7.667|16.282|182.444ms|
|Opportunity move8|3.372|65.730|10.780|45.695|13.372|7.143|21.384|167.476ms|
|Fireball13|17.638|55.157|1.804|30.996|7.458|7.532|44.889|165.474ms|

All columns are disjoint same-Godot-clock intervals and sum to the observed
first animation. Send→admission includes server, transport, framing and queue
work, not exclusively server execution. Publication/gaps includes exact small
between-stage gaps; it is not one timed function. Opening is the actual opening
witness, not the full later preparation job: the latter continues after visible
animation (e.g. Door full metadata183.6ms), without delaying ordered publication.

All7,227frames between first input and final command completion: p50 **6.126ms**,
p95 **12.167ms**,p99 **15.650ms**,maximum **33.064ms**;46frames>16.667ms,none>33.333ms,
no recording eviction. The largest frame is first end-turn:7.805ms Play +.221ms
HUD +.152ms diagnostics +24.886ms unallocated wall. Do not attribute that remainder
without more evidence. Another27.617ms frame has18.589ms HUD work (inclusive
subscopes are not additional addends). These remain actual performance gaps;
this is not a no-spike or100fps-every-frame claim. The new Factory/provider
qualification continues rather than reopening per-spell performance tuning.
Full operands/compiler leaves and worst-frame scopes are in ignored machine
report `.runtime/consolidation/shared-provider-live-gallery-20261020T080239.json`.


## e102 passive-ownership repeat, second provider batch

The first repeat failed with native heap corruption, not an assertion failure:
`.runtime/tests/20261020T082151.393677Z/summary.json`. The dump contains concurrent
passive GDScript reads. [The ownership change](PASSIVE_RESOURCE_OWNERSHIP_2026-10-20.md)
serializes actual passive admission and retains/coalesces physical Resources in
the existing owners. Exact heap-corruption causality is still unproven.

After that change, two sequential fresh live processes pass313/0 each, with zero
script/engine errors or owned leftovers:
`.runtime/tests/20261020T083526.571661Z/summary.json`. Actual game directories are
`.runtime/player-runs/20261020T083528.770523Z` and
`.runtime/player-runs/20261020T083637.843781Z`. They issue the same27commands on the
same frozen engine and installed e102 package; no concurrent owned GPU/profile
jobs or recorder measurements ran during these windows.

| Trial | Frames | p50 / p95 / p99 ms | Maximum ms | Frames >16.667 / >33.333 ms |
|---|---:|---:|---:|---:|
|1|7297|5.912 /12.200 /15.783|62.541|41 /2|
|2|7702|5.613 /11.760 /15.400|70.469|46 /1|

Exclusive intervals use only the client's monotonic clock. Sent→admission
includes server/network/framing/queue; publication/gaps is remaining wall time,
not a named CPU function. Full server execution is not newly instrumented here.

| Action / trial | Input→send | Sent→admission | Admission | Fold | Compile | Opening | Publication/gaps | Total ms |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
|Door1|15.237|48.158|5.981|29.869|7.131|4.149|100.997|211.522|
|Door2|18.202|64.742|6.530|30.714|9.860|4.787|77.833|212.668|
|Room move1|2.824|62.567|2.809|68.764|6.128|8.117|19.849|171.058|
|Room move2|2.471|66.723|2.893|73.051|6.506|8.280|15.076|175.000|
|Opportunity move1|4.019|56.072|10.280|45.234|13.955|7.505|19.591|156.656|
|Opportunity move2|4.119|57.847|10.460|44.047|13.931|6.924|23.246|160.574|
|Fireball1|19.256|56.462|2.737|32.177|8.371|7.933|43.926|170.862|
|Fireball2|19.961|80.885|2.130|35.422|8.452|7.404|48.416|202.670|

The shared attack schedule stays at9.730/9.219ms, versus105–111ms before physical
recipe sharing. Source read ownership does not claim an input-latency win.

Worst-frame decomposition, with nested scopes kept separate:

- Trial1 frame986,62.541ms: Play19.026ms and HUD.998ms; approximately42ms remains
  outside those measured scopes. Nested inside Play are session11.911ms and
  preparation7.429ms; media plan7.365ms includes demand4.484ms. These are not
  independent extra addends.
- Trial1 frame313,36.275ms: Play35.094ms and HUD.110ms. Its actual door-reveal
  work includes world sync15.873ms (ground11.929ms), lighting9.265ms
  (shadows7.541ms) and session4.547ms. This is measured client work, not an
  unallocated server wait.
- Trial2 frame1066,70.469ms: Play23.593ms and HUD.163ms leave approximately46ms
  unallocated. Session15.569ms contains timeline13.528ms/media ready13.161ms.
  Optional dispatch4.610ms, component preparation4.212ms and media sources3.248ms
  are nested work. Last-available render CPU/GPU are.379/.705ms; their counters
  may lag and do not prove a pipeline cause.
- Trial2 frame1073,26.969ms: Play24.116ms and HUD.147ms. Session20.224ms contains
  media plan12.266ms (demand8.208ms), timeline10.687ms/media ready9.847ms and
  preparation9.318ms (component4.088ms). Parent/child scopes must not be summed.

Machine decomposition is
`.runtime/consolidation/passive-admission-gallery-repeats.json`. There is no
recording eviction. These are two clean correctness repeats after containment,
not a no-spike/permanent-crash-fix or100FPS-every-frame claim. Shared migration
continues; the remaining frame and publication tails are explicit final-scale
qualification work.


## Typed-dispatch/spatial-publication final live qualification

The combined165fast and two native gates finished before this fresh live run;
no owned GPU job, recorder or CPU benchmark overlapped its measurement. Same
frozen engine, e102 package and27actual player commands. Receipt
`.runtime/tests/20261020T092008.343570Z/summary.json`: **313/0**,69.7seconds,
zero script/engine errors or owned leftovers. Actual game directory:
`.runtime/player-runs/20261020T092011.298204Z`.

From first command start_frame through final command end_frame,6736frames:
p50/p95/p99 **6.494/13.220/16.833ms**,maximum **76.273ms**;73frames exceed16.667ms,
two exceed33.333ms, zero recording eviction. These remain insufficient for the
100FPS/no-spike gate. This single correctness/profile repeat is not a matched
three-trial performance improvement claim.

Exclusive same-client-clock stage milliseconds:

| Action | Input→send | Sent→admission | Admission | Fold | Compile | Opening | Publication/gaps | First animation |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
|Door|15.121|48.041|4.915|29.067|7.745|3.729|94.250|202.868|
|Room move|2.691|76.241|2.569|75.316|6.605|7.963|18.714|190.099|
|Opportunity move|4.389|80.070|14.751|51.600|19.441|10.694|26.798|207.743|
|Fireball|21.375|72.810|1.950|33.567|8.023|7.306|43.073|188.104|

Opportunity scheduling13.306ms remains below its earlier105–111ms source-load
bottleneck, but is slower than the preceding9.2–9.7ms repeats. There is no causal
attribution from one timing sample. Fireball's nested fold is32.025ms reduce,
.865ms stage and.625ms commit; reducer world16.506ms/facts12.209ms are inside
reduce. Its compiler7.902ms envelope contains schedule.796, event trace2.326,
lineage1.557, input shell1.084, actor cuts.916, components.554, requirements.406,
ending.241 and disclosure.018ms. Rounding/envelopes are not extra independent
stages. Send→admission still includes server/network/framing/queue, not only
server CPU. Publication/gaps is remaining wall time, not a timed function.

Two largest measured frames:

- Fireball frame3267,76.273ms: Play11.732ms; after Play/HUD/diagnostics,
  **64.092ms remains unallocated**. Nested optional preparation5.631ms includes
  residency3.812ms and CPU release2.788ms; actor sample2.693ms and native2D
  lighting1.360ms are other nested work. Last-available render CPU/GPU
  .635/.534ms and pipeline counters cannot establish the unallocated cause.
- Frame975,49.557ms: Play19.809ms and29.355ms unallocated after
  Play/HUD/diagnostics. Session13.503ms includes timeline8.945ms/media ready
  6.773ms; media plan5.018ms and preparation4.291ms/component3.913ms are nested
  scopes. Do not sum parent and child timings or label the remainder as server
  work or shader compilation without more evidence.

Original full scopes, exact commands and derivation are retained in
`.runtime/consolidation/shared-variant-spatial-live-analysis.json`, the game
trace files and its original generated frame-profile path. Shared source
integration continues independently of these documented final-scale limits.

## Latest: persisted ownership and save-result selection

Actual issued-command Gallery,313/0, zero script/engine errors and owned
leftovers: `.runtime/tests/20261020T095307.551688Z/summary.json`.
Run `.runtime/player-runs/20261020T095309.982218Z`; original full frame dump
`generated/profiles/2026-10-20T11-54-09-gallery-live-spells.json`.
No correctness suite, source build or recorder ran concurrently with profiling.

The27command interaction window contains7,422frames, with no profile eviction.
p50/p95/p99/max: **6.070/12.319/16.029/71.206ms**;58frames exceed16.667ms and
two exceed33.333ms. This is a fresh qualification run, not a controlled speedup
claim. The final100FPS/no-spike gate remains open.

Exclusive input-to-first-animation stages, milliseconds:

| Command | Input→command sent | Sent→SSE admission | Admission | Canonical consumer | Compile | Opening | Publication/gaps | Total |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Door1 |16.432|61.628|5.199|30.671|9.802|4.464|80.081|208.277|
| Room move2 |4.047|83.769|4.453|76.246|6.393|7.709|16.407|199.024|
| Opportunity move8 |2.935|66.051|10.628|46.311|12.783|7.095|26.568|172.371|
| Fireball13 |18.857|55.956|1.794|31.218|8.767|7.898|43.878|168.368|

Sent→admission includes server, transport, framing and queue time, not measured
server execution alone. Publication/gaps is the remaining observed interval,
not a claimed named CPU task. Nested Fireball fold: reduce29.898ms, stage0.640,
commit0.643; world14.841/facts11.881 are within reduce. Its compiler reports
event trace2.277, lineage inputs1.688, input shell1.359, delivery1.113, actor
cuts0.857, components0.699, requirements0.357 and ending0.217ms. Opportunity
move delivery8.658ms stays far below its historical105–111ms; the canonical
fact fold is still33.589ms within reduce44.928ms.

Worst frame1196:71.206ms, Play26.030/HUD0.108/diagnostics0.189, leaving44.879ms
unallocated by these scopes. Play includes session/timeline20.326ms, preparation
12.832, media plan8.935, timeline advance7.209/readiness6.886, demand5.210,
prioritization3.490 and component preparation3.372ms. These scopes nest.
Last available render CPU/GPU samples0.347/0.401ms do not explain the remainder.
Frame7324 is36.789ms: Play8.181/HUD0.441/diagnostics0.351 leave27.816ms;
its largest measured Play tasks are actor sample2.682 and session2.450ms.
No source, driver or scheduler cause is asserted without a matching measurement.

Exact stage derivation, compiler/fold leaves and complete two-worst-frame scopes:
`.runtime/consolidation/shared-save-variant-live-analysis.json`.

## Post-production routing and anatomical-region regression receipt

Actual issued-command Gallery313/0, clean script/engine logs and no owned
leftovers: `.runtime/tests/20261020T105026.539610Z/summary.json`. Source and
headless/native suites had finished before this run. One3.6second offline read
of the previous profile occurred near startup, so this is a functional/timing
receipt, not a quiet controlled A/B performance experiment.

Run `.runtime/player-runs/20261020T105029.248040Z`; full dump
`generated/profiles/2026-10-20T12-51-27-gallery-live-spells.json`. All27commands'
interaction window has7017frames, zero evictions. Sorted-floor percentiles
p50/p95/p99/max are **6.398/12.799/17.026/65.025ms**;80frames exceed16.667ms and
two exceed33.333ms. Prior71.206ms and current65.025ms maxima do not prove an
optimization; this batch integrates production ownership, not performance work.

Exclusive input-to-first-animation stages, milliseconds:

| Command | Input→sent | Sent→admission | Admission | Fold | Compile | Opening | Publication/gaps | Total |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Door1 |15.865|63.621|4.980|29.426|10.151|5.046|86.631|215.720|
| Room move2 |3.592|92.103|2.524|76.146|6.492|7.836|14.760|203.453|
| Opportunity move8 |3.145|69.957|10.573|48.367|14.867|7.098|21.138|175.145|
| Fireball13 |35.336|57.951|1.912|32.786|8.937|7.793|24.401|169.116|

Sent→admission includes server/transport/queue; it is not server execution alone.
Publication/gaps is an observed remainder, not an invented named CPU cost. Room
move's nested reduce74.387ms includes48.965facts/19.389world. Fireball reduce
31.011ms includes11.883facts/15.804world; stage1.058/commit0.669. Its compiler
reports trace2.553, lineage1.482, shell1.247, actor cuts1.054, delivery0.919,
components0.710, requirements0.459, ending0.284ms. Opportunity delivery is10.500ms.

Worst frame3418 is65.025ms: Play16.208/HUD+diagnostics0.569, leaving48.248ms
unallocated. Play includes optional preparation8.184, residency5.199, CPU-media
release3.812, session3.045, actor sample2.931, owner preparation2.885 and component
prefetch2.629ms; these scopes nest and must not be added. Latest render CPU/GPU
samples0.384/0.685ms do not explain the remainder. Frame1069 is41.796ms:
Play8.222/HUD+diagnostics0.373 leave33.201ms; largest nested scopes are actor
sample3.279, components2.256/native1.974, lighting1.625 and session1.248ms.
No driver/source/scheduler cause is assigned without matching evidence.

Exact complete source:
`.runtime/consolidation/production-closure-live-analysis.json`. This preserves
the open frame/latency work without interrupting the production migration for
another optimization detour.
