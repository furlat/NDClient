# Passive Resource admission and lifetime

This is a shared preparation-ownership change, not a spell-specific repair.
The installed package remains e102 and event publication, native graphics,
source sampling and the schema-16 fold are unchanged.

## Failure and scope of the repair

The first repeat in `.runtime/tests/20261020T082151.393677Z/summary.json`
failed after player readiness and the first door command. Godot exited without
a GDScript diagnostic or a completed assertion report. Windows Application
events1000/1001 identify native heap corruption `0xc0000374`, process31280.
The local crash dump retains concurrent passive `GDScript::_read` threads while
session preparation was active. This establishes overlapping native reads, not
the exact operation which corrupted the heap. It is not evidence of a shader,
driver, weapon-effect or server failure.

Previously, separate preparation jobs could load and discard the same passive
Resource graph independently. Dictionary data outlived its short-lived source
Resource, and separate native-source cache shells admitted duplicate physical
owners. The following existing owners now retain and coalesce those inputs:

- `SourceMetadata._read` serializes passive native Resource admission. The
  mutex is acquired by the actual reader, not by a pool caller awaiting that
  reader. Optional profiling separates lock wait from native read time.
- `AbilityDocuments` coalesces cold table admission under its existing mutex
  and retains `[stamp, data, Resource]` together.
- `EffectPackage` retains phase Resources alongside its existing clip cache
  and coalesces cold clip metadata publication under its existing mutex.
- `NativePresentationSources` retains each physical source by its actual
  admitted index, under the existing admission mutex. Independent snapshot
  shells borrow that Resource until ordinary invalidation.

No manager, runtime validation, hash, polling task, late texture readback or
clock hold was added. Existing invalidation remains the owner boundary. Cold
synchronous callers can still wait for admission; this is not a no-stall claim.
The inspected lock order has no reverse callback from passive Resources into
the document/package owners.

## Qualification

Expanded `selection_worker_ownership_checks` starts eight real cold pool
callers, without main-thread prewarming. All share the same physical table and
native source, retain the source after caller shells retire, and complete
selection replacement/cancellation/join/teardown: **42/0**, zero script/engine
errors or owned leftovers, `.runtime/tests/20261020T083139.336382Z/summary.json`.
Existing body reload, native admission and immutable attack tests separately
pass30,53 and3186 assertions. The initial test-only duplicate variable parse
failure is retained in `.runtime/tests/20261020T083006.610992Z`; it is not a
passing whole batch.

Two fresh live Gallery runs then pass **313/0 each**, zero script/engine errors
and owned leftovers, in `.runtime/tests/20261020T083526.571661Z/summary.json`.
Their exact frame and command decomposition is appended to
[the current live ledger](GALLERY_CURRENT_PROFILE_2026-10-20.md).
This is repeated evidence for the containment, not proof that a native heap
failure can never recur. There are still isolated62.5–70.5ms frame tails.
The previous clean baseline and failed repeat are both retained; no failure is
relabelled as success.
