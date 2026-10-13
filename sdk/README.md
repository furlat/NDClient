# Godot player SDK

This project-local SDK consumes the current DnD player API: protocol 1, player
schema 6. It ships the unchanged schema and identity from `dnd_engine/sdk/protocol`.
The current Python/TypeScript transports and `dnd/player/reduction.py` are its
references. The old `sdk/typescript` client is not a dependency.

The SDK uses built-in Godot facilities and GDScript. The optional unsigned
GDSchema extension evaluated during research is not installed in this project;
no certificate or Windows security-policy changes are required.

## Ownership and API

`transport.gd` is a RefCounted session with one worker thread. It owns its
HTTPClient connections and invokes its data consumer on that worker. The main
thread submits requests and drains result notifications. Keep SceneTree,
rendering, animation and Control nodes on the main thread. A scene can own the
transport reference and call `close()` from `_exit_tree()`.

```gdscript
const Transport = preload("res://sdk/transport.gd")
const Journal = preload("res://sdk/journal.gd")

var journal = Journal.new()
var transport = Transport.new()

# Before starting the worker; check each returned result.
var opened = journal.open("user://player-recording")
var started = transport.start(base_url, bearer_token, journal.consume)

# Poll transport.drain() from the main thread. After connected.result succeeds,
# explicitly acquire the attachment using its current status attachment_epoch:
var request_id = transport.request("attach", {
    "acquisition_id": acquisition_uuid,
    "expected_attachment_epoch": current_status.attachment_epoch,
})
# After that request succeeds:
var follow_request = transport.follow()
```

This is an API sketch, not an automatically running scene. The complete caller
is `tests/sdk_live_game.gd`, including starting-state handling, attachment,
native choices/previews, numbered commands, receipt lookup, reconnect and close.

Results have `{ok: true, value: ...}` or
`{ok: false, error: {kind: ..., message: ..., retryable: ...}}`. API errors retain
their typed server value. Expected failures do not rely on GDScript exceptions
or console errors. Methods returning request IDs complete through `drain()`.

| Operation | Request arguments |
| --- | --- |
| `health`, `status` | `{}` |
| `attach` | Original `AttachmentRequest` |
| `choices`, `preview` | Original request, preserving correlation and discovery indexes |
| `submit_command` | Original numbered `CommandRequest` |
| `receipt` | `{number: command_number}` |
| `content` | `{revision: content_revision}` |
| `acknowledge` | `{cursor: player_cursor}` |

`start(url, credential, consumer, options)` schedules bootstrap. Notifications
are `connected`, `response`, `consumed`, `status`, `reconnecting`, `completed`
and `failure`. Responses retain their request ID. `follow()` owns initialization
and the SSE stream; `reconnect()` preserves the attachment and consumed cursor.
`wait_for_cursor(cursor, timeout_seconds)` waits for consumption. The ACK may
still be in flight; use explicit `acknowledge` or the acknowledged/catch-up
status before submitting a command. Terminal completion requires the final ACK.

Defaults: request timeout 30 seconds, stream-idle timeout 45 seconds, reconnect
deadline 60 seconds, at most 8 concurrent requests. `cancel()` requests shutdown;
`close()` cancels and joins outside the mailbox mutex. A transport is single-start.
The consumer is synchronous and must finish: shutdown cannot forcibly interrupt
arbitrary caller code. Request failures and pending cursor waits resolve during
shutdown. Credentials belong in caller configuration, never source or recordings.

The consumer receives `(packet, raw_bytes)` and must return a result. It runs
before consumed-cursor advancement and ACK. It must retain ownership of its data
on the worker; queue detached presentation values for the main thread. Do not
read `journal.state` concurrently from the main thread. `snapshot()` gives a
detached copy when called by the owner, or after the worker has closed.

Commands are never automatically retried. On an ambiguous network failure, look
up the same command number and reconcile its receipt. Reconnect never acquires
a replacement attachment. TLS verification stays enabled; authenticated
redirects and scope/identity changes fail explicitly.

## State and recordings

`reducer.gd` ports current Python player reduction, actor staging, retained
event state, branch extraction and causal indexes. `audience.gd` composes
recorded member senses and their provenance. All 17 PlayerState fields are
retained, including structured combat-log appends, HUD, content, world geometry,
audience and perception. The reducer does not calculate rules or visibility.

Pure entry points take admitted, protocol-normalized dictionaries and return
detached results. `reduce_initialization`, `reduce_operation`, `reduce_lineage`,
`stage_lineage`, `state_before_event`, `lineage_branch` and
`index_player_lineage` mirror their Python counterparts. Lower-level mutation
helpers operate only on a transaction owned by the caller. All facts remain in
the recording, including facts that do not directly mutate state and canceled
presentation facts whose separate world after-values still apply.

