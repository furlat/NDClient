# Native VFX runtime contract (17 October 2026)

Status: **prototype implemented for Fireball, Magic Missile and Fire Bolt**
(commits 25cb447, 8b4db36). The Factory guidance below is the user-requested
contract for new effects; it does not replace the working contract in
[NATIVE_VFX_FACTORY_HANDOFF.md](NATIVE_VFX_FACTORY_HANDOFF.md) until accepted.
No new Factory content is authored against it before Gate A.

## Principle

A spell effect phase is drawn as a function of `(source time, variant,
path)`. The GPU evaluates it. The CPU spawns it once, writes one clock texel
per frame, and retires it. It is still a full 3D effect: meshes, particles,
materials and lights are drawn every frame from the current camera.

## How it works now (baked particle playback)

Factory effects are still authored as Godot scenes with particle simulations,
animation players and scripts. `tools/bake_native_effects.gd` runs each clip
once offline, exactly as the client builds it, and records:

- **Particles:** every particle's transform, colour and custom data, 60 times
  per source second, read back from the GPU. Collisions, sub-emitters and
  turbulence are recorded as simulated.
- **Changing values:** light energy, decal fades and material clocks, as
  values per frame.
- **The scene without anything that runs:** no AnimationPlayer, script,
  collision shape or simulation.

At play time an emitter reads its recorded state for the current source time
(`presentation/baked_particles.gdshader`). Any moment draws directly, so a late
start, a seek or a replay costs the same as playing, and the result is
repeatable. Each clip has three seeded variants; a cast picks one by its seed.

Moving projectiles keep their root's path as a small texture written as the
cue plays. Particles left behind are placed by where the root was when each
was born, and GPUTrail3D ribbons are computed from that path
(`baked_trailing_particles.gdshader`, `baked_path_trail.gdshader`).

## Measured (live route, Fireball portion, same machine)

| | Native | Baked |
| --- | --- | --- |
| Effect sampling per frame (`native_sample_sources` mean) | 0.29–0.33 ms | 0.18–0.19 ms |
| Spell sampling total (`native_spell_sample` mean) | 0.54–0.63 ms | 0.47–0.49 ms |
| Building one effect | 1–4 ms (after L7) | about 1.4 ms |
| First use | path-by-path admission, 37–317 ms per clip | one file on a worker (about 155 ms for Fireball's explosion), textures created one per frame |
| Waits during Fireball | 1–2 one-frame waits per cast | 0–2 one-frame waits (floor receivers, not effects) |
| Disk / memory for the three spells | sources | 28 MB of recordings (3 variants each) |

Look: within 1–7% of drawn pixels of native for static clips (edge pixels);
flights match native in coverage and placement while flying. Known
differences: after a projectile stops, the native ribbon keeps a longer
bright head; native ribbons draw a fragment before launch that baked trails
do not.

## Rules for Factory authors

What the bake handles, so authors may keep using it: GPU particle
simulations of any kind (collision, sub-emitters, turbulence, custom particle
shaders), AnimationPlayer property tracks, light and decal animation,
GPUTrail3D ribbons, clocked shaders.

What it cannot reproduce (keeps the clip on the slow native path):

1. **CPU mesh trails** (`Trail3D.gd`, ImmediateMesh built per frame). Use
   GPUTrail3D or a particle trail instead.
2. **Camera-dependent source parameters** (`view_direction` bindings). Do view
   dependence in the shader (billboard modes, VIEW/INV_VIEW_MATRIX).
3. **Scripts that change the effect at play time** other than the above.

What keeps an effect cheap:

4. **Particles alive at once × lifetime is the size.** Recording size is about
   48 bytes per live particle per 1/60 s. Fireball's explosion (703 live
   particles over 4 s) is 4 MB per variant. Prefer fewer, larger particles.
5. **Finite clips.** Continuous emitters are recorded for one longest
   lifetime past the clip; persistent loops replay their recorded hold.
6. **Shared shaders.** Each distinct shader is a pipeline to compile before
   first use. Reuse materials across effects where the look allows.
7. **Lights stay few.** Effect lights are bridged to the 2D light table; one or
   two per effect.

## Next steps

- Bake the remaining spells (one command; about 1 s per clip per variant).
- Put the bake into the asset preparation step so recordings are rebuilt when
  Factory sources change (the clip hash already rejects stale recordings).
- Optional: randomize a variant in the shader (mirroring/rotating the
  recorded layout per cast) instead of storing more variants.
- VRAM (plan step L8): half-float recordings could be packed tighter.
