extends "res://tests/sdk_transport_checks.gd"
# Public loopback requests and durable consumer results remain identical with
# profiling enabled. No trace record may carry a credential or payload field.
const Session = preload("res://presentation/session.gd")
var profile_evidence: Dictionary = {}

func start_profile(mode: String = "normal") -> void:
    notices=[];responses={};connected=null;terminal=null
    peer=Peer.new();check(peer.start(mode),"Profile loopback peer starts")
    consumer=Consumer.new();transport=Transport.new()
    check(transport.set_profiling(true).ok,"Profiling opts in before start")
    check(transport.start("http://127.0.0.1:"+str(peer.port),"PROFILE_SECRET_TOKEN",consumer.consume).ok,"Profiled transport starts")
    check(not transport.set_profiling(false).ok,"Running transport rejects profile reconfiguration")
    await _until("connected")
    check(connected!=null and connected.ok,"Profiled bootstrap succeeds")
    check((await _request("attach",{"acquisition_id":Peer.UUID,"expected_attachment_epoch":Peer.UUID})).ok,"Profiled attachment succeeds")

func records_for(rows: Array, request_id: int) -> Dictionary:
    var result={}
    for row in rows:
        if row.get("request_id",0)==request_id:result[row.stage]=row
    return result

func numeric_phases(value:Variant)->bool:
    if value is Dictionary:
        for key in value:
            if not key is String or not numeric_phases(value[key]):return false
        return true
    return typeof(value) in [TYPE_INT,TYPE_FLOAT,TYPE_BOOL]

func profile_privacy(rows: Array) -> void:
    var allowed=["stage","time_us","started_us","http_id","request_id","operation","purpose","schema","bytes","request_bytes","declared_bytes","status","ok","sequence","frame_id","event","records","packet_started_us","compile_started_us","end_us","from_disk","compile_ended_us","required_media_ms","framing_started_us","phases","phases_ms","reused_connected","native_error","validation","transport_reason","failure_kind","connection_replaced","native_state","sent","request_attempted","phase","reason"]
    var safe=true
    for row in rows:
        for key in row:
            if key in ["phases","phases_ms"]:
                if not numeric_phases(row[key]):safe=false
            elif not key in allowed or typeof(row[key]) in [TYPE_DICTIONARY,TYPE_ARRAY,TYPE_PACKED_BYTE_ARRAY]:safe=false
    var text=JSON.stringify(rows)
    check(safe and not "PROFILE_SECRET_TOKEN" in text and not Peer.UUID in text and not "http://" in text,"Profile exports only flat timing/size/label fields, no credentials, URLs, IDs from payload or source bodies")

