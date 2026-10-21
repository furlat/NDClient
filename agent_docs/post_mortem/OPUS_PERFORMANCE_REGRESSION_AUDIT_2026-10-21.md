# Opus speed work: preservation, regressions and introducing changes

21 October 2026. Human-requested post-mortem. Implementation and runtime
testing remain stopped. This audit reads source, Git history and saved
receipts; it does not run a client, benchmark, build, recording or test. Pending
repair patches remain unapplied. Engine and Factory sources are read-only.
All art/audio remain unreviewed.

## Findings that answer the attribution question

**Several avoidable regressions have identifiable introducing changes.** The
largest newly traced playback stall is in environment metadata, where residue
integration put repeated whole-visibility work inside an existing local-row
operation. Other losses concern reducer mutation processing, Studio background
work and parse reuse. Preserving the old scheduler did not prevent new work
from overrunning its preparation lead time.

| Change | Introducing commit | Source-confirmed loss / measured boundary |
|---|---|---|
| Local environment source lookup repeatedly reconstructs global visibility | **`291e092c`** | `EnvironmentMedia._update -> _collect -> World.rows -> residue_projection` rebuilds `Cells.point_set(visible_positions(state))` for each changed tile/object cell, including partial states without residues or tiles. The same named required-worker leaf rises from Door42.264ms / Move17.398ms in the nearest pre-Sol saved run to Door629.598–857.218ms / Move581.752–599.312ms. The entire increase is not an isolated benchmark of this one loop. |
| Event processing adds complete actor/item map passes | **`119ddede`** | Copies both collection shells for every node, even without recorded transitions; recorded folds scan both stores for identity changes. New work is proportional to events × held actors/items. Immutable leaves remain borrowed. |
| Sensory fold loses the old retained indexing route | **`119ddede`** | Decodes, builds a population, sorts/re-encodes and reindexes visibility even on contact-only updates. The old `_sensory_context` argument survives unused. Source loss is real; latest Door facts timing actually improves, so this is not an exclusive explanation of that slower fold. |
| Library loses worker construction and bounded Tree publication | **`119ddede`** | Replaces background/generation adoption and at most24rows/2ms publication with synchronous catalog construction and complete Tree rebuilding. Every search change rebuilds matching rows in one call. Elapsed regression is not isolated. |
| Library reads more uncached JSON; offline packet-zero parses twice | **`291e092c`** | Library open/Refresh reads12.36MiB across five inputs, including the full9.64MB Factory index for its version. Journal.open parses initialization once for identity and again for recorded admission. Baseline parsed it once. Search does not reread those five files. |
| Cold passive metadata adds thread/join and serialized admission | **`f489896f`, `5b12fdf6`** | Explicit physical cache plus cold `CACHE_MODE_IGNORE`, a Godot Thread joined by the worker, then a cross-domain read mutex. Hot cache hits still reuse Resources. These changes repaired nested-loader ownership/deadlock problems; their isolated cost is unmeasured. |
| Equipped item owners cause broad membership processing on unrelated commits | **`78be810b`, expanded `c80cffc5` / `0fdaa552`** | Once owners exist, NativeItems.interested accepts each otherwise eligible compiler commit and playback observation. Location processing scans canonical actors/inventories/loadouts. c80 also improves78 by replacing repeated per-owner membership scans with one aggregate pass. Not a per-frame scan; isolated cost unmeasured. |
| Shared resident Resources can receive another consumer admission/fence | **`24a993f0`** | Removes the global-cache shortcut on consumer-cache misses. An owned threaded request with REUSE is now joined at actual LOADED status and follows the existing draw fence. Consumer hits still skip; shared physical data is not necessarily reread. Correct token ownership was repaired, with added waiting exposure. |
| Actual-actor histories use full viewport targets | **`ba5d0262` provider, `a33d1e59` rolling history; expanded `291e092c` and packages** | Post-baseline actual-actor input supplies full viewport size. Three active Mirror copies use7continuously updated passes. Delayed immutable captures instead draw once. The baseline reference Mirror cue did not have this actual-actor provider. No isolated elapsed cost. |
| Rolling-history predecessor realization is not internally budget-sliced | **`a33d1e59`, expanded `291e092c`** | Sampling can realize a retained prefix in one seed_history loop after ordinary budgeted allocation; a changed camera/view key can require it again. No measured Door/Move cost is transferred to this path. |

