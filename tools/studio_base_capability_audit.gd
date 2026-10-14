extends SceneTree
const Recording=preload("res://studio/recording.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
    var inventory=JSON.parse_string(FileAccess.get_file_as_string("res://generated/studio_case_inventory.json"))
    var report={"scope":"Current compiled real-case requirement audit; not rendered/audio acceptance.","cases":[],"failures":[]}
    for source in inventory.cases:
        var index=Recording.read(source.journal)
        if not index.ok:report.failures.append({"case":source.name,"error":index});continue
        var result={"case":source.name,"operations":index.operations,"duration_ms":index.duration_ms,"presentation_end_ms":index.presentation_end_ms,"missing":[],"actions":[]}
        for row in index.rows:
            if row.get("status")=="missing":result.missing.append({"kind":row.kind,"label":row.label,"source":row.get("source",""),"reason":row.get("reason",row.get("requirement",{}).get("reason",""))})
            if row.kind=="event" and str(row.event.get("behavior_id","")).begins_with("action."):
                result.actions.append({"behavior":row.event.behavior_id,"event_uuid":row.event.event_uuid,"bodies":index.rows.filter(func(x):return x.kind=="body" and x.track.get("source_event_uuid")==row.event.event_uuid).map(func(x):return x.track.clip)})
        report.cases.append(result)
        print("BASE_AUDIT ",source.name," gaps ",result.missing.size())
    FileAccess.open("res://generated/studio_base_capability_audit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    quit(0 if report.failures.is_empty() else 1)
