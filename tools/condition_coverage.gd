extends SceneTree
const Coverage=preload("res://presentation/condition_coverage.gd")
const Recording=preload("res://studio/recording.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
    var cache={};var rows:Array=[];var recordings:Array=[]
    var output="res://generated/condition_coverage.json"
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
        elif argument.begins_with("--recording="):
            var path=argument.trim_prefix("--recording=")
            var index=Recording.read(path)
            if not index.get("ok",false):push_error(str(index.get("error","Recording rejected")));quit(1);return
            cache=index.cache;recordings.append(path)
            for source in index.rows:
                var row:Dictionary=source.duplicate();row.recording=path;rows.append(row)
    var report=Coverage.build(cache,rows)
    report.recordings=recordings
    report.invocation={"script":"res://tools/condition_coverage.gd","arguments":Array(OS.get_cmdline_user_args())}
    FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("CONDITION_COVERAGE ",JSON.stringify(report.totals));quit()
