# Godot environment placement scope

User direction, 11 October 2026: set up current stable Godot; use the existing
2D environment and character sprites in 3D with four fixed orthographic views.
Use supplied depth and normals with native Godot 3D lighting. Reuse surviving
authoring instead of entering asset metadata by hand.

The user's subsequent correction establishes the composition approach:
preserve multilayer 2D logic within Godot 3D. Focus on environment placement,
joins and multiple elevations while the user is AFK. Do not block composition
on physical reconstruction of a sprite's plinth. Source depth informs lighting;
support/contact/component data determines sprite order.

Implementation sequence:

1. Install official Windows Godot 4.7.2. Read the existing catalog, world,
   static registrations, prop banks, rigs, resources and sheet components.
2. Store passive placement records for owner cell, support/base height,
   boundary directions, support identity and covering layer. Keep authoring
   owners as the source of asset metadata.
3. Compose transparent sprite components through support/layer relationships
   and projected ground/boundary contacts. Apply elevation once. Feed supplied
   geometry and normals into native lighting without using them to crop a wall
   against its own floor.
4. Exercise continuous/corner walls, supported terraces at heights 0/2/4,
   layered floor coverings and props, and actors below/above/in front of an
   upper floor. Inspect all four views and wall crossings.
5. Leave runnable controls, behavior checks, reproducible native captures and
   documentation of actual limits.

These steps are implemented. README.md describes the controls, data and verified
behavior. The layouts are explicit preview fixtures rather than recovered maps.
The source authoring and artwork are unchanged.

Anti-slop and anti-OOP review: the same-task scope_review subagent tracks the
sequence and reviews passive records/functions, source conventions and limits.
Scene nodes serve as rendering handles; no gameplay class hierarchy or separate
asset registry is introduced.

Scope excludes VFX, rules, server integration, Studio, full-client migration,
new artwork, source-depth repair, physics/collision authoring, custom light
loops and restoration of the former full per-pixel compositor. Character
sources currently use planar receivers; the later whole-outfit geometry delivery
is recorded below as pending adoption. Whole-component
sorting does not solve every possible intersecting sprite arrangement.


## Environment editor and native animation extension

User direction: use native AnimationPlayer/AnimationTree for world destruction;
click authored breakable assets to preview destruction, hold Alt to highlight
breakables, exercise the complete environment catalog in a useful large map,
and measure scaling. The user clarified that library membership is not grounds
for excluding an asset and permits native Godot conversion. Further steering:
make this a map editor with destruction preview, and use the real modular
character sheets/equipment instead of the demo goblin. These requests accumulate.

Sequence:
1. Reuse catalog/index, bank/library clocks, state/destruction selectors, physical
   mounts, masks and modular rig/item owners. Inventory missing values explicitly.
2. Introduce the modular character with synchronized authored layers and controls
   for appearance/action/facing. Retain multi-height placement and native light.
3. Build native Intact/Breaking/Settled animation graphs using original clocks,
   with per-instance playback and original final/clear-at-end behavior.
4. Add a catalog-driven map and editor: searchable palette, placement, rotation,
   elevation, selection/removal, save/load, destruction preview and reset. Source
   assets remain unchanged. Missing registration is visible, never silently guessed.
5. Validate clickable break/highlight behavior, frame and end states, camera
   rotation during playback, modular layering, map save/load and larger map sizes.
   Measure real native frame/load/memory behavior and report the tested bounds.

Requested behavior is observed through the running Godot editor/preview. Inputs
are actual source records and editor gestures; expected outputs are matching
placements, modular layers, authored destruction frames/remains and saved maps.
The same-task scope reviewer provides plan adherence, anti-slop and anti-OOP
review. Passive records/functions own state; Godot nodes are rendering, UI and
animation handles. This is local asset/editor preview; backend rules and network
integration remain outside this extension.

The extension is implemented as a local workshop. Native modular and destruction
scenes are loaded by the runtime. The full catalog remains discoverable, including
exact warnings for missing source sample registration. Source-compatible door
members, frame/leaf separation, window insert selection and after-insert parent
destruction are consumed. Editor gestures and saved-map roundtrips are exercised.
README.md and generated/performance.json record the actual checks and measured
map sizes; source art/authoring remain unchanged. Clockless or unregistered samples
are not silently assigned timing or geometry.

## Zoom-out stall and performance display

User report: zooming out froze the preview; FPS must be clearly visible. Keep
this repair limited to camera/visibility/composition work and performance UI.
Measure zoom from size12 to50 and back through native input, including raised
and below-ground placements. Preserve source registrations and draw ordering.
Coalesce repeated wheel/pan work, avoid rebuilding unchanged visible materials,
and remove global pairwise composition work where spatial overlap bounds it.
Display prominent FPS, wall-clock frame time and loading/update spikes. Verify
zoom responsiveness, composition fixtures and normal editor/animation behavior.
The same-task reviewer tracks plan adherence, anti-slop and anti-OOP scope.

User added stair traversal and movement lost after menu interaction. Reuse the
existing world stair support offsets/contact pixels for placement and walking;
verify ascent/descent in all orientations and at multiple elevations without
allowing arbitrary cliff climbing. Keep keyboard movement available after menu
selection; text editing suspends movement only until Enter, Escape or a click
outside the text field. Exercise these through native input and visible actor
position/height. This is preview locomotion, not backend navigation or physics.

Completed: authored stair support interpolation and native ascent/descent; text
focus release and menu-to-WASD checks; prominent performance HUD; coalesced
wheel/pan, staged visibility activation and spatial composition. Existing663
workshop checks pass. New walking217, composition equivalence48 and native
input12 checks pass. Same-task anti-slop/anti-OOP review found no blocking
regression. Single-image loading remains synchronous within each staged row;
README and the zoom recording state the measured cost rather than promising a
hard frame budget. Original artwork/authoring remain unchanged.

## Unity demo composition and elevation pass

User direction: rebuild the environment of SmallscaleExplore's Fantasy kingdom
Example scene in Godot, correcting inconsistent elevations in the original
single-view flat composition. Start the existing workshop for the user while
this work proceeds (running). The scene, tile assets and surviving authoring
are the placement/art references, rather than a newly invented showcase.

1. Extract actual scene tile layers, placements, sprite references and hierarchy;
   compare a visual reconstruction to the original composition.
2. Resolve sprites to surviving authored owners and four-view families. Preserve
   source position/layer provenance in the imported map, with explicit targeted
   corrections for height/support closure; retain originals unchanged.
