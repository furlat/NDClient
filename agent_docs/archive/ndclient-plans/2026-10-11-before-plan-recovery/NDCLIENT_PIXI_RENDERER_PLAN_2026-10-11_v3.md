OUR OBJECTIVE IS A COMPLETE IMPLEMENTATION

# NDClient renderer repair plan — v3

11 October 2026. Renderer chapter of the [complete client plan](NDCLIENT_IMPLEMENTATION_PLAN_COMPLETE_2026-10-11_v3.md). This revision replaces renderer v2; it does not replace the remaining gameplay, Studio, UI or authored-feature scope. The [code audit](NDCLIENT_RENDERER_CODE_AUDIT_2026-10-11.md) contains evidence, file ownership and qualifications. Implementation follows §10; the audit is evidence, not another list of mandatory architecture requirements.

## 1. Decisions and scope

- One ordinary Pixi Sprite drawing path for gameplay and Studio. Three distinct colour filters: **tint**, **precise colour swap**, **material**. Dedicated lighting operates on that path. Remove the ordinary catch-all Mesh fallback after its actual consumers have destinations.
- Environment images retain their native resolution and colours. Characters receive **cleanEdge at fixed 2× source resolution**, then the viewport scales their textures normally. This changes texture detail, not world size, sockets, pivots or accepted environment/character proportions. Do not adopt the Unity example's different proportion.
- Preserve authored layers, grounded shadows, facing, frame markers, equipment and effects. The legacy slot `weaponGlow` can hold hand magic such as `Magic2`; that does not authorize colouring the weapon or caster body.
- Show existing authored lighting working in real recorded demos. Preload the two adjacent camera views without sacrificing current playback; make quarter changes responsive during spells, with the viewed location and playback state retained.
- Restore the original blood appearance and floor-plane placement. Finish presenting an already received lethal event without its own death-related sight loss erasing the event.
- NDClient code, tracked client authoring and client tests are the implementation boundary. Engine, server, SDK, Pygame, NeuroClient, original art and Unity remain read-only. §8.2 records a **separate backend proposal**, not permission to implement it.

Use existing passive records and functional consumers. No second scene graph, renderer plugin, generic filter registry, new entity hierarchy, asset-wide preprocessing campaign or new visibility solver. Record a noncritical unknown with its evidence and continue the next unblocked step; do not invent a fallback or spend the whole delivery on that unknown.

## 2. What the scan established

The previous plan explicitly allowed indexed colour, normal lighting and component composition to route ordinary images through Mesh. The current `composition.ts` consequently allocates the universal Mesh even when it eventually displays a Sprite, and `usesMaterial` chooses between two ordinary drawing routes. This permission is removed here and in the general plan.

The scan also found: destructive environment reduction; tolerance/neighbor-based matching presented as palette replacement; different nonwhite tint results between routes; missing consumption of authored media `paletteSwap`; ordinary ground-item tint lost; isolated layer `material` copied but not consumed; camera rotation rebuilding historical playback and clearing timeline previews; and death-related sensory loss committed before Fireball's visible result finishes. Blood has a separate reproduced floor-geometry error. These have concrete work items below.

Do not reopen already corrected Sprite frame notification or divider resize bugs without a reproduction. Do not claim all old complaints are explained by a single shader. Audit details distinguish measured failures, source defects, unfinished capabilities and unmeasured performance risks.

## 3. Ordinary drawing and texture preparation

### 3.1 Pixi owns drawing

Retain the existing persistent Containers/RenderLayers, contact/elevation ordering, source blend, native hit areas, wall cutaway, camera projection and resource leases. Ordinary prepared images own their Texture/Sprite and applicable filters directly. Frame/registration data must not live inside an otherwise unused Mesh shader.

Keep specialized Meshes for actual changing geometry: arcs, ribbons, directed/orbit effects and analytic particles. Keep GPU residue-field generation. A real geometry effect is not an alternative route for an ordinary image. Move its necessary functions out of the universal surface shader into its specific owner; do not leave the whole old shader available as a fallback. Preserve portal clipping, condition masks, grid/feedback, water, paired radiance and procedural bolt consumers during this extraction. Existing simple ellipses/pixels stay Pixi Graphics.

