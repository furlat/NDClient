# Recording provenance and scenario audit — 2026-10-11

Scope: all 20 active case descriptors, every referenced raw packet, retained native server spools, private encounter recipes, native actor/loadout/action data, and the presentation release each case actually opens. No backend, SDK, gameplay packet, or artwork changes were made for this audit/correction.

## Provenance result

All 20 active cases have file evidence of server origin: **197 descriptor-referenced packets match retained server `.frames` payloads byte-for-byte**, at the same game epoch, audience, and sequence. No case currently lacks this retained-byte evidence. The original ranged and arc recordings also matched before their replacements; their setup defects were real encounter choices, not fabricated traffic.

The comparison parsed the four-byte network-order length framing implemented by `dnd_engine/server/recording.py:52–65` and compared the payload directly with each recording file. `tools/capture-session.mts:26–30` writes the SDK follower's raw bytes. Labels such as `source: "server-sdk"` and filenames were not used as proof. This is local retained capture evidence, not an independent cryptographic attestation of arbitrary local files.

Eight Crypt cases are prefixes of the same game epoch `55cd8114-4177-4e96-a888-cc87c90780bd`, retained under `.runtime/server-spool`. They are useful different action prefixes, not eight independently captured encounters. The other twelve cases have separate native sessions under `.runtime/private/*/spool`. Private credentials were neither copied into this report nor changed for existing sessions.

## All active cases

Each row's byte count is fully matched. “Current” means release `20261010T222246.146465Z-73c43b1f`; A means `20261010T221556.505524Z-2ab466aa`; B means `20261010T075703.535851Z-8bcf7cfc`.

| Case | Matched packets | Effective release | Actors, action fit, remaining issue |
|---|---:|---|---|
| `anchored-spells` | 27/27 | A | Modular Sorcerer/Fighter; native Ashhook victims. Healing/Bless select ally; Burning Hands selects Blue victim. Latent added shortbows on fixed Ashhooks. |
| `arc-spells` | 28/28 | Current | RECAPTURED: modular Sorcerer/Fighter, native Ashhook/Gloomplates; enemy-only successful spell targets; no weapon grants. |
| `conditions` | 7/7 | Current | Original Crypt modular Fighter/Sorcerer; Haste potion and door action. |
| `crypt-door` | 5/5 | Current | Original Crypt modular Fighter/Sorcerer; movement and door action. |
| `dash` | 13/13 | Current | Original Crypt modular Fighter/Sorcerer; native Dash sequence. |
| `dash-follow` | 15/15 | Current | Original Crypt modular Fighter/Sorcerer; native Dash and following turns. |
| `fighter-class-actions` | 4/4 | Current | Native level-5 Fighter, injured by authored setup for Second Wind; native Ashhook; no weapon mismatch. |
| `fireball` | 4/4 | Current | Native level-7 generic caster maps to modular rig; six Ashhook victims. Latent added shortbows on fixed Ashhooks. |
| `fireball-sorcerer` | 3/3 | Current | Native level-5 modular Sorcerer and six Ashhook victims. Latent added shortbows on fixed Ashhooks. |
| `fog-cloud-lifetime` | 5/5 | Current | Native modular Sorcerer with explicit existing Fog Cloud grant; six Ashhook actors. Latent added shortbows on fixed Ashhooks. |
| `inventory-flow` | 7/7 | Current | Native modular Fighter equipment changes; native Ashhook observer; no added bow to fixed rig. |
| `items` | 8/8 | Current | Original Crypt modular Fighter/Sorcerer; native handaxe drop and potion use. |
| `jump` | 11/11 | Current | Original Crypt modular Fighter/Sorcerer; native movement/jump. |
| `lantern-crypt` | 3/3 | Current | Original Crypt modular Fighter/Sorcerer; native opening/movement prefix. |
| `orbit-spell` | 9/9 | B | Modular Sorcerer with explicit Spirit Guardians grant; Fighter/Ashhooks. Older pin has all required rigs. Latent Ashhook shortbows. |
| `ranged` | 3/3 | Current | RECAPTURED: four native Reedshots, native shortbow variant, no item grants; actual equipped bow fires. |
| `spatial-current` | 13/13 | Current | Original Crypt modular Fighter/Sorcerer; same 13-packet prefix as Dash, not an independent capture. |
| `transport-spells` | 18/18 | B | Modular Sorcerer with explicit transport/summon grants; authored Wolf appears. Older pin has all required rigs. Latent Ashhook shortbows. |
| `wall-of-fire-forms` | 10/10 | Current | Native level-7 generic caster and Ashhooks. Root repinned descriptor to supported release; packets unchanged. Latent Ashhook shortbows. |
| `wall-of-fire-ring` | 4/4 | Current | Native level-7 generic caster and Ashhooks. Root repinned descriptor to supported release; packets unchanged. Latent Ashhook shortbows. |

