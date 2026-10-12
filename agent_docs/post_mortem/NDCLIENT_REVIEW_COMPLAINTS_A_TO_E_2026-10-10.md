# NDClient review — only the user's complaints a–e

10 October 2026. **Read-only investigation; implementation is stopped.**

The entire complaint scope is the five passages labelled **a, b, c, d and e**
in the user's supplied a–e message, with their subsequent clarifications of those
same issues recorded below. This document contains no earlier migration
complaint ledger, historical postmortem, additional feature list or new plan.
Pygame and NeuroStudio source are inspected only to answer the comparisons
explicitly requested in those passages.

“Confirmed” below means visible in the current source or the identified existing
measurement. “Reported” preserves what the user observed. A likely cause is
labelled as an inference where the exact running frame has not been measured.
No fix is declared complete from source inspection alone.

## a — Shadows, relative scale, loading, recordings, tracks and flashing

### a.1 — Existing shadows appear to have been replaced by an invented system

**Complaint:** use the supplied shadows; explain why shadows and bodies contain
horizontal stripes instead of rendering correctly.

**Current source:** the modular character layer selection explicitly includes
the `Shadow` category. Fixed-creature layers use their authored component data.
The inspected actor path does not replace those images with a newly drawn
ellipse. For component-based sheets, the renderer can draw the source shadow
separately from the source body through the composition shader.

This distinguishes the **shadow artwork** from **how the renderer places and
combines it**. Original artwork can still look completely wrong when the renderer
incorrectly hides parts of it behind the floor. Finding the original shadow
image does not dismiss the complaint or prove its rendering is correct.

The horizontal stripes are addressed in d.2; they are not adequately explained
by saying “the source shadow is correct.”

Sources: [actor layer selection and component separation](/home/tommaso/Dev/NDClient/src/presentation/actors.ts:19),
[source component sampling](/home/tommaso/Dev/NDClient/src/rendering/surface-shaders.ts:248).

### a.2 — Characters are too small relative to the environment

**Complaint:** characters look half-size or even a quarter of the expected size;
equivalently, the environment looks oversized. Compare with Pygame. Do not
arbitrarily change character proportions.

The relevant quantity is the **size of the visible character relative to the
floor and props**. Making the entire scene larger with camera zoom cannot repair
an incorrect ratio between those asset families.

Pygame's character draw function explicitly converts character image coordinates
into the map's drawing units, then applies camera zoom. Its formula is:

`character drawing scale = map diamond width / rig reference width × camera zoom × authored character scale`

In the inspected data, the map diamond width is 128 and the rig reference width
is 64. The resulting conversion is 2 before camera zoom. These numbers describe
the coordinate convention used by this renderer; they are **not** a claim that
the grid is a square or that every visible character is 64 pixels tall.

The NDClient omission identified before implementation was stopped was this
character conversion. Omitting it while using the larger map convention makes
the character half as wide and half as tall relative to the environment. Its
visible area can therefore look roughly one quarter as large. This explains
the relation between the user's descriptions without inventing a different
body shape or blaming the source artwork.

The **current checkout already contains the earlier attempted correction**:
`actors.ts` computes `128 / rigInfo.TILE_W` and includes it in character scale.
Environment images use their authored `image.scale`; animated environment
images take their scale from the authored bank. Camera zoom is subsequently
applied to the registered image as a whole.

Consequently, the current source is not an untouched snapshot of the first
reported image. The omission and the already-present correction must not be
confused with proof that the complete scene now has the right proportions.
This read-only review makes no additional scaling change and claims no visual
acceptance. No source image needs to be resized merely to reconcile the renderer's
coordinate convention.

Sources: [Pygame character scale](/mnt/c/users/tommaso/documents/dev/dnd_engine/game_obsolete/animation_draw.py:662),
[Pygame grid and camera zoom](/mnt/c/users/tommaso/documents/dev/dnd_engine/game_obsolete/projection.py:11),
[rig reference](/home/tommaso/Dev/NDClient/authoring/catalog/rig.json),
[current character conversion](/home/tommaso/Dev/NDClient/src/presentation/actors.ts:61),
[environment bank](/home/tommaso/Dev/NDClient/src/presentation/environment.ts:39),
[image placement and common camera zoom](/home/tommaso/Dev/NDClient/src/rendering/registration.ts:69).