Picking remains Pixi interaction plus authored hit areas. Depth/normals support lighting and the already specified Fireball/wall interaction; they are not required for ordinary painter visibility or a new universal pixel picker.

### 3.2 Native source pixels, then fixed character cleanEdge

1. Decode original colour once under the existing resource owner. Remove environment `resolution: .5` and its unused reduction plumbing. Keep numeric depth/normal/mask/radiance decoding lossless, with declared colour space and no premultiplication of numeric data.
2. Select the original frame and apply only that layer's authored colour operations (§4). Maintain the common native character grid and authored blend/order.
3. Reuse the native character composition owner in `body-composition.ts`. For modular characters, assemble the aligned body/equipment and character-sheet effects in the original `slot_order`, after applying each layer's own colour/material. `weaponGlow` sits between physical parts; include that treated layer at its authored position rather than flattening all clothes and then drawing Magic2 above them. Effect identity and controls remain available to Studio independently of this image composition. Keep already separate grounded shadows and independent world VFX separate. For fixed creatures, preserve the combined/body/shadow/effect algebra as a whole, including neutral overlap pixels; do not replace it with ordinary source-over of exported branches or force an inseparable shadow into a new layer. Apply cleanEdge to the resulting character image. Retain independent body, effect and shadow controls. Hand magic never causes the body to inherit its material.
4. Run the author's cleanEdge algorithm as a **separate GPU source pass** into a target with logical dimensions W×H and physical dimensions 2W×2H, e.g. `RenderTexture` at resolution 2. Preserve its license. Clamp all neighbor reads to the selected frame; use transparent outside-frame samples where the algorithm requires them, never an adjacent animation cell. Do not apply cleanEdge to environment, blood, world VFX or numeric companions.
5. Display that retained Texture as an ordinary Sprite at the existing logical registration. Example: a native 128×128 character frame produces 256×256 texture pixels but keeps its 128×128 logical frame. Keep the current common projection scale and accepted camera default. There is no second character world-size multiplication.

Use a distinct 2× pass: pinned Pixi takes the minimum resolution in an enabled filter chain, so appending a resolution-2 filter to resolution-1 colour filters would not establish a 2× source. Process native character pixels independently of current camera zoom; do not run cleanEdge over the already enlarged map.

Cache within the existing prepared-view lifetime. Frame/facing/source, equipment, colour controls and sampled animated material can invalidate a character's derived colour. Pan, zoom and world translation do not. Camera quarter can select another authored facing; update only those changed sources. Lighting updates do not recreate the cleanEdge colour source. Reuse targets and release them on replacement/disposal/context generation changes. No cache of every possible equipment × frame × material-time combination.

### 3.3 Coordinates and resource lifetime

Keep source-frame pixels, Sprite-local positions, world positions and display pixels explicit in names and transforms. A texture's physical resolution is not the grid size. The current isometric projection is 128×64 logical units before its common scale; preserve those established transforms.

Filters use Pixi's valid input frame/clamp and the Sprite transform, including anchor and cropped frame. Do not derive world positions from `gl_FragCoord`. Do not let wall alpha, neighboring artwork, pooled target padding or a different atlas cell enter a character's source operation. Neutral filters preserve colour and alpha. Keep premultiplied output conventions explicit; emitted radiance with zero alpha is handled separately (§5).

Share immutable programs and decoded sources; keep mutable values per occurrence/view. Preview preparation cannot change the active actor. Donor sampling must not mutate a shared TextureSource. Pinned Pixi 8.22 WebGL binds only the source’s own style, so the frost and directed material shaders use bounded four-texel donor reads: frost preserves fract-then-clamp linear sampling, and directed donors preserve repeat-linear sampling across wrap edges. This does not alter ordinary image or viewport sampling. Allocate material ping-pong/wither targets only when used. Rebuild private derived pixels and admit all their donor sources after context loss through the existing resource lifecycle.

### 3.4 Spell dimensions under the final texture policy

Use one conversion from each source's declared coordinates into world units. A legacy sprite authored against `catalog.rig.TILE_W = 64` needs its existing conversion into the 128×64 projection. Fireball's bank already supplies `source_to_host`, and its migrated impact `scale: 1` explicitly uses that calibrated basis; applying `128 / TILE_W` again doubles it. Correct that unit mismatch in the shared consumer, without a spell-name exception or compensating `scale: .5` in Fireball JSON. Keep authored occurrence size, appearance size and world placement separate from unit conversion.