These changes explain concrete ways the optimized design was eroded. They do
not establish a percentage attributable to every commit, and they do not imply
that all Opus optimizations were discarded. The path inventory below records
both losses and retained algorithms.

## Baseline and what the numbers actually compare

**Source baseline immediately before Sol implementation:**
`9b73f29a849ac863fe528e5b16f9166e406768af`,19October15:04local. It changes the
plan only; runtime is its parent `1c4b9eb64390f148ee1eb2073cdd00b702d5b74d`,
the final Opus handoff/UID state. The first migration implementation is
`119ddede435ec3a5d646bb518a4a716b03b0d588`, whose direct parent is9b73.
Commit attribution here comes from the actual diff, not Git author names.

Current source inspected: `fc84da2af36c33d5ccda832f3255c19987f18e01` and
the working-tree receiving changes applied before the human stop. Installed
Factory82a has **no quiet performance measurement**. Latest quiet measurements
are the earlier8dd package with engine9f and source5258 plus the saved17:23R6
working-tree diff. The later24a sparse-fold changes were already applied before
those quiet runs; commit time alone would misdate them. The additional
cancellation boundary checks were applied afterward and remain unmeasured.

Three evidence cohorts are kept separate:

1. **18October00:28–00:30UTC, quiet5-command routes:** the original Opus quiet
   receipts,81/0 each. They predate the late18October native-source/character
   migrations. Their full generated profiles are missing; original command and
   pipeline traces survive. No frame quantiles are reconstructed from absent
   profiles.
2. **18October23:12 and19October00:38UTC,27-command functional routes:**311/0
   each, with actual full profiles. The latter is the nearest saved pre-Sol
   profile found. Exact source/contention identity is not certified, so it is
   not relabelled a matched quiet9b73 benchmark.
3. **21October17:53–17:54UTC, three quiet5-command routes:** latest comparable
   original route measurements. Camera size12 versus18 before; producer,
   package, content and update counts differ.

Every compared Door packet has3events,875tiles and5body records. Old packets
are619,552–619,559bytes with108objects/one world update; current packets are
about154,800bytes with111objects/two updates. Common tile counts strengthen
the observation but do not make this a controlled same-content A/B.

Original inventory authorities:
[Opus progress ledger](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/agent_docs/CLIENT_STRUCTURE_PROGRESS_2026-10-17.md:50),
[structure/native-data plan](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/agent_docs/CLIENT_STRUCTURE_AND_NATIVE_DATA_PLAN_2026-10-16.md:421),
[final pre-migration handoff, historical section](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/agent_docs/HANDOFF_2026-10-19.md:98).

## Saved live response and playback regressions

All times below are milliseconds. Independent server duration is not added to
overlapping client/worker intervals.

| Door interval | Earlier18Oct quiet, three runs | Nearest pre-Sol19Oct003839 | Latest21Oct quiet, three runs |
|---|---:|---:|---:|
| Packet → first body animation |60.772 /62.854 /56.165|65.076|149.001 /201.968 /141.714|
| Actual submit → first body animation |198.427 /186.851 /236.064|188.078|203.888 /266.445 /190.565|
| Full gesture → first body animation |216.453 /201.389 /256.168|198.960|219.859 /282.872 /202.518|
| Packet admission |19.087 /23.545 /17.950|20.349|5.981 /8.718 /5.752|
| Canonical fold |15.015 /15.535 /16.495|15.690|26.486 /28.247 /24.737|
| Presentation compiler |4.343 /4.406 /4.776|5.454|8.687 /11.019 /9.688|
| Opening ready → first body animation |18.305 /15.442 /12.493|19.774|103.773 /146.343 /97.345|
| Backend dispatch, separate server clock |83.368 /83.071 /83.765|not used here|32.358 /43.275 /32.706|

The Door packet-to-animation median increases by83.925ms relative to the
nearest saved pre-Sol run. Server dispatch is faster. Admission also improves;
the client has not simply returned to its old slow JSON parser.

The per-trial sum of admission + canonical fold + compiler has median41.154ms
currently versus41.493ms nearest pre-Sol. Fold grows10.796ms and compiler grows
4.234ms, while admission falls14.368ms. Their combined exclusive interval is
essentially unchanged. The larger first-animation regression is after opening
preparation, not explained by adding those three CPU regressions alone.

