extends RefCounted
## Read-only, occurrence-scoped implementation receipts from the production index.
const Catalog=preload("res://source_catalog.gd")
const Characters=preload("res://presentation/characters.gd")
const Effects=preload("res://presentation/effect_package.gd")
const EventTrace=preload("res://presentation/event_trace.gd")

## Saved projection only. Dynamic optical inputs and rendered pixels require
## separate current renderer diagnostics and output evidence respectively.
static func native_method(component:Dictionary,cache:Dictionary={})->Dictionary:
    if not component.get("native_spell",false) and component.get("kind")=="native_effect":return EventTrace.render_method(component,cache)
    var clip:Dictionary=Effects.occurrence_clip(component) if not component.get("native_clip",{}).is_empty() else {}
    var cue:Dictionary=component.get("native_cue",{})
    var selected:Dictionary=Effects.choice(clip) if not clip.is_empty() else {}
    var approaches:Array=selected.get("approaches",[])
    var approach:Dictionary=approaches[0] if not approaches.is_empty() else {}
    var projected:Array=component.get("native_inputs",{}).keys();projected.sort()
    var authored:Dictionary=cue.duplicate(true)
    # The cue already is the compiler's plain, source-authored schema. Keep
    # it intact so source windows, spatial/gear selectors and future typed
    # staging fields do not vanish behind a second inspection whitelist.
    authored.source=str(cue.get("source",component.get("source","")))
    return {"renderer":"res://presentation/native_spell_renderer.gd","clip_id":clip.get("id",""),
        "source_kind":clip.get("source_kind","indexed_clip"),"source_phase":clip.get("source_phase",""),
        "authoring":authored,"constructor":cue.get("constructor_input",{}).duplicate(true),
        "constructor_evidence":component.get("native_constructor_evidence",{}).duplicate(true),
        "destination_admission":component.get("native_destination",{}).duplicate(true),
        "required_channels":clip.get("inputs",[]).duplicate(),"input_setters":clip.get("input_setters",{}).duplicate(),
        "projected_channels":projected,"runtime_binding":"not_examined",
        "lifecycle_opt_in":{"table":component.get("recipe",{}).get("persistent",{}).get("lifecycleOptInSource",""),
            "selection":component.get("lifecycle_key",""),"event_gate":component.get("native_readiness_gate",{}).duplicate(true)},
        "constructor_gaps":component.get("unbound_constructor_inputs",cue.get("unbound_constructor_inputs",[])).duplicate(),
        "input_gaps":component.get("native_input_gaps",[]).duplicate(),
        "approach":{"id":approach.get("id",""),"kind":selected.get("kind",""),
            "path":approach.get("path",""),"source_phase":approach.get("source_phase",""),"reason":selected.get("reason","")}}

static func _under(row:Dictionary,ancestor:String,by_id:Dictionary)->bool:
    var id:String=row.id
    var visited={}
    while not id.is_empty() and by_id.has(id) and not visited.has(id):
        if id==ancestor:return true
        visited[id]=true;id=by_id[id].get("parent","")
    return false

static func _row(row:Dictionary,cache:Dictionary={})->Dictionary:
    var component:Dictionary=row.get("component",{})
    var value={"id":row.id,"parent_id":row.get("parent",""),"kind":row.kind,"label":row.get("label",""),
        "start_ms":row.start_ms,"end_ms":row.end_ms,"status":row.get("status",""),
        "source":row.get("source",""),"legacy_source":row.get("legacy_source",row.get("component",{}).get("legacy_source","")),
        "source_event_uuid":row.get("source_event_uuid",row.get("track",component).get("source_event_uuid","")),
        "reason":row.get("reason",component.get("reason","")),
        "markers":row.get("markers",[]).duplicate(true),"rendered":"not_witnessed"}
    if row.has("timing_status"):
        value.timing={"status":row.timing_status,"reason":row.get("timing_reason","")}
    else:value.timing={"status":"compiled"}
    if row.has("coverage"):value.coverage=row.coverage.duplicate(true)
    if row.has("preview_scope"):
        value.preview={"scope":row.preview_scope,"status":row.get("preview_status","not_examined"),
            "reason":row.get("preview_reason",""),"lighting_scope":row.get("preview_lighting_scope","")}
    if row.has("source_fields"):value.source_fields=row.source_fields.duplicate()
    if row.has("render_method"):value.render_method=row.render_method.duplicate(true)
    if component.get("native_spell",false) or component.get("kind")=="native_effect":value.native_method=native_method(component,cache)
    return value

static func _gap(row:Dictionary,cache:Dictionary)->Dictionary:
    var value=_row(row,cache)
    var requirement:Dictionary=row.get("requirement",{})
    value.reason=row.get("reason",requirement.get("reason","Unresolved indexed requirement"))
    value.category=row.get("missing_category",requirement.get("gap_kind","implementation"))
    value.required_kind=row.get("required_kind",row.kind)
    value.implementation=requirement.get("implementation",value.get("coverage",{}).get("implementation","not_examined"))
    value.source_availability=requirement.get("availability",value.get("coverage",{}).get("source","not_examined"))
    value.prepared=value.get("coverage",{}).get("prepared","not_examined")
    return value