Audit every producer in the [scale inventory](reviews/renderer-2026-10-11/fireball-scale.md). Paired storage alone does not establish the units of an inherited authored scale: other banks derive registration from their capture matrices and retain values such as `.5`, `.7692307692` or `.7462686567`. Trace their source binding and expected world extent before changing that conversion. Normalize the proven source-coordinate distinction in existing passive data/consumers; correct confirmed duplicate conversions across their users and preserve valid legacy conversions. Do not halve every paired effect, rewrite every scale, or introduce a scale registry. Record an unresolved source-size interpretation instead of guessing. Actor sockets, ordinary travel art and procedural world-coordinate effects retain their own valid conversions.

The final texture policy is the basis for acceptance: original environment texture pixels at their registered world dimensions; fixed 2× cleanEdge character textures at unchanged logical dimensions; the same viewport transform for environment, characters, effects and the displayed native area. Restoring environment detail and increasing character texture resolution must not change grid spacing, spell reach, pivots, sockets or light positions. Physical texture dimensions do not authorize a second world-size multiplier.

Check Fireball against the actual recorded `area_geometry` and `resolved_area_positions`, as well as the accepted lighting proof. Its SRD radius is 20 feet; the engine supplies a four-step radius on its five-foot grid. Compare the main burst at its native centre with that world footprint under the final texture policy, in all quarters and more than one zoom. Smoke, sparks and the separate light falloff need not terminate at the damage boundary. The full capture rectangle, a late smoke crop, the number of affected cells and the emitter's range are not substitutes for the spell radius. Do not change native hit selection or invent a visual clipping rule. If the calibrated artwork still needs an artistic size adjustment, document the measured mismatch for discussion rather than applying another guessed scale.

An independent world-extent/area comparison is required: colour and depth can agree with each other while both are enlarged incorrectly. Keep current and accepted-proof capture revisions explicit; they share calibration but do not contain identical pixels.

## 4. Three explicit colour operations

| Operation | Meaning and input | Required consumer |
| --- | --- | --- |
| Tint | Multiply source RGB by authored RGB in the same encoded-colour convention as Pixi tint; preserve alpha. White is identity. | Ordinary body/clothes/equipment `layer.tint`; retain `part.tint` for dropped items even when `itemMaterial` is absent. Apply once, not Sprite tint plus the filter. |
| Precise colour swap | Replace explicitly mapped original source RGB bytes; every unmapped colour is unchanged. Alpha is unchanged. No distance tolerance, neighbor inference or primary-colour fallback. | Existing asset `paletteSwap.originalColors/targetColors` where present, after confirming whether selected storage is original or already transformed. Do not apply a baked transform twice. |
| Material | Authored ramp, noise, glint, emission or other explicitly defined material behavior, with its own parameters and clock. | Spell-owned hand-magic/effect layer, authored body/condition material, or explicit item modifier. These retain distinct owners even when they use the same filter implementation. |

Implement these as separate Pixi filter implementations with neutral identities and explicit inputs. Do not install all three on every Sprite. If an explicit swap and tint coexist, source-colour classification/swap precedes tint; a subsequent authored material precedes world lighting. Preserve authored material stack order. Do not silently add gamma treatment or rename a brightness ramp as a precise swap.

For exact matching at translucent PNG edges, use original straight RGB bytes. Unpremultiplying rounded 8-bit pixels cannot recover every original colour. The current raw PNG decoder can supply an additional reference **only for sources that need precise swap**; no global duplicate decode. Test close but unmapped colours and partial alpha. Existing nonzero tolerance/hue replacement, where actually authored, belongs to material treatment, not this exact operation.

### 4.1 Connect existing data rather than inventing spell exceptions

