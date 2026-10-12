OUR OBJECTIVE IS A COMPLETE IMPLEMENTATION

# NDClient renderer — Pixi scene architecture and recovery plan · v2

10 October 2026 · revision 2. Complete this plan update and review, then resume the agreed implementation without another approval step.

This is the active renderer chapter of the [general implementation plan](/mnt/c/users/tommaso/documents/dev/dnd_engine/agent_docs/NDCLIENT_IMPLEMENTATION_PLAN_COMPLETE_2026-10-10_v2.md). It preserves the full client feature scope while correcting how it is rendered. The [previous renderer plan](/home/tommaso/Dev/NDClient/agent_docs/archive/ndclient-plans/2026-10-10-before-pixi-v2/NDCLIENT_PIXI_RENDERER_PLAN_2026-10-10.md) and [previous general plan](/home/tommaso/Dev/NDClient/agent_docs/archive/ndclient-plans/2026-10-10-before-pixi-v2/NDCLIENT_IMPLEMENTATION_PLAN_COMPLETE_2026-10-08.md) are archived unchanged as evidence, not execution instructions. This revision removes the mandatory custom CPU source-mask picker: use Pixi interaction and authored hit areas first. Backend work and another asset-preparation phase remain outside the agreed client scope.

**Latest human direction:** begin with ordinary Pixi layers, camera-aware ordering and correct elevation/support placement. Use supplied depth/normals principally for lighting and the authored spells. Do not build a general solution for hypothetical isometric intersections now. If an actual case exposes an ordering problem, record it and discuss the smallest necessary correction while continuing other agreed work.

## 1. What led to the wrong renderer

The [archived general plan](/home/tommaso/Dev/NDClient/agent_docs/archive/ndclient-plans/2026-10-10-before-pixi-v2/NDCLIENT_IMPLEMENTATION_PLAN_COMPLETE_2026-10-08.md) and its engine copy were identical when inspected. The references and line numbers below refer to that archived version. The following were actual plan prescriptions, not requirements the user independently requested. The active general plan now removes those prescriptions.

| Old location | Prescription or omission | Consequence | Replacement here |
|---|---|---|---|
| §0.0, lines 160–166 | A common depth/material composition path and “one comparable depth space” became central principles. | Shared world coordinates were conflated with mandatory depth-based visibility for all artwork. | Share coordinates and presentation functions; ordinary visibility comes from scene layers and authored order. |
| §6, lines 1457–1476 | Preserve floor-below-body behavior “on the GPU”, using contact-depth continuation, receiver patches and half-space tests; semantic order only breaks physical-depth ties. | A known layer relationship became a numerical competition between floor and character pixels. This enabled the striped/clipped feet and shadows. | Draw a supporting floor and its coverings below their supported body; do not compare their depths to rediscover that relation. |
| §6, line 1572 | Ordinary `Sprite` was limited to UI and already-resolved flat composites. | Nearly all world occurrences became custom meshes. Pixi's normal scene model ceased to be the foundation. | Sprite/Container and their ordinary order are the default; a Mesh or Filter is selected for a specific material/effect need. |
| §6, lines 1591–1595 | Physical fragment depth primary; local depth peeling for crossing contributors; conservative finite peel count. | The implementation passed ordinary tiles, bodies and shadows through a general transparency solver. “Local” did not stop ordinary scenes becoming expensive. | Remove general peeling and its overlap-region dispatcher. No replacement generic crossing solver is part of this work. |
| §4.7, around line 592 | Gather the next group's state changes before readiness. | Encouraged preparing every patch before an operation became usable. | Preserve a coherent displayed sample; separate metadata readiness from GPU readiness and prepare distinct needed sources once. |
| §8.3, line 2202 | Shared production sampling for previews. | Implemented by temporarily changing live renderer state and performing synchronous GPU extraction. The plan did not require that mechanism. | Independent preview display handles, shared sampling/material functions and textures, GPU-resident thumbnail beds. |
| §7.3, around line 1944 | Native sampling policy for pixel art and smooth UI. | Manual four-sample colour interpolation was an implementation choice, not a plan requirement. | Remove it. Use Pixi texture sampling and source-appropriate settings. |
| §§3.2 and 11.3 | Keep input responsive; camera-only changes update transforms. | The implementation nevertheless rebuilt camera-dependent composition and performed blocking preview readbacks. | Retain these requirements and implement their actual execution boundary. |

The corrections also cover repeated depth-first prescriptions in §2.1, §6, §10 N1, renderer rows R02/R03/R07/R09/R10, the migration/parity commentary and §16 of the archived general plan. The active general plan incorporates the correction. Historical entries describing GPU picking or peeling do not require retaining those implementations.

**Responsibility:** the plan itself steered implementation into an overgeneralized renderer. The broad ordinary-sprite participation, manual interpolation and synchronous thumbnail extraction added further cost and failures. “The plan said so” does not justify those choices or transfer responsibility to the user.

### Evidence limits

The [current a–e investigation](NDCLIENT_REVIEW_COMPLAINTS_A_TO_E_2026-10-10.md) records the exact complaints, code and existing measurements. Its loading capture used software WebGL: it is not a 5090 benchmark. The 39.7-second operation switch and subsequent 11.6-second thumbnail call are separate intervals. No current evidence apportions the user's reported GPU percentage to individual passes or proves the cause of a whole-system freeze.

