# Baked spell effects in the client: report for the Factory agent

17 October 2026. Written for whoever authors spell VFX in
`C:/Users/tommaso/Documents/assets/VFXFactory`. It describes what the client
now does with your effects, what that costs, which effects it can't take yet
and why, and how to author effects that run cheaply. The runtime contract is
[NATIVE_VFX_RUNTIME_CONTRACT_2026-10-17.md](NATIVE_VFX_RUNTIME_CONTRACT_2026-10-17.md);
the working handoff is [NATIVE_VFX_FACTORY_HANDOFF.md](NATIVE_VFX_FACTORY_HANDOFF.md).

## In one paragraph

The client no longer simulates your particle systems while the game runs. An
offline tool (`tools/bake_native_effects.gd`) builds each clip exactly as the
game does, runs it once, and records every particle's transform, colour and
custom data 60 times per second, plus the light, decal and material values
that change. In play, each emitter reads its recorded state for the current
moment on the GPU. It is still your 3D effect, drawn live from the current
camera with your meshes, materials and lighting; only the simulation is
precomputed. Any moment can be shown directly, every playback is identical,
and nothing about the effect runs on the CPU between its start and its end.

## Why

Your effects are Godot scenes that run: particle simulations, animation
players and scripts. The client had to drive them from GDScript every frame,
replay their history to start them late or seek, and load their resources one
by one before first use. Measured on Fireball before the change:

- **First use:** resources admitted one path per frame, 37–317 ms per clip;
  Fireball's explosion took about 314 ms over 47 frames. Before the L7 work
  this showed up as a 43–114 ms freeze in the middle of the cast.
- **Every frame:** about 0.3 ms per frame just to step the effect's own
  simulation clocks, animation players and scripts.
- **Not repeatable:** two runs of the same effect with the same seeds differ
  when started on different frames, so nothing could be checked pixel for
  pixel.

After baking (live route, same machine, Fireball portion):

| | Native | Baked |
| --- | --- | --- |
| Effect sampling per frame | 0.29–0.33 ms | 0.18–0.19 ms |
| Building one effect | 1–4 ms | about 1.4 ms |
| First use | path-by-path admission | one file loaded on a worker, its textures created one per frame |
| Waits during a Fireball cast | 1–2 one-frame waits | none caused by effects |
| Repeatability | differs between runs | identical every time; any moment shown directly |

## What the bake reproduces

Use any of these freely; the bake records the result, so their cost is paid
offline:

- GPU particle simulations of any kind: collision (Fireball's ground box),
  sub-emitters (Fireball's ribbon sparks), turbulence, custom process shaders,
  high particle counts during the simulation.
- AnimationPlayer property tracks: emitter toggles, light energy and
  visibility, decal fades, material parameters.
- Clocked shaders (`source_clock`, `sandbox_source_seconds`).
- GPUTrail3D ribbons, including billboard mode: they are redrawn from the
  projectile's actual path at play time.
- World-space particles on moving projectiles: each particle is placed where
  the projectile was when it was born, so trails of sparks behave as before.
- Effect lights (OmniLight3D): bridged to the 2D light table as before.

## What the bake cannot take yet (these clips still run natively)

| Clip | Reason | What would fix it on the Factory side |
| --- | --- | --- |
| `spells/fire_bolt/default/travel` | CPU mesh trail (`Trail3D.gd`, an ImmediateMesh rebuilt every frame from recorded points) | Use a GPUTrail3D ribbon or a particle trail instead |
| `spells/guiding_bolt/default/travel` | Same `Trail3D.gd` | Same |
| `spells/scorching_ray/back/lifecycle` | Same `Trail3D.gd` | Same |
| `spells/command/back/lifecycle` | An emitter is created while the effect plays (`@GPUParticles3D@…` added at run time) | Put every emitter in the scene from the start (hidden or not emitting until needed) |
| `spells/produce_flame/palm_back/palm` | A projectile scene is instanced while the effect plays | Same: instance it in the scene up front |
| `spells/sanctuary/back/lifecycle` | A camera-dependent source parameter (`view_direction` binding written by script each frame) | Do the view dependence in the shader (billboard modes, VIEW / INV_VIEW_MATRIX) |

The client may later bake CPU mesh trails itself (a vertex shader can build the
same strip from the path). Factory-side fixes are simpler and remove the
dependency.

## Cost model: what makes a baked effect cheap

The size of a recording is about **48 bytes per live particle per 1/60 s**,
per variant (three variants are stored, so a cast can pick a different random
layout). Only particles that are ever alive, and only the frames where any is
alive, are stored.

Largest recordings (all variants):

| Clip | Live particles | Recorded length | Size |
| --- | --- | --- | --- |
| Fireball explosion, fire | 735 | 4.0 s | 12.4 MB |
| Fireball explosion, smoke | 715 | 4.0 s | 12.3 MB |
| Chill Touch impact | 400 | 8.0 s | 8.6 MB |
| Ray of Frost travel (`recovered/travelIce`) | 254 | 3.0 s | 6.6 MB |
| Mage Armor (persistent) | 80 | 8.0 s, cut at the limit | 4.5 MB |

All 66 baked clips together are 97 MB. Most are under 1 MB.

What this means when authoring:

1. **Live particles × lifetime is the cost.** Prefer fewer, larger particles
   with richer textures over many small ones. Simulation complexity is free.
2. **Keep clips finite and short.** The bake records up to 8 s. Continuous
   emitters are recorded for one longest particle lifetime past the clip.
   Persistent effects (Bane, Mage Armor) loop their recorded hold, so make the
   hold loop seamless within the first 8 s.
3. **Hidden emitters are free** (never-alive particles are not stored), but a
   hidden emitter that still simulates adds bake time only.
4. **Prefer one shared shader per look.** Each distinct shader is a pipeline
   the game compiles before first use; reuse materials across effects where
   possible.
5. **One or two effect lights.** Each is a light-table entry every frame.
6. **Avoid `DRAW_ORDER_LIFETIME`** for alpha-blended particles (Burning Hands
   uses it): the baked playback draws in index order, so overlapping smoke can
   blend in a slightly different order. Index or view-depth order matches.
7. **Built-in particle trails** (`trail_enabled`) work, but their history is
   rebuilt from playback, so a seek shows a short trail for one trail length.
   GPUTrail3D ribbons have no such limit.

## Quality notes

- Static clips (casts, impacts, areas) match the native frames within 1–7 %
  of drawn pixels, almost all single edge pixels.
- Flights match native coverage and placement while flying. Two small known
  differences: after the projectile stops, the native ribbon keeps a longer
  bright head; before launch, the native ribbon draws a fragment of
  not-yet-filled segments that the baked trail does not.
- Every cast picks one of three recorded variants by its seed. More variants,
  or variation in the shader (mirroring or rotating the recorded layout per
  cast), are possible later.

## Workflow

After changing an effect in the Factory and re-importing it into the client:

```sh
# from the client root, Windows Godot 4.7.2 from WSL
G=/mnt/c/Users/tommaso/Documents/Dev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe
# bake one spell (or --all), three variants
$G --path . --rendering-method forward_plus --rendering-driver vulkan --fixed-fps 60 \
   --script res://tools/bake_native_effects.gd -- --spells=fireball --variants=3
# compare baked against native, side by side (add --save=<dir> for frames)
$G --path . --rendering-method forward_plus --rendering-driver vulkan --fixed-fps 60 \
   --script res://tests/baked_effect_checks.gd -- --spells=fireball
```

- Results: `.runtime/baked-effects-report.json` (sizes, live particles,
  reasons a clip stays native) and `.runtime/baked-effect-checks.json`.
- A recording is tied to its clip definition. If the clip changes, the game
  plays the native source until the clip is baked again, and logs it.
- To see the native version of everything: launch with `-- --native-effects`.

## Ideas worth trying in the Factory

- **Author for the bake.** Expensive offline simulation is fine: collisions,
  turbulence, multi-stage sub-emitters, even a heavy physical simulation in a
  scratch scene. Only the live particle count and length cost anything at play
  time.
- **Design variation instead of randomness.** Three seeds give three layouts.
  If variety matters, author two or three deliberately different variants
  (e.g. spark direction, smoke shape) instead of relying on random seeds.
- **Separate the hero from the dust.** A few large hero particles carry the
  look; dust and sparks can be short-lived, which keeps recordings small.
- **Seamless holds.** For sustained effects, author the hold so its first and
  last frames match; the baked loop then has no pop.
- **Readable at the game's scale.** Effects are drawn at about 0.18 of source
  scale in a 2.5D view. Big silhouettes and strong value contrast read better
  than fine detail, and fine detail costs particles.