- `LayerColors.mode = paletteSwap` currently often describes a brightness/noise ramp. Audit actual operands and route that behavior to material; do not bulk-relabel all such JSON as exact swaps. Remove unreachable legacy modes only after source-use checks.
- Thirty-five media definitions contain `paletteSwap`, currently without a runtime reader. Trace those definitions through storage and `resolveMedia`/`mediaOccurrences`; connect genuine runtime swaps and record already-baked treatment accurately. The separately rejected per-projectile-instance field is not that working asset contract.
- `StudioActorLayer.material` is copied into `RigLayer`, but actor rendering never consumes it. Current catalog inspection found no non-null authored assignments, so this is an incomplete supported consumer, not proof of current data being ignored. Resolve an owning spell's existing material onto its designated hand-magic/effect layer. Do not infer effect ownership from a body parent or from the name `weaponGlow` alone.
- Preserve explicitly authored body materials, item suppression/priority and modifier glints/emission. Ordinary clothing tint is not a timed material event. A white base tint must not discard an independently authored glint/emission if present.
- Retain actual equipment/appearance changes as changes of the corresponding part; expose a temporal operation when the appearance changes. Do not turn every static coloured shoe/leg into a material-operation track.

Any needed client schema adjustment is narrow, source-derived and connected to its assembler/type generator in the same step. Current tracked JSON is authoritative; do not re-import Pygame authoring over it or repair a client issue with a spell-name switch.

## 5. Lighting through the same Sprite path

Move the existing receiving mathematics into a dedicated bounded Pixi filter attached only to a receiver needing it. Bind supplied geometry/normal companions, original-frame sampling, occurrence-to-world transform, camera basis, inverse-transpose normal transform and actual positioned emitters. Map the filtered Sprite back to the **original** source coordinates; cleanEdge's extra texture pixels do not double geometry coordinates. Preserve colour coverage where a solid-depth sample is absent.

**Human correction, 11 October:** backend effective light categories govern native perception; they do not multiply artwork RGB or supply shader illumination. Remove categorical cell gains, their interpolation and ambient/base-response multipliers. Preserve current-versus-memory disclosure as explicit remembered-state styling, separate from lighting. Neutral source colour stays unchanged without an actual emitter. Do not invent a global or ambient multiplier to replace it. The subsequent explicit request for directional-light testing is implemented as an authored source with a nonzero world-space `directionToSource`, linear colour and intensity, using the same receiving normals/filter as positioned lights. It is not derived from backend categories and is absent unless explicitly configured in `world.lighting.directionalSources`.

Use linear arithmetic for light, with one defined decode/encode boundary around ordinary colour. Preserve the separate Factory linear-radiance path, including RGB at alpha zero, near/far order, source registration and emitted energy. A default RGBA filter must not erase that energy. Migrate its image sampling/emission to the ordinary Sprite/filter route while keeping effect-specific geometry operations narrowly scoped. Reuse existing source/geometry definitions rather than inventing a G-buffer or global depth compositor.

Use Fireball's existing authored emitter curve once per logical impact. Its receiving smoke can remain lit by other actual disclosed lights after emission fades when their installed definitions supply that source. Other spells' world emitters remain deferred as previously agreed. The installed standing/wall torches currently provide lit-state and flame animation art, but no client emitter colour/intensity/range definition; do not infer one from bright pixels or native categorical light. Record that source gap. Preserve static floor/disclosure caching; moving direct light invalidates only the affected receiving result, not source decoding or character cleanEdge.

Demonstrate the change in the real Fireball recording and existing environment: visible light variation over time, correctly oriented receiving normals, unchanged neutral appearance and rotation during the event. Retain the selected Fireball/wall front/behind interaction from the general plan as a bounded effect consumer. If that particular interaction remains unimplemented, report it separately and continue the other steps; do not call a CPU coordinate test a GPU lighting demonstration.

## 6. Camera changes during playback

Replace Q/E's `showPrefix(operation - 1) → prepareNext → seek` flow. A camera change updates the view of the currently displayed state, operation time, ongoing tails, lights and feedback. It must not publish the preceding historical state or reset any effect clock.

Maintain the desired quarter independently of the last published quarter. Coalesce rapid input; guard publication with the existing session generation and a current view-request ticket. Continue sampling the displayed quarter while missing view resources prepare: do not enter playback's global `preparing` freeze. Publish a coherent new view sampled at the current playhead, not the captured keypress time. If playback crosses an operation boundary, reconcile preparation with the now-current operation; a seek, reload or case change supersedes the old request. Reuse current sources and prepare missing quarter sources without compiling an entire recording before rotation can complete. Keep the world point at the viewport centre fixed, and retain zoom and inspection state.