3. Build a coherent walkable environment: terrain, paths, stairs, terraces,
   walls/buildings, vegetation and prop composition. Keep the modular character,
   native animation/destruction and performance display from the current build.
4. Walk through the composition, rotate all four views, inspect elevation joins
   visually and repair actual gaps/occlusion. Use narrow checks as supporting
   evidence; visual plausibility and exploration are the acceptance boundary.
5. Leave the rebuilt map selectable and runnable with a short explanation of
   corrections and any genuine missing source views/data.

The same-task plan-adherence, anti-slop and anti-OOP reviewer follows this pass.
Scope is environmental composition and preview traversal/destruction. Unity's
combat, progression, AI, UI and backend systems are not part of this map rebuild.

Performance steering: the Unity map rebuild must also address wide-view frame
cost from first principles. Add usable profiling controls and JSON frame dumps
with measured CPU phases, renderer/GPU timings where supported, draw/node/memory
counters and view context. Measure stationary, moving and changing wide views;
use the profile to choose static-terrain batching and unchanged-scene reuse.
Preserve multilayer/support composition, native light and source artwork while
reducing per-placement rendering work. Do not equate staged loading with solved
steady-state FPS. Keep this integrated with the Unity composition pass.

New-map interface steering: use an exploration view without the editor/palette,
equipment menus or catalog controls. Keep map navigation, modular-character
movement, optional isometric grid, hovered cell coordinates/elevation, compact
FPS diagnostics and profiling shortcuts. Preserve the existing workshop as a
separate development scene; the Unity rebuild opens in the minimal view.

## GPU grid renderer replacement

Latest user correction: target an architectural50–100x improvement rather than
continuing to optimize a per-sprite CPU compositor. Treat the scene as a layered
grid. DnD engine owns gameplay, movement legality and structural state; Godot
presents authoritative data and uses source depth/normals for GPU lighting.
No wall physics, local rules engine or physical surface reconstruction.

The attempted cached graph/staged loader is superseded for exploration. Keep
the workshop available while replacing the exploration rendering path:

1. Read the actual backend snapshot/observation reducer and spatial after-values;
   establish which fields exist rather than inventing a network contract.
2. Compile existing authoring and Unity placements into native texture arrays,
   GPU calibration tables and four ordered grid/layer instance lists. Preserve
   source colour, masks, depth/normal sampling and explicit height corrections.
3. Render ordered blocks through shared instanced shaders. Static nodes and draw
   submissions scale with blocks, not sprites. Pan/zoom changes the camera;
   quarter rotation selects already prepared view data. No runtime static graph.
4. Insert moving actors and native destruction playback between static ranges
   only in affected blocks. Preserve ordinary ordered alpha compositing; do not
   replace original shadows/soft edges with guessed opaque geometry or OIT.
5. Verify original/rotated composition, grid hover, native animation and light;
   profile complete idle/walk/follow/zoom/rotation paths and report draw-count,
   CPU and frame-time changes against the same map and resolution.

Anti-slop/anti-OOP review remains with the same-task scope reviewer. Compiler
outputs are derived caches, not new authoring owners. Original files stay intact.
Native nodes are presentation handles; state remains passive records/functions.

Research: Haar/Aaltonen, GPU-Driven Rendering Pipelines (SIGGRAPH2015), motivates
shared material/instance data and coarse submission. Porter/Duff, Compositing
Digital Images (SIGGRAPH1984), supplies the ordered alpha requirement. Godot's
MultiMesh and spatial-shader reference define the available instance buffers,
custom data and native LIGHT_VERTEX/NORMAL receiving hooks. These support the
design; they do not imply that every paper technique must be implemented.

Implemented and verified: the minimal demo now uses the compiled grid renderer;
the older workshop remains separately runnable. Static87,786 components use86
blocks per quarter, shared native colour/numeric arrays and GPU lighting. Camera
navigation has no static rebuild queue. Native modular/destruction draws insert
between disjoint static ranges, with stable placement hide state across views.
The source authoring, artwork and Unity project remain unchanged.

Validation:16 original-shader/native-light pixel comparisons; four remote-position
alpha-range comparisons; all451 cliff/support relations in four views; all20
stairs ascending/descending with cursor height; native grid/quarter/Alt/click/
break/settle/reset and profile-history controls. Five areas have four-view
captures. The same-task reviewer found no material runtime or ownership blocker.

The final fixed1440x900,zoom50 run averages6.948ms walking and101 draw calls.
Against the explicitly recorded original per-sprite baseline, frame time improves
54.4x, draw submissions95.1x and renderer CPU59.2x. First movement/zoom/rotation
are included separately; initial application load is not. Raw JSON and comparison
context are retained in generated/gpu_performance.json. These are local desktop
measurements, not a universal scale claim or an assertion that intermediate
cached/staged variants had the original baseline performance.

Correction after the current protocol audit: that check used the obsolete
sdk/typescript package. The current boundary is sdk/player-typescript,
sdk/python, sdk/protocol and dnd/player/reduction.py. Current subjective world
packets include tile elevations, object base/top heights and connector support
heights. The exploration renderer remains an offline preview.

## Godot player SDK and subjective reduction

User direction: complete a tested Godot-local SDK this turn, including real
headless gameplay, event reduction, recording/replay and reconnect. Study Godot
designs first. The old NeuroClient event inspector and combat log are references
for later subjective UI; UI implementation is not part of this pass. Future
large causal maps, directional lighting and native factory VFX remain separate.

Behavior: a Godot consumer follows one authenticated subjective audience,
records admitted bytes, reduces exactly the state disclosed by the backend,
acknowledges successful consumption, discovers/previews/submits commands, and
can replay its journal without networking. The backend retains rules authority.
Boundary: public Godot SDK methods, admitted packets, reduced values and actual
HTTP responses. Inputs: the unchanged protocol1/schema5 schema and identity,
real backend streams/commands, and explicit malformed transport cases. Outputs:
Python-equivalent state at each prefix, ordered causal data/combat logs, exact
command receipts, repeatable replay, and explicit failures without partial state.

Implementation sequence:
1. Finish official Godot HTTP/thread/data/UI research and inspect current Python
   and TypeScript player SDKs, canonical reducer and old UI interactions.
2. Ship the exact existing schema/identity with strict UTF-8/JSON admission and
   validation of its vocabulary. Keep raw bytes immutable; apply model defaults
   only to reducer input copies. Avoid the unsigned optional native addon.
