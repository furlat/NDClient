extends "res://tests/schema16_recording_safety_checks.gd"
## The same production compiler/seek/canonical checks for capability studies.
## This explicit cohort gate requires its real recorder output, not a fallback.
func run()->void:
    var path:String=""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--index="):path=argument.trim_prefix("--index=")
    var local:Array=[]
    check(not path.is_empty() and FileAccess.file_exists(path),"Supply --index=<actual recorder index>",local)
    if not local.is_empty():quit(1);return
    var index:Dictionary=Library._read(path)
    var recorded:Array=index.cases.filter(func(row):return row.status=="recorded")
    var excluded:Array=index.cases.filter(func(row):return row.status!="recorded").map(func(row):return {"id":row.id,"reason":row.reason})
    var rows:Array=[];var journals:int=0
    for record in recorded:
        var result:Dictionary={"id":record.id,"factions":[]}
        for seat in record.journals:
            var inspected:Dictionary=inspect_journal(str(record.id),str(seat),str(record.journals[seat]))
            result.factions.append(inspected);journals+=1
        rows.append(result)
    var report:Dictionary={"checks":checks,"failures":failures,"studies":recorded.size(),"journals":journals,"rows":rows,"excluded_failed_recipes":excluded,
        "scope":"Only original successfully recorded studies: production compile, boundary seeks/samples and immutable canonical endpoints. Failed recipes remain excluded explicit gaps; this does not qualify native output or visual approval."}
    FileAccess.open("res://.runtime/schema16-scenario-recording-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SCHEMA16_SCENARIO_RECORDING ",JSON.stringify({"checks":checks,"failures":failures.size(),"studies":recorded.size(),"journals":journals,"failed_recipes_excluded":excluded.size()}))
    quit(0 if failures.is_empty() else 1)