static func _body(row:Dictionary,cache:Dictionary)->Dictionary:
    var value=_row(row,cache)
    var track:Dictionary=row.track
    var rig:Dictionary=Characters.rigs(cache).get(track.rig,{})
    var clip:Dictionary=rig.get("clips",{}).get(track.clip,{})
    value.clip=track.clip;value.rig=track.rig
    value.source=clip.get("resource_source","catalog/rigs.json:/%s/clips/%s"%[track.rig,track.clip])
    value.duration_ms=track.duration_ms
    value.source_start_seconds=track.get("source_start_seconds",0)
    value.source_end_seconds=track.get("source_end_seconds",0)
    value.source_time_keys=track.get("source_time_keys",[]).duplicate(true)
    value.source_paths=[];value.missing_paths=[]
    value.valid_clip=not clip.is_empty() and clip.get("frames",0)>0 and clip.get("fps",0)>0
    if value.valid_clip:
        var paths=Characters.sheet_paths(track.presentation_actor,[track.clip],cache,track.get("presentation_item_looks",{}))
        value.source_lookup_ok=paths.ok
        if paths.ok:
            for path in paths.value:
                value.source_paths.append(path)
                if not FileAccess.file_exists(Catalog.media_path(path)):value.missing_paths.append(path)
        else:value.source_error=paths.get("error","Source closure unavailable")
    else:value.source_lookup_ok=false
    value.source_available=value.source_lookup_ok and not value.source_paths.is_empty() and value.missing_paths.is_empty()
    value.prepared="not_examined"
    return value

static func build(index:Dictionary,behavior:String="",require_body:bool=false)->Dictionary:
    var by_id={};var selected:Array=[];var gaps:Array=[]
    for row in index.rows:
        by_id[row.id]=row
        if row.kind=="event" and (behavior.is_empty() or row.event.get("behavior_id")==behavior):selected.append(row)
        if row.kind!="event" and row.get("status")=="missing":gaps.append(row)
    var result={"version":1,"recording":index.directory,"behavior":behavior,"require_body":require_body,
        "identity":index.get("identity",{}).duplicate(),"passed":true,"occurrences":[],"context_gaps":[],"failures":[],
        "context_tracks":[],"scope":"Compiled occurrence implementation and current referenced-file availability only. Prepared resources, rendered pixels and audible output require separate native evidence; context gaps are not hidden by a passing scoped action."}
    if not behavior.is_empty() and selected.is_empty():result.failures.append({"reason":"requested_behavior_not_recorded","behavior":behavior})
    var owned_gaps={}
    for event_row in selected:
        var event:Dictionary=event_row.event
        var occurrence={"id":event_row.id,"event_uuid":event.event_uuid,"behavior_id":event.get("behavior_id"),
            "event_kind":event.kind,"event_status":event.status,"event_reasons":event.get("reasons",[]).duplicate(),
            "requirements":event.get("components",[]).duplicate(true),"actor_uuid":event.get("actor_uuid"),"sequence":event.sequence,"group_id":event_row.group_id,
            "parent_id":event_row.parent,"start_ms":event_row.start_ms,"end_ms":event_row.end_ms,
            "commit_markers":event_row.get("markers",[]).duplicate(true),"body_tracks":[],"component_tracks":[],
            "child_conditions":[],"unresolved_requirements":[],"failures":[]}
        for row in index.rows:
            if row.id==event_row.id or not _under(row,event_row.id,by_id):continue
            if row.kind=="body" and row.track.get("source_event_uuid")==event.event_uuid:
                occurrence.body_tracks.append(_body(row,index.cache))
            elif row.kind=="condition":
                var child=_row(row,index.cache)
                child.condition_uuid=row.owner.id;child.behavior_id=row.owner.condition.behavior_id
                child.initial=row.owner.initial;child.application_event_uuid=row.owner.condition.get("event_uuid")
                child.application_markers=by_id.get(row.parent,{}).get("markers",[]).duplicate(true)
                occurrence.child_conditions.append(child)
            elif row.has("component") or row.has("render_method"):occurrence.component_tracks.append(_row(row,index.cache))
        for row in gaps:
            if _under(row,event_row.id,by_id):
                occurrence.unresolved_requirements.append(_gap(row,index.cache));owned_gaps[row.id]=true
        if require_body and not occurrence.body_tracks.any(func(body):return body.duration_ms>0 and body.end_ms>body.start_ms and body.status=="available" and body.valid_clip and body.source_available):
            occurrence.failures.append({"reason":"required_owned_body_missing","event_uuid":event.event_uuid,
                "detail":"A positive-duration body track with this exact source event and available authored clip sources is required. Child condition poses do not satisfy it."})
        if not occurrence.unresolved_requirements.is_empty():occurrence.failures.append({"reason":"unresolved_owned_requirements","count":occurrence.unresolved_requirements.size()})
        occurrence.passed=occurrence.failures.is_empty()
        if not occurrence.passed:result.failures.append({"reason":"occurrence_incomplete","id":event_row.id,"failures":occurrence.failures.duplicate(true)})
        result.occurrences.append(occurrence)
    for row in index.rows:
        if row.get("parent","").is_empty() and row.has("render_method") and row.get("status")!="missing":result.context_tracks.append(_row(row,index.cache))
    for row in gaps:
        if not owned_gaps.has(row.id):result.context_gaps.append(_gap(row,index.cache))
    if behavior.is_empty() and not result.context_gaps.is_empty():result.failures.append({"reason":"unresolved_recording_context","count":result.context_gaps.size()})
    result.passed=result.failures.is_empty()
    result.counts={"occurrences":result.occurrences.size(),"owned_gaps":owned_gaps.size(),"context_gaps":result.context_gaps.size(),"all_timeline_gaps":gaps.size()}
    return result