3. Implement HTTP endpoints, SSE framing and a session-owned worker lifecycle.
   Consume before ACK, distinguish transport/source cursors, reconnect without
   re-reduction, reject scope/identity changes and never auto-retry commands.
4. Port the canonical reducer/audience functions and staging/causal helpers as
   pure data operations. Retain all state, HUD, content and structured logs.
   Implement durable ordered journaling and cold replay through that reducer.
5. Validate schema admission, transport faults, Python differential cases and
   real headless Godot clients completing a native backend encounter. Exercise
   reconnect, duplicate command receipts and replay every recorded prefix.
6. Review the complete changes and document actual commands, coverage and limits.

The same-task scope_review agent tracks plan adherence and supplies anti-slop
and anti-OOP review. Transport and reducer agents have disjoint files; root owns
protocol admission, journaling and integration. Godot Node/Thread/RefCounted
idioms are allowed by the user; there is no entity hierarchy or local simulation.
The backend, authoring, artwork, map and renderer are not rewritten in this pass.

Research: Godot HTTPClient supports incremental polling/stream body reads;
HTTPRequest completion waits for the full response. The active scene tree stays
on the main thread; the SDK worker owns HTTP clients and data reduction. UI can
later use shared Theme resources, Control containers, Tree for disclosed causal
branches and RichTextLabel for structured logs. Preserve the old log's reading
anchor, copy/select and bounded visible rows without discarding the raw journal.
Godot JSON parsing is permissive, so strict admission needs a lexical gate.

Primary references:
- https://docs.godotengine.org/en/stable/classes/class_httpclient.html
- https://docs.godotengine.org/en/stable/classes/class_json.html
- https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html
- https://docs.godotengine.org/en/stable/tutorials/performance/using_multiple_threads.html
- https://docs.godotengine.org/en/stable/tutorials/best_practices/node_alternatives.html
- https://docs.godotengine.org/en/stable/tutorials/ui/gui_containers.html
- https://docs.godotengine.org/en/stable/tutorials/ui/gui_skinning.html
- https://docs.godotengine.org/en/stable/classes/class_tree.html
- https://docs.godotengine.org/en/stable/classes/class_richtextlabel.html

Completed 2026-10-11: the project-local SDK now implements the current protocol,
worker-owned HTTP/SSE transport, pure subjective reduction, causal helpers,
recording and cold replay. Two real backend encounters ran to terminal state
with native headless Godot controlling both seats: ranged combat (9 commands)
and spell combat (39 commands, including ordered Magic Missile targets). Both
exercised reconnect and duplicate command receipts; every seat cold-replayed to
the same state. All 152 recorded prefixes match current Python reduction exactly,
after only the documented set-order and process-local sense-hash normalization.
The combined reducer/causal corpus passes 459 cases covering all 28 typed fact
classes. Schema, decimal, malformed transport and journal checks also pass.

The SDK README describes ownership, API usage, repeatable test commands and
limits. generated/sdk_validation.json and generated/sdk_checks.json retain the
validation summary and evidence paths. The independent same-task scope reviewer
found no critical blocker or scope drift. The exploration scene still runs
offline; attaching presentation to this SDK remains the next integration step.
No unsigned native extension is required, and Windows security was not changed.

## Authoring-driven SDK rendering: movement and attacks

User direction, 11 October: connect rendering to the SDK using existing authoring
JSONs; concentrate on movement, jumps, attacks and opportunity attacks. Skip VFX.
Behavior: a live player chooses a disclosed action/target; the backend resolves
it, and the same recorded operation drives authored character animation and
displayed state. The scene must never move actors locally to invent legal steps,
finish interrupted paths, or show latest-state HP before the presented impact.
Boundary: real SDK choices/preview/commands through displayed placements, frames,
equipment and causal commits. Inputs: current subjective records and tracked
authoring. Expected output: authored step/jump/attack playback in all four camera
views, genuine reaction ordering, matching final state and reproducible replay.

Plan:
1. Inspect current records, source movement/attack/rig/equipment authoring and the
   existing native renderer/AnimationTree. Keep backend and authoring unchanged.
2. Add a pure authored presentation compiler for the requested fact families,
   preserving source occurrences and reducer order. Prepare it on the SDK worker;
   maintain separate consumed and displayed progress. VFX remain explicitly off.
3. Adapt native character sampling to admitted identities/equipment and authored
   clocks. Feed AnimationTree from displayed time, preserving idle transitions,
   eight facings, camera continuity, hit/death reactions and jump ground contact.
4. Add a playable scene/session using disclosed terrain and placements, the
   existing shaders/grid ordering, minimal native action/navigation controls and
   directional illumination. Retain the offline exploration scene separately.
   Do not make the noncausal Unity map into backend state or add wall physics.
5. Exercise native movement, jumping, melee/ranged attacks and opportunity-attack
   interruption through actual backend records. Check pause/backlog/reconnect,
   exact end state, camera continuity, native rendered output and frame timings.
6. Document the launch path, controls, actual coverage and material limits.

Same-task scope_review supplies plan adherence, anti-slop and anti-OOP review.
Root owns integration/session/world drawing; renderer agent owns authored actor
adaptation; reducer agent owns causal presentation and authentic test scenarios.
No alternate SDK/reducer, effect pipeline, general editor, backend rules rewrite,
new asset intake or speculative binding registry is part of this change.

Completed 11 October: `play.cmd` now runs the existing Lantern Crypt through the
project-local SDK and production Godot scene. The same authoring-driven compiler
and separate displayed timeline consume live packets and cold recordings. Real
modular/fixed actors, exact equipment, movement speed/continuous gait, jumps,
melee/ranged body actions, damage/life reactions and opportunity-attack holds
are connected to native AnimationTree sampling. The backend owns every command,
step, outcome, visibility and light level. Directional lighting and existing
environment depth/normal shaders are retained.

Validation: 3,520 compiler checks across24 subjective seat streams from12 real
recordings, plus15 explicitly synthetic first-admission boundary checks. Native
production viewport input, movement, jump, receipts, end turn and reconnect pass;
recorded production scenes check pause/backlog, four camera views, actual sprite
contacts/lift and exact canonical final state. Both first-edge and late lethal
jump interruptions were captured from native backend resolution. Shared shader
regressions pass16 pixel comparisons plus4 alpha-order comparisons. Detailed
counts, inputs, logs and performance measurements are in
`generated/player_validation.json`, not summed as distinct gameplay scenarios.

