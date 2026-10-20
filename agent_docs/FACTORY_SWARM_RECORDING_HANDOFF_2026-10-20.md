# Factory handoff: Insect Plague recorded material clock

The installed complete package `production-bindings-c494177f9ef03e3d` contains
visible Insect Plague GPU output but three recorded variants that stay invisible.
Keep those three recorded-output checks **red**. No package overlay, source-art
change or client approach-policy switch was made for this finding.

## Original native evidence

Receipt: `.runtime/tests/20261020T055310.201665Z/effect_package_checks.log`,
with detailed results in `.runtime/effect-package-checks.json`:

- Full package gate: **3,986 checks, 39 failures**.
- Clip `review/insect_plague/default/lifecycle`, sampled at 0/25/50/75%:
  GPU covered pixels **[0, 1112, 1102, 1079]**; each recorded variant
  **[0, 0, 0, 0]**. Construction and sampling report no errors.
- The other **36 failures** are nine deliberately geometry-free inspection/pose
  clocks across four approaches each. They are separate from the swarm defect.
  The revised test classifies only the two exact sealed no-draw constructors,
  with no emitters and no other component programs, as `renderer_owned_interval`.
  Those rows remain exhaustive inventory entries with `sampled=false` and
  `draw_qualified=false`; actual actor treatment requires its separate output
  proof. The original failed receipt is preserved; this note does not claim a
  new complete package rerun.

## Exact recorded files

| Package path | Seed | Bytes | Declared timeline |
| --- | ---: | ---: | --- |
| `assets/vfx/recordings/5b3698bf7f4a9f70bb52d4f9/0.res` | 1000 | 511 | 865 frames, 144 Hz, 6 seconds |
| `assets/vfx/recordings/5b3698bf7f4a9f70bb52d4f9/1.res` | 8919 | 514 | 865 frames, 144 Hz, 6 seconds |
| `assets/vfx/recordings/5b3698bf7f4a9f70bb52d4f9/2.res` | 16838 | 512 | 865 frames, 144 Hz, 6 seconds |

Read-only decompression of the original Resource files shows that all three
omit `systems`, `trails`, `tracks` and `private_materials`; these use the empty
defaults in `assets/vfx/format/recording.gd`. The empty particle-system list is
not itself an error: this swarm is mesh/shader based.

Each recording references a PackedScene containing **14 MultiMesh groups**,
their original geometry, trajectory texture and swarm shaders. Geometry is
present. For example, variant 0's material
`assets/vfx/shared/resources/e6dc23f10d3b36d6efafe1b368a68f7f95c1612e841b6f008bc8f9c694bf5952.res`
explicitly serializes `shader_parameter/gpu_swarm_seconds = 0.0`.

The live program
`assets/vfx/sources/26c98431fd81e43423d8/recorded_swarm.gd::sample` advances this
uniform for every source material using its authored rounded source clock and
formation/loop rule. The baked scene has no live source sampler, and its empty
`tracks` provide no replacement material-clock samples. The retained shader
therefore stays at the zero-time formation, where the insects have zero size.

Client `presentation/baked_effect.gd::sample` already applies declared recorded
material tracks through `set_shader_parameter`. It cannot infer this source's
clock or mutate shared materials in the absence of that recording data. This
is an incomplete recorded clock/material export, not evidence that the client
cannot decode the recording format or that the export contains no geometry.

## Required complete successor

Export the actual `gpu_swarm_seconds` source values and corresponding private
material ownership for all three recorded variants, using the public recording
track contract or an explicitly delivered equivalent. Preserve the approved
meshes, trajectory texture, colours, scale, formation and loop behavior. State
the source-clock sampling/interpolation rule; do not substitute an inferred
generic clock for the source's rounded formation/loop clock.

Seal and deliver a **complete successor package**, with reproducible native
proof that the recorded variants match their original source during formation,
sustain and tail, paused frames, backward seek, looping and two simultaneous
owners at different ages. Include the currently blank 0/25/50/75% samples and
prove one owner's clock cannot change the other's materials. Existing client
tests will retain the three failures until the successor's actual recorded
output is qualified. GPU construction cost is a separate performance question,
not a reason to accept blank recordings or silently select another approach.
