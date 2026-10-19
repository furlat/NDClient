extends "res://tests/world_preparation_gate_checks.gd"
# Already received world lookahead must never become displayed state early.
var early_previews=0
var matching_due=0
var prepared={}
func run_recording(directory:String,label:String,expected:int)->void:
    # Preparation keys belong to one reducer/timeline epoch, not every replay.
    prepared.clear()
    super.run_recording(directory,label,expected)
func drain(actual:RefCounted,reference:RefCounted,gate:Gate,label:String)->void:
    var attempts=0
    while actual.busy() and attempts<4000:
        var before=actual.display_ms
        var revision=actual.revision
        var trace_revision=actual.trace_revision
        var stage=actual.staged_tiles()
        var preview=actual.preview_world()
        check(actual.display_ms==before and actual.revision==revision and actual.trace_revision==trace_revision and actual.staged_tiles()==stage,label+" preview has no clock/state/trace/staging publication")
        if not preview.is_empty():
            var key=JSON.stringify(preview.preparation_key)
            if not prepared.has(key):
                prepared[key]=preview
                if preview.display_ms>before:early_previews+=1
            check(is_same(preview,actual.preview_world()),label+" repeated preview reuses passive snapshot")
            check(not str(preview.source_group_id).is_empty(),label+" completing boundary retains source media owner")
        gate.accepted={}
        actual.advance([0.0,7.0,19.0,9000.0][attempts%4])
        if actual.waiting_for_world:
            held+=1
            check(actual.display_ms==before,label+" delayed preparation freezes clock")
            aligned(actual,reference,label+" held")
        else:
            reference.advance(maxf(0,actual.display_ms-reference.display_ms))
            aligned(actual,reference,label+" published")
            if not gate.accepted.is_empty():
                boundaries+=1
                var due:Dictionary=gate.accepted
                var key=JSON.stringify(due.preparation_key)
                check(prepared.has(key),label+" actual due boundary matches received lookahead key")
                if prepared.has(key):
                    var early:Dictionary=prepared[key]
                    check(early.presentation_state.tiles==due.presentation_state.tiles and early.presentation_state.objects==due.presentation_state.objects and early.presentation_state.senses==due.presentation_state.senses,label+" prepared world equals fresh due candidate")
                    check(early.display_ms==due.display_ms,label+" received source chronology remains exact")
                    matching_due+=1
                check(actual.state==due.state and actual.presentation_state()==due.presentation_state,label+" fresh due state is exact published boundary")
        attempts+=1
    check(not actual.busy() and not reference.busy(),label+" timelines finish without lost commits")
    check(not gate.mismatch,label+" held due candidate remains immutable")