## 2. Boundaries and completion meaning

Work stays in NDClient. Engine, service, SDK, archived Pygame, old NeuroClient, old editor, supplier assets and original authoring are read-only references. Keep the current package baseline, Pixi 8.22.0/WebGL2. Do not upgrade it, rebuild the repository, recopy assets, re-export artwork, regenerate the SDK or introduce new wire types.

Keep the real recorded-event path, source recipes, causal timing, materials, conditions, equipment, particles, deposits, UI and Studio capabilities. This plan changes how those contributions are drawn; it does not reduce the product to a sprite demo.

No geometric ordering DAG, general polygon-crossing classifier, local/global OIT framework, depth-peel region optimizer, new renderer backend, generic ECS framework, plugin system, or class per actor/spell is planned. No new packet size, memory, atlas, FPS, concurrency or certification quota is invented. Normal source constants and observed measurements still have meaning.

Ordinary renderer completion means the known production cases work with correct assets, proportions, layers and controls, and actual client stalls have been addressed. It does not mean every possible arrangement of intersecting transparent volumes has been solved. A demonstrated unsupported arrangement is recorded with the exact case and source; it is not silently hidden or automatically promoted into infrastructure work.

## 3. Retain the functional architecture

The shared path remains:

`current SDK records → existing reduction → compileOperation → source/time sampling → derived occurrences → Pixi display updates → scene render`

Play supplies live records; Studio supplies records previously captured from the actual server. No synthetic outcomes, alternate Studio compiler, parallel world schema or new gameplay inference is introduced.

| Existing owner | Keep / change |
|---|---|
| `src/session/`, `src/player/` | Keep transport consumption, recorded history, subjective reduction and latest/displayed separation. No unrelated refactor. |
| `src/presentation/compiler.ts`, `timeline.ts`, source samplers | Keep causal groups, absolute-time sampling, phases, origins, commits and retained tails. Separate GPU handle operations from sampling where currently coupled. |
| `SpriteOccurrence`, `Registration`, `ScenePatch` | Keep source/owner identity, contact, pivot, size, scale, pose/frame, role, sibling order, support, materials and dependencies. Extend only derived client fields genuinely needed for existing layer placement; no second serialized scene format. |
| `src/rendering/resources.ts` | Keep URL/kind source reuse, lossless packet decoding, source leases and context-generation handling. Separate resource readiness from scene construction. |
| `src/rendering/composition.ts` | Replace universal mesh creation, scratch-container pass orchestration, generic peeling, the compositor-dependent ordinary picking pass and live-state-mutating thumbnail extraction. Preserve useful selection/calibration/material functions in their specific consumers. |
| `src/rendering/surface-shaders.ts` | Extract actual material, geometry decode, normal and light operations. Delete custom colour interpolation and universal fragment-depth visibility. Do not discard authored shader capabilities with the old dispatcher. |
| `src/studio/channels.ts` | Derive tracks/layers from compiled presentation and source metadata, not `PreparedSprite` GPU objects. |

Use ordinary functions and passive records. Pixi Container/Sprite/Mesh/Texture instances are external renderer handles, not domain entities. Keep explicit owners; do not replace the current code with a new service/registry hierarchy.

A display object has one parent. Live and preview views use separate display handles built/updated by the same functions. They share source records, TextureSources/frame views and shader programs. Do not reparent a live actor into the timeline or make every historical moment own another complete scene tree.

## 4. One canvas, a persistent Pixi scene

The application uses a single Pixi Application and persistent display objects. The browser canvas is the output surface; it is not an image frame or grid cell. Containers/RenderLayers are scene organization inside that canvas, not one canvas per elevation.

```text
app.stage
  mapViewport                 screen-space clip for the map pane
    worldRoot                 shared pan and uniform zoom
      planarGround            background terrain at its actual supports
      planarGroundDetails     their deposits, grid/target feedback and shadows
      spatialWorld            raised assemblies, walls, props, actors, world media
        support/assembly units and ordered actor component containers
      worldAnnotations        only genuinely non-occluding world annotations
  screenFeedback              damage text / labels / screen UI where appropriate
  timelinePreviewViewport     visible Studio preview beds, clipped to timeline
```

This is an ownership diagram, not a rule to put every floor or every effect in a global pass. Raised support assemblies and their own ground detail belong inside `spatialWorld`; their relationship to lower-world objects is not lost by placing all floors at the bottom. Body-adjacent effects belong with their actor/source order, not automatically on top of the entire map.

Use ordinary child order and `sortableChildren`/`zIndex` for spatial units. `RenderLayer` is available where logical parenting and draw order must differ, such as a flying body's shadow remaining attached to a ground receiver. Reattach deliberately when an object is removed/reintroduced. Do not create a RenderGroup for each tile or each elevation: at most the meaningful world/independent UI roots need that optimization, and Pixi already owns the root render instructions.

An update changes existing transforms, textures, visibility, material values or affected membership. Pan/zoom does not remove and re-add the scene. No custom renderer plugin or raw framebuffer/scissor-state manipulation is required for ordinary drawing.

## 5. Coordinates, original proportions and camera

Keep the existing calibrated projection and all four quarter rotations. With rotated ground coordinates `(X,Z)` and elevation `H`:

`screenLocalX = 64*(X-Z)`

`screenLocalY = 32*(X+Z) - 64*H`