### a.3 — Loading freezes for approximately 15–40 seconds; switching is slow

**Reported:** initial loading takes roughly 15–40 seconds with a frozen/stuck
interface. Switching between recordings or operations also takes too long.

**Confirmed sequence in the client:** selecting an operation first prepares its
preceding state, then prepares the operation. `prepareOperation()` awaits each
scene patch in order. `prepareNext()` does not expose the operation as ready
until that preparation finishes. Scene preparation includes resource readiness
and GPU upload preparation. A prerecorded event file does not bypass these
client-side stages.

The resource store caches decoded images and tracks uploaded textures. However,
an operation still passes through the readiness machinery for its scene changes.
The installed Pixi Prepare queue resolves pending uploads when its queue drains.
An empty upload request with an empty queue resolves immediately; it is not
correct to claim that every call inherently incurs another frame of delay.

The timeline adds another concrete cost: its thumbnail function renders the
selected contribution and calls Pixi's `extract.canvas()`, which obtains the
rendered pixels for a DOM canvas. This can involve a synchronous GPU readback.
Scheduling it with `requestIdleCallback` does not make the work itself
nonblocking. The thumbnail scheduler checks `preparing` and `playing`, but
does not check the separate `filling` flag used while the next operation is
being prepared. Those activities can overlap.

An **existing, pre-stop** profile records initial readiness at 4.237 seconds and
an Anchored Spells operation switch at 39.668 seconds. That run used headless
software WebGL, not the user's GPU. It supports the existence of a large
client-side delay but cannot quantify the RTX 5090's execution time. No new
runtime benchmark was run for this document.

A subsequent read-only inspection of that same capture and its CPU profile makes
the timing more precise. Across the capture, 110 `prepareScene` calls accumulated
40.36 seconds, including 38.22 seconds in nested `uploadSources` waits. These
figures overlap and must not be added. The page's CPU samples attribute about
40.81 seconds to idle time and about 1.13 seconds to shader-program generation.
This does not describe a JavaScript calculation occupying the CPU for forty
seconds; much of the observed readiness delay is waiting in preparation. The
capture does not record enough GPU/queue detail to assign that wait to individual
uploads, scheduling gaps or GPU execution.

One `renderThumbnail` call separately took 11.61 seconds and began after the
recorded operation switch completed. It is an additional stall, not the cause
of all 39.668 seconds of that switch. In the installed Pixi WebGL implementation,
`extract.canvas()` reaches synchronous `gl.readPixels`, so a small thumbnail can
wait for rendering to finish. This capture times the whole thumbnail call rather
than isolating the readback. It does not establish the cause of a whole-machine
freeze on the user's hardware.

Sources for this timing distinction: [existing CPU profile](/home/tommaso/Dev/NDClient/.runtime/checks/loading-cpu.json),
[capture method](/home/tommaso/Dev/NDClient/.runtime/checks/loading-profile.mjs),
[installed Pixi readback](/home/tommaso/Dev/NDClient/node_modules/pixi.js/lib/rendering/renderers/gl/texture/GlTextureSystem.mjs:400).

The identified problem is client preparation and preview work delaying readiness,
with an expensive render path described in e. It is not justified to blame the
server or filesystem for the reported freeze from this evidence. Exact timing
shares on the user's machine are not established by the available profile.

Sources: [operation selection](/home/tommaso/Dev/NDClient/src/studio/workspace.ts:78),
[operation readiness](/home/tommaso/Dev/NDClient/src/app/playback.ts:159),
[sequential patch preparation](/home/tommaso/Dev/NDClient/src/presentation/playback.ts:17),
[resource cache and upload preparation](/home/tommaso/Dev/NDClient/src/rendering/resources.ts:35),
[thumbnail scheduling](/home/tommaso/Dev/NDClient/src/studio/timeline.ts:29),
[rendering and extraction](/home/tommaso/Dev/NDClient/src/rendering/composition.ts:778),
[existing profile](/home/tommaso/Dev/NDClient/.runtime/checks/loading-profile.json).

