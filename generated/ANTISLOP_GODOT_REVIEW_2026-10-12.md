# Godot architecture / anti-slop review — 12 October 2026

Read-only review of the client, presentation, SDK, animation, UI, asset-conversion and validation boundaries. No runtime, source artwork or backend changes; no native/GPU processes launched. Locations refer to the inspected source revision and may move during concurrent repairs. This is an architecture review, not a claim that every line or geometry asset is correct.

The user's latest direction authorizes a readable minimum illumination. Earlier “no ambient” notes are superseded. Lighting must not become the mechanism that hides undisclosed actors/items or distinguishes current perception from remembered terrain.

The largest replacement opportunity is lighting and resource ownership. The SDK's protocol work and causal presentation are substantially justified. Godot Nodes, Controls, Resources and RefCounted owners are appropriate; replacing them with an ECS or another general framework would add work.

## Findings and recommended order

### 1. P1 — Make readability a native environment setting; stop using darkness as visibility

**Confirmed current behavior:** [play.gd:132](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/play.gd:132) creates a WorldEnvironment but disables ambient. [lighting.gd:127](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/lighting.gd:127) also sets the material base contribution to zero. Consequently a valid surface normal receiving no positive direct light becomes black, even when the backend says the actor is visible. This now conflicts with the user's readability requirement.

Use the existing native Environment's ambient source/colour/energy as the small readable floor; retain directional/point lights for shape. Prefer an inspectable Environment resource instead of a second shader minimum-light formula. Godot already owns this contribution. [Official 4.7 Environment guidance](https://docs.godotengine.org/en/4.7/tutorials/3d/environment_and_post_processing.html).

**Presentation ambiguity, not a demonstrated disclosure leak:** [world.gd:14](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/world.gd:14) emits every retained terrain/object row. Current visual contact gates actors at line89, emitters in lighting.gd, and fixture flames at world.gd:51; it does not separately style current versus remembered props/items. Backend [projection.py:813](/mnt/c/Users/tommaso/Documents/Dev/dnd_engine/dnd/player/projection.py:813) refreshes only natively observed objects; `_object_observed` at730 admits native contacts or incident visible structural boundaries. Unobserved retained objects keep prior values, and lines820–824 clear container contents on grant loss. [SDK reducer:34](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/sdk/reducer.gd:34) only applies those disclosed after-values. No current secret-after-value path was found in this bounded check. Ambient can proceed while explicitly documenting that terrain/objects remain drawn from last-known state. Do not claim that illumination implements FOW or silently add a broad FOW redesign. Test actor/item grants separately from light intensity.

### 2. P2 — The point-light loop duplicates native lighting, but replacement is not a one-line switch

[source_lighting.gdshaderinc:34](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/source_lighting.gdshaderinc:34) tests every disclosed light at every surviving fragment, adds a custom three-band attenuation and writes the result through EMISSION. [lighting.gd:99](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/lighting.gd:99) maintains a separate float texture of light data. This bypasses native light selection and duplicates colour/attenuation ownership while the scene already supplies ALBEDO, NORMAL and LIGHT_VERTEX.

Prefer native OmniLight3D instances for disclosed sources, with backend identity/activation/radii remaining data and a documented optical attenuation convention. Preserve the source-packet decoder and the optical receiver transform: these are asset-specific necessities, not a reason to replace the entire shader with StandardMaterial3D. The architectural two-sided receiver can remain a small native `light()` hook. [Spatial shader hooks](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html).

