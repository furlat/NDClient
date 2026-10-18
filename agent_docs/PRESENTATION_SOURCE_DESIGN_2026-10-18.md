# Presentation source of truth: design (18 October 2026)

Status: proposal for the user's review. Nothing is built yet.

## 1. What the user asked for

- **One source of truth for everything the client shows.** It is a typed `.tres` that plays the role of the old authoring JSON. A build step splits it into the smaller files the game loads; those files are derived and are never edited by hand.
- **The server knows nothing about the front end.** All presentation authority lives in the client, keyed by the ids the server sends.
- **Split by domain so each part stays digestible:**
  - characters;
  - environment, including surfaces on terrain;
  - spells and actions (spells, conditions, actions, attacks).
- **It covers everything:**
  - modular characters, and characters or creatures with their own sheets;
  - portraits and icons;
  - normals, depths and directions for every character and environment piece;
  - spell effects named by their Factory id, with shaders, palette and material swaps;
  - environment tiles, walls and props, and surfaces on the ground.
- **Engine-neutral and complete.** Someone porting to a new engine or new sprite sheets must be able to recover everything from it.
- **No overfitting to the assets used today.** The schema must describe every delivery the user has (§8) and every id the server can send. The spell, condition and action ids are taken from the modern engine branch, not the pinned engine the client plays against.
- **Self-contained.** The client keeps its own copy of every asset, and the game ships as one executable without the Factory.

Research behind this design: the client's data today (spells and actions, characters, environment), the old Pygame/NeuroClient model, the server key space, every asset delivery, the 148-NPC roster and the depth/normal coverage. Reports are in the session scratchpad (`scratchpad/schema/*.md`); the coverage list is [NORMALS_DEPTH_GAPS_2026-10-18.md](NORMALS_DEPTH_GAPS_2026-10-18.md).

## 2. The shape in one picture

```
authoring/
  characters.tres          root: lists every rig, character, part, gear entry and portrait
  characters/              one .tres per entry (rigs/, characters/, parts/, gear/, portraits/)
  environment.tres         root: terrain, structures, objects, surfaces, connectors, lighting
  environment/             one .tres per entry
  abilities.tres           root: spells, conditions, actions, attacks, damage types, contexts
  abilities/               one .tres per entry
  common/                  shared vocabulary: palettes, looks, sound cues
  server_ids.json          snapshot of every id the server can send (made by a tool, §7)
assets/
  art/  vfx/  audio/       every image, mesh and sound, copied into the project
build/                     what the build writes; the game reads only this (§7)
```

### Why a root plus one file per entry

- **Same idea as the old model.** The old model had a root index plus one file per spell. The Godot client already started the same pattern in small form: `authoring/presentation/catalog.tres` lists typed `.tres` entries (`hide.tres`, `shield.tres`-style conditions, crouch clips) whose classes live in `presentation/resources/`. This design grows that pattern; it does not invent a new one.
- **Git and editing.** Each entry diffs on its own. Saving one big `.tres` from the editor renumbers its inline sub-resources and produces huge diffs.
- **Authority.** The root is still the single place that says what exists. An entry file that no root lists is an error in the build.

### Rules that hold everywhere

1. **Every entry is keyed by the exact string the server sends.** Examples: `spell.fire_bolt`, `condition.spell.shield`, `creature.goblin_redcap`, `weapon.longsword`, `environment.door.fantasy_a1`, `spatial_effect.material.oil`, `residue.blood`, tile material `stone`. Client-only things use a short client id: rigs, parts, palettes, looks.
2. **References are by id, never by copying.** A spell names the condition it applies; it does not repeat the condition's look.
3. **Measured data lives apart from hand-written entries.** Per-frame sockets, weapon-trail points, optical ground lines and depth ranges are produced by tools, so they sit next to the art they were measured from (§3.3), and entries refer to them.
4. **Art is described by its own measurements, never by assumption.** Each piece of art states its cell size, frame count, direction layout, camera, pivot, scale and depth/normal encoding. A 64 px animal, a 384 px door bank and a 128 px modular sheet are all just art sources with different numbers.
5. **Missing art is data, not an absence.**
   - Every server id gets an entry.
   - An entry without art says so, e.g. `status = "missing"` or `"stand_in"` with a reason.
   - The build reports those gaps instead of the game failing.
6. **Colours are hex strings.** Times are seconds. Distances are tiles or feet as named. One naming style throughout: snake_case.
7. **Prose stays out of the data.** Provenance and review notes go in a `notes` field the build ignores, or in docs.