The present projection and art define four quarters. “Smooth rotation” here means responsive, uninterrupted changes between those authored views while a spell plays. This does not authorize new continuous-angle art, camera wobble or a fabricated 3D character rotation.

After the current view and its admitted playback lookahead are ready, prefetch the distinct required sources for the two adjacent quarters, `(quarter + 1) % 4` and `(quarter + 3) % 4`. Derive those dependencies from the same source selectors for the current admitted scene/operation and retained effects; do not compile the whole recording or scan the whole library. This baseline preparation covers fetch, worker decode and **GPU upload**, including required colour, numeric companions and material donors. Reuse identical TextureSources across views. Do not publish a view, create another animation clock or run future gameplay while preloading.

Use `ResourceStore` and its leases, worker decode and Pixi preparation calls. Add background admission within those existing owners: current rendering, explicit camera requests and next-operation preparation have priority. Feed only bounded background work when the frame has room; yield when foreground work or frame pressure appears. The present `preloadSceneImages` launches all requests together and Pixi's upload queue has no foreground priority, so enqueueing two entire views through that function unchanged would not satisfy this requirement. Track requests already in flight and stop feeding stale/unneeded adjacent work on case/release/context change. Release superseded leases only after their in-flight work completes safely; never destroy sources still used by playback or an upload. Avoid putting a large speculative queue ahead of urgently needed textures. Individual GPU uploads are not preemptible; measure their actual cost rather than promising that asynchronous code is free.

Once those sources are GPU-resident, rotation needs view-dependent registration/order and drawing, not another network/decode/upload round for them. If measurements show that remaining work causes a hitch, prepare the current adjacent view's small derived targets/display handles incrementally through the same prepared-view owner. Do not keep two entire operations sampling or rendering every frame. A previously prepared view is still sampled at the current playhead when used. New content or an evicted source may require preparation; retain uninterrupted foreground playback in that case. After a turn, update which two views are adjacent. Keep this finite and demand-based, without a general background-job framework or a new cache manager.

Camera changes may update view-dependent preview images but do not replace the timeline's semantic rows, expansion, scroll or selection. Existing resize/scroll preview retention remains intact. Do not rebuild a full recording trace merely to retain its unchanged timing and track identities.

## 7. Blood and settled residue

Use the existing blood templates, source ellipses, deterministic selection, accumulation and lifetimes. The dedicated comparison calls unmodified Pygame residue functions on the same actual recorded deposits. It reproduces compact Pygame puddles versus added NDClient streaks.

The current residue borrows the whole floor image and geometry. Its surface shader reconstructs positions on the tile's side faces before evaluating blood. Bypassing that reconstruction removes the elongated streaks. Restore the floor-plane receiver for these floor deposits, at their admitted support height and footprint, without sampling the tile's vertical sides. Keep it ordered with the floor through Pixi. This is not a new all-surface decal system or a reason to remove geometry from actual lighting.

Pygame also rasterizes residue appearance on a 64×64 source grid; NDClient generates a 128×128 density field and evaluates appearance/noise at display fragments. Match the original source-grid appearance and projection in the GPU residue owner so zoom does not generate new speckles. Compare complete source colour/alpha silhouettes against the actual Pygame result under neutral light, not only density values; then validate new linear world lighting separately. Do not copy Pygame's encoded-colour light multiplication into the lighting filter. The diagnostic's 98.78% silhouette overlap is not exact final-colour parity. Preserve future explicitly supported non-floor recipients under their existing semantics; do not extend this fix to invent wall drips.

Verify settled and accumulating deposits in all four camera quarters, including replay/seek and zoom. Keep the density generation on the GPU if its source-space output matches; no routine Python/CPU render dependency in the client.

## 8. Death and witnessed visibility

### 8.1 Client work: finish the received event

The original Fireball case already contains the complete killing event. All six observers lose sight at impact (~1.311s); the explosion runs to ~3.227s and death falls to ~3.561s. The caster remains alive. Client reduction removes its last visual contact at impact and the renderer consequently removes it before the event ends.

Keep canonical HP/death/sensory reduction and action legality unchanged. In presentation, associate that death-caused display loss with the admitted causal event. Retain its already received visual context, caster, effects and reactions through their actual authored end, including death falls and tails. Apply the pending visibility change after that event's visual completion and keep the witnessed aftermath inspectable as remembered state. Do not animate an unseen actor's future state or revive targeting from a remembered pose.

