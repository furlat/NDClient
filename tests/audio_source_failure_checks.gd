extends SceneTree
## Named failed-source unit controls enter the real presenter. No server
## outcome, gameplay fixture, substitute sound or audible-mix claim is made.
const Presenter=preload("res://presentation/audio_presenter.gd")
const Cues=preload("res://presentation/audio_cues.gd")
const MISSING="res://tests/fixtures/audio-source-failure-not-authored.wav"
const UNSUPPORTED="res://presentation/audio_presenter.gd"
var checks:int=0
var failures:Array=[]

func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("AUDIO_SOURCE_FAILURE_FAIL ",label)

func _initialize()->void:run.call_deferred()

func failed_row(id:String,path:String)->Dictionary:
    return {"id":id,"kind":"audio","status":"available","cue_id":"unit-failed-source",
        "clip":path,"loop":false,"attachment":"ui","bus":"Master","gain_db":-18.0,
        "absolute_start_ms":100.0,"duration_ms":1000.0,"clip_duration_s":1.0}

func failed_sources()->void:
    check(not FileAccess.file_exists(MISSING),"Missing-source control is actually absent")
    check(FileAccess.file_exists(UNSUPPORTED),"Unsupported-format control is an actual existing non-audio source")
    var rows:Array=[failed_row("missing-a",MISSING),failed_row("missing-b",MISSING),failed_row("unsupported",UNSUPPORTED)]
    var original:PackedByteArray=var_to_bytes(rows)
    var presenter:RefCounted=Presenter.new()
    var host:=Node3D.new();root.add_child(host)
    presenter.prepare(rows,host)
    check(presenter.preparation_counts.loads==2,"Distinct failed sources own one read each; two cue owners share the same source")
    check(not presenter.ready(rows),"Starting failed-source preparation cannot claim readiness")
    var deadline:int=Time.get_ticks_msec()+10000
    # One shared read may finish between two cue owners in the same prepare.
    # Await each public terminal outcome, not the source task's internal token.
    while rows.any(func(row):return presenter.diagnostics(row.id).rows.get(row.id,{}).get("state")!="missing") and Time.get_ticks_msec()<deadline:
        await process_frame
        presenter.prepare(rows,host)
    check(presenter.loads.size()==2 and presenter.loads.values().all(func(job):return job.task==-1),"Completed failures retain results after consuming each pool ID exactly once")
    var expected:Array=["Missing audio source: "+MISSING,"Unsupported audio source: "+UNSUPPORTED]
    check(presenter.errors.size()==2 and expected.all(func(message):return message in presenter.errors),"Both actual failure reasons remain explicit and unique")
    var retained:Array=presenter.loads.values()
    for row in rows:
        check(not presenter.ready([row]) and not presenter.streams.has(presenter._key(row)),row.id+": failed source remains non-ready without a stream")
        var outcome:Dictionary=presenter.diagnostics(row.id).rows.get(row.id,{})
        check(outcome.get("state")=="missing" and not outcome.get("source_ready",true),row.id+": diagnostic records a failed source rather than readiness")
    for i in 24:
        var errors:Array=presenter.prepare(rows,host)
        check(errors.size()==2 and expected.all(func(message):return message in errors),"Repeated prepare preserves exact terminal errors "+str(i))
        await process_frame
    check(presenter.preparation_counts.loads==2 and presenter.loads.values()==retained,"Repeated preparation neither retries the source nor replaces its failed result")
    presenter.sample(host,[],99.0,1.0,false,1)
    presenter.sample(host,rows,101.0,1.0,false,1)
    check(presenter.late.is_empty() and presenter.voices.is_empty() and presenter.prepared_voices.is_empty(),"Failed crossed cues never become awaiting-stream retries or native voices")
    for row in rows:
        var outcome:Dictionary=presenter.diagnostics(row.id).rows.get(row.id,{})
        check(outcome.get("state")=="missing" and outcome.get("reason") in expected and outcome.get("starts",-1)==0,row.id+": final sampling keeps the exact missing reason and zero play dispatches")
    check(presenter.counters.started==0 and host.get_child_count()==0,"Source failure cannot create or start a native voice")
    check(var_to_bytes(rows)==original,"Failure handling preserves its admitted component operands")
    presenter.close();presenter.close()
    check(presenter.loads.is_empty() and presenter.streams.is_empty() and presenter.prepared_voices.is_empty(),"Repeated close releases terminal failures without joining consumed IDs")
    check(retained.all(func(job):return job.task==-1 and job.result.has("error")),"Detached failed results retain no live task token")
    host.free()

func active_close()->void:
    var presenter:RefCounted=Presenter.new()
    var row:Dictionary=failed_row("close-before-poll",MISSING)
    presenter.prepare([row])
    var job:Dictionary=presenter.loads[presenter._key(row)]
    check(job.task>=0,"Unpolled source retains its original owned task")
    presenter.close();presenter.close()
    check(job.task==-1 and job.result.get("error")=="Missing audio source: "+MISSING,"Close joins an unpolled read once before releasing its result owner")
    check(presenter.loads.is_empty() and presenter.voices.is_empty(),"Active close releases all source/voice ownership")

func authored_source()->void:
    var presenter:RefCounted=Presenter.new()
    var host:=Node3D.new();root.add_child(host)
    var row:Dictionary=Cues.resolve("footstep","actual-authored-source",0,100.0,-1.0,{"world_position":Vector3.ZERO})
    row.absolute_start_ms=row.start_ms
    check(row.status=="available" and FileAccess.file_exists(row.clip),"Positive control uses an unchanged actual authored footstep source")
    var original:PackedByteArray=var_to_bytes(row)
    var deadline:int=Time.get_ticks_msec()+10000
    while not presenter.ready([row]) and Time.get_ticks_msec()<deadline:
        presenter.prepare([row],host)
        await process_frame
    check(presenter.ready([row]) and presenter.errors.is_empty(),"Normal authored source preparation stays ready and error-free")
    check(presenter.preparation_counts.loads==1 and presenter.preparation_counts.voices==1 and presenter.loads.is_empty(),"Successful preparation consumes its task and creates one quiet voice")
    var voice:Node=presenter.prepared_voices.get(row.id)
    check(voice!=null and not voice.playing,"Successful preparation does not dispatch playback")
    for i in 8:presenter.prepare([row],host)
    check(presenter.preparation_counts.loads==1 and presenter.prepared_voices.get(row.id)==voice,"Repeated successful preparation retains the same source and quiet voice")
    check(var_to_bytes(row)==original,"Positive preparation preserves authored source/timing operands")
    presenter.close();presenter.close()
    check(host.get_child_count()==0 and not is_instance_valid(voice),"Repeated close frees the successful quiet voice once")
    host.free()

func run()->void:
    await failed_sources()
    active_close()
    await authored_source()
    var report:Dictionary={"checks":checks,"failures":failures,
        "scope":"Actual failed/unsupported source tasks through repeated preparation, sampling and close, plus unchanged authored source admission; no native mix or gameplay outcome qualification."}
    print("AUDIO_SOURCE_FAILURE ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
