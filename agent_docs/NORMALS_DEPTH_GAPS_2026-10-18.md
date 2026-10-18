<!-- Producer handoff: depth/normal coverage of every character, creature and environment source, checked 18 October 2026. -->

# Missing depth/normals: characters, creatures and environment (checked 2026-10-18)

**Short answer:** No character or creature body sheet in the source tree is missing depth and normals. All 4,381 authored sheets and all 3,410 nonempty modular sheets have Original, Gentle and Reference normals plus depth on disk. I checked that every file exists; nothing was assumed from the reports. That includes all 148 roster NPCs (3,026 sheets).

What remains falls into four groups:
- **Partial or failed sheets to redo:** 109 in the roster, 31 other creatures, 288 modular weapon/offhand sheets.
- **Sheets the reconstruction method can't fix:** the source art has one view copied into all 8 facing rows. These need hand-made normals.
- **Things excluded on purpose:** effect and shadow layers, and some environment items (shadow-only tiles, flames, decals, utility graphics).
- **Catalogue-only environment items the client doesn't use:** vendor tileset characters and effects, and the arena kit.

One thing will look like missing assets but isn't. The client's `generated/creature_geometry.json` (Oct 12 20:54) only loads 1,438 sheets: goblins, orcs, demons and the 98 summoned animal sheets. It was built before the full-library pass finished. **85 of the 148 roster NPCs (1,686 sheets) have finished geometry in the factory but aren't loaded in the client.** These are all barbarians, characters, undead and zombies, and 12 enemies. This is a client import step, not production work. `SCOPE.md` lists "Six SkeletonArcher05 clips remain outside this delivery". Those six clips are in the full-library delivery (`undead/5Archer`).

Abbreviations: `SRC` = `/mnt/c/Users/tommaso/Documents/Dev/NDClientData/.media/smallscale/authored`, `FAC` = `/mnt/c/Users/tommaso/Documents/assets/fantasy-unified-catalog/authored-creature-geometry-2026-10-12`.

## 1. Summary tables

### Characters and creatures
"Partial" means sheet support is under 80%. "Failed" means a sheet with whole frames that have source pixels but no surface.

| Family | Variants | Sheets | With D+N | Missing | Partial | Failed | Pixel cov. | In client | Notes |
|---|---|---|---|---|---|---|---|---|---|
| orcs-and-goblins | 31 (17 Goblin, 12 Orc, Animal 1/2) | 624 | 624 | 0 | 0 | 0 | 92.5% (G/O only 92.2%) | 596 | 222 sheets under 90%. 1 invalid-normal frame. Animal 1/2 not in client |
| demons | 34 (5 Beast, 6 Elite, 13 Spawn, 10 Imp) | 744 | 744 | 0 | 15 | 0 | 94.0% | 744 | 2 invalid-normal frames |
| barbarians | 9 | 278 | 278 | 0 | 13 | 1 | 94.4% | 0 | 62 sheets are 192 px cells |
| characters | 9 | 267 | 267 | 0 | 4 | 3 | 96.7% | 0 | 7DeathKnight flips/rolls failed |
| enemies | 13 | 144 | 144 | 0 | 2 | 0 | 94.0% | 0 | 13Shepard is not in the roster |
| undead | 9 | 279 | 279 | 0 | 32 | 0 | 92.3% | 0 | 4Berserker and 6Warrior weakest |
| zombies-hd | 36 | 540 | 540 | 0 | 35 | 0 | 91.6% | 0 | Die clip under 80% on 35/36. Acid/Blood (10 sheets) are effects, excluded |
| zombies-top-down | 42 | 720 | 720 | 0 | 27 | 0 | 92.7% | 0 | Decay 01/04 Die at 5–6% |
| animals | 55 | 557 | 557 | 0 | 10 | 3 | 97.1% | 76 (14 variants) | 6 sheets have repeated facing rows |
| dinosaurs | 21 | 228 | 228 | 0 | 1 | 0 | 97.3% | 22 (4 variants) | Raptor Spit has repeated rows |
| **Authored total** | **259** | **4,381** | **4,381** | **0** | **139** | **7** | — | **1,438** | — |
| modular (Fantasy V1.3) | 132 categories | 3,888 | 3,410 | 478 by design | 288 (26 under 50%) | 0 | 96.04% | 3,888 records | 348 effect/shadow excluded, 130 empty Mount sheets |

