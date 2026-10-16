# Complete the three client ownership operations

Status: user authorized planning, independent review and implementation on 16 October 2026. Initial plan independently approved; implementation incomplete. Subsequent user constraints below govern continued design and implementation. Starting checkpoint: `e920efb`.

This is the completion/removal ledger for the unmet requirements in
[the existing preparation/publication plan](PREPARATION_PUBLICATION_OWNERSHIP_PLAN_2026-10-15.md),
especially §§5.1, 5.4, 7 and 11. It introduces no parallel framework or new
renderer. Review approval means the named independent reviewers have reviewed
this document and their blocking findings have been resolved; it is not a claim
of human artistic approval or achieved performance.

## Outcome and limits

Already received actions begin promptly and reach their impact/aftermath without
resource discovery interrupting playback. Ordinary small updates remain small.
Gameplay and Studio share source ownership and presentation semantics. Preserve
hierarchical event order, accepted state/display separation, source lifetimes,
independent replay reducers, authored clocks/audio, Forward+, approved textures,
lighting/cap, normals, depth, wall modes, tint and material treatments.

No backend or Factory edits, bulk spell intake, UI redesign, new ECS, local
prediction, artistic retuning, generic transaction graph or permanent old/new
runtime switch. Read current Factory host requirements from the prior plan; wall
sections and condition leases remain separately owned disclosed occurrences.
Unintegrated source capabilities remain explicit gaps rather than fabricated
gameplay or hidden source layers. Assets stay ignored and in their current place.

## Measured baseline and accounting

### User corrections to retain throughout the work

Recorded 16 October after the first two combined live runs. These are cumulative
instructions, not reasons to stop the authorized work or ask again:

- Identical modular layers/animation sheets are shared. Source identity is the
  actual layer/category/clip plus admitted authoring revision, never actor UUID,
  equipped-item UUID, transform, tint or HP. An outfit composes shared references;
  each actor/occurrence retains only mutable playback/material/pose state and pins.
- The four actual Gallery sentries have identical visual appearance/loadout once
  equipped-item UUIDs are removed. Current actor-keyed metadata resolution is
  redundant. Physical textures already share by path: the captured second run
  shows 1,833 texture creations for 1,833 unique paths, with no duplicate texture
  creation in that captured lane. Requirement counts are not load counts.
- Trust the backend's admitted payloads and the exported artwork. Asset schema
  validation, dependency/freshness scans and hash checks belong in optional
  authoring/import tools, not the action or sampling path. Use ordinary errors
  for missing/incorrect resources. Preserve actual ordered state transitions;
  do not replace necessary publication work with repeated safety certificates.
- The later user instruction is explicit: validate during tests and import
  qualification; runtime should compute directly from prepared data. Do not add
  runtime schema, source, identity or dependency proof scans around that work.
  Production uses prepared references and reports ordinary actual resource
  errors. Cursor ordering, stale-worker rejection and owner publication gates
  remain state mechanics; they do not justify repeated schema validation.
- Factory already edits native `.tres` spell/phase Resources. The client still
  reads JSON then native overlays, and spell manifest/staging JSON. Complete the
  native Resource boundary rather than optimizing another legacy adapter. JSON
  may remain an offline import input; warm actions must use admitted references
  without file/header/socket/closure discovery. `.res` is a possible binary
  packaging form, not an automatic performance claim.
- Stop making isolated modifications without accounting for the entire critical
  path. Baseline framing+parse+reduce+setup+compile alone is 31.57/25.81 ms. Removing
  all metadata and rendering waits cannot honestly promise a 10x total speedup.
  Such a target also requires removing most serial runtime resolution/compiler
  work and measuring the remainder. Do not substitute reduced source visits for
  achieved input-to-animation latency.
- Continue investigating and refining the design; record findings here instead
  of repeatedly stopping the task. Reviewers remain involved. Preserve approved
  graphics and event ordering; no server/Factory changes are authorized here.

### Current combined evidence

First combined run `.runtime/player-runs/20261016T093103.388023Z`: 81 functional
checks passed, Fireball onset 104.17/120.22 ms including final framing; a regression.
Second run `.runtime/player-runs/20261016T093859.925211Z`: 81 checks passed, onset
84.70/81.38 ms; frame means 15.01/17.53 ms and maxima 34.86/37.92 ms. Targets remain
unmet. At that checkpoint, required-component owner reuse removed repeated
preparation on unchanged cuts, but full media publication still applied future
physical roles synchronously and actor metadata remained keyed by instance
identity. The later source-boundary changes are recorded below. The second run's
source upload counts span optional background work too; they do not explain onset
alone.

The next live run `.runtime/player-runs/20261016T103903.406859Z` passed
81 functional checks. Fireball onset was 89.78/112.64 ms including final framing;
action-frame means were 14.43/17.21 ms and maxima 41.93/42.87 ms. Opening handoff
to first visible animation took 55.779/78.722 ms. The nested main-thread
`media_plan_sets` phase peaked at 4.038/5.135 ms; its source-record union still
used quadratic identity scans. This run predates the linear union and passive
constructor-source changes below. It establishes neither achieved timing targets
nor a performance improvement for those subsequent changes.

Latest completed comparable successful live run
`.runtime/player-runs/20261016T110104.141262Z` passed
81 functional checks. Fireball onset was 82.242/89.584 ms including final framing;
action-frame means were 13.7103/18.0898 ms and maxima 33.906/36.012 ms. This remains
above the onset/frame objectives. Subsequent source-clip uniform and advance
binding work is not qualified by these earlier measurements.

The later combined live attempt at 11:31 on 16 October stopped after Haste:
`hud.bar_pending` remained pending for over five seconds. There was no live
ScriptError; optional media work taking 1.2–3 ms consumed the shared 2 ms
allowance before HUD preparation could run. This failed route does not qualify
combined performance. The saved priority correction and focused checks are
recorded below. A second matched attempt started at 11:35; its timing and
functional result are not yet available at this ledger update.

Native depth/support/outline focused checks passed. The earlier Studio
`full_or_missed_receipt` publication failure was corrected; an earlier full Studio
run passed 7,155 checks. A later attempt recorded 5,374 checks and seven
prefix/endpoint failures in `generated/studio_replay_native_checks.json`.
Independent diagnosis and the native prefix probe identified a test-oracle
error: a yielded published cut was compared with every operation sharing its
clock, rather than its actual ordered prefix. The actual cuts near 1683.333 and
4745.178 ms were exact intermediate prefixes, not runtime state loss. The
focused native probe passes 1,055 checks in `.runtime/studio-prefix-native.json`.
The corrected full native Studio run subsequently passed 8,693 checks with zero
failures, errors or warnings. That run includes the material-uniform changes
below, but predates the later native-rig and trusted-parser batch; those changes
still require combined qualification. The separate 83-check source-owner proof
also does not qualify framebuffer output or performance.
The <=30 ms warm onset,
<=1 ms ordinary publication and <=10 ms steady-frame targets remain unmet.
Current working changes are not a qualified finished client. No queued-role
publication rewrite was started.

### Original comparable baseline

Latest real Gallery route: `.runtime/player-runs/20261015T235855.075072Z`.
Windows Forward+/Vulkan, 1600×960, view size 18. Door, enter Gallery, drink Haste,
two actual action-bar/target-click Fireballs. Complete final framing start to
first observed animation is 97.93/93.67 ms, including previously omitted framing
6.11/4.04 ms. JSON/envelope 7.96/5.35; canonical consumer 4.72/6.05;
queue/setup 1.07/2.47; compiler 11.71/7.90; required metadata 13.06/12.93;
main pickup/preparation/publication/render 53.24/54.84 ms. Action frame averages
15.02/16.48 ms; maxima 27.95/37.76 ms. The 81 functional checks contain no
performance acceptance assertion. Detailed profiling and a full-size SubViewport
display blit affect comparability; qualify the ordinary scene separately.

