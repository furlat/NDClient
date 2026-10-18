# VFX package: what the Factory produces and the client loads (18 October 2026)

Decision (user, 18 October): there is **no client-side importer and no
client-side baker**. The Factory produces files in the format the client
needs, and the client loads them as they are. Baking, where an effect can be
baked, happens in the Factory as part of producing those files. The goal is
smooth effects in the game, not recordings for their own sake: the client
loads everything, tests every available way of playing each effect, and the
best one ships.

This replaces, once the first package loads in the client:
`tools/prepare_projectile_sandbox.py` (copies and rewrites Factory files into
`assets/native_effects/`), `authoring/sandbox/projectiles.json` (its
generated manifest) and `tools/bake_native_effects.gd` (client-side
recording). The client keeps playback (`presentation/native_*`,
`presentation/baked_*`) and the test bench.

## 1. Where the package lives and how paths work

- The client keeps its own copy of every asset; it never reads outside its
  project folder, so exporting the game needs nothing else.
- The Factory's export writes the package into the client project, at
  `NDClientGodot/assets/vfx/` (`res://assets/vfx/...`), as finished files with
  their final client paths. Nothing in the client copies, rewrites or imports
  them.
- Each export replaces `assets/vfx/` as a whole, so old and new files never
  mix; `index.json` names the package version.
- Every reference inside the package stays inside `res://assets/vfx/`, or is a
  Godot built-in. No `res://factory/`, `res://library/`, `res://authoring/`,
  `res://integrations/`, `res://.derived/`, and no other client path such as
  `res://presentation/`.
- Before handing over, the Factory checks its export by loading it in the
  client project: every index entry and every approach loads without error.
- **What git keeps.** The client commits the package's code and text: scripts,
  shaders, `.tres`/`.tscn`, `index.json` and other JSON (about 32 MB for
  `20261018-fa4e64489d2d25a8`). Binary resources (`.res`/`.scn`: recordings,
  meshes, textures, warmed materials; about 623 MB) are ignored by git and kept
  as a backup archive per package version, next to the repository in
  `NDClientGodot-backups/`. So the Factory keeps large data in binary resources
  and code and parameters in text files. The Factory's exporter itself is
  Factory code and is committed in the Factory repository.
- Every file loads with `ResourceLoader.load` in a project that has never seen
  it: `.res`/`.scn`/`.tres`/`.tscn` with textures and meshes saved as
  resources, `.gdshader`, `.gd`. No `.png`/`.jpg`/`.glb` that would need the
  editor's import. Shared textures and meshes are their own `.res` files, so
  effects that share them load them once.
- Constructor scripts and the scripts they load by string are inside the
  package. A script that loads anything outside it is a packaging error.

## 2. The index

`res://assets/vfx/index.json`, one entry per clip:

| Field | Meaning |
|---|---|
| `clip_id` | Unique and stable; client spell data refers to it. Two different effects never share one (today Ray of Frost and Sleep both use `recovered/travel`). |
| `spell`, `stage` | Owning spell and stage (cast, travel, impact, area, condition application/hold/removal, ...). |
| `seconds`, `loop` | Length of a finite clip; whether it holds or loops while an owner keeps it. |
| `inputs` | What the effect needs from the game while it plays: `root_path` (moving projectile), `caster_hand`, `recipient_geometry`, `targets`, `contacts`, `owner_state`, ... Empty means the effect depends only on time. |
| `approaches` | Every way the Factory can deliver this clip, each with `kind`, `path` and the Factory's own measurements (below). |
| `content_hash`, `source_revision` | Identity of what was produced; the client records which version it tested. |
| `provenance` | Author and licence of the source artwork. |

Approach kinds:

| `kind` | What it is | Client plays it with |
|---|---|---|
| `recorded` | Per-frame particle states, property tracks and the effect's scene without anything that runs. Produced in the Factory. | Recorded playback (`presentation/baked_effect.gd`). |
| `gpu` | GPU geometry and shaders evaluated as a function of time and the declared inputs. | The native runtime, through the constructor interface. |
| `native` | Original nodes and particle systems with a live controller. | The native runtime, through the constructor interface. |

Each approach also states:

- `seekable`: any moment can be drawn directly, without replaying from the start.
- `warm`: the materials and shaders to compile before first use, so the client
  compiles them at load time, not on the first cast.
- `disk_bytes`, `gpu_bytes`, `construction_ms`, `sample_us`: Factory
  measurements. The client measures again in the game; the Factory numbers are
  for comparison.

Ship every approach that exists for a clip, including ones the Factory would
not pick. The client decides from measurements in the game. Approaches ruled
out are reported back and then dropped from later packages.

## 3. Recordings

- Record every clip whose `inputs` are empty or only `root_path` (moving
  projectiles follow the path on the GPU, as now).
- Record at the source's simulation rate (some sources run at 144 Hz), with
  stable node names and private copies of tracked meshes and materials. These
  are the Factory recorder's fixes the client baker lacks; they now live only
  in the Factory.
