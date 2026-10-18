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

## 7a. Package `20261018-c3c616e88a6b725f` (18 October, 20:01)

The Factory published this version straight into `assets/vfx/` as its answer to §8, replacing `fa4e64489d2d25a8`. The clip and approach counts are unchanged.

What it changes:
- The Chill Touch recordings are bright.
- The 645 recorded `warm` lists name the recordings' own materials.
- The electric includes resolve inside the package.
- `node_aliases` gives `impact/Donor` → `impact/Source/Donor`.
- Thaumaturgy has early review times; its art is unchanged and faint.
- Every selection is tagged `staging_authority: client`.

Its text was committed in the client by mistake inside `035dd58` (a design-doc commit made with `git commit -a`). The binaries are backed up as `NDClientGodot-backups/vfx-20261018-c3c616e88a6b725f-binary.zip`.

Every client check since then ran on this version:
- gate;
- `effect_package_checks` 1,048/0;
- Studio version 32/0;
- condition lifecycles.

Not yet used by the client:
- The new `warm` lists. The client still compiles recorded materials on their first private draw.
- `node_aliases`. The client resolves old node paths through selection staging.

## 8. Findings for the Factory

The condition work (recorded lifecycles, defects, the 138 visible conditions
with no effect, Web's spatial hold) is handed off on its own in
[VFX_CONDITIONS_HANDOFF_2026-10-18.md](VFX_CONDITIONS_HANDOFF_2026-10-18.md). (18 October, package `20261018-fa4e64489d2d25a8`)

Found while loading and playing the package in the client. Evidence:
`.captures/effect-package/*.png` (one comparison sheet per clip) and the
loader merge `9ac9e20`.

Package defects:
- **Chill Touch recordings** render the fist dark inside (the same symptom the
  old client bake had). Its native approach is bright.
- **Thaumaturgy** draws 0 px at the client's sampled time in both the native
  and recorded approaches (the old effect drew 80 px). The effect is small and
  short.
- **`warm` of recorded approaches** (all 645) lists the live approach's
  clock-wrapped materials, not the recording's own. The client compiles the
  recording's materials on its first private draw instead.
- **`electric_ribbon.gd`** reads `res://factory/...`, outside the package. Not
  used by the 30 client spells today.
- **Magic Missile impact**: the node `impact/Donor` the old staging named is
  now `impact/Source/Donor`.

Staging differences between the client's staging and the package's
`selections`. These matter if the Factory takes over staging (app design D1):
- **Shield**: the package stages a finite 3.7 s preview with a probe Fire Bolt
  1.2 s after release. The client holds the lifecycle by the real condition
  and plays the hit on real interceptions. The package's separate
  `condition_shield_retained_native` selection is the one that fits play.
- **Effect lights**: most selections set `decorative_light_multiplier` 0; the
  client defaults to 1.
- **Sleep**: scale 1.0 (client 1.45), emission 0.65 s (client 1.0), opacity
  keys and `sleep_opacity`, lights hidden in flight and cast, an `asleep`
  recipient clip.
- **Web**: source end 3.8 s (client 2.0, hold at 0.8), fade 0.55, opacity
  uniform, live endpoints for both targets.
- **Cure Wounds, Healing Word, Guidance, Resistance**: opacity keys, fades and
  a `support_envelope` uniform. Cure Wounds, Healing Word and Guidance are
  larger (Cure Wounds 0.62 vs 0.3). Mage Armor's held opacity 0.045 vs 0.16.
- **Shocking Grasp**: the package puts its second cue at the hand; the client
  puts it on the recipient's body.
- **Smaller**: Eldritch Blast cast scale 0.16 vs 0.25; Guiding Bolt impact
  0.28 vs 0.18; Command delay 0.15 s; Fireball area `duration_policy:
  authored`.
- **No package staging**: Fire Bolt, Ice Knife, Poison Spray, Ray of Frost and
  Scorching Ray have no staging cues; True Strike has no cue for its clip.

Condition lifecycles (merged in the client on 18 October; per-clip numbers
from `tests/condition_lifecycle_checks.gd`):
- **All 29 are native-only, and their builds run on the main thread.**
  - The 19 overhead markers take 23–66 ms on the first build and 9–16 ms on a rebuild.
  - The 10 body lifecycles take 39–243 ms on the first build. Sanctuary (243/166 ms), Bane (210/160 ms) and Shield of Faith (155/118 ms) are the worst.
  - These are visible frame spikes in play. Please supply recorded or GPU approaches, or cheaper constructors.
- **Shield of Faith:** the sustain goes blank after about 5 s. Its emitters fire once and none keeps running (`continuous_emitters` is empty).
- **Sanctuary:** the sustain drops to about 15% coverage once its ring disappears.
- **Guidance:** the sustain falls to about 7% of its opening coverage after 2 s.
- **Aid:** the application draws nothing for its first 0.55 s.
- **Light and all 19 markers:** the sustain is static (`steady_artwork`), but the user asked for an animated hold.
- **`occurrence.set_owner_state`:** walks the whole node tree twice on every call, and the phase age has to be sent every frame.
- **`origin_path` is inconsistent:** markers use `Glyph`, which is inside the component, while body lifecycles use `effect/Retained`, from the root.
- **Bane:** has two lifecycles on one condition id, and the client plays both. Please document this.
- **Web:** has no spatial lifecycle. Its net still holds a staged pose.