## 3. Shared vocabulary (`authoring/common/` and shared classes)

### 3.1 Art source: what an image set is

| Field | Meaning | Examples |
|---|---|---|
| `container` | How frames are stored | `grid_sheet` (columns = frames, rows = directions), `atlas` (explicit rects), `views_as_files`, `frames_as_files`, `stacked_views`, `recording` (Factory), `scene` (Factory construct), `mesh` |
| `path` / `files` | Paths relative to `assets/` | `art/smallscale/authored/undead/With shadow/3DarkKnight/Attack1.png` |
| `cell` | Cell size in px | 128×128, 192×192, 64×64, 384×384 |
| `frames`, `fps` | Frame count and clock. `fps` may be empty when the source has no clock | 15 @ 12; 6; 106 |
| `directions` | Direction layout | `facing8` with row order `[E,SE,S,SW,W,NW,N,NE]`; `camera4` with order `[e,s,w,n]`; `single`; `repeated` (one view copied into every row) |
| `pivot`, `anchor` | Ground contact and body centre in cell px | (64,87); (128,208) |
| `projection` | Camera elevation, orthographic, px per metre, vertical step | 45° / 30°; 45.25, 30.33 or 25 px/m |
| `layers` | Which separate layers exist | `body`, `combined`, `shadow`, `effect`, `accent`, `mask_component`, `mask_material` |
| `surface` | Depth/normal companion (§3.2), or none | — |
| `measurements` | Link to the measured file (§3.3) | — |
| `source` | Delivery id and version | `smallscale-authored/2026-10-12` |
| `status` | `ready`, `partial` (with coverage), `stand_in`, `missing` | — |

### 3.2 Surface data: depth and normals

One record per art source (or per sheet), with:
- **`encoding`**, one of:
  - `normal_rgb_depth_byte`: characters and creatures. Depth is the byte 32–224 over a per-packet range; normals are RGB in camera space with the facing baked in.
  - `rg16_depth_oct_normal`: environment and paired VFX banks. 16-bit depth plus an octahedral normal, with matrices.
  - `metric_depth`: the 3D pilots.
  - `none`.
- **`depth_range`**, always per packet. Two deliveries never share one hard-coded range.
- **Normal profiles:** `original`, `gentle`, `reference`, `quality` (each optional).
- **Masks:** `support`, `normal_valid`, `solid`, `lighting_valid`.
- **`sampling`:** scale and offset, because geometry can be half the colour resolution.
- **`camera`:** basis, origin and matrices.
- **`coverage`:** pixel fraction, failed frames, `repeated_rows`, and `proxy` / `inferred` qualifications.

### 3.3 Measurements (generated, never hand-written)

Per art source and clip:
- per-frame sockets (hand, other hand, head, face, body centre, ground depth);
- the optical ground line;
- weapon-trail points per facing;
- surface-socket samples;
- luminance ranges for palette swaps (written at run time today).

These are produced by the existing tools and stored as `.res` files beside the art. Entries never inline them; that is what made `attack_recipes.json` 6.3 MB.

### 3.4 Palettes and looks: one vocabulary for every "swap"

The old model had seven unrelated swap mechanisms. Here they all become one `Look`, built from named steps:

| Look step | Replaces | Fields |
|---|---|---|
| `palette_ramp` | Hand-glow, Effect and Slash palette swaps; Factory effect finish palette; hit-flash ramp | `palette`, `noise`, `gamma`, `floor`/`ceiling`, `uses_luma` |
| `colour_replace` | Exact colour swaps on old effect sheets | `from[]`, `to[]`, `tolerance` |
| `tint` | Gear recolours, skin/hair/beard, item variants | `rgb` (multiply) |
| `body_adjust` | Condition tint/saturation/brightness/alpha (invisible, poisoned, haste) | `rgb`, `saturation`, `brightness`, `alpha` |
| `body_film` | Flowing texture ramps (rage, frenzy) and the not-yet-drawn petrified, barkskin and stoneskin looks | `texture`, `frames`, `fps`, `gain`, `weight`, `colours[4]`, `mapping` |
| `outline` | Paralyzed and similar | `colour`, `pulse_colour`, `width` |
| `layers` | Wings (Fly), hidden weapons while casting, extra slots | `add[{slot,part}]`, `hide[slots]`, `replace[{slot,part}]` |
| `pose` | Frozen or held poses (paralyzed, petrified, prone) | `role` or `{clip, frame}`, optionally per rig |

