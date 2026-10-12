# Finger of Death — original material and native cast

The focused consumer is implemented and its source/native checks pass with the
rasterization qualification below. This does not complete general N3 or establish
occlusion against arbitrary world geometry.

## Source and implementation

The three original open shells require nearest/farthest surface selection;
front/back face culling cannot reproduce them. `finger-mesh.ts` uses their actual
vertices, UVs, transforms and nine original float donors, then the original
splinter geometry, delays, envelope and one final palette operation. Its depth
attachment belongs only to this effect. Linear composition uses bounded retained
targets; the result is an ordinary Sprite in the existing scene. No alternate
ordinary-image route or world depth buffer was introduced.

The implementation preserves source RGB decoding before donor interpolation,
the original inner/head/outer far/near order, and up to 30 delayed splinters.
Animation revealed and fixed a stale Sprite size when its bounded target grew:
the target now declares Pixi's `dynamic: true`. Painter contact follows the moving
head, and owned shader destruction occurs before destroying their Mesh owners.

## Independent source evidence

`tests/finger-material.browser.mjs` samples the actual recorded track through
production occurrence preparation and rendering. `tests/finger-reference.py`
calls the original Python `darkness_mesh_commands` and its material/rasterizer
without modifying source files. The 32 samples cover all four quarters, camera
zoom 1 and 2, prelaunch, travel 30%/80%, and the authored contact tail.

- Unmodified original comparison: silhouette IoU 95.65–99.23%, aggregate RGB mean
  3.16/255 over occupied unions; maximum per-sample mean 12.61 and maximum single
  channel difference 229. This is **not byte parity**.
- The software GPU reports four subpixel bits. A separate diagnostic rounds only
  the reference's projected vertices to that 1/16-pixel grid. It gives IoU
  98.25–100% and per-sample RGB means 0.023–1.63/255. The original hard lower-right
  two-pixel palette magnifies covered-sample changes. Sparse edge/UV differences
  remain, including a maximum channel difference of 179; the diagnostic is not
  substituted for the original comparison.
- Warm unchanged draws perform only the final scene draw. Context restoration
  yields zero differing pixels, generation +1 and zero new decodes. All effect
  targets are destroyed; disposing the eight prepared views leaves zero views
  and zero resource leases. Browser errors are empty.

Evidence is retained under `.runtime/reviews/finger-of-death/` in `input.json`,
`gpu.json`, `reference.json`, `raster-grid.json` and the paired PNG samples.
Assertions retain both the original visual bounds and the tighter independent
raster-grid diagnosis. Software rendering does not establish hardware throughput.

## Native acceptance

`/recordings/finger-of-death/case.json` contains three unchanged server-delivered
records, captured through the existing SDK. A level-13 Generic Caster with the
Finger spell grant targets one noncaster Gloomplate at 30 feet. Discovery names
the exact creature; preview reports `can_confirm` and that same effective target.
The committed cast contains a successful Constitution save, 31 Necrotic damage,
HP 27 → -4, and native death. No Counterspell or edited native outcome was used.

`tests/finger-recording.browser.mjs` passes the actual Studio flight, aftermath
and replay. Both actors remain present during flight; the target finishes `Die`,
the caster returns to `Idle`, the effect expires at its authored end, and natural
completion advances presentation without changing recording time/state. Initial
play and replay each commit exactly `[1, 2]`. `native.json`, `native-flight.png`
and `native-aftermath.png` retain the observed result. The capture server is stopped.

Typecheck and both focused browser checks pass. Backend, SDK, source artwork and
native packets were not changed.
