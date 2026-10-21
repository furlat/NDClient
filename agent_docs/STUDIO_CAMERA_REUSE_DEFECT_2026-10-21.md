# Studio camera-quarter reuse defect — 21 October 2026

Status: the actual walled Gallery regression reproduces the defect before the
one-file correction and passes afterward: **269 checks, 22 failed before;
269 checks, zero failed after**. The first regression used an open melee arena
and failed its three wall-presence assertions; that failed receipt is retained
and did not qualify this artifact. The original three-prefix melee checks remain
in the corrected test. All artwork and audio remain **UNREVIEWED**.

[Exact comparison receipt](../.runtime/material-runtime-integration-20261021/camera-before-after.json),
[original failing run](../.runtime/tests/20261021T112534.761667Z),
[corrected passing run](../.runtime/tests/20261021T112549.760670Z).

The user's original screenshot is preserved at
[wall rotation artifact](../.runtime/material-runtime-integration-20261021/user-wall-rotation-defect.png).
The back/left room walls appear as narrow, leaning disconnected strips while
part of the right wall remains full width. The displayed timeline is at
41.599 / 43.489 seconds.

## Source cause matching the observed pattern

1. `Play.try_reset_hidden_playback` deliberately retains a hidden spare's static
   sources and its published `world_quarter` while replacing the Timeline.
2. `ReplayPanes.prepare` then directly assigns the reference pane's quarter to
   the reused host and moves its camera, despite the retained geometry still
   belonging to the spare's previous quarter.
3. World preparation retains groups whose authored rows are unchanged. Their
   billboard geometry remains in the previous camera basis; changed groups are
   rebuilt for the new basis. This permits a scene containing both orientations.

The same `ReplayPanes.prepare` path serves ordinary Studio seeks/loops and
composed previews. The applied correction preserves the published quarter of
reused hosts and requests the target through existing `request_view` publication.
New empty panes can still set their initial quarter. Existing candidate readiness
already waits for camera publication; source preparation, scheduling and clocks
remain owned by their current systems.

## Why the existing evidence missed this path

The native rotation suite checks ordinary Play quarter publication. The spare
reuse suite checks three real Timeline prefixes with one camera quarter. It did
not exercise a spare retained at quarter 0 after the reference reached quarter 1.
Canonical state and settled-view checks did not establish scenery correctness
for that combination.

The regression extends the existing spare suite with that actual cross-quarter
reuse, checks all ten selected wall registrations and their actual billboard
bases against a fresh target view, and saves the original/fresh/reused captures.
It preserves canonical state, the paused displayed reference and the existing
preparation/publication path.

The unchanged Gallery prefix reproduces the user's narrow-slat wall pattern
with the old code; the corrected code renders the intact room. This establishes
the source defect and its repair without claiming a replay of the user's exact
41.599-second recording or accepting the artwork.

| Reused quarter 1 before correction | Reused quarter 1 after correction |
| --- | --- |
| [Narrow wall strips](../.runtime/material-runtime-integration-20261021/camera-before-fix/q1-reused.png) | [Intact Gallery walls](../.runtime/material-runtime-integration-20261021/camera-after-fix/q1-reused.png) |

The larger 413-row run was interrupted to repair this user-reported defect;
the focused camera pass is not a completed replacement for that whole suite.