### a.4 — Nearly everything appears to be “The Lantern Crypt”

The current recording index contains 17 entries, eight of which have exactly
the title **The Lantern Crypt**. This confirms a real source of indistinguishable
selection labels. It does not prove that all eight event streams are identical.

The current selector already contains a pre-stop change that prefixes duplicate
titles with the recording directory's readable name. That distinguishes the
entries, but it does not by itself change their maps or demonstrate that the
examples are sufficiently varied. The complaint must not be declared resolved
merely because labels are different.

Sources: [recording index](/home/tommaso/Dev/NDClient/.runtime/recordings/index.json),
[duplicate-title handling](/home/tommaso/Dev/NDClient/src/studio/workspace.ts:136).

### a.5 — Tracks appear only after Play and disappear/change when playback ends

Two different behaviors need to be named clearly:

- **Track availability:** channels are built from the prepared active operation.
  They depend on that operation becoming available, not merely on receiving the
  recording file. The current code includes a pre-stop change to prepare the
  first operation while paused, including when its record arrives after initial
  scene setup.
- **Changing tracks:** Studio can play through successive operations. When the
  active operation changes, its displayed tracks change too. This is an operation
  boundary, not inherently a switch between characters. The current code includes
  a Stream/Selected operation control and stopping at the recording's end.

The current workspace retains inspected tracks during intermediate operation
preparation and replaces them when the next active operation is ready. Selecting
a different recording explicitly clears them while that recording loads.
These are source descriptions of the already-present changes, not proof that
the user's complete interaction now behaves correctly.

**Thumbnails are a separate problem:** the scheduler refuses to generate them
while playback is marked playing. A track may therefore exist while its preview
bed is empty. A playback flag left active at the end also prevents preview work.
Current end handling attempts to clear that flag; visual acceptance is unproven.

Sources: [paused initial preparation](/home/tommaso/Dev/NDClient/src/app/main.ts:64),
[end-of-operation behavior](/home/tommaso/Dev/NDClient/src/app/playback.ts:192),
[workspace track replacement](/home/tommaso/Dev/NDClient/src/studio/workspace.ts:160),
[thumbnail guard](/home/tommaso/Dev/NDClient/src/studio/timeline.ts:29).

### a.6 — Dragging the map/timeline separator makes the map flash

The divider changes the map area's dimensions continuously. A canvas resize
clears the drawing surface; if that clear is displayed before the next scene
draw, the user sees a flash.

The current code already contains the pre-stop change that records a pending
resize and performs the resize and scene draw in the same animation callback.
It resizes existing intermediate targets rather than recreating the whole target
set on each divider movement. This explains the intended correction precisely;
it is not a claim that the interaction has passed a full visual check.

Sources: [divider](/home/tommaso/Dev/NDClient/src/studio/workspace.ts:128),
[resize and draw scheduling](/home/tommaso/Dev/NDClient/src/app/main.ts:118),
[target resizing](/home/tommaso/Dev/NDClient/src/rendering/composition.ts:739).

## b — The explanation of scale and attachment coordinates was ambiguous

The previous phrase about “0.5” and “original 20 attachment coordinates” did not
identify an object or a meaningful transformation. It is withdrawn as an
explanation. No claim about “20 attachment coordinates” is needed to explain
the character/environment mismatch.

An **attachment position** is a point on a character animation frame—for example,
where its hand holds a weapon. It is not an environment asset. If the renderer
converts that character frame into map drawing units, it must convert its
attachment positions by the same factor, otherwise the weapon will leave the
hand. This is coordinate consistency, not an independent cosmetic resize.

Pygame's `0.5` default camera zoom is separate: it scales the entire projected
scene. It must not be described as an instruction to halve only the character,
only the environment, or only the character's attachments.

The error in communication was mixing these different transformations while
the user was asking about their visible result. Continuing implementation during
that unresolved misunderstanding was inappropriate. This review changes only
this document.

## c — Tracks, previews, FPS, NeuroStudio and clear terminology

### c.1 — Every rendering contribution needs a track and its own preview

The requirement includes body layers, added media, effects, shaders and tint
changes. Their behavior must come from the authored data and functional rendering
methods, and Studio must expose what those methods actually render and when.