The same-task reviewer cleared plan adherence and the identified support-staging,
source-clock and receipt-recovery issues. No backend or source authoring was
changed. VFX, connector-transfer choreography, general object action UI and the
future large causal map remain outside this pass. The initial texture load can
stall the main thread; the measured native Crypt startup and post-ready frame
timings are separately reported in README.md and the validation artifact.

## Contextual controls, icon HUD, equipment and source lighting

User direction, 12 October: recover the Pygame/BG3 style of world interaction,
including opening doors; use a transparent action bar with Base, Class, Spells
and Items groups; show equipped items and a searchable inventory with existing
icons. Replace resolved backend light-level tinting with Godot lighting driven
by actual sources/radii and the existing sprite normals/depth.

Behavior boundary: native viewport/control gestures -> admitted discovery and
preview -> existing commands -> displayed world/HUD/lighting. No optimistic
inventory changes, client movement paths or new rules. Sources are the surviving
Pygame interactions, current SDK, authoring/ui and world/rig registrations; BG3,
BG2 and PoE2 are interaction/layout references, not replacement game contracts.

Plan:
1. Study Pygame click/modifier/approach and action family behavior, the current
   typed command/preview/HUD data, authored icons and actual light propagation.
2. Generalize the live scene's native action selection, contextual world picking,
   right-click alternatives, cancel/confirm gestures, force attack and safe
   approach. Refresh discovery after movement before interacting with an object.
3. Build translucent grouped icon controls, contextual tooltips, an equipment
   layout and searchable bag. Use exact native variants/compatibility/commands;
   ensure focused text input and UI clicks never spend world actions.
4. Publish existing light source parameters through the player projection where
   currently omitted, only as required for correctly disclosed sources. Godot
   evaluates their receiving light through authored normals/depth; backend
   perception remains authoritative. Do not infer radii from categorical tile
   brightness or mutate backend lighting rules. Preserve source/schema identity
   and make any compatibility limits explicit.
5. Verify real door approach/open/close, base action/targeting, equip/unequip,
   inventory search and input isolation through the live player; inspect native
   UI screenshots. Validate radius/activation/normal response and honest limits
   of light occlusion. Rerun affected SDK/renderer behavior checks, record frame
   timings, then update runnable controls and validation evidence.

Root owns live command/input integration. map_audit owns HUD/icon/equipment UI;
render_audit owns source lighting and any necessary typed source-field
propagation. scope_review supplies plan adherence, anti-slop and anti-OOP review.
VFX, the general editor, a replacement inventory model, new assets, gameplay
simulation and a new large map remain outside this pass.

Accumulated user direction: Diablo-style partial wall transparency where walls
obscure a controlled character or a hovered disclosed walkable cell. Use the
current painted order and authored sprite masks to set a shader opacity;
restore opacity as the view/target changes. Faded walls allow ground selection
through them; Ctrl force-attack can still explicitly target the wall. This is
presentation only and does not change visibility, movement legality or physics.

Accumulated chest correction: compare storage-chest rendering with the original
sprite, including the earlier Pixi defect. Check exact rest-source selection,
component masks, pixel sampling and pivots in all views and both states. The
current intact banks contain reconstructed artwork; use the preserved original
library rest records with their existing registration/normal/depth references
where the authoring provides an explicit link. Keep destruction banks and source
JSON/art unchanged. Fix the independently verified boolean state-key mismatch.

Validation complete for this pass: real native movement/jump/reconnect (44),
door/equipment/Dodge/search (32), chest approach/open/close (15), source-light
activation (111), four-view wall opacity/picking/pixels (230), and eight original
chest rest comparisons (148). UI boundary/recorded/portrait checks, the refreshed
SDK suites, backend projection/event checks and historical lethal-OA playback
also pass. Counts describe assertions, not distinct gameplay scenarios.
`generated/interaction_validation.json` links evidence and performance, including
remaining first-use/UI stalls. Reviewer cleared the scoped source changes.

The original-rest source relation was absent from owner JSON; implementation
reuses the existing explicit six chest pairs in tools/build_unity_map.py as a
client policy, rather than claiming a new source-authoring binding. Backend
changes only pass through already-known source fields and publish/retain actual
portable torch activation events. No game/light propagation rules were changed.
Optical wall shadows, undisclosed and standalone spell emitters, and runtime
adoption of modular geometry remain limits. There is no claim of complete visual light
parity or of large-map lighting performance.

## Pending: modular character geometry delivery

User direction, 12 October: add the supplied [depth/normal handoff](/mnt/c/Users/tommaso/Documents/assets/fantasy-unified-catalog/modular-character-geometry-2026-10-11/delivery/HANDOFF.md)
to the task list. The delivery exists; the runtime has not adopted it. It covers
30 actions, 450 poses and 3,600 directional frames for one assembled outfit,
not independently reusable geometry for arbitrary modular equipment combinations.

- [ ] Adopt the matching whole-outfit geometry through existing authoring owners
  and character lighting, with its exact outfit coverage explicit. Handle other
  loadouts as unsupported until matching geometry is available; do not assume
  aggregate maps become component geometry by masking them.
- [ ] Preserve the shared 128×128 frame cells, eight facing rows, original colour
  alpha, body anchor (64,60), ground origin 41, sockets and existing clip timing.
  Seventeen actions have authored 12 FPS clips; thirteen are untimed library
  actions and acquire no invented clocks or gameplay bindings.
- [ ] Decode linear camera-space RGB normals and affine camera depth with their
  support/validity masks. Facing is already encoded. These are not environment
  RG-depth/BA-normal packets; reconstruction origin (64,96) and depth units must
  not replace placement or game-world elevation. Unsupported pixels stay explicit.
- [ ] Verify matching frames, facing/light response, alpha and ground contacts
  before claiming runtime adoption. Same-task plan-adherence, anti-slop and
  anti-OOP review applies during implementation.

This request records pending work only; no artwork import or shader integration
is part of the current HUD/wall correction.

## HUD alignment and visible-tile wall transparency correction

User direction, 12 October: keep action icons aligned when extra controls appear
beside group titles. Also fade every wall covering a currently visible tile,
instead of changing transparency only near the pointer or controlled actor.

The observable boundary is the running HUD and scene: both icon rows align with
mixed headers, paging and window resizing; all obstructing walls fade together
in all four views, including partial tile overlaps and nonwalkable visible tiles.
Use the displayed SDK senses.visible set, existing terrain elevations, painted
order and original sprite masks. Remembered terrain alone must not trigger fading.
Pointer movement, menus, pan and zoom must not change which walls qualify.
Ordinary clicks pass through faded walls; Ctrl retains explicit wall targeting.

