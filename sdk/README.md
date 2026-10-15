# Godot player SDK

This project-local SDK consumes the current DnD player API: protocol 1, player
schema 9. It ships the unchanged schema and identity from `dnd_engine/sdk/protocol`.
The current Python/TypeScript transports and `dnd/player/reduction.py` are its
references. The old `sdk/typescript` client is not a dependency.

The SDK uses built-in Godot facilities and GDScript. The optional unsigned
GDSchema extension evaluated during research is not installed in this project;
no certificate or Windows security-policy changes are required.

Schema 9 adds optical source observations to existing sensory after-values.
Live source descriptors carry position, height, radii, appearance and permitted
anchors, with an empty optional `affected_tiles` map. The renderer needs no
per-source cell map. The SDK retains source and removal revisions and coalesces
disclosed optional anchors; historical nonempty footprints retain their
equal-revision union during archive replay.
Equal-revision loss of one observer's view does not erase another observer's
current source; a newer removal retires older retained observations. These are
passive renderer inputs, not another light simulation or gameplay calculation.
An explicit empty `light_sources` map is authoritative. Historical schemas omit
that key and retain legacy source discovery; Studio selects their archived schema
explicitly. Live connections continue to require the current identity.

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

`trusted_choices` defaults to `false` in the SDK. The live player opts in after
connecting to its own protocol-checked server. That option uses Godot's native
JSON parser for `ChoicesResponse`, validates its envelope, actor/discovery identity,
shared domains and action references, then checks response-local references. It
keeps the ordinary scope/revision/correlation checks. Unrelated nested action
metadata remains trusted server output. Admitted choices and previews are handed
off once as sparse read-only tables: no defaulted copy, tree expansion or second
deep copy is made. This is deliberately different from untrusted imports:
public `decode`/`validate` and public journal/replay admission remain strict.
Native query parsing follows Godot's floating-point conversion and JSON
syntax tolerance; it does not promise bit-exact decoding of arbitrary decimal
tokens. It never changes the recorded event codec.
Native query numbers are floats in Godot. UI/world consumers compare coordinate
and ContentRef scalar values, not whole Array/Dictionary identity; this preserves
integer world picks and exact content versions without rewriting shared domains.

`trusted_operations` is a separate boolean option, defaulting to `false`. The
player launcher enables it only for the current typed server it owns on loopback;
Session configuration leaves it off unless explicitly supplied. Transport rejects
remote hosts for this option and requires the shipped protocol identity in both
bootstrap and the stream's ready record before accepting trusted operations.
Schema identity alone is not a guarantee of canonical bodies: this option trusts
this producer's `model_dump_json()` output, including defaults and UUID casing.

Trusted operations retain the exact JSON parser, integer token types, binary64
decimal rounding, UTF-8/NUL/size limits, bounded envelope checks and all
identity/scope/cursor/SSE sequence checks. Only recursive typed-body schema
validation and the redundant canonical normalization copy are skipped.
Initialization, status and errors remain strict. Transactional semantic reduction
must still succeed before state publication and ACK; malformed arbitrary nested
bodies are outside this explicit producer-trust guarantee. Public SDK decoding,
public `journal.consume`, archived recordings, cold replay and preparation's
overflow disk reads retain strict admission and normalization.

Choices are fetched for the latest consumed and acknowledged human-input boundary
while presentation plays. One result stays private until playback reaches its
matching cursor and actor; scope, attachment, revision or force-mode changes
discard stale results. No prefetched targets or action buttons enter a historical
display, and command submission retains its existing readiness and receipt rules.

`choices.gd` supplies the delivered response-local helper contract:
`all_actions`, `action_options`, `binding_subject`, `binding_position`,
`binding_value`, `binding_path`, `secondary_options`, `next_options`,
`preview_positions`, `selection_for` and optional `position_eligibility`.
These borrow shared domains rather than reconstructing `valid_targets`.
Keep selection UI separate from immutable admitted dictionaries. Native action
and target indices are not table offsets; ordered repeats remain meaningful.
Missing nullable pair fields mean null, missing hazards mean false, and missing
exposures mean empty. `secondary_set = 0` is valid, null inherits the primary
pool, and a reference to an empty set offers no continuation.

Every Preview owns its own subjects, positions and target sets. Resolve its
continuations and affected cells against that Preview, never against Choices.
Deferred AoE choices are different from a computed-empty Preview. The current
player requests the selected Preview for exact subjective geometry; this intake
does not introduce a second local gameplay or AoE propagation implementation.