- Three seeded variants per clip, picked by the cast's seed.
- Fields are those of the client's recording today
  (`presentation/baked_effect_bundle.gd`: `rate`, `frames`, `seconds`, the
  scene, `systems` with their state images, `trails`, `moving`, `tracks`,
  `private_materials`, `gaps`). The data class goes in the package
  (`res://assets/vfx/format/recording.gd`) as the shared definition.
- Particle systems in the recorded scene carry no playback shader. Each one
  says what it is (`static`, `trailing` or `path_trail`), and the client
  attaches its own playback shader when it builds the effect. (Client change:
  `Baked.make` assigns the shader instead of the recording naming
  `res://presentation/baked_*.gdshader`.)

## 4. Live effects (`gpu`, `native`)

- Same interface as now: the constructor script's
  `make_component(input) -> Node3D`, then `sample(seconds)` each frame, plus a
  setter for each declared input.
- One clock texel per occurrence (the shared GPU clock) for every shader that
  reads time. Today only 34 of 771 phases use it.
- No per-frame CPU simulation. A live controller writes inputs and clocks;
  it does not step particles or rebuild meshes.
- An effect that keeps GPU particle history (`seekable: false`) is a candidate
  for `recorded` whenever its inputs allow it. A late start must not replay
  the effect from its beginning in the game.

## 5. What the client tests

The bench loads the whole package and, for every clip and every approach,
plays it in the real renderer and camera:

| Measure | Pass |
|---|---|
| Load and construction on the main thread | No frame over budget; heavy loads on a worker. |
| First draw (pipeline compiles) | None during play; everything in `warm` compiled at load. |
| Per frame, CPU and GPU, alone and with the busiest scene from the routes | Fits the frame budget with the rest of the game. |
| Late start and seek (start at 0, 25, 50, 75 %) | Same cost as playing on. |
| Memory and disk | Recorded size against the VRAM plan (L8). |
| Look against the Factory's reference | Differences listed per clip, as in the baking report. |

Result: a table per clip (approach kept, approaches ruled out and why),
returned to the Factory. The package that follows keeps the winners.

## 6. Order of work

1. Factory: commit the current delivery, then export the first package (all
   clips, all approaches it has) into `assets/vfx/` in this format.
2. Client: the package loader in place of the importer's manifest, recorded
   playback assigning its own shaders, and the bench.
3. Run the bench, decide per clip or family, report back.
4. Client: delete the importer, the generated manifest, the copied
   `assets/native_effects/` tree and the client baker.

## 7. Client status (18 October, package `20261018-fa4e64489d2d25a8`)

Step 2 is in place for spells; step 4 is done except the copied tree and the
generated manifest, which the old spell sandbox (`sandbox/world.gd`) and the
class/blood sources (`authoring/native_effects/index.json` `sources`) still
read.

- `presentation/effect_package.gd` reads `index.json` and resolves each staged
  cue's clip: the same id (51 of the 55 staged cues), else the spell
  selection's clip renamed from it (`recovered/travel` → one
  `recovered/travel/source-*` per spell), else the selection's one cue in the
  same role (Chill Touch's strike, Web's area). Staging stays the client's.
- Plays `recorded`, else `gpu`, else `native`; `-- --effect-kind=` or the
  Studio's Inspect → Effect version forces a kind where a clip has it.
- Recordings play with `presentation/baked_effect.gd`: shaders assigned by
  role, emission started, source rate and frames from the bundle, variant by
  the cast's seed. Materials are indexed in the Factory recorder's order
  (override, mesh surfaces, particle passes, including passes an override
  hides).
- Live approaches: `make_component({layer_mask})`, `root_path` through its
  setter, `sample(source_seconds)`; the shared clock pool exists before any
  package material loads; `warm` materials compile on a worker during
  preparation, and the existing private warm-up draw compiles the pipelines.
- `tests/effect_package_checks.gd` builds, samples (0/25/50/75 %) and draws
  every approach of every staged clip; `tests/studio_effect_version_checks.gd`
  covers the Studio switch.
- Conditions play the package's 29 condition lifecycles
  (`EffectPackage.conditions(id)` by the server's condition id, `when`
  matched against the disclosed state): one occurrence per owner and
  lifecycle, built from its application clip; each frame its `owner_state`
  gets the phase (application, sustain, removal), the phase age and the
  owner's age, and it samples on the owner's age (`NativePersistent`). It is
  placed at its `registration` (ground, or the head socket for markers; rigs
  without one use the body centre) and follows the recipient as it walks;
  `visibility` hides it with an invisible actor, by life state, and markers
  take turns (one overhead group at a time). A spell's attached cue is not
  played at the cast when the condition's lifecycle carries the spell's body
  visual (`body_channel_included`); a marker-only condition keeps the spell's
  cue (Command). The clips are native-only: the Effect version choice says
  so on the row. Every lifecycle warms with the load (game) or the recording
  (Studio). `tests/condition_lifecycle_checks.gd` checks all 29;
  `tests/condition_lifecycle_frames.gd` captures them in the Studio cases.
