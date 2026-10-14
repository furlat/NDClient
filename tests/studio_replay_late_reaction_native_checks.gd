extends "res://tests/studio_replay_native_checks.gd"
## Unequal native Rolling durations must share the real reaction/landing cut.
func run()->void:
    report_path="res://generated/studio_replay_late_reaction_native_checks.json"
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1600,900)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.captures/studio/replay-comparison"))
    var studio=Studio.new();root.add_child(studio);studio.loop_enabled=false
    if not await settle(studio):await finish(studio);return
    check(studio.active_directory=="res://.runtime/studio-cases/oa_jump_late_lethal-seed5-v2/amber/journal","Exact late lethal reaction recording loaded")
    check(not studio.peer.is_empty(),"Late lethal recording admits both original native body clocks")
    if studio.peer.is_empty():await finish(studio);return
    verify_prefix(studio,"late lethal initial")
    await play_once(studio,"oa_jump_late_lethal-seed5-v2")
    await save_capture(studio,"late-lethal-end")
    for fraction in [.8,.2,.8]:
        studio._seek(studio.index.presentation_end_ms*fraction)
        if not await settle(studio):break
        verify_prefix(studio,"late lethal reverse seek "+str(fraction))
    await finish(studio)