**Required proof before removal:** native OmniLight falloff is 3D, whereas the current custom range test is horizontal. Compatibility defaults to eight omni lights per mesh, and the live ground is a whole-material MultiMesh at [play.gd:363](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/play.gd:363). A naive replacement can leave distant ground instances unlit. Test the furnished gallery with more than eight contributing lights; choose renderer/light limits or order-preserving spatial batches from evidence. Do not promise shadows from transparent sprite quads. [OmniLight3D limits](https://docs.godotengine.org/en/4.7/classes/class_omnilight3d.html), [MultiMesh limits](https://docs.godotengine.org/en/4.7/classes/class_multimesh.html).

### 3. P2 — Media readiness unnecessarily pins and re-decodes GPU-only geometry images

[characters.gd:155](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/characters.gd:155) adds four geometry companions to each selected colour sheet. [media_warmup.gd:135](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/media_warmup.gd:135) requires CPU residency for every requested path; lines142–150 retain all wanted CPU images. A GPU-resident revisit is queued for decoding again at lines54–59 solely because its CPU bytes were released.

Production [character_geometry.gd:29](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/character_geometry.gd:29) needs those companions as textures; actor picking at [play.gd:1471](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/play.gd:1471) reads the original colour alpha, not geometry pixels. Separate GPU readiness from CPU picking/fixture-analysis demand. Release companion Images after upload and let a retained GPU texture satisfy a revisit. Measure actual CPU and video memory; the current four-bytes-per-pixel GPU estimate is not measured VRAM.

For a later native-resource conversion, use imported lossless data textures plus ResourceLoader background requests/cache rather than extending the PNG residency manager. Raw external PNGs are not a drop-in ResourceLoader replacement: the official API requires imported resources. Preserve byte-valued geometry, nearest sampling and independent colour-space settings. [ResourceLoader](https://docs.godotengine.org/en/4.7/classes/class_resourceloader.html), [background loading](https://docs.godotengine.org/en/4.7/tutorials/io/background_loading.html).

### 4. P2 — Recording preparation has no cancellation or bounded lookahead

[session.gd:101](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/session.gd:101) processes the entire recording without checking cancellation. [session.gd:170](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/session.gd:170) joins that worker. Closing a large recording can therefore wait for all remaining decode/reduce/compile work. Prepared messages and [timeline.gd:35](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/timeline.gd:35) groups can also accumulate while display is paused or media-blocked. Diagnostic completed_groups/skipped arrays are unbounded despite the event panel's bounded retention.

Add cooperative recording cancellation and bound presentation preparation ahead of the display cursor. Keep durable SDK consumption/ACK semantics separate from display pacing; do not drop events or equate displayed state with latest state. Replace completed-group history with a count or a bounded diagnostic ring where only the count is used. Acceptance: closing during a long replay terminates promptly, and paused display has bounded prepared memory without losing the resumable journal.

### 5. P2 — Full-map metadata enumeration remains inside every relevant event delta

[environment_media.gd:61](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/environment_media.gd:61) calls `_collect(future)` whenever tiles, objects **or senses** change; `_collect` reconstructs all WorldRows and wall joins. Many movement/perception after-values do not introduce a new source image. Worker execution and per-group caching prevent a main-thread stall but do not remove this repeated work.

Retain the current plus one upcoming group policy. Within its metadata planner, enumerate changed source selectors and the affected wall-neighbor joins, reusing the source-path closure already cached by `row_paths`. Do not build a new dependency framework. Compare requested paths with the current exhaustive planner over the actual route before replacing it; measure planner CPU separately from renderer frame time.

### 6. P2 — Packet admission and normalization are repeated across owners

The live path decodes in [transport.gd:417](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/sdk/transport.gd:417), then independently decodes the same bytes in [journal.gd:36](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/sdk/journal.gd:36). Journal replay likewise decodes at line77 and again in consume. Normalization runs in journal reduction and presentation preparation. The independent public journal boundary is valid; the internal repeated full parse/schema walk is an optimization candidate, not extra semantic protection against a different input.

Establish one admitted-byte owner on each internal path while retaining strict validation for direct public/offline calls and exact raw-record ownership. Avoid a checksum/provenance framework. Measure this before changing it; no speedup is asserted here. Preserve malformed-input, conflicting-duplicate, reducer-failure atomicity, reconnect and Python parity tests.

## Native simplifications worth doing after the visible fixes

- **Scene ownership:** [play.gd:1](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/play.gd:1) inherits the entire 1,344-line workshop controller to reuse sprite helpers. It therefore depends on editor/local-walking/old graph-composition state while overriding ready/process/input/exit. This is a maintenance risk, not evidence that live commands currently simulate rules locally. Extract only the common sprite/material owner into a small Godot Node/helper; keep live and workshop controllers as siblings. Do not introduce gameplay entity classes or a generic renderer framework.
- **Animation resources:** [graphs.gd:64](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/animation/graphs.gd:64) rebuilds every rig Animation/Library/Tree for each actor, and line142 replaces its clip nodes with TimeSeek graphs for causal playback. Cache immutable authored AnimationLibrary resources per rig; keep mutable playback state per actor. Do not replace the causal timeline with automatic AnimationTree travel: reactions, interrupted jumps and exact recorded contacts require its explicit clock. Native resources already support shared loading and per-instance ownership. [Resource caching](https://docs.godotengine.org/en/4.7/classes/class_resource.html).
- **HUD layout:** The actual widgets are native Control/Tree/Containers, not a custom UI engine. Keep them. The stable shell still uses manual viewport arithmetic in [play_hud.gd:189](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/play_hud.gd:189) and all three `.tscn` entry points contain only a scripted root. Move the stable camera/environment/HUD shell into inspectable scenes, anchors, containers and a shared Theme; keep action rows generated from current discovery. Preserve hover bridges, GUI event interception and reading position. This is a maintainability recommendation, not a request to redesign the UI. [Control/container ownership](https://docs.godotengine.org/en/4.7/classes/class_control.html).

## Custom code that should remain

| Area | Decision and reason |
| --- | --- |
| Source shaders/catalog/geometry | Keep numeric packet decoding, validity, original alpha, pivots and four/eight-view selection. Native lights consume these outputs. |
| Lighting | Prefer native environment/light ownership; current EMISSION point loop is the strongest replacement candidate. |
| Ordering and wall reveal | Keep passive boundary/support/painter semantics. Godot transparent depth sorting does not know authored member ordering; sorting_offset is the native integration point. Keep source-over coverage until an equivalent native result is demonstrated. Do not revive physical-depth clipping or replace all quads with Sprite3D blindly. [Sorting API](https://docs.godotengine.org/en/4.7/classes/class_visualinstance3d.html). |
| Media/lifecycle | Native WorkerThreadPool is already appropriate; narrow readiness, memory ownership and cancellation need improvement. |
| SDK | Keep strict admission, current-schema reducer, audience projection, journal, receipt/ACK and SSE semantics. HTTPClient is already native; HTTPRequest completion does not replace streaming SSE. Godot JSON explicitly accepts invalid JSON forms and repairs some Unicode, so a direct parser swap would regress the tested contract. [JSON](https://docs.godotengine.org/en/4.7/classes/class_json.html), [HTTPRequest](https://docs.godotengine.org/en/4.7/classes/class_httprequest.html). |
| Causal presentation/history | Keep compiler/timeline and privacy gates; native AnimationPlayer/Tree and Tree controls already own playback/widgets. No generic event framework needed. |
| UI | Keep native widgets, fresh backend action identities and explicit input fences; simplify only stable layout ownership. |
| Tools/tests | Keep original-source converters, real-command recordings, Python differential oracles and native image tests. Prefer one evidence index per feature over more wrapper scripts. Counts are coverage evidence, not proof of visual acceptance. |

The three rendering paths (workshop graph, offline compiled grid, live disclosed world) have different current requirements. Their existence alone is not a bug. Consolidate shared source/material ownership first; do not substitute an offline Unity performance number for live gallery performance or force live visibility changes through a static precompiled map.

## Acceptance and scope

First finish readable lighting plus independent visible/remembered/unseen checks and the exact black-pixel diagnosis. Then compare the same recorded small encounter and large gallery at the same resolution, renderer and wall mode. Include cold reveal, movement, quarter rotation, extinguished sources and shutdown while preparation is active. Check final displayed state against the consumed cursor and reject script errors. Existing tests that merely reproduced the old floor-diamond wall policy are not acceptance evidence for the corrected member policy.

No recommendation above licenses a backend rules rewrite, new art, blind normal smoothing, an ECS conversion, removal of subjective visibility, or a claim that all delivered geometry is physically certified. Official references were checked against the 4.7 documentation; no performance improvement was measured during this read-only review.