These are projected grid distances. They are not the width/height of a character image or a square floor-image file. Camera pan and one uniform zoom are then applied by `worldRoot`.

For the source families discussed in the current review, the accepted relative proportion is environment ×1 and ordinary character ×2 before common zoom, equivalently environment ×0.5 and character ×1. Keep the current source conversion `128 / rig.TILE_W` and each environment resource's authored scale; do not add another ×2 or substitute PNG dimensions for that conversion. Animal enlargement, ancestry size and actual size effects remain their explicit authored adjustments. No cosmetic Sorcerer/Barbarian body overrides are invented.

Apply the source pivot, physical mount, source scale and socket conversion exactly once. Atlas origins select pixels; they do not move the object. A frame rectangle is only a source region. Use trim/original-frame data if actually supplied. Do not stretch an image independently on X/Y, change the camera slope, fit the body to a collision tile, or invent offsets to make incompatible art join.

Pan and pointer-centred zoom update the common transform. Quarter rotation selects the authored view banks and recomputes contact order; it does not manufacture rotated artwork or create another coloured copy of every sheet. Resize applies the new pane size/clip and renders the same scene in one scheduled frame. Preserve pan/zoom unless the user explicitly invokes Fit.

### Native image sampling

Remove the manual four-tap interpolation and any final-image resampling shader introduced for ordinary scaling. Use Pixi TextureSource/TextureStyle sampling: nearest for the existing pixel-art selection, linear for selected smooth icons/portraits; numeric depth/normal/ownership data stays raw nearest with no colour conversion or averaged mipmaps. Custom material shaders use the selected normal colour sampler rather than reimplementing it.

Restore the old source registration and accepted camera behaviour at the same world scale. Do not confuse canvas antialiasing with texture filtering. Avoid independent rounding that separates a body from its shadow or equipment. Where pixel snapping is used, apply the same policy to the complete composed object, with no change to world contact/order. Fractional zoom cannot guarantee both perfectly crisp integer-sized pixels and perfectly smooth resampling; this is a sampling trade-off, not permission to add another interpolation algorithm. Report any remaining visible difference in the actual app before changing the art policy.

## 6. Basic layer and elevation ordering

Keep three different meanings explicit: **physical height**, **support identity**, and **draw phase**. A Z-grid name is not a height; a high composition phase is not an elevated floor; two surfaces with equal height are not necessarily the same support. Current native data supplies one playable support per XY. Multiple visual pieces at different elevations remain valid; this phase does not invent independently walkable stacked floors.

### Flat support

For an ordinary connected floor region, draw its floor tops first, then its receiving deposits/ground materials, grid/path/AoE feedback, contact shadows, and spatial objects. Source-specific exceptions within the ground details retain their existing authored order. A foreground floor tile must not paint over another tile's supported feet, corpse, table legs or shadow. Do not add retaining/side components along same-height internal joins; separate top/side coverage only where the source supplies those components or masks. Do not invent a new image-splitting task or erase source pixels to conceal incorrect placement.

### Spatial order

Recover the existing painter semantics rather than inventing a numerical height formula. `game_obsolete/projection.py:painter_key` separates low planar ground from raised terrain and spatial items, uses camera-oriented ground contact, and puts boundary structures at their actual edge contact. Adapt that small semantic calculation to current passive records; do not copy its CPU pixel partitioner or obsolete imports.

Within a spatial group, sort back-to-front by the projected **ground contact with elevation excluded from the sorting projection**, then its lateral contact tie, then authored local phase/direction/sibling order, then stable identity. Use boundary-edge contact for a wall/door; a sprite rectangle's bottom is not its physical contact. The sprite remains mounted at its declared owner contact and registered pivot; the edge contact changes only the sort key. This sorting coordinate affects drawing order only. The actual sprite position still includes full `H`.

Stable identities settle otherwise equivalent ordering, not a known contradictory front/back relation. Recalculate order on a relevant contact, membership, support, assembly/view change; pan and uniform zoom preserve that order. Do not reorder by texture to improve batching when that would change visibility.

### Raised areas, stairs and enclosing geometry

Build the current source-supported raised area from its real support tops, retaining faces, corners, authored stair flight and landings. Preserve family compatibility, physical mounts, per-view contacts and supplied role masks. Keep floor/detail/body relationships local to their supporting area or source assembly. A raised assembly participates in spatial ordering with lower-world objects; do not put every higher elevation after every lower object globally.

Use the existing support/assembly grouping and source contact ordering as the initial structure. The rule “this body's support and its ground details draw below this body” is an explicit composition relationship, not a depth epsilon or sampled floor/body competition. Preserve the separately ordered cliff/rim and wall/door members. Do not merge a complete room, actors and all its walls into one immutable cached bitmap.

For stairs, use the installed lower/middle/upper contact coordinates and current support elevations. Moving bodies sample the already authored contacts. Whole-flight artwork retains its registration; no fitted ramp or stretched cliff. On jump/flight, body and ground-shadow placement separate according to the source recipe and displayed motion; landing restores the actual support association.

Start from the real enclosed raised example and the current dungeon. Upper/lower floor materials must make elevation legible. No open-sided demonstration platforms or guessed wall/door pairing. The complete scene's legitimate unknown regions must not be enclosed by invented walls.

