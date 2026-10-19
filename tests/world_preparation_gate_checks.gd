extends SceneTree
# Prospective world publication versus the unmodified immediate Timeline path.
# Recordings are admitted by their real schema and compiled by the production compiler.
const Timeline = preload("res://presentation/timeline.gd")
const Compiler = preload("res://presentation/compiler.gd")
const Journal = preload("res://sdk/journal.gd")
const Reducer = preload("res://sdk/reducer.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
var checks=0
var failures=[]
var cache={}
var boundaries=0
var held=0
var candidate_calls=0
var evidence={"oa":0,"uncommitted_steps":0,"life":0,"direct_arc":0}
var records=[]
var fixture_state={}
class Gate extends RefCounted:
    var attempts={}
    var candidate={}
    var accepted={}
    var mismatch=false
    var calls=0
    var keys=[]
    func ready(value:Dictionary)->bool:
        calls+=1
        var key=JSON.stringify(value.key)
        if not attempts.has(key):
            attempts[key]=0;candidate=value;keys.append(key)
        elif not is_same(candidate,value):mismatch=true
        attempts[key]+=1
        if attempts[key]<3:return false
        accepted=value
        return true
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("WORLD_PREPARATION_FAIL ",label)
func aligned(actual:RefCounted,reference:RefCounted,label:String)->void:
    check(actual.state==reference.state,label+" exact canonical state")
    check(actual.display_ms==reference.display_ms and actual.sequence==reference.sequence,label+" display timestamp and completed sequence")
    check(actual.staged_tiles()==reference.staged_tiles() and actual.staged_actors()==reference.staged_actors(),label+" support and actor admission")
    check(actual.actor_samples()==reference.actor_samples(),label+" authored body/motion sample")
    check(actual.trace.rows==reference.trace.rows and actual.trace.order==reference.trace.order and actual.trace.logs==reference.trace.logs,label+" causal trace and log order")
func drain(actual:RefCounted,reference:RefCounted,gate:Gate,label:String)->void:
    var attempts=0
    while actual.busy() and attempts<4000:
        # Changing frame deltas during the hold must not change its candidate,
        # advance any partial commit or accumulate a later catch-up interval.
        var before=actual.display_ms
        gate.accepted={}
        actual.advance([0.0,7.0,19.0,9000.0][attempts%4])
        if actual.waiting_for_world:
            held+=1
            check(actual.display_ms==before,label+" delayed gate freezes clock")
            aligned(actual,reference,label+" held")
        else:
            reference.advance(maxf(0,actual.display_ms-reference.display_ms))
            aligned(actual,reference,label+" published")
            if not gate.accepted.is_empty():
                boundaries+=1
                check(actual.state==gate.accepted.state and actual.presentation_state()==gate.accepted.presentation_state,label+" approved detached candidate is exact published boundary")
                check(actual.display_ms==gate.accepted.display_ms and actual.world_revision==gate.accepted.world_revision,label+" one world boundary per advance")
        attempts+=1
    check(not actual.busy() and not reference.busy(),label+" both timelines drain without missing commits")
    check(not gate.mismatch,label+" identical pending candidate reused across arbitrary waits")
func _initialize()->void:run.call_deferred()
func run_recordings()->void:
    for id in ["gallery","oa-walk","oa-jump","oa-jump-late-lethal"]:
        var directory:String=Fixtures.journal(id)
        var expected:int=int(Fixtures.case_record(id).get("packets",Array(DirAccess.get_files_at(directory)).filter(func(file):return file.ends_with(".json") and file.length()==21).size()))
        run_recording(directory,id,expected)
func run()->void:
    run_recordings()
    named_boundaries()
    check(evidence.oa>0 and evidence.uncommitted_steps>0 and evidence.direct_arc>0 and evidence.life>0,"Authentic reaction, interrupted movement, jump and life-state facts covered")
    var report={"checks":checks,"failures":failures,"recordings":records,"approved_boundaries":boundaries,
        "held_attempts":held,"callback_calls":candidate_calls,"native_fact_evidence":evidence,
        "scope":"Delayed world preparation versus immediate production Timeline on admitted recordings; canonical state, trace/log order, authored samples and source timestamps. Typed support admission/adoption/removal, same-time commits, cold next-group media, and idle callback exclusion."}
    FileAccess.open("res://generated/world_preparation_gate_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("WORLD_PREPARATION_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func run_recording(directory:String,label:String,expected:int)->void:
    var journal=Journal.new();var opened=journal.open(directory,true,false)
    check(opened.ok,label+" actual recorded protocol admitted")
    if not opened.ok:return
    var actual=Timeline.new();var reference=Timeline.new();var gate=Gate.new();actual.world_ready=gate.ready
    var count=0;var groups=0
    var files=DirAccess.get_files_at(directory);files.sort()
    for file in files:
        if not file.ends_with(".json") or file.length()!=21:continue
        var name="InitializationResponse" if count==0 else "PlayerOperation"
        var decoded=journal.protocol.decode(name,FileAccess.get_file_as_bytes(directory.path_join(file)))
        check(decoded.ok,label+" packet"+str(count))
        if not decoded.ok:break
        var packet:Dictionary=journal.protocol.normalize(name,decoded.value)
        if count==0:
            var initial=Reducer.reduce_initialization(packet.initialization,packet.content_additions)
            check(initial.ok,label+" native initialization reduced")
            if not initial.ok:break
            actual.accept({"kind":"initialization","state":initial.value.duplicate(true),"sequence":0})
            reference.accept({"kind":"initialization","state":initial.value.duplicate(true),"sequence":0})
            if fixture_state.is_empty():fixture_state=initial.value.duplicate(true)
        else:
            var compiled=Compiler.compile(actual.state,packet,cache)
            check(compiled.ok,label+" native operation compiled")
            if not compiled.ok:break
            for lineage in packet.lineages:
                for node in lineage.events:
                    if node.get("fact")==null:continue
                    var fact:Dictionary=node.fact
                    if fact.kind=="attack" and fact.get("behavior_id")=="reaction.opportunity_attack":evidence.oa+=1
                    if fact.kind=="step" and not fact.committed:evidence.uncommitted_steps+=1
                    if fact.kind=="step" and fact.trajectory=="direct_arc":evidence.direct_arc+=1
                    if fact.kind in ["life_state","life"]:evidence.life+=1
            for group in compiled.value.groups:
                actual.accept({"kind":"operation","groups":[group]})
                reference.accept({"kind":"operation","groups":[group]})
                drain(actual,reference,gate,label+"/"+str(count)+"/"+str(groups));groups+=1
            check(actual.state==compiled.value.final_state,label+" complete native operation after-values")
        count+=1
    check(count==expected,label+" full recorded packet count")
    candidate_calls+=gate.calls
    records.append({"name":label,"packets":count,"groups":groups,"boundaries":gate.keys.size()})
func make_group(id:String,commits:Array,duration:float,supports:Dictionary={},times:Dictionary={})->Dictionary:
    return {"id":id,"operation_sequence":1,"operation_end":true,"duration_ms":duration,"actor_tracks":[],
        "commits":commits,"events":[],"staged_tiles":supports,"staged_tile_at_ms":times,"staged_actors":{}}
func pair()->Array:
    var a=Timeline.new();var b=Timeline.new();var gate=Gate.new();a.world_ready=gate.ready
    for timeline in [a,b]:timeline.accept({"kind":"initialization","state":fixture_state.duplicate(true),"sequence":0})
    return [a,b,gate]
func named_boundaries()->void:
    var sample=pair();var actual=sample[0];var reference=sample[1];var gate=sample[2]
    var key:String=fixture_state.tiles.keys()[0];var tile:Dictionary=fixture_state.tiles[key]
    for timeline in [actual,reference]:timeline.state.tiles.erase(key)
    var value=make_group("stage-then-remove",[],20,{key:tile},{key:5.0})
    for timeline in [actual,reference]:timeline.accept({"kind":"operation","groups":[value]})
    drain(actual,reference,gate,"typed support admission/removal")
    check(gate.keys.size()==2,"Independent staging timestamp and end-of-group removal each require preparation")
    sample=pair();actual=sample[0];reference=sample[1];gate=sample[2]
    for timeline in [actual,reference]:timeline.state.tiles.erase(key)
    var delta=Compiler.empty_delta();delta.tiles[key]=tile
    value=make_group("stage-and-adopt-same-time",[{"at_ms":5.0,"delta":delta}],10,{key:tile},{key:5.0})
    for timeline in [actual,reference]:timeline.accept({"kind":"operation","groups":[value]})
    drain(actual,reference,gate,"typed same-time adoption")
    check(gate.keys.size()==1 and actual.state.tiles.has(key),"Same-time canonical adoption does not disclose an extra temporary support")
    sample=pair();actual=sample[0];reference=sample[1];gate=sample[2]
    var id:String=fixture_state.objects.keys()[0];var object:Dictionary=fixture_state.objects[id]
    var remove=Compiler.empty_delta();remove.objects_removed=[id]
    var readd=Compiler.empty_delta();readd.objects[id]=object
    value=make_group("zero-time-remove-readd",[{"at_ms":0.0,"delta":remove},{"at_ms":0.0,"delta":readd}],0)
    for timeline in [actual,reference]:timeline.accept({"kind":"operation","groups":[value]})
    drain(actual,reference,gate,"typed zero-duration ordered commits")
    check(gate.keys.size()==1 and actual.state.objects.keys().back()==id,"One zero-time preparation preserves remove/readd source ordering")
    sample=pair();actual=sample[0];reference=sample[1];gate=sample[2]
    # Ordinary actor/clock segments do not ask the world builder to run.
    value=make_group("ordinary",[],20)
    for timeline in [actual,reference]:timeline.accept({"kind":"operation","groups":[value]})
    drain(actual,reference,gate,"ordinary clock")
    check(gate.calls==0,"No prospective world work on ordinary frame advancement")
    var first=make_group("warm-current",[],0)
    var second=make_group("cold-next",[{"at_ms":0.0,"delta":delta}],0)
    actual.accept({"kind":"operation","groups":[first,second]})
    var ready={"next":false};var tested={"wrong_owner":false}
    actual.media_ready=func(group):
        if group.get("id")=="cold-next":
            if not actual.current.is_empty():tested.wrong_owner=true
            return ready.next
        return true
    actual.advance(100)
    check(actual.current.is_empty() and actual.queue.size()==1,"Current completion publishes before next group media preflight")
    var state=actual.state.duplicate(true);var time=actual.display_ms;var rows=actual.trace.rows.duplicate(true)
    actual.advance(100)
    check(actual.waiting_for_media and actual.state==state and actual.display_ms==time and actual.trace.rows==rows,"Cold next-group media holds every publication field")
    check(not tested.wrong_owner,"Next-group media callback never observes previous active group")
    ready.next=true
    for i in range(3):actual.advance(100)
    check(not actual.busy(),"Prepared next group can eventually commit")
    actual.media_ready=Callable() # Break the test callback's captured-owner cycle.
    check(actual._scheduled_group.is_empty(),"Completed group leaves no staged schedule owning retired metadata")
