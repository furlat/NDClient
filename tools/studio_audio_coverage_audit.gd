extends SceneTree
## Current Library audiences and resolved shared components; never a playback claim.
const Library=preload("res://studio/case_library.gd")
const Recording=preload("res://studio/recording.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
    var output="res://generated/studio_audio_coverage.json"
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
    var paths={}
    for record in Library.read():
        for audience in record.perspectives:paths[audience.journal]=record.id
    var report={"scope":"Current Library audiences, disclosed event owners, resolved audio components, source files and authored timing. Native output is qualified separately.","recordings":[],"failures":[]}
    var native_path="res://generated/studio_audio_transport_checks.json"
    var native:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(native_path)) if FileAccess.file_exists(native_path) else {}
    var outcomes={}
    for played in native.get("evidence",[]):
        for pane in [{"path":played.recording,"diagnostics":played.diagnostics},{"path":played.get("peer_recording",""),"diagnostics":played.get("peer_diagnostics",{})}]:
            for id in pane.diagnostics.get("rows",{}):
                var key=str(pane.path)+":"+str(id)
                if not outcomes.has(key):outcomes[key]=[]
                var d:Dictionary=pane.diagnostics.rows[id]
                outcomes[key].append({"run":played.label,"starts":d.starts,"state":d.state,"reason":d.reason,"source_ready":d.source_ready,"enabled":d.enabled,"mixer_peak":played.peak,"pcm_capture":played.get("pcm_capture","")})
    report.native_evidence={"report":native_path,"checks":native.get("checks",0),"failures":native.get("failures",[]),"driver":native.get("audio_driver",""),"runtime_attachment_gaps":native.get("runtime_attachment_gaps",[]),"scope":"Saved native dispatch/skip diagnostics and aggregate SFX mix, keyed by the same resolved component IDs. No physical-speaker or per-cue mix attribution claim."}
    for path in paths:
        var index=Recording.read(path)
        if not index.ok:report.failures.append({"recording":path,"error":index.error});continue
        var facts={}
        for filename in DirAccess.get_files_at(path):
            if not filename.ends_with(".json"):continue
            var packet=JSON.parse_string(FileAccess.get_file_as_string(path.path_join(filename)))
            for lineage in packet.get("lineages",[]):
                for node in lineage.events:
                    if not node.canceled and node.get("fact")!=null:facts[node.uuid]=node.fact
        var entry={"case":paths[path],"recording":path,"components":[],"unassigned_events":[],"contact_tracks":[],"condition_assignments":[]}
        for item in index.groups:
            var group:Dictionary=item.group
            for event in group.events:
                var fact:Dictionary=facts.get(event.event_uuid,{})
                if fact.get("kind","") not in ["action","shove","attack","spell","equipment","condition","damage","life","object_damage","object_destroyed"]:continue
                if fact.kind=="damage" and (fact.get("stage")!="applied" or fact.get("applied_damage",0)<=0):continue
                if fact.kind=="object_damage" and (fact.applied_damage<=0 or fact.resulting_hp<=0):continue
                if fact.kind=="life" and not ((fact.previous_state=="alive" and fact.new_state in ["dying","dead"]) or (fact.new_state=="alive" and fact.previous_state in ["dying","stable"])):continue
                var sounds=group.components.filter(func(c):return c.kind=="audio" and c.source_event_uuid==event.event_uuid)
                if sounds.is_empty():entry.unassigned_events.append({"event_uuid":event.event_uuid,"kind":fact.kind,"behavior":fact.get("behavior_id",fact.get("condition",{}).get("behavior_id",fact.get("source_item_id",fact.get("item_id","")))),"phase":fact.get("event_type",""),"reason":"audio_assignment_not_authored"})
            for track in group.actor_tracks:
                if track.get("motion",false):entry.contact_tracks.append({"rig":track.rig,"clip":track.clip,"trajectory":track.trajectory,"event_uuid":track.source_event_uuid,"source_time_keys":track.get("source_time_keys",[])})
        for row in index.rows:
            if row.kind=="condition":
                var binding:Dictionary=index.cache["audio/bindings.json"].conditions.get(row.owner.condition.behavior_id,{})
                entry.condition_assignments.append({"condition_uuid":row.owner.id,"behavior":row.owner.condition.behavior_id,"initial":row.owner.initial,"visual_disposition":row.status,"audio_bindings":binding.duplicate(true)})
            if row.kind!="audio":continue
            var c:Dictionary=row.component
            entry.components.append({"id":c.id,"owner":c.get("source_event_uuid",""),"cue":c.cue_id,"status":c.status,"reason":c.get("reason",""),"clip":c.get("clip",""),"asset_present":FileAccess.file_exists(c.get("clip","")),"assignment":c.get("assignment_source",""),"timing":c.get("timing_source",""),"selector":c.get("timing_selector",""),"attachment":c.get("attachment",""),"attachment_source":c.get("attachment_source","rendered_actor"),"start_ms":row.start_ms,"contact_ms":row.get("group_start_ms",0)+c.get("contact_ms",c.start_ms),"source_sync_s":c.get("source_sync_s",0),"native_playback":outcomes.get(str(path)+":"+str(c.id),[])})
        report.recordings.append(entry)
    FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_AUDIO_COVERAGE ",JSON.stringify({"recordings":report.recordings.size(),"failures":report.failures,"report":output}))
    quit(0 if report.failures.is_empty() else 1)