This applies only to sensory loss caused by the lethal result of that event. Unrelated blindness, fog, range, ordinary occlusion and new independent observations retain their own semantics. Seek/prefix rebuilding must produce the same final display, not rely on playback having visited every frame. Simultaneous observer deaths cannot erase their own remaining effects. No invented future facts, automatic audience reassignment or spectator framework.

### 8.2 Separate proposal: continued native sight after death

If the user wants a dead character to receive later native observations, client retention alone cannot supply unreceived data. The narrowly identified proposal is to remove only the **DEAD-owned visual-denial modifier** in engine `dnd/creature_transforms.py`, leaving incapacitation, action/movement denial, light suppression, corpse/life mechanics and independent visual-denial owners intact. Existing `SensoryFact` fields suffice; no SDK/schema change is indicated.

This also means DYING/STABLE → DEAD restores sight when no other owner denies it, and initially DEAD creatures retain their authored sight. DYING/STABLE and independently applied Unconscious/Blindness remain unchanged. Normal LOS, range and light still apply. It does not extend an already terminated encounter. These are explicit consequences, not client-side details.

**No backend implementation is authorized by this plan.** Present this small proposal for explicit approval before touching those files. If approved later, use a separate change with focused modifier-ownership and real native-to-player observation tests, including death plus independent blindness, revival, continued movement of another visible creature and inability of the dead actor to act. Client renderer work proceeds independently.

## 9. Studio and preserved behavior

The Studio visualizes the same compiled sources, clocks and operations as gameplay. Preserve these user decisions through the migration:

- Full composed Body preview, including its attached character effects; individual source parts collapsed by default. Attached effect operations are visible subordinate tracks, with material operations subordinate to the affected effect. Indentation shows causal ownership, not arbitrary padding of the Body preview.
- Foreground/background media are components of one spell media group, subordinate to the owning action. Their existence alone does not make two unrelated operations. Static clothes tint is baseline appearance, not a material event.
- Preview labels state source frame count and sampled preview count. Use the shared decoded sources and rendering functions, with consistent source framing; no second loading/rendering implementation for the bar.
- Tracks appear on recording load before Play and remain at pause/end. Expanding, resizing, scrolling or rotating preserves timeline position and selection. Schedule preview work in bounded batches so resident-source thumbnails do not monopolize a frame.
- Frame markers remain authored frame markers. Source FPS and sampled animation rate resolve presentation time. One displayed clock drives body, attached effects, transitions and media. Do not invent millisecond authoring markers or add new Haste semantics.
- Live living actors return to Idle with retained facing. Natural Studio completion keeps visible living Idle advancing with recording time/cursor fixed at the end; explicit Pause or seek freezes the inspected frame and every animation. Corpses retain the final death pose/facing. Preserve replay-from-start, zero-duration bookkeeping progress, lookahead and causal preparation holds.
- Burning Hands' launch source is sampled at the authored release/full-extension frame and stays fixed for that emission. The effect material belongs to its magic layer. Do not replace this with a continually following hand socket or a guessed offset while changing the renderer.
- Healing/damage feedback retains recipient, amount, semantic type and available damage type. Preserve event/log views, FPS display, inventory/choice interactions and subjective-data boundaries.

Remaining full-port authored consumers discovered by the scan stay in the general plan/progress inventory, with exact evidence in the presentation audit. They are not silently completed by this renderer repair and not grounds for unrelated backend work.

## 10. Implementation order and owners

Every step changes the production path used by both app and Studio. Keep the work reviewable; no standalone demo as a substitute. During implementation, use a plan-adherence subagent plus anti-slop and anti-OOP reviews as required by repository instructions.

**Current user-directed order:** complete this renderer chapter and establish its single production drawing path before resuming general N3/N4 implementation. Partial general-plan changes already written remain preserved and explicitly unverified. The current step evidence and remaining renderer acceptance are tracked at the top of `NDCLIENT_IMPLEMENTATION_PROGRESS.md`; this sequencing does not reduce the subsequent full-port scope.

