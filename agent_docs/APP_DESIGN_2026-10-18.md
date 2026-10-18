# NDClient app design (18 October 2026)

The whole client in one place: what it is for, who produces each part, how
data reaches the game and the Studio, and how it ships. It is written from a
read-only study of the code, data, tools and docs on 18 October (HEAD
`9020467`, plus the spell cases merged as `672004a`). It states the target,
what differs today, and the decisions still open. Where this document and an
older plan disagree, this one is newer; the plans it replaces are listed in §10.

## 1. Fixed requirements (user decisions)

1. **One executable.** The game ships as a single executable built from this
   project alone. It never ships with the VFX Factory, art sources or dev
   tools. Everything the game reads at run time lives inside the project and is
   included by Godot's export: no absolute paths, no junctions, no git-ignored
   code, nothing in dot-folders (Godot's export skips `.derived/`, `.runtime/`).
2. **Server.** For now the game connects to a separately started server (the
   pinned engine copy for local work). Later: single-player runs a bundled
   Python server started by the game; multiplayer connects to a hosted server.
   Both speak the same protocol.
3. **Effects come out of the Factory finished.** The Factory writes the files
   the client loads; there is no client importer or baker. Effects that can be
   recorded are recorded in the Factory. Which version of an effect ships
   (recorded, GPU, native) is chosen by measuring it in the game
   ([VFX_PACKAGE_CONTRACT_2026-10-18.md](VFX_PACKAGE_CONTRACT_2026-10-18.md)).
4. **The client keeps its own copy of every asset.** Large binaries stay out of
   git and are kept as versioned backup archives; code and text are committed.
5. **Smooth first.** No held frames, first-principles costs, the painter's draw
   order unchanged unless proven, all 8 facing rows resident, speed before VRAM.

## 2. Who produces what

| Producer | Owns | Reaches the client as | Today |
|---|---|---|---|
| **Server** (`dnd_engine`) | Rules, state, outcomes, content IDs (`spell.fire_bolt`, `condition.spell.shield`, pack `content.srd_5_1_cc`), the protocol | Packets at run time; the protocol schema copied into `sdk/` | Schema copied by hand: client has schema 9, the engine's checkout has 15. The pinned engine (`229ce025f`) is what the client is validated against. |
| **VFX Factory** | Every visual effect: meshes, particles, shaders, lights, their recordings, and (decision D1) their timing and placement | The package `assets/vfx/` (index, clips, recordings) | Package delivered (771 clips) but not read yet; the game plays an older copied subset through four client tools (§7). Class-action and blood effects are not in the package. |
| **Art deliveries** | Character and creature sheets, their geometry and normal profiles; environment art; UI icons and portraits | Today: read at run time from outside the project (`NDClientData/.media`, three `fantasy-unified-catalog` delivery folders, `NDCharacterLight`) | Must become copies inside the project (§6). |
| **Audio packs** | Sound files and licences | `assets/audio/` plus `authoring/audio/` | Already inside; needs Godot import. |
| **Client** | How the game presents server events: body animation and cast timing per spell, action/attack/condition recipes, rigs, audio bindings, UI; the runtime; the Studio; tests | `authoring/`, code | Most of `authoring/` is a frozen export of the old Pygame data model (§5). |

## 3. The apps

| App | Scene | Role | Ships | Target |
|---|---|---|---|---|
| **Game** | `play.tscn` / `play.gd` | Live play against a server | Yes | Stays; gets the package loader. |
| **Studio** | `studio.tscn` / `studio/` | Replays real server recordings on the game's own renderer; timeline tracks; review and debugging | No (dev tool; decision D5) | The one review tool for spells and everything else. Gets the effect-version toggle and the 36 lifecycle cases. |
| Spell sandbox | `spell-sandbox.tscn` / `sandbox/` | Offline spell fixture, placement and piece toggles | No | **Retire** (D3): it has its own copy of the cue scheduler that already disagrees with the game's, reads raw JSON the game doesn't, never plays recordings. Its useful authoring moves to the Factory (staging) and the Studio (inspection). |
| Workshop / exploration demo | `main.tscn`, `demo.tscn` | Older map/catalog authoring; Unity map reconstruction | No | **Delete** (D4), with `compile-grid.cmd`, the Unity tools and their `generated/` data. |

The Game and the Studio already run the same pipeline: the Studio instantiates
`play.gd` with `external_playback` and feeds it a timeline built from a recorded
journal with the same compiler. That property is the core of the design: what
you review in the Studio is what plays in the game.

## 4. Runtime pipeline (game and Studio)

Packet → pixels, in frame order (`play.gd:_process`):

1. **Transport** (`sdk/transport.gd`, `sse.gd`): HTTP/SSE on a worker. Studio: none.
2. **Protocol and journal** (`sdk/protocol.gd`, `journal.gd`): schema admission, durable record.
3. **Reducer** (`sdk/reducer.gd`, `transitions.gd`, `audience.gd`): canonical state, sensory fold.
4. **Session and compiler** (`presentation/session.gd`, `compiler.gd`, `components.gd`): one operation becomes groups of actor tracks, effect components and commits, two operations ahead of display. Studio: `studio/recording.gd` compiles the whole journal.
5. **Timeline** (`presentation/timeline.gd`): display clock, commits, world boundaries, condition and spatial owners.
6. **World** (`world.gd`, `world_preparation.gd`): rooms derived on workers, constructed in budgeted steps, published at their cue.
7. **Media** (`media_warmup.gd`): sheet decode and residency (L8 replaces PNG decode with prepacked bundles).
8. **Actors** (`characters.gd`, `actor_construction.gd`, `body_sources.gd`, `modular.gdshader`): layered sprite quads.
9. **Effects** (`component_renderer.gd` → `native_spell_renderer.gd`, `blood_renderer.gd`, `audio_presenter.gd`): the package loader plugs in here.
10. **Light, shadows, draw order** (`native_source_lights.gd`, `canvas_shadows.gd`, `grid_order.gd`).
11. **UI** (`play_hud.gd`, `ui/`, `interaction.gd`).

The only runtime difference between game and Studio is where operations come
from (live packets or a recorded journal) and the Studio's tools around the
same world.

## 5. Authoring model

### 5.1 Where it came from

`authoring/` is the Pygame client's data model (itself built on the
TypeScript NeuroClient's), exported once on 12 October. The tools that produced
it and the typed schema that validated it are gone. It is byte-identical to
`NDClientData/authoring` and to the old NDClient repo. The Godot-native files
(`audio/`, `native_effects/`, `presentation/*.tres`, `sandbox/`, `studio/`)
were added beside it from 14 October, not in place of it. So:

- one spell is described in up to 8 files with 4 ID spellings
  (`spell.fire_bolt`, `fire_bolt`, `spells/fire_bolt/default/cast`,
  `spells__fire_bolt__…`);
- generated and hand-written data share files (`native_effects/index.json`;
  `sandbox/projectiles.json` is generated but lives in `authoring/`);
- production data lives in `sandbox/` (`staging.json`, `batches/*.json`,
  `feedback.json`, `body_materials.json`);
- old fields still drive new behaviour (`projectile.speedPxPerSecond` sets
  native flight time; the sandbox uses 8 tiles/s instead, so Fire Bolt flies
  about 3× slower in the game than in the sandbox);
- nothing is validated.

### 5.2 Target rules

1. **One key per content: the server's content ID.** Spells, conditions,
   actions, items, creatures and environment objects are keyed by the ID the
   server sends. Effect clips keep the package's `clip_id`.
2. **One owner and one file per concept.** No concept in two places; no
   generated data inside `authoring/`; no production data in `sandbox/`.
3. **Typed and checked.** Each record has a schema (a Godot Resource class or a
   JSON schema) checked when the project is built, not discovered at run time.
4. **One build step, run before export.** Anything derived (body sources,
   sheet bundles, surface sockets, texture layouts) is produced by one build
   command into an exported folder (§6), never written by hand.

### 5.3 Per content kind: today → target

| Kind | Today (authoring → build → game / Studio / sandbox) | Target owner and home |
|---|---|---|
| **Spell presentation** | `spells/spell.<id>.json` (old shape: cast clip, release frame, hand sockets, sprite-sheet layers, projectile speed) → `tools/native_spell_import.gd` → `.derived/native-spells` (30 spells) → game and Studio; sandbox reads raw JSON with its own scheduler | Client owns the body side: cast clip, release frame, body speed, hand sockets, hit feedback, audio. One record per `spell.*` ID. Sprite-sheet fields go once nothing draws them (D7). |
| **Spell effects and their staging** | Factory recipes copied by `prepare_projectile_sandbox.py`; staging in `sandbox/staging.json` + `batches/*.json`; lifecycle in `native_effects/index.json` | Factory (D1): effect clips and their timing, scale, placement, hold behaviour, in `assets/vfx/index.json` `selections`. The client consumes; Studio reviews. |
| **Condition visuals** | Lifecycle windows per spell in `native_effects/index.json`; 10 lasting conditions hold one frozen frame; sprite condition layers no longer draw | Factory delivers enter/hold/exit for each condition (animated hold); the client drives them from the server's condition owner (apply, suppress, remove). |
| **Creatures (own sheets)** | `catalog/rigs.json` + `creature_rigs.json` + `resources.json` (split from one Pygame file per creature) + `generated/creature_geometry.json` → `.derived/body-sources` | One record per creature rig keyed by the server creature ref: clips, sheets, geometry, normals, shadow. Art inside `assets/`. |
| **Modular characters** | `rigs.json["neuroclient.modular"]`, clip overlays in `presentation/clips/*.tres`, gear in `items/visuals.json` keyed by English names → `.derived/body-sources` | Same model; gear keyed by server item IDs; appearance from the server as today. |
| **Actions, attacks** | `catalog/body_action_recipes.json`, `attack_recipes.json` (+ `.tres` overlays) | Client; one record per behavior ID; remove the 12 catalog files no code reads. |
| **Environment** | `environment/`, `world.json`, `assets.json`, `catalog/{devices,portals,…}` | Client; one record per server object ID; art inside `assets/`. |
| **Audio** | `authoring/audio/*` + `assets/audio` | Client (already Godot-native); one exception to fold in: Hide's cue lives in `hide.tres`. |
| **UI** | `authoring/ui/*`; server `icon_key` wins | Client; icon keys aligned with server IDs. |
| **Studio cases** | Journals in `.runtime/`, indexed by tracked `generated/studio_*inventory.json` | Dev data: journals versioned as backup archives with their engine revision; tests that need them use a small committed fixture set. |

Unused today and to be deleted after a final check: `authoring/media/` (2,300
files, 65 MB, no reader since 17 October), `catalog/vfx_source_hues.json`,
`materials/source-palettes.json`, `items/materials.json`, `ui/skin.json`,
`ui/fonts.json`, `sandbox/projectile_inventory.json`,
`generated/character_{clips,tree}.tres`, `generated/modular_animation.tscn`.

## 6. Project layout and the shipped build

| Folder | Contents | In git | In the export |
|---|---|---|---|
| `authoring/` | Hand-authored client presentation data only | Yes | Yes |
| `assets/vfx/` | Factory package | Text yes, binaries backed up | Yes |
| `assets/art/` (new) | Character, creature, environment, UI art copied from the deliveries | Text yes, binaries backed up | Yes |
| `assets/audio/` | Sounds | Backed up | Yes |
| `build/` (new, not a dot-folder) | Derived runtime data from the one build command: body sources, sheet bundles, surface sockets, texture layouts | No (rebuilt) | Yes |
| `user://` | Settings, saves, runtime caches (palette ranges move here) | — | — |
| `sdk/`, `presentation/`, `play.*`, `ui/`, `animation/` | Game code | Yes | Yes |
| `studio/`, `tools/`, `tests/` | Dev code | Yes | No |
| `.runtime/`, `.captures/`, `generated/` reports | Dev output | No (curated reports only) | No |

The export preset (`export_presets.cfg`, none exists today) embeds the pack in
the executable and excludes the dev folders. A test export, launched against
the separately started server, is the check that §1.1 holds.

## 7. Gaps between today and the target

1. **The game can't run from a fresh checkout or an export.**
   - `presentation/native_factory_source.gd` and `native_source_variants.gd`
     preload scripts from the git-ignored copied tree `assets/native_effects/`.
   - `project.godot [source_data]` points at absolute Windows paths:
     `NDClientData/.media` (all character and environment art),
     `fantasy-unified-catalog/{modular-character-geometry,authored-creature-geometry}`,
     `NDCharacterLight/.derived/normals`.
   - `presentation/lighting_2d.gd:10` loads a light cookie by absolute path;
     `generated/environment_receiving_normals.json` holds 1,142 absolute paths.
   - Runtime data lives in `.derived/` (native spells, body sources, surface
     sockets, source variants, baked effects, texture layouts), which the
     export skips.
2. **Effects run through four client tools**, not the package:
   `prepare_projectile_sandbox.py` → `native_spell_light_intake.gd` →
   `bake_native_source_variants.gd` → `import_native_spells.gd`, plus the
   client baker. `prepare_native_effects.py` (class and blood effects)
   rewrites `native_effects/index.json` as sources only and would erase the
   hand-written spell table if re-run.
3. **Staging exists twice and has already diverged**: of the 14 spells in
   `staging.json`, only Acid Splash and Produce Flame match the package.
4. **Duplicated runtime logic**: the sandbox's cue scheduler, the Studio
   thumbnail sampler and three copies of the condition exit window.
5. **Protocol drift**: the client's schema copy is 9, the engine checkout 15,
   with no sync tool.
6. **Committed test output**: about 370 report files in `generated/` change on
   every test run.
7. **Docs contradict each other** in 13 places (old importer workflow, Studio
   panes, `run.cmd`, `NDClientData/authoring`, deleted tests listed as known
   failures). §10 lists what replaces what.

## 8. Decisions for the user

| # | Decision | Recommendation |
|---|---|---|
| D1 | Who owns effect staging (timing, scale, placement, hold) | **Factory.** Feedback on effects goes to the VFX agent; client copies are deleted. The client keeps what comes from the game: body animation, release frame, real travel distance, gameplay timing (e.g. Shield lands when the arrow arrives). |
| D2 | Who owns projectile flight speed (game uses the old draft's px/s; sandbox used 8 tiles/s) | Part of D1's staging (Factory), applied over the real distance by the client. |
| D3 | Spell sandbox | Retire after the Studio toggle lands. |
| D4 | Workshop, exploration demo, Unity tools | Delete. |
| D5 | Does the Studio ship | No; dev tool. |
| D6 | Class-action and blood/hit effects | Factory takes them over in the package, so `assets/native_effects/` and `prepare_native_effects.py` go away. |
| D7 | Sprite-sheet layers still drawn: hand-magic glow (Magic1–3) on all spells, and Effect1–3 overlays on the 119 spells without native effects | Keep the hand glow until the Factory delivers native hand effects; drop Effect overlays per spell as native ones arrive. |
| D8 | Art inside the project | Copy the deliveries into `assets/art/`, binaries backed up per delivery version like the VFX package. |
| D9 | Protocol version | Stay on the pinned engine (schema 9) until the server agents settle, then add a schema sync tool and upgrade once. |
| D10 | Test reports in git | Stop committing them; keep a small curated set. |

## 9. Order of work

1. **Now:** package loader and Studio effect-version toggle (agent running);
   the 36 lifecycle cases (merged). Then the user reviews every spell in the
   Studio on the Factory's effects.
2. **Ownership** (after D1–D7): delete the duplicate copies, move generated
   data out of `authoring/`, retire the sandbox, workshop and Unity tools, the
   four client effect tools and the baker; condition holds animated.
3. **Self-contained project** (D8): art into `assets/art/`, no absolute paths,
   runtime data from `.derived/` into `build/` via one build command, export
   preset, and a test export played against the server.
4. **Authoring model**: one typed record per server ID, checked at build;
   fold the old Pygame fields the runtime still needs into those records.
5. **Later:** bundled server for single-player; hosted server for
   multiplayer.

## 10. Docs this replaces or corrects

- Current: this document;
  [VFX_PACKAGE_CONTRACT_2026-10-18.md](VFX_PACKAGE_CONTRACT_2026-10-18.md);
  [CLIENT_ESSENTIAL_WORK_AUDIT_2026-10-17.md](CLIENT_ESSENTIAL_WORK_AUDIT_2026-10-17.md)
  (renderer steps L1–L8); the progress ledger
  [CLIENT_STRUCTURE_PROGRESS_2026-10-17.md](CLIENT_STRUCTURE_PROGRESS_2026-10-17.md);
  [L8_SHEET_PREPACK_2026-10-18.md](L8_SHEET_PREPACK_2026-10-18.md).
- Superseded for the effect pipeline: `NATIVE_VFX_FACTORY_HANDOFF.md`
  (importer workflow), `NATIVE_VFX_RUNTIME_CONTRACT_2026-10-17.md` (client
  baking), §7.3 / Track S of `CLIENT_STRUCTURE_AND_NATIVE_DATA_PLAN_2026-10-16.md`
  (one client importer).
- Stale and to be rewritten in step 2: `README.md` (atlas, `run.cmd`,
  `NDClientData/authoring`), `authoring/README.md` (deleted Pygame-era tools),
  `sandbox/README.md`, parts of `studio/README.md` (two panes).