Keep nested timings for framing, parser regex/Variant/fallback, reduction,
compiler scheduling/components/traces/requirements, media actor/environment/
headers, source-role publication/queue/readiness, native construction phases,
world/atlas preparation, publication, sampling, UI, retirement and draw. Inclusive
children must not be added to parents. Report elapsed scheduling gaps separately.
Do not attribute time before the SSE record stamp to the server. Drain/correct
transport accounting within the existing protocol; preserve exact IDs/tokens.

## Operation 1 — One producer for requirements and source changes

Use existing compiled groups, MediaWarmup physical records and consumer roles.
Resolve immutable actor/environment/source closures in their worker owner once
per relevant source/actor selection revision. Keep currently displayed needs
distinct from later cue requirements. Do not gate the opening on two entire
future groups' metadata, optical masks, damage/death sheets or optional families.
Compile accepted future cues ahead without publishing their state or sound.

Publish producer-owned role additions/removals and stable references, instead of
five complete map comparisons and a reconstructed union on the main thread.
Required promotion, CPU/fixture roles, cancellation and multiple consumers must
retain their current correctness. Retained unchanged roles are not revisited
because a new operation arrived. Update readiness from changed resources, not
another full walk. Initial/global acquisition can enumerate its actual scope.
Source-size/header/socket metadata must reuse the admitted immutable records;
do not turn a small attachment into repeated large-file reads or new hashes.

Primary files: `presentation/session.gd`, `compiler.gd`, `media_warmup.gd`,
`environment_media.gd`, `encounter_media.gd`, `play.gd` handoff integration.
Remove the replaced full-set demand/proof work; do not retain it underneath a
new cache. Exit: opening vs late-cue readiness, shared-role promotion/cancellation,
ordered actual recordings and scaling with changed sources, plus measured nested
worker and main-thread demand costs. No new per-spell scheduling exceptions.

## Operation 2 — Complete occurrence preparation and exact publication

Extend existing native/component/world preparation so it owns all resources
needed at the next cue: finishing passes, optical nodes/cookies, support/depth
receivers, condition/hover helpers, feedback, audio and authoritative blood
helpers. Preparation builds private owners; sampling updates existing references,
poses and continuous authored parameters. Remove constructor/load fallbacks from
sample paths. Missing work retains the coherent displayed cut and returns to
preparation with an attributable pending reason. Silent missing rendering is not
an acceptable substitute for a synchronous fallback.

Ordinary gameplay startup uses only disclosed/currently needed source interests;
the full native catalog cannot be a mandatory gate. Existing optional lookahead
warms future accepted cues/actions under the same allowance. Keep true native
pipeline warming and the source adapter's mutability exclusions. Source-specific
adapters do not imply generic qualification of new effects.

Move every material producer, including hover/Alt, through SourceMaterial so
source/receiving/output treatments agree. Sparse atlas capacity exhaustion must
prepare a complete private repack, publish it once, and retire the replaced
owner; ordinary overflow cannot become a permanent preparing/error state when
the live set fits. Changes preserve all member geometry and source appearance.

Primary files: existing component/native/light/support/condition/blood/audio
presenters, `native_light_delta.gd`, `world_preparation.gd`, `play_hud.gd` highlight
producer, `play.gd` startup/publication. Exit: first use + impact, independent
same-source occurrences, condition/hover frame changes, remembered blood,
support membership change, atlas overflow/recovery, cancellation and no candidate
audio/trace. Compare unchanged source output to the current renderer oracle.

## Operation 3 — Incremental displayed frame and one host allowance

Use one host-frame preparation account for the displayed Play, Studio candidate,
native warming, thumbnails, UI construction and retirement. Required upcoming
publication takes priority over optional warming. The account must include real
elapsed work and cannot hide a constructor overrun behind a pre-call timer check.
Use existing owner queues; no new competing scheduler. Keep displayed playback
running while candidates prepare. Thumbnail file decoding/loading belongs off
the UI thread; graphics construction stays on its correct thread.

Remove repeated room-wide work for unchanged actors, source roles and material
operands. Make ordinary rank/membership updates touch their actual affected set;
global view changes/repack remain explicit larger jobs. Retire old trees without
an unbudgeted recursive prewalk. Avoid rebuilding outline children, feedback or
support geometry because only a pose or clock changed. Do not change approved
rendering representation just because source inspection suggests GPU expense:
measure native/atlas/root passes first. If the unchanged display loop remains
over 10 ms, report its nested actual costs and correct the dominant repeated work.

When the opening metadata/resources are already ready, handoff, role admission,
native readiness and publication are eligible in the same host frame. Only real
world/source/draw barriers justify yielding; a queue stage or allowance reset is
not itself a reason to insert another frame. Record actual work counts alongside
time: unchanged requirements revisited, sample-time constructors and room objects
touched by a small change. Each operation must demonstrate deleted work.

Primary files: `play.gd`, existing preparation/presentation owners, Studio host/
panes/timeline/thumbnail owners. Exit: ordinary gameplay and Studio playback,
seeking/looping/settings, cancellation, active spell movement, and matched
profiling-enabled/disabled measurements with startup timing.

## Native admission boundary amendment — 16 October

The current isolated replay audit of the six actual Gallery records makes 4,571
sheet/geometry resolutions for 400 distinct `(slot, sheet)` selections, 230 item
appearance selections for 13 semantic choices, and 7,413 catalog lookups for only
56 cold JSON reads. These instrumented CPU counts are not live latency evidence.
The problem is repeated resolution, not a separate GPU texture per knight.

Complete the existing admission boundary in two concrete, compatible pieces:

1. An offline body-source importer records the current approved source paths,
   dimensions, companion channels and compact attachment samples as lazy native
   metadata Resources. Share by actual layer/category/clip and admitted revision.
   Actor loadouts select these references; actor/item UUID, tint and pose do not
   create another source. Runtime no longer discovers headers, checks source
   freshness, rebuilds companion closures or joins the same source catalog.
2. An offline native-spell importer reads the current **client-approved** index,
   manifests and staging once, preserving their exact current selection, timing,
   palette and deferrals. Save one lazy metadata Resource per spell and a small
   string-path/condition-owner index. Resolve component-specific overrides and
   existing baked variant paths here. Runtime selection returns the admitted
   record directly: no manifest/staging joins, list search, recursive canonical
   serialization, SHA calculation or dependency/freshness worker. Native scene
   residency remains with the existing asynchronous Resource owner; missing assets
   fail normally. Dependency/format verification remains an explicit import-tool
   operation, not a second preparation gate.

The metadata index contains file paths, not texture/scene ext_resources: reading
it must not instantiate effects or eagerly load the library. Existing renderer
operands can reference immutable native record fields without another conversion
back through JSON. Private materials, particles, audio voices, transforms and
clocks remain occurrence-owned. NativeFactory gets its own shallow clip view for
its existing duration extension; it must not mutate a shared source record.

This admits the current approved delivery only; it does not copy the Factory,
intake new spells, alter art, or claim its JSON export is its editable source.
Rebuilding admitted metadata is an explicit import step; authoring reload selects
a new admitted revision while the previous display keeps its own references.
Verify cold/warm lookup and exact old/new source/timing operands, source sharing,
reload/cancellation and unchanged real recorded output. Keep the spell and body
removal obligations separate; neither alone completes operation 1.

The packet benchmark separately confirms that native JSON parsing is not a
speedup over native Variant parsing on these packets and changes integer types.
Do not add a recursive post-parse repair pass. The interpreted UTF-8 and full
syntax guard account for 8.42/5.48 ms on the two isolated Fireball packets; choose
a trusted-producer path only with actual scalar semantics accounted for. This is
not permission to replace ordered cursor/publication checks with assumptions.

The Studio replay regression has a different owner: a full **state** reset is not
a full **lighting atlas** replacement. Publish lighting from its prepared physical
change. An empty prepared lighting delta retains its serial; a real prepared
repack still publishes its full layout. Never suppress the atlas ordering error.

### Body source admission boundary (implementation amendment)

