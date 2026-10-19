extends SceneTree
## Same real encounter, separate authorized reducers, shared causal navigation.
const Recording=preload("res://studio/recording.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Comparison=preload("res://studio/replay_comparison.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]

func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("PERSPECTIVE_FAIL ",label)

func _case(name:String)->Dictionary:
    return Fixtures.case_record(name)

func event_rows(index:Dictionary)->Dictionary:
    var result:Dictionary={}
    for occurrence in index.clock_events:
        var key:String=Recording.event_key(index,str(occurrence))
        check(not result.has(key),"Comparison anchors never collapse two native occurrences within one view")
        result[key]=index.clock_events[occurrence]
    return result

func correspondence_boundaries()->void:
    # Pure metadata boundary, not fabricated wire facts or recording evidence:
    # equal seat-local numbers prove nothing, and repeated factual candidates
    # cannot prove which occurrence another seat observed.
    var sample={"views":{"amber":{"groups":[],"correspondence_candidates":{"7":"duplicate","8":"duplicate","9":"unique"}},
        "blue":{"groups":[],"correspondence_candidates":{"7":"duplicate","10":"unique"}}}}
    Comparison.correspondence(sample)
    check(Comparison.event_key(sample.views.amber,"amber","9")==Comparison.event_key(sample.views.blue,"blue","10"),"Unique explicit comparison operands may match different native occurrence numbers")
    check(sample.views.amber.correspondence.size()==1 and sample.views.blue.correspondence.size()==1,"Ambiguous repeated operands are absent from proven shared correspondence")
    check(Comparison.event_key(sample.views.amber,"amber","7")!=Comparison.event_key(sample.views.blue,"blue","7"),"Equal native occurrence numbers remain private when evidence is ambiguous")

func original_cursor_boundaries()->void:
    var bundle:Dictionary=Recording.read_case(Fixtures.case_record("gallery"))
    check(bundle.ok,"Original Gallery's unequal subjective cursor streams admit")
    if not bundle.ok:return
    var amber:Dictionary=bundle.views.amber;var blue:Dictionary=bundle.views.blue
    var a_turns:Array=Fixtures.fact_rows("gallery","turn")
    var b_turns:Array=Fixtures.fact_rows("gallery","turn","blue")
    var a:Array=a_turns.filter(func(row):return int(row.node.occurrence)==77)
    var b:Array=b_turns.filter(func(row):return int(row.node.occurrence)==102)
    check(a.size()==1 and b.size()==1,"Exact original Gallery turn-end witnesses exist in both subjective streams")
    if a.size()==1 and b.size()==1:
        check(int(a[0].sequence)==4 and int(b[0].sequence)==3 and a[0].fact==b[0].fact and a[0].node.turn_execution_id==b[0].node.turn_execution_id,"Same disclosed real execution has different native cursor sequences")
        var key:String=Recording.event_key(amber,"77")
        check(key.begins_with("shared:") and key==Recording.event_key(blue,"102"),"Explicit real turn execution and unique fact match regardless of subjective sequence")
    var a_steps:Array=Fixtures.fact_rows("gallery","step").filter(func(row):return int(row.node.occurrence)==42)
    var b_steps:Array=Fixtures.fact_rows("gallery","step","blue").filter(func(row):return int(row.node.occurrence)==67)
    check(a_steps.size()==1 and b_steps.size()==1,"Exact first Gallery move witnesses exist in both original journals")
    if a_steps.size()==1 and b_steps.size()==1:
        check(a_steps[0].fact==b_steps[0].fact and a_steps[0].node.get("turn_execution_id")!=null and b_steps[0].node.get("turn_execution_id")==null,"Original peer disclosure lacks the global execution identity despite equal movement operands")
        check(Recording.event_key(amber,"42").begins_with("view:") and Recording.event_key(blue,"67").begins_with("view:") and Recording.event_key(amber,"42")!=Recording.event_key(blue,"67"),"Missing execution evidence leaves each actual movement private; cursor coincidence cannot invent a join")
    check(amber.group_correspondence.is_empty() and blue.group_correspondence.is_empty(),"Seat-local packet cursor numbers never establish global native group identity")

func _initialize()->void:
    correspondence_boundaries()
    original_cursor_boundaries()
    for name in ["dash","hide","oa-jump-lethal","invisibility"]:
        var bundle=Recording.read_case(_case(name))
        check(bundle.ok,"Original faction prefixes compile: "+name)
        if not bundle.ok:continue
        var views={}
        for id in bundle.views:
            var original:Dictionary=bundle.views[id]
            var before=JSON.stringify(original.initialization)
            var view=Recording.view_index(bundle,id);views[id]=view
            check(view.ok,"Combined inspection index opens: "+name+" / "+id)
            check(is_same(view.groups,original.groups) and is_same(view.initialization,original.initialization),"Inspection shares unchanged executable recording, no union gameplay state")
            var ids={}
            for row in view.rows:
                check(not ids.has(row.id),"Inspection row identity remains unique")
                ids[row.id]=true
            for row in view.rows:
                check(row.parent.is_empty() or ids.has(row.parent),"Every inspected effect retains an existing causal owner")
                if row.kind=="event" and row.get("split_views",false):
                    var branches=view.rows.filter(func(child):return child.kind=="perspective" and child.parent==row.id)
                    check(branches.size()==bundle.perspectives.size(),"One shared occurrence contains every recorded faction branch")
                    check(branches.all(func(branch):return branch.correspondence_event_key==row.correspondence_event_key),"Split branches refer to the same proven comparison anchor")
                    for branch in branches:
                        var source:Dictionary=bundle.views[branch.source_perspective]
                        var native:Array=source.rows.filter(func(event):return event.kind=="event" and Recording.event_key(source,str(event.event.event_uuid))==branch.correspondence_event_key)
                        if native.is_empty():check(str(branch.source_event_uuid).is_empty(),"Undisclosed branch has no invented native occurrence identity")
                        else:
                            check(native.size()==1 and str(branch.source_event_uuid)==str(native[0].event.event_uuid),"Disclosed branch retains its own view's actual native occurrence identity")
                            check(Recording.event_key(source,str(branch.source_event_uuid))==branch.correspondence_event_key,"View-local native occurrence resolves to this explicit comparison anchor")
                if row.get("kind")=="other_view":
                    check(not row.visible_here and row.source_perspective!=id and not row.source_row_id.is_empty(),"Other faction requirement has explicit source and navigation")
                    if row.get("timing_status")=="other_perspective":check(row.end_ms==row.start_ms,"Unknown audience timing is not a fabricated interval")
            for fraction in [0.0,.25,.5,1.0]:
                var at=original.get("presentation_end_ms",original.duration_ms)*fraction
                var expected=Recording.restore(original,at)
                var actual=Recording.restore(view,at)
                check(actual.state==expected.state and actual.sequence==expected.sequence,"Combined inspection never changes faction reduction at %.3f"%at)
            check(before==JSON.stringify(original.initialization),"Repeated view restores do not mutate recorded initialization")
            evidence.append({"case":name,"faction":id,"own_rows":original.rows.size(),"combined_rows":view.rows.size(),"duration_ms":view.duration_ms})
        var a:Dictionary=views.amber;var b:Dictionary=views.blue
        var a_events:Dictionary=event_rows(a);var b_events:Dictionary=event_rows(b)
        for row in a.clock_events.values():
            var key:String=Recording.event_key(a,str(row.event.event_uuid))
            if row.end_ms<=row.start_ms or not b_events.has(key):continue
            var counterpart:Dictionary=b_events[key]
            if counterpart.end_ms<=counterpart.start_ms:continue
            for phase in [.1,.5,.9]:
                var at=lerpf(row.start_ms,row.end_ms,phase)
                var mapped=Recording.switch_time(a,b,at,row)
                check(is_equal_approx(mapped,lerpf(counterpart.start_ms,counterpart.end_ms,phase)),"Faction switch preserves shared occurrence phase")
                check(is_equal_approx(Recording.switch_time(b,a,mapped,counterpart),at),"Faction roundtrip returns to the same occurrence phase")
        if name=="invisibility":
            var actor_steps=a.clock_events.values().filter(func(row):return row.event.kind=="step")
            var enemy_steps=b.clock_events.values().filter(func(row):return row.event.kind=="step")
            actor_steps.sort_custom(func(x,y):return x.start_ms<y.start_ms)
            check(actor_steps.size()==2 and enemy_steps.size()==1,"Real Invisibility case has one unseen move and one move revealed by See Invisibility")
            if actor_steps.size()==2 and enemy_steps.size()==1:
                check(Recording.event_key(b,str(enemy_steps[0].event.event_uuid))==Recording.event_key(a,str(actor_steps[1].event.event_uuid)),"Enemy sees the second actual movement through proven factual correspondence, never a copy of the unseen move")
                check(enemy_steps[0].event.event_uuid!=actor_steps[1].event.event_uuid,"Real schema16 evidence exercises different subjective occurrence numbers for the same disclosed movement")
                var invisible=actor_steps[0]
                var shared=a.rows.filter(func(row):return row.kind=="event" and row.event.event_uuid==invisible.event.event_uuid)
                check(shared.size()==1 and shared[0].get("split_views",false),"Unseen movement has one causal event with split audience tracks")
                var at=lerpf(invisible.start_ms,invisible.end_ms,.5)
                var anchor=Recording.navigation_anchor(a,at,invisible)
                var enemy_at=Recording.anchor_time(b,anchor);anchor.mapped_time_ms=enemy_at
                var counterpart:Dictionary={}
                var unseen_key:String=Recording.event_key(a,str(invisible.event.event_uuid))
                for row in b.rows:
                    if (row.kind=="event" or row.get("source_kind")=="event") and row.get("correspondence_event_key")==unseen_key:counterpart=row;break
                check(not counterpart.is_empty(),"Enemy inspection retains the shared unseen occurrence as a selectable event")
                var back=Recording.navigation_anchor(b,enemy_at,counterpart,anchor)
                check(is_equal_approx(Recording.anchor_time(a,back),at),"Invisible movement phase survives a switch through the enemy's zero-duration view")
        if name=="hide":
            var hidden:Dictionary={}
            for row in a.rows:
                if row.kind=="condition" and row.owner.condition.behavior_id=="condition.hidden":hidden=row
            check(not hidden.is_empty(),"Actual Hide capture supplies hidden condition lifetime")
            if not hidden.is_empty():
                var disclosed:bool=Fixtures.fact_rows("hide","actor_change","blue").any(func(row):return row.fact.actors.any(func(actor):return actor.rows.any(func(change):return change.field=="condition" and change.condition_uuid==hidden.owner.id and change.get("member")!=null)))
                check(bundle.views.blue.rows.any(func(row):return row.kind=="condition" and row.owner.id==hidden.owner.id)==disclosed,"Blue inspection contains Hidden exactly when its original schema16 stream discloses it")
                if not disclosed:check(b.rows.any(func(row):return row.get("source_kind")=="condition" and row.get("owner",{}).get("id")==hidden.owner.id and not row.visible_here),"Undisclosed lifetime remains an inspection-only other-faction row")
                var applications:Array=Fixtures.fact_rows("hide","actor_change").filter(func(row):return row.fact.actors.any(func(actor):return actor.rows.any(func(change):return change.field=="condition" and change.condition_uuid==hidden.owner.id and change.get("member")!=null)))
                check(not applications.is_empty(),"Hidden application is an original native condition membership fact")
                var cause:String=str(int(applications[0].node.occurrence)) if not applications.is_empty() else ""
                var by_id={}
                for row in a.rows:by_id[row.id]=row
                var parent:String=hidden.parent
                while by_id.has(parent) and by_id[parent].kind!="event":parent=by_id[parent].parent
                check(a.clock_events.has(cause) and parent==a.clock_events[cause].id,"Retained condition is nested under its recorded application cause and faction: "+JSON.stringify({"condition":hidden.owner.id,"condition_parent":hidden.parent,"resolved_parent":parent,"expected_occurrence":cause,"expected_parent":a.clock_events.get(cause,{}).get("id"),"owner":hidden.owner,"cause_fact":applications[0] if not applications.is_empty() else {}}))
                if not disclosed:check(a.rows.any(func(row):return row.kind=="event" and row.get("split_views",false) and row.event.event_uuid==cause),"An undisclosed Hidden application creates split inspection timelines for the same occurrence")
                var at=minf(hidden.end_ms-.001,hidden.start_ms+30)
                var anchor=Recording.navigation_anchor(a,at,hidden)
                var enemy_time=Recording.anchor_time(b,anchor)
                anchor.mapped_time_ms=enemy_time
                var other_hidden:Dictionary={}
                for row in b.rows:
                    if row.get("source_kind")=="condition" and row.get("owner",{}).get("id")==hidden.owner.id:other_hidden=row;break
                var returning=Recording.navigation_anchor(b,enemy_time,other_hidden,anchor)
                check(is_equal_approx(Recording.anchor_time(a,returning),at),"Amber30ms through unseen zero-duration Blue view returns to same Hidden phase, not later attack")
    var mixed=_case("dash")
    mixed.perspectives[1].journal=Fixtures.journal("hide","blue")
    check(not Recording.read_case(mixed).ok,"Reject two unrelated encounter epochs instead of treating them as factions")
    var report={"checks":checks,"failures":failures,"recordings":evidence,"scope":"Real recorded faction switching and combined requirements, with unchanged authorized reducer/display input per faction."}
    FileAccess.open("res://generated/studio_perspective_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_PERSPECTIVES ",checks," checks; ",failures.size()," failures")
    quit(0 if failures.is_empty() else 1)
