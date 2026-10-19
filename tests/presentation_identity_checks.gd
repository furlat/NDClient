extends SceneTree
# Exact admitted operation identity at the compiler and bounded session boundary.
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Session = preload("res://presentation/session.gd")
const Journal = preload("res://sdk/journal.gd")
const Compiler = preload("res://presentation/compiler.gd")
const Reducer = preload("res://sdk/reducer.gd")
const Timeline = preload("res://presentation/timeline.gd")
var checks = 0
var failures: Array = []
var cache: Dictionary = {}
var evidence = {"own_operations":0,"null_operations":0,"groups":0,"multi_lineage_operations":0,"empty_typed_cases":0,"session_messages":0}
var recordings = [Fixtures.journal("dash"),Fixtures.journal("dash","blue"),Fixtures.journal("oa-jump-late-lethal")]

func check(ok:bool,label:String)->void:
    checks+=1
    if not ok: failures.append(label);print("PRESENTATION_IDENTITY_FAIL ",label)
func _initialize()->void:run.call_deferred()
func group_identity(groups:Array,packet:Dictionary,label:String)->void:
    check(not groups.is_empty(),label+" always publishes a presentation boundary")
    for group in groups:
        check(group.get("cursor",{})==packet.cursor,label+" exact game/epoch/audience/sequence")
        check(group.has("command_number") and group.command_number==packet.command_number,label+" exact nullable command number")
        check(group.operation_sequence==packet.cursor.sequence,label+" sequence remains consistent")
        check(not is_same(group.cursor,packet.cursor),label+" cursor does not alias input packet")
        evidence.groups+=1
    check(groups[-1].operation_end,label+" final boundary ends the original operation")
func direct(directory:String)->void:
    var journal=Journal.new();var opened=journal.open(directory,true,false)
    check(opened.ok,directory+" real recorded schema")
    if not opened.ok:return
    var state:Dictionary={}
    var files=DirAccess.get_files_at(directory);files.sort()
    var tested_empty=false
    for file in files:
        if file.length()!=21 or not file.ends_with(".json"):continue
        var root_name="InitializationResponse" if state.is_empty() else "PlayerOperation"
        var decoded=journal.protocol.decode(root_name,FileAccess.get_file_as_bytes(directory.path_join(file)))
        check(decoded.ok,file+" strict source admission")
        if not decoded.ok:return
        var packet:Dictionary=journal.protocol.normalize(root_name,decoded.value)
        if root_name=="InitializationResponse":
            var initial=Reducer.reduce_initialization(packet.initialization,packet.content_additions)
            check(initial.ok,"recorded initialization reduces");state=initial.value;continue
        var original=packet.duplicate(true)
        var compiled=Compiler.compile(state,packet,cache)
        check(compiled.ok,file+" recorded operation compiles")
        if not compiled.ok:return
        group_identity(compiled.value.groups,packet,file)
        check(packet==original,file+" compilation preserves admitted packet")
        if packet.command_number==null:evidence.null_operations+=1
        else:evidence.own_operations+=1
        if packet.lineages.size()>1:evidence.multi_lineage_operations+=1
        if not tested_empty:
            # A deliberately named wire fixture covers permitted no-lineage
            # publications; recorded gameplay evidence above stays unchanged.
            for command in [null,1]:
                var empty=packet.duplicate(true)
                empty.lineages=[];empty.hud=null;empty.combat_log_appends=[];empty.content_additions=[]
                empty.command_number=command
                var admitted=journal.protocol.decode("PlayerOperation",JSON.stringify(empty,"",false,true).to_utf8_buffer())
                check(admitted.ok,"typed empty operation is schema-admitted")
                if not admitted.ok:continue
                empty=journal.protocol.normalize("PlayerOperation",admitted.value)
                var result=Compiler.compile(state,empty,cache)
                check(result.ok,"typed empty operation reduces")
                if result.ok:
                    group_identity(result.value.groups,empty,"empty marker")
                    check(result.value.groups.size()==1 and result.value.groups[0].actor_tracks.is_empty(),"empty operation does not invent visual events")
                    evidence.empty_typed_cases+=1
            tested_empty=true
        state=compiled.value.final_state
