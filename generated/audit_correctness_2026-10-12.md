# Read-only correctness audit — 2026-10-12

Scope: the live Godot player, SDK admission/transport/journal/reducer, presentation session/timeline, actor and environment adapters, animation, HUD/input, media loading, offline grid renderer, launcher and selected acceptance tests. This was a source and existing-evidence review, not an exhaustive proof of every file. No source/assets were changed and no Godot/render processes were started by this reviewer. The report itself is the only written artifact.

The original observations and line references below are retained as the historical
audit. Subsequent authorized implementation and native results are recorded in
the disposition section at the end; the original read-only limits do not describe
those later checks.

## Confirmed findings

### P2 — Schema-admitted omitted defaults can break the live scene

Locations:

- `/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/session.gd:53`
- `/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/play.gd:748`
- `/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/sdk/transport.gd:339`

The SDK admits and returns raw packets without adding schema defaults. `InitializationResponse.kind` and `CommittedReceipt.kind` are optional fields with schema defaults. Session `_consume` reads `packet.kind` before normalizing; the scene's command handler reads `receipt.kind` directly. A valid initialization without `kind` therefore fails before its presentation message and ACK. A valid committed receipt without `kind` fails after `action_request` was cleared and leaves command input held.

This is a supported contract edge, not an observed failure of the current backend's normal serialization. `tests/sdk_transport_checks.gd:203–208` explicitly accepts an omitted-kind committed receipt and asserts that the returned packet still lacks the field. `sdk/journal.gd:87–94` already handles initialization by cursor and normalizes its reducer copy correctly.

Direction: infer the initialization root from its admitted cursor, and normalize a separate response copy at the presentation boundary before control flow. Preserve raw journal bytes and the transport's raw-result contract. Add scene/session regressions for those two admitted packets; the existing transport regression alone cannot catch this integration failure.

### P2 — Live character prefetch has no residency limit

Locations:

- `/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/play.gd:404`
- `/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/play.gd:423`
- `/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/media_warmup.gd:7`

Each newly admitted actor or changed outfit queues every authored clip for every selected layer. Completed work retains both the decoded `Image` in `source_images` and the GPU texture in `textures`. Live play never invokes the inherited texture-pruning path; replacing an outfit frees its render nodes but does not retire that outfit's sheets. Different encountered rigs/outfits accumulate complete clip libraries for the lifetime of the scene.

Existing native evidence demonstrates the current scale: `generated/profiles/2026-10-12T02-29-44-encounter-final.json` ends with four actor rows, 229 placements, 421 textures, 3,121 MiB reported static memory and 3,845 MiB reported video memory. `2026-10-12T01-31-44-encounter-lazy.json` ends with the same four actors/229 placements but 142 textures, 1,088 MiB static and 1,147 MiB video memory. These are the profiler's categories; do not interpret their sum as measured process RSS.

Direction: budget residency and prefetch for active outfits/current or imminently needed clips, while keeping exact authored pixels and avoiding synchronous I/O on a required animation frame. Any eviction must account for the warmup `queued` set so an evicted path can be requested again. This finding establishes memory growth; it does not claim a measured frame-rate regression.

### P2 — Height-only resizing can move gameplay controls off-screen

Locations:

- `/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/play_hud.gd:202`
- `/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/play_hud.gd:216`
- `/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/play_hud.gd:173`

The HUD caches only viewport width and calls `_layout()` when that width or unrelated gameplay state changes. Its bottom controls and inventory-panel height depend on viewport height. During an idle turn, resizing only the window's bottom edge from 900 to 600 pixels leaves the bar at y=754 and Inventory/End Turn at y=826, outside the viewport until some unrelated change triggers layout. The project does not disable resizing or use a fixed stretch viewport.

Direction: invalidate layout on the complete viewport size or the native resized signal. The UI suite checks an initial 720p layout, but does not exercise a height-only resize after initialization.

## Shader follow-up requiring native confirmation