Selected metadata work waits behind an older cancelled offered-choice task:
the selected Door job takes1.019–1.716ms but queues102.414–170.299ms; the older
aggregate body-path work takes97.998–130.127ms. Queue time overlaps transport
and folding. The single-owner/nonpreemptible body traversal existed at9b73;
new cold metadata overhead is traceable above, but its precise share of that
aggregate is unknown.24a adds cancellation boundary checks; no later quiet
measurement establishes recovery, and work already inside sheet_paths is not
preempted.

### A larger regression after animation has already started

| Sampled readiness hold with an active group | Earlier18Oct quiet and nearest19Oct | Latest21Oct runs1 /2 /3 |
|---|---:|---:|
| Door media wait |0 /0|627.012 /868.700 /603.776|
| Door world wait |0 /0|0 /0 /33.465|
| First room Move media wait |0 /0|350.546 /353.056 /365.354|

These are sampled phase-flag durations, not CPU sums. Saved native samples
independently show source ages stopping near0.25seconds during long wall-clock
gaps, then advancing by a few milliseconds. The increased elapsed playback is
therefore not merely a longer newly authored animation.

During the long Door/Move holds, metadata coverage is false and missing-resource
lists are empty. The source-group guard returns before it can diagnose actual
renderer/path readiness. Once Door metadata is adopted,110actor paths and
35environment paths appear and drain. The early false native/environment flags
do not establish a Factory constructor, PNG decode or shader stall.

The actual delayed owner is the required environment metadata continuation:

| Same named required-worker leaf | Nearest pre-Sol003839 | Current runs1 /2 /3 |
|---|---:|---:|
| Door environment |53.507|665.034 /906.814 /666.929|
| Door environment_commit_updates |42.264|630.678 /857.218 /629.598|
| Move environment |19.707|587.376 /606.565 /606.040|
| Move environment_commit_updates |17.398|581.752 /599.219 /599.312|

The new repeated global visibility construction in291e092c sits inside this
measured leaf. `_update` calls `_collect` separately for changed tile selectors
and object cells. Although each partial state is tiny, World.rows now calls
residue_projection unconditionally. When any floor-residue profile exists,
that function builds the full current visible-cell Dictionary before checking
actual tile residues. Even an object-only partial state with no tiles pays it.
Caching visible_positions only retains the points array, not this Dictionary.
Authored Ashen profile availability activates the work without requiring an
Ashen residue in the encounter.

This is a concrete change from local work to repeated global work, introduced
by291e092c. It is strongly implicated in the measured leaf; the exact fraction
of its582–857ms cost has not been instrumented or isolated by A/B execution.
No claim assigns the entire leaf to a single expression.

Live source-cut boundaries remain disabled as before; early source-interest
publication, metadata coverage guards and Timeline's readiness refusal existed
at9b73. The clock-preserving gate is not a newly inserted artificial hold. The
new metadata work makes an existing real readiness boundary arrive late.

Sources:
[local metadata loop](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/environment_media.gd:124),
[object-cell closure](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/environment_media.gd:166),
[global residue visibility construction](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/world.gd:141),
[unconditional invocation](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/world.gd:243),
[held-clock evidence](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/closing-repairs/opus-packet-path-post-mortem/held-source-clock-review.md).

First Move packet→animation is62.585ms nearest pre-Sol versus71.385–77.253ms
currently. First Fireball is56.152ms nearest pre-Sol versus50.384–52.908ms now:
that onset does not show the same regression. Later Door completion increases
from1432.924ms to2055.398–2387.530ms; content differs, so completion delta is
not an exclusive latency benchmark. The independent held source-clock evidence
is the stronger proof of freezing.

Room-Move canonical fold is12.564–17.601ms in the earlier quiet runs,
15.749ms in the nearest pre-Sol profile, and35.885–36.994ms currently. The
common373tile-row count does not erase producer/update differences, but this
confirms that the canonical cost increase affects more than Door.

## Per-frame paths: what worsened and what survived

The table uses settled same-view idle-stage samples from the nearest pre-Sol
full profile and the three latest quiet profiles. Both have6actors, but camera,
route length, retained effects, marks and private warmup differ. These are
descriptive costs, not controlled speed percentages or exclusive child sums.

