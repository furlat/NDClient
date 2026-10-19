# Schema 16 real-recording gaps — 19 October 2026

Frozen engine: `211b71134ed15c89e62232587381f7e15a5961c3`, protocol 1 / player schema 16, digest `49d14bc20920f5698eb4f09e3aeece442380242cd1453893d45f94ea9fb0c8a5`. Official engine files were not changed.

The current `.runtime/studio-library/index.json` contains eight successful cohort cases and 183 successful spell baselines out of 189. All 197 entries remain discoverable; six spell failures remain explicit. `recorded` proves legal command capture and actual native witnesses only. It does not claim native Studio/live playback, complete providers or visual approval. Both original faction journals are retained.

## Remaining engine/setup evidence

- **Branding Smite, Ensnaring Strike, Searing Smite:** their offered choice and Preview succeed; Command becomes indeterminate. Each server log ends in `dnd/player/capture.py::_lineage_graph`: `ValueError("lineage requires terminal root and child facts")`. The failure is reproduced after recipe retries; the client cannot publish a missing operation.

- **Test Bless:** `spell.fixture.test_bless` is present in the current registry with developer visibility. The public roster spell grant rejects it because the catalog has no directly registered SpellAction. It remains a failed setup; it is not silently excluded from the 189-ID gate.

- **Spare the Dying:** an actual premade allied fighter receives 44 starting Force damage. Initialization records life occurrence 29, `alive → dying`, at zero HP; its next death save is a natural 6. The caster is adjacent. Choices still returns `spell.spare_the_dying:no_valid_targets`. Revivify uses a separately recorded dead companion and succeeds. No life state was injected.

- **Hellish Rebuke:** the authored Fire Myrmidon starts with its real enabled reaction handler and one reaction/innate-rebuke resource. An adjacent enemy casts actual Magic Missiles for positive Force damage. Both resources change from one to zero, but neither original faction journal contains a Hellish Rebuke spell/action/effective-handler observation. The baseline remains failed instead of assigning a made-up reaction event.

Latest failed attempt paths:

- `spell.branding_smite/baseline`: `.runtime/studio-library/cases/spell.branding_smite__baseline/20261019T144433.097124Z` (`scenario.json`, `commands.json`, original faction `journal/`, `server.log`, `recording.json`).
- `spell.ensnaring_strike/baseline`: `.runtime/studio-library/cases/spell.ensnaring_strike__baseline/20261019T144503.650221Z` (`scenario.json`, `commands.json`, original faction `journal/`, `server.log`, `recording.json`).
- `spell.fixture.test_bless/baseline`: `.runtime/studio-library/cases/spell.fixture.test_bless__baseline/20261019T144511.104263Z` (`scenario.json`, `commands.json`, original faction `journal/`, `server.log`, `recording.json`).
- `spell.hellish_rebuke/baseline`: `.runtime/studio-library/cases/spell.hellish_rebuke__baseline/20261019T144517.972788Z` (`scenario.json`, `commands.json`, original faction `journal/`, `server.log`, `recording.json`).
- `spell.searing_smite/baseline`: `.runtime/studio-library/cases/spell.searing_smite__baseline/20261019T144902.478344Z` (`scenario.json`, `commands.json`, original faction `journal/`, `server.log`, `recording.json`).
- `spell.spare_the_dying/baseline`: `.runtime/studio-library/cases/spell.spare_the_dying__baseline/20261019T144923.997533Z` (`scenario.json`, `commands.json`, original faction `journal/`, `server.log`, `recording.json`).

## Real reaction attribution

Divine Smite succeeds through the real paladin premade attacking an authored prone goblin. It is observed as a native node with no fact shell, an `effective_handler` attribution, exact triggering occurrence/lineage and `outcome: modified_event`. Its combat-log data names the appended radiant packet. Recorder witnesses and moment extraction consume these original attributions; `no_effect` invocations do not count as successful reaction execution. Studio/compiler must retain this real handler observation rather than inventing a reaction fact or treating it as undisclosed scaffolding.

## Tooling and qualification

- `tools/studio_cases/record.py --only cohort|spell|failed|<id>` owns one backend at a time, keeps each attempt, and writes actual faction-local occurrence/lineage moments. Comma-separated IDs permit bounded recipe retries. `tools/studio_cases/live.py` uses one native Godot process with fresh Play/session owners, real player gestures and shared resource caches.
- The frozen Python SDK Choices relation check rejects valid free-aim rows with empty target sets. The recorder uses the same authenticated current endpoint and identity checks; real Preview/Command still own legality. Frozen SDK files remain unchanged.
- Native Fire Bolt initially passed nine gesture checks but emitted a cancellation error during teardown. Test teardown now disables Play processing before closing the session; the Python batch checks final native logs and exit status. The later isolated Fire Bolt native rerun passes nine gesture checks with no script/resource errors; its ObjectDB shutdown warning remains explicit. The complete native sweep is not yet qualified.
- `sdk_profile_checks` directly passes 29 checks with zero errors. Static `StringName` timing keys are accepted alongside strings; numeric-only phase leaves and token/URL/payload-UUID exclusion remain checked. Evidence: `.runtime/schema16-profile-privacy.log`.
- Full fast-suite failures from removed scripts and old runtime fixtures remain explicit baseline failures. Forty-eight removed script rows are migration-owned, not passing; real framebuffer tests are GPU gates with current recording arguments where supported.
- The complete Factory condition package is now installed privately by the separate renderer integration. Recorder/SDK tooling does not rewrite journal bytes, approved lighting, engine rules or authoritative outcomes.
- The clean headless reader run covers 183 real baselines /366 original faction journals /12,787 checks with zero script/resource errors or warnings. Six unavailable baselines keep the overall inventory gate failed. Evidence: `.runtime/schema16-recording-safety-qualified/report.json` and `godot.log`.
- The native eight-case cohort passes 10,866 assertions through seek, loop and faction changes with zero script/resource errors; one RefCounted shutdown warning remains. This is separate from the ongoing real-GUI all-spells sweep and from provider/visual completeness.