- **Roster (148 NPCs, 3,026 sheets):**
  - 63 NPCs (1,340 sheets) are loaded in the client.
  - 85 NPCs (1,686 sheets) exist in the factory only.
  - 109 roster sheets are under 80% or failed.
- **Distinct actions per pack:**
  - Demons and orcs/goblins: 35 each.
  - People packs: 32–38.
  - zombies-hd: 15. zombies-top-down: 28.
  - Animals: 32. Dinosaurs: 29.
  - Modular: 30.

### Environment
Sources: `environment-geometry-production-2026-10-09` (725 families, 324 banks, 556 resources) plus the quality pass (464 assets).

| Group | Items | With D+N | Missing / no D+N | Partial (qualified) | Notes |
|---|---|---|---|---|---|
| Ground families | 113 | 113 | 0 | 65 coarse receiver proxies | Quality pass: 40 inferred-detail, 8 macro retained, I5 cracks unresolved |
| Wall / Wall-window | 125 | 125 | 0 | 2 proxy, 1 inferred | — |
| Misc | 194 | 194 | 0 | 9 proxy, 1 inferred | — |
| Roof, Stone, Flora, WallFlora, Chest, FirePlace, Torch, interiors, traps, fixtures, doors, devices | 199 | 199 | 0 | Door: 2 proxy | — |
| Tree | 19 | 18 | 1 (Tree Shadow, shadow-only) | — | — |
| Animations (vendor) | 42 | 37 | 5 role-only | — | Fire, Fire2, PortalIdle, PortalOpen, Torch-1 |
| decals | 12 | 0 own | 12 role-only | — | Use the parent surface's depth/normals |
| Shadow1–13, BLACK TILE, TilePreview | 15 | 0 | 15 not applicable | — | Shadow and utility art |
| Banks (prop 168, door 62, window 47, trap 36, wall 11) | 324 | 324 | 0 | See §4 | 96 upgraded with source passes, 228 kept existing |
| Resources | 556 | 536 | 20 role-only | 44 proxy, 4 inferred | 16 `torch.flame.00–15`, 4 `spikes.blood.{e,n,s,w}.0` |
| Catalogue-only, outside geometry scope | 35 entries | 0 | 35 | — | Not referenced by client authoring (grep found none) |

- I relied on the delivery's own whole-scope validation for the environment (`FINAL_VALIDATION.json`: pass, 15,102 referenced files). I did not match each of the ~40.6k files in `NDClientData/.media/environment` one by one.
- The client loaded 1,142 quality packets (`environment_receiving_normals.json`): 0 failures, all 464 assets have an explicit decision.

## 2. Missing list for a producer (by priority)

### P1 — Roster NPCs
- **Nothing is missing.**
- **Client import:** run `register_creature_geometry` against `FAC/full-library/delivery/catalog-people.json` and `catalog-zombies.json`. This brings in 85 NPCs: barbarians 9, characters 9, enemies 12, undead 9, zombies-hd 22, zombies-top-down 24.
- **Redo candidates** (sheet → coverage; † = repeated facing rows, needs hand-made normals):
  - **characters** (`SRC/characters/With shadow/`):
    - `7DeathKnight/`: Rolling 0.2% (14/15 frames failed), MeleeRun 8% (5 failed), FrontFlip 10% (12 failed).
    - `3Wizard/Run` 65% †.
  - **barbarians** (`SRC/barbarians/With shadow/`):
    - `6Barbarian/` 75–80% on 10 sheets: 180Turn, AttackRun, FrontFlip, QuickSlide, Rolling, Run, RunBackwards, StrafeLeft, StrafeRight, Walk.
    - `9Shaman/`: Special2 50%, Pummel 80%.
    - `5BarbArcher/SittingChair` 77% (1 failed frame).
  - **undead** (`SRC/undead/With shadow/`):
    - `4Berserker/` 67–76% on 11 sheets: 180Turn, AttackRun, FrontFlip, QuickShot, QuickSlide, Rolling, Run, RunBackwards, StrafeLeft, StrafeRight, Walk.
    - `6Warrior/` 70–77% on 9 sheets: 180Turn, AttackRun, FrontFlip, Rolling, Run, RunBackwards, StrafeLeft, StrafeRight, Walk.
    - `3DarkKnight/` 76–80% on 9 sheets: 180Turn, AttackRun, FrontFlip, Idle, Run, SlideStart, StrafeLeft, TakeDamage, UnSheath.
    - `1Brute/` 73–75%: FrontFlip, QuickSlide, Special2.
  - **enemies:** `SRC/enemies/With shadow/11Arcane elemental/Attack4` 59%, `12Guard/Idle` 79%.
  - **demons** (`SRC/demons/Combined/`, inputs from `Bodies/`):
    - `Demon Beast 3/`: Die 2 61%; Attack 1, Attack 3, Die 1, Explode Copy, Roll 1 at 76–80%.
    - Imp 2, 3, 4, 5 `/Explode` and Imp 6, 7, 8, 9, 10 `/Explode Copy`: 65–79%.
  - **zombies-hd** (`SRC/zombies-hd/With shadow/<v>/Die.png`), 51–79%, 22 sheets: ZombieFemale1–7, ZombieHulk1–2, ZombieMale1–3 and 6–9, ZombieMonster1–3, ZombieRadioactive1–3.
  - **zombies-top-down** (`SRC/zombies-top-down/Zombies with shadow/`), 21 sheets:
    - Zombie Decay 01: Die 6%, Die (Gore) 16%.
    - Zombie Decay 04: Die 5%, Die (Gore) 14%.
    - Zombie Swamp 08: Die (Gore) 60%.
    - Zombie Radioactive 01–03: Taunt 61–70% and Die (Gore) 75–76%. Radioactive 04: Taunt 74%.
    - Die (Gore) at 73–80%: Zombie 01, 02, 08, 09; Decay 02, 05; Swamp 02, 04, 09.
  - **orcs-and-goblins:** no sheet under 80%. Weakest variants: Goblin 05 83.8%, Goblin 10 85.9%, Goblin 07, 01, 03, 09 (86–87%).