| Phase median,ms | Nearest pre-Sol | Latest runs1 /2 /3 | Interpretation |
|---|---:|---:|---|
| Frame |3.567|5.317 /5.755 /4.999|Higher observed steady cost; no isolated introducing commit. |
| Player process |2.699|3.731 /3.978 /3.546|Higher aggregate scene CPU. |
| Component preparation |0.007|0.008 /0.008 /0.008|Opus empty-idle-group reuse survives. |
| Media prioritize |0.026|0.028 /0.028 /0.027|Changed-map due-set optimization survives. |
| Optional maintenance |0.007|0.008 /0.008 /0.007|Settled early return survives. |
| Actor graph arithmetic |0.023|0.024 /0.025 /0.023|Arithmetic clock route survives. |
| Actor sample |0.474|1.013 /0.958 /0.962|Cost rises while unchanged-pose caching still works. |
| Component sample |0.245|0.740 /0.661 /0.695|New active/native work; exclusive cause unisolated. |
| Native spell sample |0.014|0.530 /0.442 /0.494|Different live effects/warmup; do not call equivalent-scene regression. |
| Draw order |0.084|0.575 /0.625 /0.536|Higher observed cost; fractional-gap algorithm survives. New depth-band work is conditional, not proved sole cause. |
| Modular shadows |0.110|0.113 /0.117 /0.111|Median retention gain survives; p95 rises0.203→0.611–0.637. |
| Native2D lighting |0.360|0.372 /0.384 /0.364|No blanket return of the old atlas cost. |
| Source lighting |0.152|0.153 /0.172 /0.151|Similar median. |
| Ground overlay sync |0.003|0.004 /0.004 /0.004|CPU-buffer route survives. |
| Blood fields |0.128|0.074 /0.077 /0.069|Different residue work; no measured regression here. |
| Timeline media readiness |0.300|0.239 /0.246 /0.231|Idle readiness CPU is not the long async metadata wait. |

Idle framep95 rises6.187→8.087/10.706/8.590ms. These samples do not substitute
for the missing exact9b73/current matched quiet run. Latest whole-run maxima
after readiness are55.680/47.080/50.918ms; current82a remains unmeasured.

Snapshots still show6retained actor poses, zero source/UV/outfit rebinding,
6retained shadows, zero shadow updates/new helpers and zero shadow uniform
writes. Shadow helper target pixels remain3,145,728. Thus those old redundant
operations have not simply returned. Draw calls393→459 and global primitives
17,702→2,151,700 are different workloads, including private warming viewports;
the latter is not proof of2million main-camera triangles.

## Optimized-path inventory against the actual starting source

Status describes inspected code and saved evidence, not new runtime
qualification. Paths share owners; rows are not additive costs.

