# NDClient Godot

Run **`play.cmd`** for the backend-driven player. It starts Lantern Gallery,
connects the Expedition seat, and opens `play.tscn`. The original Crypt rooms
lead through native doors to a furnished 48 × 36-cell hall. Use
`play.cmd --scenario crypt` for the original small encounter. Closing
that window stops its owned backend. The launcher uses the existing WSL cached
Python environment; private credentials, logs and SDK recordings stay under
`.runtime/player-runs/<timestamp>/`. The launcher reports readiness only after
initialization, acknowledgement and current command choices are available.

The Windows project uses **Forward+ with Vulkan**, validated on the RTX 5090.
Opening the project directly selects the same player scene; use the launcher to
provide its backend connection. The 3D world still receives its painted lighting
from native Godot 2D lights and authored normal maps.

## Live player controls

- **Click** ground to move or a disclosed object to use its native default
  interaction, including approaching and opening doors. **Right-click** exposes
  admitted alternatives. **Ctrl** deliberately selects force attack; **X**
  switches the visible melee/ranged preference for ordinary creature clicks.
  The preference is retained per actor; it never substitutes another weapon.
- The transparent **Base / Class / Spells / Items** blocks use the existing
  authored icons. Hover a family to inspect its actual native variants and costs.
  Each group owns its page controls and wheel input. **1–0, minus, equals** use
  the currently painted first row; **Shift** plus those keys uses the second row.
  Both rows stay aligned when group headers include weapon or paging controls.
  Unavailable choices remain inspectable and cannot execute.
- **M / J** select move or jump. Targeted actions retain the ordered target
  selection: **Enter** confirms, **Backspace** removes its last selection and
  **Escape** cancels the most local popup, panel or targeting interaction;
  otherwise it opens Settings. Character light smoothness offers Original,
  Gentle and Reference (the handoff default), saved locally. The modal owns
  keyboard/mouse input while the displayed timeline and SDK intake continue.
  **Light strength** scales native emitted light from 0–150%, without changing
  source colours or the ambient floor; **Fire light flicker** defaults off.
  Legal self actions execute once from their icon. **Space** ends the turn.
- **I** opens equipment and the searchable carried inventory. Hover an item or
  slot to see native compatibility; equip, unequip, use and drop preserve the
  exact discovered item/action. Inventory changes appear on the displayed
  timeline, without optimistic local edits. Text focus and panel scrolling own
  their input and cannot issue world commands.
- **Click a chest** to approach and open it. Its small storage panel appears
  after the native Open action commits. Select an item and **Take selected**,
  double-click its icon, or **Loot All**. **× / Escape** dismisses only the
  window; right-click the chest for its native Close action. Clicking an open
  chest reopens the window. Contents and transfer buttons follow the displayed
  player state and current admitted choices, including observed-empty storage.
- **L / Log / Events** opens history. **Combat log** shows native recorded text
  and roll details at displayed event commits. **Event stream** uses green for
  completed visual components with a real native frame witness, red for missing
  or partial presentation, amber while playing, and neutral for state-only or
  offscreen events. Green confirms a sampled frame, not every authored frame or
  pixel visibility through occluders. Select a row for component-level reasons;
  **Missing only**, **Follow latest**, **Copy trace / Copy selected** help review
  coverage. Copy Log copies readable native combat text. Future queued events
  expose counts only. The view shows the latest 200 rows from a bounded 2,000-row
  history; the full subjective source remains in its SDK recording.
- **Q/E** rotate through four views; **wheel** zooms; **middle-drag** pans;
  **F** follows the current actor. **G** toggles the grid and the cursor
  reports its cell and support height. The **Normals** button beside **Grid · G**
  displays the receiving normals without illumination for inspection.
- **Alt** shows labels for admitted interactables. **Z** cycles **Solid →
  Translucent → Hidden → Solid**; the FPS line shows the mode. Only foreground
  wall members whose finite boundaries cover currently visible support tiles
  fade uniformly or disappear. Rear-facing room walls stay solid, even when a
  neighbouring corridor is visible. Remembered tiles do not qualify.
  In Hidden mode a mixed front/rear corner switches to its original rear straight
  wall, including that wall's authored colour, normal, depth and registration.
  Ordinary picking passes through affected pixels; **Ctrl** still targets the
  original wall identities. Typing in inventory search does not change the mode.
  Visible tiles include nonwalkable cells and their actual support elevations.
  Qualification uses native grid boundaries and support elevations. It does not
  crop source artwork to a floor diamond or track character/prop silhouettes.
  A GPU ownership mask suppresses doubled opacity at joins. A conservative
  one-screen-pixel boundary retains source-over blending to avoid edge holes at
  fractional zoom; it is not an exact single-alpha compositor at every edge.
- **P** pauses displayed playback while SDK intake continues. The HUD shows
  the displayed actor's HP/resources and FPS. Spending controls wait for the
  displayed command boundary.
- Hold **Shift** when choosing a route to disable the native safe-route
  preference. Opportunity attacks still resolve in the backend.
- **F8** starts/stops profiling; **F9** saves recent frame history as JSON in
  `generated/profiles/`.

The renderer reads the surviving authoring JSON directly: creature rigs,
modular appearance, exact equipment variants, movement contexts, attack recipes,
body contexts, source frame keys and environment registrations. Native
AnimationPlayer/AnimationTree sample the displayed clock. Camera changes do not
restart actions. The player retains Camera3D, original 3D quads, floor MultiMeshes,
elevation, painter order and original-alpha picking. Only receiving light changes:
native PointLight2D/DirectionalLight2D illuminate separate source cells in a
SubViewport; unshaded 3D materials consume those straight-RGBA results. A gray
CanvasModulate at 0.18 provides readability. The painted world has no 3D receiving
lights and no custom diffuse-light loop.

Native Canvas owns tint, style and accumulated lighting. The former per-channel
albedo clamp was removed because it changed the reference demo's colours.
Overlapping lights can still saturate the native LDR output; **Light strength**
reduces their energy globally without a colour clamp. Source and normal samples
retain nearest filtering.

Disclosed, active items supply their original very-bright, bright and dim radii.
Their outer radius sets the native 2D cookie diameter. The recovered light cookie
and warm Torch/Wall Torch colour come from NDCharacterLight; other semantic item
IDs remain white. Carried sources follow displayed support/jump positions, and
ignite/extinguish follows displayed commits. The normal-light height is 56 source
pixels at the current zoom, matching the liked demo fixture and remaining separate
from world elevation. The earlier recovered template used 20. Directional sources
come from world.json (currently empty). The native 2D directional behind-plane
limitation is reported explicitly rather than silently flipping its direction.

Retained terrain/objects remain rendered from their last-known subjective state;
only currently admitted actors and light sources are active. Remembered scenery
uses 0.62 brightness and 0.35 saturation, independently of illumination.
Ambient and Godot's atmospheric fog are not fog-of-war implementations. Undisclosed geometry is not imported to fill
the unknown area.

