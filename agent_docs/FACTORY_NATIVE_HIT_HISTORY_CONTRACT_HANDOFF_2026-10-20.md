# Factory handoff: immutable actor-history material captures

This is a source-contract request for the complete installed
`runtime-e102c29dec58524b`. No source/art change or new native qualification is
claimed here. The client draft remains private; a seek-only implementation is
not being shipped as a completed shared provider.

## The concrete shared ownership defect

`assets/vfx/conditions/actor_history.gd::_snapshot` (lines 317–351) duplicates
actual layer ShaderMaterials with `duplicate(false)`. That correctly preserves
ordinary tint/flash/pose uniforms, but Texture2D references remain shared.

The client's full spell-hit treatment is evaluated by
`presentation/native_material_surface.gd` in a private 256×256 SubViewport.
`native_spell_hits.gd::decorate` binds that occurrence's ViewportTexture as
`native_body_surface`. Its authored clock changes for later samples, and the
surface can later be parked/reused when the finite hit retires. An earlier
history material therefore still references changing or recycled pixels. A
copied material is not an immutable capture of this treatment.

The existing 4,806-check original Blur/native material-transition proof covers
non-native Slashing flash uniforms. It does not cover this texture dependency.
Mirror's zero-delay current-pose mode and Banishment's held departure have
separate temporal needs; do not silently apply a rolling-history approximation
across all three modes.

## Existing public API boundary

The delivered helper accepts `set_actor_context`, `prepare_actor_context`
(allocation/binding only), and `sample`. Its normal sample automatically records
the current packet; an older explicit helper sample is followed by normal
current sampling through the occurrence. There is no public immutable external
texture capture/completion token or equivalent source-owned frozen-sampler
contract. Replaying the whole prefix every frame would still append a mutable
current texture and is not the proposed fix.

Please extend this existing actor-history capture owner, not add another client
manager or require a fake actor/pose/review fixture. The exact API spelling is
for the source author to choose; the following observable contract is required.

## Required capture contract

- Preserve the actual actor/condition owner, pose/material revision, source time,
  source layer order, transform, colour/alpha, normals/depth and original material
  treatment. No art swap, extra palette, lighting retune, downsampling, altered
  shader clock, or source-time quantization.
- A history/departure capture must own immutable evaluated colour and RGB24
  reversed-Z depth, or immutable material-texture dependencies with equivalent
  semantics. Later current-hit sampling, hit retirement, slot reuse and another
  recipient must not mutate its output. Keep immutable source Resources shared.
- Capture availability must follow actual GPU completion, with the exact
  requested/drawn sample identity retained. A material's previous `ready=true`
  is not proof that a newly requested clock has drawn. Pending capture cannot
  be labelled rendered. Use the normal preparation/capture owner and renderer
  fences; no CPU pixel readback or presentation-clock hold.
- Live sampling and restored-prefix sampling must use the same contract. Seek
  preparation may provide privately realized original actor layers and an
  authored absolute native-hit material clock; it cannot borrow a later live
  ViewportTexture. The finite hit envelope remains the client's actual result
  clock, not a second Factory event timeline.
- Retire rolling captures by the source's actual required delay window (Blur
  currently .08/.16/.24 seconds), retaining any necessary predecessor. Account
  for `history`, `pose_material_cache`, current draw bindings and departure
  `captured_packet` before recycling textures. Held departure survives for its
  actual owner/removal fade; it is not truncated to Blur's window. Camera
  recapture changes optical realization, not original admission/position.
- Demonstrate bounded targets/bytes and cleanup across two owners, view changes,
  reverse seek, loop, withdrawal, remove/reapply and teardown. Do not grow a
  texture list for the whole lifetime of a long-held condition.

Current measured export boundary: saved native-hit PNGs are **256×256, 8-bit
RGBA** (`.captures/native-spell-hits/fire-bolt-age20.png`, `fire-bolt-age120.png`,
`magic-missile-native.png`), 262,144 uncompressed colour bytes each. This is
readback/export format, not proof of the native GPU attachment format or total
allocation. The capture qualification should report actual attachment formats,
colour/depth targets, maximum live captures and retained GPU bytes; do not infer
VRAM usage from PNG size or claim a frame budget from dimensions alone.

## Genuine two-seat recordings, unchanged originals

All paths are under `C:/Users/tommaso/Documents/Dev/NDClientGodot/`.

| Fixture | Actual independent original evidence |
|---|---|
| `tests/fixtures/schema16/history-native-hit/fire-bolt/{amber,blue}` | Recipient `4e086d1d-743c-47be-ae37-d7fa93a4b8c8`; first Blur `3e0f715e-d30a-44bd-9c82-b3cf9afc5941`; actual Hit +10 Fire. Amber seq12 applied97/root99; Blue seq11 applied92/root94. Recast actually removes old owner and applies `12db1d6d-eebc-4c85-8089-12b639e0dff6`. |
| `tests/fixtures/schema16/history-native-hit/magic-missile/{amber,blue}` | Recipient `957811dd-17d3-4ae6-9f39-bfdf5dcb22f9`; Blur `d850f53c-b3ff-436b-a834-38747a5b0b84`; actual 4 Force. Amber seq12 applied87; Blue seq11 applied82. Actual subsequent movement is recorded; **no authoritative Blur retirement is recorded**. |

Each fixture includes `native-hit-evidence.json` and provenance. Fold each seat
independently; equal sequence/occurrence numbers are not cross-seat identity.
Other failed legal recorder experiments remain in `.runtime` and do not supply
missing retirement facts.

Fire Bolt's actual selected material declares `clock_parameter="source_clock"`;
Magic Missile's is empty and its original Box1 material is static. These test
animated and static dependencies without replacing either effect. The full
material setting is explicit client configuration, not a server outcome.

## Short reproducible observation and acceptance proof

1. Load an ordinary original recording with full spell-hit material enabled.
   Locate the actual native `material_flash` on the real Blur owner. Sample
   during that flash at two real ages; inspect earlier helper snapshot layer
   materials versus the current hit's `native_body_surface` Texture2D identity.
   Current code retains the mutable identity: this is the code-level alias
   observation, not a newly run GPU result.
2. Observe 40 ms after the actual flash ends, still inside the .24-second history
   window. The current body must be normal while earlier copies preserve their
   own native treatment. Advancing/restoring the current hit must not alter the
   earlier frozen output.
3. Reconstruct the same prefix through seek using original logical operands.
   Compare matching-source/matching-age colour/depth output and immutable
   material dependencies, then four camera views, looping and Fire Bolt's real
   owner replacement. Keep Magic Missile's missing retirement explicit.
4. Compare paused output before/after hiding only the history effect, restore
   through ordinary same-clock binding, and require exact restored framebuffer,
   unchanged canonical state/clock and complete capture-owner cleanup.

No new GPU reproduction was run for this handoff. It states the contract to
qualify, not a green rendering claim or user visual approval.

## Separate body-treatment clock contract

Factory `body_program.gd` reads mutable `vfx_package_clock` slots supplied by
`body_receiver.gd`/the actual source owner. A shallow material copy still reads
future clock values or a recycled slot even without a native-hit texture.
Historical body-treatment reconstruction therefore separately requires the
actual selected treatment/owner state and a retained source-owned historical
clock, or an explicit source-supported frozen-clock input. Do not mutate the
live owner's clock to render the past. Keep the client's
`departure_native_body_treatment_not_bound` and appearance-opacity gap explicit
until those capabilities are independently implemented and qualified.