The body importer reads the currently approved effective rig/sheet, equipment,
geometry, normal-profile and baked socket inputs offline. It publishes a small
metadata-only native index plus one resource for each actual rig/category
(e.g. Head3), with its admitted clips. Resources contain passive path strings,
original dimensions, exact geometry/normal companion references and compact
socket bytes; they do not reference Texture2D, scenes or other artwork resources.
Only selected category resources are loaded. Actor/item UUIDs, tint, transform,
HP and playback clocks never identify a source. Actor construction composes
references and retains mutable layer/pose/material state privately.

Admission is explicit. The importer saves the index inside a new revision
directory, then atomically publishes its path through the short `current` marker
described below. Existing cache shells retain their immutable index/resource
references; reload admits the selected revision. Worker snapshots share an
immutable admission shell; lazy loads replace its small loaded-reference map
rather than mutating a map already shared with another worker. No runtime mtime,
hash or dependency scans qualify an action. Missing resources use existing
ordinary authoring errors. SourceCatalog retains the body and spell admission
shells by direct reference; it does not scan/deep-copy their dependencies.

Removal obligations: production Characters selection uses imported semantic
item bindings and layer/clip descriptors, removing item binding/category joins,
resource-sheet joins and geometry/profile joins from each actor/clip query.
CharacterGeometry uses the same admitted records for presentation and media.
Body source estimates use imported dimensions; compact sockets use imported
samples, removing PNG-header reads and socket manifest/source freshness checks
for these admitted sources. Optional encounter families compose shared layer
references; identical sentries do not resolve all clips independently by UUID.
Legacy JSON remains an offline import input, not a production fallback switch.
Environment records remain with their existing owner; no artwork is retuned.

Qualification compares exact old/new path/CPU/GPU/normal/socket/dimension data
for approved sources and the latest actual six-record Gallery route. Measure
cold import/admission separately, unique layer refs versus actor query counts,
worker phase costs and actual live onset. The 1,833/1,833 captured physical texture
publications were already unique: this boundary removes repeated metadata work,
not duplicate GPU textures, and alone implies no 10x total latency promise.

### Index revision ownership correction (implemented)

The fixed-path index strategy failed actual native qualification. In
`.runtime/native-admission-race`, repeated `ResourceLoader` loads of the same
index with `CACHE_MODE_IGNORE` or `CACHE_MODE_IGNORE_DEEP` returned null for 191
of 192 requests; `CACHE_MODE_REUSE` succeeded for all 192. Serialized threaded
IGNORE requests also failed seven of eight times. A synchronized first-load
owner alone did not solve explicit reload: re-admitting both fixed-path indexes
failed while the previous index holders remained alive. These are observations
from the current Godot runtime, not evidence that the resources were absent or
that all failures were caused only by concurrent requests.

Both importers now save an immutable `<revision>/index.res` alongside that
revision's metadata Resources. After every required file is saved, they close a
staged short path marker and atomically rename it to
`.derived/native-spells/current` or `.derived/body-sources/current`. Admission
reads that marker once and uses `CACHE_MODE_REUSE` at the selected immutable
index path. An explicitly configured body index remains a direct, caller-owned
immutable native resource path. There is no fixed-path index fallback, runtime
schema/hash/freshness check, polling loop, retry scheme or new source registry.

The existing source boundary owns one synchronized current index reference per
source kind; body admission also respects its configured index path. A cache
with an admitted shell returns it before entering the first-admission mutex.
`SourceCatalog.source_snapshot` pins both index references before dispatching
workers. Small read-only admission shells retain those references and replace
their loaded-reference maps by copy-on-write. Explicit metadata invalidation
clears only the current references, leaving previously admitted workers and
displayed sources intact. Studio performs that invalidation before its fresh
recording loader starts; packet/program invalidation remains at its later
existing safe boundary.

`tests/source_index_owner_checks.gd` passes 83 checks, recorded in
`generated/source_index_owner_checks.json`: 24 simultaneous first admissions,
a real offline native-spell rebuild, parallel reload with old holders alive,
unchanged-body revision reuse, an independently configured body index, and
ordinary adoption retaining the prior displayed revision. This qualifies
metadata admission and ownership only. It does not replace the current live
Gallery route, full Studio seek/loop, approved-output comparison or timing
acceptance; the 7,155-check Studio run preceded this correction.

## Review, implementation and acceptance sequence

1. Antislop reviewer checks deletion of repeated work, no extra framework/caches,
   realistic critical paths and no misleading timing labels. AntiOOP/correctness
   reviewer checks ownership, lifetimes, immutable handoff, thread DAG, event order,
   atlas recovery and unchanged graphics. Resolve blocking plan findings before
   production edits. A separate plan-adherence subagent monitors implementation.
2. Implement operation 1 with its removal obligations and focused observable
   regressions. In parallel after approval, occurrence work may proceed in
   non-overlapping files. Keep Play/session handoff integration owned explicitly.
3. Finish operation 2 and the shared host account/incremental operation 3. Run
   native/GPU processes serially and stop only processes launched for this work.
4. Review combined changes, then execute the same actual Gallery door/movement/
   Haste/Fireball route and a real recorded cast/reaction/multi-hit/death sequence.
   Exercise gameplay with ordinary scene rendering and Studio with seek/loop;
   neither alone qualifies the other. Fix reviewed correctness regressions before
   interpreting performance. Tests follow `dnd_engine/HOW_TO_TEST.MD` and assert
   observable cuts/resources/output, not private cache call choreography.
5. Retain the existing objectives: <=30 ms warm received-action-to-animation,
   <=1 ms ordinary publication and <=10 ms total steady frame. These are targets,
   not predicted savings. Include final SSE framing in onset; preserve separate
   transport/server timings. Report p50/p95/p99/max, every >10 ms frame by nested
   dominant cause, cold/prefetched differences and profiling overhead. Absolute
   unmet targets stay unmet; no narrowing acceptance to successful Fireballs.

Record implementation removals, reviewer decisions and measured results below.
Do not finish with just a plan or promise; the user authorized implementation.

## Review decisions and implementation evidence

Antislop reviewer approved the plan on 16 October; required removal of the old
full-set demand path rather than a cache around it. AntiOOP/correctness reviewer
approved on 16 October, retaining actual complete-cue readiness and authoritative
dynamic source/receiver truth. Plan-adherence reviewer approved after adding the
same-frame ready-path gate and before/after work counts above. Production
implementation may proceed. No performance result is implied by these decisions.

### Body/environment source boundary implementation evidence

`tools/import_body_sources.gd` now imports the approved effective body selection
into metadata-only native Resources under ignored `.derived/body-sources/`.
The current import has 237 actual rig/category Resources plus 32 explicitly
referenced loose PNG accents, 3,429 clip/slot descriptors, 21,271 source path
references and 20,851 dimensions. It changes no artwork. The current revision's
Resources occupy 74.80 MB plus a 7.32 MB lazy index; the actual six-record route
admits 23 Resources (13.50 MB plus index), not the full dependency library.
The three profile selections and native mask roles are descriptor-owned refs
with stored scalar identities. Actor/item UUID, tint and transform are absent
from their source keys. Optional families compose each actual layer/slot once.

Runtime body source resolution no longer performs item binding/category joins,
resource-sheet/geometry/profile joins, PNG header reads or socket manifest/input
freshness scans. Imported geometry keeps its admitted absolute root and optical
registration. Existing `SourceCatalog` snapshots carry the immutable admission
shell; its adoption seam merges already loaded refs for the same revision.
No interpreted recursive freezing remains: a separate cold probe measured
36.73 ms for the index and 112.30 ms across 18 actual selected categories spent
only in that walk. Ownership now treats admitted source data as read-only and
keeps only small shell/maps explicitly read-only with copy-on-write replacement.
Binary metadata deserialization is still a measured cold cost; it is not
represented as eliminated or as a warm-action latency improvement.