- **Palettes** are named sets of hex colours with roles (`primary`, `secondary`, `tertiary`), e.g. `palette.fire`. Each damage type names its palette. A spell may name its own palette or inherit its damage type's.
- **Shaders** are not stored as code. Each look step maps to one runtime shader feature (the modular, environment and effect-finish shaders already implement them). Factory effects bring their own shaders.

### 3.5 Effect use: how anything plays a Factory effect

The **effect** is the Factory package `clip_id` or `selection` key (`spells/fire_bolt/default/travel`, `conditions/retained/shield/sustain`). The **use** of it is described by these fields:

| Field | Meaning |
|---|---|
| `at` | When the cue starts: `cast_start`, `release`, `contact`, `application`, `removal`, `state_change`, `owner_start` |
| `delay` | Delay after `at` |
| `attachment` | Where the cue sits: `caster_hand`, `caster_ground`, `caster_release`, `recipient_body`, `recipient_ground`, `cell`, `area` |
| `follow` | Whether the cue follows the attachment |
| `scale`, `rotation`, `orientation`, `offset` | `orientation` is `facing`, `world` or `aim` |
| `source_window` | `start`, `launch`, `contact`, `end`, `rate`; with `duration_policy` |
| `emission` | Emission stops at contact or release, and tails |
| `nodes` | Show or hide named nodes at contact or release, `origin_path` |
| `opacity` | Keys, fade in/out, uniform |
| `light` | `colour`, `multiplier` |
| `finish` | A look (§3.4) |
| `approach` | Preferred kind: `recorded`, `gpu` or `native` (default: what the bench picked) |

**Origin of the values.** Where the Factory supplies staging for a spell, it is imported as the starting values, marked `staging_from = "factory@<package version>"`. After that the entry is the authority. A tool shows the differences when the Factory ships new staging, and the user decides which side wins.

### 3.6 Icons, portraits, sound

- **Icon or portrait reference:** the key the server sends (`icon_key`, `portrait_key`) or a client key, plus the image (art source), native size and crop.
- **Size variants are named:** `hud`, `sheet`, `preview` and so on, for the 7 portrait sizes that exist.
- **Sound cue reference:** `cue` (an id in `authoring/audio`), `timing` (`at` plus marker), `gain`.

## 4. Characters (`authoring/characters.tres`)

### 4.1 Rig: one art variant and how its body plays

There is one rig per sheet set:
- `neuroclient.modular`, the layered rig;
- `smallscale.undead.3darkknight`, `smallscale.goblin01` and so on, the own-sheet rigs;
- later the 3D-pilot rigs.

| Field | Meaning |
|---|---|
| `kind` | `layered` (modular) or `fixed` (own sheets) |
| `cell`, `pivot`, `anchor`, `scale`, `directions`, `projection` | As §3.1 |
| `layers` | Fixed rigs only: body / shadow / effect / accent sources per clip, each optional, plus `shadow` (`generated` from depth, `baked`, `separate`) |
| `slots` | Layered rigs only: slot order and the part categories allowed per slot |
| `clips` | `role → {source_clip, frames, fps, loop, reversed, markers{prepare, release, contact, effect, recover}, sockets ref}` |
| `fallbacks` | Explicit stand-ins, e.g. `cast → attack_4` for a rig with no cast clip, each flagged `stand_in` |
| `contexts` | Movement (walk, run, fly, connector), shove, forced move, death, equipment, condition entry/hold/exit, each choosing a role and its playback |
| `mount` | Mount-and-rider sheets |
| `native_wings` | — |

**Clip roles** are one vocabulary across every pack:
- **movement and stance:** idle, idle_alt, walk, run, run_back, strafe_left, strafe_right, crouch_idle, crouch_move, roll, flip, slide, jump, fly, turn;
- **attacks and actions:** attack_1…n (tagged melee, ranged, thrust, heavy, unarmed), attack_run, shoot, throw, cast, cast_alt, kick, pummel;
- **defence and damage:** block_start, block_hold, hurt;
- **death:** die, die_gore, explode;
- **lifecycle:** emerge, wake_up, stand_up;
- **misc:** taunt, eat, sit, unsheath, special_1/2.

Each rig maps roles to its own source clip names, which stay exactly as the files name them ("Attack 1", "Zombie melee 1", "MeleeSpin"). **Release and contact frames belong to the clip**: they are a fact of that animation. A spell or attack can override them when it has to.