The current channel model starts from compiled operation tracks and adds certain
condition, item-effect and spatial drawable contributions. Body source layers
can be expanded. This does **not** establish coverage of every transformation:
an appearance change can alter an existing actor without creating a new drawable
occurrence. For example, `conditionAppearance()` changes the actor, while the
condition-channel discovery follows `conditionAnimation` occurrences. Also,
`spells.ts` explicitly reports finite body-material envelopes as unconnected.
That is a missing production consumer, not merely an absent preview picture.

The required preview meaning is concrete:

| Contribution | What its preview must show |
| --- | --- |
| Body or equipment layer | The actual authored source layer and relevant animation samples. |
| Added image/media effect | The actual selected effect frames and their timing. |
| Shader, tint or material treatment | The affected body/media rendered with that treatment. A shader need not have a PNG of its own. |
| Other authored rendering contribution | Its actual visible result and timing, not an empty placeholder bar. |

Current previews are generated through production scene sampling and thumbnail
rendering. They are not cached across every timeline rebuild: rebuilding a row
replaces its preview canvases and queues visible thumbnails again. The scheduler
constraints in a.5 explain why known artwork can still produce blank beds.

The old NeuroStudio source has explicit actor-layer and projectile-frame preview
helpers called when drawing its tracks. That is substantive existing functionality
to compare with, not just a color/style reference.

Sources: [channel model](/home/tommaso/Dev/NDClient/src/studio/channels.ts:14),
[condition channels](/home/tommaso/Dev/NDClient/src/studio/channels.ts:65),
[actor appearance changes](/home/tommaso/Dev/NDClient/src/presentation/actors.ts:68),
[missing finite material consumer](/home/tommaso/Dev/NDClient/src/presentation/spells.ts:157),
[preview canvas lifecycle](/home/tommaso/Dev/NDClient/src/studio/timeline.ts:50),
[old Studio preview calls](/home/tommaso/Dev/NeuroClient/app/src/ui/SpellStudioPreview.ts:2197).

### c.2 — A visible FPS counter belongs at the top right

This is recorded as an explicit requested change, not implemented in this review.
The current counter starts hidden and is toggled by F3. It reports animation-frame
cadence, frame interval, CPU render-submission duration and draw count. Its CPU
submission measurement is not GPU execution time, so it cannot explain 99% GPU
utilization by itself.

Source: [current counter and frame loop](/home/tommaso/Dev/NDClient/src/app/main.ts:111).

### c.3 — Compare the actual old NeuroStudio renderer setup

| Concern | Old source inspected | Current NDClient source inspected |
| --- | --- | --- |
| Character texture sampling | Shared sprite sources use `scaleMode = 'nearest'`. | Colour sources are configured linear, and the surface shader additionally performs explicit four-sample interpolation. |
| Character pixel placement | Body/equipment sprites use `roundPixels = true`. | Custom mesh positions follow fractional registration/camera coordinates. |
| Screen density | Shared setup specifies device-pixel resolution and `autoDensity: true`. | Renderer uses device-pixel resolution; CSS sizes the displayed canvas. This difference alone is not proof of a bug. |
| Studio antialiasing | `StudioPixiSurface` initializes with antialiasing enabled. | NDClient initializes its WebGL renderer with antialiasing disabled and uses intermediate targets. Antialiasing and texture sampling are different controls. |
| Resizing | Old Studio schedules a resize in an animation frame. | Current NDClient now queues resizing alongside drawing, following the pre-stop edit described in a.6. |

These are confirmed differences. They do not justify describing the old setup
as “smooth bilinear filtering”: its inspected character sources explicitly use
nearest sampling. Nor do they prove that one settings toggle resolves all the
current artifacts. The new custom shader path must be considered separately.

Sources: [old sampling](/home/tommaso/Dev/NeuroClient/app/src/render/SpriteAssetRegistry.ts:35),
[old pixel placement](/home/tommaso/Dev/NeuroClient/app/src/render/AnimatedEntity.ts:730),
[old density settings](/home/tommaso/Dev/NeuroClient/app/src/render/pixiRendering.ts:58),
[old Studio initialization](/home/tommaso/Dev/NeuroClient/app/src/ui/studio/StudioPixiSurface.ts:77),
[new initialization](/home/tommaso/Dev/NDClient/src/rendering/composition.ts:102),
[new source sampling settings](/home/tommaso/Dev/NDClient/src/rendering/resources.ts:35).