### P2 — Other creatures (no sheets missing; 31 partial)
- **animals** (`SRC/animals/With shadow/`):
  - Cat Black/Attack2 17% † (7 frames failed), Cat White/Attack2 17% † (7 frames failed).
  - antilope, Deer, Oryx, Stag `/Die` 31–32% †.
  - Boar/Walk 40% †.
  - ELITE Wolf: Attack1 70%, Attack3 65%, Die 69%.
  - Chicken/Die 88% (4 frames failed).
- **dinosaurs:** `SRC/dinosaurs/With shadow/Velociraptor/Raptor Spit` 33% †.
- **zombies-hd, non-roster** `<v>/Die`, 49–73%: ZombieCop1–4, ZombieGeneral1–2, ZombieMale4, ZombieMale5, ZombieSoldier1–3, ZombieSoldier5–6.
- **zombies-top-down, non-roster** Die (Gore):
  - Zombie Swamp 06 23%.
  - Zombie Cop 01–03 74–80%.
  - Zombie Soldier 05 72%.
  - Zombie 07 80%.
- **Effect sheets never processed** (only if you want them):
  - `SRC/zombies-hd/With shadow/Acid/Acid1–5.png` and `Blood/Blood1–5.png`.
  - Per-family `Effects/` layers: `SRC/demons/Spritesheets with seperated shadows and effects/<v>/Effects` and `SRC/orcs-and-goblins/Seperate shadows and effects/<v>/Effects`.

### P3 — Modular components (`/mnt/c/Users/tommaso/Documents/Dev/NDClientData/.media/smallscale/modular/`)
- **Excluded by design (no D+N), 348 sheets:**
  - `Effect1–5/` (30 each)
  - `GunFire2–4/` (6 each)
  - `Magic1–3/` (30 each)
  - `Slash1–2/` (30 each)
  - `Shadow/` (30)
- **Empty sources, 130 sheets:** `Mount1–5/` (26 each). Only the 4 Ride* actions have pixels.
- **Partial, 288 sheets under 80%:**
  - Melee: 218 sheets. Melee20 30, Melee7 24, Melee5 22, Melee6 22, Melee3 20, Melee1 18, Melee4 15, Melee19 11, Melee2 11, Melee24 7, Melee25 7, Melee9 6, Melee13 5, Melee23 5, Melee17 4, Melee8 4, Melee16 3, and 1 each for Melee10, 14, 15, 21.
  - Ranged: 65 sheets. Ranged4 23, Ranged3 16, Ranged7 15, Ranged5 7, Ranged1 4.
  - Offhand1 4, Offhand2 1.
  - Under 50% (26 sheets): Melee20 ×16 (AttackRun2 33%, Attack4 35%, Idle4, Attack3, Run, AttackRun, TakeDamage, CrouchRun, Attack1, Walk, Slide, Attack6, Attack2, Taunt, StrafeLeft, Special1), Melee3 ×4 (Attack4 40%, Attack3, Idle3, AttackRun2), Melee6 ×3 (Attack3, Attack4, AttackRun2), Melee7 ×3 (AttackRun2, Idle2, Attack3).