Scope review supplies plan adherence, anti-slop and anti-OOP review. Keep this
inside existing native controls and wall-opacity presentation; no new visibility
simulation, gameplay rules, physics, artwork or rendering architecture.

Completed: group headers share their measured minimum height, preserving both
icon rows across paging and window sizes. Wall fading uses current visible tile
diamonds, actual source masks and grid order, including edge overlaps. Canonical
projected buckets keep pan/zoom independent; only changed visibility, geometry
or camera quarter recomputes opacity. Unrelated displayed commits retain it.
Recorded native UI checks pass 67 assertions; existing UI boundaries pass 37.
Native wall checks pass 402 assertions across four views, with screenshots and
named nonwalkable/visibility-removal presentation fixtures. The Crypt wall update
takes 9.728–15.544 ms when recomputed; this is not a per-frame or large-map result.
Reports remain in generated/interaction_validation.json and its linked artifacts.
The final native door/equipment/Dodge/search smoke passes 32 assertions using
both corrections together; the same-task reviewer found no blocking scope issue.

## Connection readiness and overlapping wall fade repair

User reports an HTTP timeout and visible vertical seams after global wall fading.
Verify the exact run's Windows endpoint and admitted state before announcing a
playable preview. Log terminal connection errors and distinguish window creation
from initialized, acknowledged state with current choices. Preserve SDK timeout,
attachment and command semantics; do not restart unrelated backend instances.

Faded overlapping wall sprites must not accumulate opacity into join stripes.
Use original colour/selection alpha and the existing painter order in a small
GPU coverage pass; suppress fully covered earlier wall pixels before applying
opacity. Preserve translucent source edges, other objects, current visibility,
click-through and Ctrl targeting. No cast shadows, CPU depth reconstruction,
new geometry or modular-normal integration. Validate overlapping native pixels,
camera/viewport changes and real connection readiness. The same-task reviewer
tracks plan adherence and anti-slop/anti-OOP scope.

Accumulated user direction: profile the first goblin reveal and steady low FPS,
inspect crash/errors, and trace the goblin's pixel size/pivot to source authoring
and backend appearance. Use the user's actual 65-packet encounter recording for
repeatable cold asset admission and identical displayed states. Remove measured
blocking bulk clip loading and unchanged sorting/grid work; keep exact admission
timing, authored scale and final canonical state. Preserve JSON frame/phase dumps
and native visibility/compositing/input checks. The same-task reviewers cover
plan adherence, anti-slop, anti-OOP and the source scale trace.

Further correction: wall base/floor joins on the camera side are not blockers.
Require a disclosed tile behind the authored grid boundary before alpha overlap
can fade the wall; back walls retain their complete opaque base in all views.
The user also identified the incomplete wall light. Restore its existing authored
`lit_animation` (original 16-frame/10-FPS flame) at its registered pivot/scale,
controlled by displayed is_lit/visibility. This is fixture appearance only;
other VFX and lighting/rule redesign remain outside scope.

User added flame-synchronous light fluctuation and naturally smooth radial
falloff. Derive a gentle bounded energy curve from the existing flame frames,
interpolate with the displayed native animation clock, and keep backend source
activation and circular extent unchanged. Smooth brightness through the existing
very-bright/bright/outer anchors; preserve directional lights and normal/depth
response. Validate native receiver pixels, continuity, pause and extinguishing.

User identified overlapping straight artwork at a wall corner and asked about
Godot tilemap tools. Resolve compatible adjacent edges at the same cell/material
and vertical span into the existing authored corner sprite. Retain each backend
wall identity for targeting and return to straight artwork when either disappears.
Use the current grid presentation path, with no backend geometry changes or
native map-node migration. Test four views, source registration, incompatible
edges, edge removal and original target IDs. Scope review continues plan
adherence, anti-slop and anti-OOP checks.

The subsequent repair corrects corner source orientation (quarter minus authored
candidate index); the user confirmed the corner in the playable preview. Native
corner checks pass82. Non-white body/palette pixels reproduced a double sRGB
conversion; the corrected shader passes59 native lighting checks without ambient
illumination. Character normals remain explicitly deferred until full assets.
The user requested a concrete geometry handoff after the supplied whole-outfit
maps were compared with the actual fighter/mage categories. No approximate
reuse was authorized. GEOMETRY_HANDOFF.txt records delivered files, exact current
loadouts, the rejected independent-hull experiment, needed component coverage,
Goblin15's separate gap and remaining runtime work. Current combined validation
is tracked in generated/render_repair_validation.json.

The user chose B after annotated native comparisons: rear-facing room walls stay
solid. Later screenshots established a separate mixed-corner bug: fading the
whole sprite darkens the cap against empty background and affects adjacent
areas. The superseding requirement is per-fragment opacity over currently
visible tile footprints, preserving the original source outside those areas.

Implementation: project disclosed cells at their actual support elevations,
qualify foreground boundaries, and upload a shared packed list of tile diamonds.
The shader applies alpha/discard only inside eligible diamonds after lighting;
picking uses the same boundary. This replaces CPU source-alpha scans. Hidden
mode retains each node and discards only covered fragments. Z cycles Solid,
Translucent, Hidden, preserving rear walls and text focus. The mask does not
claim actor-silhouette coverage or frontmost-content selection across overlapping
Z layers. Native mixed-corner pixel tests cover all four views/fractional zoom;
all uncovered samples equal the solid reference exactly. The general native
wall tests cover real initial/terminal states, Ctrl targeting, visibility changes,
zoom and input focus. Counts/evidence live in generated/render_repair_validation.json.

Architectural lighting: original wall and door normals were mounted, but their
outward faces rejected interior lights. They now receive two-sided diffuse light
as an explicit isometric display convention. Source depth/normals, radii and
native directional receiving are retained; no ambient wash or shadow simulation
is introduced. Native tests cover original straight/corner and three door states
in four views. Ownership suppression at fractional zoom now requires surrounding
later coverage, avoiding missing edge pixels; its narrow boundary retains
ordinary source-over alpha rather than promising perfect one-alpha composition.

