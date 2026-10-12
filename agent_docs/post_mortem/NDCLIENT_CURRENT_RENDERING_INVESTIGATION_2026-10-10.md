# Current Studio rendering investigation — 10 October 2026

Latest pixel-scaling evidence: [Unity/Pixi review and cleanEdge comparison, 11 October](NDCLIENT_PIXEL_RENDERING_REFERENCE_REVIEW_2026-10-11.md). This records the provisional floor averaging, the user's preferred cleanEdge character comparison, the ordinary Sprite frame-notification fix, and the still-open tint/blood comparisons.

## Scope and status

This records the current feedback on the resumed Pixi renderer: the anchored-spells recording, timeline previews, casting layers, zoom, and the persistent red marks after Burning Hands. It does not combine this feedback with earlier Pygame development or early migration complaints. The earlier, specifically scoped a–e investigation remains separate.

The initial investigation below was read-only. The user subsequently authorized repairs: “fix everything” and “keep working and fix this stuff.” The repair status at the end of this document supersedes descriptions of broken code in the investigation. Work is confined to NDClient; the engine, SDK, Pygame, old NeuroClient and original source artwork remain read-only references.

The initial investigation examined NDClient's working tree with presentation release `20261010T075703.535851Z-8bcf7cfc`. Subsequent corrections and the current review release are identified below. Browser reproduction ran against the existing local Vite application using a separate headless page. That reproduces pixels and binding decisions; it does not measure the user's RTX 5090 utilization.

## The user's current complaints

1. A white/grey mark and black dots appear on the Sorcerer's hat. Inspect the spritesheet rather than guessing.
2. Casting produces visible artifacts and distorted-looking sprites.
3. Stream mode shows a persistent Bless effect as many tiny repeated rows.
4. Zoom causes crawling/readjusting tile edges. Fractional screen pixels may be involved.
5. Timeline thumbnails still take time to appear even when the scene already has the relevant sprites.
6. The number of source frames versus displayed preview samples is unclear.
7. Entities and different samples have inconsistent apparent size in previews.
8. The Body track contains the fire/magic contribution. Body animation, hand magic and the material applied to that magic should be distinguishable.
9. The authored Python casting behavior should have been preserved. The body should not receive the hand effect's fire material.
10. Why are ordinary sprites routed through a custom shader instead of preserving the working NeuroClient Sprite/filter setup?
11. Are camera, viewport and shader coordinates inconsistent, particularly during zoom?
12. Bright red lines/dots persist after Burning Hands finishes.
13. Burning Hands starts in the wrong place.
14. Fireball fails to open with “No authored rig for Amber combatant 1.”
15. The caster does not face the cast location, including Fog Cloud.
16. Equip/unequip uses Taunt, although the user expects that gesture for drinking potions.
17. Fix the shared source interpretation across recordings; do not require the user to find each broken animation individually. Pygame works with the existing backend, which must not be changed.

The earlier request for visible tracks before Play and no divider-induced timeline reload remains relevant context. The bounded changes addressing those behaviors introduced the repeated-condition-row problem described below; passing those checks did not establish correct track content or rendering.

## What is actually drawing the scene

There is one Pixi Application using WebGL2. There is no second raw WebGL world renderer. That does **not** mean the implementation is using ordinary Pixi Sprites sufficiently.

The scene currently contains:

```text
Pixi stage
  map viewport, clipped by a Pixi Graphics mask
    world Container: common pan and zoom
      planar ground Container
      planar details Container
      spatial world Container
        raised support groups and spatial objects
  timeline preview Container, separately clipped
```

Source: [composition.ts](/home/tommaso/Dev/NDClient/src/rendering/composition.ts:86).

The shared presentation code consumes server-derived records, resolves the installed authoring, and produces occurrences with source images, frame rectangles, registration, roles, animation samples and material inputs. Studio uses this production presentation code. Its track representation is a separate read-only view of those inputs, and that representation has mistakes.

`prepareScene` currently creates a Mesh, Shader, uniform group and associated material resources for **every new occurrence**, even one that will ultimately use an ordinary Sprite. It also prepares declared image-animation frames and geometry companions. Scene patches can retain unchanged prepared objects, and source textures have a shared cache; the entire scene is not fetched anew on every frame.

`usesMaterial` then decides which display object to show. Palette changes, item materials, body colour, conditions, non-neutral lighting, grid drawing and several effect flags select the custom Mesh. Only the remaining cases use a Sprite. Consequently ordinary-looking recoloured or lit bodies can still pass through the broad shared shader.

Sources: [preparation](/home/tommaso/Dev/NDClient/src/rendering/composition.ts:118), [selection](/home/tommaso/Dev/NDClient/src/rendering/composition.ts:696), [Sprite setup](/home/tommaso/Dev/NDClient/src/rendering/composition.ts:726).

This is the implementation mistake behind the user's architectural concern: switching some neutral objects to Sprites did not finish the agreed change to a Sprite-based ordinary renderer. The material shader remains responsible for too many unrelated operations, and selection between the two paths is itself faulty.

## Filters: what Pixi provides and what NDClient did instead

A Pixi Filter operates on a rendered image of a Sprite/Container and its children. Pixi manages the intermediate render target, filter bounds and filter coordinate uniforms; the filter shader processes that input and the result is composited into the scene. A filter still needs correct texture coordinates, resolution and scope. Replacing every shader with a filter would not automatically fix binding or placement errors and would add intermediate rendering where unnecessary.

A Pixi Mesh with a custom Shader is a different supported mechanism: the application supplies geometry and shader logic for drawing that object. NDClient uses this mechanism for most current material operations. It is not applying those operations as the old NeuroClient's Sprite filters.