func run()->void:
    run_recordings()
    received_window()
    static_window()
    reset_epoch()
    check(early_previews>0 and matching_due>0,"Real received movement offers world preparation before causal arrival")
    var report={"checks":checks,"failures":failures,"recordings":records,"early_previews":early_previews,"matched_due_boundaries":matching_due,
        "native_fact_evidence":evidence,"scope":"Read-only cached received lookahead versus fresh due admission and immediate Timeline, actual Gallery and movement/OA/jump/death captures; finite queued chronology, support transition, media callback exclusion and initialization retirement fixtures."}
    FileAccess.open("res://generated/world_preview_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("WORLD_PREVIEW_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func received_window()->void:
    var sample=pair();var actual=sample[0]
    var id:String=fixture_state.actors.keys()[0]
    var ordinary=Compiler.empty_delta();ordinary.actors[id]=fixture_state.actors[id]
    var key:String=fixture_state.tiles.keys()[0]
    var delta=Compiler.empty_delta();delta.tiles[key]=fixture_state.tiles[key]
    var first=make_group("moving-before-received-world",[{"at_ms":5.0,"delta":ordinary}],20.0)
    var second=make_group("received-next-world",[{"at_ms":10.0,"delta":delta}],10.0)
    var calls={"media":0,"world":0,"allow":false}
    actual.media_ready=func(_group):calls.media+=1;return true
    actual.world_ready=func(_candidate):calls.world+=1;return calls.allow
    actual.accept({"kind":"operation","groups":[first,second]})
    var early=actual.preview_world()
    check(calls.media==0 and calls.world==0 and actual.current.is_empty(),"Peek neither consults media nor activates the queued group")
    check(early.display_ms==30.0 and early.source_group_id==second.id and early.group_id=="","Two received groups use authored duration and retain completed source owner")
    actual.advance(6.0)
    check(actual.display_ms==6.0 and actual.revision>1 and calls.world==0,"Ordinary actor commit proceeds while future world is only prepared")
    check(is_same(actual.preview_world(),early),"Actor-only revision does not copy or invalidate earliest received world")
    actual.advance(14.0)
    check(actual.display_ms==20.0 and (actual.current.is_empty() or actual.current.id==second.id),"Prior group completion retains its authored boundary before the next received world")
    var next=actual.preview_world()
    check(next.preparation_key==early.preparation_key and next.display_ms==30.0,"Cross-group traversal keeps stable preparation key and chronology")
    actual.advance(10.0)
    check(actual.waiting_for_world and actual.display_ms==20.0 and actual.pending_world.preparation_key==early.preparation_key,"Actual causal boundary gates exact fresh candidate without early clock advance")
    calls.allow=true;actual.advance(999.0)
    check(actual.display_ms==30.0 and actual.state==early.state and not actual.busy(),"Preprepared world publishes at source timestamp without wait catch-up")
    actual.media_ready=Callable();actual.world_ready=Callable()
    actual=pair()[0]
    actual.accept({"kind":"operation","groups":[make_group("window-a",[],1),make_group("window-b",[],1),second]})
    check(actual.preview_world().is_empty(),"Lookahead stops at current plus one upcoming received group")
    actual.advance(1)
    check(not actual.preview_world().is_empty(),"Next world becomes preparable as the received media window advances")
    actual=pair()[0];actual.state.tiles.erase(key)
    var staged=make_group("staged-window",[],20,{key:fixture_state.tiles[key]},{key:5.0})
    actual.accept({"kind":"operation","groups":[staged]})
    early=actual.preview_world()
    check(early.display_ms==5.0 and early.presentation_state.tiles.has(key) and not actual.presentation_state().tiles.has(key),"Future staged support is prepared without early disclosure")
    actual.world_ready=func(_candidate):return true
    actual.advance(5)
    next=actual.preview_world()
    check(next.display_ms==20.0 and next.preparation_key!=early.preparation_key and not next.presentation_state.tiles.has(key),"Admitted support changes baseline and prepares independent end removal")

func static_window()->void:
    var actual=pair()[0]
    var key:String=fixture_state.tiles.keys()[0]
    var delta:Dictionary=Compiler.empty_delta();delta.tiles[key]=fixture_state.tiles[key]
    var group:Dictionary=make_group("source-before-static",[{"at_ms":12.0,"delta":delta}],20)
    group.actor_source_times=[0.0,5.0,9.0]
    actual.accept({"kind":"operation","groups":[group]})
    var clock:float=actual.display_ms;var revision:int=actual.revision;var trace:int=actual.trace_revision
    var ordinary:Dictionary=actual.preview_world();var passive:Dictionary=actual.preview_world(false)
    check(ordinary.source_local_ms==0.0 and passive.source_local_ms==12.0,"Static forecast skips source-only timestamps and stops at the first actual world delta")
    check(actual.display_ms==clock and actual.revision==revision and actual.trace_revision==trace and actual.current.is_empty(),"Static forecast does not activate, advance or publish any event")
    check(is_same(passive,actual.preview_world(false)) and is_same(ordinary,actual.preview_world()),"Normal and passive static forecasts retain independent cached owners")
    actual.world_ready=func(_candidate):return true
    actual.advance(0)
    check(actual.preview_world().source_local_ms==5.0 and actual.preview_world(false).preparation_key==passive.preparation_key,"Static target remains stable across an admitted source-only cut")
    actual=pair()[0];group=group.duplicate();group.actor_structure_times=[6.0]
    actual.accept({"kind":"operation","groups":[group]})
    check(actual.preview_world(false).source_local_ms==6.0,"Static forecast cannot cross an actor-structure boundary")
    actual=pair()[0];actual.state.tiles.erase(key)
    group=group.duplicate();group.actor_structure_times=[];group.staged_tiles={key:fixture_state.tiles[key]};group.staged_tile_at_ms={key:8.0}
    actual.accept({"kind":"operation","groups":[group]})
    check(actual.preview_world(false).source_local_ms==8.0 and not actual.presentation_state().tiles.has(key),"Static forecast stops at temporary support admission without disclosing it")
func reset_epoch()->void:
    var sample=pair();var actual=sample[0]
    var key:String=fixture_state.tiles.keys()[0]
    var delta=Compiler.empty_delta();delta.tiles[key]=fixture_state.tiles[key]
    actual.accept({"kind":"operation","groups":[make_group("old-active",[{"at_ms":10.0,"delta":delta}],20),make_group("old-queued",[],1)]})
    actual.advance(1)
    var early=actual.preview_world()
    actual.advance(9)
    check(actual.waiting_for_world and not actual.pending_world.is_empty(),"Reset fixture reaches a held old-epoch boundary")
    var retired=[]
    actual.retire_group=func(group):retired.append(group.id)
    var trace=actual.trace.rows.duplicate(true);var time=actual.display_ms
    actual.accept({"kind":"initialization","state":fixture_state.duplicate(true),"sequence":100})
    check(retired==["old-active","old-queued"] and not actual.busy(),"New initialization retires active and queued old-epoch groups exactly once")
    check(actual.pending_world.is_empty() and actual.preview_world().is_empty() and not actual.waiting_for_world,"Initialization rejects held and cached old preparation")
    check(actual.trace.rows==trace and actual.display_ms==time,"Initialization retirement preserves established trace and clock policy")
    actual.accept({"kind":"operation","groups":[make_group("old-active",[{"at_ms":10.0,"delta":delta}],20)]})
    var fresh=actual.preview_world()
    check(fresh.preparation_key!=early.preparation_key,"Repeated source occurrence cannot reuse preparation from another initialization epoch")