EnvironmentMedia now owns one immutable contribution per physical path/fixture
role and publishes those refs directly. Opening partial preparation borrows
previous complete refs until the full continuation replaces that finite scope.
The old whole-room contribution comparison/replacement was deleted. Main-thread
source demand compares stored identity→ref maps in linear reference count time;
changed references are still recognized even when the stored identity agrees.
Its diagnostics distinguish record-delta construction, interest updates and the
actual number of role entries visited.

`tests/body_source_parity_checks.gd` compares the latest six actual Gallery
records against frozen pre-change source adapters. Its initial 6,102 checks
passed; the expanded fixture now passes 12,424 exact path, CPU/GPU, geometry,
normal-set, socket-byte, source-sharing and optional-family checks. The fixed
creature fixture passes 736 checks across all 43 registered fixed rigs in
`generated/fixed_body_source_parity_checks.json`. The separate source publication
fixture passes 75 checks, including late-cue error gates and shared consumer
cancellation. These are source/CPU metadata qualifications, not a live latency
or native-frame acceptance claim; no runtime artwork or shader change is
claimed. In the matched Fireball source cuts,
opening→full changed from 443 added + 164 removed role entries to exactly 135
added / zero removed (135 actual physical role changes), and from 899 + 182 to
exactly 189 / zero (189 actual changes). All 195/213 opening refs respectively
remain retained. See `generated/body_source_parity_checks.json` and
`generated/source_requirement_publication_checks.json`.

The subsequent actual live run above exposed another retained-reference cost:
Play rebuilt its projected/combined source-record union with repeated
`Array.any(is_same)` scans. That union now preserves order through stored
`source_id` membership, retaining identity handling for the small unkeyed
transient contributions. Physical source readiness is refreshed once after the
interest-update batch, rather than once per individual change. The existing
source owner and readiness semantics remain in place; no extra registry,
publication queue or runtime validation was added.

`.runtime/source-union-profile.json` measures the exact real 270/302-reference
Fireball inputs against the prior union: median 3.616/4.528 ms became
0.112/0.127 ms, with the same ordered references. These are isolated CPU timings
for the union only. They remove about 3.50/4.40 ms per measured union, not the
whole 55.779/78.722 ms opening-to-visible tail. A new live run is required to
measure their actual effect; no latency or frame-target achievement is claimed.

Remaining boundary after the body import is deliberately explicit. Compiler
`Authoring.clip`, action/damage/movement/condition recipes and source provenance
still use the admitted JSON recipe documents (and the existing small native
presentation overlay). `Authoring.spell` still checks for its legacy recipe on
first uncached spell access. This change does not claim that the entire client
or every authoring recipe is native. Environment/other non-body image estimates
still inspect a PNG header on the metadata worker when their existing header
cache has no entry. Body index/category Resource deserialization remains lazy.
`CharacterGeometry.bind` still computes small scalar material-path/transform
values when an actual clip/profile binding changes; it does no image readback
or body JSON/freshness inspection.

The next compiler ownership correction is independently approved and being
implemented. Before this correction, `_actor_structure_requirements` called
`Characters.structure`, whose selector loaded full future category metadata
before the opening handoff. An isolated reveal compile was about 140 ms after
freeze removal. The source paths already exist in the admitted index; resolving
constructor identity does not require deserializing their full clip metadata.

Constructor rows now select existing revision-qualified `index.layers` paths as
`source_path`, alongside private actor layer/tint values. Required/optional media
workers explicitly admit the selected categories. `WorldPreparation._derive`
also owns explicit category/override/noise admission for its private actor-layer
output, returning the resulting immutable source snapshot and ordinary errors
before publication. Sampling uses prepared lookup-only descriptors; it must not
turn a missing handoff into a main-thread Resource load or publish an empty actor
after an admission failure. The coherent displayed owner remains until the
required preparation result is ready.

This removes full category admission from passive compiler selection and moves
any genuinely needed deserialization to its existing media/world preparation
owner. It introduces no new registry, queue, schema, prediction or validation
layer. Antislop and correctness reviewers approved the seam, and implementation
continues within the authorized three-operation plan. Source/output regressions,
the current live Gallery route and full Studio seek/loop still need to qualify
the combined change. Neither the cold cost's removal from the compiler nor the
isolated union benchmark is an achieved end-to-end latency saving until measured.

### Passive constructor selection follow-up

After the combined live route still measured door compilation at 144.94 ms and
Fireball onset at 89.78/112.64 ms, the root authorized the passive selection seam.
The independent correctness reviewer approved it with explicit row/private-layer
separation, worker error propagation and snapshot adoption requirements.
`Characters.structure` now selects revision-qualified `source_path` strings;
it no longer loads category Resources for constructor comparisons. Existing
required/optional media workers admit actual selected category data. The world
preparation worker explicitly returns `prepare_layers` success/error and its
updated immutable source snapshot; publication adopts it before native binding.
Only private visual layers carry the loaded `source_ref`. Body descriptor/sample
lookups cannot read the selector, admit an index/category or call ResourceLoader.
No importer, source schema, artwork, shader or new scheduling system was added.
Focused source qualification at that checkpoint passed 12,418 body checks, 736
fixed-rig checks across 43 rigs and 75 source-publication checks. Later full
native Studio qualification passed 8,693 checks as scoped above; the latest
expanded source fixture passes 12,424 checks. The current combined changes still
need matched live qualification, and previous onset numbers remain unmet rather
than claimed fixed. Cold category loading still exists on its appropriate
preparation worker and must be included in its nested timing. These test checks
must stay in qualification rather than being added to the production action or
sampling path.

### Action media asset admission (implemented producer boundary)

The leaf audit in `.runtime/compiler-audit-leaves-20261016/result.json` uses six
actual Gallery records in an isolated sequential compiler replay, with accepted
media/optional metadata between operations and no selected-action preview
warming. On its first Fireball, `Components.compile` took 18.804 ms inclusive;
its child `Blood.asset` took 17.672 ms across two calls. One call first loaded
the entire 2,610,696-byte `catalog/action_media_assets.json`; the second reused
that table. Later warm component compilation was under 1 ms. The blood child is
included in the component total and must not be added to it. These observations
prove a cold metadata leaf, not a live received-action latency saving or a cost
that every already-warmed cast incurs.

That table contains 13 actual assets. The selected blood definition alone is
303,909 bytes when compact JSON serialized. The reviewed change imports all 13
exact passive definitions into individual native metadata Resources within the
existing revision-qualified native source package, COW admission index and
atomic `current` marker. `SourceCatalog.asset` explicitly admits one definition
on its existing worker; `prepared_asset` is lookup-only. Compiled blood
components retain the selected definition, and WorldPreparation admits initial
authoritative residue through its existing terrain-row preparation. Blood and
SelectionMedia consume those references; renderer sampling never admits an
asset or loads the whole table. This completes the common producer boundary
rather than adding a
blood-only cache, registry, scheduler or rendering exception. Runtime performs
direct prepared-reference access and ordinary actual resource errors; schema,
identity, freshness and parity verification stay in import/fixture tests.

The newly introduced, untracked source owner/catalog scripts were renamed
to `native_presentation_sources.gd` and `native_presentation_catalog.gd` to reflect
their spell-and-action-asset scope. Their existing derived directory and cache
key remain unchanged, avoiding a separate artifact migration or runtime switch.
This changes passive metadata admission only; Factory code, artwork, shader
values, authored event order and occurrence ownership remain outside this seam.

Antislop implemented the reviewed seam and correctness reviewed the handoff and
exact-data parity after the preceding capture. The focused source/blood checks
are recorded below; a new actual live/Studio measurement must qualify the
combined implementation. No timing-target achievement is claimed from the
isolated 17.672 ms leaf measurement.

### Shared passive asset admission follow-up