Reference research: Larian documents distant/local probes as the indirect-light
layer in [Divinity](https://docs.larian.game/Light_probes); BG3's
[Patch 5](https://baldursgate3.game/news/patch-5-now-live_99) explicitly mentions
fire ambient illumination, while [Patch 4](https://baldursgate3.game/news/patch-4-now-live_96)
separately fixes map shroud/minimap display. These support separating illumination
from exploration state. They do not document a universal BG3/DOS2 minimum
brightness or a complete remembered-world pixel policy; our 0.18 ambient value is
a tested presentation choice, not a claimed Larian setting.

Carried portable lights use an explicit above-avatar optical convention: 2.5
elevation steps above displayed support and jump lift. Their native grid XY,
activation and radii stay unchanged; inventory-only Torch has no authored hand
attachment. Registered torch fixtures use the original flame's brightness-weighted
vertical centroid and pivot/scale, prepared once with their source images. Other
unregistered item emitters retain the one-step optical fallback.
The original torch.flame supplies 16 frames at 10 FPS with its original pivot and
scale. **Escape → Settings → Fire light flicker** defaults off for debugging:
fire brightness and optical height use the authored cycle average while flame
artwork and carried-light movement continue. When enabled, its animation clock
drives brightness fluctuation bounded to ±15% and the original flame centroid.
Shadow source ranking always uses the cycle average to prevent idle switching.
No second emitter is added for the flame sprite. Environment normals retain
their authored octahedral encoding and source-to-world transforms; native Canvas
lighting runs before final wall opacity and the existing wall-join coverage mask.
This does not model light transmission through stone or add wall shadows.

Modular layers use the full-component delivery and
`NDCharacterLight/NORMALS_PRODUCTION_HANDOFF.md`. Exact source identities select
original depth/support/normal-valid data plus Original/Gentle/Reference normals.
All RGB channels decode as linear numeric data; Canvas Y flips once. Original
alpha, tint, registration and animation clocks stay unchanged. Profile changes
replace only the prepared normal sampler. The same source pixel can remain
unsupported; unsupported pixels use the original flat receiver.

Generated modular ground shadows use original component depth/support/alpha,
including weapons, with no baked Shadow fallback. Each displayed actor has an
isolated native 3D shadow-measurement viewport; its helper never lights the painted
world. The strongest disclosed point source casts, and all other point sources
contribute fill through their original cookies. A black source-over output preserves
existing terrain colour. Helpers stop rendering when their inputs are unchanged.
These dense casters require measured gameplay profiling; directional shadow fill
is not implemented (the current source list contains no directional lights).
Delivered creatures use the same generated-shadow path at their native cell size
and authored optical ground. Uncovered creature rigs retain their authored shadows.

The atlas shares native materials across identical floor-source instances and
stores only nonzero-alpha bounds for static colour receivers. Animated sources
and water retain stable full cells. Storage crops never alter source registration,
3D quad sizes or picking. Artwork remains external and unchanged. Older 3D
receiving-light reports in generated/ are historical evidence; current migration
checks and frame profiles are recorded separately.

Static receiving transforms are cached against their original quad and instance
data. Orthographic pan/zoom uses one native parent transform; published changes
update only changed projections, and floor atlas addresses upload once per batch.
Dynamic frames, highlights, water time and current/remembered styles retain their
own update paths. Preparation never publishes future state into the light atlas.
The current atlas has a finite 8192×8192 capacity; overflow reports an error and
retains the previous published layout. Compatibility admits at most 15 positional
lights per CanvasItem; the Gallery profile reports conservative overlapping
source counts rather than assuming the 3D light-count setting applies to Canvas.

`presentation/session.gd` connects the existing SDK to a worker-prepared causal
timeline. The latest consumed state and displayed state have separate ownership.
Source-order commits expose HP/life changes at authored impact/release, hold a
mover during an opportunity attack and never animate an uncommitted step. A
lethal interruption after earlier committed steps preserves those steps. New
actor/support staging is presentation-only and never overwrites known tiles.
Live sessions and recorded journals use the same preparation and rendering path.
Ambiguous command failures query the original receipt; commands are not resent.

The live surface exposes native object interactions, Base actions, Class
abilities, Spells, Items, inventory/equipment commands and end turn. These use
the existing discovery, preview and numbered-command protocol. Authored body
playback covers movement, jumps, attacks and damage/life reactions. Apart from
the restored authored torch flame, general VFX,
projectile travel, dedicated spell/condition presentation and connector traversal
animation remain outside this pass. Their facts still reduce canonically and
omitted visuals have explicit diagnostics. A partially
disclosed jump uses only its disclosed edges; it does not invent the hidden arc.
The launch map is the backend Lantern Gallery: the original Crypt rooms connect
to a larger furnished hall through ordinary doors. Its tiles, placed objects,
lights, routes, actor turns and disclosure come from the engine. The original
small Crypt remains available with `--scenario crypt` for comparison.

Loot, displayed combat history, render coverage and native clipboard/input
acceptance are indexed in `generated/loot_history_validation.json`. The storage
flow can be repeated with `tools/loot_scenario.py --output <new-run-directory>`;
`tests/history_view_checks.gd` takes `--recording <journal-directory>` and needs
a native rendering window for its frame/clipboard assertions.

The earlier repair, SDK, live-gameplay and small/large performance results are
indexed in `generated/performance_scale_validation.json`. Historical
controls/lighting/chest checks remain in `generated/interaction_validation.json`;
earlier reducer/animation coverage remains in `generated/player_validation.json`. The slow
live lane can be repeated from the cached engine Python environment with
`tools/play.py --headless --test-script res://tests/player_live_checks.gd`; omit
`--headless` for native pixels/GPU profiling. Recorded playback checks use
`--script res://tests/player_view_checks.gd -- --recording <journal-directory>`.
The compiler's narrower checks use
`--script res://tests/presentation_checks.gd -- --journal=<journal-directory>`.
Native door/equipment/Dodge/search checks use
`tools/play.py --test-script res://tests/player_interaction_checks.gd`;
`chest_live_checks.gd` and `lighting_live_checks.gd` run their real encounter
sequences through the same launcher. `wall_visibility_checks.gd` accepts a
`--recording` directory and checks initial/terminal visibility, elevation changes
and keyboard focus. `wall_member_view_checks.gd` rebuilds complete wall runs from
original native members in four views at fractional zoom. The former
`wall_fragment_checks.gd` and `hidden_corner_checks.gd` delegate to that corrected
whole-room regression: their old floor-diamond/corner-only comparisons missed
the reported wedges. `wall_reveal_checks.gd` covers finite boundary spans and
support elevation. `wall_compositing_checks.gd`
separately exercises full-opacity joins and zoom-dependent ownership edges.
`architectural_lighting_checks.gd` covers original walls/corners and closed,
inward-open and outward-open door artwork in four views; door after-values in
this shader test are named fixtures, not live gameplay commands.

Intact chests now use the preserved original library colour, pivot, depth and
normal records. The six original-rest pairs come from the existing
`tools/build_unity_map.py` mapping: source JSON still names the reconstructed
banks, which remain the destruction source. Boolean `state_field` values select
the actual `"false"`/`"true"` rest keys. Closed/open artwork keeps the original
E/S/W/N facing convention. The eight-view native comparison has no extra
silhouette pixels; RGB differs slightly through Godot's documented GLES colour
transfer, rather than through texture interpolation or altered source artwork.

The validation artifact distinguishes real backend gameplay, exact recorded UI
projection, named boundary fixtures and native shader comparisons. Additional
coverage and performance evidence for the wall/encounter repair is in
`generated/render_repair_validation.json`.

Wall tiles are assembled from the disclosed grid edges before rendering. Two
adjacent walls with matching cell, material and vertical span use the existing
authored corner resource, including its normal/depth maps and registration.
Both backend wall identities remain available; picking retains the original
straight-wall hit areas and painter priority. Original side-corner views are
selected with their actual left/right artwork convention. Reveal selection uses
finite native boundary spans and currently visible support tiles. A selected
member fades uniformly or is omitted entirely; no projected diamond clips its
artwork. Equal-opacity members retain the original corner. Mixed corners use
their original straight members, keeping rear walls solid.
Removing either edge restores straight artwork. More complex junctions
remain separate edges until corresponding authored pieces are available.
Character layer colours pass through one sRGB conversion in
Compatibility, preserving original midtones. Matching modular normal/depth
companions now use the completed per-source delivery described above.
This uses the current 3D sprite renderer. Godot's `TileMapLayer` is 2D, while
`GridMap` places `MeshLibrary` meshes; neither replaces the backend's map state.

Character media preparation preserves an exact required set for the displayed
outfit/action and one queued group. The same worker also warms every authored
clip for outfits and equipment sets in displayed state and the bounded,
already-received operation window. This includes upcoming disclosed actor
families before movement arrives; prefetch does not publish actors, tiles or
outcomes. It does not load the unrelated asset catalog. Original PNGs decode on
four bounded workers; the scene publishes them in demand order and uploads at
most one prepared texture per frame. Startup waits only for its exact required
sources. Optional family warmup runs in the background, while each actual group
waits only for its exact required
sources. Loading does not advance the display clock or become a catch-up jump;
SDK intake/acknowledgment remains independent. Optional unavailable sources are
reported; missing required sources stop their own presentation boundary.

The encounter cache has a configurable **16 GiB combined soft budget** at
`source_data/encounter_cache_mib`, covering decoded CPU image bytes plus
conservative RGBA8 GPU estimates for both characters and environment. These
are accounting estimates, not measured VRAM or process RSS. Required current
and upcoming sources take priority and remain pinned even above that budget;
optional family preload fills the remaining capacity. Exact source paths are
deduplicated. The original two-party Crypt census has 1,626 unique current-family
and environment sources, with a conservative 13.87 GiB combined estimate.

A native Forward+/Vulkan startup reached playable choices in **6.342 seconds**,
versus **24.555 seconds** in the preceding full-family-gated run. At readiness,
all 200 mandatory sources were uploaded; 1,677 optional sources remained queued.
The combined CPU/GPU estimate was 2.73 GB then, growing progressively within the
same cache budget. This measures scene initialization through input readiness,
excludes engine launch/import, and does not control operating-system file-cache
warmth. See `generated/player_startup_checks.json`.

Original colour images retain their unchanged CPU alpha for picking until the
whole source is evicted. Modular normal/depth/support/validity companions
release CPU Images after upload; their resident GPU textures satisfy readiness.
Revisiting a resident source therefore does not decode it merely to restore
picking data. Budget pressure releases at most two unpinned textures per
rendered frame. Accepted source-family membership and residency diagnostics
are reused across action changes. Current readiness, background preload counts,
combined estimated bytes, and evictions are exposed by `encounter_preload`,
`character_media`, and `environment_media` in profiles.

The same queue prepares original environment colour, depth, normals, masks,
door partitions, corner members, water inputs and fixture frames for all four
views. World creation waits for these sources; a selector miss is explicit,
without a synchronous live decode fallback. Fixture luminance uses the same native image reduction as before on the worker.

Source metadata is prepared on a worker with its own authoring cache and shallow
snapshots of the relevant canonical map indexes. Immutable group unions cover all
staged/committed after-values, so each step or HP revision does not repeat source
planning. A prepared lookahead group promotes directly while the next group's
metadata is prepared. `media_metadata_ms` is the latest worker duration, not a
per-frame CPU phase; `media_metadata_pending` distinguishes pending preparation.

The environment metadata index retains only the last requested map. Changed
terrain records and affected wall cells rebuild their source closures; sense-only
changes refresh fixture eligibility. All 102 authentic Gallery packets (123
current/next windows) match an independent exhaustive planner in 371 checks.
That comparison measured 7.65 s versus 1.46 s of metadata CPU work; it is not a
frame-time or GPU-speed claim. Completed plans also publish immutable raw JSON
cache entries to the scene, including the component geometry table. Mutable
planner indexes remain on the worker; first binding avoids parsing those same
files again on the scene thread.

Presentation compilation runs separately from the transport consumer. The SDK
ACKs only after durable journal admission/reduction, regardless of display pause
or media holds. Preparation keeps at most two complete operations ahead of the
displayed sequence; one operation may contain several lineage groups. A small
admitted-packet handoff avoids repeated decode/normalization in the common live
path. Overflow stays in the journal and is read when needed, without dropping
source events. Canonical state and the raw journal remain complete; completed and
skipped presentation diagnostics retain the latest 2,000 rows plus exact totals.

Offline `recording_ready` means the source end is indexed and initialization is
prepared. `terminal` means all source packets are prepared/admitted. Full replay
callers must keep the session alive, report displayed sequence, and compare the
final displayed cursor with `latest_sequence`; freezing initialization is a
separate explicit use. Closing wakes a held preparer and checks cancellation
between packets; an active atomic decode/reduce/compile can finish first.

Completed immutable presentation groups return to that same preparation worker
for cleanup. The next session poll publishes them after the previous scene call
has returned; the worker drops references outside its mutex. Closing drains this
staged cleanup before joining. Native images, textures and nodes remain owned by
the scene thread. `session_execution` reports retired/pending/peak group counts
and observed worker cleanup time; these are group counts, not a fixed byte cap.

Profiles expose `session_execution`: operation backlog/lookahead, active or
held preparation, cumulative packet preparation/compilation time, and pending
HTTP request count/age. HTTP wall-time totals can overlap and are not frame CPU
time. Media counters separately report metadata and decoded-image/fixture work.
A final native Crypt acceptance held one actual command for 2,000 ms: receipt wait
was 2,122 ms while 307 frames and 192 animation samples advanced, viewport wheel
zoom worked, and frame p95/max were 7.460/10.361 ms. The immediate-close forwarder,
receipt, cold-journal parity and worker shutdown passed 15 checks; native close
took 1 ms. The separate lighting demo was running during this check, so this is
responsiveness evidence rather than an isolated performance comparison. A server
wait alone need not freeze the scene; it does not excuse separately measured
first-use decode/upload or scene-construction stalls. Reproduce with
`tools/play.py --scenario crypt --test-script res://tests/player_wait_checks.gd --test-command-delay-ms 2000`.
The forwarder is test-only; ordinary launch has no artificial delay.

First-use UI images, scene construction and main-thread texture/fixture-array
uploads can still cost frame time. Original assets, tint, alpha, source frames and timings
are unchanged. Authored goblin scale remains appearance1.0,128×128 cell,
pivot(64,87), with the same pixel-to-grid conversion as modular actors.

Run a repeatable native recording profile with:
`--script res://tests/player_profile.gd -- --recording <journal-directory> --profile-label encounter`.
It separates initialization, fixed-step presentation of the complete recording,
settled frames, zoom40 and each wall mode. It requires matching final canonical
state/sequence, a drained timeline and no presentation errors. CPU phases
include session/timeline, world/actor preparation, sampling, lighting, painter
order, wall visibility, HUD, PNG decoding and GPU upload. Frame intervals and
last available renderer timings are recorded with their limitations. Separate
wall-mask viewport CPU/GPU timings and per-wall tile candidate counts are in
frame context. Zero GPU timing can mean unavailable; CPU phases are inclusive.
The full-codebase audits in `generated/audit_*_2026-10-12.md` distinguish current
asset residency/loading problems from unmeasured large-map scaling risks. These
Crypt measurements do not establish a large-map performance limit; original
offline exploration measurements are retained below.

## Preserved offline exploration

Run `run.cmd` for the rebuilt Unity environment in Godot 4.7.2. It opens the
minimal exploration scene (`demo.tscn`). `workshop.cmd` opens the earlier
catalog/editor separately; `edit.cmd` opens the Godot project.

Original NDClient authoring/art and the Unity project are unchanged. Runtime
authoring and media now read the verified Windows copy at
`C:/Users/tommaso/Documents/Dev/NDClientData/{authoring,.media}`, configured in
`project.godot`. All 134,380 relative file paths and byte lengths matched the
original source; `generated/windows_source_copy.json` records the copy check.
Modular character geometry already used its separate native Windows location.
This is a copied snapshot; edits to the original WSL authoring are not
automatically synchronized into these runtime roots.

`generated/windows_source_comparison.json` records the same-build source-path
comparison with complete Crypt and Gallery recordings. Both Gallery runs had
78 traversal frames above 33.333 ms (worst 66.122 ms from WSL, 72.946 ms from Windows).
Media-wait intervals were 19.727 s and 17.594 s respectively; the remaining large
spikes were CPU world/scenery/wall updates. Each run used a fresh native process
and passed full canonical state/sequence/drain checks. OS caches were not flushed,
another user lighting demo remained running, and asynchronous admission gaps
changed the exact display-clock sample trajectory. These measurements establish
that the spikes persist with native paths, not an isolated disk-speed benchmark.

The subsequent CPU repair pass retains changed-world rows, scenery consumers,
native floor buffers and static draw keys. The final full Gallery run
(`generated/order_native_profiles.json`) reached all 102 packets/122 groups and
the exact terminal state on 1,761 tiles/360 objects. Its traversal had 51 frames
above 33.333 ms and a 59.405 ms maximum, compared with 78 and 72.946 ms in the
Windows source-location baseline. The small Crypt run had no frame above
33.333 ms and a 25.209 ms maximum. These are complete diagnostic recordings,
with the same concurrent-demo and asynchronous-sampling limitations above.

Performance remains open: the last static-order refinement had 51 slow frames
versus 48 in the immediately preceding sparse-update pass, although its maximum
was lower. World disclosure, object creation, floor updates and membership-driven
ordering still produce measurable stalls. Gallery retirement spans about 859 ms
of active frame intervals; a camera request can wait for that backlog before
preparing its next view. Large-map request-to-publication delay has not been
separately measured. The evidence index
`generated/review_repairs_validation_2026-10-12.json` records the final profiles,
focused correctness checks and the remaining one-pixel/one-byte native-light
comparison discrepancy without treating its fixed-light control as a repair.

## Exploration controls

- **WASD**: walk the modular character. **Space**: follow/recenter.
- **Middle-drag**: pan. **Wheel**: zoom. **Q/E**: four camera quarters.
- **G**: isometric grid. The cursor reports cell and support height, including
  fractional stair height. The HUD shows FPS, frame milliseconds and draw calls.
- **Click**: preview an authored break animation. **Alt**: highlight breakables.
  **R**: restore intact placements. Native AnimationPlayer/AnimationTree own
  character and destruction presentation clocks.
- **F 8**: start/stop a profile recording. **F 9**: dump the recent 1800 frames.
  JSON files go to `generated/profiles/`; the on-screen notice gives the path.
- **L**: toggle the diagnostic point light. Arrows/PageUp/PageDown move it;
  **B/N** toggle source depth/normals for comparison.

The exploration view has no palette, equipment menus or text fields. Movement
is an offline floor/stair placement preview, with no wall physics or game rules.

## Compiled grid renderer

The map contains 86,247 placement records from the actual SmallscaleExplore
scene plus explicit elevation/closure corrections. Its 87,786 static sprite
components compile into 86 ordered MultiMesh blocks per quarter. Four view
buffers share colour and raw numeric texture arrays. All four views are resident;
pan/zoom changes only the camera, and rotation selects the prepared view.

`grid_order.gd` orders owner cells along the camera's grid diagonal, then their
height and floor/shadow/body layers. Lowest ground keeps the original source
paint-layer order. Cliff rims inherit their registered upper support's display
cell/height while retaining their original physical lighting contact. A lower
foreground actor can therefore cover a distant upper floor; an actor under the
same cell's upper support stays behind it. No runtime static sorting graph or
CPU depth decoding is involved.

`grid.gdshader` reconstructs only light receiving positions/normals from the
original calibration and packed channels. Colour, masks, pivots, scale, affine
shadows and water are retained. Moving actors use binary-search insertion into
the static order; affected blocks become disjoint ranges around the native
animated draws. Breaking an object hides its stable placement slot in all views
and activates its original native destruction bank.

The cache is derived, not an editable replacement asset registry. To rebuild:

1. `python 3 tools/build_unity_map.py` converts the extracted source scene and
   `unity_elevation.json` corrections into passive placement records.
2. Run `compile-grid.cmd` (a native Godot rendering device is required; the
   dummy headless renderer cannot serialize texture-array pixels).
3. Launch `run.cmd`. Recompile after changing map/art/authoring inputs.

The native cache is under `generated/render_cache/` and can be regenerated.
Packing copies registered rectangles without resampling numeric channels. Packed
geometry already includes normals, so it is shared rather than duplicated.
Startup uploads the cache once; first movement's selected Run layers are loaded
with Idle. This trades resident memory for camera responsiveness.

The batching design draws from Haar/Aaltonen's
[GPU-Driven Rendering Pipelines](https://advances.realtimerendering.com/s 2015/aaltonenhaar_siggraph2015_combined_final_footer_220dpi.pdf).
It uses Godot instancing, not their entire compute/indirect renderer. Ordered
source-over blending follows [Porter and Duff](https://keithp.com/~keithp/porterduff/p 253-porter.pdf);
[OpenGL primitive order](https://wikis.khronos.org/opengl/Primitive_Order) preserves
instance order inside each single-surface block.

## Backend boundary

The implemented [Godot player SDK](sdk/README.md) lives under `sdk/`, with native
headless contract checks and real-backend encounter/replay runners. Its state
ownership and validation are independent of the existing exploration preview.

The current boundary is `../dnd_engine/sdk/player-typescript`, `sdk/python` and
`sdk/protocol`; the canonical subjective reducer is `dnd/player/reduction.py`.
The older `sdk/typescript` package is obsolete. Current packets disclose tile
elevations, object base/top heights and connector support heights. Earlier claims
that those fields were missing were based on that obsolete package.

This exploration scene remains offline; `play.cmd` is the connected player
described above. The integration scope is in SCOPE.md. Godot consumes disclosed
state and causal facts; it must not
recalculate collision, spell resolution, visibility or rules-based light levels
from sprite depths or native point lights.

## Exploration validation and limits

- `tests/grid_render_checks.gd`:16 native pixel comparisons against the original
  single-sprite shader, across four views with source depth/normal lighting.
- `tests/grid_alpha_checks.gd`:four native split-range alpha comparisons against
  independently ordered sprites at a remote world position.
- `tests/grid_order_checks.gd`:foreground/under-floor actor cases and all 451
  actual cliff/support relationships in four views (`--headless`).
- `tests/exploration_checks.gd`:native rotation/grid/Alt/click/break/settle/reset,
  no input-stealing menus, and F 9 history after a stopped recording.
- `tests/unity_walk_checks.gd`:all 20 imported flights, ascent/descent and
  fractional cursor height (`--headless`).
- `tests/unity_tour.gd`:five areas × four views; captures in `.captures/`.
- `tests/unity_profile.gd`:fixed 1440×900 idle, first movement, walking, following,
  zoom and rotation profiles. Input is isolated from manual camera changes.

`generated/gpu_performance.json` links the recorded baseline and current runs.
The original per-sprite wide-view baseline used about 9604 draw calls and averaged
377.93 ms while walking. The compiled renderer uses roughly 100 calls and reaches
about 6.95 ms here. Intermediate cached/staged builds had different results and
remaining camera spikes; the original baseline is explicitly identified.
These are RTX 5090 desktop measurements, not a universal hardware or map limit.

The final 7 recordings (19:03 on 11 October 2026) use a 143.933 Hz display with
VSync. Wide walking averages 6.948 ms (p 95 7.009 ms),101 median draw calls and
0.302 ms renderer CPU: 54.4×,95.1× and 59.2× improvements respectively against
the original baseline. First movement peaks at 10.50 ms, zoom at 10.62 ms and
rotation at 17.08 ms; no recorded frame in these post-load runs exceeds 33.3 ms.
Reported video memory peaks near 1.36 GiB and Godot static memory near 868 MiB.
Cold application startup is outside those samples. The baseline had 83,642
placements; the final map has 86,247 after the additional closure corrections.

Unity supplied a flat, single-view painting. Corrected terraces use heights 0/2/4;
roof and rear-cliff returns use the original kits.
River and shoreline foam retain their common zero-height level; land elevation
polygons do not lift strips of the river into terraces. The source map is not a complete
3D building model: 35 source registrations lack distinct four-view coverage,
four wall views have no surviving depth/normal registration, and some complex
buildings still contain single-view composition assumptions. Static source
animations without selected clocks stay at their imported sample. Character
sheets use matching delivered modular receivers where available, with flat
fallback for unsupported pixels and other creature rigs.
The complete environment catalog remains available in the separate workshop.

The sections below describe that preserved workshop, including its older
visibility/composition renderer and historical benchmarks.

## Workshop controls

The workshop map is a connected catalog exhibition with raised platforms,
stairs, source-compatible door assemblies and independently breakable window
inserts. Its layout is a new test map, not a recovered gameplay map.

- Search the palette; **Locate asset** jumps to its example. Source sequence,
  state/outcome and sample controls expose existing variants.
- **Select**, **Place**, **Move**, **Apply changes**, **Delete**, **Undo** edit
  passive placement data. Height and orientation are explicit. Door assembly
  members move together using the source `offset_XHZ` records.
- **Break preview** enables click-to-break. Hold **Alt** to highlight authored
  breakables; **R** or **Reset breaks** restores them. **Play sequence** previews
  the selected authored timeline, including sequences that are not destruction.
- **Save map / Load map** use `user://workshop-map.json`; the status displays
  its Windows path. Destruction playback is temporary and is not saved.
- Middle-drag pans; wheel zooms; **Q/E** select four camera views. **1–3** load
  the contact, terraces and overlapping-floor fixtures; **4** returns to the
  catalog. **1× / 2× / 4× map** builds larger layouts. The lower-left panel shows
  FPS, wall-clock frame time, the worst frame since launch, last view-update cost
  and pending placements. Wheel/pan events are coalesced; new sprites load
  progressively while the game loop continues.
- **WASD** moves the modular character across floors and authored stairs; **H** switches
  between supports at the same XY; **F** changes facing. **Bring character**
  places it near the camera. Movement is a placement probe without collision
  or gameplay navigation. Stair contacts and rise come from `world.json`, with
  interpolated height along the flight; unrelated ledges remain blocked.
  Typing in search/number fields pauses movement. Enter, Escape or clicking
  outside the field finishes editing and restores movement.
- Arrow keys and Page Up/Down move the point light. **L** toggles it, **B**
  toggles sampled lighting depth, and **N** toggles supplied normals.

The character controls use the real `neuroclient.modular` sheets and item
catalog: armor, main/off hand, helmets, actions and three additional effect
slots. All layers share the action clock and facing row. Equipment uses source
tint values: source RGB is multiplied once before lighting for body, hair and
equipment alike, including bright shades. No automatic equipment palette
substitution is inferred from those tint fields. Missing categories for an action
are hidden explicitly.

## Native animation resources

Character graphs are built at runtime by `animation/graphs.gd` from the selected
rig's authored clips. Their AnimationPlayer/AnimationTree uses **Idle** as the
action transition hub; locomotion loops and Die holds its final frame. The
exported `generated/modular_animation.tscn` is an inspection snapshot, not the
runtime's character graph owner; editing that file does not alter gameplay.

Destruction instantiates `generated/destruction_animation.tscn`, with
**Intact → Breaking → Settled**. Each instance receives its source bank duration
and samples original timestamps/FPS. Remains, clear-at-end, device wreck states
and window parent/insert lifecycle follow source records.

Camera rotation changes the source view without resetting either clock.
Animation nodes own presentation timing; world/editor state remain passive
records. The adapter maps sampled values to the existing sprite sheets.

`tools/import_animations.gd` explicitly rebuilds the inspection character scene and the
destruction scene from source clocks, replacing manual graph edits. `python3 tools/build_catalog.py` refreshes
the palette, source sequence index, bounds and coverage reports without copying
or changing artwork.

## Data and coverage

`scenes.json` and saved maps use `id`, `kind`, `position`, `base_height_steps`,
`boundaries`, `support_id`, `upper_support_id` and `layer`, plus references to
existing asset owners. Assembly members retain a root identity; window inserts
also retain a parent identity. Library records select a source sequence/sample.

The palette indexes **1,382 entries**, including all **725 library families**:
**1,346 entries have registered samples**. Thirty-six families have no complete
pivot/scale registration; another 75 have some unregistered samples. They remain
visible with warnings. `generated/catalog_coverage.json` lists unavailable
families; `generated/unregistered_samples.json` identifies all 3,486 incomplete
samples. A first available library sample is not necessarily an intact frame.

The source index exposes 3,277 registered sequences, of which 566 have authored
clocks. No FPS is invented for clockless art; use sample inspection. Separate
source sheets, variants, pitch and aim are retained when changing view. There
are 295 palette entries with explicit destruction/candidate sequences. Source
candidate qualifications remain applicable; previewing them does not certify
gameplay collision. Raw registered image entries are individual views; use
family/owner entries for objects with authored camera variants.

## Composition and lighting

The original 128×64 projection and 64-pixel height step are preserved. Support,
floor layer, source masks and ground/boundary contacts determine transparent
draw order. Native depth/normal packets determine 3D light receiving positions
and orientation; they do not crop wall bases against their floor. Actor sheets
use their exact delivered modular normal/depth companions where available;
unsupported pixels and non-modular rigs retain flat receiving light.

Only visible placements create draw nodes. Projected spatial buckets include
source sprite extents and elevation; unused textures are evicted. Whole-component
sorting is not a complete per-pixel compositor: arbitrary intersecting sprites
may require additional authored splits. Dynamic shadow casting, physics,
backend/event reduction, spell VFX and full client migration remain separate.

## Verification and measured scale

Use the installed console executable with
`--path . --script res://tests/NAME.gd`:

| Check | Mode | Scope |
| --- | --- | --- |
| `placement_checks.gd` | `--headless` | 57 checks: support, wall, underground and upper-floor composition |
| `animation_checks.gd` | `--headless` | Native clocks, loops, queued actions through Idle and settlement |
| `catalog_checks.gd` | `--headless` | 12,107 checks pass; 3,893 colour/companion paths, selected variants and device wrecks |
| `workshop_checks.gd` | Native window | 663 checks pass: viewport click/Alt, independent insert, 8 facings × 4 views, editor gestures and save/load |
| `walking_checks.gd` | `--headless` | 217 checks: source contacts, ascent/descent at three elevations × four orientations, blocked ledges |
| `composition_equivalence.gd` | `--headless` | 48 spatial-order comparisons against exhaustive constraints |
| `input_walking_checks.gd` | Native window | 12 checks: actual catalog stairs, search/number fields, buttons and dropdown selection → WASD |
| `zoom_checks.gd` | Native window | Repeated wheel bursts to size50 and back, below-ground actor, Alt/break preview; writes `generated/zoom_performance.json` |
| `map_benchmark.gd` | Native window | Writes `generated/performance.json` |

Native captures and check logs are in `.captures/`. `-- --capture` reproduces
the three placement fixtures in all camera views; `-- --workshop-check` captures
bank destruction. Tests preserve an existing saved workshop file.

Earlier narrow-view measurements at camera size12, 1440×900, Compatibility
renderer, RTX 5090, original WSL UNC inputs (before the zoom/stair repairs):

| Map | Placements | Build/load | Mean idle frame |
| --- | ---: | ---: | ---: |
| 1× | 87,813 | 1.27 s | 6.95 ms |
| 2× | 175,608 | 1.82 s | 6.95 ms |
| 4× | 351,198 | 3.59 s | 6.95 ms |

On 4×, walking averaged 7.12 ms/frame (p95 8.65 ms); the distant timber preview
averaged 7.41 ms (p95 14.19 ms), with a 0.79 s cold jump to its district. Draws
ranged from 304 to 753. Godot-reported static memory reached 1.34 GiB and video
memory 533 MiB. These are short local samples, not a hardware-independent
map limit or a claim that all catalog art can be rendered simultaneously.

The narrow-view benchmark did not exercise zoom-out. The regression produced a
949.5 ms synchronous refresh at camera size50 while idle FPS still appeared as
144. The repair reuses existing materials during pan/zoom, stages new visible
rows across frames, and bounds composition constraints by projected overlap.
Terrain pairs without constraints are omitted; a stable heap preserves painter
priority. Pending loads are replaced when the view changes. Texture eviction is
also spread across frames.

Activation targets 4 ms of work per frame before composition, but an individual
source PNG decode/upload can exceed that target. It is not a hard frame-time
guarantee. Source loading and sorting still cost time in wide views. The new
zoom recording includes the loading interval, not just idle FPS.

## Live renderer update reuse

The live player retains unchanged environment nodes, materials and floor
batches across displayed-state updates. It replaces changed visual owners and
affected ground-material batches. Ground sorting projects each cell once and
preserves its original order. Authored floor skirts overlap, so ground remains
in material-wide batches; the rejected 8 × 8 split changed exposed edge pixels.
Each authored quarter is built on first use;
repeat turns reuse its nodes, materials and floor instances. At most three
inactive views are retained, all hidden and excluded from picking and fixture
sampling. A change to canonical world rows releases inactive views; unrelated
displayed revisions retain them. Wall visibility and ownership are refreshed
on activation, including restoration of Hidden corner sources.
Static painter order is cached; actor layers merge into it using the same grid,
height, component and identity ordering. Hidden corner substitutions invalidate
the appropriate ordering and wall-mask data. Light-material registration uses
direct instance lookup with weak ownership.

Wall reveal candidates intersect native boundary quads with disclosed support
polygons, separately from current audience visibility. Changed spatial buckets
invalidate these cached candidates; each visibility update filters against
current visible cells. Elevation changes, removed tiles and revisited quarters
invalidate the relevant geometry. No CPU artwork/depth scan or per-fragment
floor lookup participates. Ordinary clicks pass through revealed foreground
members; Ctrl can target their original native identities.

The sprite renderer uses nearest source sampling without 3D MSAA. Native
fractional-zoom captures with the former 4× setting changed a handful of wall
edge pixels between otherwise unchanged frames, including with ownership masking
off. Without MSAA those repeated/opaque comparisons are byte-exact. The original
diagnostic remains in `generated/wall_compositing_msaa_diagnostic.json`; reproduce
it with `tests/wall_compositing_checks.gd -- --msaa-4x`. Source alpha still supplies
the artwork's own transparent edges; no blur or colour/depth sampling change was
added to hide the difference.

The original registered door leaf now splits around its own frame on the GPU
using authored painter depth, without a hinge/pivot adjustment. Banks lacking
that registration and destruction sequences retain their original single leaf
draw. Source-byte shadow selections account for Compatibility colour sampling.

Native checks: [world reuse and ordering](generated/world_incremental_checks.json)
89 checks; [four-view reuse](generated/world_view_cache_checks.json) 87 checks;
[door overlap](generated/door_overlap_checks.json) 79 checks;
[environment/grid source selection](generated/environment_selection_checks.json)
16 checks, all passing. World comparisons use a one-byte pixel tolerance;
the door oracle and all 15 cached-view comparisons are byte-exact. These checks establish renderer equivalence,
not a hardware-independent speedup or a large-map capacity limit.

The large-scale profile uses `tests/scale_profile.gd` with the same `--recording`
and `--profile-label` arguments. It follows a recorded backend traversal into
the 48 × 36-cell Gallery, then samples all four camera quarters at sizes 20 and
70 and the Solid/Hidden modes. The retained route contains 58 committed SDK
commands and 102 packets; its last displayed state contains 1,761 disclosed
tiles and 360 objects. Initializing this complete offline journal is distinct
from joining a fresh live game. Media-wait frames, advancing playback, cold and
cached rotations are reported separately in the comparison JSON.

`tools/gallery_recording.py` drives the real SDK through choices, previews and
numbered commands. `tools/gallery_timing.py` optionally records backend action
phases through the existing acceptance host. Those inclusive dispatch timings
exclude network/queue waits and client rendering. The movement-origin fix
preserves atomic perception publication and avoids a repeated full refresh
only when the existing observer field is demonstrably current. Moving-light
publication still causes multi-second backend commands in the large room.

## Godot ownership review — 12 October 2026

Three coordinated reviews distinguish required authored-data adapters from
avoidable engine duplication:

- [Shader inventory and native pipeline guidance](generated/SHADER_PIPELINE_REVIEW_2026-10-12.md)
- [Rendering correctness and efficiency](generated/RENDER_CORRECTNESS_EFFICIENCY_REVIEW_2026-10-12.md)
- [Architecture, SDK, UI and resource ownership](generated/ANTISLOP_GODOT_REVIEW_2026-10-12.md)

These are historical findings from the inspected source, not a list of current
defects. The follow-up now uses native item point lights and ambient, distinguishes
remembered scenery, corrects below-zero floor ordering, and gives water native
receiving light and a displayed clock. Replay preparation is cancellable and
bounded separately from durable network admission. The
[repair ledger](generated/REVIEW_REPAIR_LEDGER_2026-10-12.md) records the individual
acceptance gates and remaining performance work. Neither these reviews nor their
check counts constitute blanket correctness or visual-quality certification.

The pre-repair source/lighting/residency checkpoint and its small/large profiles
are preserved in [current_render_validation.json](generated/current_render_validation.json).
Those two traversals finish at the canonical consumed state without presentation
errors. On RTX 5090, Compatibility, 1440×900 and VSync off, that checkpoint's small
wide-view p95 is 1.86 ms and its four steady wide Gallery views are 3.16–3.60 ms.
Its first Gallery quarter construction reaches 128 ms and repeat activation
48–57 ms. These are historical baseline measurements, not timings of subsequent
staged quarter preparation. Raw frames, inclusive CPU phases, delayed GPU
samples, media holds and memory accounting remain available in those reports.


## Displayed scenery, lower floors and water

Current scenery and remembered scenery use the displayed subjective snapshot.
Tiles require a current visible-cell grant; ordinary objects require their own
visual contact. Native structural boundaries also inherit observation from either
incident support, while attached inserts require their own grant. Unknown cells
and objects are never created by the styling layer. Remembered source colour uses
0.62 brightness and 0.35 saturation; original alpha, hit masks and canonical
last-observed after-values remain unchanged. Mixed current/remembered corners use
the existing original straight members; equal-style corners retain joined art.
This is separate from atmospheric fog, actor visibility and fixture activation.

Ground batches carry visibility in per-instance custom data with explicit white
instance colour. Native checks compare their pixels with original individually
drawn terrain in all four views, including mixed visibility and original skirt
order. If any disclosed support or object is below zero, base-zero floors leave
the global background batch and join ordinary grid painter order. Their original
opaque pixels also block picking through to lower actors; authored fractional
edge alpha retains source-over compositing. Removing the lower state restores
batch eligibility. This uses the grid and disclosed elevation, not physics or
CPU depth-map sorting.

Live water retains the original mask, ripple and colour graph, receives native
Godot lighting on its disclosed horizontal support plane, and advances only with
the presentation timeline. Pause, preparation holds and replayed timestamps
therefore preserve its pixels. The standalone sprite workshop uses an explicit
local clock, paused during capture. The older compiled `grid.gdshader` exploration
reference remains an offline source-art comparison path with its old emissive
water/TIME behavior; it is not the live player or the native-light demo.

Focused evidence: `generated/scenery_state_checks.json` (33 logical checks),
`generated/scenery_render_checks.json` (36 native checks),
`generated/ground_visibility_checks.json` (24 native original-pixel comparisons),
and `generated/water_render_checks.json` (11 native lighting/clock checks).
These use a real admitted outfit plus named renderer fixtures; they do not claim
that a backend negative-height or water command was issued.

## Native item-light migration

Every currently disclosed, active item emitter now owns an `OmniLight3D`.
Godot accumulates direct light through the source material's `ALBEDO`, decoded
`NORMAL`, and reconstructed `LIGHT_VERTEX`; the former custom torch texture/loop
has been removed. Carried sources follow displayed movement and jump height;
authored fixture flames supply their registered optical height and flicker.
Unobserved remembered emitters do not remain active. Directional lights and the
native white ambient resource remain independent contributions.

Native spherical attenuation is an optical convention, not an implementation of
the backend's horizontal light bands. The configured Compatibility limits are
64 lights per draw and 256 renderable lights. The native shared-floor test uses
24 actually overlapping sources, demonstrating contributions beyond the default
eight; this is not an unlimited-light or arbitrary-hardware claim. No physical
sprite-wall shadows were added.

Painted quads retain their original pivots, tint and alpha. Their native culling
bounds include the affine source receiver extrema, without reading every depth
pixel on the CPU. `generated/receiver_bounds_checks.json` verifies four camera
quarters using an explicitly synthetic admitted depth extremum: original bounds
reject the tiny light and expanded bounds receive it. Both the light and the
receiver are within the test camera frustum; changing `LIGHT_VERTEX` does not
override native light-camera culling. This fixture does not claim a naturally
occurring defect in the selected Head15 sheet.

Artistic evaluation of character lighting and the standalone single-light demo
are now a separate user-directed track. Native wiring checks do not certify the
estimated source geometry or establish that the character appearance is approved.


## Prepared camera quarters

Q/E requests a target quarter while the current camera, artwork, picking and
character clocks remain active. A passive native renderer prepares exact source
sprites, floor instances, wall qualification, memory styling, painter order and
coverage masks over bounded slices. It shares the original sprite/material
helpers with the workshop; it owns no session or gameplay controller. Repeated
Q/E composes from the requested quarter. Changed source rows cancel obsolete
work; changed visibility or wall mode refreshes target styling, and pan/zoom or
resize refreshes the target mask projection before publication.

Publication changes the camera and complete prepared view together. At most
three inactive quarters are retained for the current source generation; a pure
cached rotation does not enumerate `WorldRows` again. Inactive views have hidden
parents and disabled mask viewports, and do not participate in picking or active
fixture sampling. `rotation_prepare` and `rotation_publish` profile phases include
both preparation and final activation; the cooperative slice target is not a
promise about total frame time or every possible source packet.

`generated/world_view_cache_checks.json` and
`generated/world_incremental_checks.json` compare original source pixels and
painter order against independent reconstruction. The focused native
`generated/rotation_preparation_checks.json` covers current-view continuity,
native pose progress, rapid cached-target cancellation, source-generation
invalidation, pending visibility/mode/projection changes, and retirement of
three cached views. Its small Crypt fixture does not replace the complete
Gallery profile, and timings gathered with another user-owned Godot demo running
must not be described as isolated GPU measurements.

The HUD also retains the original projected grid edges when a world revision
changes sight or objects without changing tile geometry. Native grid comparison
`generated/hud_grid_checks.json` covers all four views, empty views, inserted and
removed tiles, changed elevation, row ordering, fractional zoom and resize with
exact original pixels. Inventory descriptor lookup skips constructing qualified
identities for ordinary short content IDs; every admitted short, qualified and
exact reference is checked in the recorded UI fixture. Original asynchronous
icon resources and their image bytes remain unchanged.

Static source entries retain their complete painter order independently of
visibility. Wall fading selects the visible subsequence instead of re-sorting
the map; hidden member picking uses the same complete order. Source replacement,
camera quarter, floor representative and background eligibility invalidate the
ordering keys. A retained native transform also invalidates its physical depth
compensation. The independent full-sort/native pixel comparisons remain the
acceptance oracle for this reuse.

### Changed-world drawing reuse

Disclosed floor additions and removals retain the native per-material floor draw,
mesh and material. Cached source transforms and receiving bounds are assembled
in the original projected-Y order, including its input ties, and uploaded using
Godot's [native MultiMesh buffer](https://docs.godotengine.org/en/4.7/classes/class_renderingserver.html#class-renderingserver-method-multimesh-set-buffer).
White instance colours, current/remembered custom data, active instance count and
active receiving bounds remain explicit. Reserved capacity is not rendered;
this does not split transparent floor skirts into spatial chunks.

The Timeline accumulates changed tile/object identities across every applied
commit until the media-ready renderer consumes them. Staged support additions
and removals join that same update; initialization and an untracked explicit
renderer revision use a complete refresh. The retained source adapter projects
only affected records, preserves canonical insertion order after remove/re-add,
and updates the affected wall assemblies and fixture sight grants. It does not
scan every immutable SDK record on each sensory commit.

Scenery retains its object consumers and resolves changed floor identities
through the current batch's direct instance index. Rebuilt packets receive their
current or remembered style even when the tile was already visible. The complete
world, styling, member selection, painter order and picking still publish in the
same displayed frame. Floor instance changes do not invalidate the static draw
order when the retained draw and its representative ordering key are unchanged.
Named renderer fixtures follow replacement/revision semantics; gameplay tests
exercise the real `Compiler` and `Timeline` producer.

`generated/world_sparse_checks.json` compares the dirty-key adapter and sight
grants against the exhaustive original adapter across all 102 Gallery packets
and 122 admitted staged lineages. `generated/timeline_world_changes_checks.json`
checks actual compiled staging/commit boundaries, accumulated commits, media
holds, remove/re-add ordering, reset and ordinary same-visible-ID material
transfers. Its projected-record counts describe CPU work, not frame-time speedup.
The earlier `generated/world_delta_checks.json` remains evidence for the previous
full-scan cache. `generated/ground_update_checks.json` compares original single
sprites against retained batches for additions, representative removal,
elevation and input reordering in four quarters. Native scenery checks also
retain below-floor pixels and picking. Whole-frame performance remains a separate
recorded-profile measurement.

## Received-event preparation

The player reads up to two received presentation groups for deterministic
lookahead. Their first future world boundary can prepare while the current
animation advances. `Timeline.preview_world()` creates a passive snapshot;
ordinary actor/log commits do not invalidate unchanged world work. Due admission
still applies fresh ordered commits to the real Timeline, so preparation cannot
publish future logs, actors, visibility or interaction targets.

WorkerThreadPool tasks project authored world rows, floor buffers, physical wall
targets and the unchanged total painter order using private mutable data. Once the target group's exact textures are resident,
the scene thread builds changed native groups under a hidden parent in cooperative
2 ms slices. Publication adopts those groups and buffers at the matching event
boundary. Camera or initialization changes invalidate obsolete work. If preparation
is late, displayed time holds at that boundary; network intake continues and the
loading interval is not replayed as an animation jump.

This moves data projection and changed-object creation ahead of publication.
Scene-tree/resource mutation remains on the scene thread. Current wall-mode
selection, actor/static-order merging, masks and current/remembered styling still
publish there; neither
the slice target nor asynchronous preparation guarantees a maximum frame time.
The cache and profiles report preparation separately from initial asset loading.
Local unconfirmed command prediction was later removed; this
path uses only already received server outcomes.

Preparation-pass acceptance and raw timings are indexed in
[async_preparation_validation.json](generated/async_preparation_validation.json)
and [async_preparation_profiles.json](generated/async_preparation_profiles.json).
The final Gallery recording reaches 1,761 tiles/360 objects across all 122 groups
with canonical agreement and no presentation errors. It retains 20 intervals over
33.333 ms (previously 51), a 45.139 ms maximum (previously 59.405), and 3.816 ms
post-startup p95. Initial preload completes in about 14–15 seconds with VSync off.
These are measured runs, not an all-stalls-fixed claim. New-family selection,
scene/style/mask/HUD publication and view retirement remain material. Six strict
native-direct captures still differ by one byte at one pixel; their fixed-direct
controls and order/picking/state/lifecycle checks pass. See the linked index for
exact lanes, receipts and limitations.

## Authoritative action playback

Local prediction and reconciliation were removed at the user's request after
accepted actions visibly restarted. Commands now play only from the authoritative
event timeline. Asynchronous media/world preparation, native animation, causal
ordering and command receipt handling remain. The older `prediction_*.json`
reports are historical measurements, not validation of the current runtime.

The live Gallery regression uses `tools/play.py --test-script
res://tests/live_gallery_checks.gd`. It issues actual discoveries, previews and
commands through the production player, records post-draw native source frames,
and separates request/preparation waits from frame times. Its private command
trace and canonical journal live alongside the launcher's run output.

Use **Grid · G** beside **Log / Events**, or press **G**, to toggle the grid.

The visual regression comparison also uses the user's newer recorded prefix9:
both carried torches are extinguished, two wall torches remain active, and
foreground walls are Hidden. All four views preserve that source state. This
distinguishes the screenshot context from the older71-packet recording, whose
terminal state has both carried torches lit. See
`generated/native_surface_receiving_checks-carried-off.json` and
`generated/graphics_quality_repair.json` for the native evidence and limits.

The final Forward+ live route issues 58 real commands, reaches 1,761 tiles and
360 objects, and drains all 122 groups with canonical agreement: 367 checks pass.
Scene readiness takes 5.345 seconds in this run. Main-thread action-response
work falls from 47.53 ms to 0.087 ms at its measured maximum. Retained frame
p95 is 6.878 ms and p99 is 11.247 ms; the worst command frame is still 96.888 ms,
including 64.08 ms of lighting-atlas publication. Sparse cells preserve existing
atlas addresses, but remaining full receiver/support traversal still causes
spikes. This is not an all-stutters-fixed claim. The measured route completed
before reopening the user preview. Full comparison and sampling limits are in
`generated/live_gallery_repair_profiles.json`.

The launcher selects its default port through native Windows socket allocation
and verifies the same port in WSL. A WSL-only ephemeral choice previously selected
53359, inside a Windows excluded TCP range, and the native player timed out.
The delayed test proxy uses the same admission path; an explicit `--port` remains
the caller's choice. Selection releases its temporary sockets and does not alter
Windows reservations or existing listeners.

Repository migration, 12 October 2026: the active Windows client is
`C:/Users/tommaso/Documents/Dev/NDClientGodot`, with the historical NDClient Git
repository and remote preserved. Its `authoring/` is now the tracked runtime copy.
Artwork remains external at `NDClientData/.media` and the original geometry and
normal-profile delivery folders. Media, imports, private runtime recordings,
captures and raw frame profiles are ignored. Fresh full WSL and Windows-source
ZIP backups were CRC-verified before importing Git; see local
`.runtime/repository-migration-archives.json` for exact locations.

## Native 2D migration validation

[Validation index](generated/native_2d_validation.json) and
[profile comparison](generated/native_2d_profiles.json) record the earlier
Compatibility migration baseline. Native checks cover actual Crypt actors, all four camera quarters, the three
normal profiles, wall modes, source alpha/picking, settings and generated-shadow
lifetime. Separate original-source comparisons retain their measured one-byte
lit-corner sampling differences. The former per-channel illumination cap was
removed after final-frame comparison exposed a colour regression; its historical
checks do not validate the current renderer. The shadow probe covers dominant selection and five-source fill.

The final full Gallery replay completes all 122 groups at sequence 101 with
canonical agreement, 1,761 tiles, 360 objects, a drained queue and no presentation
errors. Final-view culling rectangles overlap at most seven of its 26 sources;
this is a measured view, not an arbitrary-map light-count guarantee.

On the Windows RTX5090 at 1440×900 with VSync off, steady Gallery p95 is
8.58–11.80 ms (first 2D implementation: 20.42–26.33 ms). Whole traversal p95 is
10.914 ms; after preload it is 12.676 ms. The worst traversal interval is
122.047 ms, with 118 intervals above 33.333 ms. Startup preload takes 21.0 seconds.
This remains slower than the prior 3D receiving path, whose post-preload p95 was
4.475 ms. Atlas reconciliation, world/media/style publication and cold camera
preparation remain open costs; the migration does not claim to eliminate stutters.
The separate lighting demo remained running during these comparisons.

Run the native lanes with the Windows Godot executable and this project path:
`--script res://tests/native_2d_integration_checks.gd -- --recording <Crypt journal>`,
`--script res://tests/native_2d_source_checks.gd`, and
`--script res://tests/native_light_output_checks.gd`.
The full map lane is `--script res://tests/scale_profile.gd -- --recording
<Gallery journal> --profile-label <label> --background-check
--exercise-cache-invalidation`. Private recordings, captures and raw profiles
remain ignored. Original input paths and the external shadow/capacity probes are
listed in the validation index.

## Creature lighting delivery

The completed creature delivery supplies 1,438 native action sheets for 81
appearances. Of these, 420 sources/429 aliases belong to the 42 existing gameplay
rigs. The remaining library actions are indexed without adding gameplay clips,
timing or assignments. `tools/register_creature_geometry.py` checks the delivered
catalogs against this repository's tracked authoring and writes
`generated/creature_geometry.json`; artwork stays external and unchanged.

Creatures use the same native 2D receiving light and
Escape → Settings → normal smoothness selection as modular characters. Each
packet retains its own depth range, optical origin, native cell size and support
masks. Generated shadows use the original painted ground contact and cached
64/84/96/128-pixel caster meshes. Unsupported source pixels stay visible under
flat receiving light and do not acquire invented casting geometry.

Animals draw the delivery's exact original visible-body RGBA partition instead
of the combined body/shadow image. Rendering, source-alpha picking and media
readiness all consume that same image. Covered creature rigs omit the separate
baked Shadow layer, preventing doubled shadows. This preserves each authored
partition rule, including its exceptional actions; it does not recover hidden
body pixels or rescale the smaller animals.

Coverage remains qualified: Stag Die repeats one view in all facing rows and
has only 30.755% geometry support. The six current SkeletonArcher05 clips are
outside these two completed packages and retain their prior rendering path.
The larger 259-appearance/4,381-sheet factory census is not evidence that those
additional geometry packets have finished delivery.

Validation commands with the Windows Godot executable and this project path:
`--headless --script res://tests/creature_geometry_checks.gd`,
`--script res://tests/creature_source_checks.gd`,
`--script res://tests/creature_shadow_checks.gd`, and
`--script res://tests/creature_scene_checks.gd -- --recording <Crypt journal>`.
The Python intake lane is `python -m pytest tests/test_creature_geometry_intake.py`.
Native reports are under `generated/creature_*checks.json`; the source comparisons
use independent decoded normals and real Godot lights, while the scene replay
checks first disclosures, preloaded companions and canonical terminal equality.

This intake passes 6,180 source-selection checks, 213 native source comparisons,
118 native shadow checks, 10 Python intake cases and the 52-check actual Crypt
replay (75 causal groups, two revealed goblin families). Existing modular/profile
and presentation checks also pass. `generated/creature_validation.json` collects
the evidence; this is finite validation, not certification of every source frame.

The repeated Gallery route drains all 122 groups canonically at sequence 101,
with 1,761 tiles/360 objects. `generated/creature_profiles.json` retains the prior
and current measurements. Current steady p95 is 14.11–17.64 ms; post-preload
traversal p95 is 27.322 ms and maximum 240.641 ms, with 258 intervals over
33.333 ms. Preload takes 29.3 seconds. These numbers are slower than the preceding
run; asset production was active and unchanged CPU phases also slowed, so the
difference is not isolated creature-feature cost. The final wide view has one
additional caster (19 components/622,592 prepass triangles versus 18/589,824).
Publication spikes remain unresolved; neither this intake nor its passing tests
claim to complete renderer optimization.

The small environment receiving-normal cache can be regenerated from the original
retained Cycles sample passes with the current project-owned authoring:

```sh
python tools/prepare_receiving_normals.py --banks prop.interior-writing-desk.intact prop.bed.intact prop.interior-bookshelf.intact prop.interior-ingredient-shelves.intact prop.interior-preparation-counter.intact prop.interior-storage-shelving.intact prop.table.intact
```

The manifest records each original pass and registration. These are receiving-only
pixel-integrated normals; original color, alpha, depth and support are unchanged.
The generated PNGs are disposable, ignored cache files. Connected floor interior
sides instead use published adjacent tile support; exposed skirts remain authored.
