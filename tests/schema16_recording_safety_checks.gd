extends SceneTree
## Headless dispatch/state safety over the current recorded spell inventory.
## No pixel, audio-output, native warmup or live-input qualification is claimed.
const Library=preload("res://studio/case_library.gd")
const Recording=preload("res://studio/recording.gd")
const Journal=preload("res://sdk/journal.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const REPORT="res://.runtime/schema16-recording-safety.json"
var checks:int=0
var failures:Array=[]

func _initialize()->void:run.call_deferred()

func check(value:bool,label:String,local:Array)->void:
    checks+=1
    if not value:local.append(label);failures.append(label);print("SCHEMA16_RECORDING_FAIL ",label)

static func boundaries(index:Dictionary)->Array:
    var times:Dictionary={0.0:true}
    var end:float=maxf(float(index.duration_ms),float(index.presentation_end_ms))
    for row in index.rows:
        if row.kind in ["body","condition","condition_exit","condition_restore","condition_state"]:
            for at in [float(row.start_ms),float(row.end_ms)]:
                if is_finite(at) and at>=0.0 and at<=end:
                    times[maxf(0.0,at-.001)]=true;times[at]=true;times[minf(end,at+.001)]=true
        for marker in row.get("markers",[]):
            if marker.kind not in ["contact","commit","restored"]:continue
            var at:float=float(marker.at_ms)
            if is_finite(at) and at>=0.0 and at<=end:
                times[maxf(0.0,at-.001)]=true;times[at]=true;times[minf(end,at+.001)]=true
    times[end+1.0]=true
    var result:Array=times.keys();result.sort();return result

func inspect_journal(identity:String,faction:String,directory:String)->Dictionary:
    var started:int=Time.get_ticks_usec()
    var label:String=identity+" / "+faction
    var local:Array=[]
    print("SCHEMA16_RECORDING_START ",label," ",directory)
    var result={"faction":faction,"journal":directory,"status":"failed","failures":local,"rendered":"not_examined_headless"}
    var value:Variant=Recording.read(directory)
    check(value is Dictionary and value.get("ok",false),label+" Recording.read admits and compiles the real journal",local)
    if not value is Dictionary or not value.get("ok",false):
        result.error=str(value);return result
    var index:Dictionary=value
    var initial:Dictionary=index.initialization.state.duplicate(true)
    var journal=Journal.new()
    var opened:Dictionary=journal.open(directory,false,true)
    check(opened.ok,label+" independent Journal replay admits the same original bytes",local)
    if not opened.ok:result.error=str(opened.get("error",opened));return result
    var end:float=maxf(float(index.duration_ms),float(index.presentation_end_ms))+1.0
    var samples:Array=boundaries(index)
    var cached:RefCounted
    var cached_state:Dictionary={}
    var cached_at:float=0.0
    var body_samples:int=0;var component_samples:int=0
    for at in samples:
        var restored:Variant=Recording.restore(index,float(at))
        check(restored!=null,label+" restores at "+str(at)+" ms",local)
        if restored==null:continue
        var poses:Variant=restored.actor_samples()
        var components:Variant=restored.component_samples(index.cache)
        check(poses is Dictionary and components is Array,label+" samples body/effect state at "+str(at)+" ms",local)
        body_samples+=poses.size() if poses is Dictionary else 0
        component_samples+=components.size() if components is Array else 0
        if cached==null and float(at)>0.0 and float(at)<end:
            cached=restored;cached_at=float(at);cached_state=restored.state.duplicate(true)
        if float(at)==end:
            check(not restored.busy(),label+" reaches the actual presentation endpoint",local)
            var issue:String=Compare.difference(restored.state,journal.state)
            check(issue.is_empty(),label+" published end equals independent canonical fold: "+issue,local)
    check(index.initialization.state==initial,label+" repeated restoration does not mutate cached initialization",local)
    if cached!=null:
        check(cached.state==cached_state,label+" later seeks/samples do not mutate the earlier retained state",local)
        var repeated:Variant=Recording.restore(index,cached_at)
        check(repeated!=null and repeated.state==cached_state,label+" backward/repeated seek restores the same canonical prefix",local)
    result.status="passed" if local.is_empty() else "failed"
    result.operations=index.operations;result.groups=index.groups.size();result.rows=index.rows.size()
    result.boundaries=samples.size();result.body_samples=body_samples;result.component_samples=component_samples
    result.elapsed_ms=float(Time.get_ticks_usec()-started)/1000.0
    print("SCHEMA16_RECORDING_RESULT ",identity," ",JSON.stringify(result))
    return result

func run()->void:
    var started:int=Time.get_ticks_usec()
    var snapshot:Dictionary=Library._read(Library.SERVER_IDS)
    var index:Dictionary=Library._read(Library.INDEX)
    var baseline:Dictionary={}
    for record in Library.records(index,snapshot):
        if record.get("kind")=="spell" and str(record.id).ends_with("/baseline"):baseline[str(record.id).trim_suffix("/baseline")]=record
    var identities:Array=snapshot.get("ids",{}).get("spell",{}).keys();identities.sort()
    var missing:Array=[];var unavailable:Array=[];var passed:Array=[];var tested_failures:Array=[];var rows:Array=[]
    var inventory_failures:Array=[]
    check(not identities.is_empty(),"Frozen official spell inventory is present",inventory_failures)
    for identity in identities:
        var record:Dictionary=baseline.get(identity,{})
        var result={"id":identity,"case_id":str(identity)+"/baseline","status":"missing_baseline","factions":[],"failures":[]}
        if record.is_empty():
            missing.append(identity);result.reason="No current baseline entry"
            check(false,str(identity)+" has a current legal baseline",result.failures)
        elif not record.get("ready",false):
            result.status="baseline_unavailable";result.scenario_status=record.scenario_status
            result.reason=record.get("reason","");result.recording_errors=record.get("errors",[])
            unavailable.append(identity)
            check(false,str(identity)+" baseline is ready: "+str(record.scenario_status)+" "+str(result.reason),result.failures)
        else:
            var perspectives:Dictionary={}
            for perspective in record.perspectives:perspectives[perspective.id]=perspective.journal
            for faction in ["amber","blue"]:
                if not perspectives.has(faction):
                    check(false,str(identity)+" original "+faction+" journal is present",result.failures);continue
                var inspected:Variant=inspect_journal(str(identity),faction,perspectives[faction])
                if inspected is Dictionary:
                    result.factions.append(inspected)
                    if inspected.status!="passed":result.failures.append_array(inspected.failures)
                else:check(false,str(identity)+" / "+faction+" inspection aborted; inspect script-error log",result.failures)
            result.status="passed" if result.failures.is_empty() and result.factions.size()==2 else "failed"
            if result.status=="passed":passed.append(identity)
            else:tested_failures.append(identity)
        rows.append(result)
        # Persist completed rows so a later reader crash does not erase the
        # exact last examined ID or previously completed inventory results.
        var report={"scope":"headless_current_recordings_only","engine":index.get("engine",{}),"expected_engine":snapshot.get("header",{}),
            "inventory":identities.size(),"index_cases_at_start":index.get("cases",[]).size(),"checks":checks,"failures":failures,
            "passed":passed,"missing_baseline":missing,"unavailable_baseline":unavailable,"tested_failures":tested_failures,"spells":rows,
            "complete":rows.size()==identities.size(),"elapsed_ms":float(Time.get_ticks_usec()-started)/1000.0,
            "qualifies":"Original faction journals, production compiler, boundary restore/sample, canonical endpoint and immutable earlier state",
            "does_not_qualify":"Native pixels, shader/resource preparation, audible playback, Studio UI or actual live player gestures; script-error log must also be clean"}
        FileAccess.open(REPORT,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
        print("SCHEMA16_RECORDING_SPELL ",JSON.stringify({"id":identity,"status":result.status,"factions":result.factions.size()}))
    print("SCHEMA16_RECORDING_SAFETY ",JSON.stringify({"checks":checks,"failures":failures.size(),"inventory":identities.size(),"passed":passed.size(),"missing_baseline":missing.size(),"unavailable_baseline":unavailable.size(),"tested_failures":tested_failures.size(),"report":REPORT}))
    quit(0 if failures.is_empty() else 1)
