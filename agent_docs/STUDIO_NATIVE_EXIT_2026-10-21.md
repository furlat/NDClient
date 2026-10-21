# Native exit after successful Studio and live controls

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

## Subsequent actual delayed-server invocation, 21 October 16:39 UTC

The complete broad batch later encountered another native access violation after
`player_wait_checks` completed all **16 assertions with zero assertion failures**.
This invocation used installed `runtime-call-heavy-defaults-20261021-8dd103fb92174541`
and immutable producer `9f81d52676d4cea78be0be951dfc51a756050032`.
The actual 2,000 ms delayed-server command, continuing camera input and 305
animation samples passed; session close took 1 ms and reported no pending
retirement groups. These functional observations do not qualify native teardown.

- Launcher log: `.runtime/tests/20261021T144622.590398Z-current-checkpoint/player_wait_checks.log`.
- Native log and original control: `.runtime/player-runs/20261021T163851.617705Z/`.
- Windows event: `.runtime/material-runtime-integration-20261021/windows-player-wait-native-exit-event.json`.
- Application Error record **75514**, UTC **16:39:00.9460468**, exception
  `0xc0000005`, `ntdll.dll`, offset `0x1ceed`, process `0x9E78`, report
  `edeed91e-7e97-4be9-8447-774b426f65f2`.

`tools/play.py` reports generic launch failure and exits 1 after a nonzero native
exit; that launcher code is **not** the actual native process status. The
matching event establishes an access violation for this process. Its module and
offset match the earlier Studio event, which does not establish a common cause
or identify a backend, Factory or operating-system defect. Successful intervening
exits do not explain either crash. The current source-frozen live closure batch
includes one ordinary existing delayed-server invocation; its result will remain
a separate receipt.
