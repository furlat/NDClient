extends SceneTree
## Current Library audiences and resolved shared components; never a playback claim.
const Library=preload("res://studio/case_library.gd")
const Recording=preload("res://studio/recording.gd")
const Catalog=preload("res://source_catalog.gd")
func _initialize()->void:run.call_deferred()

func _gap(component:Dictionary)->String:
    if not str(component.get("clip","")).is_empty() and not FileAccess.file_exists(component.clip):return "missing_file"
    if component.status!="missing":return ""
    var reason:String=component.get("reason","")
    if reason.begins_with("invalid_contact_") or reason in ["contact_id_not_authored","contact_direction_not_authored","contact_binding_not_authored","source_contact_markers_not_authored","authored_audio_timing_unavailable","source_sync_points_not_authored","invalid_source_sync_point","source_sync_requires_unavailable_preroll","loop_interval_not_resolved","ogg_loop_end_must_match_source_duration","loop_source_sync_not_supported"]:return "timing_defect"
    if not component.get("assignment_enabled",true) or not component.has("clip"):return "unassigned_cue"
    return "resolution_gap"

func _owner(event:Dictionary,node:Dictionary)->Dictionary:
    var fact:Dictionary=node.fact
    return {"event_id":event.id,"sequence":event.sequence,"occurrence":event.event_uuid,"lineage":event.lineage_uuid,
        "phase":node.phase,"kind":event.kind,"behavior":event.get("behavior_id",""),"source_item_id":fact.get("source_item_id"),
        "attack_source_kind":fact.get("attack_source_kind"),"damage_type":fact.get("damage_type"),"actor_uuid":event.get("actor_uuid"),"target_uuid":event.get("target_uuid")}

func _eligible(fact:Dictionary)->bool:
    if fact.kind not in ["action","shove","attack","spell","damage","life","object_damage","object_destroyed"]:return false
    if fact.kind=="damage":return fact.get("stage")=="applied" and fact.get("applied_damage",0)>0
    if fact.kind=="object_damage":return fact.applied_damage>0 and fact.resulting_hp>0
    if fact.kind=="life":return (fact.previous_state=="alive" and fact.new_state in ["dying","dead"]) or (fact.new_state=="alive" and fact.previous_state in ["dying","stable"])
    return true