func _run() -> void:
    var off=Transport.new()
    off.request("sensitive-unknown-operation",{"secret":"PROFILE_SECRET_TOKEN"})
    check(off.drain_profile().records.is_empty(),"Profiling is disabled by default")
    var bounded=Transport.new();bounded.set_profiling(true)
    for i in range(Transport.PROFILE_CAPACITY+9):bounded.request("PROFILE_SECRET_TOKEN",{"secret":Peer.UUID})
    var full=bounded.drain_profile()
    check(full.records.size()==Transport.PROFILE_CAPACITY and full.total==Transport.PROFILE_CAPACITY+9 and full.dropped==9,"Undrained profile retains a fixed ring and exact loss count")
    check(full.records.front().request_id==10 and full.records.back().request_id==Transport.PROFILE_CAPACITY+9,"Overflow retains the most recent records in order")
    profile_privacy(full.records)
    check(bounded.drain_profile().records.is_empty(),"Draining detaches records exactly once")
    bounded.request("health")
    check(full.records.front().request_id==10 and bounded.drain_profile().records.size()==1,"A drained snapshot remains immutable across later records")
    await start_profile()
    var id=transport.request("choices",{"actor_uuid":Peer.UUID,"state_revision":"r","force_attack":false,"correlation_id":Peer.UUID})
    await _until("response",id)
    var response:Dictionary=responses[id]
    check(response.ok and not response.value.has("kind") and not response.has("normalized") and response.value.choices.entity_uuid==Peer.UUID,"Profiled choices preserve the current sparse admitted response without a duplicate normalized tree")
    check((await _request("follow")).ok,"Profiled follower begins")
    await _until("terminal")
    check(terminal!=null and terminal.kind=="completed" and peer.acks==[0,1,2] and consumer.seen==[0,1,2],"Profiled SSE preserves duplicate handling, canonical consumption and ACK order")
    transport.close()
    var report=transport.drain_profile()
    var phases=records_for(report.records,id)
    var previous=0
    var ordered=true
    for phase in ["request_enqueued","http_created","request_sent","response_headers","body_complete","http_admission","reply_check","response_published","http_end"]:
        if not phases.has(phase):ordered=false;continue
        if phases[phase].time_us<previous:ordered=false
        previous=phases[phase].time_us
    check(ordered,"Choices record a monotonic enqueue→send→headers→body→admission→normalization→publication→end chain")
    check(not phases.has("response_normalization"),"Sparse choices do not report a normalization phase that no longer runs")
    check(phases.has("body_complete") and phases.body_complete.bytes>0 and phases.request_sent.request_bytes>0,"HTTP records report received and transmitted sizes without bodies")
    var canonical=[];var framed={};var sse_ok=true;var chunks=0
    for row in report.records:
        if row.stage=="canonical_consumer":
            canonical.append(row.sequence)
            if row.time_us<row.started_us or not row.ok:sse_ok=false
        if row.stage=="sse_chunk":chunks+=1
        if row.stage=="sse_record_ready":
            framed[row.frame_id]=row.time_us
            if row.get("framing_started_us",row.time_us)>row.time_us:sse_ok=false
        if row.stage=="sse_admission":
            if not framed.has(row.frame_id) or framed[row.frame_id]>row.started_us or row.started_us>row.time_us:sse_ok=false
    check(canonical==[0,1,2] and chunks>0 and framed.size()>0 and sse_ok,"SSE raw-chunk/framing/admission and exactly-once canonical-consumer timings are correlated")
    profile_privacy(report.records)
    profile_evidence.transport=report
    _stop()

    # Exercise the separate real preparation worker through Session, using the
    # same bounded wire source. It shares only the scalar timing ring.
    peer=Peer.new();check(peer.start("bounded"),"Session timing peer starts")
    var session=Session.new();session.transport.set_profiling(true)
    var directory="user://checks/profile-"+Session.uuid()
    check(session.start({"journal":directory,"url":"http://127.0.0.1:"+str(peer.port),"token":"PROFILE_SECRET_TOKEN"}).ok,"Profiled session starts")
    var deadline=Time.get_ticks_msec()+20000
    while (not session.terminal or session.diagnostics().prepared_sequence<1) and session.issue.is_empty() and Time.get_ticks_msec()<deadline:
        session.poll();await process_frame
    check(session.issue.is_empty() and session.latest_sequence==8 and session.diagnostics().prepared_sequence==1,"Instrumentation preserves durable cursor and bounded presentation lookahead")
    session.close()
    var prepared=session.transport.drain_profile()
    var operations=[];var monotonic=true
    for row in prepared.records:
        if row.stage=="presentation_prepare":
            operations.append(row.sequence)
            if not (row.packet_started_us<=row.compile_started_us and row.compile_started_us<=row.end_us and row.end_us==row.time_us and row.ok):monotonic=false
    check(operations==[0,1] and monotonic,"Each prepared initialization/operation reports monotonic packet and compile intervals without changing window")
    profile_privacy(prepared.records)
    profile_evidence.session=prepared
    peer.close();peer=null
    for name in DirAccess.get_files_at(directory):DirAccess.remove_absolute(directory.path_join(name))
    DirAccess.remove_absolute(directory)
    FileAccess.open("res://generated/sdk_profile_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":profile_evidence},"  "))
    print("SDK_PROFILE_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