| Opus path / responsibility | Current result versus9b73 | Evidence / attribution |
|---|---|---|
| Protocol schema/identity parse once per path pair | Preserved | Protocol static map/mutex and private per-instance admission caches remain. |
| Current-producer fast JSON, no recursive default expansion | Preserved | Door packet admission improves20.349→median5.981ms. |
| Normalize once, canonical final state/transitions handed to compiler | Preserved live | Session passes admitted packet/final_state/transitions; no repeated live decode/fold established. |
| Copy-on-write immutable state leaves | Preserved with added shells | Retained collections4→13 plus static maps in119; new shells are additional work, not full deep copies of leaves. |
| Incident actor/item mutation capture | Regressed |119 full collection snapshots/diffs per node replace incident-only work. |
| Sparse world disclosure / row borrowing | Preserved after repair |119 introduced full-store world snapshots/diff;24a touched-row repair was already in latest quiet source. |
| Retained sensory indexing | Lost route, changed schema |119 replacement decodes/sorts/reindexes; facts phase nonetheless improves on saved Door. |
| Compiler staged-row admission clocks | Preserved | Single actor/tile clock passes; no per-staged-row scan of every commit. |
| Lightweight operation ending | Preserved | No new entire canonical-state ending copy. |
| Compiler requirements/event/source inspection | Expanded work | Nearest→latest event_trace1.082→2.220ms; native_requirements0.059→0.991; schedule_delivery0.835→1.529. Required semantics grew; no exclusive per-feature timing. |
| Ordinary Timeline advance avoids future-world copies | Preserved | Lightweight advance plan; candidate copy belongs to actual world boundary. |
| Staged binary index, cue tolerance, candidate reuse | Preserved | ba2da1f algorithms remain; current holds are late required metadata. |
| Change-proportional environment source metadata | Regressed |291 local `_collect` now reconstructs global visible population repeatedly. |
| Partial required interest published before continuation completes | Preserved but late | Coverage guard and early interest publication predate Sol; continuation cost grew. |
| Item ownership recomputed only for relevant mutations | New broad work |78 adds item owners; once nonempty, commits pass NativeItems.interested. c80 aggregates locations once;0f expands actual membership. Compiler and playback both do the work at their own observation, not every animation frame. |
| Optional work cancellation behind selected work | Existing weakness, larger exposure |9b73 serial/nonpreemptible sheet traversal; new cold loader work;24a boundary checks not performance-qualified. |
| Empty idle resource-group preparation reuse | Preserved | Same shortcut;0.007→0.008ms median. |
| Media due-set composed only on map change | Preserved |0.026→0.027–0.028ms median. |
| Settled optional maintenance; family map read once | Preserved | Early return and local family-map references remain. |
| Shared preparation allowance / bounded publication | Preserved architecture, incomplete bound | Shared2ms account remains. Indivisible loads/readbacks can exceed its pre-check; a worker dependency can still delay animation. |
| Scene-thread work moved to resource worker | Preserved native | Private actor/environment material preparation still uses worker; explicit headless dummy path is synchronous. |
| Support/wall geometry overlap other derivation | Preserved | Parallel branches remain; new residue/world families add work. |
| Source support adoption on texture/path/revision change | Preserved | No full unchanged actor support mask rebuild every prefetch frame. |
| Change-only proxy uniform writes | Preserved | Output uniforms still reasserted by design, as before. |
| Actor arithmetic clocks | Preserved | Graph/Tracks arithmetic route, no per-frame schema-time expansion. |
| Actor pose/outfit/source binding reuse | Preserved | New body-scale/aperture keys extend reuse; saved idle binding changes remain zero. |
| Actual actor/history rendering | New full-area workload |ba5d actual-actor provider, a33 rolling histories,291 expanded captures.7active Mirror passes versus one-shot delayed history are distinct; retained-prefix sampling has no internal budget slice. |
| Shared actor quad mesh / SourceMaterial setup | Preserved | SourceMaterial unchanged versus9b73; shared shapes retained. |
| Fractional static/moving draw gaps | Preserved | New conditional depth bands from291 add separate work; current draw-order increase not isolated. |
| Shadow retention and light ranking distinct from flicker | Preserved | Same retained actor keys;6retained/0updated idle snapshot. |
| Fixed shadow targets, unit light plane, shared caster geometry | Preserved | No per-play resize/PlaneMesh surface rebuild restored. |
| No GPU cookie readback | Preserved | Old readback path remains removed. |
| Blood visibility/uniform/kernel/source reuse | Preserved | Existing pooled atlas/flight path carries new families. |
| Ground/target CPU mirrors and whole MultiMesh upload | Preserved | No per-instance GPU readback loop restored. |
| Effect-layer binding in sampling rather than full world cut | Preserved | Live source cuts remain disabled; no proof cue cuts were re-enabled. |
| Ready object-row adoption; blocked world construction not repeatedly polled | Preserved | Existing prepared publication remains; this does not make new metadata cheap. |
| Package recorded-source private clocks / incremental publication | Preserved | Factory route retained; latest installed82a has no quiet timing qualification. |
| Shared native Resource reuse | Physical sharing retained, consumer waiting expanded |24a removes globally cached fast adoption; consumer miss gets owned request/status plus existing postdraw fence. Hot consumer cache still returns immediately. |
| Studio cached catalogs / retained typed documents | Preserved outside Library | Library's new direct JSON reads bypass those caches. |
| Offline initialization parse once | Regressed |291 reparses full packet0 inside Journal.open. |
| One selected perspective / operation decode and compile once | Preserved | Recording reads one audience; restore uses retained compiled groups. |
| Background retirement of old index/data/native preview nodes | Preserved in established routes | Native worker retirement remains; explicit headless exception is synchronous. New restoration ownership has separate join cost. |
| Same-index Studio seek, spare pane/source reuse | Preserved | Functional retained-anchor/cache bugs are separately dated. |
| Background Library discovery and bounded Tree rows | Regressed |119 removes worker24-row/2ms publication;291 increases uncached input. |
| Parked eight-slot previews, paused-only live native swatches | Preserved | New composed whole-scene previews are additional work, not equivalent isolated old swatches. |
| Thumbnail memory limits / disk store | Preserved storage bounds |1024textures/64MiB;256MiB source images. Disk store unchanged; version invalidation bug inherited. |
| Sheet-prepack runtime loading (L8) | Not an active9b73 optimization | Opus7dbb was an offline experiment; late Opus44bd removes the tooling. Final handoff already asks to restore it. Current PNG loading cannot be attributed to Sol deleting active bundle playback. |