### 4.2 Character: one server creature, or the player body

Keyed by the server id (`creature.goblin_redcap`, `creature.player.humanoid_body`).

| Field | Meaning |
|---|---|
| `rig` | Which rig draws it |
| `portrait`, `icon` | §3.6 |
| `size_scale` | Visual scale, plus a flag when cell size and creature size disagree |
| `default_look` | §3.4 |
| `attacks` | Variant matches: delivery, weapon slot, item id, damage type, outcome, multiattack step → clip role, contact override, trail, impact effect, projectile. Taken from today's attack variants, which match on rig and item |
| `cast` | Gesture role, release sockets ref, spell-specific overrides |
| `reactions` | Block, parry, protection → clip role |
| `death` | Die variant per damage or outcome |
| `kit_mismatch` | E.g. the Orc's art shows a scimitar and shield while its kit is a greataxe and javelin |
| `status`, `notes` | — |

### 4.3 Parts and gear (layered rig)

- **Part:** one modular category (`Chest7`, `Head10`, `Melee20`). It holds one art source per action, its surface data, and its source palette (the 118 source palettes and their gray flags).
- **Gear:** keyed by the **server item id** (`weapon.longsword`, `armor.chain_mail`), not the English name used today, plus `visual_variant_id`. It holds:
  - `layers[{slot, part, look}]`;
  - hand overrides;
  - `ground` (how it looks dropped);
  - item icon;
  - whether it lights (torch radius handled by the server).

  Natural weapons (`weapon.creature.wolf_bite`) are gear with no layers.
- **Appearance mapping:** the server's `AppearanceConfig` values map to parts:
  - `body_category` → body part;
  - `head_category` → head part;
  - `has_beard` → beard part (hard-coded `Head2` today);
  - tints → `tint` looks.

  Rules such as "a helmet hides the hair except Head5 and Head8" become data.

### 4.4 Portraits

- **Player portraits:** class × species group × sex, 312 plus expansions.
- **Creature portraits:** 229 in the bank.
- **Hero aliases.**
- Every portrait has its named sizes.

The 116 roster portraits that exist under source keys get bound to their native ids here.

## 5. Environment (`authoring/environment.tres`)

### 5.1 Terrain: one entry per tile material

Covers the 10 server materials (earth, sand, stone, wood, metal, fabric, glass, water, ice, vegetation). Each entry holds:
- floor art per camera view;
- variants;
- surface data;
- how it receives effects (flat plane, joined faces);
- **material behaviour:** footstep sound, how blood soaks or pools, whether it freezes or burns;
- raised-edge (skirt) art.

Today only earth, stone and wood are drawn; the other 7 materials become `missing` entries.

Stairs and ramps (server `surface_kind`, `slope_axis`) get their own pieces here; the game draws neither today.

### 5.2 Structures: walls, cliffs, fences, door frames

One entry per server boundary structure and material (`wall/stone`, `retaining_wall/wood`, `cliff`, `embankment`, `fence/*`). Each holds:
- straight and corner pieces per view;
- corner-face pairs;
- height handling;
- cutaway behaviour (front walls go translucent);
- destruction banks.

### 5.3 Objects: one entry per server environment item id

Covers the 160 `environment.*` ids: doors, directional doors, windows (wall and insert), furniture and props, chests, traps, levers, torches, campfires, arcane devices, cannons, blockers and barrels. Each entry holds:

| Field | Meaning |
|---|---|
| `views` | Camera quarters and their order (the capture orders differ between packs, so the order is data) |
| `states` | `state → bank` (art source with frames, fps, pivots per pose, surface data, hit mask). Server fields select the state: `is_open`, `door_swing`, `integrity`, `destruction_outcome`, `trap_state`, `is_engaged`, `is_lit` |
| `transitions` | `from → to`: an animated bank range, `reversed` (door closing), sound, effect. Today doors snap to their end pose; the data allows animating them |
| `parts` | Door leaf vs frame with its depth split; window parent wall vs insert |
| `lights` | Light appearance and flame animation for lit objects |
| `draw` | Footprint, height, flat-ground and sort offset. Today `flat_ground` is authored but ignored |
| `icon` | — |
| `status` | — |

Devices (8-direction banks), portals and trap animations exist as data today but are not drawn. They become entries with their art and `status`.

