# NDClient

WSL repository recreated on 9 October 2026, branch `codex/ndclient`.
Current step: repository setup and preparation of Smallscale character assets
only. The renderer, UI, SDK integration and other asset families are not started.

The single implementation plan remains in the engine repository:
[NDClient implementation plan](/mnt/c/users/tommaso/documents/dev/dnd_engine/agent_docs/NDCLIENT_IMPLEMENTATION_PLAN_COMPLETE_2026-10-08.md).
There is no second plan in this repository.

## Prepared artwork

| Family | Copied original sheets |
| --- | ---: |
| A: complete modular Character Creator V1.3 plus the existing x256 comparison source | 4,368 |
| B: all sheets from ten owned fixed-character packs | 11,742 |
| Existing authored character resource references, including derived shadows | 2,146 |

The source records resolve to **15,320 unique PNG payloads / 2,844,969,775 bytes
(2.650 GiB)** after byte-identical files share storage. The 2,146 references are
not necessarily additional files. They retain already-installed adaptations
alongside the complete vendor sheets. No image is resized, recolored or repacked.

B includes Animals, Dinosaurs, Orcs/Goblins, Demons, HD Barbarian, HD Character,
HD Enemy, HD Undead, HD Zombie and Top-down Zombie Pack 2. Every sheet variant
in these packs is included, independently of whether native content currently
uses it. Separate body/shadow/effect sheets and combined versions are preserved.
Duplicate loose frame exports, pack executables, videos and unrelated assets
remain in the original archives. Existing content exclusions stay unchanged;
having a sheet installed does not enable a creature or override its authoring.

No standalone VFX, icons/portraits or environment banks are migrated in this step.
Original Magic/Effect layers that belong to A, and baked/separated creature
effects belonging to B, are part of their character packs.

## Existing bindings remain authoritative

Use the existing [reviewed fixed-character mappings](/mnt/c/users/tommaso/documents/dev/dnd_engine/agent_docs/audits/FIXED_CHARACTER_ANIMATION_MAPPINGS_2026-10-01.json)
and [integration handoff](/mnt/c/users/tommaso/documents/dev/dnd_engine/agent_docs/audits/FIXED_CHARACTER_RENDERER_INTEGRATION_2026-10-01.md),
the [art-led roster](/mnt/c/users/tommaso/documents/dev/dnd_engine/agent_docs/ART_LED_NPC_ROSTER_DESIGN_2026-09-30.md),
and the later canonical `game/data/rigs/*.json` in that engine checkout.
The older mapping document contains 150 nonanimal character selections and
explicit calibration limitations; it is not permission to invent missing values.

All 43 current fixed-rig JSON documents, modular bindings/rig tables/sockets and
the three mapping/handoff documents have exact local reference snapshots under
`.runtime/character-assets/authoring-reference/` (49 files). They remain unchanged,
not newly generated bindings or an alternative editable source of truth.
All 1,205 body/effect hash references in the 150-character mapping were found in
the prepared payloads. No action assignment, FPS, pivot or creature binding is
created by this intake.

## Local storage and Pixi

```text
.media/objects/                  original PNG bytes, one copy per content hash
.runtime/character-assets/      intake receipt and exact authoring references
src/                           reserved; no client implementation yet
tools/prepare_character_assets.py
```

`files.jsonl` in the intake directory records original pack/member names and
payload locations; `summary.json` records counts and bytes. These are copy
receipts, not runtime asset bindings or a complete presentation release.
Original archives and canonical engine data remain untouched.

[Pixi Assets](https://pixijs.com/8.x/guides/components/assets) loads relative or
absolute URLs and supports `basePath`; it does not require a disk folder named
`public`. The plan serves this ignored store at `/media/` via an explicit static
mapping when the app is set up. [Vite's public directory](https://vite.dev/guide/assets.html#the-public-directory)
is copied into build output, so the media store stays outside `public` and `dist`.
No web server or Vite application has been created in this step.

Reproduce the offline intake with the original sources in their recorded locations:

```bash
python3 tools/prepare_character_assets.py \
  --engine /mnt/c/users/tommaso/documents/dev/dnd_engine
```

The tool checks copied bytes and reuses identical payloads. Dinosaur sheets use
the already extracted source, checked against the original RAR member sizes and
CRCs through the installed Windows 7-Zip. It does not install software, change
bindings, regenerate SDKs or scan art at normal application startup.

Artwork, receipts/reference snapshots, dependency caches and builds are ignored
by Git. No remote has been configured. A leftover `node_modules` directory was
already present; it was left untouched and ignored, and is not a new dependency
installation or part of the asset size above.