## Concrete faults and corrections

1. **Axe goblins firing bows was a setup mismatch.** Original `ranged/000003.json` contains native `Attack_RANGED_MAIN` / `source_item_id: "weapon.shortbow"`. All four actors were `content.neurodragon:creature:creature.goblin@1`, whose authored art is `smallscale.goblin01` / Ashhook with a handaxe. The existing server acceptance setup explicitly grants a shortbow to this creature (`devtools/player_server_acceptance/fixtures.py:72–76`). Fixed art uses its authored parts (`src/presentation/actors.ts:24–30`); it cannot swap a baked axe into a newly granted bow. This was not a reason to invent replacement rig selection.

   Replaced the active `ranged` case with a separate real server capture of four **Reedshots**, using `content.neurodragon:creature:creature.goblin_reedshot@1` → `smallscale.goblin03`, and native `weapon.roster.shortbow_a0000007`. No item/spell grants. Native attack sequence 2 identifies that exact equipped item UUID and `RANGED_MAIN`. Current immutable presentation is pinned. Old complete case preserved at `.runtime/reviews/recording-audit/ranged-axe-goblin-original`; capture setup, SDK evidence and provenance live in `.runtime/recordings/ranged/capture-notes.json` and `.runtime/private/ranged-reedshot/`.

   Other exact authored ranged options are Quicktail (`creature.goblin_quicktail` → `smallscale.goblin09`, `weapon.roster.shortbow_20000002`) and the existing modular Fighter with its native longbow. Gutterknife / goblin17 is a **pistol** character, not a shortbow alternative. Goblin source kits are in `dnd_engine/dnd/monsters/goblins.py:87–204`.

2. **The original arc script deliberately selected allies by sorting affected-count without faction intent.** `.runtime/sdk-capture-driver/arcs.mjs` picked the greatest `affected_count` for both spells. Archived `steps.json` records Lightning at `[0,0]`, affecting only the allied Injured Fighter, and Call Lightning at `[3,7]`, affecting the Fighter and caster. Their native geometry correctly describes those bad choices; changing rendering direction would falsify it.

   Replaced active `arc-spells` with **28 new real server packets**. Existing modular Sorcerer and Fighter ally, Ashhook target for True Strike, and two existing noncaster Gloomplate enemies at `[9,7]` and `[9,10]`. Only the existing spell grants remain; no weapon grants, HP overrides or suppressed handlers. True Strike sequence 11 completes and kills Ashhook; Lightning sequence 20 completes and kills the eastern Gloomplate; Call Lightning sequence 27 completes on the southern Gloomplate.

   Native Lightning discovery uses representative selection `[5,7]` for the eastward line: origin `[4,7]`, direction `[1,0]`, length 100 feet, width 5 feet. Its declared target list contains **only Blue Gloomplate east**, at `[9,7]`. Call Lightning's native sphere is centered at `[9,10]`, radius 7 feet, with **only Blue Gloomplate south** declared. Both native previews return `can_confirm: true` and affected cells containing the intended enemy. Their `effective_target_uuids` fields are empty for these positional selections; the actual identity evidence comes from native discovery and the committed spell's `declared_target_entity_uuids`, not an invented preview field. Caster and ally are absent from these lists.

   Exact selected targets, preview cells, native area geometry and declared identities are preserved in `.runtime/recordings/arc-spells/capture-notes.json`. Old complete case: `.runtime/reviews/recording-audit/arc-allied-targets-original`. Configuration and installed-SDK driver: `.runtime/private/arc-spells-enemy-bruisers/`. An earlier Wispbinder candidate was not promoted: real automatic Counterspell canceled the spells. The correction used existing noncaster creatures; it did not disable native reactions.

