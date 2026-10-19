extends SceneTree
## Current server journals -> shared compiler/Studio timeline -> canonical publication.
const Recording=preload("res://studio/recording.gd")
const Timeline=preload("res://presentation/timeline.gd")
const Journal=preload("res://sdk/journal.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
var failures:Array=[]
var checks:int=0
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("FAIL ",label)
func run()->void:
    var directory:String=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--journal="):directory=arg.trim_prefix("--journal=")
    if directory.is_empty():print("Use --journal=<current-schema journal>");quit(1);return
    var index:Dictionary=Recording.read(directory)
    check(index.ok,"real server recording compiles")
    if not index.ok:print(index);quit(1);return
    var journal=Journal.new()
    var opened:Dictionary=journal.open(directory,false,true)
    check(opened.ok,"same received bytes fold independently")
    if not opened.ok:print(opened);quit(1);return
    var timeline=Timeline.new()
    var initial:Dictionary=index.initialization.duplicate()
    initial.state=initial.state.duplicate(true)
    timeline.accept(initial)
    var groups:Array=[]
    for item in index.groups:groups.append(item.group)
    timeline.accept({"kind":"operation","groups":groups})
    timeline.advance(float(index.duration_ms)+1000.0)
    check(not timeline.busy(),"timeline reaches real journal end")
    var issue:String=Compare.difference(timeline.state,journal.state)
    check(issue.is_empty(),"published canonical state equals the actual fold: "+issue)
    check(index.rows.size()>0,"Studio exposes actual operations")
    var spell_rows:Array=index.rows.filter(func(row):return row.kind=="event" and row.event.kind=="spell")
    if not spell_rows.is_empty():
        check(spell_rows.any(func(row):return not str(row.event.get("behavior_id","")).is_empty()),"cast/application rows resolve real declarations")
        check(index.groups.any(func(item):return not item.group.actor_tracks.is_empty()),"real body animation tracks compile")
    print(JSON.stringify({"checks":checks,"failures":failures,"operations":index.operations,"groups":index.groups.size(),"rows":index.rows.size(),"duration_ms":index.duration_ms}))
    quit(0 if failures.is_empty() else 1)