**11 October feedback integrated into the current steps:** retain the verified material-branch fix for disappearing Fireball recipients, preserve the authored final blend when scoped filters are enabled, and remove backend light-category RGB multiplication under §5. Verify projectile release/direction/contact against actual native targets. Replace misleading spell/weapon capture setups through the existing server capture procedure and repair stale presentation pins without editing delivered events. Trace the measured Call Lightning playback hitch separately from scenario correctness. Record each result in progress, then continue the complete client plan; this feedback does not open another renderer architecture phase.

| Step | Work and existing owners | Completion evidence |
| --- | --- | --- |
| 1 | Correct source/colour records and consumers in `presentation/{actors,media,items,item-material,spells,attacks}.ts`; keep actual ownership. Correct the audited source-unit conversions across media consumers (§3.4). Add the three filter implementations under `rendering/`. | Nonwhite tint; original/unmapped exact swap; Magic2 spell material with unchanged physical body; dropped/equipped tint agreement; calibrated paired-source dimensions and unchanged valid legacy sprite/socket conversions. |
| 2 | Replace ordinary universal allocation in `composition.ts`; adapt `body-composition.ts`; restore native environment decoding; add retained native → cleanEdge 2× source pass. | Original floor detail; approved cleanEdge comparison; stable dimensions/pivots/animation; migrated consumers allocate no hidden Mesh and do no source redraw on zoom. Full removal is the shared steps 2–3 gate. |
| 3 | Migrate lighting, paired image/radiance and remaining ordinary surface consumers; retain/extract genuine effect geometry from `surface-shaders.ts`. | Fireball lighting and burst shown against the recorded world area under the final texture policy; raw companion/radiance integrity, fixed-character neutral/component controls, existing procedural effects retained. Delete ordinary fallback only once these consumers have real destinations. |
| 4 | Correct floor blood receiver and source-grid appearance in `residue-media.ts`, `residue-fields.ts`, `residue-shader.ts`. | Pygame/current/corrected comparison for the same actual deposits and all four quarters; no side-face streaks or zoom-dependent blood pattern. This step may proceed earlier independently. |
| 5 | Correct Q/E in `app/main.ts`, `app/playback.ts` and relevant session view preparation; incrementally preload adjacent dependencies through the existing resource owner; preserve Studio semantic rows in `workspace.ts`, `recording.ts`, `timeline.ts`. | Active spell continues, adjacent ready sources need no new loading/upload on rotation, prefetch yields to foreground, rapid Q/E ends at desired quarter, stale work cannot overwrite selection, centred view and stable tracks. |
| 6 | Implement causal presentation retention for admitted lethal events in existing presentation commits/scene sampling/actor visibility owners. | Original Fireball, cold seek and final aftermath remain explainable through the event; unrelated visibility rules and canonical death remain correct. Backend proposal is separate. |
| 7 | Remove obsolete routing/uniforms/source loads/tests, run combined visual/lifecycle/performance checks, update progress with evidence and unresolved full-port work. | §11 passes; no catch-all ordinary path survives; no false claim that remaining client scope is complete. Continue the general plan's unblocked work. |

The rendering audit includes the complete 21-file keep/replace/delete map. Delete unused GPU physical-mask/support bindings and obsolete depth-pass uniforms when removing their dead route; retain metadata and CPU support data actually used by ordering/picking. Do not revive unconsumed delivered metadata as an invented prerequisite. Keep character-review's independent source oracle; migrate its display to shared filters or retain it explicitly as a bounded inspection harness, not a second production renderer.

## 11. Acceptance

Read `HOW_TO_TEST.MD`. Prefer existing real recordings and source assets. Test observable behaviour and source/reference agreement, not a duplicate of the new implementation. Build/typecheck/unit success is necessary but does not prove visual correctness.