A fresh six-operation Gallery compiler probe isolates the remaining first-Fireball Components cost: 18.804 ms inclusive contains 17.672 ms in Blood.asset; its first selected blood read parses the entire 2,610,696-byte catalog/action_media_assets.json. The second Fireball performs the same two blood releases with Blood.asset at 0.009 ms. Actual reveals/duration are 0.188/0.123 ms, not the blocker. First native spell Resource load is 3.919 ms and cached palette operands are 0.993 ms; neither explains the blood cost. These isolated CPU observations are not live latency acceptance.

The root and independent correctness reviewer approved extending the existing revision-qualified native presentation package with all thirteen current passive asset operands. The source owner and index are renamed to native_presentation_sources/native_presentation_catalog; the existing .derived/native-spells package and admission cache key stay in place. Each metadata-only Resource stores the exact asset identity/value, selected by an asset_metadata path in the same index. Native source paths stay immutable; the existing current marker, COW loaded shell, snapshot adoption and retained old-revision references remain the only ownership mechanism. Asset keys are explicitly namespaced from spell behavior keys. No second registry, marker, queue, texture dependency or runtime freshness proof is introduced.

The existing offline importer admits all thirteen exact legacy values and compares its saved operands offline. SourceCatalog.asset performs explicit preparation-worker admission; SourceCatalog.prepared_asset is lookup only. Blood.asset uses the selected native operand, damaging selection warms that operand, and each authoritative residue component retains its own admitted metadata reference. Initial persistent blood is admitted in WorldPreparation's existing changed/full terrain-routing loop only when actual tile residues require it; its existing source_files handoff reaches the scene owner before binding. The blood renderer borrows prepared/component refs only and never reads an asset during sampling. An actual selected asset load failure follows the ordinary preparation error result; no schema/range validation is added to action processing.

Removal obligations: the production Blood.asset and SelectionMedia whole action_media_assets document read disappear; renderer fallback admission disappears; selected data remains unchanged. Import tools/tests may retain legacy reads as exact parity oracles. At this asset-boundary checkpoint, the first door clip still parsed the 1.845 MB rigs catalog; the later rig-consumer deletion below removes that read. Fireball destruction banks still parse their selected JSON, and NativeAuthoring's existing cold overlay conversion/range checks remain. Those are separate boundaries, not silently included in the asset batch. Qualification requires exact parity for all thirteen values, lazy single-asset loading, disjoint loaded keys, immutable/COW worker handoff, retained old revisions, and real blood/replay behavior. Live onset and frame acceptance must then be measured again.

Asset-boundary qualification after import: thirty spells plus thirteen passive assets import in 173.94 ms offline, with every saved asset compared exactly before publication. Native asset metadata totals 1,242,830 bytes; selected blood is 314,318 bytes. The first isolated selected blood Resource admission measures 6.44 ms, so deserialization remains real preparation work, not a zero-cost claim. The new asset fixture passes 52 lazy-selection/COW/revision/identity checks, existing native spell admission 368, condition owners 18, concurrent/reload source ownership 83, actual blood authority/timing 281, exact Gallery blood kernels 56,881, and selected damaging/non-damaging feedback parity 27. The concurrent-index fixture also reports three ObjectDB instances at process exit; its ownership assertions pass, but that diagnostic is not described as clean. Initial persistent-residue worker integration and combined native/live qualification are being checked independently; no end-to-end target achievement follows from these isolated results.

### Yielded-prefix oracle diagnosis and continuing implementation

The later Studio failure compared a yielded native publication with
`Recording.restore(time)`, which drains later equal-time operations too. At the
actual intermediate cuts near 1683.333 and 4745.178 ms, the renderer had consumed
cursors 32 and 78; the time-only oracle expected later cursors 40 and 99. The
native probe established that the displayed states match their exact ordered
intermediate prefixes and continue draining normally. Tests must compare the
published cut's existing group/commit position, then wait for the intended
terminal prefix instead of treating the displayed clock alone as completion.
This is a test-oracle correction, not a runtime ordering defect, and introduces
no production prefix-validation pass. The corrected full native Studio run
subsequently passed 8,693 checks, with no failures, errors or warnings. That
result precedes the later native-rig/parser batch and does not establish the
remaining preparation/publication latency targets.

Concrete implementation continues under the same three-operation plan:

- The ordinary clip-uniform deletion is implemented and qualified as recorded
  below. Preserve its exact color, normal/depth inputs and material values while
  measuring the combined live path; do not describe the isolated fixture as
  achieved onset or frame performance.
- Complete advance source binding for the next received clip even when its
  actor keeps the same outfit. Source/resource readiness alone must not leave
  first-use binding work until sampling; existing preparation owns those refs
  before their cue.
- Remove the remaining preparation/publication tail using its nested measured
  work and existing owners. Already completed work can cross its handoff in the
  same host frame; real construction/draw dependencies and correct event order
  still determine publication.

The user's direction is to keep concrete implementation moving while targeted
tests and independent reviews continue, rather than retreat into repeated
evaluation or another approval cycle. Native-process coordination remains in
place. These tracks are not declared complete by source parity, an isolated
benchmark or the prefix-oracle diagnosis; the current timing targets remain
unmet until a new matched live/ordinary-scene/Studio measurement establishes
otherwise.

### Remaining rig consumer deletion

The isolated first door still parsed the 1.845 MB effective rig JSON because Authoring.clip/body, Components, ImpactPlacement, Selection and Studio looked up the legacy table even after its native admission. The approved follow-up preserves each effective clip.sheets string map in the existing BodySourceIndex.rigs instead of dropping it offline. Authoring.rigs and remaining production read-only consumers borrow that admitted rig value; Palette.prepare selects its source path from the existing index.sheets default map. No schema, texture dependency, fallback, validator or new ownership system is introduced. Import continues to use the effective native presentation overlay, preserving crouch clip overrides and source provenance. Exact forty-four rig/clip and resource-reference parity belongs to offline tests; actual six-operation compilation must neither read legacy rig JSON nor admit category Resources. Other current resource-table consumers remain explicit until migrated; this batch does not claim all recipe JSON is gone.

Rig-consumer qualification: the effective native index now preserves all 44 rigs, 454 complete clip definitions, 3,301 sheet references and 3,313 existing resource paths; 4,379 exact offline/reference checks pass, including authored CrouchIdle/CrouchRun overrides. Index size is 7,528,394 bytes; its load is still an admission/startup cost, not claimed free. The expanded six-operation source test passes 12,424 checks and asserts every compiler operation leaves category admission unchanged and never reads catalog/rigs.json. Source-publication checks remain 75 passing. Isolated compiler timings are 0.70/24.24/17.09/5.94/25.90/9.59 ms for the six records and are not an end-to-end improvement claim. Conditions.paths, condition coverage and thumbnail resource-map consumption still use the 300 KB legacy resource table; Palette's selected source lookup no longer does. Combined matched live qualification follows these source checks.

Play startup now borrows `Characters.rigs` from the same native source owner as
its worker snapshots; it does not create a separate legacy rig-table identity.
The later trusted-grammar parser switch has focused qualification as recorded
below, while its combined live qualification remains pending.
Neither that parser change nor this native-rig batch is qualified by the earlier
8,693-check native Studio run. Preserve exact token/ID and ordered packet
semantics, and report their current test/live outcome separately when measured.

### Ordinary source-clip uniform updates (implemented deletion)

`ActorConstruction.bind_source` now treats sheet and palette changes as actual
uniform-value updates through the existing SourceMaterial owner. A supported
geometry source changing to another supported clip/profile writes its final
maps and scalar values directly. It no longer clears maps/geometry flags to
null/false and restores them, or marks the unchanged quad/shader binding as
structural. Unsupported sources and incomplete profiles still clear geometry;
optional ground data, source paths/status, transforms and AABB updates retain
their existing behavior. This changes update work, not the approved source
values or rendering representation.

Two redundant producer-presence asserts were removed from SourceMaterial's
direct value/change access. Atlas output and receiver parameter-name membership
uses its existing cached dictionary instead of a linear array during changed
uniform copies. No new owner, proof scan, cache or scheduling path was added.

