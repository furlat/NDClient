# Native VFX runtime contract (proposal, 17 October 2026)

Status: **proposal for the user to accept or change.** It does not replace the
working contract in [NATIVE_VFX_FACTORY_HANDOFF.md](NATIVE_VFX_FACTORY_HANDOFF.md)
until accepted. No new Factory content is authored against it before Gate A.

## Principle

A spell effect phase is a pure function of `(age, seed, endpoints, view)`.
The GPU evaluates it. The CPU spawns it once and retires it once, and writes
nothing about it in between.

Today's effects are Godot scenes that *run*: particle simulations, animation
players, scripts and lights that the client must drive from GDScript every
frame, and replay step by step to reach a given age.

## Why: measured cost of the current shape

Measured on `feature/opus-refactor` after the L7 work (`agent_docs/CLIENT_STRUCTURE_PROGRESS_2026-10-17.md`):

| Cost | Where it comes from |
| --- | --- |
| Mid-cast Fireball hold, 43–114 ms | The projectile is not ready about 70 ms into the cast. First-use admission loads one resource path per frame and then runs the program job: 37–317 ms per clip (Fireball fire lifecycle 314 ms over 47 frames). |
| About 1.1 ms of script per frame during Fireball | `native_spell_sample` (0.92–0.99 ms) plus support sync (0.2 ms): per effect, a 144 Hz tick loop pushing clock parameters into each material, `AnimationPlayer.advance`, manual `_process` calls into scene scripts, per-emitter `speed_scale` set and reset after draw, light energies, opacity bindings, layer masks. |
| Seeks, late starts, replays | Particle simulations cannot be sampled at an age. The client re-simulates history in bounded steps ("history preparing"), and output is not deterministic, so no byte-exact proof of reuse is possible. |
| 42.7 MiB VRAM and one extra 3D render per colour profile | Each appearance profile renders the effect world into its own full-screen target, then a colour-finish pass. |

## What the current sources contain

Survey of the 52 scenes selected by `authoring/sandbox/projectiles.json` (34 spells):

| Feature | Count | Why it needs the CPU |
| --- | ---: | --- |
| GPUParticles3D systems | 136 (125 with a ParticleProcessMaterial) | Stateful simulation: clocked per frame, replayed for seeks |
| AnimationPlayer | 37, with 328 tracks | Keyframes evaluated on the CPU, written into nodes and materials |
| OmniLight3D | 27 | Animated per frame, then bridged into the 2D light table |
| ShaderMaterial | 150 | Duplicated per occurrence so a script can push the clock |
| GDScript nodes | 31 (trails, controllers, light flicker, cutters) | Called every frame |

Fireball's explosion (`VFX_Explosion_B.tscn`) alone has 12 particle systems, a
collision box, one AnimationPlayer with 16 tracks, one Decal, one OmniLight3D,
9 shader materials, 39 Curves, 29 CurveTextures and 20 Gradients.

## Rules for Factory authors

1. **One clock.** Shaders read only `age` (global time minus the instance's
   start, given as an instance uniform). No script sets a clock, opacity or
   energy per frame. Lifecycle (enter, held loop, exit) is data the shader
   evaluates from `age` and the phase's close time, which is set once.
2. **Stateless particles.** Every particle is `f(seed, index, age)`: emission
   shape, initial velocity and spread, gravity, linear damping, orbit, and
   colour/scale/alpha/rotation curves over lifetime. Bursts and rates are a
   fixed spawn schedule by index.
   - Not allowed: collision (use a ground-height clamp; the ground height is a
     uniform), sub-emitters (author a second stateless system with spawn times
     derived from the parent formula), turbulence (offset by a noise texture
     sampled at position and age), attractors, custom `particles` shaders.
3. **No AnimationPlayer and no scripts.** Curves and gradients are baked into
   one small curve texture per effect (one row per curve), sampled by `age`.
   Travel is computed in the vertex shader from the endpoints and bend the
   client already passes. Trails sample that same path at earlier ages
   instead of keeping a history buffer.
4. **Shared shaders.** Use the client's shader set (additive card, alpha card,
   soft mesh shell, ground decal, ribbon; the client owns the list). Per-effect
   values live in the effect resource; per-instance values are instance
   uniforms. New shader code goes through client review so every pipeline can
   be compiled at boot.
5. **Lights are data, not nodes.** No Light3D. Declare offset, colour, radius
   and an energy curve over age. The client writes them into the light table.
   Effect geometry is emissive and is not lit by its own lights.
6. **Colour finish in the material.** The palette ramp is a texture lookup in
   the effect's shader, not a separate full-screen pass per profile.
7. **One file per phase.** All meshes, textures and curves embedded, no
   external scripts. The client loads it on a worker in one step.
8. **Deterministic.** The same seed and age give the same pixels. Seeking to
   any age costs the same as playing it.

### Budgets per phase (proposed numbers, to be tuned)

| Item | Budget |
| --- | --- |
| Draw calls | ≤ 8 |
| Live particles | ≤ 2,000 |
| Texture memory | ≤ 4 MiB |
| Main-thread construction | ≤ 0.2 ms |
| Script per frame | none |
| Ready after first request | one worker load; no on-screen shader compile |

## Migration of the current 34 spells

| Group | Size | Path |
| --- | --- | --- |
| Particle systems using only closed-form features (emission shape, velocity, gravity, damping, orbit; radial and tangential acceleration approximated) | about 109 of 125 | Automatic offline conversion, then visual review |
| Systems using collision (7), sub-emitters (4), turbulence (1) or custom particle shaders (4) | about 16 | Re-author in Factory |
| AnimationPlayer tracks | 328 | Bake to curve rows |
| Light nodes and light scripts | 27 lights, 5 scripts | Convert to light rows |
| Trail scripts (`Trail3D`, `GPUTrail3D`) | 6 | Path-sampled ribbons |
| Other scripts (`plane_cutter`, `shield_modifier`, `laser_activator`) | 5 | Re-author |

Converted effects will not be pixel-identical to today's simulations.
Acceptance is visual review per spell, which the handoff already lists as
outstanding for every spell's timing and placement.

## Client work this needs (not Factory's)

- An effect runtime that draws these phases in one shared effect pass or the
  main pass, with the existing 2.5D depth and draw-order rules proven by an
  order oracle.
- Boot-time compilation of the shared shader set.
- The timeline gives each instance its start time; sockets give endpoints once
  per phase, or again only when a socket moves.
- An offline converter from the current Factory scenes, with a per-spell
  report of what converted and what needs re-authoring.
