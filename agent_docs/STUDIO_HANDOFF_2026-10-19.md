# Studio: complete case library and browser — handoff (19 October 2026)

For the agent that takes over the Studio work. Read this fully before starting.

## 1. What the user wants

The user's words: "your main task now is working on having a complete studio so i can actually test things"; "properly organized not this complete mess"; "following the authoring data every action / conditions all strange interactions need to have a studio version"; "what we need is no spell to crash"; "no errors because they can't find the resource we have"; "for the studio we must be ready to update the events once the server changes get merged".

So the job has five parts:
1. **Cases for everything:** a recorded server journal for every spell, condition, action, creature, environment interaction and unusual interaction the client can play.
2. **One organized browser** in the Studio, laid out like the authoring data. Every id is listed with its status.
3. **No spell crashes:** zero script errors and zero missing-resource warnings, in the Studio and in live play.
4. **Re-recordable:** cases are scenario data, and one command re-records them all when the server changes.
5. **Hand review:** the user then reviews everything by hand in the Studio.

## 2. When to start (dependencies)

Do not start before both of these:
- **The presentation-source migration is merged into `feature/opus-refactor`.** That is three branches: `feature/opus-src-characters`, `feature/opus-src-environment` and `feature/opus-src-abilities`. Design: `agent_docs/PRESENTATION_SOURCE_DESIGN_2026-10-18.md`. After the merge, the game reads `build/presentation/` built from `authoring/{characters,environment,abilities}.tres`, and `build/presentation/coverage.json` says, per id, whether its art is ready, partial, stand-in or missing.
- **The VFX Factory has delivered the reauthored condition effects** (handoff: `agent_docs/VFX_CONDITIONS_HANDOFF_2026-10-18.md`). A new package version lands in `assets/vfx/`. Check the version in `assets/vfx/index.json`. Commit it on its own (never `git commit -a`). Then `tests/condition_lifecycle_checks.gd` should reach 0 failures.

Start from the tip of `feature/opus-refactor`, on a new branch.

## 3. What already exists (reuse it)

- **Recorders that drive real server commands:**
  - `tools/studio_spell_lifecycle_capture.py` records whole spell lifecycles for both factions: cast, held condition, walk, real end, walk after (36 cases in `.runtime/studio-spells-20261018/`);
  - `tools/studio_capture.py` (finite cases), `tools/studio_spell_capture.py`, `tools/studio_gallery_spell_capture.py`, `tools/loot_scenario.py`, `tools/presentation_scenarios.py`.
- **Started and paused:**
  - `tools/studio_cases/adapter.py` (692 lines) on branch `feature/opus-studio-cases`, worktree `NDClientGodot-noatlas`, commit `303aa50a`. It is the one module meant to hold every engine, protocol and SDK call. Read it and finish it.
  - A first index of the existing cases at `.runtime/studio-library/index.json` (main tree; not in git): 131 cases (85 spell, 15 action, 14 condition, 13 interaction, 4 environment), converted from the old inventories.
  - `.runtime/studio-library/engine_ids.json`: every id the pinned engine supports. 132 spells, 130 conditions, 79 actions, 95 creatures, 162 environment objects, 51 spatial effects, 6 residues, plus the enums.
- **The ids the newer server sends:** `authoring/server_ids.json`, from the modern engine branch (schema 15). 189 spells, 235 conditions, 179 actions, 232 creatures, 67 spatial effects. Made by `tools/snapshot_server_ids.py`.
- **The existing Studio browsers to replace:** `studio/case_library.gd`, `study_library.gd`, `study_catalog.gd`, `source_inventory.gd`, `capability_report.gd`, `authoring_audit.gd`, and the "Spell composition" and capability Library panels in `studio/studio.gd`. Read `studio/README.md`.
- **Opening a journal headless the Studio way:** `tools/studio_spell_lifecycle_times.gd -- --output=res://.runtime/spell-lifecycle-times.json` indexes journals through `studio/recording.gd` and seeks to each event.
- **Tests:** `tools/run_tests.sh` with `tests/manifest.json` (fast, gate and live tiers), plus `tools/live_suite.sh`, if `feature/opus-live-triage` is merged. Otherwise only `tools/live_suite.sh`.

## 4. The index contract

Keep this shape exactly:

`res://.runtime/studio-library/index.json` (dev data, not in git). Journals go in `.runtime/studio-library/cases/<case-id>/<faction>/journal`.
```json
{"version": 1,
 "engine": {"path": "...", "commit": "...", "player_schema_version": 9},
 "engine_ids": "res://.runtime/studio-library/engine_ids.json",
 "cases": [
  {"id": "spell.fireball/hit", "title": "Fireball: cast, blast on two goblins, one saves",
   "kind": "spell|condition|action|interaction|creature|environment|surface",
   "subjects": {"spell": ["spell.fireball"], "condition": [], "action": [], "creature": ["creature.goblin"],
                "environment_object": [], "spatial_effect": [], "residue": [], "item": []},
   "journals": {"amber": "res://.runtime/studio-library/cases/spell.fireball__hit/amber/journal",
                "blue": "res://.runtime/studio-library/cases/spell.fireball__hit/blue/journal"},
   "moments": [{"label": "cast", "sequence": 3, "event_uuid": "...", "published_ms": 1840}],
   "status": "recorded", "reason": "", "seed": 3, "scenario": "tools/studio_cases/...#fireball",
   "studio_checked": true, "errors": []}
 ]}
```

Field rules:
- **`status`** is one of:
  - `recorded`;
  - `failed`, with `reason`;
  - `engine_unsupported`: the id is in `authoring/server_ids.json` but not in the recording engine's `engine_ids.json`.
- **`studio_checked`** says the case opened and played to its end in the Studio. **`errors`** lists every `SCRIPT ERROR`, engine `ERROR`, and every "Missing", "not found", "Failed loading" or "Cannot open" line from that run.

## 5. Work, in order

### 5.1 The recorder (`tools/studio_cases/`)
- Scenarios are data (or plain Python data): who, where, which commands, which seeds or outcomes to look for. They use ids and roles. Every engine-specific call lives in `adapter.py`.
- `record.py --engine <path> [--only kind|id|case] [--out res://.runtime/studio-library]` records both factions, finds the moments, writes `index.json` and `engine_ids.json`, then opens each case headless through the Studio path and fills in `studio_checked` and `errors`.
- Keep the engine to at most 2 processes at once.
- Use the pinned engine: `E=/home/tommaso/.cache/ndclient/dnd_engine-229ce025f`, `PYTHONPATH=$E:$E/sdk/python/src /home/tommaso/.cache/dnd-engine/venv/bin/python`. Never use `/mnt/c/Users/tommaso/Documents/Dev/dnd_engine`. The modern branch `/home/tommaso/.codex/worktrees/remaining-npc-authoring/dnd_engine` may only be read.

