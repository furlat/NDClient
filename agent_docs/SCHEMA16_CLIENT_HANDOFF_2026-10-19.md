# Client upgrade to player schema 16 — handoff (19 October 2026)

For the agent(s) that take this over. It has not been started: no code is changed yet.

## Spec and engine
- **The spec** is the engine's handout: `/home/tommaso/.codex/worktrees/event-native-deltas/dnd_engine/agent_docs/GODOT_CLIENT_SCHEMA_16_HANDOUT_2026-10-19.md`. Read it fully.
  - The executable spec is `dnd/player/reduction.py`, `world_reduction.py` and `world_columns.py`. Where the text and the code disagree, the code is right.
  - Its `sdk/protocol/README.md` still describes schema 15; ignore it.
- **The engine copy to use:** `/home/tommaso/.cache/ndclient/dnd_engine-6e9cc5bbf`. It was exported read-only from that worktree at `6e9cc5bbf`: protocol 1, schema 16, digest `26c80694…99532`.
  - Never write to the codex worktree.
  - Never use `/mnt/c/Users/tommaso/Documents/Dev/dnd_engine`.
  - Python: try `/home/tommaso/.cache/dnd-engine/npc-mechanics-venv/bin/python`, then `/home/tommaso/.cache/dnd-engine/venv/bin/python`, with `PYTHONPATH=<copy>:<copy>/sdk/python/src`.
- **Why upgrade:** the new engine fixed the slow status updates and has the new spells, conditions and NPCs.

## The client today
- **Branch** `feature/opus-refactor`. The SDK (`sdk/`) speaks schema 9 (`protocol.gd`, `reducer.gd`, `transitions.gd`, `audience.gd`, `journal.gd`, `choices.gd`, `transport.gd`, `sse.gd`). Presentation compiles from the reduced state (`presentation/compiler.gd`, `components.gd`, `session.gd`, `timeline.gd`, `world.gd`, `characters.gd`).
- **Presentation data** now lives in `authoring/{characters,environment,abilities}.tres`. `tools/build_presentation.gd` builds it into `build/presentation/`; run it once before Godot tests. It is keyed by content ids, and schema 16 keeps those ids, so the sources survive. Only retired ids change (§5 of the handout).
- **Tests:** `tools/run_tests.sh --tier fast|gate|live [--only …]` reads `tests/manifest.json`. `tools/live_suite.sh` runs the live tier; its default engine is the pinned schema 9 copy, so change it to the new copy.
- **The Studio's recordings** (`.runtime/studio-*`) are schema 9. After the upgrade they must be re-recorded on the new engine. See `agent_docs/STUDIO_HANDOFF_2026-10-19.md`: its recorder is built to re-record everything with one command.

## Plan

Two lanes can run in parallel; then they integrate.

### Lane A: the fold (`sdk/`)
1. Copy the identity: `player-api-v1.schema.json` and `protocol-identity.json` into `sdk/`. Check each record's `protocol` (handout §6.1).
2. Rewrite the reducer as the handout's fold:
   - encodings (§2.1);
   - client stores (§2.2);
   - order: groups, lineages, cursors, the spell declaration check (§2.3);
   - world update: static stores, entered cells, tile and object columns, residues, connectors, contents (§2.4);
   - the composed sensory fact: members, lights, effects (§2.5), with the memory rules (§3);
   - bodies, `ActorChangeFact` and items (§2.6);
   - HUD and initiative (§2.7);
   - combat log (§2.8).