### c.4 — Use precise terms and resolve understanding before changing code

| Term | Meaning in this review |
| --- | --- |
| Isometric grid cell | A projected diamond on the ground, not a square image frame. |
| Character sprite frame | The rectangular part of a sheet containing one pose, including transparent padding. |
| Environment sprite | The image for a floor, wall or prop, positioned using its authored data. |
| Relative scale | How large the visible character is compared with that environment. |
| Camera zoom | One common enlargement/reduction of the whole projected scene. |
| Browser canvas | The HTML drawing element displaying the scene; not the name for a character frame. |

The artwork should retain its intended relationship. An image frame's width is
not the width of a ground cell, and its transparent padding is not the size of
the visible character. Numeric frame dimensions do not answer a question about
relative visual size unless the conversion and displayed result are explained.

The complaint record must stay limited to a–e. Reading code and writing this
explanation are authorized; implementing the recorded requests is not.

## d — Remove custom interpolation; identify the stripes separately

### d.1 — The custom interpolation exists and bypasses ordinary sampler control

`surface-shaders.ts::appearance()` calls `appearanceAt()` four times and mixes
the results. Each call fetches a source pixel and can compose character
components, apply material/palette treatment and convert color. This is manual
colour interpolation in our shader, even though the renderer uses Pixi.

Changing only Pixi's texture `scaleMode` cannot remove these explicit
`texelFetch` and mixing operations. The user's instruction is to remove this
custom interpolation path. It remains in the checkout solely because implementation
is stopped. This review does not silently substitute another filter.

Source: [custom interpolation](/home/tommaso/Dev/NDClient/src/rendering/surface-shaders.ts:248).

### d.2 — Were the horizontal stripes simply interpolation?

**That is not established, and there is a separate concrete depth problem.**

The earlier narrow reproduction with original floor and character artwork found
the floor hiding alternating rows of the nearby body/shadow. The floor's sampled
depth and the continuously calculated contact depth did not consistently describe
the same surface. A prior edit attempted to reconcile them for ordinary floors.
That limited result is not proof that all character, shadow or body poses now work.

The current source still contains an inconsistency for contributions drawn on
that floor: ground deposits reuse the floor image and geometry, but are tagged
`ground`; the correction applies only to entries tagged `floor`. Consequently
the floor can use the corrected continuous depth while the deposit uses the
uncorrected sampled depth, and they compete in the same visibility test.

This mismatch is confirmed in source. It supports a depth-ordering explanation
for stripes near the surface; it is not a pixel-by-pixel diagnosis of every body
or shadow in the reported view. The current read-only review did not rerun the
app or measure the exact reported frame.

**Colour filtering** decides how nearby image pixels are sampled. **Depth
ordering** decides whether the floor hides a character/shadow pixel at all.
They are different operations. The existence of the custom filter does not make
it the sole cause, and removing it cannot honestly be promised to resolve this
depth inconsistency.

Sources: [shader depth calculation and floor-only correction](/home/tommaso/Dev/NDClient/src/rendering/surface-shaders.ts:318),
[floor flag assignment](/home/tommaso/Dev/NDClient/src/rendering/composition.ts:239),
[floor geometry reused for ground contributions](/home/tommaso/Dev/NDClient/src/presentation/residue-media.ts:40).

## e — GPU utilization during zoom and the actual cache/render path

**Reported:** zooming the small prerecorded scene drives GPU utilization to
about 99%. The user questions whether anything is cached and why this workload
is so expensive relative to much more demanding games.

The source shows that caches exist. It also shows substantial repeated rendering
work that those caches do not avoid. The complaint is valid without the specific
inference that caching is completely absent.

### e.1 — Work triggered by zoom

1. Wheel input updates the camera zoom/pan across successive animation frames.
   That handler does not decode artwork, request server events or resize source
   images.
2. The drawing key contains zoom and pan. Each changed camera sample triggers
   scene rendering, even while the recording is paused. Unchanged idle frames
   can skip drawing.
