extends SceneTree
## Usage: --recording=<journal> [--behavior=action.hide] [--require-body] [--output=<json>]
const Recording=preload("res://studio/recording.gd")
const Report=preload("res://studio/capability_report.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
    var directory="";var behavior="";var output="";var require_body=false
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--recording="):directory=argument.trim_prefix("--recording=")
        elif argument.begins_with("--behavior="):behavior=argument.trim_prefix("--behavior=")
        elif argument.begins_with("--output="):output=argument.trim_prefix("--output=")
        elif argument=="--require-body":require_body=true
        else:printerr("Unknown argument: "+argument);quit(2);return
    if directory.is_empty():
        printerr("Usage: --recording=<real SDK journal> [--behavior=action.hide] [--require-body] [--output=<json>]");quit(2);return
    var index=Recording.read(directory)
    if not index.ok:printerr("Recording rejected: "+str(index.get("error","unknown")));quit(2);return
    var report=Report.build(index,behavior,require_body)
    report.command={"script":"res://tools/studio_capability_report.gd","arguments":Array(OS.get_cmdline_user_args())}
    var serialized=JSON.stringify(report,"  ")
    if not output.is_empty():
        var file=FileAccess.open(output,FileAccess.WRITE)
        if file==null:printerr("Cannot write report: "+output);quit(2);return
        file.store_string(serialized)
        print("STUDIO_CAPABILITY ",JSON.stringify({"passed":report.passed,"counts":report.counts,"failures":report.failures,"output":output}))
    else:print(serialized)
    quit(0 if report.passed else 1)