`tests/actor_material_preparation_checks.gd` passes 2,510 checks in
`.runtime/actor-material-preparation-checks.json`: exact actual source, receiver
and output shader uniforms, including missed acknowledgements and retained old
targets. This focused fixture makes no framebuffer or performance claim. The
subsequent full native Studio run passes 8,693 checks with zero failures, errors
or warnings, before the later native-rig/parser batch. Complete same-outfit
advance source binding and the remaining measured preparation/publication tail
remain open; current onset, publication and steady-frame targets are still unmet.

### Trusted producer parsing and host preparation priority

The existing trusted-producer parser no longer recursively qualifies JSON
syntax before decoding. Its scalar-compatibility detector selects the existing
exact decoder fallback where necessary; this does not replace the decoder or
repair a whole packet after parsing. Strict public/offline parsing retains its
grammar/depth contract. Private malformed-grammar and depth tests now exercise
that strict public boundary rather than requiring the trusted producer path to
repeat the same qualification. Exact scalar/ID and six-operation state/timeline
parity pass 3,445 checks; actual trusted SSE input passes 165 checks. Both report
no errors or warnings. These are parsing/state qualifications, not achieved
received-action latency or frame performance.

The native authoring-reload fixture passes 24 Forward+ checks. The environment
source-owner fixture passes 331 checks. Both are clean focused results; neither
replaces the unfinished combined live route or extends the earlier Studio pass
to all later changes.

The 11:31 route exposed preparation starvation rather than a script failure.
Within the same host allowance, required world/current-component preparation
now runs first, pending `hud.prepare_bar` runs next, and optional rotation media
preparation runs last. It adds no separate UI allowance or competing scheduler.
The admission fixture passes 28 checks and HUD retention passes 67. The older
recorded HUD fixture still emits its missing-portrait warning; those functional
passes are not described as warning-free.

The 11:35 matched live run completed at
`.runtime/player-runs/20261016T113552.339361Z`, with 81 checks passing and no live
script errors. Haste's pending bar finished 249.223 ms after command readiness,
versus exceeding the five-second observation window in the failed run. Door
packet-to-animation was 86.973 ms, movement 158.746 ms, Haste 35.662 ms and the two
Fireballs 85.501/100.424 ms. Fireball frame means were 14.755/19.095 ms and maxima
33.979/40.197 ms. These do **not** improve the prior 82.242/89.584 ms Fireball
onsets or meet the timing targets. The corresponding 17-layer impact frames now
perform parameter copies with no full material copies; atlas material sync was
1.114/1.108 ms, versus 2.472/2.321 ms on the earlier 34-full-copy impact frames.
This qualifies deleted material work, not an overall latency improvement.

Current Fireball nested costs remain parser/admission 6.272/4.342 ms, canonical
consumer 4.720/7.822 ms, compiler 11.393/11.514 ms, opening metadata 6.953/7.746 ms,
and opening-to-observed-animation tail 54.598/65.202 ms. Server execution is
separate at 563.206/435.125 ms. Main-thread source-role publication and waiting
still dominate the next implementation track. The run reports the existing
missing-caster-portrait warning and 32 ObjectDB/one Resource exit diagnostics;
it is not described as clean teardown or finished performance qualification.
At cleanup, two obsolete headless source-loader race reproductions from the
earlier rejected importer experiments were found still blocked (each had already
printed 191/192 failures). Their four exact Windows wrapper/child processes
were terminated. No NDClientGodot Godot process remained afterward. The live
measurement above must not be described as isolated from those headless jobs;
it remains a scoped functional/deleted-work observation, with timing targets
unmet.

Remaining source-role work is a candidate deletion of mirrored physical-role
maps and redundant count rewrites in the existing owner. A larger future-role
queue is not complete: any such continuation must retain the actual sources
pinned by worlds already being prepared, in addition to current/displayed or
projected interests. Do not report a queued-publication solution or global
completion from the parser, ownership and focused HUD checks above. Same-outfit
advance binding and the measured preparation/publication tail remain explicit
until implemented and qualified by current gameplay and Studio evidence.


### Received-operation ownership batch, 16 October afternoon

The later user request delegates reduction, opening asset resolution and
presentation compilation separately, and asks how much of the 143 KB reply is
actually consumed. The plan-adherence/ownership reviewer and compiler/correctness
reviewers remain involved. No engine/Factory edits or graphical retuning belong
to this batch.

Implemented deletions at existing ownership boundaries:

- Session packet/compiler locals now expire at their own operation handoff,
  instead of charging prior temporary destruction to the next action's setup.
- Retained reduction forks only actual mutable actor/loadout/contact collections.
  For a single audience member, its already reduced cell/contact operands feed
  presentation directly; light/hazard visibility filtering, optical/effect
  composition, public detached inputs and multi-member composition remain exact.
- The existing imported native presentation package owns 27 static fact
  descriptions and 186 recipe requirement rows across 30 spells. Runtime still
  binds occurrence-specific applicability/context. Accepted passive version/log
  payloads are retained; only mutable trace shells and pruned child lists are
  constructed. Public diagnostics remain detached.
- Opening/full source owners retain physical source selections, finite size and
  header facts, role families and completed environment unions. Required source
  header publication selects the actual source scope instead of duplicating the
  optional catalog header table. An opening no longer discards the complete
  mixed-role partitions before continuation can reuse them.
- Presenter allocation readiness and optional preparation follow an explicit
  resource-owner revision reported by existing condition/spatial/retained-tail
  updates. HP/log/ordinary motion commits still advance canonically without
  invalidating unchanged allocations. Native source completion, cue clocks,
  membership, camera and material gates remain active.

Qualification before the final finite optical-role retention correction:
source 200 and environment 345 checks; native requirement templates 373;
presentation coverage 175; exact frozen compiler output 326 checks over 51 real
operations, 289 event rows and 1,056 version rows; actual two-owner/public trace
isolation 822; resource-owner revision 25; single-member projection 39; real-six
canonical/capture ownership 59; retained transactions 225; Journal refusal/retry
31; public reducer 125; optical ownership 425. The broad snapshot harness was not
qualified against the current three-sensory/single-observer route: its fixture
requires four alternating observers. Its unchanged committed generated report
is preserved, not claimed as a current pass. Failed fixture-attempt logs remain
in `.runtime`.

Live Windows Forward+/Vulkan route
`.runtime/player-runs/20261016T125701.044401Z` passes 81 checks using actual door,
Gallery movement, Haste and native action-bar/target-click Fireballs. Warm
Fireball final framing to first observed animation is 66.710 ms, comprising
23.821 ms to opening preparation and 42.889 ms afterward. Before this frontend
batch the comparable warm values were 90.983 / 32.958 / 58.025 ms.
Warm JSON/admission is 3.952 ms, canonical admission 4.807, packet setup .005,
compiler 6.462 and opening metadata 8.326. Header count is 416 selected versus
3,235 cached; size/header publication is .396 ms versus the earlier 1.444 ms.
The Fireball segments average 14.176/13.290 ms per frame and peak at
27.406/32.668 ms. Server execution is separate at 567.683/389.943 ms. The live
harness uses one full-size SubViewport plus a root display blit; these are not
ordinary root-only or Studio timings. The live exit retains the known
missing-portrait/ObjectDB/one-Resource diagnostics, so it is not a clean teardown
claim. Full native Studio on this tree passes 8,724 checks with no errors or
warnings in `.runtime/frontend-qualified-studio.log`.

The 143,011-byte packet audit is in `.runtime/fireball-payload-audit.json`:
76,072 event bytes (including nested fact/log values), 26,290 version rows,
21,649 world updates, 13,149 root, 4,642 HUD and 1,209 envelope/separators.
The root duplicates a flat event (9.19%); changing its wire encoding belongs to
the protocol. All 207 versions/56 received event nodes, 33 world updates and
14 combat logs have current ordering/state/replay/diagnostic consumers. This
is not a claim that every field selects rendered pixels. Existing Godot native
JSON alternatives do not preserve the exact integer contract; no replacement
parser or wire-format change was introduced.