User explicitly requested full-codebase reviews while root fixes the corner.
Same-task correctness, efficiency and anti-slop/anti-OOP reviewers audited SDK,
presentation, rendering, UI, tools and tests. Reports are under generated/audit_*.
Profiler acceptance now rejects presentation errors and incomplete playback;
documentation distinguishes the runtime character graph from its exported
inspection snapshot. Broader architectural and contract findings are recorded
for follow-up rather than silently expanding this corner repair.

## Modular tint and open-door placement correction

User direction, 12 October: ordinary modular sprite colouring must be tint,
not equipment palette substitution. This supersedes the historical held-item
zone-swap policy for this client. Apply source RGB × authored tint exactly once
before existing lighting in both live and offline modular paths; preserve alpha,
source frames, layers and registration. Validate original fighter/caster layers
including bright/unmapped shades with native pixel comparisons. The supplied
screenshot also adds open-door placement: inspect the authored hinge/frame/leaf
registration and correct the adapter, preserving original art and backend state.
Same-task scope reviewer tracks anti-slop/anti-OOP and plan adherence; correctness
reviewer is checking the door source while root fixes tint. General audit debt
and modular normal/depth intake remain outside this repair.

## Connected gallery and scale profiling

User direction, 12 October: after the visual repairs, address the full reviewer
findings and optimize against a substantially larger furnished, causal map.
Add a separate Lantern Gallery scenario while retaining the original Crypt
baseline. Its new hall spans 48 by 36 cells beyond the original burial hall,
connected through ordinary native doors. Existing party and Crypt occupants
retain their positions; one distant authored guardian keeps the extended
encounter playable until its ordinary defeat, without changing combat rules.

Use existing furniture, statues, chests and native torch builders. Preserve
walkable entrance, central and cross aisles, and expose named route points for
actual SDK movement profiling. Cold world facts and ordinary torch activation
publish the authoritative map; no ambient illumination or client-generated
occupancy/visibility is added. Verify room connectivity, supported placements,
serialized state and encounter admission before the native performance run.
Scope reviewer owns the bounded map changes; root and the same-task correctness
reviewer retain independent plan, anti-slop and anti-OOP review. Root owns the
client profiling/optimization and the accumulated visual repairs.

## Storage loot, combat history and presentation coverage

User direction, 12 October: opening storage should show a compact closable
inventory with individual loot and Loot All. Restore the combat log and add a
subjective event stream: green when actually rendered, red when required
animation is missing, with a button to copy diagnostics for investigation.

Boundary: displayed subjective SDK state, current admitted choices/preview/
numbered commands, native scene presentation and Godot UI input. The current
backend lacks individual stored-item loot and public contents, so this extension
includes only the native single-item action, explicit discovery identity, nullable
open/observed-container contents and corresponding cold world after-values.
Closed/unobserved contents are unavailable, not an empty or privately read bag.
No local inventory mutation, guessed target indices, rules or extra endpoints.

Sequence: implement the small native loot gap; connect an icon-based storage
panel and safe reopen/close behavior; expose recorded combat text at displayed
commits; attach bounded per-occurrence diagnostics to the existing compiler and
timeline and confirm body samples after native frame presentation; add copy
controls; validate real single/all transfers, authority changes, pause/backlog,
missing/partial visuals, source-order log reveal, clipboard and GUI input.
Queued, canceled, state-only and offscreen events are explicit neutral states.
Compiling an animation or advancing its clock is not evidence of rendering it.
Missing effect components remain visible even when a body animation played.

The same-task scope_review agent tracks plan adherence and performs anti-slop /
anti-OOP review. Separate agents own trace compilation/timeline and the minimal
backend loot extension; root owns HUD, renderer evidence and integration.
Original assets, physics, VFX implementation and unrelated rules remain unchanged.

Completed and reviewed: native loot plus schema 6 contracts, displayed storage
popup, combat history, bounded event coverage and clipboard controls. Real GPU
acceptance passed 63 loot checks and 88 history checks; the trace suite passed
2,341 and the current SDK passed all six lanes (11,725). The actual eight-packet
loot journal also matches Python reduction. Evidence and explicit coverage
limits are indexed in `generated/loot_history_validation.json`. Missing visual
components remain red; this work does not claim to implement them.

## Corrections and full modular geometry delivery

The latest screenshots invalidate the prior floor-diamond wall clipping policy
and its acceptance tests: both hidden and translucent walls retain diagonal
fragments. Select complete finite native boundary members from displayed visible
support cells and actual elevations. Keep rear members solid. Reuse the original
joined corner when both members have equal opacity; otherwise use each original
straight member with uniform opacity, omitting hidden members. Preserve native
IDs, source registration, lighting, shadow passes, ordinary click-through and
Ctrl targeting. Validate full neighboring wall runs, four views, elevated spans,
mixed-opacity joins and restoration; a corner-only comparison is insufficient.

Combat log completion order is not causal narrative order. Study the archived
Pygame/NeuroClient consumers, reconstruct native parent/child relationships for
both history tabs, preserve admission/privacy gates and source text, and place
the panel on the right with partial transparency. Tests must include the real
attack/damage/death chain, nested entries and copy output.

The user supplied the completed full-components geometry HANDOFF on 12 October,
superseding the deferral above. Integrate its per-source paired normals/depth and
validity masks into modular receiving light, retaining original tint, alpha,
authored order, pivot and clocks. Use the delivered final references on demand;
optical depth is never game Z or painter order. Validate equipped fighter/mage,
facings and equipment changes, including unsupported source pixels.

Root owns wall runtime/visual acceptance; render_audit owns history; map_audit
owns modular geometry. scope_review tracks plan adherence, anti-slop and anti-OOP
review. No unrelated backend rules, VFX or new geometry generation is included.

The user's next screenshot shows excessively dark characters despite lit carried
torches and explicitly asks about light elevation. Correct the optical emitter
height while retaining native activation, XY origin and circular radii. Carried
torches have no selected visual attachment; use an explicit elevated carried-light
convention, not an invented hand binding. Derive wall fixture elevation from its
registered flame artwork once during existing media preparation. Compare actual
character receiving light before/after, extinguished lights, raised floors and
jumps; keep unsupported pixels, rear-wall policy and no general ambient light.

Independent review found that delivered observations use a 45-degree numerical
camera and reconstruction origin (64,96), while the client had directly applied
their depth in its 30-degree display camera. Correct the optical position and
normal transform using that source provenance; the original sprite pivot (64,87),
alpha, game elevation and layer ordering must remain unchanged. Validate actual
torch-lit characters visually as well as source-coordinate and GPU comparisons.
Do not compensate for this registration error with stronger or invented lights.