**Deliberate limit:** these basic rules are not claimed to solve arbitrary intersecting bridges, cyclic painter ordering or every large-sprite overlap. Do not prepare a geometric dependency solver now. If one of the actual supported scenes fails, preserve the case, identify the responsible source/group/order and discuss the local correction. Continue unrelated known work. Partial stair disclosure retains the user's earlier explicit deferral: record an observed failure without making its solution a prerequisite. No new stacked-playable-floor support is added.

## 7. Environment and character contributions

| Family | Required consumer behaviour |
|---|---|
| Floors, cliffs, stairs, corners | Native support/height plus installed source contacts and roles. Separate visible retaining faces from planar tops. Preserve complete compatible enclosures. |
| Walls, doors, windows, hatches | Use current family/parent/insert/leaf associations, physical edge, capture-camera crosswalk, pose offset and frame contact. Preserve apertures and source sibling order. Do not emit a solid wall behind its own opening. |
| Animated/destructible props and devices | Select colour and companions on the same authored frame clock; cold open/broken/activated state selects the correct endpoint. Preserve attachments and visible remnants independently of native interaction lifetime. |
| Modular actors | Ordered body/shadow/equipment/Magic/Effect layers from `slot_order`, facing and source clip. Hidden slots, palette/material overrides and source sockets retain their meaning. |
| Goblins/devils/animals and other fixed rigs | Consume the installed component decomposition, body/shadow/accent enablement, independent tint/alpha/blend and recomposition data. Preserve original shadows; no generated ellipses or guessed alpha threshold. |
| Items | The same source appearance/material follows equipped, held, dropped and re-equipped states; retiring a floor instance does not destroy the shared texture. |
| Dead/prone/frozen/absent/copy poses | Keep authored frames and original contact. Copies remain visual contributors, not new actors or hit targets. No floor clips caused by the old depth solver. |

The current data includes image `roles`, `receiver`, `receiving_geometry` and component masks, but the existing renderer does not consistently consume them. Connect these existing owners for layer selection, lighting and placement; do not call them already implemented because they are present in JSON. Preserve original coverage where the supplied solid depth has no sample, especially shadow, glow, cloth and dust.

## 8. Materials, geometry, lighting and spells

### What needs a shader

Use ordinary Sprite/AnimatedSprite frame views when texture, alpha, source blend and basic tint are sufficient. Keep external absolute-time sampling in control; do not let an AnimatedSprite independently advance gameplay or Studio time.

Use a Pixi Mesh with shared shader programs and compatible geometry/state for a real source operation such as indexed palette replacement, component recomposition, normal-based lighting, procedural ribbons, paired radiance or analytic particles. Keep mutable uniforms, resource bindings and differing render state per occurrence/view so preview sampling or an actor's tint cannot overwrite another draw's values. Use Filters only for operations on a composed image that actually require that input. Scope their bounds and padding; do not install a fullscreen filter or offscreen pass per simple sprite. A custom shader does not imply custom visibility or depth writes.

Material order remains source decode → authored palette/material → receiving light → authored emission → source blend. Preserve masks, donor textures, gamma/noise, material envelopes, body/item ownership and normal/add/screen blending. Keep source alpha semantics and zero-alpha additive radiance. Custom paths must not accidentally premultiply or convert colour twice.

`RigLayer.material` and finite body-material envelopes are not fully consumed today. Wire their existing finite operators into these material functions; merely retaining a track or envelope clock is not completion. No per-spell class or new material language is needed.

### Depth and normal use

Reuse supplied plane, mesh, ellipsoid and ray-depth types for the uses that need them. The current renderer's rejection of every geometry kind except `ray_depth` is not the source contract. Keep source-to-world calibration, native colour-to-packet sampling, camera-local/object-local distinction, correct legacy/new byte decoding, masks and inverse-transpose normal transport. Read packets losslessly; do not run them through a colour-managed canvas.

These channels supply receiving positions/normals, source inspection and the spell/surface interactions already selected. They do not participate in ordinary floor/body/shadow visibility. Having depth attached to an image must not automatically turn its ordinary draw into an offscreen composition job.

### Lighting

Use the admitted native light treatment as baseline and the existing authored WorldLightingPolicy for its presentation. Smooth only across admitted compatible connected receivers. Use a wall/door's actual face/support and an actor's displayed support; do not sample whatever floor happens to lie under the sprite's topmost pixel.

The shared material functions evaluate direct light from displayed emitters at the registered receiving position and normal. Keep baked shading/shadows; no albedo recovery or shadow-extraction project. Where supplied finite blocker/door aperture geometry supports the selected light obstruction, use it and update it with displayed state. Camera-depth samples alone do not describe unseen light-blocking faces; do not fabricate those faces. Pan/zoom does not rebuild world light/blocker data.

Use the authored Fireball emitter curve once per logical impact, not once per bank/layer. The whole Fireball can receive light while retaining emitted radiance. Smoke can continue receiving other light after the short emitter curve fades. Other spell world-emitter authoring remains deferred by the user's earlier decision; this renderer work does not reopen it.

### Spell rendering within the scene

Preserve casting gesture, source hand/weapon media, release, travel, contact, impact, sustain/removal and recovery as distinct timed contributions when the recipe defines them. Keep selected banks, actual FPS and duration; new Fireball's authored 24 FPS is not a global conversion. Direction bank choice and permitted projectile-axis rotation remain separate, using the presented socket and trajectory.