### Native-data inventory N1–N13

These were design items, not thirteen completed speedups at Sol's start. The
historical progress ledger explicitly leaves some open. The source comparison
must not turn unimplemented proposals into regressions.

| Item | Starting/current status |
|---|---|
| N1 attack recipes | Baseline already uses shallow recipe-shell copy; current retains it. No return of a whole nested weapon-trail duplicate per attack. Lazy per-recipe shape migration is a separate content boundary. |
| N2 environment assets | Lazy typed/resource catalog route survives. New environment residue lookup above violates proportional lookup work around it. |
| N3 environment banks | Per-record native source/bank lookup retained; no blanket monolithic bank parse reintroduced. Cold loader implementation changedf489/5b. |
| N4 definition/storage join | Existing native presentation/catalog path remains. Added source families consume shared resources; no old two-document join reinstated for every effect. |
| N5 condition/action overlay | Typed/native authoring route retained. New compiler ownership/inspection adds cost but does not restore the old JSON overlay join. |
| N6 environment receiving metadata | Existing admitted resource route retained. Current new source/header families are extra work; no isolated N6 regression timing. |
| N7 UI startup reads | Proposed worker move was not universally complete at baseline. Built icon-map reads and async image decoding remain; no claim Sol removed a completed all-UI worker stage. |
| N8 other startup documents | Baseline `_ready` already reads catalog/rig/resources/world. Current retains it; not a newly introduced scene-thread startup regression. |
| N9 old native-effects index duplication | Native package/source path retained; current Library's giant package-index parse is a new different bypass. |
| N10 movement reference scalar | Retained on catalog; no animation-schema parse for this scalar. |
| N11 palette ranges | Palette file unchanged versus9b73. Built measured ranges used first; missing ranges can still measure an image on compiler worker. That fallback predates Sol. |
| N12 PNG size/header inspection | Imported headers used first, cached PNG-header fallback remains on metadata worker as before; no scene-thread whole-PNG dimension scan shown. |
| N13 Protocol static schema cache | Retained and admission faster. Offline Journal double initialization parse is a separate291 regression. |

New numeric environment paging in `a76207a6` reduces a documented large-source
upload/worker memory exposure. It is not proof that current Door latency or all
sheet loading is qualified. The old209–212ms native resource startup leaf is
absent from later quiet traces; initial readiness and frame maxima still miss
the desired performance. Local gains and overall regressions coexist.
That startup comparison is between two21October batches, not an Opus-to-Sol
startup benchmark.

## Additional Astra findings: verified costs and necessary corrections

The human supplied another read-only history review during this audit. Its
main observation agrees with the source findings: local mutations now cause
unnecessary broad work in several paths. The following details extend or
qualify that review; they do not authorize repairs.

### Native admission waits

The24a removal is precise: a non-fresh consumer miss could previously adopt a
globally cached Resource immediately when the load/material owner was idle
and not settling. That shortcut is gone. The new route requests with REUSE,
waits for its owned actual LOADED result and invokes the existing native
postdraw fence. A physical Resource can therefore be shared while its new
consumer waits again. Multiple missing paths can incur separate fences.

The reason recorded by the change is real: a globally cached resource can
still be IN_PROGRESS for another owner, and request/get tokens must be paired
correctly. It does not prove every already-loaded Resource needs a fresh
physical load or expensive admission. Headless skips the fence; an existing
consumer cache entry skips the whole path. No isolated saved timing establishes
the additional delay from this change, and no reversal is applied here.