The default consumer receives `(packet, raw_bytes)` and must return a result.
When `trusted_operations` is enabled, its callback must also accept an optional
third argument, `canonical_server_operation: bool = false`. Transport passes
`true` only for the checked live operation path; initialization still uses two
arguments. The player forwards this private ownership flag to its journal; an
ordinary two-argument consumer and public journal calls retain strict behavior.
The consumer runs
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
The journal copies only containers that the next transaction can mutate, sharing
immutable installed records with its earlier states. Public reducer functions
still return fully detached values. Actor event snapshots own mutable loadout
and item shells; later facts replace immutable leaves. The retained-transaction
checks exercise later nested mutations and failures after successful fact folds.

Schema 7 world updates install complete `tiles` before applying ordered
`tile_changes` to known positions at that same event. Each patch creates a new
complete tile, retaining omitted fields and replacing present fields wholesale,
including explicit clears. Unknown bases fail the transaction. Staging still uses
only full first-disclosure records; presentation receives reconstructed complete
after-values at the original commit times. Schema 7 and older recordings select
their exact archived contract only through explicit historical replay, never
live admission. Schema 8 changes query domains, not the tile-field reducer.

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

To include current-server operation trust/parity and real loopback SSE checks,
pass an explicit current journal; recordings are not tracked test dependencies:

```bash
python3 tools/check_sdk.py --trusted-operations-recording /path/to/current/journal
```

The focused script can also run directly with
`--script res://tests/trusted_operations_checks.gd -- --recording=<journal>`.
Its [report](../generated/trusted_operations_checks.json) records the exact input
and command. The latest focused run passes 450 checks across 101 operation
records and bounded-admission/loopback fault cases; it is correctness evidence,
not a live performance measurement.

The slower real-service lane starts and cleans up its own host and native worker:

```bash
/home/tommaso/.cache/dnd-engine/venv/bin/python tools/sdk_acceptance.py \
  --case ranged --output /mnt/c/Users/tommaso/AppData/Local/Temp/sdk-new-run
```

Use a fresh output directory. `--case magic_missile` exercises ordered multi-target
preview and spell resolution; `--case fireball_six_goblins` checks a selected
computed area against the real encounter. Private run configurations contain credentials;
the summarized validation report does not. Python prefix comparison uses
`tools/reducer_oracle.py --journal RUN/amber/journal --states RUN/amber/states`
and the corresponding blue pair. It normalizes only visible/seen set order and
the process-local sense-mode hash, which Godot represents as a deterministic
signature. All other fields and values compare exactly.

Godot strings cannot represent embedded NUL. Admission explicitly rejects that
case rather than silently replacing it, even though the Python SDK accepts it.
Other escaped controls are preserved. Strict event/import decoding uses exact IEEE-754 rounding
because Godot's built-in decimal parser can differ by one bit; the independent
Python oracle supplies binary64 bit patterns for the codec tests. State evidence
and outgoing JSON use full-precision serialization. The JSON nesting limit is 512 and the
record limit matches the current SDK's 64 MiB. The validator deliberately
supports the shipped schema vocabulary and fails on unknown keywords; it is not
advertised as a general JSON Schema implementation.

The production player in `../play.gd` consumes this SDK through
`../presentation/session.gd`. Its displayed timeline and HUD remain behind the
latest native state while authored animations play. Choices may prepare ahead,
but only the matching displayed boundary can publish them or accept input.
Player controls and rendering are documented in the project README; the older
exploration scene remains an offline fixture.


## Compact discovery acceptance — 13 October 2026

The [schema 8 acceptance report](../generated/compact_choices_acceptance.json)
records the native Gallery route (58 commands, 644 checks, 16 actual Gallery
viewport clicks), semantic/transport tests, selected Fireball, repeated-target
Magic Missile and historical schema 7 replay. Compact interaction tests include
native JSON floats against integer grid picks and exact ContentRef metadata;
no response-wide normalization is needed for either.

The largest Gallery choices reply is 273,132 bytes versus 2,399,276 before; client
admission/publication is 75.911 ms versus 536.056 ms including the former defaulting
and copy passes. These are query-processing figures, not total movement latency.
The final real-click route still measures 317.728 ms median click-to-motion in the
Gallery. Its [per-command trace analysis](../generated/compact_choices_live_pipeline.json)
keeps server dispatch, event admission, consumer, compiler and completion frames
separate. No graphics-performance improvement is claimed by this protocol intake.
