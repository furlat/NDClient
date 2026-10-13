extends SceneTree
const Protocol=preload("res://sdk/protocol.gd")
const Transport=preload("res://sdk/transport.gd")
const Fixture=preload("res://tests/sdk_choices_checks.gd")
const Choices=preload("res://sdk/choices.gd")
const Peer=preload("res://tests/trusted_choices_peer.gd")
const SAFE=9007199254740991
var checks=0
var failures: Array=[]
var path=""
var payload_bytes=0
var timings={}
var peer: RefCounted
var transport: RefCounted
var connected: Variant=null
var terminal: Variant=null
var responses={}

func check(ok: bool,label: String) -> bool:
    checks+=1
    if not ok: failures.append(label); print("TRUSTED_CHOICES_FAIL ",label)
    return ok

func _initialize() -> void: run.call_deferred()
func _process(_delta: float) -> bool:
    if peer!=null: peer.tick()
    if transport!=null:
        for notice in transport.drain():
            if notice.kind=="connected": connected=notice.result
            if notice.kind in ["failure","completed"]: terminal=notice
            if notice.kind=="response": responses[notice.request_id]=notice.result
    return false

func equal_values(protocol: RefCounted,raw: PackedByteArray,label: String) -> Dictionary:
    var tick=Time.get_ticks_usec()
    var strict=protocol.decode("ChoicesResponse",raw)
    var strict_ms=(Time.get_ticks_usec()-tick)/1000.0
    tick=Time.get_ticks_usec()
    var trusted=protocol.decode_server_choices(raw)
    var trusted_ms=(Time.get_ticks_usec()-tick)/1000.0
    check(strict.ok and trusted.ok,label+" accepted by strict and opted-in decoders")
    if not strict.ok or not trusted.ok:
        print("TRUSTED_ADMISSION_DIAGNOSTIC ",label," ",strict.get("error")," ",trusted.get("error")); return {}
    var issue=Fixture.difference(strict.value,trusted.value)
    check(issue.is_empty(),label+" exact raw JSON values match: "+issue)
    if label=="Actual recorded choices":
        tick=Time.get_ticks_usec()
        var reference_issue=Choices.check_choices(trusted.value.choices,true)
        timings={"strict_decode_ms":strict_ms,"native_decode_structure_references_ms":trusted_ms,
            "references_only_ms":(Time.get_ticks_usec()-tick)/1000.0}
        check(reference_issue.is_empty(),"Actual shared reference check independently succeeds")
    return trusted.value