3. **Wall case pins predated their required authored caster mapping.** Both Wall of Fire descriptors originally pinned B, which lacks `creature.generic_caster`. Their native source is a level-7 generic caster; current authoring/current immutable release explicitly maps it to `neuroclient.modular`. Root repinned only those two descriptors, with originals backed up under `.runtime/reviews/recording-audit`; native bytes stay unchanged. All 20 active cases now resolve every observed creature identity in their effective release. The older B pins in orbit/transport contain every rig those cases use and are not broken merely because they are old.

   Root-level `.runtime/presentation/catalog/creature_rigs.json` is an older redundant copy, but `openRelease` follows `index.release_index` before document reads (`src/presentation/release.ts`). It is not the production source selected by `/presentation/index.json`; this audit did not patch it. Existing Wall `capture-notes.json` still describes the historical missing-rig limitation and should be read as capture-time history after repinning, not current failure.

## Remaining setup debt, kept separate from observed failures

Exactly **eight** active cases retain an irrelevant shortbow grant on baked Ashhook actors: `anchored-spells`, `fireball`, `fireball-sorcerer`, `fog-cloud-lifetime`, `orbit-spell`, `transport-spells`, `wall-of-fire-forms`, `wall-of-fire-ring`. None of their recorded actions has an Ashhook bow attack. Their existing native spells and victims remain usable, but future recaptures should omit those grants or select authored archers if ranged attacks are actually needed. Rewriting already captured native loadouts would destroy provenance.

Sorcerer spell grants are explicit existing encounter setup, not proof those spells belong to the standard premade's unmodified progression. Healing Word/Bless/Spirit Guardians/Call Lightning/Conjure Animals cases should be described as spell presentation encounters. `anchored-spells` correctly directs Healing Word/Bless to its injured ally and Burning Hands to a Blue enemy. The native Fighter class/inventory cases use the existing premade and appropriate modular equipment. The `wall-of-fire-ring` title still says “segment and ring” although that particular case contains a ring; the separate forms case provides segment coverage. These are documentation/setup clarity issues, not grounds to fabricate events.

## Checks completed

- Original and replacement raw packets checked against retained server frame bytes; all 20 active effective-release creature maps inspected.
- Replacement ranged: six targeted tests (cast routing, actor scale/projectiles, log evidence, displayed logs) passed; typecheck passed. Real Studio worker/channel browser check: no problems/issues. Real Studio screenshot inspected at `.runtime/reviews/recording-audit/ranged-reedshot-studio.png`: authored archers visible, bow attack lane resolves, no page errors. This screenshot is an initial pose, not a full projectile pixel-oracle claim.
- Replacement arcs: existing arc and corpse-pose tests passed; tests locate actual completed spells/deaths rather than retaining obsolete sequence 9/16/23. Typecheck passed. Worker cold-prefix corpse replay browser check passed (same final `Die` frame, NW facing, contact `[5,0,7]`, no errors).
- Current Studio worker/channel sweep passes for both replacements. Arc retains one explicit preexisting gap: measured weapon trail/contact media for True Strike’s actual dagger attack. This does not block the corrected enemy-target provenance, but it is not full visual acceptance.
- The new local servers used free ports 8795/8796/8797 after existing listeners were inspected, then were stopped after capture; preexisting 8793/8794 servers were left alone. No backend source edits.