Ground media goes on its receiving layer; body-attached back/front media follows authored actor order; world projectiles/ribbons/areas belong at their source contact/elevation. Preserve existing source near/far or front/back components and their actual meaning. Do not split every ordinary source into invented halves.

For the selected depth-carrying Fireball/wall interaction, keep source geometry and lighting mathematics, and implement the bounded effect draw inside Pixi's Mesh/RenderTexture facilities. The effect may compare its registered samples with the relevant visible surface data to preserve the demonstrated front/behind interaction. This does not enroll the whole ordinary scene into a generic transparent-depth solver. Its implementation follows after the ordinary scene is sound and is checked against that actual example.

Do not prescribe a universal crossing classifier, depth-peel fallback, screen-region subdivision or full-scene opaque/transparent pipeline in advance. Exact mutually intersecting transparent volumes are not certified by simple layer ordering or one nearest-depth texture. If a real selected case requires more than the source components and bounded effect treatment, document it for discussion rather than quietly rebuilding the old compositor. This is the user's explicit sequencing decision, not a hidden claim of full volumetric correctness.

Visible effects may extend over dark/unknown floor. No tile-visibility stencil clips a fireball's silhouette. Received hits, cancellation and suppression control outcomes/lifetimes; visual depth cannot change gameplay, invent propagation or disclose hidden entities. Keep existing Globe/Antimagic appearances and admitted responses without inventing mechanical interception from visible dome artwork.

## 9. Other authored rendering families remain in scope

| Capability | Pixi-path responsibility |
|---|---|
| Conditions | Existing entry/sustain/removal clocks, masks, owner multiplicity and suppression; separate body material, ground media and overhead marker. Head marker cycling must not rotate/remove other condition layers. |
| Body copies/trails/distortion | Same source pose/layers, actual authored material operator and historical sample time; no full-world screenshot history, camera warp or targetable duplicate actor. |
| Beams, ribbons, orbits, intake | Existing finite parameter records through shared Mesh functions, with displayed endpoints/sockets and source blend. |
| Blood/bone/vapor/sparks | Keep seeded release/landing laws and absolute-time analytic shader sampling; group compatible particle draws without CPU images per particle. Independent decorative sprites may use Pixi particles where appropriate. |
| Settled deposits, water, frost, soot | Receiver-local fields/masks and source material clock. Update coverage on arrival/removal/seek, not pan/zoom or every old injury. Draw on the receiving layer; wall marks use the wall's local coordinates. |
| Constructions and destruction | Existing path/section/formation/retirement data, compatible pieces and displayed commits. No new rigid-body simulation or fabricated geometry. |
| Portals and relocation | Existing entrance/exit front/back layers and aperture-local masking; visual copies/shadows follow authored phases. No undisclosed destination preview. |
| Damage/heal/lifecycle feedback | Actual recorded amount/outcome, source timing and retained identity; independent duration after the action ends. Draw text/badges as readable annotation, not competing physical geometry. |

The masterplan's R01–R23 remains a feature inventory. Its global physical-composition prescription is replaced here. Retain the unfinished authored consumers as explicit implementation work rather than declaring a simpler renderer complete while silently losing them.

## 10. Picking, grid and wall transparency

Use Pixi pointer events and authored hit areas as the starting point. A hit area follows the displayed object's transform, current frame/pose registration and interaction eligibility. Floor targets use the projected diamond or authored top/tread polygon at the actual support height. Resolve the displayed actor/object/support identity, then use the existing native choices/preview for legality. Shadows, cosmetic effects and noninteractive overlays must not capture ordinary world commands. Keep intended targets reachable through cutaway walls.

Pixi handles pointer dispatch and local-coordinate hit-area testing. Do not introduce a separate general picker, require a CPU copy of every source alpha/role plane, or add a GPU ID/depth readback pass for ordinary hover/click. Precise alpha/silhouette testing is an optional refinement only when an observed selection problem shows authored hit areas are insufficient; document the case before adding it. Keep interactive parent/child order aligned with intended target priority; cosmetic layers use `eventMode='none'`. If RenderLayer display order differs from logical parenting, verify that the intended visible target receives the event. RenderLayer is not automatically a 3D picker, and this setup does not require another picking framework.

The current `pickScene` uses GPU ID/world-point readback and belongs to the compositor being replaced. Replacing that dependency means connecting normal Pixi interaction to the existing command/preview flow; it is not authorization to build another picking subsystem. Do not use the latest server position while showing an older frame.

Grid/path/AoE/impact feedback uses the actual receiving surfaces and appears between their floor appearance and foreground objects. Read the current native preview; do not compute another route or area algorithm. Overlay decoration is not another gameplay collider.

Foreground walls covering admitted visible interactive space fade automatically. Use actual projected authored wall/receiver coverage to identify those current occlusions; Alt highlights usable objects and is not a prerequisite for cutaway. Preserve physical/native blocking and admitted light obstruction. Allow the same eligible door/support to be picked through a faded covering wall. Do not make camera rotation change which known objects exist or are eligible.

The basic change to Pixi does not require a GPU ID pass for ordinary picking. A future demonstrated need for a specialized pick path is discussed as such, not built now.

## 11. Asset readiness, caching and responsive loading

Keep prepared assets and readable paths. Frame views refer to shared sheet TextureSources; no per-frame decode for sheets and no per-camera colour copies. Existing ordinary PNG and special raw/paired packet decoders remain at their appropriate boundaries. Do not repack the entire library as a prerequisite.

