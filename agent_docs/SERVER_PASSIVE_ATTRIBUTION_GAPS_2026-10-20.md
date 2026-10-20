# Emitted-only passive attribution — concrete producer gaps

Read-only findings against frozen engine `211b71134ed15c89e62232587381f7e15a5961c3`,
protocol1/player schema16. No engine files were changed. The client keeps the
corresponding Factory bindings explicitly missing; it does not infer a passive
from damage type, actor class or combat-log source text.

## Unchanged real evidence

**Blessed Healer:** `tests/fixtures/schema16/scenarios/blessed-healer/party/`,
packet12, lineage417. Ordinary Fireball previously hurt both living players;
Healing Word then heals the ally10HP (occurrence428, parent419) and the caster
3HP (occurrence427, no parent event). The public packet does not identify
`class_feature.cleric.blessed_healer` or its emitted lineage. Human combat-log
text is not a typed semantic attribution. This is an honest single-party build.

**Destroy Undead:** `tests/fixtures/schema16/scenarios/destroy-undead/{amber,blue}/`,
packet2. Turn Undead applies actual Turned and causes17Radiant damage (Amber35,
Blue39), but neither stream names `class_feature.cleric.destroy_undead` as an
effective handler or discloses its emitted lineage. This is a lawful level5
Cleric with the actual level5 passive grant, not a fabricated high-level action.

Strict recording gates remain failed for this missing attribution despite real
healing/damage. Other supported OA `effective_handler` data survives in the same
Blessed recording, corroborating that the recorder is not dropping the field.

## Source cause and bounded server fix

- `dnd/core/events.py:1609–1625` already detects emitted-event outcomes.
  At1655–1659, however, `EffectiveHandlerPresentation` is retained only when
  the handler returns a non-None result.
- `dnd/classes/cleric.py:147–164` and223–266 emit the actual healing/damage
  and return None. Their dispatch presentation is consequently lost.
- Blessed Healer already has its real `BehaviorBinding` in
  `dnd/content/characters/cleric_grants.py:184–189`. Destroy Undead's handler
  at197–211 has only a semantic key and lacks that binding.
- `dnd/player/projection.py:959–973` serializes retained handler presentations;
  it cannot recover information discarded earlier.

Retain emitted-only class-handler presentation on the actual triggering event
version even when the return is None; add the exact Destroy Undead binding. Use
the existing ContentAttribution structure and disclosure filtering: real behavior
identity/source, triggering occurrence/lineage and only disclosed emitted
lineages. No protocol redesign, fake ActionFact or client rule reconstruction is
needed. After promotion/export, re-record these two unchanged legal scenarios
and qualify the shared effective-handler→emitted-result join before enabling
their delivered art. Divine Strike/Improved Smite rider identity remains a
separate issue; this fix does not automatically establish rider ownership.