### P4 — Environment (none of these is used by the client)
`CAT` = `/mnt/c/Users/tommaso/Documents/assets/fantasy-unified-catalog`
- **Vendor characters:** `CAT/a-original/vendor/Fantasy tileset - 2D Isometric/Characters/{Enemy 1,Enemy 2,Enemy 3,NPC1,NPC2,NPC3,Player}/`, 24 sheets each, 168 total. 1920×1024, 128 px cells.
- **Vendor effects:** `…/Animations/Effects/{AoE,Bolt,Buff1–Buff10,Cone,Dash,Hook,LevelUp}/` (14 folders), `…/Animations/Props/Skeleton explosion/` (16 frames), `…/Other/` (7 files).
- **Arena kit:**
  - `CAT/c-new-props/arena-kit/`: 342 piece files, no sprite D+N (GLB models exist).
  - `constructor/crowd/`: 1,152 depth-only sheets with **no normals**, 576 quiet + 576 react.
  - 9 arena scene builds: depth only, no normals.
- **By design, no D+N:**
  - Shadow1–13 and Tree Shadow.
  - BLACK TILE, TilePreview.
  - `torch.flame.00–15`, `spikes.blood.*.0`.
  - Fire/Fire2/Portal/Torch-1 vendor animations.
  - 12 decals.
- **Desert:** excluded from the catalogue and from geometry.

## 3. Format to match

**Characters and creatures**
- **Sheet layout:**
  - Native sheet, no resampling.
  - One column per native frame: usually 15, but 6/7/8/10/13 are kept as-is.
  - 8 facing rows, top to bottom: **E, SE, S, SW, W, NW, N, NE** (rows 0–7).
- **Cell size:**
  - 128 px: modular, goblins/orcs, demons, top-down zombies, most people.
  - 192 px: some barbarians, undead, enemies and zombies-hd.
  - 64/74/84/86/96/118/124 px: animals and dinosaurs.
- **Camera:** fixed 45° elevation. Optical origin is (w/2, 3h/4), i.e. (64,96) at 128 px. Not a calibrated physical camera.
- **Normals (`normals.png`):**
  - Linear RGB, no sRGB conversion: `n = normalize(2·RGB/255 − 1)`.
  - Axes: screen-right, screen-up, toward camera. Facing is already baked in.
  - Godot canvas uses `(nx, −ny, nz)`.
  - Alpha 255 = supported, 0 = unsupported.
- **Depth (`depth.png`):**
  - Same byte in R, G and B: `D = lo + (R−32)/192·(hi−lo)`. Bytes 32–224; larger = nearer.
  - The range is per packet. 128 px cells use [−181.1371, 249.0193]; other sizes carry their own `depth_range`.
  - Float data is in `geometry.npz` (camera_depth, camera_normals, raw_support, normal_valid; NaN = unknown).
- **Normal variants:**
  - Original = `normals.png`.
  - Gentle = 1 pass, Reference = 2 passes.
  - Each pass is a simultaneous 4-neighbour update `n + 0.2·Σ(nb − n)`, renormalized, run only inside each cell on admitted texels.
  - Quantize once at the end: `round_half_even(clamp((n+1)·127.5))`.
  - Alpha and unadmitted RGBA stay byte-identical.
- **Masks:**
  - L8, 0/255. Creatures: `raw-support.png`, `normal-valid.png`.
  - Modular adds `lighting-valid`, `solid-valid`, `source-support`, `unsupported`, `disagreement`.
- **Folder layout:**
  - Creatures: `FAC/full-library/delivery/actions/<pack>/<variant-slug>/<action-slug>/` with `colour.png`, `normals.png`, `normals-gentle.png`, `normals-reference.png`, `depth.png`, `raw-support.png`, `normal-valid.png`, `geometry.npz`, `layout.json`, `metrics.json`, `normal-profiles.json`. Indexed by `catalog-<group>.json` and `complete-source-index.json`.
  - The first delivery uses `FAC/delivery/actions/<family>/<action>/`, e.g. `goblin-01/attack-1`.
  - Modular: `…/modular-character-geometry-2026-10-11/full-components/exports/fused/maps/<Category>/<Action>/` plus `reference.json`. Gentle/Reference are in `/mnt/c/Users/tommaso/Documents/Dev/NDCharacterLight/.derived/normals/{gentle,reference}/<Category>/<Action>.png`.