`protocol.decode(root, bytes)` admits bytes without applying defaults or changing
them. `normalize(root, value)` creates a separate reducer copy with model
defaults, integer fields and canonical UUIDs. It preserves the Python public
serialization rule that omits empty item construction suppressions. Coordinate
map keys use the Python JSON spelling, such as `"x,y"`.

`journal.gd` stages and flushes original bytes, computes the next pure state,
renames a successful record into the committed prefix, then publishes state and
cursor. Rejected staged records cannot poison the accepted history. Exact
duplicates are idempotent; conflicting duplicates, gaps and foreign audiences
fail. `open(directory)` cold-replays the committed prefix. `replay(sequence)`
selects a historical prefix transactionally; the live transport and displayed
history must use separate journal/reducer owners. Interrupted `.tmp` files do
not become accepted records. This tests process recovery, not hardware power-loss
durability guarantees.

The player preparation worker uses a bounded internal handoff. During canonical
operation reduction, `transitions.gd` collects pre-fact actor inputs and ordered
state after-values. `journal.gd` exposes these records only after the complete
operation and durable commit succeed. The compiler consumes those records to
schedule authored tracks; it does not reduce the same sensory facts again.
Records are private, read-only owned values, not a second public mutable snapshot
API. They are retained only within the existing two-operation preparation window.
Overflow and cold replay reconstruct them from the original journal bytes.
Cell lookups are local to each fold; published visible/seen arrays remain sorted,
with full integer coordinates and independent event-time versions.

## Validation and deliberate limits

Completed validation on 2026-10-11 using native Windows Godot 4.7.2:

| Evidence | Result |
| --- | --- |
| Real ranged encounter, two Godot seats | Terminal; 9 commands; reconnect; cold replay equal |
| Real spell encounter, two Godot seats | Terminal; 39 commands; ordered multi-target previews; reconnect; cold replay equal |
| Recorded states against current Python reduction | All 152 prefixes match exactly with the normalization below |
| Combined reducer and causal cases | 459 pass; all 28 typed fact classes represented |
| Strict schema parity corpus | 7,754 pass, including the explicit NUL admission difference below |
| Decimal-to-binary64 oracle | 3,404 exact bit-pattern checks pass |

The [complete validation report](../generated/sdk_validation.json) links the
actual game recordings and case evidence. The [fast-suite report](../generated/sdk_checks.json)
includes additional protocol, journaling and transport fault checks and their
logs. Live encounters cover the listed scenarios; typed boundary fixtures cover
the other fact classes. These counts are overlapping suites, not additive claims
of distinct gameplay scenarios.

Run `python3 tools/check_sdk.py` from the project under WSL for the native Godot
contract suite. It rejects logged Godot script errors even when Godot exits 0.
The generated schema corpus is checked against the shipped identity. Regenerate
the reference data with the current backend checkout/environment when changing
the protocol:

```bash
export PYTHONPATH=/mnt/c/Users/tommaso/Documents/Dev/dnd_engine:/mnt/c/Users/tommaso/Documents/Dev/dnd_engine/sdk/python/src
/home/tommaso/.cache/dnd-engine/venv/bin/python tools/protocol_oracle.py
/home/tommaso/.cache/dnd-engine/venv/bin/python tools/reducer_oracle.py
```

The slower real-service lane starts and cleans up its own host and native worker:

```bash
/home/tommaso/.cache/dnd-engine/venv/bin/python tools/sdk_acceptance.py \
  --case ranged --output /mnt/c/Users/tommaso/AppData/Local/Temp/sdk-new-run
```

Use a fresh output directory. `--case magic_missile` exercises ordered multi-target
preview and spell resolution. Private run configurations contain credentials;
the summarized validation report does not. Python prefix comparison uses
`tools/reducer_oracle.py --journal RUN/amber/journal --states RUN/amber/states`
and the corresponding blue pair. It normalizes only visible/seen set order and
the process-local sense-mode hash, which Godot represents as a deterministic
signature. All other fields and values compare exactly.

Godot strings cannot represent embedded NUL. Admission explicitly rejects that
case rather than silently replacing it, even though the Python SDK accepts it.
Other escaped controls are preserved. Decimal input uses exact IEEE-754 rounding
because Godot's built-in decimal parser can differ by one bit; the independent
Python oracle supplies binary64 bit patterns for the codec tests. State evidence
and outgoing JSON use full-precision serialization. The JSON nesting limit is 512 and the
record limit matches the current SDK's 64 MiB. The validator deliberately
supports the shipped schema vocabulary and fails on unknown keywords; it is not
advertised as a general JSON Schema implementation.

The exploration scene is still offline. Connecting its renderer, constructing
the new large backend map and building the UI are subsequent work. UI research
is recorded in `../SCOPE.md`: shared Themes and Control containers, a disclosed
causal Tree, and structured RichTextLabel logs, retaining the old NeuroClient's
reading-position and copy/select behavior. No new UI is introduced here.