func run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--choices="): path=arg.trim_prefix("--choices=")
    if path.is_empty():
        check(false,"Usage: --choices=<actual compact ChoicesResponse JSON> is required")
        finish(); return
    var raw=FileAccess.get_file_as_bytes(path)
    payload_bytes=raw.size()
    var protocol=Protocol.new()
    if not check(protocol.setup_error.is_empty(),"Current schema loads"): finish(); return
    var actual=equal_values(protocol,raw,"Actual recorded choices")
    if actual.is_empty(): finish(); return
    check(payload_bytes>0 and not actual.choices.target_sets.is_empty(),"Actual fixture supplies shared compact domains")
    var small=Fixture.envelope(Fixture.discovery())
    var minimal=small.duplicate(true)
    minimal.erase("kind")
    minimal.choices={"entity_uuid":"abcdefab-cdef-4abc-8def-abcdefabcdef".to_upper(),"discovery_generation":0}
    var defaults=equal_values(protocol,JSON.stringify(minimal).to_utf8_buffer(),"Sparse defaults and UUID case")
    if not defaults.is_empty():
        check(not defaults.has("kind") and defaults.choices.entity_uuid==minimal.choices.entity_uuid,"Query preserves omitted discriminator and authored UUID case")
        check(not defaults.choices.has("target_sets") and not defaults.choices.has("entity_actions") and Choices.all_actions(defaults.choices).is_empty(),"Defaults are read at lookup without materializing missing arrays")
    for value in [-SAFE,-2,0,2,SAFE]:
        var typed=Fixture.envelope({"discovery_generation":1,"entity_uuid":Fixture.UUID,
            "subjects":[{"uuid":"ABCDEFAB-CDEF-4ABC-8DEF-ABCDEFABCDEF","kind":"creature"}],
            "positions":[[value,-value]],"target_sets":[[{"kind":"subject","index":absi(value),"subject":0,"position":0}]],
            "entity_actions":[Fixture.action(0,0)],"remaining_movement":value})
        typed.choices.entity_actions[0].allow_same_target=true
        typed.choices.entity_actions[0].source_item_uuid=null
        var decoded=equal_values(protocol,JSON.stringify(typed).to_utf8_buffer(),"Safe integer "+str(value))
        if decoded.is_empty(): continue
        var got=decoded.choices.entity_actions[0]
        var option=Choices.action_options(decoded.choices,got)[0]
        check(got.discovery_index==0 and option.index==absi(value),"Native discovery/target integer values remain exact")
        check(Fixture.difference(Choices.binding_position(decoded.choices,option),[value,-value]).is_empty(),"Signed safe-coordinate boundaries remain exact")
        check(typeof(got.can_afford)==TYPE_BOOL and got.can_afford and got.allow_same_target==true and got.source_item_uuid==null,"Booleans/null retain native types")
        check(Choices.binding_subject(decoded.choices,option).uuid==typed.choices.subjects[0].uuid,"Nested UUID case is retained without normalization")
    # The public strict parser preserves integer-token distinctions. Native JSON,
    # like TypeScript, sees only Number; its explicit path accepts exact integers.
    var real_token=JSON.stringify(small).replace('"target_set":0','"target_set":0.0')
    check(not protocol.decode("ChoicesResponse",real_token.to_utf8_buffer()).ok and protocol.decode_server_choices(real_token.to_utf8_buffer()).ok,"Only opted native-number path accepts integral real-token references")
    for field in ["game_id","game_epoch","audience_id","state_revision","correlation_id","force_attack","choices"]:
        var omitted=small.duplicate(true); omitted.erase(field)
        check(not protocol.decode_server_choices(JSON.stringify(omitted).to_utf8_buffer()).ok,"Missing required envelope "+field+" rejected")
    for mutation in ["wrong_kind","invalid_actor","null_actor","family_shape","choice_extra","top_extra","fractional_generation","unsafe_generation","force_number","missing_generation","missing_index","float_index","invalid_reference"]:
        var bad=small.duplicate(true)
        match mutation:
            "wrong_kind": bad.kind="operation"
            "invalid_actor": bad.choices.entity_uuid="invalid"
            "null_actor": bad.choices.entity_uuid=null
            "family_shape": bad.choices.entity_actions={}
            "choice_extra": bad.choices.extra=true
            "top_extra": bad.extra=true
            "fractional_generation": bad.choices.discovery_generation=0.5
            "unsafe_generation": bad.choices.discovery_generation=SAFE+1
            "force_number": bad.force_attack=1
            "missing_generation": bad.choices.erase("discovery_generation")
            "missing_index": bad.choices.target_sets[0][0].erase("index")
            "float_index": bad.choices.target_sets[0][0].index=0.5
            "invalid_reference": bad.choices.target_sets[0][0].subject=999
        check(not protocol.decode_server_choices(JSON.stringify(bad).to_utf8_buffer()).ok,"Envelope/shared-domain/reference admission rejects "+mutation)
    for malformed in ["{",'{"choices":',"not json","[]","null"]:
        check(not protocol.decode_server_choices(malformed.to_utf8_buffer()).ok,"Malformed JSON or non-object envelope rejected: "+malformed)
    for invalid_utf8 in [[255],[0xc0,0x80],[0xed,0xa0,0x80],[0xf4,0x90,0x80,0x80]]:
        check(not protocol.decode_server_choices(PackedByteArray(invalid_utf8)).ok,"Invalid UTF8 rejected before native JSON")
    var nested=small.duplicate(true)
    nested.choices.entity_actions[0].trusted_fixture_marker="nested server data"
    var nested_bytes=JSON.stringify(nested).to_utf8_buffer()
    check(not protocol.decode("ChoicesResponse",nested_bytes).ok,"Generic decoder still rejects undeclared nested action fields")
    check(protocol.decode_server_choices(nested_bytes).ok,"Opted path trusts non-reference action metadata; no deep-validation claim")
    for invalid in [0,1,"true",null]:
        var client=Transport.new()
        check(not client.start("http://127.0.0.1:1","test",Callable(),{"trusted_choices":invalid}).ok,"Trust option requires a real boolean")
        client.close()
    await start_peer(small,false)
    if connected!=null and connected.ok:
        peer.reply_case="trusted_body"
        var strict_reply=await request("choices",arguments())
        check(not strict_reply.ok and strict_reply.error.kind=="protocol","Real HTTP default transport still deeply validates choices")
    stop_peer()
    await start_peer(small,true)
    if connected!=null and connected.ok:
        var offered=await request("choices",arguments())
        check(offered.ok,"Opted real HTTP choices succeeds after verified bootstrap/attachment")
        if offered.ok:
            check(not offered.has("normalized") and offered.value.choices.entity_uuid==Peer.UUID,"Worker transfers compact query value without a normalized alias")
            check(not offered.value.choices.has("position_actions") and offered.value.choices.target_sets.size()==6,"Worker preserves sparse defaults and shared sets")
            offered.value.choices.entity_uuid="caller mutation"
            var second=await request("choices",arguments())
            check(second.ok and second.value.choices.entity_uuid==Peer.UUID,"Separate HTTP responses retain independent owners")
        peer.reply_case="trusted_body"
        var trusted_reply=await request("choices",arguments())
        check(trusted_reply.ok and trusted_reply.value.choices.entity_actions[0].has("trusted_fixture_marker"),"Explicit transport opt-in reaches native trusted-metadata path")
        for mode in ["foreign_game","foreign_epoch","foreign_audience","wrong_actor","wrong_revision","wrong_correlation","wrong_force","invalid_actor","invalid_family","invalid_reference"]:
            peer.reply_case=mode
            var rejected=await request("choices",arguments())
            check(not rejected.ok and rejected.error.kind=="protocol","Opted HTTP still rejects "+mode)
        for received in peer.requests:
            check(received.headers.get("authorization")=="Bearer test","Loopback requests retain authentication header")
    stop_peer()
    await start_peer(small,true,"bad_bootstrap")
    check(connected==null and terminal!=null and terminal.kind=="failure","Opt-in cannot bypass bootstrap protocol identity")
    stop_peer()
    finish()

