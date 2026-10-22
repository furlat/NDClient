extends SceneTree
## Exact human/Codex summon journey bytes and Python per-record state, with
## event-time control publication and acknowledged input boundaries.
const Protocol=preload("res://sdk/protocol.gd")
const Reducer=preload("res://sdk/reducer.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Timeline=preload("res://presentation/timeline.gd")
const Requirements=preload("res://presentation/requirements.gd")
const Session=preload("res://presentation/session.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const ROOT="res://tests/fixtures/schema18/summon-control"
var checks:int=0
var failures:Array=[]
var grants:int=0
var revocations:int=0
var nested_sensory:int=0
var private_grants:int=0
var input_modes:Dictionary={}

func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("SCHEMA18_AUDIENCE_FAIL ",label)

func _initialize()->void:call_deferred("run")

func input_boundary(packet:Dictionary,state:Dictionary,label:String)->void:
    var session=Session.new();var cursor:Dictionary=packet.cursor
    session.following=true
    session.status={"boundary":packet.boundary,"acknowledged_cursor":cursor,"catch_up_cursor":cursor}
    var waiting:bool=packet.boundary.input_actor_uuid!=null
    check(session.ready_for_input(int(cursor.sequence))==waiting,label+" uses the real producer input boundary")
    if waiting:
        var actor:String=packet.boundary.input_actor_uuid
        check(actor in state.audience.controlled and state.current_actor_uuid==actor,label+" authorizes the controlled current actor")
        input_modes[packet.boundary.lifecycle]=true
        check(not session.ready_for_input(int(cursor.sequence)-1),label+" waits for displayed catch-up")
        var prior:Dictionary=cursor.duplicate();prior.sequence=int(cursor.sequence)-1
        session.status.acknowledged_cursor=prior
        check(not session.ready_for_input(int(cursor.sequence)),label+" waits for acknowledged catch-up")
        session.status.acknowledged_cursor=cursor;session.following=false
        check(not session.ready_for_input(int(cursor.sequence)),label+" requires the live attachment")

func event_cuts(before:Dictionary,packet:Dictionary,folded:Dictionary,label:String)->void:
    var displayed:Dictionary=Reducer.copy_target(before)
    for index in range(packet.lineages.size()):
        var native:Dictionary=packet.lineages[index];var recorded:Dictionary=folded.transitions.lineages[index]
        for event_index in range(native.events.size()):
            var node:Dictionary=native.events[event_index];var captured:Dictionary=recorded.events[event_index]
            var prior_audience:Dictionary=displayed.audience
            Compiler.apply_delta(displayed,captured.delta)
            for body in native.get("bodies",[]):
                if body.occurrence!=node.occurrence or body.body.get("controlled_items")==null or body.actor_uuid in before.audience.controlled:continue
                private_grants+=1
                check(body.actor_uuid in displayed.audience.controlled,label+" admits the original new private body after control")
            var fact:Variant=node.get("fact")
            if fact==null or fact.kind!="audience" or node.get("canceled",false):continue
            var where:String=label+" occurrence "+str(node.occurrence)
            check(displayed.audience==fact.audience,where+" publishes the actual roster at its native cut")
            check(int(displayed.audience.revision)==int(prior_audience.revision)+1,where+" advances one roster revision")
            for identity in displayed.audience.controlled:
                if not identity in prior_audience.controlled:grants+=1
            for identity in prior_audience.controlled:
                if identity in displayed.audience.controlled:continue
                revocations+=1
                check(not displayed.actors.has(identity) or displayed.actors[identity].controlled_items==null,where+" removes revoked private inventory")
                if displayed.hud_snapshot!=null:
                    check(displayed.hud_snapshot.sheets.all(func(sheet):return sheet.actor_uuid in displayed.audience.controlled),where+" removes revoked HUD sheets")
            if fact.get("sensory")!=null:
                nested_sensory+=1
                check(captured.delta.set.has("senses"),where+" publishes the nested perception settlement")
        Compiler.apply_delta(displayed,recorded.trailing)
    # HUD/content/log append publication belongs to the operation tail, outside
    # the recorded occurrence deltas. Compare the occurrence-owned state here.
    for field in ["audience","current_actor_uuid","round_number","actors","items","senses","entity_members","object_contact_members","effect_members","object_members"]:
        var issue:String=Compare.difference(displayed[field],folded.value[field])
        check(issue.is_empty(),label+" displayed "+field+" matches canonical "+issue)

func scheduled_publication(before:Dictionary,packet:Dictionary,folded:Dictionary,timeline:RefCounted,cache:Dictionary,label:String)->void:
    var compiled:Dictionary=Compiler.compile_recorded(before,packet,cache,folded.value,folded.transitions)
    check(compiled.ok,label+" compiles through production presentation "+str(compiled.get("error","")))
    if not compiled.ok:return
    var duration:float=0.0
    for group in compiled.value.groups:
        duration+=float(group.duration_ms)
        for event in group.events:
            if event.kind=="audience":
                check(Requirements.fact(event.kind,cache).implementation=="not_applicable",label+" classifies roster publication without an invented animation requirement")
    timeline.accept({"kind":"operation","groups":compiled.value.groups})
    timeline.advance(duration+1.0)
    check(not timeline.busy(),label+" reaches the actual scheduled operation end")
    var issue:String=Compare.difference(timeline.state,folded.value)
    check(issue.is_empty(),label+" shared timeline publishes complete canonical state "+issue)

func refused_revision(before:Dictionary,packet:Dictionary,label:String)->void:
    var invalid:Dictionary=packet.duplicate(true);var changed:bool=false
    for lineage in invalid.lineages:
        for node in lineage.events:
            var fact:Variant=node.get("fact")
            if fact!=null and fact.kind=="audience" and not node.get("canceled",false):
                fact.audience.revision=int(fact.audience.revision)+1;changed=true;break
        if changed:break
    if not changed:return
    var frozen:Dictionary=before.duplicate(true)
    check(not Reducer._reduce_operation_retained(before,invalid,true).ok,label+" rejects a skipped roster revision")
    check(before==frozen,label+" rejected revision preserves the accepted state")

func run()->void:
    var index:Variant=JSON.parse_string(FileAccess.get_file_as_string(ROOT.path_join("index.json")))
    if index==null:check(false,"Missing original summon journey index");finish();return
    var archive:ZIPReader=null
    if index.has("states_archive"):
        archive=ZIPReader.new()
        if archive.open(ROOT.path_join(index.states_archive))!=OK:check(false,"Missing Python per-record state archive");finish();return
    var protocol=Protocol.new()
    for seat in index.seats:
        var state:Dictionary={};var context:Dictionary={};var held:Array=[];var frozen:Array=[]
        var timeline=Timeline.new();var cache:Dictionary={}
        for position in range(seat.records.size()):
            var record:Dictionary=seat.records[position];var label:String=str(seat.id)+":"+str(position)
            var raw:PackedByteArray=FileAccess.get_file_as_bytes(ROOT.path_join(record.bytes))
            var admitted:Dictionary=protocol.decode("InitializationResponse" if position==0 else "PlayerOperation",raw)
            check(admitted.ok,label+" current schema admits original bytes")
            if not admitted.ok:break
            var packet:Dictionary=admitted.value;var before:Dictionary=state.duplicate(true)
            var folded:Dictionary=Reducer.reduce_initialization(packet.initialization,packet.get("content_additions",[])) if position==0 else Reducer._reduce_operation_retained(state,packet,true,null,context)
            check(folded.ok,label+" original record folds "+str(folded.get("error","")))
            if not folded.ok:break
            var expected_text:String=archive.read_file(record.expected).get_string_from_utf8() if archive!=null else FileAccess.get_file_as_string(ROOT.path_join(record.expected))
            var expected:Variant=JSON.parse_string(expected_text)
            var issue:String=Compare.difference(folded.value,expected)
            check(issue.is_empty(),label+" matches complete Python reference "+issue)
            check(state==before,label+" preserves the preceding accepted state")
            for saved in range(held.size()):check(held[saved]==frozen[saved],label+" preserves prior roster/display cuts "+str(saved))
            if position>0:
                event_cuts(state,packet,folded,label)
                scheduled_publication(state,packet,folded,timeline,cache,label)
                input_boundary(packet,folded.value,label)
                var membership:bool=packet.lineages.any(func(lineage):return lineage.events.any(func(node):return node.get("fact")!=null and node.fact.kind=="audience"))
                if membership:
                    refused_revision(state,packet,label)
                    held.append(folded);frozen.append(folded.duplicate(true))
            else:timeline.accept({"kind":"initialization","state":folded.value.duplicate(true),"sequence":int(packet.cursor.sequence)})
            state=folded.value;context=folded.sensory_context
    if archive!=null:archive.close()
    check(grants>0 and revocations>0 and nested_sensory>0 and private_grants>0,"Original journeys exercise grant, private admission, revocation and nested perception")
    check(input_modes.has("waiting_for_human") and input_modes.has("waiting_for_codex"),"Original journeys exercise both authorized controller modes")
    finish()

func finish()->void:
    print("SCHEMA18_AUDIENCE_CHECKS ",JSON.stringify({"checks":checks,"failures":failures,"grants":grants,"revocations":revocations,"nested_sensory":nested_sensory,"private_grants":private_grants,"input_modes":input_modes.keys()}))
    quit(0 if failures.is_empty() else 1)