Separate three readiness states: compiled metadata is inspectable; needed sources are decoded/uploaded; a coherent candidate sample is ready to display. Show the application shell and meaningful loading status immediately. Retain the previous coherent scene and responsive controls during preparation. A cold load may take time; it must not monopolize the main thread or leave the interface apparently dead.

Collect and deduplicate source dependencies for the requested sample/next animation before upload. Reuse unchanged prepared resources and display handles. Avoid the current sequence of reconstructing every scene patch and awaiting a fresh global upload drain after each one. Admit a display change when that sample's coupled colour/components/companions are ready. Future operations, alternate camera banks and offscreen timeline previews are lower-priority preparation, not blockers for inspecting current metadata.

Use Pixi Prepare for incremental uploads of the explicitly collected required TextureSources, including shader-bound companion sources. Its completion does not mean an arbitrary custom shader has compiled. Prepare only needed shader programs through their actual Pixi draw path during candidate preparation and measure compilation/first use separately. Existing source fetching/decoding work stays off the main thread where supported. Background loading is still work; it must not flood GPU uploads or be described as free. Keep current interaction ahead of thumbnails and speculative lookahead. Do not replace sequential barriers with an unbounded all-library Promise.all.

If playback reaches a boundary whose required display resources are not ready, hold its cursor and commit at the last coherent ready sample while input and metadata inspection stay responsive. Resume without skipping source phases or applying later state early. Preserve existing operation origins/starts and retained-tail semantics; do not let elapsed wall-clock preparation time jump the display straight to the end. This is a readiness rule in the existing playback owner, not a new scheduler framework.

| Change | Necessary update | Must remain reusable |
|---|---|---|
| Pan / uniform zoom | Root transform, clip/visibility checks, any actually view-dependent effect uniforms | Source pixels, GPU uploads, ordinary ordering, world light/blockers, settled deposits |
| Quarter rotation | Selected view/frame registration, affected order and missing view resources | Existing source cache and camera-independent authored state |
| Animation frame / time | Frame texture/UV, pose, material/light/particle uniforms | Scene structure where membership is unchanged |
| Door opens / object breaks | That assembly's frame/state, relevant picking/light/order | Unchanged actors and unrelated environment |
| New operation / seek | Required sampled state and changed memberships; coherent publication | Shared source pages, shader programs, still-valid previews |
| Timeline scroll / divider resize | Visible preview beds and pane clips/layout | Compiled tracks, existing cached sample textures and world assets |

Retain leases for the displayed view, pending candidate and useful preview entries. Cancel obsolete requests by existing generation/request identity and release only their ownership. Do not immediately destroy a texture still needed by another view, and do not retain the entire library forever. Context restoration rebuilds necessary GPU resources from the existing sources before publishing a coherent scene.

`cacheAsTexture` is for genuinely static, compositing-safe groups. Do not cache an entire changing world, lock live lighting into a bitmap, or flatten actors whose layers need independent authored effects. Start with ordinary Pixi batching; add a cache only for demonstrated repeated work and give it an explicit invalidation cause.

## 12. One display clock and frame loop

Keep network receipt/reduction separate from the displayed animation cursor. Ahead-of-display AI results queue; they do not skip animations or replace the visible world early. Play and Studio sample the same functions at the same displayed time.

Use one application-owned requestAnimationFrame/ticker path. In order: consume pending pane/input changes; publish a ready candidate if present; sample the displayed time; update changed Pixi handles/uniforms and ordering; render the scene; update inexpensive diagnostics. Pixi submits actual draws. No second animation clock, independent thumbnail ticker, continuous idle compositor or forced synchronization with the backend.

A paused unchanged frame does not require an endless busy redraw. Camera input, a new displayed sample, relevant resource completion or pane change makes it dirty. Animation still advances normally while active. Frame rendering must not perform fetch, decode, schema validation, scene-wide source reconstruction, readPixels or per-particle CPU raster work.

## 13. Studio is inspection of this same renderer

Keep the map across the upper workspace, timeline beneath, and optional inspector/events/combat-log panels. Recover NeuroStudio's readable time ruler, playhead, layered clip beds, source labels and expandable rows; omit editing/save/asset-import controls.

Build channel metadata as soon as the operation is compiled. Tracks do not require Play, do not disappear on completion and are not destroyed just because the user resizes/scrolls. Operation changes show the selected operation and keep the current display usable during preparation; do not silently advance selection. Labels identify the actual recording/action, not just a shared dungeon name.

Use the existing recording index and contents to expose the actual distinct actions/scenes available. Renaming duplicate titles alone does not close the complaint about repetitive examples. A requested example still absent remains an explicit gap; do not recapture unchanged cases or start another capture campaign to improve labels.

Every rendering contribution appears in a meaningful row: body, original shadow, equipment, source media, back/front component, projectile, area, condition phase, shader/material/tint/fade, particle release, deposit, emission and relevant commit. A shader/tint row shows its effect on the actual source with its values/time; an empty coloured bar is not a preview. Curves and parameters supplement the rendered result.

Generate sample previews using the same pure presentation/material functions and source textures, with separate preview display handles. Cache GPU-resident preview textures by actual source release, channel, selected sample/frame, view and resolved material inputs. Render only demanded visible rows/samples. Keep cached beds when the playhead moves; invalidate only affected content.