3. The renderer sorts contributors, determines visible bounds, and checks its
   camera-dependent overlap partition.
4. It draws opaque content, copies that color to an intermediate image, resolves
   transparent overlaps, then draws the composed result to the screen.
5. If wall cutaway is enabled, its separate floor-receiver image is also redrawn
   when zoom invalidates that image's camera-dependent cache.

Sources: [wheel input](/home/tommaso/Dev/NDClient/src/app/camera.ts:20),
[drawing key](/home/tommaso/Dev/NDClient/src/app/main.ts:120),
[composition](/home/tommaso/Dev/NDClient/src/rendering/composition.ts:653),
[conditional cutaway redraw](/home/tommaso/Dev/NDClient/src/rendering/composition.ts:624).

### e.2 — Why a redraw can require much more than one sprite draw

The custom compositor groups overlapping contributors and repeatedly draws them
to select successive depths and blend the selected pixels. This is depth peeling.
For each selected depth it draws the contributors once for selection and again
for blending. The loop runs for an overlap estimate calculated from bounding
rectangles and depth intervals, not an exact count of visible fragments at every
pixel. It has no early exit based on an empty GPU result.

The transparent candidate list includes ordinary floor, wall and character
layers as well as effects. Opaque pixels can be rejected in the shader, but
these contributors are nevertheless submitted so their non-opaque parts can be
handled. Bounding rectangles also contain transparent space. Therefore the
pass estimate and submissions can exceed the work actually needed for the
visible scene.

The renderer has culling, scissor rectangles, instancing and a direct path for
certain nonoverlapping or constant-depth groups. Those reduce some work. They
do not eliminate the repeated shading. The region splitter's cost function counts
submissions; it does not weight screen area or material/shader expense.

The same surface shader calls the manual four-sample colour treatment before
ordinary opacity rejection and before testing visibility against the opaque
result. Its depth-selection pass shares that entry point. There is no dedicated
cheap coverage-only shader path there. The GPU compiler's exact optimization
is not measured, but the source clearly requests far more than a simple cached
sprite transform and draw.

This is the main structural performance concern found in the zoom path. The
custom interpolation adds cost within it. Removing that interpolation alone is
not a demonstrated complete performance solution.

Sources: [candidate list and repeated selection/blending](/home/tommaso/Dev/NDClient/src/rendering/composition.ts:700),
[overlap estimate and partition cost](/home/tommaso/Dev/NDClient/src/rendering/overlap-regions.ts:9),
[shader work before rejection](/home/tommaso/Dev/NDClient/src/rendering/surface-shaders.ts:291),
[depth-selection pass](/home/tommaso/Dev/NDClient/src/rendering/surface-shaders.ts:415).

### e.3 — What is cached and what still repeats

| Item | Current behavior during zoom |
| --- | --- |
| Decoded images | Retained source promises are reused; zoom does not clear this cache. Sources can be released when no scene references them. |
| Uploaded textures | Already-uploaded sources are tracked and reused until unload/context loss. |
| Prepared scene and source coverage | Existing contributors and coverage data are reused. |
| Settled deposit density | Its update depends on time/state/context changes, not camera zoom alone. |
| Screen overlap partition | Zoom can change raster bounds and invalidate the cached partition. |
| Cutaway receiver image | Its key includes zoom/pan, so it must be redrawn when enabled and the view changes. |
| Final scene image | The last result avoids idle redraws, but the compositor runs again for each changed zoom sample. |
| Intermediate render targets | Reused during zoom; repeatedly read and written by the passes. They are not recreated by the wheel handler. |

The targets use floating-point colour and selection attachments. Repeated passes
over these screen-sized images add memory traffic. Their mere allocation is not
proof of the measured bottleneck, and no arbitrary target-size budget is added
by this review.

Sources: [source cache and lifecycle](/home/tommaso/Dev/NDClient/src/rendering/resources.ts:35),
[deposit update reuse](/home/tommaso/Dev/NDClient/src/rendering/residue-fields.ts:70),
[overlap cache](/home/tommaso/Dev/NDClient/src/rendering/composition.ts:704),
[intermediate target formats](/home/tommaso/Dev/NDClient/src/rendering/composition.ts:38).