The <=30 ms onset, <=1 ms ordinary publication and <=10 ms steady-frame targets
remain unmet. Functional/oracle passes do not certify those performance targets.
The analyzer now partitions the opening-to-visible wall time into recorded
process intervals and the final draw-observation gap; inclusive CPU children
remain separately labeled rather than summed into a false exclusive total.


Final source-role correction: the existing selector retained only the current
native-optics role and discarded the other role of the same selected physical
base. That made opening/full handoffs alternate five rebuilds per warm action.
The owner now retains at most one packet per boolean role for an exact base
still selected in its current scope; both retire when that base leaves. No
cached metadata adds demand or pins by itself, and there is no base/packet cycle.
Source 203 and environment 345 checks pass cleanly, including mode reuse and
scope retirement. A corrected private causal probe isolates the prior character
cost: five packet misses, no sheet/base resolution, 15 family constructions
1.198 ms, role-map construction .643 ms and repeated finite header/size work.
The final real run confirms character preparation 1.437 ms and no repeated
packet rebuilds, rather than inferring a win from source visit counts.

Final matched live route `.runtime/player-runs/20261016T130629.163665Z` passes
81 checks. Fireball onset is 76.583/79.474 ms; warm frontend is 22.479 ms and
the subsequent process/draw-observation tail is 56.995 ms. Warm admission/decode
is 4.458 ms, canonical consumer 5.583 (reduction 4.274), packet setup .009,
compiler 6.738 and opening metadata 5.398. Metadata children are character
1.437, environment 1.033, record roles .469, size/header .431, publications
1.417 and source snapshot .068 ms. Header scope is 416 of 3,235 cached records.
Warm compiler EventTrace is 1.995 ms; full histories/logs remain present.
Compared with the pre-frontend 90.983/32.958 ms onset/frontend, this improves the
worker path but still does not meet latency or frame targets. The preceding
qualified run reached 66.710 ms onset; the final run's extra process interval
makes its end-to-end result slower despite the confirmed source work deletion.
Do not cherry-pick the preceding onset as the final-tree result or describe
these single-route measurements as a statistical speedup.

The final Fireball segments average 14.942/13.728 ms, peak 27.438/31.368 ms and
have p95 20.026/19.074 ms. Server execution is separately 613.627/443.204 ms.
The final report is `.runtime/frontend-final-role-live-analysis.json`; its
warm opening tail partitions into 13.606, 15.647 and 23.514 ms process intervals
plus 4.228 ms after the last process sample. CPU children attached to those
intervals are inclusive, not exclusive wall-time causes. No further lighting,
shader or engine change was made to improve a displayed metric.

Full native Studio after the final role-retention change passes 8,825 checks
with zero errors or warnings in `.runtime/frontend-final-role-studio.log`.
The final validation processes exit; no preview is intentionally left open.

### Opening-to-visible follow-through, 16 October

User authorized optimizing the measured 56.995 ms publication tail while server
work continues separately. This batch retains the same renderer, assets,
light values, event order and shared 2,000 us preparation allowance:

- Unchanged immutable optical observations reuse the published source
  resolution, cookies and native light nodes. Page-owner changes still reject
  stale preparations; changed/legacy optical input resolves normally. Due world
  work adopts its exact source pins before demand publication. Empty completed
  phases and existing prepared-owner readiness can finish at a spent allowance;
  actual constructors, binds, uploads and post-draw fences retain their gates.
- Required source contribution counts and physical contracts remain exact.
  Optional readiness is evaluated for queried paths rather than scanning whole
  hint catalogs. The existing union/diff skips identical source-set references,
  compares unkeyed contributions only with unkeyed references, and skips
  unchanged Boolean role publication. No second residency owner was added.
- A captured single dynamic non-batched receiver, with no removals, floor or
  support expansion and at most one captured receiver/group, runs the SAME
  passive atlas planner as one bounded scene-thread unit. An elapsed check
  precedes that work; binding/publication remains unchanged. Broader layouts
  keep their worker. Main planning CPU is separately measured; it is not added
  to world worker time.
- Pending releases no longer invalidate blood fields whose authoritative
  contributions they cannot affect. Actual flights, landing thresholds and
  field values remain unchanged. Real ordered kernel parity passes 1,100 checks;
  native blood preparation passes 32, including byte-identical 64x64 field
  pixels and zero redundant upload. That fixture reports three ObjectDB exit
  warnings; its clean functional result is not a clean teardown claim.

Source delta/union qualification passes 5,850 checks, six-operation source
selection 203, shared real-PNG residency 44, preparation admission 35 and native
receiver ownership 264. The receiver fixture compares exact single-receiver
addresses, supports, specifications and ordering against the worker planner.
Independent anti-slop and correctness/plan reviewers found no blocking issue.

First matched actual GUI route
`.runtime/player-runs/20261016T144457.063384Z` passes 81 checks. Warm onset is
64.681 ms and tail 42.988 ms. After the bounded atlas and union changes, final
route `.runtime/player-runs/20261016T145323.621572Z` also passes 81 checks:
warm onset 58.087 ms, frontend 22.953 ms and tail 35.134 ms. Compared with the
earlier final-role baseline this is about 27% less onset and 38% less tail in
these matched runs, not a statistical or 10x claim. The final tail partitions
into 7.501 and 23.054 ms process intervals plus 4.579 ms after the last sample.
The publishing interval includes only .033 ms inline atlas planning and .408 ms
blood sampling, with no blood kernel/upload work. Inclusive CPU children are
not additional elapsed intervals.

Cold first Fireball onset is 77.629 versus the baseline's 76.583 ms: no cold
improvement is claimed. Its new native resource/optical scope still has real
preparation work, and source-role publication can run twice across an opening
and its full continuation. The warm whole-action frame mean is 14.309 ms,
p95 19.687 and maximum 35.305. Therefore 100 fps/no-spike and <=30 ms onset
targets remain unmet. Server dispatch is separately 547.753/393.469 ms. No
backend changes were made. Evidence is in
`.runtime/publication-tail-final-live-analysis.json`; the actual GUI/live
measurement uses the same full-size SubViewport/display blit as the baseline.
The final live process exits but reports ObjectDB/resource teardown diagnostics.
Final native Studio seek/loop/faction/ordered-prefix qualification passes 8,862
checks with zero errors or warnings in `.runtime/publication-tail-studio.log`.
All owned validation processes exited; the final Windows process inspection
finds zero NDClientGodot Godot processes. The legacy broad SDK snapshot harness
was not rerun or newly qualified by this renderer/source batch.

### Shared reveal-publication completion — authorized 16 October

User requested a checkpoint and a common-cause fix for door, movement and spell
aftermath spikes. Starting checkpoint is `e138fc9`; source art remains ignored.
This continues operations 2/3 above, without a different renderer or backend.

Boundary: given the same accepted operation and published base, preparation
produces the exact next scene/atlas membership, materials, support contacts and
ordering operands privately. Publication adopts those prepared values once;
sampling consumes actual current actor poses/hover/time. No partial reveal,
future trace/audio, hidden-source exposure or visual retuning is allowed.

1. Finish atlas registration inside the existing bounded binding lane: prepare
   final new receiver/partition arrays and indices, group/source registration
   deltas and counts, and output/source sampling operands. Publish native array
   appends/map deltas rather than replaying GDScript row/group derivation. Avoid
   cloning the whole retained scene for ordinary sparse updates. Keep actual
   retained-node replacement commands and real capacity-growth normalization.
   Detach transferred arrays/maps from the old private retirement payload.
2. Finish scene-derived indexes in WorldPreparation: direct scenery ground
   targets and consumer deltas; prepared support-contact updates for the ground
   overlay; exact fixed order/subsequence/rank operands where that cut owns
   them. Remove the corresponding publication-time joins/reconstruction. Keep
   changing actor order and wall member selection under their existing owners.