Source: [native resource admission](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/native_source_admission.gd:61).

### Actor-history targets and prefix realization

The full-viewport actual-actor provider starts in **ba5d0262**,19October23:26,
after the first migration. It does not start ina33d1e59, and is not inherited
from9b73. At baseline, Mirror Image already selected a finite4.2second
reference cue with native/recorded approaches, but no actor_context input or
actual assembled-body provider. The new provider therefore adds real work
relative to that baseline, while also adding previously absent actual-body
behavior.

Current native_inputs supplies the visible viewport size as capture_size.
With three active Mirror copies, the selected helper runs one live-body colour
pass plus three colour/depth pairs: **seven full-size continuously updating
passes**. Actor bounds position the output; they do not crop these targets.
Fewer copies, suspension and hidden output change the count.

Mirror explicitly skips immutable capture creation. Delayed non-Mirror
histories use owned one-shot colour/depth/dependency captures, then disable
those viewports; their unused copy passes are also disabled. Calling every
retained history continuously updating would be wrong. There is no isolated
GPU duration or memory-byte measurement for either mode in this audit.

a33d1e59 introduces rolling-prefix preparation/seeding;291 extends immutable
material/native-hit dependencies and consumers. Ordinary actor-context
allocation checks and charges the shared preparation allowance. Separately,
seed_history iterates all retained predecessors in one sampling call, binds
their private layers and samples their exact historical ages without an
internal frame-budget slice. Successful/requested keys prevent doing that same
prefix on every frame. The optical key includes viewport and camera state;
changing the view can require prefix realization again.

This identifies a new burst mechanism during seek, late admission or view
change. It does not establish that every change realizes the maximum prefix,
or that this history path caused the saved Door/Move environment holds.
Current helper installation history is distinct from the client provider's
introducing commit.

Source/history details and exact shipped helper paths:
[item and actor-history review](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/postmortem-opus-audit/item-history-cost-review.md),
[full viewport input](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/native_inputs.gd:219),
[prefix sampling](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/native_inputs.gd:298).

### Composed previews and the exact discovery/poll receipts

291e092c adds production-scene previews for input-bearing item/material and
world effects. In the saved1600×470 viewport, one primary target processes
752,000pixels versus65,536for an old256²swatch:11.4746times as many pixels
per primary target. This is not a whole-GPU-work or elapsed-time multiplier.
The full target is read back before shrinking to a maximum128px thumbnail.

Every uncached composed sample restores a new Timeline from retained compiled
data. The first constructs a Play; subsequent jobs attempt pane/source/media
reuse. It is inaccurate to say all Resources and the entire Play are newly
loaded every time. No-input isolated swatches retain their old path. The new
capability is larger work, not a matched slowdown of an equivalent old preview.
291 also adds a synchronous restoration-worker join during teardown after
cancellation; ordinary decode-worker joins already existed. That additional
scene-thread blocking exposure has no isolated elapsed receipt.

Saved discovery does grow41.147→259.642ms. Both profiles are **post-Sol**, at
010343ab and the current82a checkpoint with different case/evidence/package
inventories. This is not the Opus9b73 comparison.291 adds the full-package and
evidence parse on this path; not all218.495ms is assigned to one parse.

One current playback frame has11.696ms in thumbnail polling. Its receipt shows
eight native composites and suspended composed prewarming. It proves a native
swatch polling spike, not a composed-Play spike. The whole-call budget check
and eight-slot loop existed at9b73; larger source costs can expose this old
coarse bound. It is not newly introduced scheduling architecture in291.

Details/original profile names:
[Studio evidence addendum](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/postmortem-opus-audit/studio-optimization-audit.md:146).

### The60.798ms replay frame is shared preparation CPU

The original stopped-queue Studio profile records engine frame14475:

| Nested scope |ms|
|---|---:|
| Whole frame |60.798|
| Play process |55.382|
| Timeline readiness, within Play |32.795|
| Component preparation, within readiness |16.928|
| Media planning, within readiness |14.310|
| Studio callback |0.101|
| Thumbnail polling |0.011|

These are nested timers. Readiness is already inside Play; its two preparation
children are not added again. This frame is dominated by shared preparation,
not timeline UI painting or thumbnails. Native resource preparation is only
0.057ms and held_media/held_world are false. Therefore this frame does not
show that24a's cached-resource request caused60.798ms or a playback hold.