**Subsequent disposition: confirmed and fixed.** See the native selection probe
and renderer dispositions below. The following paragraph records the original
unconfirmed finding.

`environment.gdshader:73–75` and `grid.gdshader:69–70` always convert sampled RGB from linear to sRGB before evaluating source-byte `source_rgba` selections. This deserves a targeted Compatibility-renderer probe: the current lighting/actor shader code explicitly accounts for Compatibility's sRGB output boundary. If these `source_color` samples are already sRGB, the unconditional conversion turns byte 1 into approximately byte 13 and incorrectly excludes it from the authored shadow bounds `[0,0,0,1]` to `[1,1,1,249]`. Picking and the canvas ownership mask compare original bytes.

A read-only scan of the registered library source images found 113,996 relevant RGB=1 shadow pixels across 349 samples, so the input is real. Example: `environment/library/fantasy.misc.e3.json`, original `Misc E3_E.png`, has 621 such pixels; one value is RGBA `(1,1,1,190)`. This report does not promote the renderer-dependent conversion concern to a confirmed runtime defect without the native probe. Do not modify source artwork to compensate.

## Wall change reviewed during this audit

The new shared, per-wall list of qualified visible-tile diamonds is consistent with the current visible-floor requirement: the shader changes opacity/discards only covered pixels; picking uses the same canonical diamonds; opaque fragments ignore later-wall ownership discard. Mixed corners can qualify by a front boundary while caps outside the mask stay solid. Rear straight boundaries retain their front/behind eligibility rule. Hidden mode no longer hides the whole node.

This is visible-floor coverage, not an arbitrary actor-silhouette mask. An actor's head or jump can extend outside the projected floor union. No separate actor-content pass was added or implied. Parent-reported native wall checks were 22 corner checks and 565 visibility checks passing; they were not rerun by this reviewer.

## Review limits and retained boundaries

- The SDK reconnect path does not automatically resend commands; the scene queries the original receipt after an ambiguous transport failure. Raw journal admission/reduction is transactional and duplicate sequences are checked before replay publication. No new authority or command-duplication defect was established in these inspected paths.
- Existing protocol/reducer/transport and native gameplay tests cover substantial ordinary behavior, but do not cover the admitted-default scene integration, repeated outfit residency growth, or height-only HUD resize described above.
- Offline `demo.tscn` grid benchmarks are not evidence that the live player has identical batching or large-map capacity. Their known camera clipping and fixed-view coverage limits should remain explicit; this audit does not reinterpret their reported speedups as full-map live performance.
- Item-source lighting still has its documented boundaries: disclosed item emitters, no private spell emitters or optical wall shadow reconstruction. Modular/goblin geometry coverage remains a separate supplied-asset task. These are acknowledged limits, not newly discovered bugs.
- No native reproduction was performed during this read-only pass. New failures are established from exact control flow, schema/test contract evidence, or existing recorded measurements; the renderer-dependent shader concern is explicitly left for native confirmation.

## Subsequent renderer dispositions — 12 October

### Fixed: original-byte source selection in Compatibility

The installed native Godot 4.7.2 Compatibility renderer reproduced the suspected
classification error: source RGB byte 1 disappeared from the shadow pass and
survived in the body pass despite the original authored bounds accepting it.
`environment.gdshader` and `grid.gdshader` now convert sampled colour back to
encoded bytes only when `OUTPUT_IS_SRGB` is false. Lighting output conversion
and the original PNGs remain unchanged. The actual `torch.body` PNG contains
73 affected RGB=(1,1,1) pixels among its 153 selected shadow pixels.

`tests/environment_selection_checks.gd` exercises both production shaders,
bytes 0/1/2/20, and both body/shadow selection inversions: **16 checks, 0 failures**.
Evidence: [report](environment_selection_checks.json),
[native failure before repair](../.runtime/environment-selection-before.log),
[native result after repair](../.runtime/environment-selection-after.log).
This probe validates Compatibility; other renderers were not run.

### Fixed: intact registered door leaf/frame overlap

