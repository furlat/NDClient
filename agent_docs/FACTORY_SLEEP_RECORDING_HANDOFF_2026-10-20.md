# Factory handoff: Sleep recorded placement

The original default recorded Sleep area draws at the origin but disappears
when translated to the actual game target. Its source-local clipping matrix is
retained as identity. Keep the two actual-seat Sleep area-output failures red;
no source-art, default approach or runtime repair was made for this finding.

## Actual native probe

Receipt: `.runtime/tests/20261020T064208.584962Z/report.json` and
`sleep_placement_probe.log`: Forward+/Vulkan, exit 0, zero script/engine errors,
no owned processes left. Detailed samples and PNGs:
`.runtime/consolidation/sleep-placement-probe/report.json`.

The probe uses **one unchanged default recorded occurrence**, an isolated
384×384 viewport, the same source ages and the same camera-relative placement.
It translates the effect and camera together; it does not rebuild the source.

| Source seconds | Covered pixels at origin | Covered pixels at `[6,0,7]` |
| ---: | ---: | ---: |
| 0.25 | 1,654 | 0 |
| 0.65 | 3,730 | 0 |
| 1.00 | 6,950 | 0 |
| 1.50 | 7,575 | 0 |

Clip: `spells/sleep/default/lifecycle`; approach `recorded-0`; bundle
`assets/vfx/recordings/1b81a8502490db118ff7da57/0.res` (seed 1000).
The bundle declares private material `[0]` and exactly one material track:
`source_clock`, 469 values from 0 to 3.25 seconds. At every ordinary sample,
that private material's `sleep_world_to_source` remains the identity matrix.

A final **explicit private-material diagnostic intervention** sets only this
matrix to the inverse of the translated root transform. At source age 1.0,
the translated effect then recovers exactly **6,950 pixels**, with the same
maximum alpha **0.325490206480026** as the origin. This intervention is confined
to the ignored probe, is not a proposed hardcoded client uniform adapter, and
does not qualify ordinary translated playback.

## Source ownership and retained successor

The live source
`assets/vfx/sources/4a4e8903467f4f83a356/sleep_application.gd::update_geometry`
sets `sleep_world_to_source = global_transform.affine_inverse()`. The shader
uses this matrix to bound world-space smoke to the authored local footprint.
The recorded scene has no live source program; its declared recording tracks
advance `source_clock` but supply no placement-dependent matrix binding.

The client already places the occurrence at the actual target and replays all
declared recording tracks. A recorded constant matrix cannot express a
runtime root transform. The missing piece belongs to the source/export
contract: deliver an explicit source-local transform binding, or an equivalent
source shader that remains correctly local when the recording is placed.
The client should consume that declared contract, without discovering shader
uniform semantics from names or adding a Sleep-specific runtime branch.

Read-only inspection of complete successor `runtime-e102c29dec58524b` retains
the same default `recorded-0/1/2` paths and original native approach for this
clip, without an appended alternative. The `recorded-0` Resource is byte-for-byte
identical to the probed file. This confirms retention of the recorded program
record; it is **not** a native rerun of the complete successor or a claim about
every external dependency. Its translated recorded output still requires the
same qualification gate after installation.

## Required complete successor proof

Preserve the approved smoke, colours, opacity, radius and source timing. Seal
a complete successor with an explicit placement/private-material contract and
actual recorded-output proof at origin and translated/rotated/scaled roots,
paused ages, backward seek, loops and two simultaneous owners at different
transforms. One owner's placement must not alter the other's material. Keep
the ordinary actual-seat area checks required until that delivered path draws.
This is separate from the Insect Plague missing recorded material-clock export
described in `FACTORY_SWARM_RECORDING_HANDOFF_2026-10-20.md`.
