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

The default frozen engine is `/home/tommaso/.cache/ndclient/dnd_engine-211b71134`.
Use `--engine` to select a deliberately refreshed export, and `--out` for an
independent library. One recorder owns one backend at a time. Each attempt gets
a new directory; original Amber and Blue journal bytes are never rewritten.

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

The frozen Python SDK's Choices relation check currently rejects valid free-aim
rows with empty target sets. The adapter's small `choices()` transport uses the
same authenticated connection and current endpoint, retaining request identity
checks while letting the real server Preview/Command own legality. This is a
known SDK handoff; the frozen engine and SDK files are not modified.