The sprite-only renderer now disables 3D MSAA after unchanged-frame comparisons
showed fractional-zoom edge variation with 4x MSAA. Preserve the diagnostic and
validate the actual default without increasing image tolerances; source alpha
and 2D overlay antialiasing remain independent.

The user's later readability request explicitly supersedes the earlier no-ambient
policy. Use a native Godot Environment resource for a modest ambient baseline,
keeping directional and disclosed torch contributions. Compare actual source
characters under native Omni and ambient lighting, including extinguished lamps;
do not claim native spherical falloff reproduces backend horizontal light bands.
Current retained scenery remains last-known subjective data, with current actor
and emitter admission unchanged. Distinct remembered-map shading is still missing;
ambient or atmosphere fog must not be presented as implementing fog of war.

The user requested a full codebase anti-slop review, including every shader and
material path against official Godot guidance. map_audit owns the shader inventory,
render_audit correctness/efficiency, and scope_review anti-slop/anti-OOP and plan
adherence. Save evidence-backed findings, distinguish proposals from implemented
changes, and measure current small/large-map behavior before reopening the preview.

Apply the review's bounded media-residency correction during this optimization
pass: retain original colour CPU images for picking, but release exact modular
geometry companion Images after GPU upload. Carry CPU/GPU roles with accepted
current/upcoming media plans, including cached revisits and full eviction. Keep
GPU readiness, source masks, timeline holds, and renderer output unchanged.
render_audit implements and validates it; scope_review reviews plan ownership and
cache boundaries. Report released decoded bytes separately from process/VRAM use.

## Complete the open review repairs

User direction, 12 October: fix all open findings, investigate client/server wait
coupling and remaining spikes, then build a single-light demo comparable to the
supplied `Downloads/760aYk8EL1saBPdF.mp4`. Do not stop after another review.

Later steering assigns the lighting study and isolated demo to a separate user
chat running Astra/xhigh. This task continues renderer correctness, performance,
and the existing regression checks. Demo delivery is no longer required here;
shared production renderer files remain owned by this task during these repairs.

Behavior/boundary: the actual Godot player remains responsive during network and
media waits, consumes every admitted event canonically, renders disclosed worlds
at positive/negative heights with clear remembered scenery, and receives native
point/directional light with unchanged original artwork. Inputs are the current
subjective SDK packets, real small/Gallery recordings, original authoring/maps,
and named delayed-server/height/light fixtures. Outputs are native rendered
pixels, exact canonical replay state, bounded residency/queues and frame profiles.

Root owns native item lights, receiver bounds, actor/quarter creation costs,
retired actor hosts, bounded profiling and final integration. render_audit owns
cancellable bounded preparation, duplicated admission/metadata work and network
decoupling evidence. map_audit owns below-floor ordering, remembered/current
scenery and water lighting/display-clock behavior. scope_review tracks adherence,
anti-slop and anti-OOP review across the whole ledger. GPU checks are serialized.

Native Omni attenuation is optical presentation; backend circular light rules
and subjective disclosure remain authoritative. Keep existing source NORMAL and
LIGHT_VERTEX adapters; no second custom torch contribution. Prove more than eight
relevant lights and reconstructed receiver bounds on the shared floor path.
Fix defensive numeric sampler guards while touching those materials. Preserve
original alpha, tint, layer/contact registration, reaction ordering and clocks.

The separate lighting track owns the runnable one-character, one-light scene
and direct visual feedback. This renderer task still preserves exact source
geometry and reports measured residual costs honestly. Native shader plumbing
checks do not establish artistic approval of character lighting.

Repair implementation decisions: native point lights use spherical Omni falloff (energy2, attenuation1) at disclosed optical anchors; backend radius facts and visibility stay untouched. Compatibility capacity is explicitly64 relevant lights per draw and256 renderable lights, tested beyond the default8. Source reconstruction expands native culling AABBs from affine extrema. Shared animation templates are scene-owned; each actor still has its own native clock. Hidden actors retain only passive facing and canonical data. Native Control layout is retained. The measured first-quarter construction stall justifies extracting only common source-sprite/material helpers for a bounded hidden quarter builder; this is not a second game controller or a general rendering framework. A prepared view must publish camera, original artwork, ordering, masks and picking together, reject stale targets/state, and leave the current view responsive while preparing.

## Native Windows source comparison and remaining CPU work

User steering: copy runtime WSL inputs into Windows Documents/Dev and measure
whether spikes persist before further renderer changes. The project itself and
modular geometry were already native. Authoring/media were copied unchanged to
NDClientData and 134,380 relative paths/sizes verified; originals remain intact.
Fresh same-code Crypt/Gallery runs changed only the two configured source roots.
All four runs reached the complete canonical terminal state without errors.
Gallery retained 78 frames above 33.333 ms in both arms, so native paths remain the
default while the existing renderer repair work continues. Saved reports disclose
OS cache state, concurrent demo, and differing idle display-clock gaps.

Remaining measured work is proportional to the entire retained map even for
sparse source changes. map_audit owns accumulated Timeline change identities,
incremental WorldRows and scenery indices; render_audit owns exact-order floor
sorting/buffer work; root owns wall/draw-order consumers and native integration.
scope_review continues plan-adherence, anti-slop and anti-OOP review. Preserve
original pixels/order, staged supports, visibility and canonical replay. Changes
must be validated against the original full Gallery and focused native fixtures;
performance closure requires measured frame intervals, not callback budgets.

## Asset preloading and asynchronous world publication

User direction, 12 October: preload assets, prepare world updates asynchronously,
preserve event ordering, and profile the same large map again. Root owns the
renderer preparation/publication path; render_audit owns encounter asset loading;
map_audit owns prospective Timeline boundary admission; scope_review tracks plan
adherence and performs anti-slop/anti-OOP review. No backend or artwork changes.

Prepare outfits and environment families from already received server events through the existing loader,
with configurable residency and explicit initial readiness. Received future states are permitted preparation inputs; their artwork, logs and interactions remain hidden until their presentation boundary. Animation time is used for deterministic lookahead, rather than starting work only when a boundary is due. Worker threads derive
passive world rows and buffers from a stable prospective boundary. Native object
creation is sliced while the displayed scene remains active. A boundary may not
publish state, staged supports, trace/log commits or future actors before its
matching world is ready. Preserve source order, same-time commit order, zero-time
groups and original event timestamps; do not catch up elapsed loading time.