3. **Golden vectors.** Write `tests/schema16_fold_vectors_checks.gd`. It folds every vector in `<copy>/sdk/protocol/fold-vectors/` (world w1–w14, sensory v1–v8, bodies v1–v9, groups g1) from an empty seat and compares each step's `expected`, including the error cases. On the engine they pass with `pytest tests/player/test_{world,client,body,group}_fold_vectors.py`.
4. **Spool oracle.** Record a seeded run with `devtools/performance/gallery_transcript.py record … --oracle <dir>` (handout §6.3). Fold each seat's frames in Godot and diff every record's state against the reference fold, using `seat_oracle.state_data` and the `PlayerState` field names.
5. **Journal** (`sdk/journal.gd`): admit schema 16 records. "Saved `PlayerSequence` files are schema 9" (handout header); find out what that means for the journal container.
6. **Presentation's view.** Give presentation the state it reads today: actors with position, appearance, loadout and conditions; objects; tiles; senses. Either project the new stores into that shape in one place, or update the readers. Pick one and document it.

### Lane B: around the fold
1. **Transport and reconnect** (handout §7): `GET /initialization`, then `GET /events?after=0`, resuming on the same attachment; always fold from an empty state.
2. **Choices free aim** for position spells (§2.9).
3. **Rendering obligations** (§4):
   - member bits ("seen by A only");
   - targets come only from Choices bindings, never from perception.
4. **Content changes** (§5):
   - one public `action.monster.multiattack`, with 60 per-creature ids retired. Re-key the client's binding in `authoring/abilities` so Multiattack still plays a body recipe;
   - the `encounter_end` removal trigger;
   - the new `action.help_attack`, `action.monster.shield_bash`, `condition.attack_assistance`, the assassin poison coat, the fighter protection reaction, and the new traits.
5. **Re-snapshot the ids:** `python3 tools/snapshot_server_ids.py --engine /home/tommaso/.cache/ndclient/dnd_engine-6e9cc5bbf` writes `authoring/server_ids.json`. Then rebuild the presentation, which reports coverage for the new ids.
6. **Live tooling:** point `tools/play.py` and `tools/live_suite.sh` at the new engine copy, check the scenarios (`crypt_gallery`, `gallery_sorcerer`) still exist, and fix them where the engine changed.

### Integration
1. Compiler and components read the new facts:
   - a spell's declaration is only on its cast;
   - `ConditionMember` replaces `ConditionFact`;
   - `ActorChangeFact` replaces the equipment, condition-change and item-effect facts;
   - world rows come from columns.
2. Remove all schema 9 code. The user wants exactly one path.
3. The live tier passes on the new engine with 0 script errors, 0 engine `ERROR` lines and 0 missing-resource warnings. That includes `live_spell_checks`; the user's top priority is that no spell crashes.
4. Re-record the Studio cases (Studio handoff), then run the Studio gate on the new recordings.

## Rules (non-negotiable)
- **Git:**
  - Work in your own worktree and branch.
  - Stage by explicit path; never `git commit -a`. The VFX Factory writes into `assets/vfx/` at any time.
  - Plain commit messages, with NO Co-Authored-By or any other attribution line.
  - Never push (the user pushes) and never merge into `codex/ndclient`.
- **Godot hygiene:**
  - `G=/mnt/c/Users/tommaso/Documents/Dev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe`.
  - Always use the absolute `--path C:\Users\tommaso\Documents\Dev\<worktree>`. Wrap every run in `timeout`.
  - Afterwards, kill only your own leftovers, matched by your path. That includes the windowed child.
  - Never kill Godot by name, and never anything under `VFXFactory`.
  - Use `--headless` whenever possible.
- **Zero errors:** no failing checks, script errors, engine errors or "Missing / not found" lines. Run the live tier after every merge. The user must never be the one to find a crash.
- **Style:**
  - Match the surrounding GDScript; dense one-line statements are house style.
  - No Manager, Registry or Handle classes.
  - In tools and tests use `preload` consts.
  - Python tools are plain functions.

## Done means
- The golden vectors pass.
- The spool oracle shows no state differences.
- The client plays the new engine live, with the whole live tier green.
- `authoring/server_ids.json` comes from the new engine, and the presentation build has 0 errors.
- No schema 9 code is left.
- The Studio cases are re-recorded on schema 16.