Official references: [Pixi filters](https://pixijs.com/8.x/guides/components/filters), [Pixi meshes](https://pixijs.com/8.x/guides/components/scene-objects/mesh).

Old NeuroClient provides a concrete working comparison:

- It creates `AnimatedSprite` layers with `autoUpdate = false`, an explicit anchor, and `roundPixels = true`.
- It uses ordinary `sprite.tint` when sufficient.
- It applies `HslAdjustmentFilter`, `ColorReplaceFilter`, its targeted `MultiTintFilter`, and `ColorMatrixFilter` for the relevant colour operations.
- The shadow is an existing authored layer with its own alpha.
- It hides hair under ordinary helmets; decorative crowns are the explicit exceptions.

Sources: [AnimatedEntity.ts](/home/tommaso/Dev/NeuroClient/app/src/render/AnimatedEntity.ts:934), [vfxFilters.ts](/home/tommaso/Dev/NeuroClient/app/src/render/vfxFilters.ts:1), [layer modifiers and head visibility](/home/tommaso/Dev/NeuroClient/app/src/render/AnimatedEntity.ts:945).

The behavioral reference was available. Replacing it broadly before proving equivalent output was an assistant implementation choice, not a requirement from the user or from Pixi.

## Camera, placement and sampling

### The coordinate sequence

The world uses `(X, height, Z)`. At camera quarter zero, projection is:

```text
local screen X = 64 × (X − Z)
local screen Y = 32 × (X + Z) − 64 × height
```

These numbers describe projected grid distances. They are not the dimensions of the character image. A character frame is a rectangular source region containing artwork and transparent margins; its painted silhouette occupies only part of that rectangle.

An occurrence's source pivot, authored scale, offset and local transform place its artwork around the projected contact. The common world Container subsequently applies camera pan and zoom. Pixi's projection and world-transform matrices reach the Mesh vertex shader too. The main vertex path does not manually apply a second copy of camera zoom.

Sources: [projection.ts](/home/tommaso/Dev/NDClient/src/rendering/projection.ts:19), [spriteVertex](/home/tommaso/Dev/NDClient/src/rendering/surface-shaders.ts:18), [renderScene](/home/tommaso/Dev/NDClient/src/rendering/composition.ts:829).

### Fractional pixels are a real difference

The current wheel handler produces a continuously varying zoom and fractional pan. Texture sources use nearest-neighbour sampling. Application and Sprite creation do not enable the old NeuroClient's explicit `roundPixels` policy, and the custom vertex path does not implement equivalent placement rounding.

At a fractional effective screen scale, one source pixel does not occupy an integer number of physical screen pixels. Nearest sampling makes some source columns/rows cover more output pixels than others; those choices change during zoom/pan. Rounding placement alone does not make fractional-sized source pixels evenly sized. Device-pixel ratio also participates in this conversion.

Old NeuroClient explicitly rounds placement and uses nearest for its actor sheets. This investigation did not establish that every old environment texture had the same filtering setting; the actor setting must not be generalized to all old assets without evidence.

Pygame's path composes body layers into a source image, scales that image to rounded integer output dimensions, and places the result at integer coordinates. NDClient currently transforms separate layer objects at fractional positions instead. That is a meaningful behavioral difference even though both can be described loosely as “nearest”.

Sources: [camera.ts](/home/tommaso/Dev/NDClient/src/app/camera.ts:1), [texture sources](/home/tommaso/Dev/NDClient/src/rendering/resources.ts:33), [old NeuroClient Application](/home/tommaso/Dev/NeuroClient/app/src/main.ts:131), [Pygame body scaling](/mnt/c/users/tommaso/documents/dev/dnd_engine/game_obsolete/animation_draw.py:705).

The current custom colour sampler also calls `floor(vSource)` and samples at a texel centre. The removed four-tap interpolation is gone, but changing the texture's colour sampling setting alone would not produce ordinary linear interpolation in this path. This still conflicts with the active plan's instruction to let the selected colour sampler handle sampling.

Source: [appearanceAt / appearance](/home/tommaso/Dev/NDClient/src/rendering/surface-shaders.ts:244).

### What zoom does not currently do

Pan/zoom updates the common transform and causes a redraw. It does not change contact order or rebuild assets solely because zoom changed. Camera quarter rotation does select different authored views and recalculate spatial order. `arrangeScene` has an order-dirty guard.

This rejects the specific hypothesis that tile crawling necessarily means zoom is re-sorting the map. It does not certify the renderer's sampling as correct.

### A confirmed viewport-uniform problem, with limited scope

`uFramebuffer` is initialized from the application dimensions. Resize changes the Pixi renderer size but does not update that custom uniform. The water shader uses `gl_FragCoord / uFramebuffer` for its screen-edge sheen, and preview views do not provide an equivalent target-sized framebuffer uniform.

That is a real viewport-dependent shader-input mismatch. It concerns the water branch, not the dry floor or red blood marks in the supplied screenshot. It must not be presented as the proven cause of every artifact.

Sources: [global initialization](/home/tommaso/Dev/NDClient/src/rendering/composition.ts:92), [resize](/home/tommaso/Dev/NDClient/src/rendering/composition.ts:862), [preview view](/home/tommaso/Dev/NDClient/src/rendering/composition.ts:883), [water shader](/home/tommaso/Dev/NDClient/src/rendering/water-shader.ts:22).

## Confirmed cause of the persistent bright red lines

The Burning Hands final-state artifact was reproduced at operation 26, local time 3030 ms. Its flame media runs from 500 to 2000 ms, so the bright marks are present after that media has ended.

The final scene contains sixteen blood-residue occurrences. Four select the ordinary Sprite path while the others select the material Mesh path. Their source is a generated floating-point **density texture**, not a colour image. Density is stored in the red channel; the material shader is supposed to turn it into the authored blood appearance.

The failure is concrete:

1. Residue placed on a known floor inherits the floor's image registration. It has `residueField`, but need not have `occurrence.primitive`.
2. Preparation binds its density texture to `uColour` and sets `uPrimitive = 4` for the material shader.
3. `usesMaterial` tests `occurrence.primitive`, lighting and other flags, but omits `residueField`.
4. In neutral lighting those four objects fall through to the ordinary Sprite branch.
5. That branch creates a Sprite from the density texture using image-frame information intended for the receiving artwork. It displays numeric field data as colour and skips the blood shader.

The code is therefore making appearance depend accidentally on whether lighting happens to force the material branch. This is a faulty boundary between custom material data and ordinary images.

In an isolated replay, removing residue removes the bright artifacts; actor-only and condition-only renders do not contain them. The reproduced picture matches the user's persistent lines/dots. This diagnosis is not based merely on their being red.

Sources: [residue occurrence construction](/home/tommaso/Dev/NDClient/src/presentation/residue-media.ts:45), [density target](/home/tommaso/Dev/NDClient/src/rendering/residue-fields.ts:65), [resource binding](/home/tommaso/Dev/NDClient/src/rendering/composition.ts:249), [path selection](/home/tommaso/Dev/NDClient/src/rendering/composition.ts:696).

## Burning Hands: attachment and geometry are separate problems

The active recipe binds `whole-flame` to `area.burning_hands.v9` with `attachment: source_ground`, 48 frames at 32 FPS. It has no hand socket or emission-point adjustment for this media track. The runtime places the capture's ground pivot at the caster contact `[3, 0, 7]`, with scale 2 and zero attachment offset.

That explains **which reference point the implementation actually uses**. It does not by itself prove the correct replacement: a capture can intentionally encode a hand-height origin relative to a ground pivot. The relationship between that exported origin and the authored Attack6 hand must be established before changing an offset. The visibly wrong start reported by the user remains an unresolved placement defect; no guessed shift has been applied.

Sources: [current recipe](/home/tommaso/Dev/NDClient/authoring/spells/spell.burning_hands.json), [media registration](/home/tommaso/Dev/NDClient/src/presentation/media.ts:43), [source-hand binding](/home/tommaso/Dev/NDClient/src/presentation/spell-media.ts:84).

There are two additional confirmed errors in the supplied VFX-data integration:

### Colour registration and reconstructed geometry disagree

The Burning Hands capture maps horizontal source-world displacement to 32 pixels per unit. Displaying that capture at image scale 2 gives 64 pixels per unit, matching the client projection's horizontal coefficient. However, `pairedImage` also multiplies the reconstructed source-world coordinates by that same image scale. Projecting those reconstructed positions therefore gives 128 pixels per source unit horizontally.

A sampled opaque near-layer pixel in frame 6 demonstrates this without depending on a subjective visual comparison:

| Quantity, relative to caster contact before camera zoom | Value |
|---|---:|
| Displayed colour-pixel offset | `(213.00, −51.00)` |
| Projected point reconstructed by the current geometry path | `(426.00, −58.50)` |

A far-layer sample similarly produces horizontal offsets of 73 pixels for colour versus 146 pixels for reconstructed geometry. The vertical calibration also differs: the capture uses a height coefficient near 39.1918, while the client uses 64. A uniform image multiplier is not a valid general source-world conversion.

This means a shader can light a visible pixel using a different world position from the one implied by its screen location. It is a confirmed source-to-world registration defect. It is not proof that the main camera transform is applied twice, and it is not the cause of the ordinary red density-texture Sprites above.

Sources: [pairedImage](/home/tommaso/Dev/NDClient/src/presentation/media.ts:120), [capture matrices](/home/tommaso/Dev/NDClient/authoring/media/banks/burning_hands-whole-lifecycle-SE.json), [geometry reconstruction](/home/tommaso/Dev/NDClient/src/rendering/surface-shaders.ts:354).

### Near/far contributions are emitted in the wrong order

The bank declares the composition `near + (1 − nearAlpha) × far`. With ordinary source-over drawing, the far contribution must be drawn first and near afterward.

The observed frame creates occurrence 0 from `near` and occurrence 1 from `far`; `mediaOccurrences` iterates the bank's object keys, and the ordinary sibling ordering preserves that sequence. It therefore draws near before far. The code is not preserving the bank's specified composition. This is separate from timeline grouping and source-origin placement.

Sources: [paired media occurrence order](/home/tommaso/Dev/NDClient/src/presentation/media.ts:138), [sibling ordering](/home/tommaso/Dev/NDClient/src/rendering/composition.ts:772).

## Sorcerer appearance and casting layers

### Hat pixels: source versus recolouring

The initial Sorcerer uses `Head15/Idle.png`, frame rectangle `(0, 256, 128, 128)`. Its cropped pixels were compared directly with the archived Pygame source frame: zero differing channels. The inspected Head22 and Chest14 initial frames also match. This does not certify every migrated image; it rules out damaged copying for these inspected frames.

The hat's source greys are remapped using these installed item-palette values:

```text
original zones: (203,203,203), (179,179,179), (90,90,91)
target zones:   (170,51,51),   (133,40,40),   (0,0,0)
```

The nearest-zone tolerance leaves three source pixels unmatched: two `(163,163,164)` and one `(162,162,162)`. They remain grey. The dark source pixels that match the third zone become pure black. These values account for a grey patch and black details in the current recolouring path.

The archived Python item-material implementation contains the same basic shade construction and matching threshold. Therefore this must not be described as proof that an entirely new colour algorithm invented those pixels; the combination of installed palette inputs and matching behavior is the demonstrated issue. A whole-frame visual parity claim requires comparing the complete old appearance inputs, not just the image.

There is also a definite missing visibility rule: old NeuroClient and Pygame hide the `head`/hair layer under normal helmets, except the authored crown categories. NDClient currently leaves the Sorcerer's Head22 hair layer visible under Head15.

Sources: [actor layer assembly](/home/tommaso/Dev/NDClient/src/presentation/actors.ts:22), [item material](/home/tommaso/Dev/NDClient/src/presentation/item-material.ts), [shader palette treatment](/home/tommaso/Dev/NDClient/src/rendering/surface-shaders.ts:177), [Pygame helmet rule](/mnt/c/users/tommaso/documents/dev/dnd_engine/game_obsolete/animation_draw.py:490).

### Body, hand effect and material are being confused in the track presentation

Burning Hands is authored as Attack6 with separate Magic2 and Effect5 casting layers and a fire palette/noise input on those layers. Healing Word uses Attack5 with its own corresponding Magic2/Effect5 layers and palette. Neither inspected spell has a body-material binding.

The runtime does create separate occurrences for `weaponGlow` and `aura`. Thus “there is no magic source at all” is not an accurate diagnosis of the data. Whether those layers are positioned and coloured correctly is a separate rendering question.

The Body track's contributor selector takes all animated occurrences owned by the actor with the same pose clip. That includes the magic/aura occurrences. Its preview therefore shows body plus casting effects together, while the desired separation is not represented clearly. Child layer entries exist, but the main Body preview does not mean “body only”. The screenshot of a burning Body preview is not, by itself, evidence that the body's material was changed to fire.

Sources: [spell cast compilation](/home/tommaso/Dev/NDClient/src/presentation/spells.ts:90), [actor palette selection](/home/tommaso/Dev/NDClient/src/presentation/actors.ts:102), [track contributors](/home/tommaso/Dev/NDClient/src/studio/channels.ts:39).

### The authored instruction to hide equipment during casting is broken

The recipe says `equipment.kind = hidden`. The compiler writes hidden slots named `weapon_melee_main`, `weapon_melee_off`, `weapon_ranged_main`, `weapon_ranged_off`. Rendered layers are named `weapon` and `offhand`; the actor-layer filter compares those names directly. They do not match.

The probe confirms Melee1 remains in the Sorcerer's casting layers alongside Magic2 and Effect5. Pygame explicitly removes the weapon when `hide_weapon` is active. This is a porting error, not an artistic preference or an ambiguity requiring the user to re-author the spell.

Sources: [incorrect slot names](/home/tommaso/Dev/NDClient/src/presentation/spells.ts:90), [filter comparison](/home/tommaso/Dev/NDClient/src/presentation/actors.ts:86), [Pygame removal](/mnt/c/users/tommaso/documents/dev/dnd_engine/game_obsolete/animation_draw.py:493).

## Timeline content, thumbnail cost and scale

### Why Bless becomes many tiny rows

Stream mode currently concatenates `channels(...)` from each recorded operation. A persistent condition is emitted again for each operation's interval, including zero-duration intervals because the exclusion is `end < start`, not `end <= start`. The concatenation does not coalesce intervals belonging to the same persistent condition contribution.

Those slivers do not represent many authored Bless casts or independent animation loops. They are a mistake in the timeline aggregation added while making the recording visible before Play.

Sources: [Stream aggregation](/home/tommaso/Dev/NDClient/src/studio/workspace.ts:78), [condition channel intervals](/home/tommaso/Dev/NDClient/src/studio/channels.ts:76).

### Why previews still appear gradually

The image-source cache is shared between scene and previews. It is inaccurate to say every thumbnail necessarily downloads the same sprite again.

However, every requested thumbnail creates a separate temporary scene view, prepares display handles and shaders for its contributors, samples them, renders a 54×54 target, and disposes the temporary view. A serial `requestIdleCallback` queue processes these requests. Source reuse avoids some I/O but does not avoid all this preparation and rendering.

Some preview times also require assets the live scene has not reached yet. In addition, the source cache distinguishes `colour` from `colour-palette`, so URL equality alone does not guarantee a single cached decode across uses.

Rendered thumbnail targets survive ordinary divider layout changes in the recent bounded fix. Timeline rebuilds, including its current expansion/zoom rebuild path, can still discard targets and queue them again. These are different invalidation cases and must not be described as one solved “cache” problem.

Sources: [preview pump](/home/tommaso/Dev/NDClient/src/studio/timeline.ts:46), [channelThumbnail](/home/tommaso/Dev/NDClient/src/presentation/playback.ts:80), [cache keys](/home/tommaso/Dev/NDClient/src/rendering/resources.ts:33).

### Why preview scale changes

`renderPreview` independently fits the current contributors' bounds into 54×54. A pose with extended limbs, an aura or a different silhouette gets a different scale from a compact pose. This is preview auto-fit; it does not describe the actor's world scale. It makes comparison confusing and fails the user's requirement for an intelligible track.

### What the thumbnails mean

The timeline currently chooses roughly one sample per 54 horizontal pixels of clip width and samples the midpoint of each interval. It is a sparse filmstrip, not a display of every source frame. Its labels expose the selected frame and source FPS but not a clear total source-frame count or the number of displayed samples. The UI does not explain this distinction.

Sources: [sample placement](/home/tommaso/Dev/NDClient/src/studio/timeline.ts:77), [sample count](/home/tommaso/Dev/NDClient/src/studio/timeline.ts:146), [independent fit](/home/tommaso/Dev/NDClient/src/rendering/composition.ts:902).

## Shader inventory and comparison with the references

| Current NDClient operation | Current mechanism | Reference behavior / difference |
|---|---|---|
| Unmodified image | Pixi Sprite only if `usesMaterial` returns false | Ordinary Sprite/AnimatedSprite is the old NeuroClient baseline. |
| Palette, tint, saturation, brightness, flash | Shared surface Mesh shader; some direct Sprite tint | Old NeuroClient uses tint and targeted filters; Python treats source layers/images. |
| Modular body animation | Separate layer occurrences with authored frame selection | Both references have explicit layer order, slot visibility and casting overlays; visibility parity is incomplete. |
| Existing shadow artwork | Modular shadow sheet; fixed-rig composition uses supplied shadow/body sources | Present source shadows are used; the red density artifacts are not a new shadow image. This does not retroactively resolve earlier shadow complaints. |
| Fixed-rig body/shadow/accent controls | `character-material.mjs` composition from supplied combined and separated sources | New fine-grained controls prepared during the asset phase; not the modular Sorcerer's path. |
| Whole-body material | `body-composition.ts` / `body-ramp-shader.ts`: offscreen source-frame composition and treatment | Python composes the body then applies its authored treatment. These passes are not active for the two inspected spells' body materials. |
| Environment / ordinary lighting | Surface shader samples the disclosed lighting field; optional world emitters and supplied normals | Per-pixel depth/normal relighting is a new addition. Baked source shading is retained. |
| Paired VFX | Appearance plus depth/normal textures in the surface material | Replaces old XYZ exports. Current near/far order and source-world calibration have the confirmed problems above. |
| Airborne blood / fragments | `particle-shader.ts` evaluates authored trajectories on the GPU | Python performs the corresponding particle presentation on the CPU. Pixel equivalence has not been established by this investigation. |
| Settled blood / fragments | `residue-fields.ts` generates a density field; `residue-shader.ts` renders its appearance | GPU adaptation of the authored residue presentation. Path selection currently mis-displays some density fields as images. |
| Water | `water-shader.ts` uses the imported water material parameters | Custom material branch; framebuffer-dependent sheen input is stale on resize. |
| Lightning | `arc-mesh.ts` draws authored ribbon samples | Specialized geometry is a legitimate effect use, not a reason to route ordinary sprites through it. |
| Directed spell materials | `directed-mesh.ts` handles selected noise/plasma effects | Specialized effect path; not established as the cause of this screenshot. |
| Orbiting spell effects | `orbit-mesh.ts` draws formations/mist/wakes | Specialized effect path; likewise outside the reproduced artifact. |
| Ordinary visibility | Ground/details/spatial child order, raised support groups | The current scene is no longer using general per-pixel depth peeling. That removal does not certify every layer/order relationship. |
| Picking | Pixi EventBoundary plus authored/derived hit areas | No general GPU framebuffer picking loop in the current ordinary scene. |

### What depth currently does and does not do

The main surface shader can reconstruct a world point for lighting and receiving effects. It does not write `gl_FragDepth` or perform the old universal transparency/depth solver. Ordinary visibility is decided by the scene's layer/order rules. Having depth textures loaded therefore does not mean all wall/spell interactions are implemented or correct.

The new point-light emitter association is explicit authored data; the renderer does not infer an emitter from every fire-coloured spell. The existence of normals likewise does not prove that their source-to-world registration is correct, as the Burning Hands numerical comparison shows.

## Performance: established facts and limits

The source cache, retained prepared scene objects and dirty render key exist. There is not zero caching. Pan/zoom does not itself refetch textures. On an unchanged paused frame, the application can skip a scene submission.

During zoom, the dirty key changes and the visible scene is submitted again. Many lit/recoloured objects use individual Mesh material paths; this loses the ordinary Sprite batching advantage. Thumbnail preparation and rendering add separate work. These are concrete sources of avoidable complexity and cost, but this investigation has not apportioned the user's GPU utilization among them.

The top-right FPS number measures requestAnimationFrame cadence. The “submit” duration measures CPU time inside the render call; it is not GPU execution time. A screenshot showing 145 FPS and 0.0 ms submit does not prove either high or low GPU utilization.

Sources: [main render loop](/home/tommaso/Dev/NDClient/src/app/main.ts:120), [source reuse](/home/tommaso/Dev/NDClient/src/rendering/resources.ts:33), [material selection](/home/tommaso/Dev/NDClient/src/rendering/composition.ts:696).

The earlier 30–40-second loading/system-freeze complaint is not reclassified as solved here. This pass reproduced appearance and inspected current preparation; it did not capture a current hardware loading/GPU profile. The earlier software-rendering measurements must not be relabelled as a current 5090 measurement.

## Evidence and remaining uncertainty

Temporary diagnostic files produced outside the repositories:

- `/tmp/ndclient-render-audit.json`: actual initial/casting layer inputs and uniforms.
- `/tmp/ndclient-idle-helmet.png`, `/tmp/ndclient-idle-head.png`, `/tmp/ndclient-idle-chest.png`: native source-frame crops used for inspection.
- `/tmp/ndclient-burning-audit.json`: operation 26 media, registration and final rendering-path selections.
- `/tmp/ndclient-burning-after.png`: reproduced persistent red lines after the flame lifetime.

These are diagnostic captures, not a substitute for the application or a request that the user review another screenshot collection.

Confirmed: incorrect residue path selection; paired VFX near/far order; paired geometry versus colour calibration mismatch; casting equipment slot mismatch; missing helmet/hair visibility rule; misleading Body contributor grouping; repeated persistent-condition rows; per-sample preview auto-fit and unexplained sparse sampling; continued preview preparation cost; inconsistent rounding versus the old client; stale water framebuffer input.

Still not established: the exact corrected Burning Hands emission attachment; a pixel-for-pixel explanation of every visible casting mark; full old-versus-new appearance equivalence; the allocation of current RTX 5090 GPU time; the current cold-load/system-freeze cause. These are open findings, not permission to invent offsets, replace artwork, broaden the renderer or modify the backend.

## Repair pass after the user's authorization

### Shared source interpretation and appearance

- **Residue routing:** `residueField` explicitly selects its material. Numeric density textures cannot fall through to ordinary colour Sprites. An isolated replay of the completed Burning Hands operation finds no bright red artifact pixels in the full scene, residue-only, actor-only or condition-only outputs. Existing blood artwork/material remains; the change removes the incorrect display of its numeric data.
- **Source sampling:** ordinary appearance now uses interpolated colour UVs and the selected Pixi texture sampler. The manual `floor(vSource)` colour lookup was removed. Numeric geometry/material lookups remain numeric. Application placement and the material vertex path use Pixi's own pixel-rounding policy. A neutral material and ordinary Sprite now match for the same recorded body and shadow at zooms 0.73, 1, 1.37 and 2.11: body channels match exactly; shadow channels differ by at most one 8-bit value. This proves equivalence to the chosen Pixi sampling, not that fractional zoom can display every source pixel at an integer width.
- **Target dimensions:** each scene/preview submission updates `uFramebuffer` from its actual render target, fixing the stale water input described above.
- **Lighting admission:** material selection considers the complete non-neutral disclosed lighting field, baseline and base response. A bright contact cell no longer suppresses treatment where neighboring cells should blend across the artwork. Emission-preserving and unlit sources retain their authored policies.
- **Layer resolution:** the shared cast resolver follows Pygame's rig-specific body context, release/preparation anchors, sockets and palette precedence. Equipment hiding is applied after layer merging. Ordinary helmets hide hair, with the existing Head5/Head8 crown exceptions. Physical body colour excludes isolated casting/effect layers, while the original hit flash still covers its original non-shadow contributors.
- **Cast layers:** Burning Hands remains Attack6 with separate Magic2 and Effect5 sources; Healing Word remains Attack5 with its corresponding isolated layers. Magic2 supplies the hand magic. Effect5 can surround the body as its own authored artwork. That outline does not mean the body itself receives the fire palette. Already colour-baked source overrides retain their pixels; automatic layers resolve their owning spell's palette. The source gamma default is 0.65, recovered from Pygame; it is not presented as a new user-selected art direction.
- **Facing:** animation-frame updates now select the rig's facing row as well as the frame column. Fog Cloud uses the center of the uniquely identified spatial effect created by that received cast when the root event has no explicit aim. This uses existing received information and changes no backend contract.
- **Missing connections:** the existing `creature.generic_caster` visual profile now resolves to its original modular rig, so Fireball no longer fails for Amber combatant 1 under the current authoring. Existing compatible modular sheets were connected across 17 declared clips, along with the supplied Goblin 01 Attack3 Slash1. These are references to installed sources, not new animation choices. Head11 remains an actually absent artwork category.

Sources: [cast resolution](/home/tommaso/Dev/NDClient/src/presentation/cast.ts), [actor assembly](/home/tommaso/Dev/NDClient/src/presentation/actors.ts), [spell compilation](/home/tommaso/Dev/NDClient/src/presentation/spells.ts), [material admission and submission](/home/tommaso/Dev/NDClient/src/rendering/composition.ts), [sampling](/home/tommaso/Dev/NDClient/src/rendering/surface-shaders.ts).

### VFX registration and authored action strips

Paired media now derives its source-to-world transform from the delivered capture calibration and the actual displayed registration. Image scale is not applied twice. Normals use the inverse-transpose transform. Near/far occurrences draw far first and near second. The coordinate regression checks actual bank pixels across four camera quarters, scales and screen transforms; reconstructed geometry and displayed colour agree within 0.000001 projected pixels.

Burning Hands retains the original Python `source_ground` attachment. That attachment is an authored registration point for the exported artwork, not a claim that the flame visibly starts at ground height. No guessed hand offset was added. Correcting geometry registration does not independently prove exact Attack6-to-flame visual alignment, so that remaining comparison is not called completed.

The original potion action strip is now connected as timed media: `Effect2_Special1_phase-1.png`, nine frames, 12 FPS, anchored at authored frame 8. Its source was copied unchanged from old NeuroClient into `.media/vfx/actions/strips/`; client JSON definitions and generated types describe the connection. Registration preserves the source bottom-center placement, body registration, authored offset and scale. Its hue and white replacement use the same `HslAdjustmentFilter` then `ColorReplaceFilter` from `pixi-filters` as old NeuroClient, scoped to the isolated effect node. The effect is authored unlit; filtering it does not recolour or change lighting on the actor parent.

Sources: [paired media](/home/tommaso/Dev/NDClient/src/presentation/media.ts), [action strips](/home/tommaso/Dev/NDClient/src/presentation/action-media.ts), [source filters](/home/tommaso/Dev/NDClient/src/rendering/source-color.ts), [strip definition](/home/tommaso/Dev/NDClient/authoring/media/definitions/strip.effect2.special1.phase1.json).

**Equip/unequip is a source-policy discrepancy, not a backend defect:** the inspected Python and old NeuroClient authoring both specify Taunt at speed 3 with commit frame 4 for visible equipment changes. The user expects Taunt only for potions. This repair does not silently replace that gesture with a guessed alternative. The requested equipment presentation remains an explicit unresolved choice; the recorded gameplay outcomes are unaffected.

### Studio representation

The complete stream is compiled for inspection before Play. Moving the divider changes layout and clipping without recreating track content or discarding already prepared sample textures. A persistent contribution is joined across contiguous operation intervals using its actual owner/lifetime; the inspected Bless lifetime has its back and front lanes, each spanning two intervals, instead of one row per sampled update.

Body previews show physical body/equipment sources. Isolated cast, aura, effect and material contributors have expandable source/treatment rows and provenance. The main Body bed no longer flattens fire magic into the body description. Item treatments include their actual source item. Body samples share full-frame framing to preserve relative actor size; effect samples use a stable registered envelope. Source FPS, source frame count and displayed sample count are distinguished.

Preview views retain their prepared handles and GPU sample textures, and share the production resource store. Scrolling, expanding and resizing reuse those results. An additional real visibility bug was found: opaque child-row DOM backgrounds covered the correctly rendered Pixi thumbnails. Preview lanes are now transparent over the shared preview canvas while source labels retain their background.

The existing **Reload JSON** action is available once recording metadata is loaded, including when initial scene preparation failed. It selects current client authoring explicitly. Recordings pinned to an older presentation release are not silently unpinned; they need this action to use newly corrected authoring. The native event bytes remain unchanged.

Sources: [channels](/home/tommaso/Dev/NDClient/src/studio/channels.ts), [timeline](/home/tommaso/Dev/NDClient/src/studio/timeline.ts), [playback](/home/tommaso/Dev/NDClient/src/app/playback.ts).

### Checks and practical limits

- The repository test run passes all 28 tests after these source/presentation repairs. Type checking passes.
- Current-authoring compilation and channel inspection cover all 20 indexed server recordings and 177 operations. No case throws, has invalid visual intervals or merges unrelated Bless lifetimes. This is stronger than checking a single spell but is not a claim that every frame of every recording has been visually certified.
- Browser sampling tests cover the recorded modular body/shadow at four zooms. Body-material tests cover supplied fixed-rig sources, neutral recomposition, actual material treatment and reuse during zoom.
- The current broad shader still allocates material handles for ordinary occurrences before selecting Sprite versus material. This was not replaced with another rendering architecture during the repair.
- Near/far order and geometric calibration are repaired. Exact linear-radiance recomposition remains unproven: each contribution is encoded to display colour before ordinary Pixi blending. Independently rounded cropped contributions also need a dedicated overlap comparison at fractional zoom. Neither is concealed by the geometry test.
- Existing compilation notices for measured weapon trails/contact media, the Wall of Fire safe-side tint mask and partial ring media remain client presentation work. They are not demands to modify the backend, and they are not certified complete by the recording sweep.
- A current headless zoom profile found zero warm texture uploads and zero new source textures. It initially measured about 244.5 GL draws per frame, with 220 of 222 visible occurrences taking the material path. This confirms repeated draw work despite source caching. The test uses ANGLE SwiftShader; its roughly 1.1-second recording metadata preparation and 0.9-second scene preparation are not measurements of the user's hardware or proof that the reported system freeze is resolved. CPU submission time is not GPU execution time.

### Static-floor rendering cost

The existing flat-floor container now uses Pixi's `cacheAsTexture` when its members are static and compositing-safe. All disclosed floor tiles are included, including those outside the current viewport. The cache preserves source pixel resolution and nearest sampling. It is invalidated by floor membership, lighting, camera-quarter or GPU-generation changes. Grid drawing, live point lights and animated floors bypass it. A group exceeding the actual GPU texture-size capability uses the uncached path. There are no new per-tile render groups, invented memory budgets, or changes to the hit-test tree.

This is the documented use of a [Pixi static container cache](https://pixijs.com/8.x/guides/components/scene-objects/container/cache-as-texture), applied to measured repeated work. It does not flatten actors, raised supports or the entire changing world.

`tests/ground-cache.browser.mjs` checks the actual recorded floor artwork through the production renderer. Source/integer sampling comparisons show no channels differing by more than 2/255 after initial zoom, panning beyond the initial viewport, retained-node lighting changes, floor removal, grid restoration, emitter completion, camera rotation and actual WebGL context restoration. Picking and dynamic/oversized-group bypass checks pass. Four warm floor-only renders use 12 actual GL draws in total, compared with 227 for one uncached floor render, with no new texture uploads or source loads.

In the full anchored-spells diagnostic at 1280×900, 24 warm zoom frames now use **32 actual GL draws per frame, down from about 244.5**. Mean CPU submission time changes from approximately 3.95 ms to 1.53 ms. Warm texture uploads and additional source textures remain zero. The initial metadata/scene preparation stays approximately 1.1/0.95 seconds. These are headless ANGLE SwiftShader results, not hardware GPU time or a claim that RTX 5090 utilization is fixed.

At fractional zoom, sampling one cached source image is not pixel-identical to independently rounding every source tile. The inspected 1.37× comparison changes approximately 3% of channels by more than 2/255, concentrated at nearest-sampled pixel edges; it preserves tile joins, lighting and source detail without added interpolation. No custom snapping or Pixi-internal patch was added to conceal this trade-off. The source/integer sampling checks must not be generalized into a claim of fractional pixel parity.

### Preview capture limitation and review

A final expanded/scrolled timeline capture showed a black rectangle over part of the map and a solid-looking clipped preview. The supplied source texture and the actual root framebuffer at those positions had correct alpha/clear pixels. The rectangles survived removing the timeline mask and hiding both scene containers in the diagnostic, while framebuffer reads remained correct; disabling GPU compositing did not resolve the screenshot discrepancy. This reproduces a discrepancy in browser/DOM-composited capture, without establishing a renderer-mask defect. No speculative renderer workaround was introduced. Evidence is in `/tmp/ndclient-studio-pixel-check.txt`; this does not certify that every possible user-visible preview artifact is absent.

Final plan-adherence, anti-slop/ownership and source-behavior review passes for these scoped repairs and the cache. The production build and type check pass. The completion claim is the specific repaired behavior and checks above, with the equipment gesture, exact Burning Hands release alignment, radiometric/fractional VFX overlap, remaining authored presentation notices and hardware GPU attribution still explicitly unresolved.

### Replay after the recording ends

User complaint: pressing Play after a full recording finishes starts near the end instead of replaying from the beginning. The completed Stream path called `seekPlayback(0)`, which rewinds only the currently selected operation. It therefore repeated the last action.

`src/studio/workspace.ts` now restarts completed Stream playback through the existing operation-1 selection path, restores prefix 0, and clears the previous run's clock and effect start times. Selected operation mode retains its local rewind. The recording, source textures and compiled timeline remain loaded.

`tests/studio-replay.browser.mjs` failed against the original behavior and passes after this change on the actual anchored-spells Studio recording. It verifies operation 1 at 0.00 s, an initial worker world request with `time_ms: 0` and `starts: {}`, progression through the initial zero-duration records, and independent Selected operation replay of operation 26. Type checking and focused read-only plan-adherence review pass. This check addresses replay only; the unresolved rendering findings above remain open.

### Pauses between recorded actions

User complaint: playback freezes whenever an action finishes. The user authorized fixing this before moving on. These were client preparation stalls, not authored pauses.

The actual anchored-spells recording has 26 operations and three timed animations: Healing Word, Bless and Burning Hands, totaling approximately 7.29 seconds. The intervening records have zero presentation duration but still carry ordered state commits. The old lookahead stopped at each such record. In addition, unchanged lighting was repeatedly sent through the worker as a new object, invalidating the lighting texture and static floor cache. Actor frame changes rebuilt layers already handled by the renderer's frame sampler. Animation preparation awaited a separate upload drain after every scene patch, and cold image decoding completed before GPU uploads started.

The shared game/Studio playback path now:

- Prepares through zero-duration records to the next timed animation. Playback applies every ready commit in order in the same frame; it carries unused frame time into the next ready animation.
- Omits unchanged lighting fields from patches, preserving their existing texture and static-floor cache. Real lighting changes still invalidate them.
- Keeps actor handles when only the sampled frame/time changes; the existing sampler updates their source frame, direction, opacity and authored registration. Changes to the actor or pose definition still rebuild their affected contributors.
- Starts the upcoming animation's image requests together through the existing source cache. As each image decodes, its distinct sources enter Pixi Prepare's incremental upload queue while the other images continue loading. Ordered scene assembly uses those resources; one final upload admission covers the animation's remaining derived/non-image sources.
- Retains pending/displayed scene ownership until replacement is ready. If a genuinely missing resource prevents advancement, it holds displayed state and time together. Live idle animation still advances when no next operation has arrived. Selection/camera/session cancellation and manual Pause retain their existing authority.

No upload quota was changed. This is limited preparation for the next animation, not loading the entire artwork library. It changes no backend, SDK, recording bytes, animation recipes, or authored durations.

`tests/studio-continuity.browser.mjs` exercises first playback and replay in the actual Studio. The final headless run measured **7.383 seconds** after the first advancing clock sample, with a maximum unchanged-clock hold of **83.3 ms**, for the 7.29-second recording. Replay measured **7.250 seconds**, with **no measured boundary hold and zero new image decodes**. Both runs committed operations 1–26 in order. These measurements exclude initial page/recording loading; they use headless Chromium, not the user's RTX 5090. They establish the scoped inter-action repair, not a resolution of every earlier loading or GPU complaint.

`tests/retained-actor-sampling.browser.mjs` uses the server jump recording. Retained handles advance from source frame 1 to frame 8, keep the body airborne and the shadow grounded, match freshly prepared output with zero channels differing by more than 2/255, and reproduce the initial pixels on rewind. The replay regression, 28 repository tests, type checking and production build also pass. The plan-adherence reviewer found no actionable ownership/cancellation issue in the final preparation changes. The earlier unresolved visual findings remain open.

### Current correction: composition, subordinate effects and meaningful feedback

The user's current instructions define the desired behavior. Pygame and old NeuroClient supply existing artwork, calibration and timings; they do not override these instructions. The earlier statement that the unwanted Effect5 caster aura should remain because it existed in source authoring is superseded.

The user distinguished two relationships that the previous Studio flattened:

- **Components** are parallel sources forming one subject: body/head/clothes/equipment, or the back and front sources of one spell effect.
- **Operations** act on a subject and have a target and time interval: attached hand magic, its palette, a timed item/body treatment or a hit flash. An attached effect can own further operations. An existing shoe, leg or skin colour is baseline appearance, not an operation. Actual equipment changes belong to their native state commit.

Body may own effects. It does not need separate unrelated top-level effect tracks. Body's main preview shows the complete composed result. Effect/material subtracks must be visible initially, while individual source parts may remain collapsed. Top-level Body uses the full row width; indentation means subordination (Body → hand magic → palette). The user's “full space” complaint referred to this indentation; the assistant's initial interpretation as a request to change thumbnail scaling was incorrect and withdrawn.

Additional current complaints: healing/damage numbers must identify the actual result and damage type; inspecting/expanding a track must not reset its scroll or playback time; a corpse must keep its witnessed final Die frame, contact and direction; Burning Hands still starts away from the caster. The user rejected the automatic caster aura in the reviewed Healing Word, Bless and Burning Hands sequence. This does not request suppressing every aura or recipient condition in the library.

Implementation uses existing source records and sampling. `StudioActorLayer.role` describes the attached effect independently of its rig draw slot; Magic2 remains in the existing slot for ordering but is identified as hand magic. `SpriteOccurrence.actorEffect` retains that authored descriptor. Physical body colour/material treatment excludes these attached cast sources. Normal rig hit feedback retains its existing non-shadow scope, while attached cast effects keep their own treatment.

Explicit `StudioMediaTrack.effectGroup` identities join reviewed back/front pairs. Compiled identities retain the cast, recipient and contact occurrence so unrelated applications cannot merge. The annotation pass preserves timing, registration and drawing order, adds roles/groups across 147 recipe files, and sets `cast.aura.enabled=false` in the three reviewed spells. The separate Burning Hands attachment correction is described below. Artwork remains untouched. `Channel.components` and `Channel.operations` project these relationships for inspection; they are not a new renderer or animation executor.

The death repair retains the witnessed terminal clip/frame/facing/contact across later operations and fresh prefix restoration, and releases that pose on authoritative revival. Focused tests pass for all four views and sequential versus fresh worker restoration.

Healing Word's grouped media and healing result now belong to their casting Body through the received lineage. The Body interval is unchanged; its child media can continue after the Body ends. Ambiguous multiple-action lineages are not assigned an invented parent. Actual equipment before/after appearance is exposed at existing commits; this does not replace the unresolved Taunt gesture.

Studio checks pass for complete Body previews, initially visible effect/material rows, initially collapsed source components, full-width top-level rows, and retained scroll/time while inspecting. Pixel checks distinguish the physical Body, its attached Magic2 source and its palette result, with zero new decodes for warm previews. All 20 indexed recordings / 177 operations compile through shared code; existing wall/ring/melee-trail notices remain. These checks do not certify every frame of every recording.

### Burning Hands: corrected attachment and recording reference

`spell.burning_hands.json` now uses `media[whole-flame].attachment = source_hand`. Its `emissionPointByFacing` comes from the eight delivered `resolved-contract.json` emitter coordinates projected through the supplied camera matrices, relative to each bank's `pivot_pixels`. No visually guessed displacement is used. `cast.releaseFrame = 6`, source media FPS and the 1500 ms flame duration remain unchanged. Tests verify all eight exported coordinates and agreement with the authored release socket across four cameras at three animation times.

The `anchored-spells/case.json` descriptor still selected presentation `20261010T075703.535851Z-8bcf7cfc`, so normal loading did not use these corrected recipes. The generated local descriptor was updated to `20261010T213643.695768Z-16d02a49`, then to `20261010T215454.849214Z-4e581d57` for the Healing Word timing correction below, and now to `20261010T220330.457518Z-56bfcca2` for the casting-hand socket correction. Its 27 original SDK packet files and the earlier presentation releases remain unchanged. This updates this recording's existing presentation reference; it does not alter the application's release-selection policy.

Direct loading of the normal scene URL, without Reload JSON or request interception, verified Burning Hands using release `213643`: frame 6 at 500 ms, visible flame at 750 ms, absent flame at 2020 ms. Shared-renderer pixel comparisons found zero changes to physical-body pixels outside Magic2 coverage; Magic2 source versus palette output differed, and both the cast effect and flame had no remaining pixels at operation completion. Internal evidence is `/tmp/ndclient-burning-direct-pixels.json` and `/tmp/ndclient-burning-direct-*.png`. Those checks establish palette isolation and lifetime, not correct hand selection. The previous visual approval at the fitted map scale is withdrawn: enlarged actual Studio frames on release `215454` still show the flame near the face while Magic2 is on the lower casting hand.

The source images explain the mismatch. `devtools/author_spell_casts.py` copied the generic rig's `pose_sockets.hand.Attack6` into this spell's `cast.sourceSockets`. For this selected `Magic2/Attack6.png`, that generic socket belongs to the other arm. At source frame 6 facing SE, the old point was `(76.233, 54.900)` while Magic2 occupies source pixels `x=70..79`, `y=72..83`; its measured centre is `(74.795, 78.415)`. These are coordinates within the 128×128 sprite frame, not the isometric grid size or viewport dimensions. Moving the release time would not correct that wrong-hand selection.

Only Burning Hands' `cast.sourceSockets` was replaced with points measured from the selected Magic2 source using alpha × maximum RGB brightness as the centroid weight. Preparation points use the same selected source in each frame, with null for an empty frame. These are newly measured spell-specific points, not recovered pre-authored Attack6 sockets. The eight release points remain tied to `releaseFrame = 6`; the shared rig, source artwork, exported `emissionPointByFacing`, playback speed and flame lifetime are unchanged. No backend or renderer change was required.

`tests/source-emission.test.ts` now checks each preparation/release point against independently read occupied pixels of the actual Magic2 PNG in all eight facings. It also verifies that the compiled release contains the reviewed sockets, then checks exported emitter-to-hand registration in all four camera quarters at three times. These tests would detect the old other-arm socket and stale published data, unlike the earlier test that only aligned an emitter to whichever socket was supplied. All five focused anchored-spell/cast/emission tests pass on release `220330`; type checking also passes.

Enlarged actual Studio captures, loaded normally from release `220330` without Reload JSON or request interception, now show the flame onset meeting the forward casting hand at body frame 6 / flame frame 0. Body frame 8 retains that source region; at 2020 ms the flame and hand magic are absent and the caster retains its base appearance. Root and the independent plan reviewer inspected these pixels. This visual result covers the displayed camera; the eight-direction PNG and four-camera coordinate checks are separate evidence. No browser errors were reported. Internal evidence: `/tmp/ndclient-burning-corrected-frame-6.png`, `/tmp/ndclient-burning-corrected-frame-8.png`, `/tmp/ndclient-burning-corrected-after-end.png`, and `/tmp/ndclient-burning-corrected-evidence.json`.

The 31-test repository suite, type check and build passed. After the separate Healing Word authoring change, the four focused anchored-spell, casting-layer and flame-emission tests passed again.

### Timing vocabulary and scope correction

`cast.releaseFrame` is authored as a source-frame index. Its calculated position in the playback timeline uses the selected clip's FPS and `cast.bodyPlaybackSpeed`. `media.startOffsetMs` is a separate authored offset relative to its selected clock. Do not describe a calculated millisecond position as though the authored frame marker had been replaced.

The user mentioned Haste to explain this distinction, not to request another implementation task. The assistant incorrectly started a Haste investigation; no Haste timing code or authoring was edited, and that work was stopped. The investigation found that negative media offsets are not adjusted with the external condition playback rate, but this is a recorded finding, not an instruction to divert from the requested spell/Studio repairs.

The separate, explicit Healing Word complaint was that the recipient effect began with Attack5 rather than at the cast release marker. Its two `startOffsetMs = -500` overrides have now been removed. Both sources use the existing release clock with `cast.releaseFrame = 7`; no new millisecond delay was added. At the authored 12 FPS and `bodyPlaybackSpeed = 1.15`, release occurs at approximately 507.246 ms. The recipient media and native healing feedback therefore share that frame-derived start; the media still lasts 3000 ms, independently of the completed Body animation. This extends the whole recorded sequence by 500 ms; it does not extend or freeze the Body track.

The user also clarified: living gameplay actors return to looping Idle; paused Studio playback stays still. Recorded-state checks confirm living Idle samples advance and witnessed corpses retain Die. No separate animation clock was added while paused.

### Burning Hands: fixed release origin; following change withdrawn

The user explicitly clarified that Burning Hands must start at maximum hand extension and then stay in place while the hand retracts. The previously introduced `sourceSocketSampling: "cast_pose"` behavior was a mistaken interpretation of the later-frame gap. Its schema field, recipe setting and runtime branch have been removed. The flame uses the measured Magic2 socket at the authored Attack6 release frame 6 for its entire lifetime. There is no hand-following or terminal-hand hold mode.

The earlier release point correction remains valid: the generic rig hand selected the other arm; Burning Hands uses the measured Magic2 casting-hand point. The release marker, exported emitter calibration, source frame rate and flame lifetime remain unchanged. The expanded regression checks the fixed emission origin across later cast frames, both sides of the return to Idle, the flame tail and reverse sampling in all four camera quarters. Later separation from the retracting hand is expected and must not trigger another attachment change.

### Door reveal, retained facing, Idle and Fireball visibility — 2026-10-11

Current user feedback: the Lantern Crypt room appears only when the opening door finishes; body-part tinting needs explanation; living Idle appears frozen; Fireball's caster disappears; actors reset direction after acting. These are separate findings, not one shader problem.

**Door reveal.** Fantasy A1 has 12 source frames at 16 FPS. The original workshop metadata gives opening angles `0, 3, 8, 16, 27, 40, 54, 67, 78, 85, 89, 90` degrees. No previous reveal marker was recovered. Following the user's half-open instruction, the client copies of its inward/outward banks now author `state_change_frame: 6`, the first source pose beyond 45 degrees. This is a newly requested authoring change, not a claim that the old data already contained that marker. Source artwork and engine authoring were not changed.

The environment animation now identifies the recorded `spatial/object_changed` cause, rather than taking the sensory world-update event as its cause. Sensory `observed_changes.source_event_uuid` can identify an earlier event version; `eventDates` now resolves that version through `version_rows` to its final lineage event. Both observers therefore receive the room visibility at the same door frame. The original interaction gesture marker remains unchanged. Reversed banks convert the source marker to the corresponding reversed playback frame.

In the actual `crypt-door` recording: interaction contact / leaf start is 250 ms, visibility changes at 625 ms (375 ms after leaf start), leaf completion is 1000 ms, and the action ends at 1250 ms. The normal Studio URL loaded presentation `20261010T222246.146465Z-73c43b1f` and returned those same commits, including both sensory events and the spatial event at 625 ms, with no browser errors. `tests/door-reveal.test.ts` checks the actual objects and visible cells immediately before and at the marker, and equality with the native final prefix. This recording tests opening; closing has not received an equivalent recorded visual check.

**Facing.** The previous resting fallback explicitly selected south, and untargeted actions/equipment/self-casts also selected south. `CompiledOperation.restFacings` now carries only the last witnessed direction. Active Body tracks determine subsequent direction; recovery, later operations and fresh worker prefix reconstruction retain it. Actions without a new aim reuse that direction; directed actions still use their disclosed aim. This does not retain casting layers, hidden slots, opacity overrides or obsolete contact positions. Current visibility still controls actor admission. Existing corpse `restPoses` retain their terminal clip/frame/contact independently.

**Idle.** The existing live playback branch already advances living Idle with the displayed clock; paused Studio does not advance. `tests/idle-facing.browser.mjs` exercises the shared worker and Pixi rendering using the actual Fireball movement prefix: the caster remains facing north, uses Idle, advances from source frame 0 to frame 3 over 250 ms, and changes 528 pixel channels. With playback paused, another tick changes zero pixels and does not advance the clock. Fresh prefix reconstruction matches sequential playback. This verifies the live Idle branch; it is not evidence of a newly repaired Idle clock, nor a test that a finished Studio recording should continue playing. Studio currently stops at recording completion.

**Fireball caster.** The caster is Amber combatant 1, `e8915953-6f78-4315-a1b4-770126baac77`, while the recording's controlled observers are the six Blue targets. All six targets receive lethal damage, and each observer's recorded sensory event explicitly includes the caster in `entity_contacts_removed`. The caster remains alive and present in retained state but loses the audience's visual contact at impact. The current disappearance follows this data; it is not a missing rig, transparent texture or body deletion. The strengthened regression checks this particular caster during the cast and Idle recovery, then its removal only at the recorded sensory-loss commit. Previously checking that *some* actor existed could not detect a missing caster.

The user subsequently rejected the gameplay experience of incapacitation cutting off the player's ability to understand what happened. Distinguish character perception from the player's presentation: the witnessed attack and consequences need to remain understandable, and the received combat log remains available. The player's continuing view after incapacitation is a separate gameplay/view-policy requirement. No backend sensory rules or subjective visibility admission have been silently changed in this repair. Completion of that presentation/view-policy work is not claimed here.

**Body colours.** Pygame `_colored` multiplies skin/hair/beard source RGB by the selected tint (`BLEND_RGBA_MULT`); its equipment path then calls `item_material` with the authored item tint/effects. NDClient likewise resolves separate physical body-part tints and equipment palettes; Magic2's spell palette belongs to the attached casting effect, not skin/clothes. The lit shader performs tint multiplication in linear colour, whereas Pygame's multiplication uses encoded RGB values, so exact pixel parity is not claimed. This was an explanation request; no unrequested gamma or recolouring change was made.

Verification: eight focused tests pass across actions, cast routing, corpse retention, door reveal, playback and fixed Burning Hands emission; TypeScript checking passes. The live Idle/pause pixel test and normal Studio door-load check report no browser errors. Plan-adherence review checked these changes and explicitly called out the opening-only and live-Idle-only test limits.

### Character tint artifacts, environment pixel scale and camera — 2026-10-11

The user confirmed that the reported character colour artifacts disappeared after the ordinary equipment tint correction. `itemMaterial` previously converted every nonwhite equipment colour into HLS palette replacement. The selected V1.3 Head15 source contains grey shades outside the old palette's match tolerance; those survived grey while a darker matched shade could become black. Ordinary equipment now retains its authored multiplicative tint. Explicit item effects and condition equipment modifiers still resolve their authored materials. This matches old NeuroClient's ordinary single-tint branch; Pygame's equipment palette path was the source of the previous implementation. Do not claim exact encoded/linear colour parity: the existing lit shader still multiplies tint in linear colour space.

The user initially selected a physical half-resolution environment colour raster, native ordinary character pixels at camera 100%, and camera 200% as the default apparent size. This policy is now under review following the floor-detail complaint and cleanEdge comparison linked above. The source PNGs and numeric companions are unchanged. The resource worker initially reduced each environment bitmap once with nearest sampling; the current provisional version averages colour once during reduction, while GPU sampling remains nearest. The user found the averaged result blurry, so this is not a completed visual repair. Pixi TextureSource resolution retains the authored source-coordinate units; mesh colour UVs use that same conversion. Geometry, normal and support packets retain their original resolution and lossless decoding. One base scale of 0.5 converts the calibrated 128×64 projection to the 64×32 display grid at 100%. Camera zoom multiplies that common transform. Actor scale exceptions remain authored; the source frame's 128×128 dimensions are not the grid dimensions.

Initial load now centres the map without overriding the 200% default with automatic Fit. Explicit Fit remains available. Studio framing, logical terrain contact validation, culling and source-pixel conversion use the appropriate logical/display scale. Environment colour is physically reduced; simply changing both transform multipliers would not have implemented the user's request. The static floor cache keeps its previous minimum resolution of 1 in calibrated coordinates, avoiding a second reduction of already reduced colour and evaluated lighting. There is no per-zoom texture resizing or asset rebuild.

Q/E now preserves the ground point under the viewport centre after the new view is ready. The wheel controller consumes accumulated input once per frame; its former exponential decay continued moving the camera for roughly half a second after a wheel event. Source textures and floor cache remain resident through zoom.

Evidence from current Chromium checks:

- 33 unit tests pass, including actual dash-follow ordinary equipment tint and existing explicit coating/suppression behavior. Type checking and build pass.
- Neutral body, shadow and reduced chest rendering matches ordinary Pixi Sprite sampling at zoom 0.73, 1, 1.37 and 2.11; no channels differ by more than 2/255. Source alpha has visible coverage in every case.
- All eight cached/direct floor comparisons pass, including panning to initially offscreen tiles, lighting changes, removal, view rotation and context restoration. Warm zoom performs zero texture uploads and adds zero source resources. Floor picking still returns the selected world cell.
- Actual camera controls and shared prefix publication preserve the viewport-centre ground point through E/E/Q/Q at two pane heights and a deliberately panned/zoomed view; maximum numerical error is below 1e-9 pixels. Pointer-centred wheel zoom also preserves its ground point. Another 40 frame ticks after input produce identical pixels and no camera change, upload or new source.
- Studio full-body, attached Magic2 and palette previews remain visible and distinct; warm previews perform zero additional decodes.

The chest's production colour source is now 192×768 instead of the 384×1536 source sheet; its geometry packet remains 384×1536. At the reviewed dash-follow view, all 24,494 fully opaque chest pixels match between isolated and full-room rendering, with no missing pixel or colour difference. This establishes the current view, not every environment asset/view.

The thin blue/silver shape reported beside the fighter at the doorway is present in the selected `Melee2/Idle.png` source frame (SW row); it is the edge-on weapon silhouette. The inspected full scene preserves all 20,700 opaque pixels from the isolated fighter/effects with maximum channel difference 1/255. No source artwork was erased or reshaped to conceal that silhouette. The fighter's brown points were traced to the separate authored beard layer below the helmet, not invented source pixels.

These checks do not establish the user's hardware GPU utilization, every camera view's environment occlusion, or completion of the full client. The earlier post-death presentation requirement remains separately unresolved. Engine/server/SDK/Pygame and original artwork were not edited in this batch.

**Wall transparency versus texture sampling.** In the current `crypt-door` recording the moving wooden leaf and stone door frame both retain node alpha 1 and source opacity 1 at opening start (250 ms), reveal (625 ms) and completion (1250 ms). They are not marked `cutaway`. The neighbouring wall set changes from 11 to 19 faded contributors as the room is revealed. `updateCutaway` sets those wall nodes to alpha 0.18; it does not change another sprite's UVs or sampler. Map colour textures use nearest sampling individually; a cached floor group is sampled as its own texture. There is no full-scene interpolation filter. A translucent wall can blend over a character and produce ghosted overlap; an opaque wall covers the character instead. Whether a particular doorway artifact comes from that overlap requires isolating its actual contributors.

The user then suggested the sword shape may combine Idle, Haste and the translucent wall. The current Studio end-of-recording branch explicitly sets `playing=false`, so it freezes the resting Idle pose and remaining condition animation. Returning to the Idle clip is distinct from advancing that clip's clock. Explicit Pause must keep every inspected animation still. No change to recording completion behavior was made merely to test the artifact hypothesis.

**Exact white shape beside the sword: identified.** The follow-up attachment was readable through its `/mnt/c/Users/...` path and matches the inspected doorway view. Separately rendering the fighter's physical layers, Haste, and wielded weapon shows the blue horizontal silhouette in `Melee2/Idle.png`, frame 13 facing SW. The white continuation is absent from all three. Isolating contributors at its actual screen pixel identifies ground occurrence `item:90cdb471-5240-4041-97d3-2c6a007fc000:0`, using `Melee15/Idle.png`. Packet `dash-follow/000007.json` contains `action.core.drop`, named `Drop (Handaxe)`, for that exact item, and supplies its floor placement `[4,9]`, `base_height_steps: 0`. The existing Handaxe ground appearance selects Melee15. It is therefore a recorded dropped handaxe coincidentally aligned with the wielded sword in this view, not interpolation damage, missing character pixels or a Haste fragment. The wall can blend its own translucent pixels but does not create either weapon silhouette. Continuing Idle would change the visual coincidence over time, not remove the separately recorded item.
