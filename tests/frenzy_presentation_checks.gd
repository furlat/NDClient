extends SceneTree
const Recording=preload("res://studio/recording.gd")
var checks=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("FRENZY_PRESENTATION_FAIL ",label)
func run()->void:
    var directory=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="):directory=arg.trim_prefix("--recording=")
    if directory.is_empty():print("Use --recording=<actual Frenzy journal>");quit(2);return
    var index=Recording.read(directory)
    check(index.ok,"Actual Frenzy journal compiles")
    if not index.ok:finish({});return
    var sources=Recording.Compiler.Authoring.load_data("native_effects/index.json",index.cache).sources
    var record:Dictionary=sources["class.frenzy.ground"]
    check(record.script==sources["class.rage.ground"].script and record.properties.kind=="ground" and record.duration==2 and record.loop,"Exact previously installed native ground source and original64/32s clock")
    check(record.palette.colors==["#78262b","#da393f","#f07b68"],"Original Frenzy conversion palette, distinct from Rage")
    check(FileAccess.file_exists(record.script),"Selected native source file actually installed")
    var found=0
    for item in index.groups:
        for event in item.group.events:
            if event.get("behavior_id")!="action.class.barbarian.frenzy":continue
            var components=item.group.components.filter(func(row):return row.source_event_uuid==event.event_uuid and row.get("source_id")=="class.frenzy.ground")
            check(components.size()==1,"One original Frenzy occurrence owns one ground source")
            for component in components:
                found+=1
                check(is_equal_approx(component.start_ms,event._start_ms+100) and component.duration_ms==950,"Original action media100ms start and950ms lifetime")
                check(component.attachment=="source_ground" and component.scale==.5 and component.alpha==.6,"Original ground registration, scale and alpha")
                check(component.fade_in_ms==180 and component.fade_out_ms==350 and component.fade_curve=="smoothstep","Original finite fades")
                check(component.loop and component.source_duration_ms==2000,"Occurrence clock samples exact original looping source")
            check(not event.components.any(func(row):return row.status=="missing"),"Actual compiled source satisfies all selected Frenzy occurrence requirements")
    check(found>0,"Actual recording exercises selected Frenzy source")
    finish({"recording":directory,"source":record})
func finish(evidence:Dictionary)->void:
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Recorded Frenzy occurrence and exact installed native source/palette/clock registration. Native rendering remains separate."}
    FileAccess.open("res://generated/frenzy_presentation_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("FRENZY_PRESENTATION ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