Display these beds in the timeline's clipped Pixi preview viewport within the same application canvas. DOM controls/labels can remain above it. This avoids copying every preview through `extract.canvas()`/`readPixels` and avoids a separate WebGL context per lane. Preview rendering must not swap the live scene/camera/time or reparent its objects. Exporting pixels for an explicit diagnostic is a separate optional user action, never the preview loop.

Divider movement updates clipping/layout and renders once in the scheduled frame. Reuse scene/preview targets unless their actual dimensions changed. Do not clear the map now and asynchronously refill it later. Retain playback/selection when resizing.

**Show a visible FPS counter at the top right of the map by default.** Display observed render frame rate and frame time with a modest UI update cadence. Optional detailed diagnostics distinguish CPU submission, long tasks, upload/preparation wait and measured GPU time; do not label CPU draw-call duration as GPU execution. Source animation FPS belongs in the track inspector, separately.

## 14. Implementation order

Each step edits the production path. No replacement standalone demo, temporary synthetic world protocol or second renderer is a completion milestone.

1. **Persistent Pixi shell and ordinary draw path.** Keep recording/reduction/compiler and source selection. Replace universal depth passes with retained layer containers and ordinary sprite/material draws. Remove manual interpolation, use the shared camera transform, and expose FPS. Ordinary flat scenes must require no depth-selection pass, even if their resources include companion maps.
2. **Authored support, environment and actors.** Connect actual phase/support/role data; preserve flat-floor precedence, raised/stair/cliff assemblies, wall/door compatibility, rig slot order, fixed-rig controls, native proportions and original shadows. Review the actual known scenes in all relevant cameras before calling this foundation sound. Do not build rare-intersection machinery.
3. **Preparation and Studio readiness.** Separate metadata from display readiness, deduplicate dependencies, keep responsive publication, and replace synchronous thumbnail extraction with the shared GPU preview path. Retain tracks at pause/end and stop divider flashing. These changes do not wait for every shader family to be ported.
4. **Actual material, light and spell consumers.** Connect existing palette/body/item operators, coupled depth/normal inputs for lighting, Fireball emission and selected bounded spell/surface behaviour. Keep ordinary visibility on layers. Document a demonstrated additional intersection need instead of enabling a generic fallback.
5. **Complete remaining authored rendering and interactions.** Conditions, projectiles, construction, particles/deposits/water, portals, damage/lifetimes, grid/targeting/cutaway and source previews use those same paths. Work through the existing capability inventory; mark actual missing consumers explicitly.
6. **Focused combined verification and cleanup.** Exercise the representative app cases below; remove obsolete dispatcher/peeling code and dead imports after replacement consumers work. Do not keep hidden old-renderer switches. Preserve unchanged tests/data and update only tests tied to the superseded rendering mechanism.

Use a plan-adherence subagent during implementation as required by repository instructions. It checks current work against these steps and stops side quests; it does not impose another approval or test ritual. Noncritical uncertainty is a short issue entry, not a reason to stop all known work. Backend changes remain prohibited throughout.

## 15. Behavioural checks in the actual application

Read the repository's existing HOW_TO_TEST guidance before writing tests. No tests or benchmarks were run to produce this plan. During implementation, use focused data-to-visible-result checks and inspect the live app; the user need not review exported videos/screenshots. Keep server-origin recordings for gameplay outcomes. Source-only material inspection must be labelled as such and must not fabricate a gameplay event.

| Actual case | Required result |
|---|---|
| Current Fighter/Sorcerer and goblin on flat floor, standing/damaged/prone/dead | Accepted relative scale; original shadows; complete source silhouette, no striped/chopped feet or corpses. |
| Lantern Crypt props and doors | Table/chest rest on floor; compatible frames/leaves join; corners/openings consistent through four views. |
| Existing properly enclosed raised area and stairs | Distinct floor materials, complete source enclosure, authored contact joins and bodies on correct support; no image warping. Record an actual exceptional overlap if encountered. |
| Modular and fixed-rig actions | Source layers, controls, enabled accents, equipment, sockets and clip timings preserved; changing one owner does not erase another. |
| Oblique projectile and complete spell cycle | Release from displayed hand/weapon/world source; correct bank and permitted orientation; actual impact/condition timing. |
| Fireball beside real wall/open door, with light | Source silhouette preserved, actual demonstrated depth/light interaction, emission curve ends as authored, no visibility-cell cuts or leaked numeric-channel colours. |
| Existing conditions and finite materials | Effect visibly changes the intended body/item/media; source inspection and preview show the same values; all phases persist across seek. |
| Blood/deposit and world transition | Flight/landing/settled mark agree; fresh material does not restart old marks; camera move does not rebuild deposition. |
| Current Studio recordings before Play, paused, at end, and switched | Tracks/previews remain readable and correspond to the selected operation; no metadata wait on GPU thumbnails. Selector exposes actual distinct contents, and absent examples are identified rather than disguised with renamed duplicates. |
| Repeated pan/zoom and divider dragging | Responsive input, stable image/proportions, no resize flash, no texture reupload or generic peel loop. Visible FPS reflects frame drops. |
| Cold then warm scene/camera/recording use | Attribute network/decode/upload/shader/readiness separately; warm sources reused; preparation does not block UI with synchronous readback. |
| Picking, Alt, cutaway, grid/target preview | Same disclosed objects across cameras; source-aligned hit areas; visible covered supports reachable; grid under objects on correct surfaces. |