### e.4 — What can be concluded without pretending to have a GPU trace

Loading cached images and redrawing cached images are different costs. Redrawing
after zoom is expected; repeatedly solving transparency across many contributors
can make that redraw unnecessarily expensive. This is why “textures are cached”
does not answer the user's performance complaint.

The code confirms repeated composition and custom sampling. The user's report
establishes the unacceptable utilization they observed. The exact share of GPU
time belonging to each pass, and whether thumbnail extraction overlapped that
particular gesture, are not captured by the available measurements. Short CPU
submission times do not prove that GPU execution is cheap.

No claim is made that 99% utilization is inevitable, that the hardware is
inadequate, or that the prerecorded workload excuses this implementation. No
new benchmark, runtime change, asset change or backend change was made for this
review. Only this Markdown was created.


### e.5 — Layer ordering and the boundary between Pixi and custom rendering

**User clarification:** ordinary rendering should use the chosen Pixi scene
architecture and authored layers, with sorting within the appropriate groups.
The availability of world geometry, depth and normals does not justify making
every floor, shadow and body compete through a general per-pixel depth solver.
The currently reported flat-floor scenes do not need that general solution to
establish that a character or its ground shadow appears over its supporting floor.

**Confirmed in NDClient:** `createSceneRenderer` creates a real Pixi Application
and uses Pixi textures, meshes, shaders and render targets. However, ordinary
occurrences become custom meshes. `renderScene` repeatedly empties and fills a
single scratch container for separately orchestrated passes. It selects opaque
depth, copies the result, and selects/blends successive transparent depths.
The labels `floor`, `ground`, `shadow`, `behind_body`, `body`, `attachment` and
`effect` determine semantic rank, which resolves equal-depth ties; calculated
fragment depth remains the primary visibility decision. This is not a persistent
layered scene whose ordinary visibility is determined by Pixi child ordering.

There are also direct WebGL calls: scissor state in composition and framebuffer
attachment readback in picking. Their presence does not by itself prove a GL
state-corruption bug. The established problem is the breadth and repeated work
of the custom compositor. Custom meshes/shaders themselves are supported Pixi
features and do not inherently require abandoning Pixi.

**Comparison:** old NeuroClient explicitly creates floor, floor-overlay and world
containers; the world container sorts children. Its character renderer inserts
AnimatedSprite children in authored slot order. This establishes an existing
layering implementation to learn from. It does not certify that every old
ordering rule handles all new elevation or intersecting-effect cases unchanged.

**Terminology and architectural direction:** one browser canvas can contain the
whole Pixi scene. Containers and RenderLayers organize drawing within it; they
are not separate HTML canvases. World X/Y/Z determines placement and spatial
ordering, while authored compositing layers establish relationships such as a
floor below its own deposits/shadows and an actor's ordered component layers.
At different elevations, those relationships must refer to the correct support
surface; a blanket rule drawing every floor before every actor would be wrong
for bridges and overhangs. Depth/normal data can still support lighting and
specific intersecting effects without requiring global transparency peeling for
ordinary sprites. Merely adding containers around the current repeated passes
would not remove that work.

This records the user's architectural correction and the inspected implementation;
it is not an implementation plan or authorization to resume code changes.

Sources: [current Pixi initialization](/home/tommaso/Dev/NDClient/src/rendering/composition.ts:102),
[custom pass orchestration](/home/tommaso/Dev/NDClient/src/rendering/composition.ts:653),
[fragment depth and semantic rank](/home/tommaso/Dev/NDClient/src/rendering/surface-shaders.ts:382),
[old NeuroClient scene layers](/home/tommaso/Dev/NeuroClient/app/src/main.ts:158),
[old character slot ordering](/home/tommaso/Dev/NeuroClient/app/src/render/AnimatedEntity.ts:878),
[Pixi Container documentation](https://pixijs.com/8.x/guides/components/scene-objects/container),
[Pixi RenderLayers documentation](https://pixijs.com/8.x/guides/concepts/render-layers),
[Pixi custom Mesh documentation](https://pixijs.com/8.x/guides/components/scene-objects/mesh).
