# Native exit after successful Studio and live controls

## Recovery integration update — 22 October

The human supplied both reviewed patches during the active recovery. They are
now applied in the client: exact prototype-material task join at process-root
exit; terminal base range-cookie collection with native subclass cleanup; and
actual baked-only direct source-thumbnail sampling. The real unpolled cookie
control and an actual unpolled material-task root-exit control are included.

The grouped current-source qualification completes at
`.runtime/tests/20261021T231323.714699Z-opus-recovery-shutdown`: 16 cookie,
67 source/root-exit, 255 thumbnail and 61 Transport checks all pass, with natural
process exits 0. The material task is genuinely unfinished before quit; actual
root exit releases its bound owner. The passing Transport receipt is current
closure evidence, not proof of the exact historical task or every interleaving.
Thumbnail pixels pass, but full-context availability still exceeds 200 ms. The following
investigation and original crash receipts retain their historical boundaries;
the exact submission responsible for those dumps remains unidentified.

Historical investigation status,22 October: native failure mechanism narrowed to an unreclaimed
WorkerThreadPool task releasing script-bearing bound data after GDScriptLanguage
destruction. The exact task submission remains unidentified; targeted client
ownership corrections are prepared but not applied or runtime-qualified by this
investigation. This is not a backend, artwork or established Factory defect.
Other integration work continues independently. All artwork/audio remain UNREVIEWED.

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

## 22 October: offline native investigation and bounded correction proposals

The recovery receipt
`.runtime/tests/20261021T222550.160639Z-opus-recovery-affected/summary.json`
again records Studio transport61/0 followed by native exit5. The A10 affected
receipt `.runtime/tests/20261021T223942.929612Z-opus-recovery-a10/summary.json`
also records61/0 followed by exit5. Neither is a passing process.

This investigation started no Godot/backend/build process and changed no
production or test source. The second quiet timing cohort was left undisturbed.
Its independently produced summary subsequently completed three83/0 runs with
natural exit0; that does not explain the failing Studio teardown.

### Evidence from the existing executable and four saved dumps

Read-only extraction and the original return-address candidates are preserved in
`.runtime/closing-repairs/studio-shutdown-owned-tasks/dump-evidence.json`.
`inspect_saved_dumps.py` in that directory reproduces the extraction using only
the existing executable and dumps. These are raw stack-address candidates with
binary/source corroboration, not a claim of a fully symbolicated native unwind.

The four dump PIDs are35260,40568,55040,10040, written at13:13:41,16:39:03,
22:31:36 and22:45:32 UTC on21October. All reportc0000005, a write to0x1b0,
and a captured zero pointer at the executable global RVA0xabfb8d0. The original
executable's code atRVA0x536b70 reads that global, adds0x1a8, then calls its
imported EnterCriticalSection. This is the scripting-language mutex path.

The executable's actual RTTI identifies:

- VtableRVA0x81064d0: `GDScript`.
- VtableRVA0x7feaf40: `WorkerThreadPool`.
- VtableRVA0x7ffb9f0: `CallableCustomBind`.

All four fault stacks contain the corresponding WorkerThreadPool destructor
return atRVA0x3e55597 and task-Callable destruction return atRVA0x3e553fa.
The three Studio dumps also containRVA0x5483a3 inside the GDScript destructor;
the player dump takes a different script-instance notification path. In the
installed binary, the pool shutdown routine releases the retained Task's
Callable; the bind destructor releases its bound Variant data. Those data then
release scripting objects after the language singleton is gone.

This matches the exact pinned engine source: [WorkerThreadPool::finish](https://github.com/godotengine/godot/blob/ed1daf0bf/core/object/worker_thread_pool.cpp#L790-L816)
frees remaining Task allocations, while [Main::cleanup](https://github.com/godotengine/godot/blob/ed1daf0bf/main/main.cpp#L4877-L4904)
has already finished scripting languages before late core shutdown. The
[GDScript destructor and pending-function cancellation](https://github.com/godotengine/godot/blob/ed1daf0bf/modules/gdscript/gdscript.cpp#L1388-L1427)
still require the language singleton's mutex.

The captured heap ranges do not include the particular Task/description.
Therefore the native evidence identifies the unreclaimed-task mechanism, not
which client submission produced that task. It does not establish random heap
corruption, an RTX/Vulkan fault, or a Factory shader error.

### Definite client ownership omissions

1. `NativeSourceAdmission.prepare_materials` submits **Native prototype programs**.
   Only ordinary `_poll()` collects `_material_job`; consumer cancellation
   handles `_source_job` and never joins that material task. Exiting after
   submission but before another poll leaves its Callable/job/cache retained by
   the pool, even if the work has already finished. The bounded proposal adds
   final process-root ownership for this exact job, without another draw fence,
   readiness publication or normal-play blocking.
2. `Lighting2D._range_cookies` owns **Generate light cookie** tasks. Final Play
   teardown calls `clear_pages()`, which clears light nodes but never collects
   these ordinary range-cookie jobs. The native-effect subclass already joins
   its separate effect-cookie jobs. The proposal gives the base owner terminal
   `close()` using existing `LightCookies.release()`, preserves ordinary
   `clear_pages()` reuse, and makes final Play teardown call terminal close.

The unapplied `owned-task-retirement.patch` and its source mirrors live in
the same scratch directory. These repair proven ownership gaps; neither is yet
proven to be the task in the dumps. BackgroundRelease's deferred next-frame
submissions remain a separate ordering question. Draw-callback/token-retirement
gaps are source findings, but they are not substituted for the demonstrated
WorkerThreadPool outer owner. No global task sweep, force exit, extra playback
delay, unsafe cache shortcut or engine/source-package modification is proposed.

### Separate slow-preview finding

The affected source-preview resource control passes255 functional assertions
but reports4.315–6.652s until its requested thumbnails are available, against
its200ms target. The transport receipt's6.153s case selection spends6.114s in
prepared-world readiness versus2.491ms constructing the host. Those are
different boundaries; neither is a measured live Fireball cast delay.

An avoidable source-only swatch delay is independently visible in
`studio/native_spell_preview.gd`: every requested sample advances at most1/60
source-second per drawn frame, even for a recorded approach. Ordinary
non-lifecycle clips use an infinite opening endpoint, so they never bypass
that stepping. A two-second recorded sample consequently requires about120
draw advances after source readiness. Existing `Baked.sample()` already selects
the absolute recorded state. `recorded-preview-clock.patch` therefore proposes
direct sampling only for an actual baked handle, preserving live simulation,
authored clocks/controls and the final post-draw witness. Its contribution to
whole Studio delay and pixel equivalence remain unmeasured.

### Applicable next qualification

Apply/review the bounded changes between existing frozen readers. Extend the
existing cookie control for an unpolled real job and terminal double-close.
Run the affected source/preparation and thumbnail pixel controls, then repeat
the original Studio transport through natural exit, retaining nonzero exits.
Exercise final close with prototype work submitted but not consumed by another
ordinary poll. A clean native repeat establishes its own cutoff; it does not
rewrite the four preserved crashes or establish the exact historical task.
No competing GPU process may overlap the recovery timing cohort.

Independent source review found no blocking issue in either unapplied patch:
exact material-job ownership, subclass light-cookie cleanup, unchanged ordinary
page reuse, actual baked-handle selection and final draw observation are retained.
Context checks also accept both patches on checkpoint523d5e02. This is source
review/applicability only. In particular the cookie assertion does not qualify
the material root-exit hook; that requires the explicit unpolled-material case.
