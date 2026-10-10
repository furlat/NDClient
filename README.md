# NDClient

Fresh WSL repository, branch `codex/ndclient`. Current work is asset and editable-authoring preparation;
the Goblin/Demon character material and its inspection page are implemented.
The game renderer, UI and SDK integration have not started.

The sole detailed specification is the engine's
[NDClient implementation plan](/mnt/c/users/tommaso/documents/dev/dnd_engine/agent_docs/NDCLIENT_IMPLEMENTATION_PLAN_COMPLETE_2026-10-08.md).

## Artwork folders

```text
.media/
  smallscale/
    modular/                 complete Fantasy Character Creator V1.3
      NakedBody/Idle.png     original layer/action filenames
      ...
    authored/                all owned non-modular creature packs
      animals/
      barbarians/
      characters/
      demons/
      dinosaurs/
      enemies/
      orcs-and-goblins/
      undead/
      zombies-hd/
      zombies-top-down/
  environment/
    doors/ walls/ windows/   selected banks, frames, masks and companions
    props/ traps/ devices/   selected objects and their state animations
    terrain/ portals/        registered surfaces and hatch layers
    fixtures/ lighting/ water/
    library/                 preserved Fantasy originals and source exports
  ui/icons/smooth48/          selected smooth icons
  ui/portraits/192x256/       selected portraits by source bank and art key
  vfx/                       spells, conditions, areas, actions, shared effects
```

**Modular: 3,888 source sheets from the unified Fantasy V1.3 archive.**
The old 1,281-sheet selection is not a second library or an override. Its 50
pixel differences matched old NeuroClient, while both delivered V1.3 packages
agreed with each other. Original engine/source copies remain untouched.
Source files include transparent vendor placeholders; counts are files, not
claims that every sheet contains useful artwork.

**Authored: 7,351 selected original sheets from all ten owned packs**, including
creatures not yet implemented. Combined/with-shadow bodies are selected instead
of redundant shadowless variants. For Goblins/Demons, the authorized separate
clean bodies are now installed too: 1,368 originals in the packs' `Bodies/` folders
(198.69 MiB) for independent body/effect/shadow controls. Original separate
shadows/effects are retained.
The existing 98 derived animal/dinosaur shadow sheets sit in those packs' named
`Derived shadows` folders. Existing rig references reuse the original pack files;
there is no separate `rigs` image-library duplicate.

Existing bindings, timings, sockets, layer order and creature assignments are
preserved in the tracked [client authoring](authoring/README.md). The initial copy
was seeded from the engine; Pygame authoring remains unchanged. Copying an
unimplemented creature does not invent gameplay or animation assignments.
`.runtime/character-assets/` retains original source evidence and copy locations.

[Character component authoring](authoring/characters/README.md) owns source roles
and the completed Goblin/Demon interaction material: all 65 characters and 1,368
combined sheets. Original combined/body/shadow/effect sources preserve neutral
appearance and allow independent strengths and body/VFX hue/tint. The original
43 fixed rigs and modular rig remain unchanged. Other packs retain their initial
partition annotations and qualifications.

```sh
npm ci
npm run review:characters
# http://127.0.0.1:8798/ — all sheets, source comparison and layer controls
```

The review uses `src/rendering/character-material.mjs`, the same leaf material
intended for the game; it is an asset inspection tool, not event-stream Studio.

Modular casting accents referenced by VFX use this same V1.3 modular folder.
Other VFX stay separated by spells, conditions, areas, actions and shared media.
The selected Factory delivery adds 28 spell families, 193 paired depth/normal
banks and preserved flat/live dependencies. They sit directly in the relevant
named folders, such as `vfx/areas/fireball/explosion/` and
`vfx/conditions/protection-from-energy/`, without batch-name or nested `media/`
wrappers. All 38 formerly pending XYZ references have replacements; retired XYZ
banks remain excluded. Desert remains deferred.

## Tracked authoring

[authoring/README.md](authoring/README.md) describes the editable JSON and binding
flow. `authoring/catalog-index.json` is its entry point. Existing IDs now resolve
to installed `/media/` files, including the replacement clocks, directions,
components, geometry and normals. Conditions retain independent lifecycles.

```sh
python3 tools/build_authoring.py
python3 -m unittest discover -s tests -v
```

The one-time importer refuses to overwrite client authoring. Copy tools do not
change it. The current assembler prepares catalog/world/assets/environment and
the existing item appearance/material/variant/source-palette and UI sections; complete client
release integration, renderer, Studio and gameplay UI remain future work.

UI selection remains 594 smooth48 icons and 661 portraits at 192×256, preserving
43 existing creature assignments and the unassigned/player portrait choices.
Selected environment banks and state bindings are adopted in tracked
`authoring/environment/index.json`; its family files assemble the same existing
EnvironmentDocument. [Environment authoring](authoring/environment/README.md)
locates clocks, states, contacts, source assemblies and remaining qualifications.
The 60 delivered source records are tracked, with installed-media links; existing
native door/prop records link to their relevant source records. Wall corner
directions live in `world.json`, separately from cliff corner directions.
Runtime placement/rendering consumers are still pending.

[Item authoring](authoring/items/README.md) now preserves the existing hand and
ground appearances, item variants, material treatments and source palettes.
Equipment references connect to the installed modular library through existing
rig clips; no artwork was copied again. [UI authoring](authoring/ui/README.md) now
connects all 620 icon keys, 43 delivered creature portrait assignments, 618 free
portraits, five premade defaults and 103 choice records. Its existing passive types
are retained. The modular Skeleton Warrior portrait assignment and dedicated
Unarmed icon remain explicit artwork gaps; gameplay UI consumption remains pending.

## Copy tools

`tools/prepare_character_assets.py --engine <engine-path>` copies the full selected
Smallscale library. `prepare_environment_assets.py`, `prepare_ui_assets.py` and
`prepare_vfx_assets.py` own their existing family selections. UI preparation uses
the engine's Python/Pillow environment. VFX copies require `--copy`; otherwise the
tool reports its selection. `prepare_vfx_replacements.py --factory <VFXFactory-path>
--delivery <delivery/manifest.json> --engine <engine-path> --copy` installs the
completed Factory selection and follows its existing bindings, without old XYZ. Preparation follows readable names without checksum
or content-addressed storage machinery.

Authoring, schema, tools and tests are Git-tracked. Artwork and local intake
records are Git-ignored. Original sources remain untouched.
Serve `.media/` through `/media/` when the app is implemented; keep it outside
Vite's `public/` and `dist/` so builds do not duplicate the artwork library.
Factory bank source manifests and the localized delivery manifest remain in
`.runtime/vfx-replacements/` as provenance. Runtime selections and bank metadata
are in tracked `authoring/`, independent of those receipts.