| Area | Required check |
| --- | --- |
| Source fidelity | Native environment dimensions and small grout details; numeric maps byte-exact; no averaging branch on environment colour. Preserve Sprite frame-notification regression. |
| Colour | Nonwhite tint/white identity; exact mapped/unmapped/nearby/partial-alpha pixels; no extra gamma; correct material target; real existing media swaps traced for pre-baked storage; dropped item colour. |
| Characters | Modular physical assembly, animal and Goblin/Demon component control; cleanEdge physical 2× with logical size/pivot/socket unchanged; neighboring atlas cell cannot bleed; original shadow source and effect isolation. |
| World dimensions | Exercise every affected media producer in the scale audit, preserving valid legacy-source conversions. For Fireball, display its recorded centre/area with the burst under native-environment and character-cleanEdge textures; compare with the accepted proof at equal grid magnification. Check all quarters and multiple zooms. Keep damage radius, visual smoke extent and light falloff separate; self-consistent colour/depth alone is insufficient. |
| Lighting | Existing Fireball emitter/receivers visibly respond at multiple times and quarters; neutral/light-off comparison; correct normal orientation; paired alpha-zero emission remains; wall interaction honestly reported. Backend effective-light categories alone leave current artwork RGB unchanged. Adding a neutral scoped filter preserves the occurrence's normal/add/screen blend. |
| Blood | Independent Pygame source-function reference for the same deposits; complete image silhouette/colour, floor support, accumulation, final state and all four quarters. |
| Camera and Studio | Rotate during projectile, impact and persistent effect; rapid Q/E; cold missing-quarter preparation while playback crosses an operation boundary; rotate then seek/reload/select another case. Compare foreground frame times with adjacent prefetch active/inactive; verify it yields under pressure and preloaded sources trigger no fetch/decode/upload on rotation. Preserve advancing time, feedback, centre, zoom, row identity/expansion/scroll. Before Play/paused/end previews, divider drag, replay start and no full recording rebuild for rotation. |
| Lethal event | Original six-observer Fireball versus surviving-caster Fireball; canonical contact disappears at impact while admitted presentation remains through its end; complete fall/final pose; same aftermath after cold seek; unrelated sight loss unchanged; no future unseen actor motion or retained target legality. |
| Lifetimes/cost | Repeated zoom, camera, replay, case changes and context restoration do not leak sources/targets or corrupt another view's samplers; stationary paused frame does no unnecessary world submission/source processing. Warm zoom has no source decode/upload or native/cleanEdge recomposition. |

Adapt tests that encode rejected behavior: `environment-reduction.browser.mjs` currently requires half-size averaged colour; `sprite-sampling.browser.mjs` treats two ordinary routes as the contract; `idle-facing.browser.mjs` explicitly expects the Fireball caster to disappear at impact; `particles.test.ts` requires the faulty whole-floor blood receiver. Replace those specific expectations while preserving independent lifecycle, sampling, facing, pause, native quantity and landing-clock checks.

Measure cold load, warm case switch, action boundary, zoom and rotation separately. Record browser/device pixel ratio, viewport, renderer, draw/pass/source counts and CPU preparation versus GPU work. Use existing counters first. Do not claim a cause of 99% RTX utilization from static inspection or a software-WebGL run; use the user's hardware/browser for hardware conclusions. Existing source caches are real and must be retained. No invented FPS threshold, arbitrary cap or cache rewrite substitutes for measuring avoidable work.

## 12. Review and references

Required document reviews: **anti-slop/rendering**, **anti-OOP/ECS**, and **camera/visibility boundary**. Review both this chapter and the updated general-plan instructions. Results and corrections are recorded in the audit's review section. A document review is not implementation or visual acceptance.

- [Pixi filters](https://pixijs.com/8.x/guides/components/filters): supported ordered, scoped shader operations on scene objects. Installed `pixi.js` 8.22.0 `FilterSystem.mjs` supplies Sprite-coordinate mapping, valid pooled-input bounds and minimum-chain resolution; `DisplacementFilter.mjs` demonstrates companion samplers.
- [cleanEdge author implementation and MIT license](https://torcado.com/cleanEdge/): use the actual algorithm, not a similarly named invented interpolation.
- [Existing reference comparison](NDCLIENT_PIXEL_RENDERING_REFERENCE_REVIEW_2026-10-11.md): Pygame/NeuroClient/Unity findings and the already viewed character comparison. Their code is evidence; current user decisions control this plan.

Plan review status: **passed** anti-slop/rendering, anti-OOP/ECS and camera/visibility reviews after corrections. The later adjacent-view preload addition passed targeted rendering and camera review; the scale/recorded-area/final-texture-policy addition passed targeted anti-slop/rendering and anti-OOP/ECS review. See the audit's recorded disposition. No renderer, authoring, assets or backend implementation is claimed by this document.
