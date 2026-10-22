# Current-engine Studio recordings

`cases.py` declares legal roster setup, role names, exact aims/recipients and
ordered commands. `adapter.py` owns the current engine and SDK calls. No renderer
or private engine state is used to manufacture an outcome.

From the client checkout:

```sh
python3 tools/studio_cases/record.py --only cohort
python3 tools/studio_cases/record.py --only spell
python3 tools/studio_cases/record.py --only spell.fire_bolt
python3 tools/studio_cases/record.py --only failed
```

The default frozen engine is `/home/tommaso/.cache/ndclient/dnd_engine-1f044792b1`.
Use `--engine` to select a deliberately refreshed export, and `--out` for an
independent library. One recorder owns one backend at a time. Each attempt gets
a new directory; original Amber and Blue journal bytes are never rewritten.

Publish the committed lifecycle captures into the normal Studio library without
running or importing the engine:

```sh
python3 tools/studio_cases/record.py --import-recordings \
  tests/fixtures/schema16/native-persistent-studio \
  tests/fixtures/schema16/vampiric-positive \
  tests/fixtures/schema16/banishment-departure
```

This merges the original case IDs, subjects, faction journals and occurrence
markers into the existing index. It preserves capture failures and makes no
playback/provider/visual approval claim. Use `--out` for a separate library;
publishing the same originals twice does not duplicate its cases.

The version-1 index retains failures and actual occurrence/lineage jump points.
`recorded` proves only that the requested legal commands and factual witnesses
were captured. It does not mark Studio playback, provider implementation or
visual acceptance as passed. Native Studio playback is checked separately by
`tests/schema16_studio_replay_checks.gd`; its `--all-spells` mode reads the current
spell baselines. Missing journals, missing required outcomes and failed setup
remain failures, rather than being replaced with another target or skipped.

`live.py` drives actual player UI actions in one native Godot process, with fresh
Play/session owners and legal case servers. It retains shared Godot resource
caches between cases. Run it in the frozen engine's Python environment with
`PYTHONPATH` containing the export, its `sdk/python/src`, and this project's
`tools`; start with `--only spell.fire_bolt` before the full `--only spell` gate.
The batch reports to `.runtime/studio-live/`. It does not set `studio_checked` or
claim visual approval.

Give each live attempt a fresh `--out` directory. `--start-after` resumes after
an exact case ID in the declared inventory; it does not substitute another
spell or discard the earlier attempt. Requests are immutable numbered files so
Windows never observes a partially replaced request. A per-case script error
makes that case fail while the driver continues with a fresh Play. Parse/load
errors and a native process exit stop the batch.

Join ordered partitions and explicit retries without losing their provenance:

```sh
python3 tools/studio_cases/join_live.py --out .runtime/studio-live-qualified/report.json \
  .runtime/studio-live-first/results.json .runtime/studio-live-rest/results.json \
  .runtime/studio-live-retry/results.json
```

The latest attempt supersedes only its exact case. Earlier attempts and raw
logs remain linked. `complete` means the current inventory was attempted;
`command_succeeded` and `runtime_safe` are separate results. Render traces are
captured at the command boundary, so a finite effect tail with no observed
sample is not automatically missing art. Neither result grants visual approval.

To check every available original spell journal through the current compiler,
boundary restoration and sampling, with complete Godot-log qualification:

```sh
python3 tools/studio_cases/check_recordings.py --out .runtime/schema16-recording-safety-qualified
```

This headless check writes `godot.log` and `report.json` under that directory.
It attributes script/resource errors to their spell and original faction,
preserves assertion results, and reports unavailable server cases explicitly.
An inventory with unavailable cases still fails the complete gate. Passing
assertions with script errors also fails. Native drawing, audio output and
actual player input require the separate native replay/live checks.

The frozen Python SDK's Choices relation check currently rejects valid free-aim
rows with empty target sets. The adapter's small `choices()` transport uses the
same authenticated connection and current endpoint, retaining request identity
checks while letting the real server Preview/Command own legality. This is a
known SDK handoff; the frozen engine and SDK files are not modified.
