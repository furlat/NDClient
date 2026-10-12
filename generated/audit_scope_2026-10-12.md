# Scope, architecture and validation audit — 12 October 2026

Independent same-task review by `scope_review`. The requested scope covered the
NDClientGodot root, presentation, SDK, tools, tests and documentation while the
implementation owner repaired wall composition. The review was read-only;
saving this report was separately authorized. No artwork, backend files or
implementation were changed by this reviewer, and no native renderer, server
or gameplay tests were launched.

The review looked for material scope drift, unnecessary parallel ownership,
misleading validation claims and gameplay class hierarchies. It combined
targeted source inspection with a structural scan of all 108 source files:
87 GDScript scripts, 12 Python files and nine shader/include files. Literal
GDScript resource dependencies had no missing targets or cycles. All 12 Python
files parsed successfully. These checks are not a complete behavioral
verification or proof that every runtime path is correct.

## Findings

### P2 — Profiler could succeed despite failed or incomplete presentation

At review time, `tests/player_profile.gd:44–49` returned success solely when the
displayed canonical state equaled the journal state. Presentation failures can
leave that equality intact: `play.gd:353–358` records a character-resolution
error and hides the affected actor without changing canonical state. The
profiler printed `presentation_errors` but did not fail on them. Its
20,000-step playback limit also lacked an explicit drained-timeline/final-
sequence assertion.

Consequence: an incomplete or visibly broken replay could be recorded as a
successful performance run. This is a validation weakness, not evidence that
the previously captured runs themselves failed.

**Status:** implementation owner corrected the gate during this audit. Fresh
inspection of `tests/player_profile.gd:44–51` confirms that success now requires
canonical equality, a drained timeline, displayed sequence equal to the journal
cursor, empty presentation errors and an empty session issue. The native rerun
was still pending when this report was saved.

### P2 — Documented editable character scene is not the runtime owner

`README.md:341–345` says runtime instantiates the editable
`generated/modular_animation.tscn`. In fact,
`animation/graphs.gd:104–105` calls `build_character(parent, rig)` directly;
the runtime does not load that generated character scene.
`tools/import_animations.gd:6–8` still generates it. The separate generated
destruction scene is loaded and instantiated, so the two resources have
different roles.

Consequence: someone following the documentation to edit the character graph
edits a resource the runtime ignores. Correct the documented runtime owner and
identify the generated character scene's actual role. This finding does not
require a runtime architecture redesign.

**Status:** documentation correction assigned to the implementation owner;
the stale wording remained present when this report was saved.

## Scope and architecture assessment

No material unauthorized expansion or gameplay entity class hierarchy was
identified. Godot scene/Control/RefCounted ownership is compatible with the
user's accepted native-engine approach. The SDK reducer and presentation
compiler operate on passive records. The live player retains backend command,
visibility and outcome authority, with separate consumed and displayed state.

The preserved offline workshop/exploration and the live Crypt player are
distinct, documented launch paths. Their coexistence is authorized earlier
work, not evidence of a second gameplay rules engine. Offline GPU performance
figures are explicitly distinguished from live Crypt measurements. The exact
decimal codec, current-schema validator and Python differential corpus address
documented SDK requirements; their existence alone is not unnecessary work.

The current fragment-level wall repair remains within the accumulated request:
displayed SDK-visible tile diamonds, the existing foreground-boundary policy,
shared passive numeric data, shader opacity/discard and a matching picking
predicate. No new visibility simulation, backend geometry, artwork or physics
system was introduced by this change. Current README/SCOPE descriptions of
two-state Z and whole-corner opacity must be reconciled with the final validated
three-state, fragment-level behavior. This report does not certify the pending
native wall results.

## Validation limits

The review found no basis for an absolute correctness or completeness claim.
Historical reports have distinct scopes and dates; the combined render-repair
report still marked the repair incomplete during the audit. Native test results
reported by the implementation owner are separate evidence and were not
independently rerun here. The two findings above concern a concrete acceptance
gap and misleading resource ownership, rather than speculative framework or
style changes.

## Implementation follow-up

