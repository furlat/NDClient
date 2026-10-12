extends SceneTree
# Isolate the actual bounded Gallery replay's scene-thread timeline work.
# No media/renderer callback: this cannot measure GPU release or source planning.
const Session = preload("res://presentation/session.gd")
const Timeline = preload("res://presentation/timeline.gd")
var samples: Array = []
func _initialize() -> void: run.call_deferred()
func run() -> void:
    var session = Session.new()
    var timeline = Timeline.new()
    var worker_retirement = "--worker-retirement" in OS.get_cmdline_user_args()
    if worker_retirement: timeline.retire_group=session.retire_group
    var opened = session.open_recording("res://.runtime/gallery-route/journal")
    if not opened.ok: print(opened); quit(1); return
    var deadline = Time.get_ticks_msec()+120000
    while (not session.terminal or timeline.sequence<session.latest_sequence) and session.issue.is_empty() and Time.get_ticks_msec()<deadline:
        session.poll()
        var messages: Array = session.take_prepared()
        if not messages.is_empty():
            var before = timeline.sequence
            var started = Time.get_ticks_usec()
            for index in range(messages.size()): timeline.accept(messages[index])
            var admitted_us = Time.get_ticks_usec()-started
            var count = messages.size()
            # Keep no extra test-owned group reference after queue admission.
            messages.clear()
            var groups = timeline.queue.size()
            started = Time.get_ticks_usec()
            timeline.advance(1000000)
            samples.append({"before":before,"after":timeline.sequence,"messages":count,"groups":groups,
                "accept_ms":admitted_us/1000.0,"advance_ms":(Time.get_ticks_usec()-started)/1000.0,
                "trace_rows":timeline.trace.rows.size(),"tiles":timeline.state.tiles.size(),"objects":timeline.state.objects.size()})
        session.set_displayed_sequence(timeline.sequence)
        await process_frame
    var report = {"scope":"Actual Gallery bounded replay timeline CPU, excluding media gate, renderer, GPU cleanup and source preparation.",
        "complete":session.terminal and timeline.sequence==session.latest_sequence,"canonical_equal":timeline.state==session.journal.state,
        "issue":session.issue,"sequence":timeline.sequence,"groups":timeline.completed_group_count,"samples":samples}
    session.close()
    report.worker_retirement=worker_retirement
    report.execution=session.diagnostics()
    FileAccess.open("res://generated/gallery_timeline_cpu"+("_worker" if worker_retirement else "_inline")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("GALLERY_TIMELINE_CPU ",JSON.stringify({"complete":report.complete,"canonical_equal":report.canonical_equal,"issue":report.issue,"samples":samples.size()}))
    quit(0 if report.complete and report.canonical_equal and report.issue.is_empty() else 1)