- **Shadow and effect layers are excluded.**
  - Geometry is built from the body only: the `Bodies` layer, or the original Shadowless archive art.
  - Shadow, effect and accent layers are kept only as reference.
  - Production uses a generated Dominant shadow from depth, with no prebaked shadow.

**Environment**
- 4 camera quarters (e/s/w/n).
- New paired packets: RG = 16-bit big-endian depth, BA = octahedral normal. A is normal data, not opacity.
- 88 legacy `rg16le_contact` banks stay unchanged.
- Linear data: no gamma, premultiplication or filtering. Use each packet's own basis, ray, pivot and normal transform.

## 4. Partial-coverage caveats
- **Demons, 94.0%:** 3.74M body pixels unsupported. 659 poses have silhouette IoU under 75%; 4,081 poses are under 90% support. Some normals are invalid on 2 poses (Demon Beast 2 Attack 1 and Attack 4).
- **Goblins and orcs, 92.2%:** 3.26M pixels. 551 poses have IoU under 75%; 4,347 are under 90%. 1 invalid-normal pose (Goblin 09 Run Backwards).
- **Other groups:** people 94.3%, zombies 92.1%, animals 97.0%, modular 96.04%.
- **Failed poses:** 50 frames on 7 sheets have source pixels but no surface (listed above). There are also 25 blank source frames (single trailing blank frames on QuickSlide/Special1/SittingChair/QuickShot and similar). These are source gaps, not failures.
- **Repeated facing rows:** 9 sheets have one source view copied into all 8 rows. They need hand-authored normals: antilope/Deer/Oryx/Stag Die, Boar Walk, Cat Black/White Attack2, Velociraptor Raptor Spit, 3Wizard Run.
- **Modular:** losses are thin weapons, mostly one-pixel features. An experimental thin-weapon tolerance test raised coverage but changed depth and normal directions substantially, so it was not merged. The translucent NakedBody3 has normals but doesn't count as solid geometry.
- **Environment:**
  - 78 families are coarse receiver proxies: 65 Ground, 9 Misc, 2 Door, 2 Wall.
  - Ground I5 crack detail is unresolved.
  - In fine ground, 2,867 support-gap pixels across 77 views fall back to the proxy.
  - 6 intact Chest states (24 quarter records) keep original normals because of a 256 vs 384 px registration mismatch.
  - 66 break banks have 264 frame-0 records that keep originals.
  - 17 coarse Ground families keep their original normals.

Key evidence:
- `FAC/full-library/delivery/complete-source-index.json`
- `/mnt/c/Users/tommaso/Documents/Dev/NDCharacterLight/analysis/AUTHORED_LIBRARY.md`
- `…/modular-character-geometry-2026-10-11/full-components/exports/queue/package/catalog.json`
- `/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/generated/creature_geometry_intake.json`
- `…/environment-geometry-production-2026-10-09/family-worklist.csv`
- `…/environment-normal-quality-2026-10-12/quality.json`

## Follow-up delivery (18 October, 23:16)

`fantasy-unified-catalog/geometry-gap-repairs-2026-10-18/` (copied, without
float caches and review images, into `assets/art/geometry/repairs-20261018/`):

- **Modular Melee20 Attack4 and AttackRun2:** a finer ray-sampling rescue adds
  34 and 14 supported pixels (35.0 → 35.6% and 33.0 → 33.3%). The remaining
  thin-weapon gaps have no depth consistent with all eight silhouettes at the
  frozen tolerance; loosening the tolerance was rejected.
- **Three invalid-normal texels** (Goblin09 RunBackwards, Demon Beast 2
  Attack 1 and 4): normal alpha set to 0 where `normal_valid` is false.
  The client already gates on `normal_valid`.
- **Creature geometry intake table:** 4,381 records (1,438 already registered
  + 2,943 animals, people, zombies), covering the 6 SkeletonArcher05 clips.
  The characters migration uses it as the full-library cross-check.
- **Not for adoption:** the DeathKnight Rolling/FrontFlip/MeleeRun
  reconstructions. Their source art mixes translucent motion, shadow and
  effect pixels, so a body/shadow mask is needed first.
- **Unchanged:** the 9 repeated-view sheets and the Decay zombies' death poses
  stay qualified.