### 5.4 Surfaces: everything that lies on the ground

There is one entry per server **spatial effect** (51 ids, `spatial_effect.*`) and per **residue** (6, `residue.*`), plus decals.

| Field | Meaning |
|---|---|
| `layer` | `ground_surface`, `cloud` or `field` |
| `lasting` | Effect use for the steady state (§3.5), and how it covers the cells (per cell, area mask, footprint) |
| `appear`, `disappear`, `spread` | Effect uses at creation, removal and `footprint_changed` |
| `operations` | `ignite`, `douse`, `freeze`, `electrify`, `vaporize`, `disperse` → transition effect + resulting surface id. This mirrors the server's own rules: oil + ignite → fire; water + freeze → ice; web + ignite → burning web |
| `amount` | For residues: how amount and maximum change the look (blood grows today) |
| `walls` | Whether residues on wall faces are drawn |

The Factory already ships oil ignite/douse, web ignite/douse, water and blood freeze/thaw, water vaporizing to steam, grease and an ice dome. Today the game draws only blood and the Web area; the rest become entries pointing at those clips.

### 5.5 Connectors, lighting, battlefields

- **Connectors:** `traversal.ladder`, `rope`, `lift`, `vertical_stairs`, `passage` → art and the movement body context to use.
- **Lighting:**
  - light appearances (`torch`, `neutral`): colour, flicker, cookie, height;
  - light-level treatments;
  - ambient;
  - directional sources.

  These replace the hard-coded torch colour and the absolute-path cookie.
- **Battlefields:** an optional per-battlefield ambient, background and music.

## 6. Spells and actions (`authoring/abilities.tres`)

### 6.1 Spell: one entry per spell id

Key space from the modern branch: 181 roots plus 6 composition rows.

| Field | Meaning |
|---|---|
| `icon` | — |
| `delivery` | `projectile`, `ray`, `touch`, `melee_spell`, `self`, `cone`, `line`, `sphere`, `wall`, `zone`, `cloud`, `summon`, `buff`, `teleport` |
| `body` | Gesture role (`cast`, `cast_alt`, `touch`), timing overrides, hidden slots |
| `effects` | Effect uses by phase: `cast`, `flight`, `impact`, `area`, `attached`. Each phase is a list, and each is chosen per fact scope (single, per application, per area) |
| `flight` | Speed in tiles/s and stagger between missiles. This replaces the old `speedPxPerSecond` |
| `hit` | Flash look, body material, damage-number timing |
| `palette` | Its own palette, or inherit the damage type's |
| `variants` | Upcast, element choice, outcome (miss, save, critical), form. Each is a partial override of the fields above |
| `applies` | Condition ids and surface ids it creates. These are references only; those entries own their visuals |
| `sound` | — |
| `staging_from`, `status` | — |

### 6.2 Condition: one entry per condition id

| Field | Meaning |
|---|---|
| `icon` | HUD icon. The game shows no condition icons today |
| `lifecycle` | `application`, `sustain` (animated, driven by owner age, never a frozen frame) and `removal` effect uses. Plus `registration` (attachment, scale, origin) and `visibility` (which activities show it, hidden with invisible actors). The Factory's 29 condition lifecycles map here directly |
| `look` | §3.4: body adjust, film, outline, layers, pose |
| `stacking` | Group, exclusive group, priority, maximum layers |
| `feedback` | Apply/remove text and colour, apply/remove body clip |
| `playback_rate` | E.g. haste ×2 |
| `reaction_cast` | E.g. Shield's cast gesture on application |
| `sound` | — |
| `status` | — |

### 6.3 Action, trait, reaction, class feature

One entry per id: `action.*` (79), `trait.*`, `reaction.*`, `class_feature.*`, `feat.*`.

| Field | Meaning |
|---|---|
| `body` | Clip role, markers, hidden slots |
| `target` | Object interaction, e.g. `action.environment.door.open` → the door's `open` transition |
| `effects` | Effect uses, e.g. rage mantle, action surge |
| `feedback` | Text |
| `icon` | — |
| `sound` | — |
| `status` | — |

### 6.4 Attack and damage

- **Attack defaults:** per delivery (melee, ranged, thrown, unarmed, natural, spell attack). They hold outcome feedback, trail, impact and projectile shape. Characters (§4.2) override per rig and item.
- **Damage type:** 13 entries, each with:
  - palette and impact colour;
  - blood or hit response effect (air spray, deposit);
  - number colour;
  - sound.