func arguments() -> Dictionary:
    return {"actor_uuid":Peer.UUID,"state_revision":"r","force_attack":false,"correlation_id":Peer.UUID}
func until(which: String,id: int=-1) -> bool:
    var deadline=Time.get_ticks_msec()+10000
    while Time.get_ticks_msec()<deadline:
        if which=="connected" and (connected!=null or terminal!=null): return true
        if which=="response" and responses.has(id): return true
        await process_frame
    check(false,"Timed out waiting for "+which); return false
func request(operation: String,args: Dictionary) -> Dictionary:
    var id: int=transport.request(operation,args)
    if not await until("response",id): return Transport.failure("transport","Test timeout")
    var value: Dictionary=responses[id]; responses.erase(id); return value
func start_peer(body: Dictionary,trusted: bool,mode: String="normal") -> void:
    connected=null; terminal=null; responses={}
    peer=Peer.new(); peer.choices_body=body
    if not check(peer.start(mode),"Independent loopback TCP server starts"): return
    transport=Transport.new()
    var options={"request_timeout":5.0,"reconnect_timeout":5.0,"stream_idle_timeout":5.0}
    if trusted: options.trusted_choices=true
    if not check(transport.start("http://127.0.0.1:"+str(peer.port),"test",Callable(),options).ok,"Real transport worker starts"): return
    await until("connected")
    if connected!=null and connected.ok:
        var attached=await request("attach",{"acquisition_id":Peer.UUID,"expected_attachment_epoch":Peer.UUID})
        check(attached.ok,"Real attachment establishes request scope")
func stop_peer() -> void:
    if transport!=null:
        transport.close(); check(not transport.is_running(),"Worker closes cleanly"); transport=null
    if peer!=null: peer.close(); peer=null
func finish() -> void:
    var report={"checks":checks,"failures":failures,"choices":path,"payload_bytes":payload_bytes,"timings":timings,
        "command":"Godot --headless --path \"%s\" --script res://tests/trusted_choices_checks.gd -- --choices=\"%s\"" % [ProjectSettings.globalize_path("res://"),path],
        "scope":"Schema8 actual compact payload strict/native JSON equality without normalization; once-per-domain structure/reference admission; sparse defaults, safe integer coordinates and native indices. Real loopback HTTP default strict and explicit trusted metadata preserve identity/scope/correlation and reject unsafe references. Native JSON intentionally cannot distinguish integer versus integral-real tokens. Single-call diagnostic timings are not live-frame performance claims."}
    FileAccess.open("res://generated/trusted_choices_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("TRUSTED_CHOICES_CHECKS ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