func run()->void:
    var output="res://generated/studio_audio_coverage.json"
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
    var report={"scope":"Current Library audiences, disclosed occurrence/phase owners, resolved audio components, source files and authored timing. Unassigned events are inventory for authoring decisions, not a requirement to add a sound to every state change.",
        "cases":[],"recordings":[],"failures":[],"selected_cues":[],"acceptance":{"native_playback":"not_run_in_headless_audit","audible_mix":"not_assessed","human_approval":"not_assessed"}}
    var catalog:Dictionary=Catalog.read_file("audio/cues.json",{})
    report.missing_cues=catalog.get("missing_cues",{})
    for id in catalog.get("cues",{}):
        var cue:Dictionary=catalog.cues[id];var files:Array=[]
        for clip in cue.clips:files.append({"clip":clip,"asset_present":FileAccess.file_exists(clip)})
        report.selected_cues.append({"cue":id,"status":cue.get("status",""),"files":files,"source_sync_s":cue.get("source_sync_s",[]),"purpose":cue.get("purpose","")})
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
    report.native_evidence={"report":native_path,"checks":native.get("checks",0),"failures":native.get("failures",[]),"driver":native.get("audio_driver",""),"runtime_attachment_gaps":native.get("runtime_attachment_gaps",native.get("runtime_audio_gaps",[])),"current_package_match":"not_checked","scope":"Historical native dispatch/skip diagnostics and aggregate SFX mix joined by recording path and component ID only. This audit neither reruns native playback nor establishes current-package, physical-speaker or per-cue mix approval."}
    for record in Library.read():
        var case_row={"id":record.id,"status":record.status,"scenario_status":record.scenario_status,"ready":record.ready,"reason":record.get("reason",""),"errors":record.get("errors",[]),"declared_journals":record.get("journals",{}),"recordings":[]}
        report.cases.append(case_row)
        for audience in record.perspectives:
            var path:String=audience.journal;case_row.recordings.append(path)
            var index=Recording.read(path)
            if not index.ok:report.failures.append({"case":record.id,"recording":path,"error":index.error});continue
            var nodes={}
            for filename in DirAccess.get_files_at(path):
                if not filename.ends_with(".json") or not filename.get_basename().is_valid_int():continue
                var packet:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path.path_join(filename)))
                for lineage in packet.get("lineages",[]):
                    for node in lineage.events:
                        nodes["%d:%d"%[int(packet.cursor.sequence),int(node.occurrence)]]=node
            var bindings:Dictionary=Catalog.read_file("audio/bindings.json",index.cache)
            var entry={"case":record.id,"recording":path,"audience":audience.id,"scenario_status":record.scenario_status,"scope":"complete_recording" if record.ready else "available_prefix_of_unqualified_case","components":[],"event_assignments":[],"unassigned_events":[],"contact_tracks":[],"condition_assignments":[],"join_failures":[]}
            for row in index.rows:
                if row.kind!="condition":continue
                var owner:Dictionary=row.owner;var behavior:String=Catalog.condition_key(owner.condition)
                entry.condition_assignments.append({"condition_uuid":owner.id,"actor_uuid":owner.actor_uuid,"behavior":behavior,"initial":owner.initial,"parent":row.parent,"start_ms":row.start_ms,"end_ms":row.end_ms,"visual_disposition":row.status,"audio_bindings":bindings.conditions.get(behavior,{}).duplicate(true),"application_scope":"initial_membership_no_entry_sound" if owner.initial else "recorded_membership"})
            for item in index.groups:
                var group:Dictionary=item.group
                for event in group.events:
                    var node:Dictionary=nodes.get(event.id,{})
                    if node.is_empty() or node.phase!=event.phase:
                        entry.join_failures.append({"event_id":event.id,"phase":event.phase,"reason":"occurrence_phase_not_found"});continue
                    if node.get("canceled",false) or node.get("fact")==null:continue
                    var fact:Dictionary=node.fact
                    var sounds:Array=group.components.filter(func(c):return c.kind=="audio" and c.source_event_uuid==event.event_uuid)
                    if fact.kind=="actor_change":
                        for commit in group.commits:
                            if commit.get("event_uuid")!=event.event_uuid:continue
                            for change in commit.get("condition_rows",[]):
                                if change.row.field!="condition":continue
                                var member:Variant=change.after if change.after!=null else change.before
                                if member==null or (change.after!=null and change.before!=null):continue
                                var behavior:String=Catalog.condition_key(member)
                                var phase:String="application" if change.after!=null else "removal"
                                var assignment:String="audio/bindings.json:/conditions/"+behavior+"/"+phase
                                var owned:Array=sounds.filter(func(c):return c.get("assignment_source")==assignment)
                                var owner:Dictionary=_owner(event,node)
                                owner.merge({"kind":"condition","condition_uuid":member.condition_uuid,"actor_uuid":change.actor_uuid,"behavior":behavior,"condition_phase":phase,"assignment":assignment,"audio_components":owned.map(func(c):return c.id)},true)
                                entry.event_assignments.append(owner)
                                if owned.is_empty():entry.unassigned_events.append(owner.merged({"reason":"audio_assignment_not_authored"}))
                        if group.actor_tracks.any(func(track):return track.source_event_uuid==event.event_uuid and track.get("equipment_change",false)):
                            var owned:Array=sounds.filter(func(c):return c.get("assignment_source")=="audio/bindings.json:/equipment/change")
                            var owner:Dictionary=_owner(event,node)
                            owner.merge({"kind":"equipment","assignment":"audio/bindings.json:/equipment/change","audio_components":owned.map(func(c):return c.id)},true)
                            entry.event_assignments.append(owner)
                            if owned.is_empty():entry.unassigned_events.append(owner.merged({"reason":"audio_assignment_not_authored"}))
                    if not _eligible(fact):continue
                    var owner:Dictionary=_owner(event,node)
                    owner.audio_owner_occurrence=event.get("cast_owner_event",event.event_uuid)
                    owner.audio_components=sounds.map(func(c):return c.id)
                    entry.event_assignments.append(owner)
                    if sounds.is_empty() and owner.audio_owner_occurrence==event.event_uuid:entry.unassigned_events.append(owner.merged({"reason":"audio_assignment_not_authored"}))
                for track in group.actor_tracks:
                    if track.get("motion",false):entry.contact_tracks.append({"spatial_only":track.get("spatial_only",false),"rig":track.get("rig"),"clip":track.get("clip"),"trajectory":track.get("trajectory"),"sequence":group.operation_sequence,"occurrence":track.source_event_uuid,"source_time_keys":track.get("source_time_keys",[])})
            for row in index.rows:
                if row.kind!="audio":continue
                var c:Dictionary=row.component
                entry.components.append({"id":c.id,"row_id":row.id,"owner":row.parent,"occurrence":c.get("source_event_uuid",""),"condition_uuid":row.get("owner",{}).get("id",""),"cue":c.cue_id,"status":c.status,"reason":c.get("reason",""),"gap_category":_gap(c),"clip":c.get("clip",""),"asset_present":FileAccess.file_exists(c.clip) if c.has("clip") else null,"assignment":c.get("assignment_source",""),"assignment_enabled":c.get("assignment_enabled",true),"timing":c.get("timing_source",""),"selector":c.get("timing_selector",""),"timing_review":c.get("timing_review",c.get("contact_review","not_assessed")),"attachment":c.get("attachment",""),"attachment_source":c.get("attachment_source","rendered_actor"),"start_ms":row.start_ms,"contact_ms":row.get("group_start_ms",0)+c.get("contact_ms",c.start_ms),"source_sync_s":c.get("source_sync_s",0),"saved_native_playback":outcomes.get(str(path)+":"+str(c.id),[])})
            for failure in entry.join_failures:report.failures.append(failure.merged({"case":record.id,"recording":path}))
            report.recordings.append(entry)
        if report.cases.size()%20==0:print("STUDIO_AUDIO_PROGRESS cases=",report.cases.size()," recordings=",report.recordings.size())
    var counts={"cases":report.cases.size(),"ready_cases":0,"unqualified_cases":0,"cases_without_recordings":0,"recordings":report.recordings.size(),"components":0,"unassigned_events":0,"missing_file":0,"unassigned_cue":0,"timing_defect":0,"resolution_gap":0,"audit_failures":report.failures.size()}
    for row in report.cases:
        counts["ready_cases" if row.ready else "unqualified_cases"]+=1
        if row.recordings.is_empty():counts.cases_without_recordings+=1
    for entry in report.recordings:
        counts.components+=entry.components.size();counts.unassigned_events+=entry.unassigned_events.size()
        for component in entry.components:
            if not component.gap_category.is_empty():counts[component.gap_category]+=1
    report.counts=counts
    FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_AUDIO_COVERAGE ",JSON.stringify({"counts":counts,"report":output}))
    quit(0 if report.failures.is_empty() else 1)
