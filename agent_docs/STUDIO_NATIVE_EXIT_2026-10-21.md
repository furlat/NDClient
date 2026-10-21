# Studio native exit after successful transport controls

Current status: open client runtime investigation, cause unattributed. This is
not a backend, artwork or established Factory defect. Other integration work
continues independently. All artwork/audio remain UNREVIEWED.

The current Forward+/Vulkan transport invocation completed 61 assertions with
zero failures, then exited with code 5. The runner correctly marks it failed:

- Receipt: `.runtime/tests/20261021T131204.311779Z/summary.json`.
- Exact log: `.runtime/tests/20261021T131204.311779Z/studio_transport_checks.log`.
- Script: `res://tests/studio_transport_checks.gd`, Godot 4.7.2, installed
  `runtime-spike-seed-20261021-7ca62e2877bf5156`.
- Three actual loops, exactly two hosts, preserved canonical seeks, four
  camera rotations, retained textures, and study/rejected-selection controls
  reached their assertions. This does not qualify process teardown.

The matching Windows Application Error event at 13:13:38 UTC reports
`Godot_v4.7.2-stable_win64.exe`, exception `0xc0000005`, faulting module
`ntdll.dll`, offset `0x1ceed`, process `0x89BC`, report
`c565f028-7414-4eae-aa32-64fd1922b115`. The native access violation is consistent
with the exit's low byte; the module name does not identify the originating
code or establish an operating-system defect. The event time aligns with the
single owned GPU transport process.

Preserved event:
`.runtime/material-runtime-integration-20261021/windows-godot-exit5-event.json`.
No GDScript/resource error, timeout or leftover process was reported by this
invocation. A prior transport invocation failed its loop/seek assertions;
neither receipt is replaced by the other.

Next client action: distinguish native teardown/worker/resource retirement
from a reproducible source defect using the existing bounded transport case.
Keep actual exit status in qualification; do not turn passing assertions into
a process pass, suppress the crash, or request backend changes without evidence.