Original:
[current82a Studio profile](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/tests/20261021T203343.842010Z-current82a-runtime-tail/studio-profile-current-gallery-checkpoint.json).

## Correctness regressions are also dated, not all blamed on the latest work

The [shared-path post-mortem](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/agent_docs/post_mortem/CLIENT_RENDERING_REGRESSIONS_2026-10-21.md:337)
contains the supplied independent review and exact consequence limits.

| Finding | Introducing history versus9b73 |
|---|---|
| Sparse tile removal misses dirty-cell propagation; re-entry loses insertion order |119ddede adds schema16 removal/re-entry without adapting old Timeline dirty/order logs.24a sparse-fold repair did not originate it. |
| Direct Mute/Solo wrong component identity |291e092c blanket parent routing. Pending repair unapplied. |
| Native-light inspection queries channel ID against occurrence diagnostics |291e092c inspector join. False inspection does not prove failed light output. |
| External equipped-weapon material not withdrawn by root hide |ba5d0262 adds root/actor-context hiding after Sol starts; d4eb31de later adopts equipped FireBlade;2bb expands;291 adds coatings without the required external-material withdrawal. Actual destroy/clear releases; not claimed permanent universal leak. |
| Effect-owned motion / world-mechanism Follow gaps |2bb7ede2 motion omission;291e092c world-row negative default priority. |
| Composed preview queue starves ordinary previews |Introduced291e092c, repairedc76e2139; not current unresolved. |
| Immediate Freezing Sphere explosion inherits caster elevation |Introduced291e092c, repaired5258b326; not current unresolved. |
| Slatted-wall camera quarter reuse |Already present at9b73/Opus7faf78fb; repaired291e092c. Discovery date is not introduction date. |
| Shadow UV/restoration invalidation holes |Already present at9b73/813d21f6/bd3c20f7; repaired291e092c in scoped evidence. |
| Same-clock explicit seek retained wrong anchor |Already present at9b73; repairedc76e2139. |
| Follow layout skipped when preparation budget exhausted |Already present at9b73/e138fc99; working-tree repair predates stop. No whole-current native qualification claim. |
| Effect-version change retains old thumbnails |Already present at9b73, interaction introduced0529f8ed; new291 composed keys inherit it. |

## Evidence and unresolved attribution

Saved derivations, with original file pointers:

- [Eight original route/profile comparisons and sampled hold intervals](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/postmortem-opus-audit/saved-profile-comparison.json).
- [Six original Door traces, server/job clocks](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/material-runtime-integration-20261021/door-postmortem-evidence.json).
- [SDK/reducer/compiler/Timeline source audit](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/closing-repairs/opus-packet-path-post-mortem/README.md).
- [Environment metadata source and worker attribution](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/postmortem-opus-audit/environment-metadata-regression.md).
- [Item membership and actor-history source costs](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/postmortem-opus-audit/item-history-cost-review.md).
- [Held source-clock review and evidence](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/closing-repairs/opus-packet-path-post-mortem/held-source-clock-review.md).
- [Resident-resource admission review and exact replay frame](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/closing-repairs/opus-packet-path-post-mortem/native-admission-cache-review.md).
- [Studio history and optimization audit](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/postmortem-opus-audit/studio-optimization-audit.md).
- [Latest original quiet comparison](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/tests/20261021T175335.405738Z-r6-current-three/quiet-r6-comparison.json).

No exact-current82a benchmark or causal commit bisect exists. The aggregate
Door response, playback freezes and worker-leaf growth are observed; specific
additional passes/lost bounds are established by source history. Exact isolated
milliseconds for each copy, item pass, metadata lock, history capture or Studio
parse remain unmeasured. Those are different levels of evidence and are kept
separate.

The old reducer's world timer excluded separate actor-input capture; the new
world timer includes actor/item input capture. Subphase labels alone are not
identical scope. Profiles' parent/child timers overlap. Native visibility flags
after an early metadata refusal do not identify a renderer failure. Historical
230headless joins span source cuts and do not qualify the current package.

The audit identifies multiple client changes responsible for lost proportional
work and responsiveness bounds. It does not substitute backend blame, a new
renderer framework, or individual-spell tuning for those findings. **No repair
or runtime work is resumed by this document.**