Run the focused checks once after their owning change, then broaden when an actual failure or new change justifies it. Do not test a private pass count as if it were gameplay correctness; the absence of the retired global dispatcher is an architecture check, while visible ordering is a separate behavioural check.

Measure on the actual hardware/browser when evaluating the reported GPU/load problem. Record viewport/DPR, scene, source readiness and action; distinguish real hardware from SwiftShader. Compare flat idle, camera movement, ordinary animation, selected spell and timeline preparation. Use asynchronous GPU timing if available without waiting on the current frame; otherwise report that GPU attribution is unavailable. No invented utilization percentage or universal frame-time threshold is a delivery gate. Fix observed avoidable stalls and report remaining causes honestly.

## 16. Source and Pixi documentation grounding

The old implementations are evidence for useful behaviour, not codebases to copy indiscriminately. Existing plan text, files and app data were inspected; no other chat history was queried.

| Reference | Specific use / limit |
|---|---|
| [Old NeuroClient layer stack](/home/tommaso/Dev/NeuroClient/app/src/main.ts:158) | Persistent floor/overlay/world containers and ordinary scene ownership. Its old global ground-depth key is not a complete elevation solver. |
| [Old actor layers](/home/tommaso/Dev/NeuroClient/app/src/render/AnimatedEntity.ts:878) | Authored slot order and frame texture views. Recover behaviour using functions/passive records, not its actor class/FSM architecture. |
| [Old painter semantics](/mnt/c/users/tommaso/documents/dev/dnd_engine/game_obsolete/projection.py:220) | Planar versus raised/spatial work, physical edge contacts and deterministic local order. No Python CPU image partitioning port. |
| [Editor composition policies](/home/tommaso/Dev/NeuroMapEditor/src/render/orderPhaseOne.ts:1) | Separate planar/spatial composition policy, grid identity and source calibration. Do not treat editor group names as physical height. |
| [Wall/door/elevation handoff](/mnt/c/users/tommaso/documents/dev/dnd_engine/agent_docs/PIXI_WALL_DOOR_ELEVATION_POSITIONING_HANDOFF_2026-10-08.md) | Source-compatible assemblies and authored placement; current adopted client data remains the runtime input. |
| [Current registration](/home/tommaso/Dev/NDClient/src/rendering/registration.ts:15) and [support](/home/tommaso/Dev/NDClient/src/presentation/support.ts:5) | Existing passive occurrence and support identity, with current one-playable-support-per-XY limitation. |
| [Pixi Container](https://pixijs.com/8.x/guides/components/scene-objects/container), [RenderLayers](https://pixijs.com/8.x/guides/concepts/render-layers), [RenderGroups](https://pixijs.com/8.x/guides/concepts/render-groups) | Child order, logical versus display parenting, common transforms. RenderGroups optimize instruction ownership; they are not automatically bitmap caches or 3D sorters. |
| [Textures](https://pixijs.com/8.x/guides/components/textures), [background loading](https://pixijs.com/8.x/guides/components/assets/background-loader) | Shared sources/frame views and demand preparation. Background fetch alone does not eliminate decode/upload stalls. |
| [Mesh](https://pixijs.com/8.x/guides/components/scene-objects/mesh), [Filters](https://pixijs.com/8.x/guides/components/filters) | Supported specialized material/effect paths, bounded filters and ordinary Pixi renderer ownership. |
| [Performance guidance](https://pixijs.com/8.x/guides/concepts/performance-tips) | Prefer ordinary batching; avoid unnecessary filters/masks and repeated rebuilding. Correct order takes precedence over texture grouping. |

Official guides were rechecked during planning. Installed `node_modules/pixi.js` is 8.22.0; its RenderLayer, TextureStyle and renderer sources settle version-specific API details. The engine's pinned documentation snapshot remains at `agent_docs/references/pixijs-8.22.0-20261008/`. No new download/archive or version upgrade is required.

## 17. Review disposition

Required reviews: anti-slop, anti-OOP/ECS, and renderer/layer correctness. Review this document against the latest user correction: no speculative geometry solver, ordinary Pixi structure first, depth/normals retained for actual lighting/spell needs, no backend changes and no loss of authored capability.

All three reviewers read the complete draft. Their concrete findings have been incorporated:

- **Anti-slop:** distinguish actual recording variety from renamed duplicate labels; make the partial-stair limitation explicit without turning an observed issue into a general readiness blocker. The user's prior stair deferral remains in force.
- **Anti-OOP/ECS:** separate mutable live/preview shader inputs; distinguish texture uploads from shader compilation; identify the current GPU picking dependency; define behaviour at an unready playback boundary.
- **Renderer/layers:** clarify shader/program ownership and explicit companion uploads; distinguish wall edge sorting from owner-contact mounting; do not assume every source skirt is a separable asset.

Anti-slop and anti-OOP/ECS reviewers examined revision 2. Their remaining findings were incorporated: remove mandatory crossing/CPU-mask selection requirements, limit depth formulas to their actual consumers, and make the general plan and renderer chapter agree. Existing authored behavior and passive ownership remain intact. The user also removed the unnecessary pause/renewed-approval wording: after this plan update and review, resume implementation in §14 order. The document review does not claim that the runtime fixes have already been implemented or tested.