Acceptance: delayed preparation preserves earlier visible state and ordering,
complete actual Crypt/Gallery recordings match canonical state and drain, native
original-source pixels/picking survive publication and camera changes, cancellation
and close release preparation, and measured whole-frame profiles report remaining
stalls honestly. The separate lighting demo and its process remain untouched.

Measured follow-up within this preparation path: initial native Gallery still
spent 6–11 ms sorting static entries and 3–6 ms on wall targets at publication.
Prepare the exact seven-field/ID total order and finite wall targets before
admission, including changed floor representatives and hidden straight members.
Keep actual mode/current-visibility selection at publication. Repeated preload
readiness scans measured 21.6 seconds across the startup source stream; replace
those scans with publication/failure/eviction accounting and validate roles/pins.
These changes require fresh native source comparisons and full Crypt/Gallery runs.

## Local presentation prediction and measured media selection

User direction, 12 October: start extensible local prediction now, retain ordered
asynchronous preparation, and optimize before subsequent character-light integration,
event studio and VFX migration. Those three subsequent stages remain outside this
implementation. No backend gameplay or asset changes and no cross-chat coordination.

Root owns shared authored track sampling, bounded speculative prefixes and native
player integration. map_audit preserves native command identity through compilation
and tests it. render_audit owns measured new-family media selection cost. scope_review
tracks plan adherence and performs anti-slop/anti-OOP review. Native GPU runs serialize.

Prediction starts at submission of a preview-admitted command. A passive command
record owns an authored body/motion prefix, identified by game, epoch, audience and
command number. It never writes the reducer, visibility, resource costs, logs or
authoritative trace evidence. It consumes the selected server route or jump target
path; no local pathfinding/physics. Stop before the first edge/contact and cap
unconfirmed visual progress at 120 ms. Known immediate opportunity attacks suppress
motion prediction; missing media/support suppress prediction without blocking input.
Unknown/network-failed receipts remain unresolved, never resent or treated as rejection.

Reconcile only at admission of the matching authoritative group. A matching sampled
prefix can hold its already displayed pose until canonical time catches up; no
canonical fast-forward or skipped commits. Changed timing/clip/path or a prior
reaction relinquishes the overlay before authoritative sampling. Rejection returns
the speculative pose to origin over a bounded interval. Reset/close removes it.
Shared authored track data and the native AnimationTree remain the extension seam;
future event families need explicit authored prediction prefixes, not fabricated
outcomes. Unsupported families play through normal confirmed presentation.

Acceptance covers actual recorded movement, jumps, attacks and lethal OA; ordered
and reordered receipt/event arrival, foreign operations, duplicate delivery, reset,
rejection, unresolved timeout, media/world holds and source changes. Check unchanged
canonical state and hierarchical logs, native sampled continuity/camera changes,
real delayed-server responsiveness and a fresh complete large-map frame profile.
Report finite evidence and remaining stalls rather than promising 1–2-frame rollback.

Prediction acceptance completed on original recordings and a real delayed native
command run, including camera rotation and walk/jump handoff. Review repaired the
attack-source enum mismatch; outcome-ambiguous body selection stays confirmed-only.
The full Gallery drains canonically; source-selection CPU cost improves, while
whole-frame p95/max remain mixed and publication spikes remain open. Exact finite
checks, raw profiles and remaining limits are recorded in
`generated/prediction_validation.json` and `generated/prediction_profiles.json`.

## Native 2D receiving light and settings

User direction, 12 October: integrate NDCharacterLight/NORMALS_PRODUCTION_HANDOFF.md,
add Escape settings with character normal smoothness, and use native 2D lighting
for the entire painted world. This supersedes mixed 3D/2D receiving proposals.
Spells/VFX remain a subsequent task. Existing source placement, elevation, painter
order, subjective disclosure, preparation, prediction and canonical logs remain
owned by their current systems.

The user explicitly retains the 3D engine, camera, quads, placement and sorting.
Native PointLight2D/DirectionalLight2D and CanvasModulate receive light in an
offscreen atlas with separate source-component cells. Existing 3D quads consume
the resulting straight RGBA with unshaded materials; they receive no second 3D
lighting pass. This is a lighting migration, not a migration of world rendering
to Canvas. Preserve floor batching and original per-component painter order. Authoring masks, door partitions and translucent
wall coverage still own source composition. Screen-normal light height is explicit
and separate from world elevation. Depth remains original shadow/geometry data.

render_audit owns exact source-identity normal-profile intake and environment
Canvas shader conversion. map_audit owns native Escape settings and persistence.
scope_review tracks plan adherence, anti-slop, anti-OOP, and the generated-shadow
handoff. Original/Gentle/Reference switch through prepared GPU textures only;
Reference is the handoff demo default. No changes to the lighting source project.

Acceptance: native screenshots across profiles, camera quarters, elevations and
wall modes; unchanged source alpha/placement, selection/picking and event clocks;
modal input without pausing network/presentation; no real Light3D receiver path;
actual recorded gameplay canonical completion and same large-map whole-frame
profiling. Generated shadows must use original depth/support and dominant-source
selection, not the original modular Shadow artwork or the demo's fixed three-light
limit. Record measured limits honestly. Native GPU runs serialize.

Further user direction in this run: light height is fundamental; excessive
overlap must be clipped as a maximum accumulated illumination, not as wall
occlusion or a shorter radius. Preserve the handoff's normal-light height and
the distinct actual fixture/carried elevation and shadow-height conversion.
Keep native Godot light accumulation and cap its final gain to one using the
original tinted source colour as the upper bound. This prevents bright sources
from washing artwork to white without a second atlas or a custom light loop.
Shared source-colour sampling must retain memory, highlight, water, flame and
alpha behavior. Verify overlapping lights and native height response, then
repeat actual scene checks and Gallery profiling. Continue the existing
anti-slop/anti-OOP and plan-adherence review through scope_review.

Migration acceptance is recorded in `generated/native_2d_validation.json` and
`generated/native_2d_profiles.json`: original source and actual-scene checks pass,
and the full Gallery drains canonically. The cap and normal-height response are
verified with native lights. Same-root review found no remaining correctness
blocker. Performance is explicitly incomplete: steady final Gallery p95 is
8.58–11.80 ms, and publication reaches 122.047 ms. This is faster than the first
2D implementation but slower than the prior 3D receiving path. Those spikes,
cold view preparation, finite atlas capacity and directional shadow fill remain
documented limits, not completed optimization claims. No VFX/Studio work was added.