func prepared(directory:String)->void:
    var session=Session.new();var opened=session.open_recording(directory)
    check(opened.ok,"bounded session opens actual recording")
    if not opened.ok:return
    var timeline=Timeline.new()
    var deadline=Time.get_ticks_msec()+60000
    var received=0
    while Time.get_ticks_msec()<deadline and session.issue.is_empty():
        session.poll()
        for message in session.take_prepared():
            var raw=FileAccess.get_file_as_bytes(directory.path_join("%016d.json" % message.sequence))
            var admitted=session.protocol.decode("InitializationResponse" if message.kind=="initialization" else "PlayerOperation",raw)
            check(admitted.ok,"session message has exact recorded source")
            if not admitted.ok:continue
            var packet:Dictionary=admitted.value
            check(message.get("cursor",{})==packet.cursor,"prepared message preserves full cursor identity")
            check(message.has("command_number") and message.command_number==packet.get("command_number"),"prepared message preserves own/null command scope")
            if message.kind=="operation":group_identity(message.groups,packet,"prepared group")
            else:check(message.command_number==null,"initialization has no invented command owner")
            timeline.accept(message);received+=1;evidence.session_messages+=1
        timeline.advance(1000000)
        session.set_displayed_sequence(timeline.sequence)
        if session.terminal and timeline.sequence==session.latest_sequence and not timeline.busy():break
        await process_frame
    check(session.issue.is_empty(),"bounded session has no admission/preparation error")
    check(session.terminal and timeline.sequence==session.latest_sequence,"bounded session preserves full recording order")
    check(received==session.latest_sequence+1,"one prepared message per actual packet")
    check(timeline.state==session.journal.state,"identity metadata does not alter final reducer state")
    session.close()
func packet_executions(packet:Dictionary)->Dictionary:
    var result:Dictionary={}
    for lineage in packet.get("lineages",[]):
        for event in lineage.events:
            if event.get("turn_execution_id")!=null:result[event.turn_execution_id]=true
    return result
func receipts()->void:
    var directory:String=Fixtures.journal("dash").get_base_dir()
    var report=Journal.Protocol.parse_json(FileAccess.get_file_as_bytes(directory.path_join("commands.json")))
    check(report.ok,"Original current-schema two-seat submitted commands and receipts load")
    if not report.ok:return
    for row in report.value:
        var receipt:Dictionary=row.receipt
        check(receipt.kind=="committed" and receipt.command_number==row.command.command_number,"Actual receipt retains submitted command number")
        var own:String=Fixtures.journal("dash",row.seat)
        var path:String=own.path_join("%016d.json" % int(receipt.cursor.sequence))
        var parsed=Journal.Protocol.parse_json(FileAccess.get_file_as_bytes(path))
        check(parsed.ok,"Committed receipt cursor names a real durable own operation")
        if not parsed.ok:continue
        var packet:Dictionary=parsed.value
        check(packet.cursor==receipt.cursor and packet.command_number==receipt.command_number,"Actual receipt matches exact own operation, including audience and epoch")
        var executions:Dictionary=packet_executions(packet)
        var other:String="blue" if row.seat=="amber" else "amber"
        var matched:int=0
        # Sequence and occurrence numbers are subjective. Match only an actual
        # shared execution UUID, then inspect that audience's own publication.
        for file in DirAccess.get_files_at(Fixtures.journal("dash",other)):
            if file.length()!=21 or not file.ends_with(".json"):continue
            var foreign=Journal.Protocol.parse_json(FileAccess.get_file_as_bytes(Fixtures.journal("dash",other).path_join(file)))
            if not foreign.ok:continue
            var disclosed:Dictionary=packet_executions(foreign.value)
            if not disclosed.keys().any(func(id):return executions.has(id)):continue
            matched+=1
            check(foreign.value.command_number==null and foreign.value.cursor.audience_id!=receipt.audience_id,"Corresponding actual execution does not assign the other audience this command")
            check(foreign.value.cursor.game_id==receipt.game_id and foreign.value.cursor.game_epoch==receipt.game_epoch,"Foreign subjective publication belongs to the same exact encounter")
        check(matched>0,"Real two-seat receipt evidence includes the execution in the peer's original stream")
func run()->void:
    receipts()
    for directory in recordings:
        direct(directory)
        await prepared(directory)
    check(evidence.own_operations>0 and evidence.null_operations>0,"actual own-command and foreign/autonomous operation scopes covered")
    check(evidence.multi_lineage_operations>0 and evidence.empty_typed_cases==6,"multi-lineage actual commands and both empty command scopes covered")
    var report={"checks":checks,"failures":failures,"evidence":evidence,"recordings":recordings,
        "scope":"Real two-seat Dash/movement/OA and lethal jump/OA recordings through strict historical admission, compiler and bounded session; explicitly typed empty-operation cases. Full identity survives every group/message without changing original packets or reducer state."}
    FileAccess.open("res://generated/presentation_identity_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("PRESENTATION_IDENTITY_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