- **Contexts:** global defaults that entries override: damage, healing, death, death saves, movement, forced movement, equipment, number and badge styles.

## 7. Build, check and run

### 7.1 `server_ids.json`

A tool reads the engine read-only (pinned or modern branch) and writes the list of every id per kind, with icon and portrait keys. The client never talks to the server for this. This is the only link, and it goes one way.

### 7.2 One build command

`tools/build_presentation.gd`, run headless and before export, does three things:

1. **Checks:**
   - every root lists only existing entries, and every entry is listed;
   - every reference resolves (rig, part, palette, look, effect clip in `assets/vfx/index.json`, art file inside `assets/`);
   - markers fall inside frame counts;
   - surface data dimensions match their colour art;
   - no absolute or outside path anywhere.
2. **Writes the runtime files into `build/presentation/`.** The folder has no dot, so Godot's export includes it. The files are compact binary resources split the way the game loads them:
   - a body-source index per rig;
   - spell, condition and action runtime records;
   - environment banks;
   - the UI icon map;
   - measurements.

   This replaces `.derived/body-sources`, `.derived/native-spells` and the run-time palette-range cache.
3. **Writes a coverage report.** For every id in `server_ids.json` it records whether art is ready, partial, stand-in or missing. This is the to-do list for art and staging.

Studio and the game read only `build/`. The Studio can rebuild one entry and reload it after an edit, so reviewing and tuning feed straight back into the source.

### 7.3 Porting

- The `.tres` files are text, and every field is plain data with named units.
- The build can also dump the whole source as one JSON document for tools outside Godot.
- Engine-specific details stay in the build's output, never in the source. That covers which shader implements a look step and the binary resource layout.

## 8. Coverage this must hold (not just today's slice)

| What | Today in the game | Must fit |
|---|---|---|
| Character rigs | 44 | All authored packs, 259 art variants incl. 55 animals and 21 dinosaurs; the 3D pilots (89 clips) and the carriage actors |
| Server creatures | 45 bound | 95 in the pinned engine; 148 roster NPCs on the modern branch |
| Spells | 30–34 staged | About 187 in the Factory package, 181 roots on the modern branch |
| Conditions | 160 recipes, few drawn | All server conditions; 29 Factory lifecycles |
| Items | Keyed by English name | 381 item ids |
| Environment objects | Doors, props, traps, 4 fixtures | 160 `environment.*` ids; 760 catalogued pieces; devices, portals, decals |
| Surfaces | Blood, Web area | 51 spatial effects, 6 residues, 10 tile materials |
| Art conventions | 128 px, 15 frames, 8 rows | 5+ cell sizes, 6–106 frames, 4 direction schemes, 3 cameras, 4 depth/normal encodings, 7 containers |

## 9. Getting there without changing a pixel

1. **Classes and converter.**
   - Write the resource classes and a one-time converter from today's files into the three sources:
     - `authoring/` JSON;
     - `sandbox/staging.json` and batches;
     - `native_effects/index.json`;
     - the `.tres` overlays;
     - `generated/*geometry*.json`.
   - **Proof:** the build regenerates what the game reads today, and the Studio gate stays byte-identical.
2. **Game reads `build/`.**
   - Switch the readers one domain at a time; the gate stays byte-identical after each step.
   - Remove `.derived/` from the runtime path and remove the absolute paths from `project.godot`.
3. **Art inside the project.**
   - Copy the deliveries into `assets/art/`, with binaries backed up per delivery version.
   - Load the finished depth for the 85 roster NPCs the client never imported.
   - Add an export preset and run a test build against the server.
4. **Fill the coverage.**
   - Rigs and characters for the 123 new NPCs.
   - Spells, conditions and actions from the modern branch's ids.
   - Surfaces and objects.
   - Every gap stays visible in the coverage report.
5. **Delete the old files.** `authoring/catalog/*`, `spells/*.json`, `sandbox/*`, `native_effects/index.json` spells, and the rest (the dead files listed in the research).

## 10. Open points for the user

1. **The spells-and-actions file:** keep it as a third file, or fold it into characters? The proposal keeps it separate because spells touch characters (body) and environment (surfaces) alike.
2. **Effect staging authority.** The proposal imports the Factory's staging once, then the source decides, with a diff tool for later Factory changes. The alternative is that the Factory always wins.
3. **Release and contact frames:** owned by the rig clip, with a per-spell override. Today they are per spell.