After the read-only audit, the implementation owner corrected README's runtime
character graph ownership and the Z/fragment descriptions in README and SCOPE.
Native wall checks passed (22 fragment, 565 visibility, 20 compositor), alongside
59 lighting and 44 architectural-lighting checks. Profiler gate verification is
recorded separately in generated/render_repair_validation.json.

The final native profile completed2620 presentation steps, drained the timeline,
matched canonical state/sequence and reported no presentation errors. Evidence:
`.runtime/profile-fragments.log` and `generated/wall_fragment_profile.json`.

## Later authorized scale work and sensory correction

The original read-only audit above predates the user's subsequent authorization
to implement a connected gallery, optimize the live client and investigate
measured backend command latency. This reviewer subsequently implemented the
dedicated `encounter.lantern_gallery` fixture, recorded its actual public-SDK
traversal, and made the bounded sensory correction described here. Those later
changes were authorized explicitly; the opening read-only statement describes
the original audit only.

The gallery retains the original Crypt and adds a connected 48×36 furnished
hall with native doors, obstacles and lights. It uses one additional normal
guardian to keep the encounter active. The benchmark journal is an authentic
58-command route, not replicated packets or teleports. Original input remains
in `.runtime/gallery-route/journal`; diagnostic repetitions are separate.

Moving-light timing exposed a correctness dependency in
`dnd_engine/dnd/blocks/sensory.py`: recomputation captured the committed actor
position but measured special-sense distances using the previous senses
position. All four new regression cases failed before repair: toward/away
movement across a 15-foot Darkvision/Truesight boundary, with/without an attached
light. Attached-light cases checked the intermediate LIGHT sensory completion,
not only the final movement state.

The correction reuses the existing pure `grid_distance_feet` helper with the
captured current origin. It preserves the existing floored Euclidean rule and
atomic after-value replacement. Once corrected, the existing fully-current
field branch also accepts self-entry after a light child has already refreshed
that observer. Published-observer, occupancy-revision, world-revision and owner
state guards remain; parent event completion, hazard refresh and path-dirty
publication remain intact. No event batching or FOV algorithm was replaced.

Validation: 60 tests passed across `test_sensory_movement_origin.py`,
`test_senses_light_stealth.py`, `test_sensory_initial_replay.py` and
`test_light_source_projection.py`. The new cases reduce serialized observations
in source order and verify that a subsequent public full refresh neither
corrects perception nor emits an extra sensory delta. The implementation owner
independently reviewed the narrow diff and found no blocker.

Two instrumented actual gallery games completed the same 58 command outcomes,
102 packets and final sequence 101. Action, actor, position, HP, disclosed counts
and route stages match. Across 29 Move commands, mean worker dispatch decreased
from 2745.68ms to 1953.68ms; all-command P95 from 5530.58ms to 3946.76ms, and maximum
from 6182.11ms to 4760.09ms. Backend command latency still reaches multiple seconds.
Moving-light publication remained substantial: 50.91s before, 44.06s after;
update-position totals 65.31s and 44.88s. These are
inclusive instrumented wall times, with nested phases that must not be summed.
They exclude HTTP/queue/polling waits and packet serialization/delivery. One
before/after run is evidence of this measured change, not a general latency
guarantee or a claim that client rendering resolved backend delays.

Raw evidence is in `.runtime/gallery-timing` and `.runtime/gallery-timing-after`.
`comparison.json` reports full-state normalization differences honestly: the
two games have fresh UUIDs and UUID-ordered inventory/perception collections,
including differences at unchanged initialization. This is not evidence of
full cross-game canonical-prefix equality. The 58-command outcome comparison
and the focused emitted-prefix/replay tests are the established guarantees.
All owned diagnostic hosts, workers and CPU tests stopped before final native
performance measurement.

Remaining broader audit limitations include unbounded paused intake/history
collections, explicitly recorded profiler history, and per-fragment iteration
over disclosed source lights. Character residency has a 512MiB soft estimate;
environment media is a separate pinned working set. Native tests and measured
scenarios do not prove arbitrary-catalog completeness. Final client stall and
image-equivalence results belong to the separately recorded native benchmarks;
no blanket claim that all prior review findings or scaling limits are closed
is warranted.
