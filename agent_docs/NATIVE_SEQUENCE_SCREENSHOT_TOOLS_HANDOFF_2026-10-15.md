# Native sequence screenshots and clips — Studio handoff

15 October 2026. Requested by the user for the production/NDStudio Godot agent.

**Purpose:** let an agent see the complete rendered sequence with actual actors, equipment, casting, native effects, contact, response and removal. This is an internal visual inspection tool. Its PNGs, contact sheets and MP4s are review evidence, not production VFX assets. No spritesheet, depth, normals or XYZ export is part of this workflow.

The Factory implementation works now. **Integration into Studio has not been performed.** This document is also supplied in the production repository's agent_docs. Production code remains unchanged; no message was sent to another chat.

## Working code and examples

Factory root: C:\Users\tommaso\Documents\assets\VFXFactory, also available at /mnt/c/Users/tommaso/Documents/assets/VFXFactory.

| File | Responsibility |
| --- | --- |
| [GDScript sequence observer](/mnt/c/Users/tommaso/Documents/assets/VFXFactory/factory/authoring/sequence_review.gd) | Select a case, restart its real authoring scene, advance its displayed clock, wait for the draw, capture the final viewport and record cue/time/error information |
| [Python runner and packaging](/mnt/c/Users/tommaso/Documents/assets/VFXFactory/tools/native_authoring/review_sequence.py) | Launch the ordinary project with official Windows Godot, watch its own process, encode clips, select contact-sheet moments, prune intermediate PNGs and build a small HTML index |
| [Factory host adapter](/mnt/c/Users/tommaso/Documents/assets/VFXFactory/factory/scenes/authoring_world.gd) | Read --sequence-review, resolve saved spell Resources and start the observer in the generated production-renderer host |
| [Core scene](/mnt/c/Users/tommaso/Documents/assets/VFXFactory/factory/scenes/authoring_world.tscn) | Production-renderer fixture with modular characters and wooden tiles |
| [Saved spell index](/mnt/c/Users/tommaso/Documents/assets/VFXFactory/authoring/spells/index.json) | The current 34 fixture spell selections; this is not the entire historical artwork library |

Rendered evidence:

- [Fire Bolt and Magic Missile, plus four explicitly unaccepted support baselines](/mnt/c/Users/tommaso/Documents/assets/VFXFactory/reviews/native-sequences-20261015/first-six/index.html).
- [Twelve projectile/area spell sequences](/mnt/c/Users/tommaso/Documents/assets/VFXFactory/reviews/native-sequences-20261015/projectile-area-pass/index.html).
- [Sixteen support/area spell sequences](/mnt/c/Users/tommaso/Documents/assets/VFXFactory/reviews/native-sequences-20261015/support-area-pass/index.html).
- [Source-coordinate repair: chains, shield, spiral, Slow and Death Ward](/mnt/c/Users/tommaso/Documents/assets/VFXFactory/reviews/native-sequences-20261015/source-space-repair/index.html).
- [Steady overhead markers and a separate Slow colour candidate](/mnt/c/Users/tommaso/Documents/assets/VFXFactory/reviews/native-sequences-20261015/condition-glyph-pass/index.html).
- [Second-camera placement checks, including Heroes' Feast on empty ground](/mnt/c/Users/tommaso/Documents/assets/VFXFactory/reviews/native-sequences-20261015/placement-camera-check-v2/index.html).

All 34 fixture spells completed sequence capture with no script/construction errors. A completed capture is **not artistic acceptance** or proof of every gameplay branch. Aid, Bless, False Life and Sacred Flame retain their existing unaccepted status. Legacy compositions and colour variants remain private review candidates. Marker previews demonstrate glyph presentation, not full condition mechanics/body effects.

## Run it now in Factory

The launcher is a WSL Python convenience around official Windows Godot 4.7.2, Forward+/Vulkan. Successful logs identify NVIDIA GeForce RTX 5090. It runs an ordinary Godot project, not a custom executable or a software renderer.

~~~bash
cd /mnt/c/Users/tommaso/Documents/assets/VFXFactory

/home/tommaso/.cache/vfxfactory/export-venv/bin/python \
  tools/native_authoring/review_sequence.py \
  --spells fire_bolt magic_missile \
  --camera 0 \
  --review-fps 12 \
  --output reviews/studio-handoff-example
~~~

Use a fresh output directory. Completed review folders are protected against accidental reuse. The wrapper requires Pillow, ffmpeg on PATH and wslpath. Its Godot path is explicit near the top of the script; make that a setting when adapting it to Studio rather than retaining another machine's local paths.

| Option | Current behaviour |
| --- | --- |
| --spells ID... | Explicit bounded list |
| --spells all | All 34 current fixture selections, **not** all authored spells/conditions |
| --resources PATH | JSON map from case ID to a saved res:// spell Resource; only selected IDs load as additional cases |
| --camera 0..3 | One production camera quarter for this run |
| --review-fps 1..30 | Screenshot/video sampling rate; default 12 |
| --retain-frames | Keep every captured PNG; otherwise keep the contact-sheet frames and MP4 |

The observer advances source/display time at 60 Hz; screenshot FPS is independent. Components retain their own authored sampling behaviour and simulation_hz. Do not replace the native particle clock with the low review FPS. The 60-Hz stepping is a current Factory implementation detail, not a requirement to force Studio or every source to that rate.

Generated job:

~~~json
{
  "output": "res://reviews/studio-handoff-example",
  "review_fps": 12,
  "resources": {},
  "cases": [
    {"id": "fire_bolt", "camera": 0, "split_targets": false},
    {"id": "magic_missile", "camera": 0, "split_targets": true}
  ]
}
~~~

The ordinary project can consume that saved job directly:

~~~powershell
$reviewArgs = @(
  "--path", "C:\Users\tommaso\Documents\assets\VFXFactory",
  "--rendering-method", "forward_plus", "--rendering-driver", "vulkan",
  "--fixed-fps", "60", "--resolution", "1280x800",
  "res://factory/scenes/authoring_world.tscn",
  "--", "--sequence-review", "res://reviews/studio-handoff-example/job.json"
)
& "C:\Users\tommaso\Documents\Dev\Tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe" @reviewArgs
~~~

The direct Godot command creates images/receipts. Python performs MP4/contact-sheet/HTML packaging. That command does not create the job file itself.

### Outputs and failures

Each case directory contains sequence.mp4, contact.jpg, sequence.json and retained frame-NNNN.png images. The batch contains index.html, job.json, capture.json, console.log and godot.log.

sequence.json records actual sampled seconds, camera, preparation/release/arrival and scheduled source cue begin/end/contact times. Contact sheets select eight moments across preparation, release, contact, the longest source phase and clearance, avoiding duplicate frame choices where possible. These labels are inspection aids; they do not invent gameplay events.

Packaging happens after each completed case, so intermediate full-resolution PNGs do not accumulate across a long batch. The process watcher stops its own child after a script error or a bounded timeout. The final command fails for recorded failures or source errors. **Read the receipts and images**, not only the last progress message.

## Integrate with the existing Studio

Studio is already in NDClientGodot through [studio.tscn](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/studio.tscn) and [studio/studio.gd](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/studio/studio.gd). Use those owners. Do not create another application, renderer, replay scheduler or spell-specific synthetic recording format.

| Existing production source | Reuse |
| --- | --- |
| [studio/studio.gd](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/studio/studio.gd) | Recording selection, _seek(), candidate installation, current viewport/world, replay diagnostics and paired-pane advancement |
| [studio/replay_panes.gd](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/studio/replay_panes.gd) | Stable pane ownership, independent mutable render state, preparation and freezing |
| [tests/studio_condition_restore_native_checks.gd](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/tests/studio_condition_restore_native_checks.gd) | Working settled-seek gate and both full-UI and world-pane PNG capture |
| [tests/studio_hide_render_checks.gd](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/tests/studio_hide_render_checks.gd) | Readiness including component_renderer.ready, exact displayed-time checks, actual pane screenshots and assembled actor bounds |
| [play.gd](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/play.gd) | Existing can_publish_replay_advance()/publish_replay_advance() and rendering/preparation gates |

tools/studio_capture.py and tools/studio_spell_capture.py capture **server/SDK recording evidence**. They are not screenshot tools. Reuse their existing admitted recordings for gameplay inspection; do not silently generate backend outcomes just to capture an image. tools/render_studio_scenarios.py renders a Markdown catalogue, not scene images.

### Thin adapter

Keep frame writing, contact selection and clip packaging shared. Replace only the Factory host controls:

| Factory observer currently uses | Studio adapter should use |
| --- | --- |
| Spell Resource ID and select_spell() | Existing recording/case/perspective and selected event/row |
| elapsed, duration, release, arrival and cue_plan | Published Studio displayed time, selected replay range and actual compiled row/event/source boundaries |
| restart() and _sample_frame() | Existing Studio seek/readiness and production replay advancement |
| rotate_view() | Existing Studio camera rotation/preparation, with framing retained |
| host.get_viewport() | The **current** Studio pane viewport, or root viewport when UI context is requested |

Do not paste the Factory observer's elapsed assignment or offline cue scheduler into Studio. Factory staging is useful for authoring; Studio must inspect the real recording through its existing runtime.

For a still image:

1. Seek using Studio's existing method.
2. Wait for the current recording/prefix to install: nonempty index; loader/seeker complete; installing false; requested_seek negative; rotation settled; component renderer ready. Use the existing tests as implementation references.
3. Confirm published timeline.display_ms matches the requested time; inspect presentation_errors/media_issue.
4. Wait for process_frame and RenderingServer.frame_post_draw.
5. Resolve the **current** studio.viewport after the seek. Studio can replace its pane during preparation; a cached old viewport can capture the previous scene.
6. Save the final pane image. Optionally also save the root viewport for timeline/UI context.

The existing screenshot boundary:

~~~gdscript
# After Studio's readiness gate and exact-time check:
await get_tree().process_frame
await RenderingServer.frame_post_draw
studio.viewport.get_texture().get_image().save_png(world_path)
# Optional full Studio UI:
get_tree().root.get_texture().get_image().save_png(ui_path)
~~~

For a continuous clip, prepare/seek once, then advance through existing production replay and readiness gates. Observe published times; do not rebuild and seek the whole recording for every video frame. Do not assign timeline.display_ms to bypass preparation or sample the private native source separately. Paired faction panes retain Studio's synchronized-publication checks and independent visibility.

Capture the final rendered pane, not only native_effect_layer.viewport: the latter is a source pass and omits actors/floor/equipment/body treatments whose integration we need to check. Preserve source lights, material selection, native depth and body masks.

## Suggested first production delivery

Add a small agent-facing helper with explicit recording/perspective, time or bounded range, camera and output folder. It can be a command-line/test entry point or a small action in existing Studio controls; no separate UI is needed.

Use the Python contact/clip packager on its receipts. Persist requested/published times, selected recording/row, camera, pane dimensions, errors and filenames. Keep still capture usable without ffmpeg. Provide full-UI and clean final-pane options.

First verify Fire Bolt and Magic Missile using existing real recordings: preparation → hand release → travel/ordered contacts → actual receiving reaction → tail/clearance. Then cover one persistent condition's application/removal and one rotated camera. Use bounded cases before expanding.

Screenshot success remains separate from source availability, a presented-track witness and artistic acceptance. Include missing layers/errors in the receipt rather than silently declaring a completed render.

## Limits and pitfalls

- Review FPS of 8–12 is economical; it can miss a short flash. Use higher sampling or an exact-time still through existing seek when checking a boundary. Uniform review frames do not necessarily land on every source key.
- Contact-sheet moments are heuristics, not proof that every effect reached its peak. Full clips and cue receipts remain available.
- The Factory tool hides controls and moves **its own** review window offscreen. It must never close or restart the user's active Studio or another agent's Godot.
- Bound GPU concurrency and durations; keep process ownership/cleanup. Do not launch every camera/facing by default.
- [native_source_space.gd](/mnt/c/Users/tommaso/Documents/assets/VFXFactory/factory/core/native_source_space.gd) fixes old camera-half cuts and source-relative reveal/mask coordinates. That is separate artwork-port work, not a general shader rewrite needed by the screenshot helper.
- The generated Factory renderer snapshot is transitional. Copying it into production would create a renderer fork; Studio already owns the real implementation.
- The wider native artwork review is unfinished. Historical component-only recipes, actor-bound runtime effects and whole-spell assemblies need separate review. This handoff delivers the working **inspection tool**, not a claim that every asset has been tuned.

No production implementation or chat coordination was performed for this handoff.
