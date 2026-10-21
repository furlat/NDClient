extends "res://tests/media_latency_checks.gd"
## Replay an explicit original server operation, then exercise its real required-worker fallback.
const Journal = preload("res://sdk/journal.gd")

func run() -> void:
    var directory = ""
    var sequence = -1
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--journal="): directory = arg.trim_prefix("--journal=")
        if arg.begins_with("--sequence="): sequence = int(arg.trim_prefix("--sequence="))
    check(not directory.is_empty() and sequence>0,"Explicit saved live journal and operation sequence supplied")
    if not failures.is_empty(): finish_recorded(); return
    var journal = Journal.new()
    var opened = journal.open(directory,true,false)
    check(opened.ok,"Saved live journal opens read-only for replay")
    if not opened.ok: finish_recorded(); return
    var replayed = journal.replay(sequence-1)
    check(replayed.ok,"Original reducer reaches the boundary before the recorded operation")
    if not replayed.ok: finish_recorded(); return
    var before: Dictionary = journal.state
    var raw = FileAccess.get_file_as_bytes(directory.path_join("%016d.json" % sequence))
    var decoded = journal.protocol.decode("PlayerOperation",raw)
    check(decoded.ok,"Original recorded server packet validates")
    if not decoded.ok: finish_recorded(); return
    var admitted = journal._consume_admitted(decoded.value,raw,true)
    check(admitted.ok,"Original reducer admits the recorded operation")
    if not admitted.ok: finish_recorded(); return
    var compiled = Compiler.compile_recorded(before,admitted.normalized,{},journal.state,admitted.transitions)
    check(compiled.ok,"Actual recorded operation compiles")
    if not compiled.ok: finish_recorded(); return
    var groups: Array = compiled.value.groups
    check(not groups.is_empty(),"Actual operation contains presentation groups")
    var player = Player.new()
    player.timeline.accept({"kind":"initialization","sequence":sequence-1,"state":before})
    player.timeline.paused = true
    for index in groups.size():
        player.timeline.current = groups[index]
        player.timeline.queue = groups.slice(index+1)
        player._prepare_media()
        while not player.media_metadata_ready and player.media_warmup.plan_thread!=null:
            var result = await poll_plan(player.media_warmup)
            check(not result.has("error") and result.get("complete",false),"Recorded group %d worker publishes a successful result" % index)
            player._adopt_media_plan(result)
            player._prepare_media()
        check(player.media_metadata_ready and player.media_issue.is_empty() and player.media_plan.errors.is_empty(),
            "Recorded group %d is no longer blocked by a false metadata error" % index)
        check(player.timeline.current==groups[index] and player.timeline.sequence==sequence-1,
            "Preparing recorded group %d does not advance the displayed cursor" % index)
        for commit in groups[index].commits: Compiler.apply_delta(player.timeline.state,commit.delta)
    var exact_message = "Authored media metadata preparation did not complete; inspect the source error log."
    var report = player.error_report(exact_message)
    check(report.message==exact_message and report.displayed_sequence==sequence-1 and report.kind=="ndclient_error",
        "Error report preserves the exact displayed message and playback boundary")
    evidence = {"journal":directory,"sequence":sequence,"groups":groups.size()}
    dispose(player)
    finish_recorded()

func finish_recorded() -> void:
    var report = {"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Original live server journal/reducer/compiler and asynchronous required media metadata; no GPU readiness or live reconnect claim."}
    FileAccess.open("res://generated/recorded_media_completion_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("RECORDED_MEDIA_COMPLETION_CHECKS ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