### 5.2 Spells first (the user's top priority: no spell may crash)
1. A case for each of the 132 pinned spells:
   - a caster who has the spell;
   - a target or area that fits its shape;
   - seeds that show hit/miss or save/fail where relevant;
   - for lasting spells: hold, walk and real end (reuse the lifecycle recorder's logic);
   - upcast and choice variants where the engine offers them.
2. **Studio check:** every spell case plays to its end with 0 errors of any kind listed in §4.
3. **Live check:** write `tests/live_all_spells_checks.gd` and a `tools/play.py` scenario hook (keep the hook small), with the client as the human seat. For each spell:
   - select it;
   - hover every valid target kind;
   - open the preview;
   - confirm;
   - wait for the result.

   Batch many spells per session. Report spell by spell. Add it to the live tier.

   The crash the user hit (fixed in `671248a`) was in live choice and selection code, which Studio replays never run.

### 5.3 Conditions, then actions
- **Conditions:** every visible condition has at least one case: applied, held, walked with where possible, ended by a real rule. Many come from spells; write dedicated scenarios for the rest: prone, grappled, restrained, poisoned, frightened, invisible, hidden, unconscious with death saves, exhaustion…
- **Actions:** every action has one case, with its object or item set up. The ~20 action ids the server sends without a catalogue entry count too (rage, action surge, second wind, quickened spell…). This covers:
  - every environment interaction: doors open/close/break/jam, directional doors, chests open/close/loot, levers, wall torch, campfire, arcane device, heroes' feast, escaping the jaw trap;
  - item actions: potions, torch, weapon coat, field kit, ember quiver;
  - movement and stance actions: shove, dash, disengage, dodge, hide, jump, swim, drop prone, stand up, pick up, drop, traverse connector, shake awake, drop concentration.

### 5.4 Interactions, then creatures
- **Interactions:** take the inventory from the engine itself. At least:
  - reactions: Shield against melee, ranged and Magic Missile; Counterspell; Hellish Rebuke; opportunity attack; Protection; Parry; Divine Smite;
  - concentration broken by damage, or dropped;
  - removal triggers: shake awake, getting wet, ally help;
  - forced movement: shove, Thunderwave, Gust of Wind; falling and elevation;
  - hidden and invisible creatures against attacks and detection: See Invisibility, Faerie Fire;
  - surfaces: oil ignite → fire, douse, water freeze → ice, electrify, vaporize → steam, web ignite → burning web, clouds dispersing, barrels spilling;
  - every trap kind;
  - light and darkness;
  - summons;
  - Enlarge/Reduce;
  - death, death saves, stabilize, revive;
  - criticals, resistance, immunity, vulnerability;
  - area spells that catch allies;
  - healing and temporary HP.
- **Creatures:** each of the 95 appears, moves, uses each attack, takes damage and dies. Group several per case when that helps; every creature id must appear in some case's `subjects.creature`.

### 5.5 The browser (one panel, replacing the old ones)
- **Sections, laid out like the authoring data:**
  - spells by level, then school;
  - conditions by family;
  - actions by family;
  - interactions by kind;
  - characters and creatures;
  - environment objects;
  - surfaces;
  - items, where cases have them.
- **Every id appears exactly once,** with its cases and a status:
  - recorded and opens;
  - stale (recorded on a different engine commit or schema);
  - no case yet;
  - recorder failed (with the reason);
  - needs the schema 15 server.
- **Each id also shows its art status** from `build/presentation/coverage.json`.
- **Search and filters.** Each section header shows counts, e.g. "Spells 132 · 120 recorded · 12 missing".
- **Opening a case** loads it in the chosen faction and puts its moments on the timeline as jump points. Keep the Inspect tools, including "Effect version: Recorded / GPU / Native", and keep case switching under about 1 s.
- **Retire the old browsers** and their dead code. Update `studio/README.md`, and replace or update the Studio tests for the old browsers without weakening real checks.
- **Add `tests/studio_library_browser_checks.gd`:**
  - every server id appears once;
  - every case is reachable from each of its subjects;
  - a sample of cases from every kind opens and lands on its first moment;
  - statuses are right for a synthetic index containing stale, failed and unsupported cases.
- **Take screenshots** of the panel at 1600×900: spells expanded, conditions expanded, an open case. Look at them: no truncated or overlapping text.

### 5.6 Re-record everything once
Re-record the whole library with the one command, to prove it is reproducible. Report the time it took.

## 6. Rules (non-negotiable)

- **Git:**
  - Work in your own worktree on your own branch.
  - Stage by explicit path; never `git commit -a`. The VFX Factory writes into `assets/vfx/` at any time.
  - Plain commit messages, with NO Co-Authored-By or any other attribution line.
  - Never push; the user pushes. Never merge into `codex/ndclient`.
- **Godot hygiene.** The user has found Godot windows left open, and the VFX Factory runs its own Godot.
  - Launch with the absolute `--path C:\Users\tommaso\Documents\Dev\<your worktree>`, never `--path .`.
  - Wrap every run in `timeout`.
  - After each run, kill only your own leftovers, matched by your path in the command line. That includes the windowed `Godot_v4.7.2-stable_win64.exe` child.
  - Never kill Godot by name, and never anything under `VFXFactory` or the main `NDClientGodot\` folder.
  - Use `--headless` whenever you can.
- **Zero errors.** No failing tests, no script errors, no engine errors, no missing-resource warnings. If a resource we have isn't found, fix the binding in the presentation source; don't add a warning.
- **Run the live tier after your work.** That is `tools/run_tests.sh --tier live` or `tools/live_suite.sh`. The user must never be the one to find a crash.
- **Code style:** match the surrounding GDScript (dense one-line statements are house style). No Manager, Registry or Handle classes. In tools and tests use `preload` consts. Python tools are plain functions.
- **Running Godot:** `G=/mnt/c/Users/tommaso/Documents/Dev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe`. Headless: `$G --headless --path <abs> --script res://...`. GPU: `--rendering-method forward_plus --rendering-driver vulkan`.

## 7. Done means

- Every pinned spell, visible condition and action has a recorded, Studio-checked case with 0 errors.
- Every interaction from the inventory and every creature is covered, or listed with the reason it can't be.
- `live_all_spells_checks` passes for every spell.
- The browser lists every id from `authoring/server_ids.json`, organized as above, with correct statuses.
- One command re-records the library.
- The live tier and the Studio gate are green.
- `studio/README.md` describes the new browser.