The later user screenshot exposed a separate local assembly error: every leaf
pixel previously drew after the stone frame. Original legacy actor-depth
registration demonstrates both front and rear leaf pixels in all four views;
reversing the complete frame/leaf order is also wrong. The adapter now uses two
complementary GPU leaf passes around the original frame, decoding the supplied
RG16 little-endian painter-depth packet. This is separate from the lighting
packet's RG16BE ray depth. Original colour, pivot, scale, normal and lighting
registration are unchanged.

`tests/door_overlap_checks.gd` compares the real A1/`environment.directional_door`
assembly with an independently decoded source-JSON pixel oracle: closed,
inward and outward in four views. **79 checks, 0 failures**; all 12 oracle captures
are byte-identical. The previous order differs by 16–799 pixels across these
cases. Destruction and banks lacking the legacy ground-origin registration keep
one leaf pass and were checked for duplicate rendering. Evidence:
[report](door_overlap_checks.json), [native log](../.runtime/door-overlap-checks.log).
Scope remains local to the door's own frame; this does not implement arbitrary
door/actor/adjacent-wall per-pixel ordering or resolve other families' pose offsets.

### Validated: incremental world updates and cached static order

`play.gd:_sync_world` retains unchanged visual owner groups and floor-material
batches. Canonical rows stay separate from camera-selected resource IDs and
Hidden-mode rear-wall substitutions. Changed owners and affected floor batches
are recreated; first use of a camera quarter binds its source registrations.
`_sort_draws` retains the sorted static sequence and merges visible actor layers
using the unchanged painter key and identity tie-break. Moving node depth is
compensated even when a jump leaves its ground ordering key unchanged.

`tests/world_incremental_checks.gd` uses the actual recorded Crypt initialization
and explicit presentation after-values for door states and wall modes. It checks
the complete order against an independent full sort and native pixels against
an independent full rebuild, including source-backed doors and Hidden corners.
**89 checks, 0 failures** across 12 room comparisons, including the subsequent
production media-preparation assertions. Eleven comparisons are
byte-identical; one translucent q3 comparison differs by at most 1/255, with no
pixel beyond the stated one-byte tolerance. Resource identity checks supplement,
rather than replace, these order and pixel checks. Evidence:
[report](world_incremental_checks.json), [native log](../.runtime/world-incremental-checks.log).
These are rendering equivalence checks, not a large-map speedup measurement.

The subsequent bounded quarter cache retains up to three inactive static views
for the current canonical world rows. Inactive nodes are hidden and omitted from
active picking, fixtures and ordering. Actual row changes release those views;
unchanged displayed revisions do not. Activation refreshes current wall modes,
Hidden source substitutions and wall ownership before final mask publication.
This also removes the former duplicate mask rebuild during Hidden rotations.
[The native cache regression](world_view_cache_checks.json) passes **87 checks,
0 failures**: all 12 cached-versus-fresh room comparisons and three mode round
trips are byte-identical. It additionally checks exact order, resource retention,
inactive isolation and release following a door-state change. The
[native log](../.runtime/world-view-cache-checks.log) contains no script or renderer
errors. First construction and current-visibility updates still cost work; the
large-map timing comparison remains separate.

### Fixed: scene defaults, retained replay and viewport height

The scene now normalizes separate presentation copies of choices, previews and
receipts; original SDK/journal bytes remain unchanged. Initialization is identified
by its cursor. A restored journal's final state is reused only for its exact current
cursor; replaying initialization cannot expose later facts. Offline replay admits
once and rejects a filename/cursor mismatch. `player_defaults_checks.gd` passed
16 checks, including omitted defaults, retained-prefix replay and renamed packets.

HUD layout now observes both viewport dimensions, and action controls rebuild
when their discovery/selection/layout inputs change. Native UI checks passed 39,
including height-only resizing. The current SDK contract suite passed 11,719
checks across exact decimals, protocol/Python parity, reducer, journal and transport.
These results resolve the named audit findings, not every possible gameplay case.
