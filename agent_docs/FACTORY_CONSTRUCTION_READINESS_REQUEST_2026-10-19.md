# Factory follow-up: native construction readiness

19 October 2026. This is a measured follow-up to the received [production bindings handoff](/mnt/c/Users/tommaso/Documents/assets/VFXFactory/docs/NDCLIENT_PRODUCTION_BINDINGS_HANDOFF_2026-10-19.md). It does not request another renderer or changes to approved artwork.

## Confirmed problem

Client: `NDClientGodot-authoring-schema`, Windows Godot4.7.2, Forward+/Vulkan, RTX5090,1600×960, orthographic size24. Whole package `production-bindings-2081189e43bf0443`; ordinary player UI, actual server commands. The door reveals the Gallery; the player moves in, drinks Haste, and casts Fireball twice. No other client preview/native test ran concurrently.

| Source | First complete UI run | Repeated independent UI run | Second run `_ready()` | Client make-component call |
|---|---:|---:|---:|---:|
| `sorcerer_quickened_native` |165.799ms|163.029ms|162.952ms|0.013ms|
| `sorcerer_twinned_native` |176.753ms|181.519ms|181.446ms|0.015ms|

Script lookup, admission and client adaptation each measure below0.02ms. These are real main-thread CPU spikes during optional warm preparation, not server waits or the authored door-animation duration. A2ms scheduler allowance cannot interrupt an individual163ms call; charging it afterward does not solve this. Moving it to another gameplay frame would only move the freeze.

Exact source chain: generated clip constructor→`occurrence.gd._ready()`→`source_bridge.make()`→`recording_source_sampler.make()`→`class_strips.make_component()`/class-action build, source adaptation, material and input binding discovery. Current timings isolate `_ready()`; **the relative contribution of those inner steps is not measured yet**. Do not claim one is the cause merely from inspection.

Factory canonical files: `factory/components/.../class_action.gd` and the selected GPU-motion `class_strips.gd`/`strip_motion.gd` (use the release's paths inventory for exact canonical locations). Installed files include:

- `assets/vfx/clips/57e472ad4303e7b27b553a1e/construct.gd` (Quickened)
- `assets/vfx/clips/523fcdfed0ce924dfb2185f7/construct.gd` (Twinned)
- `assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd`
- `assets/vfx/sources/5ab0d0eb20f55fac8240/class_strips.gd`
- `assets/vfx/sources/5944248dd6bb52ef8394/class_action.gd`
- `assets/vfx/sources/584a1116b96d865072e3/strip_motion.gd`

The delivered index itself lists171.709ms and226.190ms for these two approaches. Its other construction estimates identify additional candidates for investigation, but they are **isolated Factory measurements, not measured player spikes**. [Offline complete outlier inventory](../generated/reports/factory-construction-readiness.json).

## Requested source work

1. Break `_ready()` into exclusive source construction, adaptation, material discovery, input receiver binding and clock preparation timings. Measure first and repeated construction after immutable resources/programs are prepared. Preserve unchanged source output.
2. Move immutable shader/noise/texture decode, strip/mote mesh and other reusable preparation out of occurrence construction. Use serialized native Resources or a public preparation seam. Share immutable programs/meshes/textures; private materials, owner facts, transforms and clocks stay per occurrence. If remaining scene registration cannot fit a short preparation unit, expose bounded preparation/publication steps rather than one indivisible build. No generic new effect manager is requested.
3. The generic occurrence's `set_recipient_geometry()` currently always calls `refresh_material_bindings()`, recursively walking the descendant/resource graph on every changed pose packet. Make topology/material revisions own discovery and cache immutable method metadata. Preserve first lazy material creation and later real material changes. We have identified the repeated work but **not measured its total live cost**; no claim that this causes the two startup spikes.
4. Audit other live-native approaches sharing these owners, particularly dynamic walls/volumes and created-item appearances. Do not infer all sources need fixing from a single noisy cold estimate. Keep a source/readiness report with the next complete package.

Desired occurrence work is on the order of1–2ms per preparation unit on this machine, with no long indivisible main-thread step. Report remaining limits rather than changing visuals, dropping effects, holding clocks or preconstructing the entire catalog at startup. A prepared prototype must not carry review recipient/owner/outcome facts into actual occurrences.

## Receiving evidence and delivery

Client artifacts (same local disk):

- `.runtime/production-bindings-live-profile-r4.json`; actual run `.runtime/player-runs/20261019T182749.590909Z/`.
- `.runtime/production-bindings-live-profile-r5.json`; actual run `.runtime/player-runs/20261019T182948.784034Z/`.
- Each `player-live-checks.json` has `evidence.native_startup.construction_ms`; native source/frame phases are retained in its full profile. Each run passed83 live checks, with both actual Fireball commands and final canonical state. Exit ObjectDB warnings remain.

Work in Factory, preserve the sealed release and original source art, deliver another complete staged replacement with its public contracts and measured costs. Do not patch the client checkout or its package while tests run. No other-chat communication is needed; the user can hand this file to the Factory author.


## Current main follow-up —20 October

The old worktree measurements above are historical evidence. All client work is
now merged in `C:/Users/tommaso/Documents/Dev/NDClientGodot`, branch
`codex-authoring-schemabump`; installed complete package is c494177f9ef03e3d.
The nine prepared class approaches do not qualify all unrelated Baked sources.

The actual player Gallery run
`.runtime/player-runs/20261020T001245.877194Z/` passes313 assertions/27commands,
including door reveal, movement, Shield and seven spell families. Its full
profile is `generated/profiles/2026-10-20T02-13-56-gallery-live-spells.json`.
The remaining in-play57.849ms frame correlates with optional native preparation:
`native_startup_construct`52.616ms for
`original-repairs/chill-touch/contact-layers`; its nested `baked_instantiate`
receipt is52.572ms. This identifies the indivisible scene instantiation boundary,
not yet the decomposition of its node/material/resource internals. The phase
measurements overlap and must not be summed. First Magic Missile Baked
instantiation is21.083ms; Ray of Frost donor10.422ms. Startup separately has a
126.442ms frame, including108.893ms native resource preparation.

These are observed remaining limits, not a request to change the approved art,
turn effects off, insert a presentation wait or preload the entire catalog.
The client already supplies selected/received requirements ahead of publication;
a single expensive native registration still exceeds a frame budget. Factory's
current broader runtime repair remains separate and its unsealed WIP is not
installed. Preserve the actual source when exposing prepared resources or bounded
construction steps; qualify the eventual successor in this same live route.