3. Prepared static materials retain their actual prepared SourceMaterial sample
   values. Remove cross-group/material recertification at publication; ordinary
   scalar source-version/hover/visibility sampling still updates anything that
   actually changed since preparation. Dynamic/water sampling remains live.

Root owns native_light_delta; the anti-slop reviewer owns the matching atlas
source sampling change; correctness owns Play/WorldPreparation/ground overlay.
The independent plan guard also performs the anti-OOP review and checks the
whole ownership/order boundary. Native tests/profile runs are serialized.

Qualification: exact prepared-vs-original atlas addresses/group counts/order,
source changes during preparation, cancellation/retirement, support changes,
native recorded prefix/seek/loop cases, then the SAME real action route (door,
move, Haste, two Fireballs). Report per-parent phase breakdown and actual work
counts, all slow frames and idle separately. In particular, `addresses_ms`
at checkpoint included output_materials_ms; preserved-row diagnostics alone do not
prove a runtime row walk. Door actual address publication was .015 ms, while
Fireball's 1.184 ms needs its real index/buffer/upload branch distinguished.
Targets and full elapsed accounting remain unchanged; no warm-FPS or no-spike
claim follows merely from green functional tests.

### Shared reveal owner result and limits — 16 October

Checkpoint requested by the user was committed first as `e138fc9`. The new
batch completes prepared values inside the existing owners, without backend,
Factory, artwork, shader math, light tuning or event-clock changes:

- Atlas binding prepares final receiver/partition append arrays, indexes and
  output samples. Publication uses native array/map operations and ordered
  retained/group commands; zero-user/drop/reappear group identity is preserved.
- A packed floor's current row directory is its only slot authority. Removed
  eager per-receiver slot repair and duplicate per-tile scenery consumers,
  including their rotation producer. Actual projection/style/capture resolves
  the directory when needed. No every-floor search in production scenery sync.
- Actual canonical membership/order rebuilds prepare touched WorldRows indexes
  and GroundOverlay maps alongside their already prepared arrays. Publication
  adopts references. Ordinary same-membership edits remain sparse; native map
  merge replaces interpreted per-key after-value insertion. Displaced maps and
  passive completed preparation data remain under existing budgeted retirement.
- Existing light preparation now also owns colour/cookie updates and removals.
  Publication does not resynchronize every page or sample empty actor anchors.
  Actual displayed actor/fixture sampling still precedes native projection.
- Static material sample ownership replaces cross-group recertification.
  Explicit style/output fields no longer trigger empty generic uniform copying.
  Current hover/frame/water/source/binding changes keep their real consumers.
- Fixed a real prepared-to-displayed lease hole: completing movement withdrew
  152 immutable source records, then reacquired them next frame (7.031 ms plus
  5.784 ms). Terminal promotion now precedes displayed-source replacement and
  same-frame optional work, taking the latest full continuation rather than a
  cached opening-plan pointer. Exact readiness/accounting is unchanged.

The first attempted scenery/support delta still did wholesale retained-floor
registration at the cue and regressed the live route. It was rejected and
deleted, rather than accepted because isolated checks passed. The rows above
describe the corrected final ownership.

Matched real GUI route: door, move to `[26,6]`, Haste potion, Fireball `[32,8]`,
Fireball `[33,7]`; Forward+/Vulkan RTX 5090, 1600x960, view size 18, full-size
native viewport plus root display blit. Owned Godot runs were serialized. Two
final runs, with no production changes between them, each passed 81 checks:

| Action playback maximum | Earlier checkpoint route | Final run A | Unchanged repeat B |
| --- | ---: | ---: | ---: |
| Door | 47.556 ms | 69.515 ms | 44.145 ms |
| Move | 37.678 ms | 38.792 ms | 31.018 ms |
| Haste | 20.101 ms | 36.999 ms | 22.260 ms |
| First Fireball | 26.192 ms | 30.416 ms | 24.577 ms |
| Second Fireball | 35.305 ms | 38.229 ms | 29.408 ms |

These ranges do **not** establish consistent whole-frame improvement. They do
show removed work at the measured ownership boundary:

| Actual component | Instrumented during this batch, before its correction | Final repeat B |
| --- | ---: | ---: |
| Door canonical row adoption | 3.461 ms | 0.021 ms |
| Door support publication | 2.329 ms | 0.140 ms |
| Fireball scenery membership | 4.054 ms | 0.036 ms |
| Fireball floor address publication | 1.101 ms / 1,179 index writes | 0.128 ms / zero index writes |
| Door generic parameter-copy operations | 185 | 11 |
| Movement generic parameter-copy operations | 214 | 10 |

In repeat B the remaining 44.145 ms door frame has 42.103 ms player callback:
17.322 ms native lighting, 5.848 ms session/timeline, 4.131 ms world publication,
3.933 ms actor sampling, 3.317 ms ordering/output, plus source lighting, actor
membership, wall selection and optional preparation. Native lighting includes
the atlas, shadows and projection; its atlas includes resize, registry, binding,
output, material sample and culling. Do not add these children to their parents.
The door still admits 279 sources / 1,156 receiving specs, including genuine
native viewport growth and 1,098 cull checks. It is still a spike.

Repeat B has two post-action-start intervals above 33.33 ms: that door frame
and a 37.985 ms Fireball targeting interval (aim marker, before cast playback).
The targeting interval has only 12.449 ms inside the measured player callback,
unchanged pipeline counts and no world publication. Its remaining interval is
not attributed to a particular input/native/OS cause by this instrumentation.
Run A additionally has 57.597 ms during targeting, 38.792 ms movement,
36.999 ms Haste, and 38.229 ms Fireball aftermath. No no-spike or 100-FPS claim.

Packet-to-first-visible Fireball is 70.002/60.019 ms in A and 67.398/61.186 ms in
B (first/repeated). B's opening preparation is 26.008/22.183 ms; the remaining
41.390/39.003 ms includes actual process intervals, prepared-world gates and the
draw observation. Server dispatch remains separate: 713.336/446.097 ms in A,
624.248/422.646 ms in B. This batch does not solve those server times or claim
an improvement in repeated-cast onset.

Evidence: `.runtime/player-runs/20261016T154109.508036Z` and
`20261016T154406.286364Z`; `.runtime/shared-reveal-final-live-analysis.json` and
`shared-reveal-final-repeat-live-analysis.json`; complete frame profiles
`generated/profiles/2026-10-16T17-41-40-gallery-live-spells.json` and
`2026-10-16T17-44-35-gallery-live-spells.json`. Raw CPU/context diagnostics retain
the actual work counts and nested stage decomposition, not only an FPS summary.

Correctness qualification: source output samples 159 headless / 204 native;
staged atlas 1,987; native lifecycle 221; prepared emitters 69 headless / 79
native plus 17 ownership checks; ground support 67; scenery 10; prepared
admission 28; sparse preparation 69; actor material/retirement 3,726; world
projection 147; native floor/rotation 28; native HUD grid 241; terminal lease
handoff 8; final native WorldPreparation/atlas 150 (nine cases). Output, staged, emitter and terrain suites include at least 85 exact
native framebuffer comparisons. Final full native Studio passes 8,647 checks
covering seek/loop/faction selection and exact ordered prefixes. Its count varies
with sampled playback frames; it is not a fixed test inventory count.

The old `media_completion_checks` fixture was attempted but has stale null-sense
and missing native-render-owner assumptions before reaching the new regression;
it was restored unchanged, not reported green. The new narrow terminal handoff
fixture proves CPU registration continuity; real playback remains qualified by
the live and Studio runs. Sparse preparation retains 26 ObjectDB exit warnings;
final live runs retain 30/31 leaked-instance warnings and one resource-at-exit
diagnostic, plus the missing generic-caster portrait warning. Native Studio and
the focused native output suites are clean. No clean-live-teardown claim.

The anti-slop/correctness reviewers and independent plan/anti-OOP guard found no
remaining blocker in these saved ownership changes. Broader latency/frame
targets remain open. All owned client Godot processes were closed after testing.
